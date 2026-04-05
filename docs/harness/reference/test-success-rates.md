# Taux de Succès Tests - Claude Code

**Version :** 1.1.0
**Créé :** 2026-03-16
**MAJ :** 2026-03-30 (#827 — vitest output sature le contexte scheduler)
**Issue :** #720

---

## Taux de Succès Attendus

| Machine | Taux attendu | Commande recommandée | Notes |
|---------|-------------|---------------------|-------|
| myia-ai-01 | 99.8% | `npx vitest run` | Machine puissante |
| myia-po-2023/2024/2025/2026 | 99.6% | `npx vitest run` | Quelques tests skipped (platform-dependents) |
| myia-web1 | 99.6% | `npx vitest run --maxWorkers=1` | **TOUJOURS --maxWorkers=1** |

**Référence Roo :** [`.roo/rules/13-test-success-rates.md`](../../.roo/rules/13-test-success-rates.md)

---

## Contexte

Les tests unitaires du projet `roo-extensions` utilisent Vitest. Le taux de succès attendu varie selon la machine en raison de :
- **Tests platform-dependents** : Certains tests dépendent de PowerShell, de chemins Windows, ou de services spécifiques
- **Contraintes ressources** : myia-web1 nécessite `--maxWorkers=1` pour stabilité

---

## Commande de Test

**IMPORTANT :** Toujours utiliser `npx vitest run` au lieu de `npm test`

### Pourquoi ?

`npm test` lance Vitest en mode watch interactif, ce qui :
- Bloque le terminal en attendant des inputs
- Ne se termine jamais automatiquement
- Surveille les changements de fichiers

```bash
# Tests complets (recommandé)
cd mcps/internal/servers/roo-state-manager
npx vitest run

# Tests avec couverture (INTERDIT en scheduler — output trop volumineux)
npx vitest run --coverage

# Tests d'un fichier spécifique
npx vitest run src/tools/roosync/__tests__/manage.test.ts

# Tests avec pattern
npx vitest run --testNamePattern="mark_read"

# Machines contraintes (web1)
npx vitest run --maxWorkers=1

# Si échec persistant sur machines contraintes
npx vitest run --reporter=verbose --no-coverage --maxWorkers=1
```

### Pour les agents schedulés (CRITIQUE — #827)

**L'output brut de `npx vitest run` fait ~600K caractères (~150K tokens).** Cela sature le contexte des agents schedulés et provoque une boucle de condensation infinie.

**TOUJOURS tronquer la sortie dans les commandes scheduler :**
```bash
# CORRECT - seulement les 30 dernières lignes (résumé)
npx vitest run 2>&1 | Select-Object -Last 30

# INTERDIT - output brut sature le contexte
npx vitest run
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

## Intégration avec Autres Règles

Cette règle consolide les commandes de test et les taux de succès (anciennement dans `testing.md`, fusionné ici).

Documents complémentaires :
- [`.claude/rules/ci-guardrails.md`](ci-guardrails.md) — Validation CI avant push

---

**Dernière mise à jour :** 2026-03-30
