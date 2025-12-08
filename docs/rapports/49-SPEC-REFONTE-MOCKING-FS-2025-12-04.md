# 📐 SPÉCIFICATIONS TECHNIQUES : REFONTE MOCKING FS

**Date** : 2025-12-04
**Cible** : Cycle 5 - Tâche P0
**Contexte** : Les tests unitaires actuels souffrent d'instabilité due à l'utilisation de `vi.mock('fs')` et `vi.mock('fs/promises')` qui interfèrent avec les modules internes de Node.js et les autres librairies.

---

## 1. 🚫 Problème Actuel

*   **Interférences Globales** : `vi.mock('fs')` affecte tout le processus de test, y compris le chargement des modules par Jest/Vitest.
*   **Complexité des Mocks** : Nécessité de mocker manuellement chaque méthode (`readFile`, `writeFile`, `existsSync`, `stat`, etc.) avec des comportements complexes (promesses vs callbacks).
*   **Fragilité** : Les tests cassent souvent lors de mises à jour de dépendances ou de changements mineurs dans l'implémentation qui utilisent une méthode `fs` non mockée.
*   **Symptômes** : 16 fichiers de tests en échec aléatoire ou constant, erreurs "module not found" ou "callback is not a function".

## 2. 🎯 Objectif

Mettre en place une stratégie de test du système de fichiers qui soit :
1.  **Isolée** : Chaque test a son propre système de fichiers virtuel.
2.  **Robuste** : Comportement fidèle à un vrai système de fichiers (chemins, erreurs, permissions).
3.  **Simple** : API facile à utiliser pour setup/teardown.

## 3. 🛠️ Solution Technique Préconisée

### Option A : `memfs` + `unionfs` (Recommandée)
Utilisation de `memfs` pour créer un système de fichiers en mémoire complet.

**Avantages** :
*   Simulation très fidèle de `fs`.
*   Supporte `fs/promises`.
*   Populaire et maintenu.

**Implémentation** :
```typescript
import { fs as memfs } from 'memfs';
import { ufs } from 'unionfs';
import * as realFs from 'fs';

// Setup
ufs.use(realFs).use(memfs);

// Dans les tests
memfs.mkdirSync('/test');
memfs.writeFileSync('/test/file.txt', 'content');
```

### Option B : Injection de Dépendances (Architecture)
Refactoriser les services pour qu'ils acceptent une interface `IFileSystem` au lieu d'importer `fs` directement.

**Avantages** :
*   Découplage total.
*   Facilité de mocker l'interface.

**Inconvénients** :
*   Refactoring lourd de l'existant.

### Décision : Approche Hybride
1.  **Court Terme** : Utiliser `memfs` pour remplacer les `vi.mock('fs')` existants sans tout réécrire.
2.  **Long Terme** : Introduire une abstraction `FileSystemService` pour les nouveaux développements.

## 4. 📝 Plan de Migration

### Phase 1 : POC (Proof of Concept)
*   Cibler un fichier de test problématique (ex: `production-format-extraction.test.ts`).
*   Remplacer `vi.mock` par `memfs`.
*   Valider le fonctionnement.

### Phase 2 : Migration Massive
*   Identifier tous les fichiers utilisant `vi.mock('fs')`.
*   Appliquer le pattern validé en Phase 1.
*   Nettoyer les `jest.setup.js` et `vitest.config.ts` des mocks globaux.

### Phase 3 : Validation
*   Exécuter la suite complète de tests.
*   Vérifier l'absence de régressions.

## 5. ⚠️ Points d'Attention
*   **Chemins Absolus** : `memfs` gère les chemins virtuels, attention aux chemins Windows (`C:\...`) vs Linux.
*   **Modules Tiers** : Si une librairie tierce utilise `fs` en interne, il faudra s'assurer que le mock `memfs` est bien pris en compte (via `vi.mock('fs', () => memfs)` si nécessaire, mais plus propre).

---
*Document de référence pour le Cycle 5*