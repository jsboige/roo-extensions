# Plan d'action pour les tests de `roo-state-manager`

Ce document décrit le plan d'action pour refactoriser et améliorer la suite de tests du MCP `roo-state-manager`.

## Synthèse des bonnes pratiques de test pour les MCPs

L'analyse des MCPs `quickfiles-server` et `jinavigator-server` a permis d'identifier les bonnes pratiques suivantes pour la configuration des tests :

*   **Configuration Jest (`jest.config.js`) :**
    *   Utiliser `ts-jest` pour les projets TypeScript.
    *   Utiliser la configuration ESM `preset: 'ts-jest/presets/default-esm'` pour les modules ES.
    *   Définir `testEnvironment` à `node`.
    *   Configurer `moduleNameMapper` pour résoudre correctement les imports de modules `.js`.
    *   Utiliser un pattern de test clair comme `**/__tests__/**/*.test.js` ou `**/?(*.)+(spec|test).ts`.
    *   Exclure les répertoires `node_modules` et `dist` des recherches de tests.
    *   Activer et configurer la collecte de la couverture de code avec des seuils raisonnables.

*   **Dépendances (`package.json`) :**
    *   Inclure `jest`, `ts-jest`, `@types/jest`, et `typescript` dans les `devDependencies`.
    *   Utiliser des librairies comme `mock-fs` pour mocker les dépendances externes (comme le système de fichiers) et isoler les tests.

*   **Scripts (`package.json`) :**
    *   Un script `test` qui lance simplement `jest`.
    *   Un script `test:coverage` qui exécute `jest --coverage` pour générer les rapports de couverture.

## Plan d'action pour `roo-state-manager`

Le `roo-state-manager` possède déjà une configuration Jest moderne, mais ses scripts et dépendances de test ne sont pas alignés.

1.  **Nettoyage des dépendances :**
    *   **Action :** Supprimer les dépendances suivantes de `devDependencies` dans le fichier `package.json` :
        *   `@types/mocha`
        *   `mocha`
        *   `vscode-test`
        *   `assert`
    *   **Raison :** Ces dépendances sont liées à une ancienne configuration de test basée sur Mocha et ne sont plus nécessaires avec Jest.

2.  **Mise à jour des scripts de test :**
    *   **Action :** Modifier les scripts dans `package.json` comme suit :
        *   `"test": "jest"`
        *   Laisser `"test:coverage": "jest --coverage"` tel quel.
    *   **Raison :** Aligner l'exécution des tests sur la configuration Jest existante, ce qui simplifie la commande de test et assure que la couverture est calculée correctement.

3.  **Création d'un test initial :**
    *   **Action :** Créer un fichier `tests/initial.test.ts` avec un test simple pour valider la nouvelle configuration.
    *   **Exemple de contenu pour `tests/initial.test.ts` :**
        ```typescript
        import { RooStateManager } from '../src/RooStateManager';

        describe('RooStateManager Initialization', () => {
          it('should be instantiable', () => {
            const manager = new RooStateManager();
            expect(manager).toBeInstanceOf(RooStateManager);
          });
        });
        ```
    *   **Raison :** Fournir une validation rapide que l'environnement de test Jest est fonctionnel avant de migrer les tests plus complexes.

4.  **Migration des tests existants :**
    *   **Action :** Migrer progressivement la logique des anciens fichiers de test (par exemple, `test-basic.js`, `test-imports.js`, etc.) vers de nouveaux fichiers de test Jest (`.test.ts`) dans le répertoire `tests/`.
    *   **Raison :** Consolider tous les tests sous le même framework (Jest) pour une meilleure maintenabilité et cohérence.

## Rapport d'incident de test du 2025-07-23

### Contexte

Tentative de test des outils du serveur MCP `roo-state-manager`.

### Problème rencontré

Le serveur MCP ne parvient pas à rester en ligne, ce qui empêche toute interaction avec ses outils. La tentative d'appel à `detect_roo_storage` (et à tout autre outil) résulte systématiquement en une erreur `Error: Not connected` ou `McpError: MCP error -32000: Connection closed`.

### Actions de débogage effectuées

1.  **Analyse du code initial :** Le code source du serveur (`src/index.ts`) a été inspecté. Aucune erreur évidente n'a été trouvée.
2.  **Ajout de logs :** Des logs `console.error` ont été ajoutés au cycle de vie du serveur (initialisation, connexion, traitement des requêtes) pour tracer l'exécution.
3.  **Correction d'erreurs de compilation :**
    *   Correction d'une référence à un fichier `test.ts` inexistant dans `mcps/internal/servers/roo-state-manager/tsconfig.json`.
    *   Correction d'une erreur de casse (`onClose` vs `onclose`) dans `mcps/internal/servers/roo-state-manager/src/index.ts`.
4.  **Analyse des dépendances (`package.json`) :**
    *   La dépendance locale `"jsboige-mcp-servers": "file:../.."` a été identifiée comme une source potentielle de problèmes.
    *   Tentative de mise à jour de `@modelcontextprotocol/sdk` vers `^1.16.1`, mais la version n'existe pas.
5.  **Nettoyage et réinstallation des dépendances :**
    *   La dépendance `jsboige-mcp-servers` a été supprimée du `package.json`.
    *   La version de `@modelcontextprotocol/sdk` a été maintenue à `^1.16.0`.
    *   `npm install` a été exécuté pour mettre à jour les dépendances.
    *   Le projet a été recompilé avec `npm run build`.

### Résultat

Malgré ces actions, le serveur continue de se fermer prématurément. Le problème semble être plus profond, potentiellement lié à l'environnement d'exécution ou à la manière dont l'extension VS Code gère les processus MCP.

### État final

Tous les fichiers modifiés (`index.ts`, `tsconfig.json`, `package.json`) ont été restaurés à leur état d'origine pour assurer la propreté de la base de code.

### Recommandation

Une investigation plus approfondie par un développeur est nécessaire. Il est recommandé de vérifier :
*   Les logs de l'extension VS Code elle-même lors du démarrage du serveur.
*   La compatibilité entre la version de Node.js, la version du SDK MCP et l'environnement global.
*   Le fonctionnement de la dépendance locale `jsboige-mcp-servers`.
