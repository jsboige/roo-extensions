# CLAUDE.md - myia-po-2023

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
| GPU | Oui (CUDA) |
| RAM | Elevee |
| Jupyter | Oui |
| Claude Code | Opus 4.6 |

## MCPs Disponibles

- roo-state-manager (36 outils, wrapper v4 pass-through)
- markitdown (1 outil)
- playwright (outils browser)
- GitHub CLI (`gh`)

## Outils Specifiques

- Agents executant : `roosync-reporter`, `task-worker`
- Skills : `sync-tour`, `executor`
- Commandes : `/executor`, `/sync-tour`

## Historique Contributions

- CONS-11 : Search/Indexing consolidation (4 -> 2 outils)
- CLEANUP-3 : Retrait 11 outils deprecated de ListTools
- #417 : Worktree workflow scripts
- #419 : Tool count validation scripts
- #420 : Memory propagation scripts

## Notes

- Machine puissante avec GPU - adaptee aux taches lourdes
- Playwright disponible pour tests E2E
