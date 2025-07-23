# Plan d'Intégration de l'Environnement pour les Tests E2E des Serveurs MCP

## 1. Contexte

Les tests E2E pour les serveurs MCP, comme `roo-state-manager`, échouent car ils ne s'exécutent pas dans un environnement qui simule correctement celui de l'extension VS Code. La variable d'environnement `ROO_STORAGE_PATH`, qui doit pointer vers le `globalStoragePath` de l'extension, n'est pas définie, ce qui empêche les tests de fonctionner comme prévu.

Ce document propose un plan pour résoudre ce problème en intégrant une gestion de l'environnement au sein de notre suite de tests Jest.

## 2. Analyse de l'Existant

-   **Configuration Jest (`jest.config.js`)** : La configuration actuelle est basée sur `ts-jest` pour les fichiers TypeScript et `ESM`. Elle ne contient aucune configuration pour charger des variables d'environnement globales ou des scripts d'initialisation (`globals` ou `setupFiles` ne sont pas utilisés).
-   **Tests (`tests/index-creation.test.ts`)** : Les tests manipulent `process.env.ROO_STORAGE_PATH` manuellement, ce qui est une approche fragile et non centralisée. Un test confirme même que le code échoue comme attendu lorsque la variable n'est pas définie, ce qui prouve la nécessité d'une solution globale.

## 3. Comparaison des Solutions

Deux approches principales ont été évaluées pour définir la variable `ROO_STORAGE_PATH` avant l'exécution des tests. Pour rendre les tests plus réalistes, la valeur de `ROO_STORAGE_PATH` devrait pointer vers un répertoire temporaire unique pour chaque exécution de test.

### Approche 1 : Fichier `.env` avec `dotenv`

Cette approche consiste à créer un fichier `.env.test` à la racine du projet MCP (`mcps/internal/servers/roo-state-manager`).

-   **Mise en œuvre** :
    1.  Installer `dotenv` : `npm install dotenv --save-dev`
    2.  Créer un fichier `mcps/internal/servers/roo-state-manager/.env.test` avec le contenu suivant :
        ```
        ROO_STORAGE_PATH=./.tmp/test-storage
        ```
    3.  Modifier le script de test dans `package.json` pour pré-charger `dotenv`.

-   **Avantages** :
    -   **Simplicité** : Très facile à mettre en place et à comprendre.
    -   **Découplage** : Sépare clairement la configuration de l'environnement du code de test.
    -   **Standard** : `dotenv` est une pratique courante dans l'écosystème Node.js.

-   **Inconvénients** :
    -   **Chemin Statique** : Le chemin défini dans `.env.test` est statique. Cela peut poser des problèmes si des tests s'exécutent en parallèle.
    -   **Dépendance supplémentaire** : Ajoute une nouvelle dépendance au projet.

### Approche 2 : Script d'Initialisation Jest (`globalSetup`/`globalTeardown`)

Cette approche utilise les options `globalSetup` et `globalTeardown` de Jest pour exécuter des scripts avant et après tous les tests.

-   **Mise en œuvre** :
    1.  Créer un script `globalSetup.ts` qui crée un répertoire temporaire unique et définit `process.env.ROO_STORAGE_PATH`.
    2.  Créer un script `globalTeardown.ts` qui supprime le répertoire temporaire.
    3.  Mettre à jour `jest.config.js` pour pointer vers ces scripts.

-   **Avantages** :
    -   **Dynamique et Isolé** : Crée un répertoire de stockage unique pour chaque suite de tests, garantissant l'isolation.
    -   **Flexibilité** : Permet d'exécuter n'importe quel code pour des configurations complexes.
    -   **Centralisé** : La logique est centralisée dans la configuration de Jest.

-   **Inconvénients** :
    -   **Légèrement plus complexe** : Demande un peu plus de code que l'approche `.env`.

## 4. Recommandation

**L'approche recommandée est la n°2 : utiliser les scripts `globalSetup` et `globalTeardown` de Jest.**

Cette solution est techniquement supérieure car elle garantit l'isolation des tests, un principe fondamental pour des tests E2E robustes et fiables. La flexibilité offerte est un avantage considérable pour la maintenabilité et l'évolutivité de notre suite de tests.

## 5. Plan de Mise en Œuvre Détaillé

1.  **Créer le script `globalSetup.ts`** :
    -   Créer le fichier `mcps/internal/servers/roo-state-manager/tests/config/globalSetup.ts`.
    -   Y ajouter le code suivant :
        ```typescript
        import * as fs from 'fs';
        import * as os from 'os';
        import * as path from 'path';

        export default async function () {
          const storagePath = path.join(os.tmpdir(), `jest-roo-e2e-${process.hrtime().join('-')}`);
          fs.mkdirSync(storagePath, { recursive: true });
          process.env.ROO_STORAGE_PATH = storagePath;
          (global as any).E2E_STORAGE_PATH = storagePath;
        };
        ```

2.  **Créer le script `globalTeardown.ts`** :
    -   Créer le fichier `mcps/internal/servers/roo-state-manager/tests/config/globalTeardown.ts`.
    -   Y ajouter le code suivant :
        ```typescript
        import * as fs from 'fs';

        export default async function () {
          const storagePath = (global as any).E2E_STORAGE_PATH;
          if (storagePath) {
            fs.rmSync(storagePath, { recursive: true, force: true });
          }
        };
        ```

3.  **Mettre à jour la configuration Jest (`jest.config.js`)** :
    -   Modifier `mcps/internal/servers/roo-state-manager/jest.config.js` :
        ```javascript
        export default {
          // ... (contenu existant)
          roots: ['<rootDir>/src', '<rootDir>/tests'],
          globalSetup: '<rootDir>/tests/config/globalSetup.ts',
          globalTeardown: '<rootDir>/tests/config/globalTeardown.ts',
          // ... (contenu existant)
        };
        ```

4.  **Nettoyer les tests existants** :
    -   Supprimer les manipulations manuelles de `process.env.ROO_STORAGE_PATH` dans les fichiers de test.
