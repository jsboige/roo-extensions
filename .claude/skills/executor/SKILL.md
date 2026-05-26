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
  version: "3.2.1"
  compatibility:
    surfaces: ["claude-code"]
    restrictions: "Requiert acces aux MCPs roo-state-manager"
---

# Skill: Executor - Session d'Execution RooSync

**Version:** 3.2.2
**Cree:** 2026-03-28
**MAJ:** 2026-05-26 (#2337 extend pre-flight guard to Roo transport timeout)
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

1. MCP roo-state-manager disponible (34 outils) → Si absent, STOP & REPAIR
2. `git fetch origin && git pull origin main`
3. Verifier submodule mcps/internal a jour
4. **Win-cli timeout guard** (anti-régression #2333) :
   - Lire `~/.win-cli-mcp/config.json` → si `commandTimeout < 600`, poster `[WARN]` et corriger
   - Lire `%APPDATA%/Code/User/globalStorage/rooveterinaryinc.roo-cline/settings/mcp_settings.json` → si win-cli `timeout < 600`, poster `[WARN]` et corriger
   - Les deux niveaux sont indépendants (interne vs transport MCP Roo)

Si un outil critique manque : signaler via dashboard workspace `[CRITICAL]` et STOP.

**Reference :** `.claude/rules/tool-availability.md`

---

### Phase 1 : Collecte + Grounding SDDD (5 min max)

Executer en parallele quand possible :

1. **RooSync inbox (OBLIGATOIRE, EN PREMIER)** : `roosync_read(mode: "inbox", status: "unread")`
2. **Dashboard workspace** : `roosync_dashboard(action: "read", type: "workspace", section: "intercom", intercomLimit: 20)`
3. **GitHub Issues ouvertes** : `gh issue list --repo jsboige/roo-extensions --state open --limit 15`
4. **PRs ouvertes (ANTI-DOUBLE-CLAIM)** : `gh pr list --state open --limit 20 --json number,title,headRefName --repo jsboige/roo-extensions`
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
7. Tache de maintenance (build + tests, config-sync)
8. **PR review (fallback #1713)** : Lancer `/pr-review` pour reviser les PRs ouvertes en attente

**ANTI-DOUBLE-CLAIM (OBLIGATOIRE avant chaque tache) :**

Avant de travailler sur une issue, verifier qu'aucune PR ouverte ne la couvre deja :

```bash
gh pr list --state open --search "<issue-number>" --repo jsboige/roo-extensions
```

Si une PR existe deja → **SKIP l'issue** + rapporter `[INFO] Issue #X deja couverte par PR #Y, skip`.

Cross-checker aussi avec les branches wt/ actives : si une branche `wt/*-{issue-keyword}` existe avec une PR ouverte, ne pas dupliquer.

**Si AUCUNE tache disponible (priorites 1-7)** : Lancer le skill `/pr-review` pour contribuer des reviews independantes. Si aucune PR reviewable non plus, envoyer un message RooSync au coordinateur demandant du travail.

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

### Wakeup Cycle Cadence (#2203, mandate user 2026-05-15)

**Intervalle fleet-wide : 1h (3600s) — DEFAULT FERMÉ.**

```
ScheduleWakeup(delaySeconds: 3600, prompt: "/executor", reason: "...")
```

- **Pourquoi 1h** : cycles courts (5-30 min observés cycle 33) + cap 3-IDLE déclenchent AUTO-STOP avant que le coordinateur n'ait le temps de dispatcher du frais → flotte stallée. 1h × 3 = 3h avant AUTO-STOP, fenêtre réaliste.
- **Cap 3-IDLE inchangé** (#2185) mais devient 3h au lieu de 30 min.
- **Override urgent : `[WAKE-CLAUDE]`** routé `machine:workspace` (début de ligne, dashboard append). Permet réveil immédiat sans attendre le tick 1h.
- **NE PAS varier** l'intervalle selon « charge perçue » — l'auto-régulation se fait via AUTO-STOP + WAKE-CLAUDE, pas via timer adaptatif.

### Inactivity Cap (#2185)
- Après **3 cycles consécutifs** sans tâche exécutée (IDLE au sens : aucune investigation/implémentation/validation commencée) → **arrêter la session** (ne PAS appeler `ScheduleWakeup`)
- Poster `[IDLE] AUTO-STOP` sur le dashboard avec le nombre de cycles
- La session sera relancée par le prochain `[WAKE-CLAUDE]` du coordinateur ou par le scheduler (schtask)
- **Pourquoi :** Incident web1 (37.1 MB, 2417 lignes JSONL, 16+ cycles inactifs générant des messages redondants)
- Un cycle où une tâche a été ne serait-ce qu'investigée (code lu, commentaire posté) compte comme actif

### PR obligatoire
- Tout changement de code passe par worktree → PR → review → merge
- Reference : `.claude/rules/pr-mandatory.md`

---

## Outils Utilises

- **Read/Write/Edit** : Code et fichiers
- **Bash** : Git, hostname, build, tests
- **roosync_dashboard** : Coordination cross-machine (CANAL PRINCIPAL)
- **roosync_read/send** : Messages inter-machines
- **conversation_browser** : Grounding conversationnel SDDD
- **gh** CLI : Issues, PRs, Project #67

---

## Invocation

```bash
# Session executor
/executor
```

---

**Derniere mise a jour :** 2026-05-15
