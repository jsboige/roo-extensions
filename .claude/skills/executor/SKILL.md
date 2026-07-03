---
name: executor
description: Lance une session d'execution multi-agent RooSync pour les machines executantes (myia-po-* et myia-web1). Phrase declencheur : "/executor", "mode executor", "lance executor".
triggers:
  keywords:
    - "lance executor"
    - "mode executor"
    - "session executor"
  exact:
    - "executor"
  context:
    - "executor"
  priority: normal
metadata:
  author: "Roo Extensions Team"
  version: "3.6.0"
  compatibility:
    surfaces: ["claude-code"]
    restrictions: "Requiert acces aux MCPs roo-state-manager"
---

# Skill: Executor - Session d'Execution RooSync

**Version:** 3.6.0
**Cree:** 2026-03-28
**MAJ:** 2026-06-09 (#2509 fix faux-drain + #2539 cron 2h verification in Phase 0 pre-flight)
**Usage:** `/executor`
**Methodologie:** SDDD triple grounding (voir `docs/harness/reference/sddd-conversational-grounding.md`)

---

## Objectif

Executer une session de travail autonome sur les machines executantes (myia-po-2023, myia-po-2024, myia-po-2025, myia-po-2026, myia-web1).

**Canal de coordination PRINCIPAL :** Dashboard workspace (`roosync_dashboard`).
**Pas de fichier d'etat local.** La progression est rapportee via le dashboard workspace, pas via un fichier local.

---

## Workflow

### Phase 0 : Pre-flight Check

**Verifier les outils critiques AVANT toute autre action :**

1. MCP roo-state-manager disponible (15 outils) → Si absent, STOP & REPAIR
2. `git fetch origin && git pull origin main`
3. Verifier submodule mcps/internal a jour
   - **Deploy-lag nudge (#2591 follow-up)** : si le dernier commit merged sur main est un `chore(submod): bump roo-state-manager` ET qu'il touche `src/**/*.ts` (vérifier `git log --name-only -1`), le fix est merged en source mais **PAS live** jusqu'à rebuild+restart MCP host. Poster `[INFO] restart VS Code requis pour activer le fix submod #NNN` sur le dashboard (1 append, fusionnable avec le [DONE] du cycle). Le pre-flight worker (`start-claude-worker.ps1` `Sync-McpSubmoduleBuild`) rebuild déjà automatiquement le main-tree `build/` ; le nudge documente le restart `[INTERACTIVE-ONLY]` restant.
4. **Win-cli timeout guard** (anti-régression #2333) :
   - `pwsh.exe -ExecutionPolicy Bypass -File scripts/infra/harmonize-win-cli-timeouts.ps1`
   - Script idempotent vérifie les 2 niveaux (interne `~/.win-cli-mcp/config.json` + transport `mcp_settings.json`)
   - Ajouter `-Fix` pour corriger automatiquement si `commandTimeout < 600`
   - Poster `[WARN]` sur dashboard si corrections appliquées
5. **Cron 2h re-arm verification** (#2539) :
   - `CronList` — vérifier qu'un job récurrent `*/2` pour `/executor` existe
   - Si absent → `CronCreate(cron: "41 */2 * * *", prompt: "/executor", recurring: true)`
   - Session-only, auto-expire 7j — doit être vérifié/réarmé à chaque session
   - Poster `[INFO]` si réarmé (pour traçabilité)

Si un outil critique manque : signaler via dashboard workspace `[CRITICAL]` et STOP.

**Reference :** `.claude/rules/tool-availability.md`

---

### Phase 1 : Collecte + Grounding SDDD (5 min max)

Executer en parallele quand possible :

1. **RooSync inbox (OBLIGATOIRE, EN PREMIER)** : `roosync_messages(action: "inbox", status: "unread")`
2. **Dashboard workspace** : `roosync_dashboard(action: "read", type: "workspace", section: "intercom", intercomLimit: 20)`
3. **GitHub Issues ouvertes** : `gh issue list --repo jsboige/roo-extensions --state open --limit 100 --json number,title,labels`
   - **PIEGE `--limit` (bug #2509)** : `gh issue list --limit 15` retourne les **15 issues les PLUS RECENTES**, PAS un echantillon representatif. Si les 15 dernieres sont toutes `needs-approval`/meta, l'agent conclut faussement « pool draine, 0 tache » alors que des dizaines d'issues actionnables existent plus bas dans la liste. **TOUJOURS `--limit 100`** (le backlog reel tourne autour de 80-90 issues ouvertes).
   - **Filtrage actionnable (cote agent, apres recuperation)** : ne retenir que les issues portant un label actionnable — `approved`, `bug`, `investigation` — et **exclure** `needs-approval`, `deferred`, `blocked-on-gate`, `epic`. Compter ce sous-ensemble filtre, pas la liste brute.
   - **Conclusion « pool draine » INTERDITE** sans avoir verifie le backlog filtre complet (priorites Phase 2 ci-dessous). Un cycle IDLE ne se justifie que si le sous-ensemble actionnable est reellement vide.
4. **PRs ouvertes (ANTI-DOUBLE-CLAIM)** : `gh pr list --state open --limit 50 --json number,title,headRefName --repo jsboige/roo-extensions`
5. **Git state** : `git log --oneline -5`

**Resume concis (10 lignes max) :**
```
Machine: {name} | Git: {hash} | MCPs: {OK/KO}
RooSync: {Y non-lus} | Dashboard: {X messages recents}
Issues ouvertes: {Z} | PRs ouvertes: {P} ({branches})
Taches assignees: {liste courte}
```

---

### Phase 2 : Selection de Tache (automatique)

**Algorithme par priorite decroissante :**

1. Instructions directes RooSync du coordinateur
2. Issue GitHub avec Machine={MA_MACHINE} dans Project #67
3. Issue GitHub avec Machine=Any non reclamee
4. Issue GitHub avec TODO detaille sans Machine assignee
5. Bug ouvert reproductible
6. Issue "In Progress" sans activite recente
7. **Catalogue idle tasks** (voir ci-dessous — #1417)
8. **PR review (fallback #1713)** : Lancer `/pr-review` pour reviser les PRs ouvertes en attente

**ANTI-DOUBLE-CLAIM (OBLIGATOIRE avant chaque tache) :**

Avant de travailler sur une issue, verifier qu'aucune PR ouverte ne la couvre deja :

```bash
gh pr list --state open --search "<issue-number>" --repo jsboige/roo-extensions
```

Si une PR existe deja → **SKIP l'issue** + rapporter `[INFO] Issue #X deja couverte par PR #Y, skip`.

Cross-checker aussi avec les branches wt/ actives : si une branche `wt/*-{issue-keyword}` existe avec une PR ouverte, ne pas dupliquer.

**Si AUCUNE tache disponible (priorites 1-6)** : Executer les idle tasks ci-dessous puis fallback PR review.

> **Garde-fou anti-faux-drain (#2509)** : avant de declarer « aucune tache disponible », confirmer que le **backlog filtre complet** (`--limit 100` + labels actionnables, Phase 1 etape 3) a bien ete examine — pas seulement les 15 issues les plus recentes. Les priorites 3-5 (Machine=Any, TODO detaille, bug reproductible) sont quasi toujours servies par ce backlog. Passer aux idle tasks UNIQUEMENT si ce sous-ensemble est genuinement vide.

#### Catalogue Idle Tasks (#1417)

Quand aucune issue GitHub n'est assignable, executer ces taches productives dans l'ordre :

| # | Tâche | Type | Description | Contraintes |
|---|-------|------|-------------|-------------|
| I1 | Worktree/Branch cleanup | ACTIF | Detecter branches `wt/` orphelines >48h (PR merged/closed), nettoyer worktrees | `git worktree list` + `gh pr list` |
| I2 | Submodule drift check | READ-ONLY | Verifier `mcps/internal` vs dernier commit merged upstream. Signaler si >1 commit behind | Rapport dashboard `[WARN]` si drift |
| I3 | Heartbeat health patrol | READ-ONLY | `roosync_inventory(type: "machines")` — verifier heartbeats <6h pour chaque machine | Signaler silencieuses `[WARN]` |
| I4 | Config drift patrol | READ-ONLY | `roosync_compare_config()` entre machines, signaler divergences MCP/modes | Claude only |
| I5 | Doc freshness check | READ-ONLY | Verifier TOUTE la doc — `docs/`, `.claude/rules/`, `.claude/skills/`, `.roo/`, `roo-config/` — chemins references existent encore | Poster `[FRICTION]` si cassé |
| I6 | TODO/FIXME audit | READ-ONLY | Scanner `TODO`, `FIXME`, `HACK` dans le code. Recouper avec issues existantes | Creer issue pour non-trackés |
| I7 | Memory freshness audit | READ-ONLY | Verifier entrées MEMORY.md >30j sans MAJ | Signaler potentiellement obsoletes |
| I8 | Stale build artifacts | ACTIF | Scanner `build/` pour .js/.d.ts sans .ts source | Sous submodule seulement |

**Regle :** Max 2 idle tasks par cycle. Poster resultat sur dashboard (`[DONE]` ou `[INFO]`). Issue staleness patrol INTERDIT sans arbitrage utilisateur (priorite 6 couvre si issue genuinely stale). Fermeture d'issue INTERDITE sans arbitrage utilisateur (voir `.claude/rules/issue-closure.md`).

**Qui / Type / Contraintes (legende #1417) :** ce catalogue est le **versant Claude** (ce skill `executor` = agent Claude Code). Toutes les taches I1-I8 sont executables par Claude sauf restriction explicite en colonne *Contraintes* (ex. I4 = `Claude only`). Le **versant Roo** equivalent (patrouilles idle du scheduler) vit dans [`.roo/scheduler-workflow-executor.md`](../../../.roo/scheduler-workflow-executor.md) Option 2 — I2 (submodule drift) et I6 (TODO/FIXME) y sont desormais mirror. *Type* = `ACTIF` (modifie l'etat : commit/cleanup) ou `READ-ONLY` (diagnostic + rapport dashboard seulement).

---

### Phase 3 : Execution Autonome

Pour chaque tache selectionnee, executer le cycle complet :

1. **Investigation** : Lire le code, comprendre l'architecture
2. **Implementation** : Ecrire le code, tester incrementalement
3. **Validation** : `npm run build && npx vitest run` (JAMAIS `npm test`)
4. **Commit + PR** : Worktree → commit → PR (regle PR-mandatory)
5. **Rapport** : Dashboard workspace `[DONE]` + commentaire GitHub

**Objectif : 2-3 taches substantielles par session minimum.**

---

## Coordination

### Canal principal : Dashboard workspace

```javascript
// Rapporter progression
roosync_dashboard(action: "append", type: "workspace", tags: ["DONE", "claude-interactive"], content: "...")

// Rapporter blocage
roosync_dashboard(action: "append", type: "workspace", tags: ["BLOCKED", "claude-interactive"], content: "...")

// Signaler friction
roosync_dashboard(action: "append", type: "workspace", tags: ["FRICTION", "claude-interactive"], content: "...")

// Repondre a un [ASK]/[PROPOSAL]/[REQUEST] — notifie l'expediteur via mentions (#1956)
roosync_dashboard(action: "append", type: "workspace", tags: ["REPLY", "claude-interactive"],
  mentions: [{ messageId: "<id-du-message-original>" }],
  content: "...")

// Accuser reception sans reponse substantielle (ACK seul)
roosync_dashboard(action: "append", type: "workspace", tags: ["ACK", "claude-interactive"],
  mentions: [{ messageId: "<id-du-message-original>" }],
  content: "...")
```

**Regle mentions (#1956 niveau 1) :** Quand tu reponds a un message tagge `[ASK]`/`[PROPOSAL]`/`[REQUEST]` (ou tout message qui attend une reponse), TOUJOURS inclure `mentions: [{ messageId: "..." }]` avec l'id du message original. Cela notifie l'expediteur via RooSync qu'il a une reponse a lire — sans cela, l'expediteur n'a aucun signal et la boucle de coordination se rompt. Detail complet (`userId` vs `messageId` XOR, crossPost, dedup) : [`docs/harness/reference/intercom-v3-mentions.md`](../../../docs/harness/reference/intercom-v3-mentions.md).

### Communication Roo (meme machine)

- Dashboard workspace pour coordination
- Si MCP dashboard indisponible (GDrive offline) : INTERCOM local comme LAST RESORT (DEPRECATED)

---

## Regles Critiques

### Autonomie maximale
- **NE PAS** demander "Que dois-je faire ?"
- **TOUJOURS** selectionner une tache et commencer
- L'utilisateur intervient pour : arbitrages, approval issues, decisions irreversibles

### Tests
- `npx vitest run` (JAMAIS `npm test` — bloque en mode watch)
- Build obligatoire apres toute modification TypeScript
- Ne JAMAIS committer du code qui ne passe pas les tests

### Wakeup Cycle Cadence (#2203, mandate user 2026-05-25 — 2h supersede 1h)

**Cadence fleet-wide : 2h via `CronCreate`** (économie tokens, mandate user 2026-05-25 — le cycle 1h de #2203 est superseded). `ScheduleWakeup` est clampé à `[60, 3600]s` → ne PEUT PAS porter un cycle 2h.

```
CronCreate(cron: "41 */2 * * *", prompt: "/executor", recurring: true)
```

- **Pourquoi 2h** : mandate user 2026-05-25 — ralentir la flotte pour économiser les tokens. 1h générait trop de cycles IDLE consommateurs.
- **Session-only**, auto-expire 7j. **Phase 0 vérifie** à chaque cycle que le cron est actif et le réarme si besoin (#2539).
- **Cap 3-IDLE** (#2185) → 3 cycles × 2h = 6h avant AUTO-STOP.
- **Override urgent : `[WAKE-CLAUDE]`** routé `machine:workspace` (début de ligne, dashboard append). Permet réveil immédiat sans attendre le tick 2h.
- **NE PAS varier** l'intervalle selon « charge perçue » — l'auto-régulation se fait via AUTO-STOP + WAKE-CLAUDE, pas via timer adaptatif.
- **NE PAS** ajouter un `ScheduleWakeup` par-dessus — cela réintroduirait le cycle 1h superseded.

### Inactivity Cap (#2185)
- Après **3 cycles consécutifs** sans tâche exécutée (IDLE au sens : aucune investigation/implémentation/validation commencée) → **arrêter la session** (ne PAS appeler `ScheduleWakeup`)
- Poster `[IDLE] AUTO-STOP` sur le dashboard avec le nombre de cycles
- La session sera relancée par le prochain `[WAKE-CLAUDE]` du coordinateur ou par le scheduler (schtask)
- **Pourquoi :** Incident web1 (37.1 MB, 2417 lignes JSONL, 16+ cycles inactifs générant des messages redondants)
- Un cycle où une tâche a été ne serait-ce qu'investigée (code lu, commentaire posté) compte comme actif

### Session Hygiene — Restart Cadence (#2532)
- Une session **interactive** executor accumule ~30 KB/cycle (mesuré 10,3 MB / 7110 msgs sur 4 jours) → ralentissements MCP + risque de timeout
- **Redémarrer la session interactive** après **~25 cycles** OU dès que `conversation_browser(action: "current")` rapporte **> 5 MB**
- Workers **schedulés** (`claude -p`) = process frais par tâche → **non concernés**
- La lecture dashboard est déjà bornée `section: "intercom", intercomLimit: 20` — **ne PAS descendre sous 20** (plancher #2306). Le levier est le restart, pas `intercomLimit`

### PR obligatoire
- Tout changement de code passe par worktree → PR → review → merge
- Reference : `.claude/rules/pr-mandatory.md`

---

## Outils Utilises

- **Read/Write/Edit** : Code et fichiers
- **Bash** : Git, hostname, build, tests
- **roosync_dashboard** : Coordination cross-machine (CANAL PRINCIPAL)
- **roosync_messages** : Messages inter-machines (inbox, send, mark_read, archive)
- **conversation_browser** : Grounding conversationnel SDDD
- **gh** CLI : Issues, PRs, Project #67

---

## Invocation

```bash
# Session executor
/executor
```

---

**Derniere mise a jour :** 2026-06-09
