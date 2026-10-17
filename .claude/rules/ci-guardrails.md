# Garde-Fous CI - Prevention des Regressions

**Version:** 3.1.0 (gates racine #3685 — phase 3 livrable 1 Epic #3111)
**MAJ:** 2026-10-17

---

## Regle Absolue

**AVANT de pousser dans `mcps/internal`, VALIDER build + tests CI.**
**TOUT push (racine incluse) passe les gates CI secret-scan + doc-tree-drift (§ Gates racine).**

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
| `vitest.config.ci.ts` | CI (exclut 8 fichiers de tests déclarés — recensement courant : `mcps/internal/servers/roo-state-manager/docs/CI-EXCLUSIONS-CENSUS.md`) |

Nouveaux tests : verifier avec `--config vitest.config.ci.ts`.

### Gates racine (#3685, 16/09 — adaptes de CoursIA)

Le depot racine porte ses propres gates, independantes du submodule :

| Gate | Surface | Declenchement |
|------|---------|---------------|
| **Secret scan gitleaks** | `.github/workflows/secret-scan.yml` | Chaque push `main` + PR — binaire epingle `GITLEAKS_VERSION` + SHA256, config `.gitleaks.toml` a la racine |
| **Pre-commit local (opt-in)** | `.pre-commit-config.yaml` | `pip install pre-commit && pre-commit install` — MEME hook gitleaks, meme `rev` |
| **Doc-tree drift** | `scripts/docs/scan-doc-tree-drift.ps1` + suite Pester | Garde CLAUDE.md (decomptes #3321, liens, chemins backtick) + **parite gitleaks** ; cron CI quotidien sur main (fixtures qui pourrent sans push) |

Ce que l'agent doit savoir :

- **Le point d'application = la CI.** Le pre-commit local est opt-in par machine (Python requis) — son ABSENCE locale ne signifie aucune absence de gate : secret-scan tourne sur le push.
- **Un secret-scan CI rouge est un vrai finding** (generic-api-key, entropy), pas un flake → incident `security.md`, jamais un `--no-verify`.
- **JAMAIS bumper `GITLEAKS_VERSION` seul** : 3 surfaces a re-pingler ensemble (version workflow + SHA256 depuis `gitleaks_<v>_checksums.txt` + `rev` du pre-commit) — la parite est assertee mecaniquement par le drift-scan.
- **Toucher `CLAUDE.md`** → le drift-scan le garde : lancer `scripts/testing/unit/doc-tree-drift-scan.Tests.ps1` localement avant le push.
- Inventaire complet des gates et lessons CoursIA : `docs/harness/reports/coursia-gates-inventory-2026-09-16.md`.

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
