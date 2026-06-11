# Wake-Claude Routing & Listener Durability

**Version:** 1.1.0 (heartbeat cadence relaxed — user mandate 2026-06-06 : un listener n'est pas un service temps-reel)
**Issue :** #2431 (durability + observability) ; routing verifie #2186
**MAJ:** 2026-06-06

---

## Quoi

Le mecanisme `[WAKE-CLAUDE]` permet a une machine de reveiller l'agent Claude d'une autre
machine en postant un tag sur le dashboard `workspace` partage (GDrive). Chaque machine fait
tourner un **listener** qui surveille les dashboards et spawn `claude -p` quand un tag la cible.

## Contrat de routing (NE PAS MODIFIER — #2186 verifie-correct)

Le tag doit etre en **debut de ligne** ou dans un **header markdown** (`#`/`##`/`###`), hors bloc
de code, dans la section Intercom d'un dashboard `workspace-*.md`. Detection : `Test-ActionableContent`
([dashboard-listener.ps1:352](../../scripts/dashboard-scheduler/dashboard-listener.ps1#L352)).

| Forme | Cible |
|-------|-------|
| `[WAKE-CLAUDE] myia-po-2023` | machine entiere (tous workspaces) |
| `[WAKE-CLAUDE] myia-po-2023:IISManagement` | machine **+ workspace** precis (#2240) |
| `[WAKE-CLAUDE] → myia-po-2026:Embeddings` | fleche optionnelle toleree |
| `[WAKE-CLAUDE] myia-po-2023:IISManagement model=haiku` | **suffixe `model=X` optionnel** (#2561) — choix du modele de la session reveillee |
| `[WAKE-HERMES]` | `myia-po-2026:hermes-agent` (#2244) |
| `[WAKE-NANOCLAW]` | `myia-ai-01:nanoclaw` (#2244) |

Routing : `Get-WakeTargetMachine` (L383), `Get-WakeTargetWorkspace` (L393), `Get-WakeBotTarget` (L402).
Garde-fous : cooldown `Test-CooldownOk` (L444), sanity issues fermees `Test-ReferencedClosedIssues` (L414).
**Toute modif de ces fonctions est hors-scope** : la cause des reveils manuels n'a jamais ete le routing.

## Choix du modele de la session reveillee (#2561, mandate user 2026-06-11)

**Defaut = capable** : `spawn-claude.ps1` defaulte a `sonnet` (Claude Sonnet sur machines Anthropic, **GLM sur machines routees z.ai** via l'alias du routeur). Le haiku-defaut #2172 etait trop faible pour les interventions infra (rebind cert, restart container).

- **Override par-machine** : `$env:WAKE_DEFAULT_MODEL` (ex. un id GLM z.ai epingle) — utile si l'alias `sonnet` ne mappe pas proprement cote z.ai.
- **Override par-WAKE** : suffixe `model=X` sur la ligne WAKE → `Get-WakeModelHint` (scope = ligne d'instruction WAKE uniquement) passe `-Model X` a spawn-claude. L'appelant downshift a `model=haiku` quand la tache est triviale.
- **Precedence** : `model=X` (per-WAKE) > `$env:WAKE_DEFAULT_MODEL` (machine) > `sonnet`.
- Les regexes `Get-WakeTarget*` arretent la capture workspace au premier espace → un suffixe ` model=X` ne corrompt jamais le routing.

## Architecture (chaine de spawn)

```
Tache planifiee  Claude-DashboardListener  (utilisateur, RunLevel Highest, Interactive)
   -> dashboard-listener-wrapper.ps1   (boucle while($true) : relance le listener s'il sort)
      -> dashboard-listener.ps1        (FileSystemWatcher + poll 20s + spawn claude -p)
```

Installation : `scripts/dashboard-scheduler/install-dashboard-listener-schtask.ps1` (elevation requise).
**Principal = utilisateur** (PAS SYSTEM) : le listener spawn un `claude -p` en contexte utilisateur,
comme la tache `Claude-Worker`.

## Durabilite (fix #2431)

La cause des ~2 mois de reveils manuels etait **mecanique**, pas du routing :

1. **Kill 72h sans re-arme.** La tache etait enregistree sans `-ExecutionTimeLimit` → defaut Windows
   `PT72H` → le wrapper long-running etait force-termine (`SCHED_S_TASK_TERMINATED` / `0x41306`) au bout
   de 72h, et le **seul** trigger `-AtLogOn` ne relancait rien jusqu'au prochain logon interactif.
2. **Heartbeat menteur.** Le heartbeat etait ecrit par le wrapper au start/exit du listener, **hors**
   de la boucle infinie du listener → il devenait stale en ~1 min meme listener vivant.

**Design retenu** (mime l'idiome `install-watchdog-schtask.ps1`, PAS de tache watchdog separee) :

- Triggers : `-AtLogOn` + `-AtStartup` (delai 1 min) + repetition `-Once` toutes les **15 min**.
- `-ExecutionTimeLimit ([TimeSpan]::Zero)` → plus de kill 72h.
- `-MultipleInstances IgnoreNew` → la repetition 15 min est un no-op si un wrapper tourne deja ;
  elle ne relance donc qu'un wrapper **mort** (self-healing par construction, ≤15 min en session ouverte).
- Compromis assume : un reboot sans logon attend le logon (ces machines restent loguees ; `-AtLogOn`/`-AtStartup`
  couvrent re-logon/boot).

## Liveness (observabilite #2431)

Le listener ecrit son heartbeat **dans sa boucle**, sur une cadence **decouplee du poll 20s** :
defaut **5 min** (`DASHBOARD_HEARTBEAT_INTERVAL_SECONDS`). Un listener n'est PAS un service temps-reel —
la coordination flotte tourne sur des crons 2h+, donc un ping minute-par-minute ne sert qu'a saturer GDrive.

- **Local** : `<RepoRoot>/.claude/locks/dashboard-listener.heartbeat`
- **Partage (GDrive)** : `<ROOSYNC_SHARED_PATH>/listener-heartbeats/<machine>.heartbeat`
  (`ROOSYNC_SHARED_PATH` se termine deja par `.shared-state`)

Ecriture best-effort/try-catch : une indisponibilite GDrive ne casse jamais la boucle.

**Cote coordinateur (ai-01)** : lire `<ROOSYNC_SHARED_PATH>/listener-heartbeats/*.heartbeat` et flagger
celui dont le mtime > **~2h** comme listener mort — 2h = la duree de la plupart des crons flotte. Un
listener vraiment vivant pingue toutes les 5 min, donc 2h de silence = mort certaine, jamais un faux
positif ; un seuil plus serre n'a aucun sens quand la coordination elle-meme tourne sur des crons 2h+.
Seuil porte par `-StaleSeconds` (defaut 7200) de `diagnose-wake-listener.ps1`. Diagnostic local non-eleve dispatchable :
`scripts/dashboard-scheduler/diagnose-wake-listener.ps1` (State/LastTaskResult + fraicheur heartbeat +
derniere ligne de log → append dashboard workspace).

## Re-install eleve = `[INTERACTIVE-ONLY]`

Re-enregistrer la tache (`Register-ScheduledTask -RunLevel Highest`) **exige l'elevation** : ni un worker
cron non-eleve, ni un `[WAKE-CLAUDE]` (chicken-and-egg : on ne peut pas WAKE pour reparer le WAKE) ne
peuvent le faire. A executer par l'utilisateur, ou par le Claude interactif (VS Code) de chaque machine :

```powershell
pwsh -ExecutionPolicy Bypass -File scripts\dashboard-scheduler\install-dashboard-listener-schtask.ps1
```

Verifier ensuite : `(Get-ScheduledTask Claude-DashboardListener).Triggers` (AtLogOn + AtStartup + repetition),
`.Settings.ExecutionTimeLimit = PT0S`, `.Settings.MultipleInstances = IgnoreNew`.

---

**Reference technique :** `dashboard-listener.ps1`, `dashboard-listener-wrapper.ps1`,
`install-dashboard-listener-schtask.ps1`, `diagnose-wake-listener.ps1` (tous dans `scripts/dashboard-scheduler/`).
