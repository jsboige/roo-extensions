# Rapport d'Analyse Archéologique de la Configuration

## 1. Grounding Sémantique et Intentions Initiales

### 1.1 Intentions Historiques
L'analyse des scripts révèle une évolution en trois phases :
1.  **Phase "Scheduler" (Août 2025)** : Tentative d'orchestration centralisée via `roo-config/scheduler/`. Utilisation de chemins absolus en dur (`D:/roo-extensions`).
2.  **Phase "RooSync v1" (Octobre 2025)** : Introduction de la synchronisation via Google Drive (`G:/Mon Drive`) et de la notion de "Shared State".
3.  **Phase "RooSync v2.1" (Actuelle)** : Consolidation, utilisation de variables d'environnement (`ROO_HOME`, `ROOSYNC_SHARED_PATH`), et support multi-machines.

### 1.2 État Actuel vs Intentions
*   **Intention** : Un système unifié et agnostique du chemin d'installation.
*   **Réalité** : Une coexistence de scripts modernes (v2.1) et de vestiges (v1.0, scheduler legacy) qui pointent encore vers des chemins absolus obsolètes.
*   **Dualité** : `RooSync` est devenu le standard, mais `roo-config/scheduler` persiste comme un "fantôme" non migré.

## 2. Cartographie des Incohérences

### 2.1 Chemins Absolus vs Variables d'Environnement
Une recherche regex a révélé de nombreuses références hardcodées problématiques :

| Chemin / Variable | Statut | Problème Identifié |
| :--- | :--- | :--- |
| `D:/roo-extensions` | **CRITIQUE** | Utilisé par défaut dans `sync-manager.ps1` (ligne 21) si `ROO_HOME` n'est pas défini. Présent dans ~40 scripts (tests, scheduler). |
| `G:/Mon Drive/...` | **WARN** | Présent dans `sync-config.ref.json` et plusieurs scripts de migration. Devrait être uniquement dans `.env`. |
| `ROO_HOME` | **OK** | Variable pivot, mais sa définition par défaut pointe vers `D:/` au lieu de `C:/dev` sur la machine actuelle. |
| `ROOSYNC_SHARED_PATH` | **OK** | Bien utilisé dans les scripts récents, mais certaines fallbacks pointent vers des chemins locaux `.shared-state`. |

### 2.2 Scripts Redondants et Obsolètes

#### A. Scripts de Synchronisation
*   **Actif** : `RooSync/sync_roo_environment_v2.1.ps1` (Dernière modif : 02/11/2025)
*   **Obsolète** : `RooSync/archive/sync_roo_environment_v1.0_technical.ps1`
*   **Obsolète** : `RooSync/archive/sync_roo_environment_v1.0_documented.ps1`
*   **Obsolète** : `scripts/archive/migrations/sync_roo_environment.ps1` (Août 2025)

#### B. Module Scheduler (roo-config/scheduler/)
Tout ce dossier semble être une ancienne tentative d'orchestration non maintenue (dernière modif Août 2025) :
*   `roo-config/scheduler/orchestration-engine.ps1`
*   `roo-config/scheduler/deploy-complete-system.ps1`
*   `roo-config/scheduler/config.json` (Note: Ce fichier config définit encore `repository_path: "d:/roo-extensions"`)

## 3. Recommandations pour Harmonisation

### 3.1 Nettoyage Immédiat
1.  **Archiver** tout le dossier `roo-config/scheduler/` vers `archive/scheduler-legacy/` pour éviter la confusion.
2.  **Supprimer** les scripts doublons dans `RooSync/archive/` et `scripts/archive/` s'ils sont confirmés comme inutiles.

### 3.2 Correction des Chemins
1.  **Standardiser `ROO_HOME`** : Modifier `RooSync/src/sync-manager.ps1` pour détecter dynamiquement le chemin du script ou utiliser `C:/dev/roo-extensions` comme défaut plus probable sur cette machine.
2.  **Nettoyer les références D:/** : Faire un replace massif de `D:/roo-extensions` par `${ROO_HOME}` dans tous les scripts non-archivés.

### 3.3 Consolidation de la Configuration
1.  Centraliser la configuration dans `RooSync/.config/sync-config.json` et `.env`.
2.  Supprimer ou migrer les configurations restantes dans `roo-config/scheduler/config.json`.

## 4. Conclusion
L'écosystème est fonctionnel grâce à RooSync v2.1, mais traîne une dette technique importante liée aux tentatives précédentes (Scheduler, v1.0). La présence de chemins hardcodés `D:/` est le risque majeur pour la portabilité et les tests sur de nouvelles machines.

**Action Prioritaire** : Archiver le code mort (`roo-config/scheduler`) et variable-iser les chemins hardcodés.