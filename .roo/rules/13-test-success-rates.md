# Taux de Succes Tests

**Version:** 2.0.0 (condensed from 1.1.0, aligned with .claude/rules/ci-guardrails.md)
**MAJ:** 2026-04-08

## Taux attendus

| Machine | Taux | Commande |
| ------- | ---- | -------- |
| ai-01 | 99.8% | `npx vitest run` |
| po-2023/24/25/26 | 99.6% | `npx vitest run` |
| web1 | 99.6% | `npx vitest run --maxWorkers=1` |

## Commandes

```bash
# Standard
cd mcps/internal/servers/roo-state-manager && npx vitest run

# Fichier specifique
npx vitest run src/tools/roosync/__tests__/manage.test.ts
```

## CRITIQUE Scheduler (#827)

Output vitest ~600K chars. **TOUJOURS tronquer :**

```powershell
npx vitest run 2>&1 | Select-Object -Last 30
```

`--reporter=compact` N'EXISTE PAS. Seule methode : `Select-Object -Last 30`.

## A eviter

- `npm test` / `npm run test` (bloque en mode interactif)
- `npx vitest` sans `run`
- `--coverage` (output trop volumineux)

---
**Historique versions completes :** Git history avant 2026-04-08
