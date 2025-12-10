# Plan d'Action - Cycle 8 : Déploiement Généralisé RooSync

**Date :** 2025-12-08
**Auteur :** Roo (Architecte)
**Statut :** Planifié
**Cycle :** 8 (Déploiement & Adoption)

## 1. Phase 1 : Mise à jour des Agents (Code)
*Objectif : Garantir que tous les agents exécutent la version v2.1.0+.*

*   [x] **Tâche 1.1 :** Commit final et Tag `v2.1.0` sur le dépôt principal.
*   [x] **Tâche 1.2 :** Envoi du message RooSync `UPDATE_REQUIRED` à `myia-po-2024` et autres agents.
*   [x] **Tâche 1.3 :** Vérification de la mise à jour (via logs ou message de confirmation).

## 2. Phase 2 : Collecte Initiale (Data)
*Objectif : Récupérer l'état réel des configurations pour construire la Baseline.*

*   [x] **Tâche 2.1 :** Instruction aux agents pour exécuter `roosync_collect_config`.
*   [x] **Tâche 2.2 :** Surveillance du répertoire `.shared-state/configs/incoming/`.
*   [x] **Tâche 2.3 :** Validation de l'intégrité des packages reçus (format JSON, présence des fichiers clés).

## 3. Phase 3 : Création de la Baseline Maître (Arbitrage)
*Objectif : Fusionner les configurations en une source de vérité unique.*

*   [x] **Tâche 3.1 :** Analyse comparative des configurations reçues (Orchestrateur).
*   [x] **Tâche 3.2 :** Génération du fichier `.shared-state/configs/baseline.json` initial.
*   [x] **Tâche 3.3 :** Validation manuelle de la Baseline (vérification des chemins, des secrets exclus).
*   [x] **Tâche 3.4 :** Publication de la Baseline (`roosync_publish_config` en mode baseline).

## 4. Phase 4 : Activation & Monitoring (J+3)
*Objectif : Activer la synchronisation automatique et surveiller la stabilité.*

*   [ ] **Tâche 4.1 :** Instruction aux agents pour exécuter `roosync_compare_config`.
*   [ ] **Tâche 4.2 :** Collecte des rapports de différence (`roosync_list_diffs`).
*   [ ] **Tâche 4.3 :** Résolution des premiers conflits (si nécessaire).
*   [ ] **Tâche 4.4 :** Validation finale du cycle (Rapport de Clôture).

## 5. Checkpoints de Validation (SDDD)

*   **Checkpoint 1 (Fin Phase 1) :** Tous les agents répondent au ping en version v2.1.0.
*   **Checkpoint 2 (Fin Phase 2) :** Au moins 2 configurations complètes reçues dans `incoming/`.
*   **Checkpoint 3 (Fin Phase 3) :** Fichier `baseline.json` valide et commité.
*   **Checkpoint 4 (Fin Phase 4) :** Rapport de synchronisation positif pour tous les agents.

---
*Fin du Plan d'Action*