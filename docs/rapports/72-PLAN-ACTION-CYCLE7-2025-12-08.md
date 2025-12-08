# Plan d'Action - Cycle 7 : Implémentation Normalisation & Synchronisation

**Date** : 2025-12-08
**Auteur** : Roo (Architecte)
**Statut** : Validé
**Référence** : Cycle 7

## Objectif Global
Rendre le système RooSync v2.1 capable de synchroniser des configurations entre environnements hétérogènes de manière fiable, sécurisée et transparente.

## Phase 1 : Fondation de la Normalisation (Jours 1-2)

Cette phase se concentre sur la création du service de normalisation et son intégration dans le flux de collecte.

*   **Tâche 1.1 : Création de `NormalizationService`**
    *   Implémenter la classe `NormalizationService`.
    *   Implémenter les regex de détection/remplacement de chemins (`%USERPROFILE%`, `%ROO_ROOT%`).
    *   Implémenter la détection basique de secrets (clés API).
    *   *Livrable* : `NormalizationService.ts` + Tests unitaires.

*   **Tâche 1.2 : Intégration dans `ConfigSharingService` (Collecte)**
    *   Modifier `collectConfig` pour utiliser `NormalizationService.normalize()`.
    *   Mettre à jour les tests de collecte pour vérifier que les fichiers produits sont bien normalisés.
    *   *Livrable* : `ConfigSharingService.ts` mis à jour.

*   **Tâche 1.3 : Intégration dans `ConfigSharingService` (Application)**
    *   Modifier `applyConfig` pour utiliser `NormalizationService.denormalize()`.
    *   Implémenter la logique de reconstruction des chemins absolus.
    *   *Livrable* : `ConfigSharingService.ts` mis à jour.

## Phase 2 : Moteur de Synchronisation & Diff (Jours 3-4)

Cette phase vise à rendre le `BaselineService` pleinement opérationnel pour l'application des changements.

*   **Tâche 2.1 : Finalisation de `BaselineService`**
    *   Implémenter `applyConfigChanges` pour de vrai (lecture fichier -> patch -> écriture).
    *   Gérer les cas de conflits simples (fichier existant vs nouveau).
    *   *Livrable* : `BaselineService.ts` fonctionnel.

*   **Tâche 2.2 : Amélioration de `GranularDiffDetector`**
    *   Ajouter des règles sémantiques pour ignorer les changements non pertinents (ex: ordre des clés JSON).
    *   Optimiser la détection des déplacements dans les tableaux.
    *   *Livrable* : `GranularDiffDetector.ts` optimisé.

## Phase 3 : Validation & Déploiement (Jour 5)

*   **Tâche 3.1 : Tests End-to-End (Local)**
    *   Simuler deux environnements (dossiers différents) sur la même machine.
    *   Vérifier le cycle complet Collecte -> Sync -> Application.

*   **Tâche 3.2 : Déploiement Pilote**
    *   Déployer sur l'Orchestrateur.
    *   Générer la première "Golden Baseline" normalisée.
    *   Tenter une synchronisation depuis un agent distant (si disponible).

## Risques & Mitigations

| Risque | Impact | Mitigation |
| :--- | :--- | :--- |
| **Corruption de chemins** | Critique (Système inutilisable) | Tests unitaires exhaustifs sur les regex. Backup systématique avant application. |
| **Perte de secrets** | Élevé (Perte de fonctionnalité) | Ne jamais écraser un secret local par un placeholder vide. Logique de merge intelligente. |
| **Conflits de version** | Moyen | Le système de Baseline impose une source de vérité unique pour simplifier. |

## Prochaines Étapes Immédiates

1.  Valider ce plan.
2.  Lancer la Tâche 1.1 (Création `NormalizationService`).