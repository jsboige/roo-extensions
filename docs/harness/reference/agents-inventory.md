# Architecture Agents, Skills & Commands

> **Note relocalisation (2026-05-19)** : Ancien `.claude/rules/agents-architecture.md`. Déplacé hors des rules auto-chargées car descriptif pur (inventaire de ce qui existe) — pas une règle de comportement. Référencé depuis `CLAUDE.md` projet section "Ressources".

**Version:** 2.1.0 (skills et commands recomptés sur l'arbre — 9 et 5 ; 2.0.0 : condensed from audit #556)
**MAJ:** 2026-11-13

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
| `executor` | `/executor`, "mode executor" |
| `memory-inject` | Debut de tache significative (lecons MEMORY.md pertinentes) |
| `pr-review` | `/pr-review`, review de PRs ouvertes quand la lane est idle |

## Commands (`.claude/commands/`)

| Commande | Machine | Usage |
|----------|---------|-------|
| `/coordinate` | ai-01 | Coordination multi-agent |
| `/executor` | Autres | Execution multi-iterations |
| `/switch-provider` | Toutes | Basculer Anthropic/z.ai |
| `/debrief` | Toutes | Analyse session |
| `/team` | Toutes | Pipeline Team (plan → prd → exec → verify → fix) |

## Workflow

1. **Debut** : "tour de sync" → sync-tour (phases 0 a 9)
2. **Pendant** : Agents s'activent selon contexte
3. **Fin** : `/debrief` + commit
