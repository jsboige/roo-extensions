# Worker Model Defaults — Label-Based Selection

**Version:** 1.0.0
**Issue:** #2236 Sprint 4
**MAJ:** 2026-05-18

---

## Regle

Le worker (`start-claude-worker.ps1`) selectionne le modele Claude via cette chaine de priorite :

| Priorite | Source | Valeur |
|----------|--------|--------|
| 1 | Champ Project "Model" | Deterministe (coordinateur) |
| 2 | Param script `-Model` | Fallback (Task Scheduler) |
| 3 | Labels issue | Heuristique (voir ci-dessous) |
| 4 | Defaut | `sonnet` (conservateur) |

## Heuristique label-based (Priorite 3)

Si aucune source explicite (champ Project, param script), le worker inspecte les labels GitHub :

- **`haiku`** si l'un de ces labels est present : `roo-schedulable`, `simple`, `docs`, `audit`
- **`sonnet`** sinon (defaut conservateur)

### Raison

- `roo-schedulable` / `simple` : taches mechaniques (lint, format, bump)
- `docs` : modifications documentation-only
- `audit` : lecture/investigation sans modification de code

Ces categories sont suffisamment simples pour Haiku. Les autres taches beneficient de Sonnet par defaut pour eviter les echecs silencieux.

## Garde-fous complementaires

- **`Get-EscalatedModel`** : Haiku → Sonnet apres retry echoue (caps a Sonnet, pas Opus)
- **`MinimumModel` guard** : Force Sonnet minimum si le harnais est trop complexe (#747)

---

**Implementation :** `Determine-Model` dans `scripts/scheduling/start-claude-worker.ps1`
