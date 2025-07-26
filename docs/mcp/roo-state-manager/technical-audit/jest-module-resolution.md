# Audit Technique : Résolution des Modules Jest avec NodeNext

## 1. Résumé du Problème

L'exécution des tests E2E pour le MCP `roo-state-manager` (spécifiquement `tests/e2e/semantic-search.test.ts`) échoue systématiquement avec une erreur `Configuration error: Could not locate module...`.

Le problème fondamental réside dans l'incapacité de Jest à résoudre les chemins d'importation non-relatifs (par exemple, `src/services/task-indexer.js`) lorsque le projet TypeScript est configuré avec les options de résolution de module modernes `module: "NodeNext"` et `moduleResolution: "NodeNext"`.

## 2. Analyse de la Configuration

### a. `tsconfig.json`

Le compilateur TypeScript est configuré pour un environnement Node.js moderne, ce qui est la source du conflit.

```json
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "NodeNext",
    "moduleResolution": "NodeNext",
    "baseUrl": ".",
    // ...
  }
}
```

- **`"module": "NodeNext"` et `"moduleResolution": "NodeNext"`**: Ces options imposent des règles strictes sur les imports. Notamment, elles exigent que les chemins d'importation de fichiers incluent l'extension (ex: `.js`), même s'ils sont écrits en TypeScript.
- **`"baseUrl": "."`**: Cette option permet d'utiliser des chemins d'importation absolus depuis la racine du projet (ex: `'src/services/...'`). TypeScript résout ces chemins correctement lors de la compilation.

### b. `jest.config.js`

La configuration de Jest contient une tentative directe de résoudre ce problème.

```javascript
module.exports = {
  preset: 'ts-jest',
  testEnvironment: 'node',
  moduleNameMapper: {
    '^src/(.*)$': '<rootDir>/src/$1',
  },
  // ...
};
```

- **`moduleNameMapper`**: Cette configuration est le mécanisme standard de Jest pour gérer les alias de chemin. L'intention ici est de dire à Jest que tout import commençant par `src/` doit être mappé vers le répertoire physique `<rootDir>/src/`. En théorie, cela devrait résoudre les imports non-relatifs.

### c. `package.json`

L'analyse des dépendances (`jest`, `ts-jest`, `typescript`) montre que les versions utilisées sont récentes et ne sont pas la cause apparente de problèmes de compatibilité.

## 3. Hypothèse sur la Cause Racine

Le problème provient d'un conflit entre le mode de résolution `NodeNext` et le mécanisme `moduleNameMapper` de Jest.

1.  **Exigence de `NodeNext`** : Pour se conformer à la spécification des modules ES dans Node.js, `NodeNext` exige que les `import` incluent les extensions de fichier (par exemple, `... from 'src/services/task-indexer.js'`). Le code source respecte bien cette contrainte.

2.  **Interférence du `moduleNameMapper`** : Le `moduleNameMapper` de Jest est un simple mécanisme de remplacement de chaîne de caractères. Il est appliqué *avant* que le moteur de résolution de modules de Node.js (utilisé par Jest) ne tente de localiser le fichier.

3.  **Le Conflit** : L'hypothèse est que l'interaction entre `ts-jest` (qui doit gérer la transpilation en respectant les règles `NodeNext`) et `moduleNameMapper` est défaillante. La présence de l'extension `.js` dans le chemin d'import (`src/services/task-indexer.js`) pourrait faire en sorte que `moduleNameMapper` ne traite pas le chemin comme prévu, ou que `ts-jest` échoue à le "traduire" correctement pour le runtime de Jest. La chaîne de résolution est rompue : le `mapper` ne fonctionne pas comme attendu car le chemin ne correspond peut-être pas exactement au pattern à cause de la façon dont `ts-jest` le traite dans un contexte `NodeNext`. Jest cherche donc un module littéralement nommé `src/services/task-indexer.js` et ne le trouve pas car il n'est pas dans un emplacement standard (comme `node_modules`).

En résumé, le `moduleNameMapper` n'est pas suffisant pour simuler la résolution de `baseUrl` de TypeScript dans un environnement strict `NodeNext` géré par `ts-jest`.

## 4. Tentatives Précédentes

La principale tentative de correction, documentée dans `jest.config.js`, a été l'utilisation de `moduleNameMapper`. Cette solution, bien que fonctionnelle dans de nombreux projets TypeScript, s'avère inefficace dans ce cas précis à cause des contraintes spécifiques imposées par la résolution de module `NodeNext`.