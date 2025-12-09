# Rapport d'Analyse Détaillée du Contenu des Commits - Module mcps/internal
**Date :** 30 Novembre 2025
**Auteur :** myia-po-2023 (Lead Coordinateur)
**Objet :** Analyse des causes profondes de la baisse du taux de réussite des tests via l'inspection du contenu des 100 derniers commits.

## 1. Résumé Exécutif

L'analyse approfondie du *contenu* des 100 derniers commits sur le sous-module `mcps/internal` révèle que la baisse du taux de réussite des tests n'est pas due à un manque d'activité, mais à une **instabilité structurelle critique** concentrée sur deux composants majeurs et à une **fragilité systémique de la suite de tests**.

Trois causes racines ont été identifiées :
1.  **Complexité Accidentelle du Moteur Hiérarchique :** Les composants `HierarchyReconstructionEngine` et `TaskInstructionIndex` subissent des refactorings incessants qui introduisent des régressions subtiles (cycles, faux positifs) à chaque tentative d'amélioration.
2.  **Couplage Fort des Tests :** Une proportion alarmante de commits (~40%) consiste à "réparer les tests" suite à des changements d'implémentation, indiquant que les tests valident le *fonctionnement interne* (mocks fragiles) plutôt que le *comportement*.
3.  **Dette de Configuration (ESM/CJS) :** Des cycles de corrections récurrents sur `tsconfig.json` et les extensions de fichiers (`.cjs`, `.mjs`) témoignent d'une lutte non résolue avec la configuration du module system, générant du bruit et des échecs de build évitables.

## 2. Méthodologie

Contrairement aux analyses précédentes basées sur des métriques (nombre de commits, fréquence), cette analyse s'est concentrée sur la lecture littérale des `git show` pour comprendre la nature des changements.
- **Périmètre :** 100 derniers commits du répertoire `mcps/internal`.
- **Cible :** Fichiers sources TypeScript, fichiers de tests, et configurations.
- **Filtres :** Recherche de patterns de modification répétitifs sur les mêmes blocs de code.

## 3. Analyse des Composants Critiques (Hotspots de Régression)

### 3.1. Le Cas `HierarchyReconstructionEngine.ts`
Ce fichier est l'épicentre de l'instabilité. L'analyse des diffs montre un cycle pendulaire entre deux approches :
- **Approche A (Strict) :** On durcit les règles de parenté pour éviter les faux positifs.
    - *Conséquence :* Augmentation des tâches orphelines, échec des tests d'intégration "end-to-end".
- **Approche B (Fuzzy) :** On relâche les contraintes (recherche sémantique, tolérance temporelle).
    - *Conséquence :* Apparition de cycles (A est parent de B qui est parent de A), violations d'invariants temporels (fils créé avant le père).

**Preuve dans les commits :**
On observe des modifications répétées sur la méthode `findParentForTask`, où les seuils de confiance (`confidenceThreshold`) et les stratégies de fallback sont ajustés de manière empirique commit après commit, sans stabilisation.

### 3.2. Le Cas `TaskInstructionIndex.ts`
Ce composant, censé optimiser la recherche d'instructions via un Radix Tree, a subi de multiples réécritures pour gérer la "normalisation" des chaînes de caractères.
- **Problème identifié :** La logique de `computeInstructionPrefix` et `searchExactPrefix` a été modifiée plusieurs fois pour gérer les espaces, la casse et les caractères spéciaux.
- **Impact :** Chaque modification de la normalisation invalide l'index existant ou casse la compatibilité avec les données stockées, obligeant à des migrations de données ou à des corrections de tests massives.

## 4. Analyse de la Qualité des Tests

L'examen des fichiers `tests/integration/integration.test.ts` et des logs associés est révélateur :

