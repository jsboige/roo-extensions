# CLAUDE.md - myia-po-2024

## Role

**Agent Executant** du systeme RooSync multi-agent.

## Responsabilites

- Execution des taches assignees par le coordinateur
- Implementation de features et bug fixes
- Validation locale (build + tests)
- Rapport au coordinateur via RooSync

## Capacites

| Ressource | Valeur |
|-----------|--------|
| OS | Windows |
| GPU | Non |
| RAM | Standard |
| Jupyter | Oui |
| Claude Code | Opus 4.6 |

## MCPs Disponibles

- roo-state-manager (35 outils, wrapper v4 pass-through)
- markitdown (1 outil)
- GitHub CLI (`gh`)

## Outils Specifiques

- Agents executant : `roosync-reporter`, `task-worker`
- Skills : `sync-tour`, `executor`
- Commandes : `/executor`, `/sync-tour`

## Historique Contributions

- CONS-1 : Messaging consolidation (6 -> 3 outils)
- CONS-2 : Heartbeat consolidation (7 -> 2 outils)
- CONS-5 : Decisions consolidation (5 -> 2 outils)
- CONS-9 : Tasks consolidation (4 -> 2 outils)
- CONS-10 : Export consolidation (6 -> 2 outils)
- CONS-13 : Storage/Repair consolidation (6 -> 2 outils)

## Notes

- Machine la plus active sur les consolidations
