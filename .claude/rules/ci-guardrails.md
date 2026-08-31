# Garde-Fous CI - Prevention des Regressions

**Version:** 3.0.0 (condensed from 2.0.0)
**MAJ:** 2026-04-05

---

## Regle Absolue

**AVANT de pousser dans `mcps/internal`, VALIDER build + tests CI.**

### Validation

```powershell
# Complete
powershell -ExecutionPolicy Bypass -File scripts\mcp\validate-before-push.ps1

# Rapide (doc-only)
powershell -ExecutionPolicy Bypass -File scripts\mcp\validate-before-push.ps1 -Quick
```

Ou directement :
```bash
cd mcps/internal/servers/roo-state-manager && npm run build && npx vitest run --config vitest.config.ci.ts
```

Raccourci depuis la racine du depot (#3009) :
```bash
npm run test:mcp
```
**NE JAMAIS lancer `npx vitest run` depuis la racine du depot** — un garde `vitest.config.ts` root limite la decouverte aux tests root-level uniquement, et `test:mcp` delegue au sous-repertoire du submodule.

**Si echec :** NE PAS POUSSER. Corriger, revalider, pousser SEULEMENT quand tout passe.

### Deux configs Vitest

| Config | Usage |
|--------|-------|
| `vitest.config.ts` | Local (dev) |
| `vitest.config.ci.ts` | CI (exclut 31 fichiers de tests déclarés — recensement #3322 : `mcps/internal/servers/roo-state-manager/docs/CI-EXCLUSIONS-CENSUS.md`) |

Nouveaux tests : verifier avec `--config vitest.config.ci.ts`.

### Agents

- **Claude :** TOUJOURS valider avant push
- **Roo -simple :** NE PAS pusher. Valider via win-cli, rapporter au dashboard
- **Roo -complex :** Validation complete avec terminal natif
- **Orchestrateurs :** NE PAS toucher au submodule

### Scheduler — Troncation Output (#827)

Sortie Vitest peut atteindre ~600K chars. **OBLIGATOIRE :**
```powershell
npx vitest run 2>&1 | Select-Object -Last 30
```
`--reporter=compact` N'EXISTE PAS. Seule methode : `Select-Object -Last 30`.

---

**Historique versions completes :** Git history avant 2026-04-05
