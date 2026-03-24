# Taux de Succès Tests

**Version :** 1.0.0
**Créé :** 2026-03-15
**Issue :** #710

---

## Taux de Succès Attendus

| Machine | Taux attendu | Commande recommandée | Notes |
|---------|-------------|---------------------|-------|
| myia-ai-01 | 99.8% | `npx vitest run --reporter=compact` | Machine puissante |
| myia-po-2023/2024/2025/2026 | 99.6% | `npx vitest run --reporter=compact` | Quelques tests skipped |
| myia-web1 | 99.6% | `npx vitest run --reporter=compact --maxWorkers=1` | **TOUJOURS --maxWorkers=1** |

---

## Commande de Test

**IMPORTANT :** Toujours utiliser `npx vitest run` au lieu de `npm test`

```bash
# Tests complets (recommandé) — TOUJOURS utiliser --reporter=compact
cd mcps/internal/servers/roo-state-manager
npx vitest run --reporter=compact

# Tests avec couverture (INTERDIT en scheduler — output 600KB sature le contexte)
npx vitest run --coverage

# Tests d'un fichier spécifique
npx vitest run --reporter=compact src/tools/roosync/__tests__/manage.test.ts

# Machines contraintes (web1)
npx vitest run --reporter=compact --maxWorkers=1

# En scheduler (via win-cli) — OBLIGATOIRE : tronquer la sortie
# execute_command(shell="powershell", command="npx vitest run --reporter=compact 2>&1 | Select-Object -Last 30")
```

### Commandes à éviter

```bash
# NE PAS utiliser - bloque en mode interactif
npm test
npm run test
npx vitest  # sans "run"

# NE PAS utiliser en scheduler - output 600KB sature le contexte LLM (#827)
npx vitest run              # sans --reporter=compact
npx vitest run --coverage   # output encore plus volumineux
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

**Référence :** [`.claude/rules/test-success-rates.md`](../../.claude/rules/test-success-rates.md)
