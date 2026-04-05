# Architecture Agents, Skills & Commands

**Version:** 2.0.0 (condensed from audit #556)
**MAJ:** 2026-04-05

## Principe

Deleguer les taches verboses a des subagents. La conversation principale orchestre.

## Subagents

### Projet (`.claude/agents/`)

`github-tracker`, `intercom-handler`, `intercom-compactor`, `sddd-router`, `task-planner`

### Globaux (`~/.claude/agents/`)

`git-sync`, `test-runner`, `code-explorer`

### Coordinateur (ai-01)

`roosync-hub` (recoit rapports, envoie instructions), `dispatch-manager` (assignation taches)

### Executants

`roosync-reporter`, `task-worker`

### Workers (`.claude/agents/workers/`)

`code-fixer`, `consolidation-worker`, `doc-updater`, `test-investigator`, `issue-worker`, `config-auditor`, `codebase-researcher`, `script-runner`, `pr-reviewer`, `issue-triager`, `sync-checker`

## Skills (`.claude/skills/`)

| Skill | Declencheur |
|-------|-------------|
| `sync-tour` | "tour de sync", "faire le point" |
| `validate` | Validation apres modifications |
| `git-sync` | Synchronisation Git |
| `github-status` | Progression Project #67 |
| `redistribute-memory` | "redistribue la memoire" |
| `debrief` | `/debrief` |

## Commands (`.claude/commands/`)

| Commande | Machine | Usage |
|----------|---------|-------|
| `/coordinate` | ai-01 | Coordination multi-agent |
| `/executor` | Autres | Execution multi-iterations |
| `/switch-provider` | Toutes | Basculer Anthropic/z.ai |
| `/debrief` | Toutes | Analyse session |

## Workflow

1. **Debut** : "tour de sync" → sync-tour (9 phases)
2. **Pendant** : Agents s'activent selon contexte
3. **Fin** : `/debrief` + commit
