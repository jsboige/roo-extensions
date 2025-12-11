# Plan de Transformation Architecturale RooSync v2.3 (Final)

## Objectif
Unifier l'API RooSync autour de **12 outils essentiels** en intégrant nativement la logique non-nominative (profils) comme moteur par défaut, et supprimer les 42 outils redondants.

## Phase 1 : Sécurisation (Mode Code)

1.  **Snapshot des Tests** : Exécuter tous les tests (`npm test`) et sauvegarder le rapport.
2.  **Tests de Compatibilité** :
    *   Créer `tests/integration/legacy-compatibility.test.ts` : simule un cycle complet avec les outils actuels (`collect` -> `compare` -> `update`) pour s'assurer que le refactoring ne cassera pas les usages existants.

## Phase 2 : Unification des Services (Mode Code)

1.  **Refactoring de `RooSyncService.ts`** :
    *   Modifier `compareConfig()` pour qu'il détecte automatiquement si une baseline non-nominative est active. Si oui -> déléguer à `NonNominativeBaselineService`. Si non -> utiliser `ConfigComparator` legacy.
    *   Modifier `updateBaseline()` pour supporter une option `mode: 'profile' | 'legacy'` (défaut 'profile'). Si mode 'profile', utiliser la logique d'agrégation de `NonNominativeBaselineService`.

2.  **Refactoring de `ConfigComparator.ts`** :
    *   Lui permettre de comparer un `MachineInventory` non plus seulement avec une `BaselineConfig` (JSON), mais avec un ensemble de `ConfigurationProfile`s actifs.

## Phase 3 : Nettoyage de l'API MCP (Mode Code)

1.  **Suppression des Outils Spécifiques** :
    *   Supprimer `src/tools/non-nominative-baseline-tools.ts`.
    *   Supprimer `src/tools/roosync/granular-diff.ts` (les fonctions deviennent internes).
    *   Supprimer les fichiers correspondants dans `src/tools/index.ts` et `registry.ts`.

2.  **Consolidation des Outils Standard** :
    *   Mettre à jour `src/tools/roosync/compare-config.ts` pour documenter le comportement automatique "Profils".
    *   Mettre à jour `src/tools/roosync/update-baseline.ts` pour inclure les paramètres d'agrégation (provenant de `create_non_nominative_baseline`).

3.  **Nettoyage des Tests** :
    *   Supprimer `non-nominative-tools.test.ts` (car les outils n'existent plus).
    *   S'assurer que `non-nominative-baseline.test.ts` (service) est toujours vert.
    *   Mettre à jour `compare-config.test.ts` pour inclure les cas "profils".

## Phase 4 : Validation Finale (Mode Debug)

1.  **Exécution Complète** : Lancer la suite de tests unitaires et d'intégration.
2.  **User Acceptance Test (Simulé)** :
    *   Initialiser un environnement RooSync vierge.
    *   Collecter une config.
    *   Mettre à jour la baseline (vérifier création de profils).
    *   Modifier un fichier local.
    *   Comparer (vérifier détection via profils).
    *   Valider décision.
    *   Vérifier application.

## 5. Livrable Final

Une version épurée de `roo-state-manager` avec :
*   `src/tools/roosync/` nettoyé (~12 fichiers).
*   Services unifiés (`RooSyncService` intelligent).
*   Tests verts.
*   Documentation utilisateur mise à jour.