# 📅 Plan d'Action Cycle 5 : Stabilisation & Ventilation - 2025-12-04

## 1. Contexte et Objectifs
Suite à la clôture du Cycle 4 et à l'analyse des tests (39 échecs), le Cycle 5 se concentre sur la **stabilisation technique critique** de `roo-state-manager`. L'objectif est de rétablir un taux de succès de 100% sur les tests unitaires, d'intégration et E2E.

**État des lieux (Vitest) :**
*   **Total Tests :** 761
*   **Échecs :** 39 (5%)
*   **Points Critiques :** Mocks FS, Moteur Hiérarchique, Tests E2E RooSync/Synthesis.

### 🚀 Contexte de Démarrage (2025-12-05)
*   **Synchronisation Git :** ✅ Effectuée avec succès (voir `54-CHECKPOINT-IMPACT-CYCLE5-2025-12-05.md`).
*   **Tests de Régression :** ✅ 98% de succès (seuls les tests connus en échec persistent).
*   **Statut Global :** **PRÊT POUR VENTILATION**

## 2. Ventilation des Tâches par Agent

### 🔴 Agent 1 : `myia-web1` (Lead Technique & Core)
**Mission :** Sauvetage du Moteur Hiérarchique et des Orphelins.
**Contexte :** Vous avez identifié la situation critique. Vous avez le lead sur le cœur du système.
**Tâches Prioritaires :**
1.  **Réparer `tests/integration/hierarchy-real-data.test.ts`** : Le moteur ne reconstruit aucune relation (0 vs 100 attendus). Vérifier `radix_tree_exact` et les seuils de similarité.
2.  **Réparer `tests/integration/task-tree-integration.test.ts`** : Échecs similaires sur la reconstruction de l'arbre.
3.  **Réparer `tests/integration/orphan-robustness.test.ts`** : Taux de résolution trop bas (25% vs 70%) et performance insuffisante.
4.  **Coordonner** les actions techniques avec les autres agents.

### 🟠 Agent 2 : `myia-ai-01` (Tests Unitaires & Mocks)
**Mission :** Réparation des Fondations (Mocks & Utils).
**Contexte :** Les tests unitaires échouent à cause de mocks incomplets suite aux changements récents.
**Tâches Prioritaires :**
1.  **Réparer `tests/unit/utils/hierarchy-inference.test.ts`** : Ajouter les exports manquants (`mkdtemp`, `rmdir`) au mock `fs/promises`. Utiliser `vi.mock` avec `importOriginal`.
2.  **Réparer `tests/unit/tools/read-vscode-logs.test.ts`** : Erreur `Cannot read properties of undefined (reading 'filter')`. Vérifier l'initialisation du filtre.
3.  **Réparer `tests/unit/utils/bom-handling.test.ts`** : Erreur `charCodeAt` undefined. Vérifier la gestion des buffers/strings.
4.  **Réparer `tests/unit/utils/timestamp-parsing.test.ts`** : Mock `spy` non appelé.

### 🟡 Agent 3 : `myia-po-2026` (E2E & Configuration)
**Mission :** Stabilisation des Scénarios E2E.
**Contexte :** Votre mission Git est terminée. Focus sur les tests de bout en bout qui valident l'intégration globale.
**Tâches Prioritaires :**
1.  **Réparer `tests/e2e/roosync-workflow.test.ts`** : Erreur sur `myia-po-2023` undefined. Vérifier la configuration de test RooSync et les mocks de machines.
2.  **Réparer `tests/e2e/synthesis.e2e.test.ts`** :
    *   Corriger l'assertion modèle : `gpt-5-mini` -> `gpt-4o-mini`.
    *   Corriger l'assertion version : `3.0.0-phase3-error` -> `3.0.0-phase3`.
3.  **Réparer `tests/unit/services/BaselineService.test.ts`** : Erreurs de lecture de fichier baseline (mock `readFile`).

### 🟢 Agent 4 : `myia-po-2024` (Documentation & Support)
**Mission :** Documentation SDDD & Analyse Transverse.
**Contexte :** Assurer que les corrections techniques sont bien documentées et alignées avec le protocole SDDD.
**Tâches Prioritaires :**
1.  **Mettre à jour le SDDD** : Intégrer les constats de `myia-web1` (problèmes d'architecture, seuils).
2.  **Suivi des KPIs** : Mettre à jour le tableau de bord des tests au fur et à mesure des corrections.
3.  **Support** : Aider à l'analyse des logs si un agent bloque.

## 3. Protocole de Communication (RooSync)
*   **Format :** Utiliser les templates de messages RooSync.
*   **Fréquence :** Point d'avancement à chaque étape majeure (Correction Unitaires -> Correction Intégration -> Correction E2E).
*   **Urgence :** Utiliser le flag `URGENT` uniquement pour les blocages bloquant les autres agents.

## 4. Prochaines Étapes (Orchestrateur)
1.  Envoyer les messages RooSync (fait dans la foulée).
2.  Surveiller les PRs/Commits des agents.
3.  Relancer une campagne de tests globale une fois les corrections unitaires annoncées.