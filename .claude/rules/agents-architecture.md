# Architecture Agents, Skills & Commands

Extrait de CLAUDE.md le 2026-02-19. Reference des subagents, skills et commandes disponibles.

---

## Principe : Conversations Legeres

Deleguer les taches verboses a des **subagents**. La conversation principale reste legere et orchestre.

---

## Subagents ([.claude/agents/](.claude/agents/))

### Agents Communs (toutes machines)

| Agent | Description | Outils |
|-------|-------------|--------|
| `git-sync` | Pull/merge conservatif, submodules | Bash, Read, Grep |
| `test-runner` | Build TypeScript + tests unitaires | Bash, Read, Edit |
| `github-tracker` | Suivi GitHub Project #67 | Bash |
| `intercom-handler` | Communication locale Roo | Read |
| `code-explorer` | Exploration codebase | Read, Grep, Glob |

### Agents Coordinateur (myia-ai-01)

| Agent | Description |
|-------|-------------|
| `roosync-hub` | Hub central RooSync : recoit rapports, envoie instructions |
| `dispatch-manager` | Assignation taches aux 6 machines x 2 agents |
| `task-planner` | Analyse avancement, equilibrage charge |

### Agents Executants (autres machines)

| Agent | Description |
|-------|-------------|
| `roosync-reporter` | Envoie rapports au coordinateur |
| `task-worker` | Prend en charge taches assignees |

### Agents Workers Specialises ([.claude/agents/workers/](.claude/agents/workers/))

| Agent | Description |
|-------|-------------|
| `code-fixer` | Investigation et correction de bugs |
| `consolidation-worker` | Execution consolidations CONS-X |
| `doc-updater` | MAJ documentation apres changements |
| `test-investigator` | Investigation tests echoues ou instables |

---

## Skills ([.claude/skills/](.claude/skills/))

| Skill | Description | Declencheur |
|-------|-------------|-------------|
| `sync-tour` | Tour de sync complet en 9 phases | "tour de sync", "faire le point" |
| `validate` | Build TypeScript + tests unitaires | Validation apres modifications |
| `git-sync` | Pull conservatif + resolution conflits | Synchronisation Git |
| `github-status` | Etat Project #67 via `gh` CLI | Progression et incoherences |
| `redistribute-memory` | Audit et redistribution memoire/regles | "redistribue la memoire" |
| `debrief` | Analyse session + capture lecons | `/debrief` |

---

## Commands ([.claude/commands/](.claude/commands/))

| Commande | Machine | Description |
|----------|---------|-------------|
| `/coordinate` | myia-ai-01 | Session de coordination multi-agent |
| `/executor` | Autres | Session d'execution multi-iterations |
| `/switch-provider` | Toutes | Basculer entre Anthropic et z.ai |
| `/debrief` | Toutes | Analyse session et capture lecons |

---

## Workflow Recommande

1. **Debut** : "tour de sync" → active le skill sync-tour (9 phases)
2. **Pendant** : Agents s'activent selon le contexte
3. **Taches specifiques** : Invoquer explicitement l'agent
4. **Fin** : `/debrief` + commit
