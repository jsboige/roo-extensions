# Rapport de Coordination - Correction des Tests Unitaires (Ventilation Équilibrée)
**Date :** 30 Novembre 2025
**Auteur :** Orchestrateur (Roo)

## 1. Synthèse
*   **Total Erreurs :** 152
*   **Agents Actifs :** 4 (myia-po-2024, myia-ai-01, myia-web1, myia-po-2026)
*   **Statut :** CRITIQUE - Régression majeure sur RooSync et le moteur hiérarchique.

## 2. Ventilation Équilibrée des Tâches

### 🔴 Agent 1 : myia-po-2024 (Gestion des Messages)
**Charge :** ~38 erreurs
**Périmètre :**
*   `amend_message.test.ts` : Correction de l'édition des messages.
*   `archive_message.test.ts` : Réparation de l'archivage (déplacement physique des fichiers).
*   `mark_message_read.test.ts` : Gestion du statut de lecture.
*   `reply_message.test.ts` : Logique de réponse et héritage des threads.
**Priorité :** P0 (Bloquant pour la communication)

### 🟠 Agent 2 : myia-ai-01 (Gestion des Décisions)
**Charge :** ~38 erreurs
**Périmètre :**
*   `apply-decision.test.ts` : Application des changements et mise à jour roadmap.
*   `approve-decision.test.ts` : Workflow d'approbation.
*   `reject-decision.test.ts` : Workflow de rejet avec motif.
*   `rollback-decision.test.ts` : Restauration des états précédents.
**Priorité :** P0 (Bloquant pour la synchronisation)

### 🟡 Agent 3 : myia-web1 (Parsing & Hiérarchie)
**Charge :** ~40 erreurs
**Périmètre :**
*   `xml-parsing.test.ts` : Extraction des patterns, troncature, validation.
*   `hierarchy-reconstruction-engine.test.ts` : Validation temporelle, cycles, logique métier.
**Priorité :** P1 (Majeur pour l'analyse sémantique)

### 🔵 Agent 4 : myia-po-2026 (Config, Statut & Intégration)
**Charge :** ~36 erreurs
**Périmètre :**
*   `compare-config.test.ts` : Comparaison multi-machines.
*   `get-status.test.ts` : Calcul des statistiques globales.
*   `integration.test.ts` : Tests de bout en bout et performance.
**Priorité :** P1 (Majeur pour le monitoring)

## 3. Instructions Communes
1.  **Mocking FS :** Tous les agents doivent vérifier l'initialisation des mocks `fs` dans leurs tests respectifs. L'erreur `File not found: /sync-roadmap.md` est transverse.
2.  **Isolation :** Travaillez sur vos fichiers de tests spécifiques pour éviter les conflits de merge.
3.  **Documentation :** Mettez à jour le SDDD correspondant à vos modules corrigés.