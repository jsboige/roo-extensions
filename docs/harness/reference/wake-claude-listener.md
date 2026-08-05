# Wake-Claude — Listener, durabilité et observabilité

**Déporté de** `.claude/rules/wake-claude-routing.md` (v1.1.0) le 2026-08-05.
**Issues :** #2431 (durabilité + observabilité) · #2186 (routing vérifié-correct) · #2928 (détection fleet) · #2561 (choix du modèle)

La règle auto-chargée garde le **contrat de routing** et les interdits. Tout ce qui suit est de la
procédure et du contexte : on le lit quand on répare un listener, pas à chaque conversation.

---

## Architecture (chaîne de spawn)

```
Tâche planifiée  Claude-DashboardListener  (utilisateur, RunLevel Highest, Interactive)
   -> dashboard-listener-wrapper.ps1   (boucle while($true) : relance le listener s'il sort)
      -> dashboard-listener.ps1        (FileSystemWatcher + poll 20s + spawn claude -p)
```

Installation : `scripts/dashboard-scheduler/install-dashboard-listener-schtask.ps1` (élévation requise).

**Principal = utilisateur** (PAS SYSTEM) : le listener spawn un `claude -p` en contexte utilisateur,
comme la tâche `Claude-Worker`.

## Fonctions de routing (référence)

