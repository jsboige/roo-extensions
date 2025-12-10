# Spécification de Déploiement - Cycle 8 : Généralisation RooSync

**Date :** 2025-12-08
**Auteur :** Roo (Architecte)
**Statut :** Brouillon
**Cycle :** 8 (Déploiement & Adoption)

## 1. Objectifs du Cycle 8

Le Cycle 8 vise à déployer le moteur de synchronisation validé lors du Cycle 7 sur l'ensemble de l'écosystème RooSync. L'objectif est de passer d'un mode "test" à un mode "production" où la configuration est gérée de manière centralisée et distribuée.

**Objectifs Clés :**
1.  **Mise à jour universelle :** Tous les agents doivent exécuter la dernière version du code (v2.1.0+).
2.  **Initialisation de la Baseline :** Création d'une "Baseline Maître" à partir des configurations réelles collectées.
3.  **Activation de la Synchronisation :** Passage en mode actif pour la détection et l'application des changements.

## 2. Stratégie de Déploiement

### 2.1. Mise à jour des Agents (Code)

La mise à jour du code se fera via le gestionnaire de version Git.

*   **Méthode :** `git pull origin main` sur chaque machine agent.
*   **Reconstruction :** Recompilation nécessaire des serveurs MCP (`npm run build` dans `mcps/internal/servers/roo-state-manager`).
*   **Redémarrage :** Redémarrage des instances Roo (Reload Window) pour charger les nouveaux MCPs.

### 2.2. Collecte Initiale (Data)

Avant d'imposer une configuration, nous devons connaître l'état réel du parc.

*   **Action :** Chaque agent exécutera `roosync_collect_config`.
*   **Cible :** Modes, Paramètres MCP, Profils.
*   **Destination :** `.shared-state/configs/incoming/{machine_id}/`.

### 2.3. Création de la Baseline Maître (Arbitrage)

L'Orchestrateur (cette machine) sera responsable de la fusion des configurations.

*   **Processus :**
    1.  Analyse des configurations collectées dans `incoming/`.
    2.  Identification des communs et des spécificités.
    3.  Génération du fichier `.shared-state/configs/baseline.json`.
    4.  Validation manuelle (Human-in-the-loop) de la Baseline.

### 2.4. Activation (Switch-over)

Une fois la Baseline publiée, les agents passeront en mode "Sync".

*   **Action :** Exécution de `roosync_compare_config` sur chaque agent.
*   **Résultat attendu :**
    *   Si la config locale == Baseline : Statut "Synced".
    *   Si la config locale != Baseline : Génération de "Pending Decisions".

## 3. Phasage Détaillé

### Phase 1 : Préparation & Mise à jour (J-0)
*   [Orchestrateur] Commit & Push final du code Cycle 7.
*   [Orchestrateur] Envoi d'un message RooSync "UPDATE_REQUIRED" à tous les agents.
*   [Agents] Pull, Build, Restart.

### Phase 2 : Collecte Distribuée (J+1)
*   [Agents] Exécution de `roosync_collect_config`.
*   [Agents] Publication des packages de configuration.
*   [Orchestrateur] Monitoring de la réception des packages.

### Phase 3 : Consolidation & Baseline (J+2)
*   [Orchestrateur] Analyse des différences inter-agents.
*   [Orchestrateur] Création de la Baseline v1.0.0.
*   [Orchestrateur] Publication de la Baseline.

### Phase 4 : Activation & Monitoring (J+3)
*   [Agents] Première synchronisation descendante (`roosync_compare_config`).
*   [Agents] Application des mises à jour non-conflictuelles.
*   [Orchestrateur] Surveillance des taux d'erreur et des conflits.

## 4. Gestion des Risques & Rollback

| Risque | Impact | Mitigation | Plan de Rollback |
| :--- | :--- | :--- | :--- |
| **Échec du Build MCP** | Agent hors ligne | Tests unitaires stricts avant push. | `git checkout tags/v2.0.0` |
| **Corruption Config** | Perte de paramètres | Backup automatique avant toute écriture (`.backup/`). | Restauration depuis backup local. |
| **Conflit Majeur** | Blocage sync | Mode "Manual Resolution" par défaut. | Désactivation temporaire de la sync auto. |

## 5. Critères de Succès

*   100% des agents en version v2.1.0+.
*   Baseline générée et validée.
*   Au moins une synchronisation réussie par agent.
*   Aucune perte de données de configuration critique.

---
*Fin de la Spécification*