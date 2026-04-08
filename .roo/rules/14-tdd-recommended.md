# TDD Recommande

**Version:** 2.0.0 (condensed from 1.0.0)
**MAJ:** 2026-04-08

## Principe

TDD est RECOMMANDE mais pas OBLIGATOIRE.

## Quand appliquer

| Situation | TDD ? |
| --------- | ----- |
| Nouveau MCP tool | OUI |
| Fonctionnalite complexe | OUI |
| Bug fix | Optionnel (test de regression) |
| Documentation / refactoring simple | NON |

## Workflow minimal

1. Ecrire le test d'abord (rouge)
2. Implementer le minimum (vert)
3. Refactoriser si necessaire
4. Committer

```bash
cd mcps/internal/servers/roo-state-manager && npx vitest run
```

---
**Historique versions completes :** Git history avant 2026-04-08
