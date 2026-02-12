# CLAUDE.md - myia-web1

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
| Jupyter | Non |
| Claude Code | Opus 4.6 |

## MCPs Disponibles

- roo-state-manager (39 outils, wrapper v4 pass-through)
- markitdown (1 outil)
- GitHub CLI (`gh`)

## Outils Specifiques

- Agents executant : `roosync-reporter`, `task-worker`
- Skills : `sync-tour`, `executor`
- Commandes : `/executor`, `/sync-tour`

## Particularites

- Pas de Jupyter (N/A)
- RAM limitee (2 GB) - adapter la charge
- Harmonisation H6 (win-cli) en cours

## Notes

- Machine web - acces reseau potentiellement different
