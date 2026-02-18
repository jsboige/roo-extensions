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

- roo-state-manager (36 outils, wrapper v4 pass-through)
- desktop-commander (26 outils, remplace win-cli - #468 Phase 3 DONE)
- markitdown (1 outil)
- sk-agent (4 modeles LLM: glm-4.6v, glm-5, zwz-8b, glm-4.7-flash)
- GitHub CLI (`gh`)

## Outils Specifiques

- Agents executant : `roosync-reporter`, `task-worker`
- Skills : `sync-tour`, `executor`
- Commandes : `/executor`, `/sync-tour`

## Particularites

- Pas de Jupyter (N/A)
- RAM limitee (2 GB) - adapter la charge
- Harmonisation H6 (#468 win-cli → DesktopCommanderMCP) COMPLETEE

## Notes

- Machine web - acces reseau potentiellement different
