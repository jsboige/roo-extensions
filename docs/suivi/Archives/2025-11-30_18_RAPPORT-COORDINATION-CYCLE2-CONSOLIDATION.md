# Rapport de Coordination : Consolidation Cycle 2 (Tests Unitaires)
**Date :** 30 Novembre 2025
**Statut :** CRITIQUE - PLAN D'ACTION FINAL

## 1. Résumé Exécutif

La campagne de stabilisation des tests unitaires a progressé significativement à travers deux cycles de correction d'infrastructure.

*   **État Initial :** 143 erreurs (principalement dues à des mocks `fs` manquants).
*   **Cycle 1 (Fix Infra `fs`) :** Réduction à 54 erreurs. Succès majeur.
*   **Cycle 2 (Fix Infra `path`) :** Réduction à 43 erreurs. Le mock `path` a résolu les problèmes de résolution de chemin restants.

Il reste **43 erreurs** identifiées et analysées, qui ne sont plus des problèmes d'infrastructure globale mais des problèmes spécifiques à chaque domaine (Logique, Outils, Configuration).

## 2. Ventilation des Erreurs Restantes (43)

L'analyse technique (`mcps/internal/servers/roo-state-manager/analysis-reports/2025-11-30_RAPPORT-CYCLE2-ANALYSE.md`) a permis d'attribuer chaque erreur à un agent spécifique.

### Agent 1 : `myia-po-2024` (Infra/Core) - 8 Erreurs
*   **Responsabilité :** Infrastructure, Mocks Système, Performance.
*   **Points Critiques :**
    *   Module manquant `BaselineService` (bloquant).
    *   Mocks de performance (`performance.now()`).
    *   Tests de diagnostic workspace.

### Agent 2 : `myia-po-2026` (Service/Logique) - 24 Erreurs
*   **Responsabilité :** Logique Métier, Parsing, Hiérarchie.
*   **Points Critiques :**
    *   **Parsing XML (15 erreurs) :** Le service semble inopérant en test. Priorité absolue.
    *   **Hiérarchie :** Problèmes de normalisation et de reconstruction.
    *   **Synthèse E2E :** Modèles LLM incorrects.

### Agent 3 : `myia-ai-01` (Tools État) - 9 Erreurs
*   **Responsabilité :** Outils RooSync (Lecture).
*   **Points Critiques :**
    *   Validation de configuration (`roosync-config`).
    *   Logique de comparaison (`compare-config`).
    *   Calcul de statut (`get-status`).

### Agent 4 : `myia-web1` (Tools Action) - 2 Erreurs
*   **Responsabilité :** Workflows E2E, Actions RooSync.
*   **Points Critiques :**
    *   Mock du Dashboard pour les tests E2E.
    *   Simulation du DryRun.

## 3. Plan d'Action Détaillé

Les agents doivent intervenir en parallèle sur leurs périmètres respectifs.

### Phase 1 : Corrections Prioritaires (Immédiat)

1.  **`myia-po-2026` : Réparation du Parsing XML**
    *   **Cible :** `tests/unit/services/xml-parsing.test.ts`
    *   **Action :** Vérifier l'initialisation du parser XML et ses dépendances. C'est le bloqueur principal.

2.  **`myia-po-2024` : Restauration `BaselineService`**
    *   **Cible :** `tests/unit/services/BaselineService.test.ts`
    *   **Action :** Restaurer le fichier manquant ou corriger l'import.

### Phase 2 : Stabilisation Fonctionnelle

3.  **`myia-ai-01` : Fiabilisation RooSync**
    *   **Cible :** `tests/unit/tools/roosync/*`
    *   **Action :** Corriger la validation de config et la logique de statut.

4.  **`myia-po-2026` : Logique Hiérarchique**
    *   **Cible :** `tests/unit/hierarchy-pipeline.test.ts`
    *   **Action :** Ajuster la normalisation et la résolution.

### Phase 3 : Nettoyage Final

5.  **`myia-web1` & `myia-po-2024` : Tests E2E et Performance**
    *   **Cible :** Tests restants.
    *   **Action :** Ajuster les mocks spécifiques (Dashboard, Performance).

## 4. Consignes de Sécurisation

Avant de lancer les agents :
1.  Le sous-module `mcps/internal` a été mis à jour avec le fix `path` et le rapport d'analyse.
2.  Le dépôt racine a été mis à jour avec ce rapport de coordination.
3.  **Règle d'Or :** Chaque agent doit créer une branche spécifique pour ses corrections (`fix/agent-name/scope`) et ne merger qu'après validation des tests locaux.

---
**Validation :**
Ce plan est validé pour exécution immédiate.