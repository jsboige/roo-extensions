# Plan de Consolidation et de Rationalisation RooSync v2.3

## 1. Analyse de l'État Actuel

Le système RooSync actuel souffre d'une complexité accidentelle due à une transition inachevée entre deux modèles architecturaux :
1.  **Le Modèle "Legacy" (Nominatif)** : Basé sur `sync-config.ref.json`, où la baseline est une copie quasi-exacte d'une "machine maître". Les outils comme `update-baseline` et `compare-config` reposent historiquement sur ce modèle.
2.  **Le Modèle "Moderne" (Non-Nominatif)** : Basé sur `non-nominative-baseline.json`, introduisant des "Profils de Configuration" (ex: "Profil CPU High-Perf", "Profil Roo Dev") et des mappings anonymisés (hash). Ce modèle est géré par 7 outils spécifiques (`create_non_nominative_baseline`, etc.) et le service `NonNominativeBaselineService`.

**Problèmes Identifiés :**
*   **Inflation des Outils** : 54 outils au total, dont 7 outils dédiés exclusivement au modèle non-nominatif, créant une API redondante et confuse.
*   **Double Source de Vérité** : Coexistence de deux systèmes de baseline parallèles (`BaselineService` vs `NonNominativeBaselineService`).
*   **Complexité Utilisateur** : L'utilisateur doit choisir entre les outils "normaux" et les outils "non_nominative".

## 2. Architecture Cible (Consolidée)

L'objectif est d'unifier le système autour du modèle **Non-Nominatif (Profils)** tout en conservant l'interface simple des outils historiques. Le système deviendra "Non-Nominatif par défaut".

### 2.1. Outils Rationalisés (12 Outils Essentiels)

| Outil Consolidé | Rôle & Évolution |
| :--- | :--- |
| **`roosync_init`** | Initialise l'infrastructure. **Évolution** : Initialise la structure de profils et mappings par défaut. |
| **`roosync_get_status`** | Tableau de bord unique. **Évolution** : Affiche l'état des profils, la conformité des machines et les versions. |
| **`roosync_collect_config`** | Remonte la config locale. **Évolution** : Effectue automatiquement le mapping/hashage vers la baseline active. |
| **`roosync_update_baseline`** | Met à jour la référence. **Révolution** : Utilise l'algo d'agrégation de profils (ex-`create_non_nominative`) au lieu de copier une machine. |
| **`roosync_manage_baseline`** | Gestion des versions (Backup/Restore). Remplace `version/restore_baseline`. |
| **`roosync_compare_config`** | Comparaison. **Révolution** : Compare la machine (source) aux profils de la baseline (cible) par défaut. |
| **`roosync_list_diffs`** | Liste les écarts machine vs profils. |
| **`roosync_approve_decision`** | Valide un écart : soit mise à jour du profil (baseline), soit correction machine (deploy). |
| **`roosync_reject_decision`** | Ignore un écart. |
| **`roosync_get_decision_details`** | Détails techniques. |
| **`roosync_apply_decision`** | Exécute l'action validée. |
| **`roosync_apply_config`** | Force l'application des profils sur la machine. |

### 2.2. Services Sous-jacents

*   **`RooSyncService`** : Reste le point d'entrée. Il orchestrera la transition en privilégiant `NonNominativeBaselineService`.
*   **`DiffDetector`** : Sera adapté pour comparer systématiquement un `MachineInventory` vs `ConfigurationProfile` (au lieu de `BaselineConfig`).
*   **`BaselineManager`** : Sera refondu pour unifier la logique de gestion.

## 3. Plan de Transformation

Ce plan sera exécuté en mode Orchestrator.

### Étape 1 : Préparation & Sécurisation (Code Mode)
1.  Créer une suite de tests d'intégration "Legacy vs Modern" pour garantir qu'on ne perd pas de fonctionnalités.
2.  Sauvegarder l'état actuel des configurations de test.

### Étape 2 : Unification des Services (Code Mode)
1.  Modifier `RooSyncService.ts` pour que `compareConfig` utilise `NonNominativeBaselineService` si une baseline moderne existe.
2.  Modifier `RooSyncService.ts` pour que `updateBaseline` propose (ou force) la création de profils.
3.  Adapter `ConfigComparator.ts` pour supporter la comparaison hybride.

### Étape 3 : Migration des Tests (Code Mode)
1.  Migrer les cas de test de `non-nominative-tools.test.ts` vers les tests des outils standard (`compare-config.test.ts`, etc.).
2.  Vérifier que `identity-protection-test.ts` passe toujours avec la nouvelle architecture.

### Étape 4 : Suppression du "Gras" (Code Mode)
1.  Supprimer le fichier `src/tools/non-nominative-baseline-tools.ts`.
2.  Retirer les exports correspondants dans `src/tools/index.ts` et `src/tools/registry.ts`.
3.  Supprimer les outils granulaires exposés inutilement (`granular-diff.ts` -> rendre interne).

### Étape 5 : Validation Finale (Debug Mode)
1.  Exécuter la suite complète de tests.
2.  Valider le scénario "User Story" : Init -> Collect -> Update Baseline (création profils) -> Compare -> Decision.

## 4. Bénéfices Attendus

*   **Clarté** : API MCP réduite de ~75% (complexité apparente).
*   **Robustesse** : Utilisation systématique du modèle de profils (plus flexible et sécurisé).
*   **Maintenance** : Une seule code base de comparaison à maintenir.
*   **Confidentialité** : Anonymisation native "by design".