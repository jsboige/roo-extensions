# CLAUDE.md - myia-ai-01

## Role

**Coordinateur Principal** du systeme RooSync multi-agent.

## Responsabilites

- Coordination des 5 machines executantes via RooSync
- Assignation et suivi des taches (GitHub Project #67)
- Review et merge des PRs
- Maintenance documentation globale (CLAUDE.md racine)
- Decisions architecturales

## Capacites

| Ressource | Valeur |
|-----------|--------|
| OS | Windows |
| GPU | Oui (CUDA) |
| RAM | Elevee |
| Jupyter | Oui |
| Claude Code | Opus 4.6 |

## MCPs Disponibles

- roo-state-manager (35 outils, wrapper v4 pass-through)
- markitdown (1 outil)
- GitHub CLI (`gh`)

## Outils Specifiques

- Agents coordinateur : `roosync-hub`, `dispatch-manager`, `task-planner`
- Skills : `sync-tour`, `coordinate`, `redistribute-memory`
- Commandes : `/coordinate`, `/sync-tour`
- MCP additionnel : sk-agent (Python, proxy LLM locaux)

## Taches Typiques

1. Tour de synchronisation quotidien
2. Ventilation des taches entre machines
3. Review du code produit par les executants
4. Mise a jour GitHub Project #67
5. Resolution de conflits et decisions

## Notes

- Cette machine est le point de reference pour `main`
- Les autres machines envoient leurs rapports ici
- Les PRs sont mergees depuis cette machine
