
# 58 - Réparation Tests Unitaires Cycle 5 (Mocking FS)

**Date:** 2025-12-05
**Auteur:** Roo (Code Mode)
**Statut:** ✅ Terminé

## 🎯 Objectif
Stabiliser les tests unitaires du Cycle 5 (`roo-state-manager`) en remplaçant les accès fichiers réels par un mock robuste (`mock-fs`) pour garantir l'isolation et la fiabilité des tests, suite à une demande urgente P0.

## 🛠️ Réalisations Techniques

### 1. Refactoring `BaselineService.test.ts`
*   **Problème :** `copyFileSync` n'était pas intercepté par `mock-fs` car importé via un import nommé (`import { copyFileSync } from 'fs'`).
*   **Solution :** Utilisation d'un mock hybride :
    *   `mock-fs` pour la structure du système de fichiers.
    *   `vi.mock('fs', ...)` explicite pour mocker `copyFileSync` tout en préservant les autres exports via `vi.importActual`.

### 2. Refactoring `read-vscode-logs.test.ts`
*   **Problème :** Le test échouait à trouver les logs mockés.
*   **Cause Racine :** Le module `read-vscode-logs.ts` utilise `import * as fs from 'fs/promises'`. Dans l'environnement Vitest, `mock-fs` (qui patche `process.binding('fs')`) n'interceptait pas correctement les appels via ce module `fs/promises` spécifique, probablement dû à l'ordre de chargement ou à la gestion des modules ESM/CJS par Vitest.
*   **Solution :** Mock explicite de `fs/promises` pour le rediriger vers `fs.promises` (qui est correctement patché par `mock-fs`).
    ```typescript
    vi.mock('fs/promises', async () => {
      const actualFs = await vi.importActual<typeof import('fs')>('fs');
      return {
        ...actualFs.promises,
        default: actualFs.promises,
      };
    });
    ```

## 📊 Résultats
*   **Tests Affectés :** `BaselineService.test.ts`, `read-vscode-logs.test.ts`.
*   **État Final :** ✅ Tous les tests passent (`npm run test:unit:tools`).
*   **Isolation :** Plus aucun fichier réel n'est créé sur le disque pendant les tests.

## 📝 Leçons Apprises (SDDD)
*   **Mocking FS/Promises :** Avec `mock-fs` et Vit