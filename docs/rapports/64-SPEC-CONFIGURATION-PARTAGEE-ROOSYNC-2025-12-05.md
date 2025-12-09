# Spécification Technique : Configuration Partagée RooSync (Cycle 6)

**Date** : 2025-12-05
**Auteur** : Roo Architecte
**Statut** : Draft
**Version** : 1.0.0

## 1. Contexte et Objectifs

RooSync v2.1 dispose d'une architecture *Baseline-Driven* capable de comparer l'inventaire d'une machine avec une référence (`sync-config.ref.json`). Cependant, cette comparaison reste superficielle (métadonnées).

L'objectif du Cycle 6 est d'implémenter une **Configuration Partagée Profonde**, permettant de synchroniser le contenu réel des configurations :
1.  **Modes** : Définitions `.json`, prompts `.md`, configurations spécifiques.
2.  **MCPs** : Fichiers `mcp_settings.json`, configurations de serveurs.
3.  **Profils** : Paramètres utilisateur, thèmes, snippets.

## 2. Architecture de Données

### 2.1 Structure du Stockage Partagé

La configuration partagée sera stockée dans `.shared-state/configs/` avec une structure hiérarchique reflétant l'organisation locale.

```
.shared-state/
└── configs/
    ├── baseline-v2.1/              # Version de référence active
    │   ├── roo-modes/
    │   │   ├── architect.json
    │   │   ├── code.json
    │   │   └── ...
    │   ├── mcp-settings/
    │   │   └── mcp_settings.json
    │   └── profiles/
    │       └── default/
    │           └── settings.json
    └── snapshots/                  # Snapshots des machines (backup avant sync)
        └── myia-ai-01/
            └── 2025-12-05-1400/
```

### 2.2 Format du Manifeste de Configuration

Un fichier `manifest.json` à la racine de chaque version de configuration décrira le contenu.

```json
{
  "version": "2.1.0",
  "timestamp": "2025-12-05T14:00:00Z",
  "author": "myia-ai-01",
  "description": "Mise à jour des prompts Architecte",
  "files": [
    {
      "path": "roo-modes/architect.json",
      "hash": "sha256:...",
      "type": "mode_definition"
    },
    {
      "path": "mcp-settings/mcp_settings.json",
      "hash": "sha256:...",
      "type": "mcp_config"
    }
  ]
}
```

## 3. Nouveaux Outils MCP

### 3.1 `roosync_collect_config`

Collecte la configuration locale et la prépare pour l'envoi vers le stockage partagé.

*   **Input** :
    *   `targets`: Liste des cibles (`modes`, `mcp`, `profiles`).
    *   `dryRun`: Simulation (bool).
*   **Output** :
    *   Rapport de collecte (fichiers trouvés, taille).
    *   Chemin du package temporaire créé.

### 3.2 `roosync_publish_config`

Publie un package de configuration collecté vers le stockage partagé (crée une nouvelle version baseline ou met à jour l'existante).

*   **Input** :
    *   `packagePath`: Chemin du package temporaire.
    *   `version`: Version de la configuration (ex: "2.2.0").
    *   `description`: Description des changements.
*   **Output** :
    *   Confirmation de publication.

### 3.3 `roosync_apply_config`

Applique une configuration partagée sur la machine locale.

*   **Input** :
    *   `version`: Version à appliquer (défaut: latest baseline).
    *   `targets`: Filtre optionnel.
    *   `backup`: Créer un backup local avant application (défaut: true).
*   **Output** :
    *   Rapport d'application (fichiers modifiés, erreurs).

## 4. Workflow SDDD

1.  **Collecte** : L'utilisateur (ou un agent) lance `roosync_collect_config` sur une machine "source".
2.  **Publication** : Après validation, `roosync_publish_config` pousse les fichiers vers `.shared-state/configs/`.
3.  **Détection** : Les autres machines détectent une nouvelle version via `roosync_check_update` (à implémenter dans `BaselineService`).
4.  **Application** : L'utilisateur valide l'application via `roosync_apply_config`.

## 5. Sécurité et Conflits

*   **Backup Systématique** : Aucune écrasement sans backup préalable dans `.shared-state/snapshots/`.
*   **Validation Humaine** : Le processus reste *Human-in-the-loop*. Pas d'application automatique silencieuse.
*   **Atomicité** : L'application d'une configuration doit être atomique (tout ou rien) autant que possible.

## 6. Impact sur l'Existant

*   **BaselineService** : Doit être étendu pour gérer les versions de configuration (pas juste un fichier JSON unique).
*   **InventoryCollector** : Doit inclure les hashs des fichiers de configuration critiques pour la détection de dérive.

---
**Validation** : Ce document sert de référence pour l'implémentation du Cycle 6.