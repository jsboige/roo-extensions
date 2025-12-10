# 🔄 Plan d'Orchestration Continue - Cycle 5 (SDDD)

**Date :** 2025-12-05
**Auteur :** Roo (Architecte)
**Statut :** 🟢 ACTIF
**Référence Précédente :** `docs/rapports/56-RAPPORT-COORDINATION-PHASE2-2025-12-05.md`

## 1. Changement de Paradigme : Orchestration Continue

L'approche "Mission Finie" est remplacée par une **Orchestration Continue**. Le système n'est pas statique ; il évolue, communique et doit être maintenu en permanence.

**Objectifs Permanents :**
1.  **Synchronisation Active :** Maintenir la cohérence Git et RooSync entre les agents (`myia-ai-01`, `myia-po-2026`, `myia-web-01`).
2.  **Qualité Continue :** Exécution régulière des tests (Unitaires, E2E) pour détecter les régressions.
3.  **Réactivité & Communication :** Traitement rapide des messages entrants dans la `inbox` RooSync et **réponse systématique** à tout message reçu.
4.  **Grounding SDDD :** Documentation en temps réel des actions et de l'état du système.
5.  **Rigueur Git :** "Clean Push" systématique à la fin de chaque boucle.

## 2. Structure des Boucles d'Itération (Loops)

Chaque cycle d'intervention (Loop) suivra ce schéma standardisé :

### 🔁 Standard Loop Protocol

1.  **📥 Sync & Update (Grounding)**
    *   `git pull` : Récupérer les derniers changements.
    *   `roosync_read_inbox` : Vérifier les nouveaux messages.
    *   `roosync_get_status` : Vérifier l'état de la synchronisation.

2.  **🏥 Health Check (Validation)**
    *   Exécution d'un sous-ensemble de tests critiques (ex: `npm test` sur `roo-state-manager`).
    *   Vérification de l'intégrité des fichiers de configuration (`sync-config.json`).

3.  **⚙️ Action (Execution)**
    *   Traitement des demandes issues de la `inbox`.
    *   Maintenance proactive (nettoyage logs, optimisation).
    *   Développement de fonctionnalités (si demandé).

4.  **📤 Reporting & Communication (Closing)**
    *   Mise à jour du journal de bord ou création d'un rapport de boucle.
    *   **Communication Systématique :** Répondre à tous les messages traités ou notifier de l'avancement.
    *   Notification RooSync si nécessaire.

5.  **🧹 Clean Push (Finalization)**
    *   **Vérification :** `git status` pour s'assurer qu'aucun fichier critique n'est oublié.
    *   **Commit :** `git commit -m "Loop X: [Description]"`
    *   **Push Main :** `git push origin main`
    *   **Push Submodule :** Si `mcps/` modifié, push également dans le sous-module.

## 3. Instructions pour Loop 1 (Immédiat)

**Objectif :** Initialiser le mode continu et vérifier l'état post-lancement Phase 2.

1.  **Sync :** Vérifier si `myia-ai-01` ou `myia-po-2026` ont répondu au message de lancement (`msg-20251205T030342-4m2b9v`).
2.  **Health :** Lancer les tests unitaires de `roo-state-manager` pour confirmer la stabilité locale.
3.  **Action :**
    *   Si des messages sont reçus, les analyser et planifier la réponse.
    *   Si aucun message, vérifier la cohérence des inventaires via `roosync_compare_config` (mode diagnostic).
4.  **Report :** Créer `docs/rapports/58-RAPPORT-LOOP1-2025-12-05.md`.

## 4. Planification des Boucles Suivantes (Cycle 5)

### Loop 2 : Validation Tests Production
**Objectif :** S'assurer que l'environnement est prêt pour la production.
1.  **Sync :** Standard Protocol.
2.  **Health :** Exécuter la suite complète de tests (`npm test` global).
3.  **Action :**
    *   Analyser les résultats des tests.
    *   Corriger les éventuels échecs bloquants.
    *   Vérifier les logs de production simulée.
4.  **Report :** Rapport de validation des tests.
5.  **Clean Push.**

### Loop 3 : Consolidation Documentation
**Objectif :** Mettre à jour la documentation pour refléter l'état actuel (SDDD).
1.  **Sync :** Standard Protocol.
2.  **Health :** Vérifier la cohérence des liens dans la documentation.
3.  **Action :**
    *   Mettre à jour le `README.md` principal si nécessaire.
    *   Vérifier que tous les rapports récents sont indexés.
    *   Générer une synthèse intermédiaire si besoin.
4.  **Report :** État de la documentation.
5.  **Clean Push.**

### Loop 4 : Performance Check
**Objectif :** Vérifier que les modifications n'ont pas dégradé les performances.
1.  **Sync :** Standard Protocol.
2.  **Health :** Vérifier l'utilisation CPU/RAM des MCPs.
3.  **Action :**
    *   Lancer un benchmark léger sur `roo-state-manager` (temps de réponse).
    *   Optimiser si des goulots d'étranglement sont détectés.
4.  **Report :** Rapport de performance.
5.  **Clean Push.**

### Loop 5 : Sécurité & Dépendances
**Objectif :** Audit de sécurité et mise à jour des dépendances.
1.  **Sync :** Standard Protocol.
2.  **Health :** `npm audit` sur les modules critiques.
3.  **Action :**
    *   Mettre à jour les dépendances mineures (`npm update`).
    *   Vérifier les permissions des fichiers sensibles.
4.  **Report :** Rapport de sécurité.
5.  **Clean Push.**

### Loop 6 : Synthèse Finale Cycle 5
**Objectif :** Clôturer le Cycle 5 et préparer le Cycle 6.
1.  **Sync :** Standard Protocol.
2.  **Health :** Vérification globale du système ("Green Board").
3.  **Action :**
    *   Compiler tous les rapports des Loops 1 à 5.
    *   Rédiger la Synthèse Finale du Cycle 5.
    *   Définir les objectifs du Cycle 6.
4.  **Report :** `SYNTHESE-CYCLE5-2025-12-05.md`.
5.  **Clean Push.**

## 5. Critères de Validation Continue (SDDD)

Le système est considéré "Sain" si :
*   ✅ `roosync_get_status` retourne `synced`.
*   ✅ Les tests unitaires passent à 100%.
*   ✅ Aucun message critique non lu dans la `inbox` depuis > 1h.
*   ✅ La documentation (SDDD) est à jour avec les dernières actions.