Détection : `Test-ActionableContent` ([dashboard-listener.ps1:352](../../../scripts/dashboard-scheduler/dashboard-listener.ps1#L352)).
Routing : `Get-WakeTargetMachine` (L383), `Get-WakeTargetWorkspace` (L393), `Get-WakeBotTarget` (L402).
Garde-fous : cooldown `Test-CooldownOk` (L444), sanity issues fermées `Test-ReferencedClosedIssues` (L414).

Les regexes `Get-WakeTarget*` arrêtent la capture workspace au premier espace → un suffixe ` model=X`
ne corrompt jamais le routing.

**Toute modification de ces fonctions est hors-scope** : la cause des réveils manuels n'a jamais été
le routing.

## Choix du modèle de la session réveillée (#2561, mandat user 2026-06-11)

**Défaut = capable** : `spawn-claude.ps1` défaute à `sonnet` (Claude Sonnet sur machines Anthropic,
**GLM sur machines routées z.ai** via l'alias du routeur). Le haiku-défaut #2172 était trop faible
pour les interventions infra (rebind cert, restart container).

- **Override par-machine** : `$env:WAKE_DEFAULT_MODEL` (ex. un id GLM z.ai épinglé) — utile si
  l'alias `sonnet` ne mappe pas proprement côté z.ai.
- **Override par-WAKE** : suffixe `model=X` sur la ligne WAKE → `Get-WakeModelHint` (scope = ligne
  d'instruction WAKE uniquement) passe `-Model X` à spawn-claude. L'appelant downshift à
  `model=haiku` quand la tâche est triviale.
- **Précédence** : `model=X` (per-WAKE) > `$env:WAKE_DEFAULT_MODEL` (machine) > `sonnet`.

## Durabilité (fix #2431)

La cause des ~2 mois de réveils manuels était **mécanique**, pas du routing :

1. **Kill 72h sans ré-arme.** La tâche était enregistrée sans `-ExecutionTimeLimit` → défaut Windows
   `PT72H` → le wrapper long-running était force-terminé (`SCHED_S_TASK_TERMINATED` / `0x41306`) au
   bout de 72h, et le **seul** trigger `-AtLogOn` ne relançait rien jusqu'au prochain logon interactif.
2. **Heartbeat menteur.** Le heartbeat était écrit par le wrapper au start/exit du listener, **hors**
   de la boucle infinie du listener → il devenait stale en ~1 min même listener vivant.

**Design retenu** (mime l'idiome `install-watchdog-schtask.ps1`, PAS de tâche watchdog séparée) :

- Triggers : `-AtLogOn` + `-AtStartup` (délai 1 min) + répétition `-Once` toutes les **15 min**.
- `-ExecutionTimeLimit ([TimeSpan]::Zero)` → plus de kill 72h.
- `-MultipleInstances IgnoreNew` → la répétition 15 min est un no-op si un wrapper tourne déjà ;
  elle ne relance donc qu'un wrapper **mort** (self-healing par construction, ≤15 min en session ouverte).
- Compromis assumé : un reboot sans logon attend le logon (ces machines restent loguées ;
  `-AtLogOn`/`-AtStartup` couvrent re-logon/boot).

## Liveness (observabilité #2431)

Le listener écrit son heartbeat **dans sa boucle**, sur une cadence **découplée du poll 20s** :
défaut **5 min** (`DASHBOARD_HEARTBEAT_INTERVAL_SECONDS`). Un listener n'est PAS un service temps-réel —
la coordination flotte tourne sur des crons 2h+, donc un ping minute-par-minute ne sert qu'à saturer GDrive.

- **Local** : `<RepoRoot>/.claude/locks/dashboard-listener.heartbeat`
- **Partagé (GDrive)** : `<ROOSYNC_SHARED_PATH>/listener-heartbeats/<machine>.heartbeat`
  (`ROOSYNC_SHARED_PATH` se termine déjà par `.shared-state`)

Écriture best-effort/try-catch : une indisponibilité GDrive ne casse jamais la boucle.

**Côté coordinateur (ai-01)** : lire `<ROOSYNC_SHARED_PATH>/listener-heartbeats/*.heartbeat` et flagger
celui dont le mtime > **~2h** comme listener mort — 2h = la durée de la plupart des crons flotte. Un
listener vraiment vivant pingue toutes les 5 min, donc 2h de silence = mort certaine, jamais un faux
positif ; un seuil plus serré n'a aucun sens quand la coordination elle-même tourne sur des crons 2h+.
Seuil porté par `-StaleSeconds` (défaut 7200) de `diagnose-wake-listener.ps1`.

Diagnostic local non-élevé dispatchable : `scripts/dashboard-scheduler/diagnose-wake-listener.ps1`
(State/LastTaskResult + fraîcheur heartbeat + dernière ligne de log → append dashboard workspace).

## Ré-installation élevée = `[INTERACTIVE-ONLY]`

Ré-enregistrer la tâche (`Register-ScheduledTask -RunLevel Highest`) **exige l'élévation** : ni un
worker cron non-élevé, ni un `[WAKE-CLAUDE]` (chicken-and-egg : on ne peut pas WAKE pour réparer le
WAKE) ne peuvent le faire. À exécuter par l'utilisateur, ou par le Claude interactif (VS Code) de
chaque machine :

```powershell
pwsh -ExecutionPolicy Bypass -File scripts\dashboard-scheduler\install-dashboard-listener-schtask.ps1
```

Vérifier ensuite : `(Get-ScheduledTask Claude-DashboardListener).Triggers` (AtLogOn + AtStartup +
répétition), `.Settings.ExecutionTimeLimit = PT0S`, `.Settings.MultipleInstances = IgnoreNew`.

## Détection fleet proactive (#2928)

Sans surveiller les heartbeats eux-mêmes, un listener mort passe inaperçu 8h+ (au lieu de 2h max).
`check-all-listeners.ps1` lit tous les `*.heartbeat` partagées et poste `[FLEET-ALERT] [WARN]` dès
qu'une machine dépasse 2h. Conçu pour cron 2h, mais **il n'était enregistré sur AUCUNE machine**
(incident #2928 : ai-01 dead 8h, remarqué seulement par patrouilles manuelles po-2026/po-2024).

Installer (identique sur chaque machine — n'importe laquelle peut détecter n'importe quel autre
listener mort via les heartbeats partagées GDrive) :

```powershell
pwsh -ExecutionPolicy Bypass -File scripts\dashboard-scheduler\install-check-all-listeners-schtask.ps1 -DryRun   # preview
pwsh -ExecutionPolicy Bypass -File scripts\dashboard-scheduler\install-check-all-listeners-schtask.ps1           # register (elevated)
```

Options de rollout (lane coordinator/user) : (1) ai-01 seul auto-monitore tout le fleet,
(2) chaque machine installe → détection distribuée redondante, (3) garder ad-hoc. L'installeur ne
décide pas — il supporte les trois selon qui l'installe.

---

**Référence technique :** `dashboard-listener.ps1`, `dashboard-listener-wrapper.ps1`,
`install-dashboard-listener-schtask.ps1`, `diagnose-wake-listener.ps1`, `check-all-listeners.ps1`,
`install-check-all-listeners-schtask.ps1` (tous dans `scripts/dashboard-scheduler/`).
