---
name: executor
description: Lance une session d'execution multi-agent RooSync pour les machines executantes (myia-po-* et myia-web1). Phrase declencheur : "/executor", "mode executor", "lance executor".
metadata:
  author: "Roo Extensions Team"
  version: "3.0.0"
  compatibility:
    surfaces: ["claude-code"]
    restrictions: "Requiert acces aux MCPs roo-state-manager"
---

# Skill: Executor - Session d'Execution RooSync

**Version:** 3.0.0
**Cree:** 2026-03-28
**MAJ:** 2026-04-04 (retrait executor-state.json, alignement #745 Phase 2)
**Usage:** `/executor`
**Methodologie:** SDDD triple grounding (voir `.claude/docs/sddd-conversational-grounding.md`)

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

Si un outil critique manque : signaler via dashboard workspace `[CRITICAL]` et STOP.

**Reference :** `.claude/rules/tool-availability.md`

---

### Phase 1 : Collecte + Grounding SDDD (5 min max)

Executer en parallele quand possible :

1. **RooSync inbox (OBLIGATOIRE, EN PREMIER)** : `roosync_read(mode: "inbox", status: "unread")`
2. **Dashboard workspace** : `roosync_dashboard(action: "read", type: "workspace", section: "intercom", intercomLimit: 20)`
3. **GitHub Issues ouvertes** : `gh issue list --repo jsboige/roo-extensions --state open --limit 15`
4. **Git state** : `git log --oneline -5`

**Resume concis (10 lignes max) :**
```
Machine: {name} | Git: {hash} | MCPs: {OK/KO}
RooSync: {Y non-lus} | Dashboard: {X messages recents}
Issues ouvertes: {Z} | Taches assignees: {liste courte}
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

**Si AUCUNE tache disponible** : Envoyer un message RooSync au coordinateur demandant du travail.

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
```

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

**Derniere mise a jour :** 2026-04-04
