# Taux de Succès Tests

**Version :** 1.0.0
**Créé :** 2026-03-15
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

# Tests avec couverture
npx vitest run --coverage

# Tests d'un fichier spécifique
npx vitest run src/tools/roosync/__tests__/manage.test.ts

# Machines contraintes (web1)
npx vitest run --maxWorkers=1
```

### Commandes à éviter

```bash
# NE PAS utiliser - bloque en mode interactif
npm test
npm run test
npx vitest  # sans "run"
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

**Référence :** [`.claude/rules/testing.md`](../../.claude/rules/testing.md)
