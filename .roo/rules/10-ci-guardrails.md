# Garde-Fous CI - Prevention des Regressions

**Version:** 1.0.0
**Cree:** 2026-03-11
**Contexte:** Regressions CI repetees (#626, mock removal 2e6b49a, 31 tests casses)

---

## Regle Absolue

**AVANT de pousser des changements dans le submodule `mcps/internal`, VALIDER que le build et les tests CI passent.**

---

## Validation Obligatoire

### Avant chaque push du submodule

```powershell
# Validation complete (build + tests CI)
powershell -ExecutionPolicy Bypass -File scripts\mcp\validate-before-push.ps1

# OU validation rapide (build seulement, pour changements doc-only)
powershell -ExecutionPolicy Bypass -File scripts\mcp\validate-before-push.ps1 -Quick
```

### Commande alternative (bash)

```bash
cd mcps/internal/servers/roo-state-manager
npm run build && npx vitest run --config vitest.config.ci.ts
```

### Si la validation echoue : NE PAS POUSSER

1. Corriger les erreurs de build ou de tests
2. Re-executer la validation
3. Pousser SEULEMENT quand tout passe

---

## Deux configs Vitest

| Config                | Usage                   | Tests exclus                  |
| --------------------- | ----------------------- | ----------------------------- |
| `vitest.config.ts`    | **Local** (dev)         | Seulement e2e et timeouts     |
| `vitest.config.ci.ts` | **CI** (GitHub Actions) | + 32 tests platform-dependants |

Le CI utilise `vitest.config.ci.ts` qui exclut les tests qui :

- Dependent de PowerShell (6 fichiers)
- Dependent de APPDATA/chemins Windows (4 fichiers)
- Dependent de GDrive (2 fichiers)
- Ont des mocks obsoletes apres refactoring (15 fichiers)
- Ont d'autres dependances plateforme (5 fichiers)

---

## Incidents Ayant Motive Cette Regle

| Date       | Agent    | Probleme                                                    | Impact                           |
| ---------- | -------- | ----------------------------------------------------------- | -------------------------------- |
| 2026-03-10 | po-2024  | Retrait mocks jest.setup.js sans verifier tous les tests    | 31 fichiers casses, CI rouge     |
| 2026-03-09 | po-2025  | Tests integration ajoutes sans CI validation                | Tests referencent methodes inexistantes |
| 2026-03-10 | multiple | Submodule pousse avec CI deja rouge                         | Accumulation de regressions      |

---

## Pour les Agents

### Claude Code

- **TOUJOURS** executer `validate-before-push.ps1` avant `git push` dans le submodule
- Si les tests CI echouent : corriger AVANT de pousser
- Ne JAMAIS pousser en ignorant les tests ("ca passait en local" n'est pas suffisant)

### Roo (scheduler)

- Les modes `-simple` ne poussent PAS dans le submodule
- Les modes `-complex` doivent valider avant push (via win-cli)

---

**Derniere mise a jour:** 2026-03-11
