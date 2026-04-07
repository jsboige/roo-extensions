# Taux de Succès Tests

**Version :** 1.1.0
**Créé :** 2026-03-15
**MAJ :** 2026-03-24 (#827 — vitest output sature le contexte scheduler)
**Issue :** #710

---

## Taux de Succès Attendus

| Machine | Taux attendu | Commande recommandée | Notes |
|---------|-------------|---------------------|-------|
| myia-ai-01 | 99.8% | `npx vitest run` | Machine puissante |
| myia-po-2023/2024/2025/2026 | 99.6% | `npx vitest run` | Quelques tests skipped |
| myia-web1 | 99.6% | `npx vitest run --maxWorkers=1` | **TOUJOURS --maxWorkers=1** |

---

## Commande de Test

**IMPORTANT :** Toujours utiliser `npx vitest run` au lieu de `npm test`

```bash
# Tests complets (recommandé)
cd mcps/internal/servers/roo-state-manager
npx vitest run

# Tests avec couverture (INTERDIT en scheduler — output trop volumineux)
npx vitest run --coverage

# Tests d'un fichier spécifique
npx vitest run src/tools/roosync/__tests__/manage.test.ts

# Machines contraintes (web1)
npx vitest run --maxWorkers=1
```

### Pour les schedulers Roo (CRITIQUE — #827)

**L'output brut de `npx vitest run` fait ~600K caractères (~150K tokens).** Cela sature le contexte GLM (262K tokens) et provoque une boucle de condensation infinie.

**TOUJOURS tronquer la sortie dans les commandes scheduler :**
```powershell
# CORRECT - seulement les 30 dernières lignes (résumé)
execute_command(shell="powershell", command="cd mcps/internal/servers/roo-state-manager; npx vitest run 2>&1 | Select-Object -Last 30")

# INTERDIT - output brut sature le contexte
execute_command(shell="powershell", command="npx vitest run")
```

**Note :** `--reporter=compact` N'EXISTE PAS dans vitest 3.x. Ne pas l'utiliser. La troncature via `Select-Object -Last 30` est la seule solution fiable.

### Commandes à éviter

```bash
# NE PAS utiliser - bloque en mode interactif
npm test
npm run test
npx vitest  # sans "run"

# NE PAS utiliser en scheduler sans truncation (#827)
npx vitest run              # sans '2>&1 | Select-Object -Last 30'
npx vitest run --coverage   # output encore plus volumineux
npx vitest run --reporter=compact  # N'EXISTE PAS — erreur fatale
```

---

## Localisation des Tests

Les tests unitaires sont dans :
```
mcps/internal/servers/roo-state-manager/src/**/__tests__/*.test.ts
```

---

## En Cas d'Échec

1. **Vérifier le submodule** : `cd mcps/internal && git status`
2. **Builder** : `npm run build`
3. **Réessayer** : `npx vitest run`
4. **Si persiste** : Signaler dans INTERCOM avec `[ERROR]`

---

**Référence :** [`docs/harness/reference/test-success-rates.md`](../../docs/harness/reference/test-success-rates.md)
