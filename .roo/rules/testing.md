# Règles de Test - Roo Code

## Commande de Test - IMPORTANT

**Toujours utiliser `npx vitest run` au lieu de `npm test`**

### Pourquoi ?

`npm test` lance Vitest en mode watch interactif, ce qui :
- Bloque le terminal en attendant des inputs
- Ne se termine jamais automatiquement
- Surveille les changements de fichiers

### Commandes correctes

```bash
# Tests complets (recommandé)
cd mcps/internal/servers/roo-state-manager
npx vitest run

# Tests avec couverture
npx vitest run --coverage

# Tests d'un fichier spécifique
npx vitest run src/tools/roosync/__tests__/manage.test.ts

# Tests avec pattern
npx vitest run --testNamePattern="mark_read"
```

### Commandes à éviter

```bash
# NE PAS utiliser - bloque en mode interactif
npm test
npm run test
npx vitest  # sans "run"
```

## Localisation des tests

Les tests unitaires sont dans :
- `mcps/internal/servers/roo-state-manager/src/**/__tests__/*.test.ts`

## Validation rapide

Pour une validation rapide, utiliser :
```bash
cd mcps/internal/servers/roo-state-manager && npx vitest run
```