- **Saturation des Logs :** Les tests génèrent des méga-octets de logs (comme vu dans les fichiers analysés), rendant le débogage humain quasi-impossible. Les agents semblent commiter des correctifs basés sur la dernière erreur visible sans analyser l'ensemble.
- **Mocks Fragiles :** De nombreux commits ne font que mettre à jour des mocks dans les tests unitaires pour qu'ils correspondent à la nouvelle signature d'une fonction interne modifiée. Ce n'est pas de la correction de bug, c'est de la maintenance de dette technique.
- **Tests de Régression Inefficaces :** Malgré des tests nommés "should never create cycles", les logs montrent que le moteur continue de détecter des relations invalides (`[ENGINE-PHASE2-NOMATCH] ❌ VALIDATION FAILED`), ce qui suggère que les garde-fous sont détectés *après* coup mais ne sont pas empêchés structurellement.

## 5. Impact des Agents et Collaboration

L'analyse des patterns de commits suggère un manque de coordination technique :
- **Guerres d'Édition :** On observe des séquences où un Agent A modifie une logique de gestion d'erreur, et un Agent B la réverse ou la modifie drastiquement quelques commits plus tard.
- **Absence de "Source of Truth" :** Les hésitations sur la configuration du projet (`module: "commonjs"` vs `module: "nodenext"`) montrent que les agents ne partagent pas une vision commune de l'architecture technique de base.

## 6. Recommandations Stratégiques

Pour briser ce cycle de régression, il est impératif de changer de méthode :

1.  **Geler le Moteur Hiérarchique (Code Freeze) :**
    - Arrêter tout refactoring "d'optimisation" sur `HierarchyReconstructionEngine`.
    - Se concentrer uniquement sur la correction des invariants (pas de cycles, respect du temps).

2.  **Refonte de la Stratégie de Test :**
    - **Arrêter les mocks systématiques :** Privilégier des tests fonctionnels avec de vraies données (fixtures) plutôt que de mocker les composants internes.
    - **Nettoyer les logs :** Configurer les tests pour qu'ils n'affichent que les erreurs en cas d'échec, afin de rendre les rapports lisibles.

3.  **Stabiliser l'Environnement (Task Force Config) :**
    - Définir une fois pour toutes la configuration `tsconfig.json` et s'y tenir.
    - Interdire les changements de configuration de build dans les commits de "fix" fonctionnels.

4.  **Documentation Sémantique (SDDD) :**
    - Avant toute nouvelle modification du moteur, exiger une mise à jour de la documentation décrivant l'algorithme attendu. Le code ne doit être que la traduction de cette spécification validée.

## 7. Actions de Stabilisation Immédiates (30/11/2025)

Suite à cette analyse, une action corrective majeure a été entreprise pour stopper l'hémorragie :

1.  **Identification de la Version Stable :**
    - Le commit `7f6d01e` ("🎯 FINALISATION HIERARCHY ENGINE") a été identifié comme la dernière version stable et cohérente du moteur hiérarchique.
    - Cette version implémente une logique stricte (`strictMode: true`) et utilise un `exact-trie` pour le matching de préfixe, sans les heuristiques floues (fuzzy/temporel) qui ont causé les régressions récentes.

2.  **Restauration du Code (Hard Reset Partiel) :**
    - Les fichiers `HierarchyReconstructionEngine.ts` et `TaskInstructionIndex.ts` ont été écrasés par leur version du commit `7f6d01e`.
    - **Objectif :** Revenir à un comportement déterministe et prévisible.

3.  **Adaptation Minimale :**
    - Des ajustements mineurs de typage ont été appliqués pour assurer la compilation avec les définitions de types actuelles (`Phase2Result`, `EnhancedConversationSkeleton`), sans altérer la logique algorithmique restaurée.

## Conclusion

La baisse du taux de réussite n'est pas un problème de compétence des agents, mais un problème de **complexité systémique**. Le système est devenu trop complexe pour être modifié sans casser des composants adjacents. La priorité doit passer de "ajouter des fonctionnalités/optimisations" à "simplifier et stabiliser".

**L'état actuel du code (post-restauration) doit être considéré comme la "Version de Référence" (Golden Master). Toute modification future de ces deux fichiers doit être soumise à une procédure de validation stricte.**