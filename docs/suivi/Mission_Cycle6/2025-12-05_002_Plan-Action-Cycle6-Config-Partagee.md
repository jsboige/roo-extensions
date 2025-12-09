# Plan d'Action Cycle 6 : Configuration Partagée RooSync

**Date** : 2025-12-05
**Objectif** : Implémenter la synchronisation profonde des configurations (Modes, MCPs, Profils).
**Référence** : `docs/rapports/64-SPEC-CONFIGURATION-PARTAGEE-ROOSYNC-2025-12-05.md`

## Phase 1 : Développement MCP (Collecte & Publication)
*Objectif : Permettre à une machine de packager sa configuration et de la publier.*

1.  **Création du Service `ConfigSharingService`** :
    *   Logique de collecte des fichiers (modes, mcp_settings, etc.).
    *   Génération du manifeste `manifest.json`.
    *   Création d'archives (zip ou dossier structuré).
2.  **Implémentation `roosync_collect_config`** :
    *   Outil MCP pour déclencher la collecte.
    *   Paramètres : `targets` (modes, mcp, profiles), `dryRun`.
3.  **Implémentation `roosync_publish_config`** :
    *   Outil MCP pour pousser vers `.shared-state/configs/`.
    *   Gestion du versioning (incrémentation automatique ou manuelle).

## Phase 2 : Validation Locale (Test sur l'Orchestrateur)
*Objectif : Vérifier que la collecte et la publication fonctionnent sans corruption.*

1.  **Test Unitaire** :
    *   Collecter la configuration de la machine actuelle (`myia-ai-01` ou `myia-po-2026`).
    *   Vérifier le contenu du package généré.
2.  **Test d'Intégration** :
    *   Publier une version "test" dans `.shared-state/configs/test-v1/`.
    *   Vérifier l'intégrité des fichiers sur le disque partagé.

## Phase 3 : Déploiement & Collecte Distribuée
*Objectif : Récupérer les configurations des autres agents pour créer une baseline unifiée.*

1.  **Instruction aux Agents** :
    *   Envoyer un message RooSync aux autres machines (`roosync_send_message`).
    *   Demander l'exécution de `roosync_collect_config` et `roosync_publish_config`.
2.  **Consolidation** :
    *   Analyser les configurations reçues.
    *   Créer une "Golden Baseline" (v2.1.0) fusionnant le meilleur de chaque environnement.

## Phase 4 : Analyse Diff & Baseline (Supervision Utilisateur)
*Objectif : Implémenter la détection de dérive et l'application.*

1.  **Mise à jour `BaselineService`** :
    *   Ajouter la vérification de version de configuration partagée.
    *   Comparer le hash des fichiers locaux avec le manifeste distant.
2.  **Implémentation `roosync_apply_config`** :
    *   Logique de backup (`.shared-state/snapshots/`).
    *   Logique d'écrasement sécurisé.
3.  **Interface de Validation** :
    *   Intégrer les diffs de configuration dans `sync-roadmap.md`.

## Planning Estimatif

| Tâche | Durée | Priorité |
|-------|-------|----------|
| Phase 1 (Dev MCP) | 2 jours | Haute |
| Phase 2 (Tests) | 1 jour | Moyenne |
| Phase 3 (Déploiement) | 2 jours | Haute |
| Phase 4 (Diff/Apply) | 3 jours | Moyenne |

**Total** : ~8 jours ouvrés pour une fonctionnalité complète et robuste.