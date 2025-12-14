# Stratégie d'Évolution et de Consolidation RooSync (Cycle 7)

**Date :** 2025-12-14
**Auteur :** Roo Architect
**Statut :** Validé
**Réf :** Tâche 9

## 1. Vision Cible

L'objectif est de transformer RooSync d'une collection de scripts PowerShell disparates en une solution intégrée TypeScript/MCP robuste, capable de gérer le cycle de vie complet de la synchronisation (Configuration, Planification, Déploiement) de manière multi-plateforme et sécurisée.

## 2. Analyse de l'Existant (Gap Analysis)

| Domaine | État Actuel (PowerShell) | État Cible (MCP TypeScript) | Écart (Gap) | Priorité |
| :--- | :--- | :--- | :--- | :--- |
| **Settings** | `deploy-settings.ps1` gère le merge intelligent et la préservation des secrets. | `ConfigSharingService.applyConfig` est vide (`Not implemented`). | **CRITIQUE** : Aucune capacité d'application de config. | 🟥 P0 |
| **Scheduler** | `setup-scheduler.ps1` gère tout (install/uninstall/status) via TaskScheduler. | Inexistant dans le MCP. | **MAJEUR** : Pas d'automatisation native. | 🟧 P1 |
| **Orchestration** | `deploy-complete-system.ps1` coordonne l'ensemble. | `roosync_init` est partiel. | **MOYEN** : Coordination manuelle requise. | 🟨 P2 |
| **Modes** | `deploy-modes-*.ps1` gère la logique complexe des modes. | `collectConfig` supporte les modes, mais l'application est générique. | **MOYEN** : Validation spécifique aux modes manquante. | 🟨 P2 |

## 3. Audit Technique & Inventaire (Tâche 9b)

### 3.1. État des Tests (MCP Roo-State-Manager)

L'audit révèle un socle de tests TypeScript MCP solide et fonctionnel (161 tests passants), mais une fracture fonctionnelle majeure entre l'existant PowerShell (Legacy) et la nouvelle implémentation MCP.

| Catégorie | Fichiers | Tests Total | ✅ Pass | ❌ Fail | ⚠️ Skip | État |
| :--- | :--- | :---: | :---: | :---: | :---: | :--- |
| **Unitaires** | `unit/services/*.test.ts`, `unit/tools/*.test.ts` | 132 | 132 | 0 | 0 | **Excellente couverture** des services internes. |
| **E2E** | `e2e/roosync-workflow.test.ts`, `e2e/roosync-error-handling.test.ts` | 29 | 29 | 0 | 2 | **Workflow validé**. Skipped: timeout edge cases. |
| **Legacy Check** | `roosync/test-*.ts` (DryRun) | - | - | - | - | Scripts de tests "DryRun" présents mais non intégrés à Vitest. |

### 3.2. Analyse Comparative Détaillée (Gap Analysis)

#### A. Gestion de Configuration (`deploy-settings.ps1` vs `ConfigSharingService.ts`)

| Fonctionnalité | Legacy (`deploy-settings.ps1`) | MCP (`ConfigSharingService.ts`) | Écart (Gap) | Criticité |
| :--- | :--- | :--- | :--- | :--- |
| **Application Config** | ✅ Implémenté | ❌ `Not implemented yet` (L143) | **TOTAL** | 🟥 P0 |
| **Backup Préalable** | ✅ `.backup_YYYYMMDD` | ❌ Prévu mais vide | **Manque Sécurité** | 🟥 P0 |
| **Merge Intelligent** | ✅ `Merge-JsonObjects` | ❌ Inexistant | **Risque écrasement secrets** | 🟥 P0 |
| **Détection OS** | ✅ Windows/Mac/Linux | ❌ Non géré (chemins durs ?) | **Portabilité** | 🟧 P1 |

#### B. Planificateur de Tâches (`setup-scheduler.ps1` vs `SchedulerManager`)

| Fonctionnalité | Legacy (`setup-scheduler.ps1`) | MCP (`SchedulerManager` inexistant) | Écart (Gap) | Criticité |
| :--- | :--- | :--- | :--- | :--- |
| **Installation** | ✅ `Register-ScheduledTask` | ❌ Inexistant | **Pas d'auto-install** | 🟧 P1 |
| **Vérification Droits** | ✅ `Test-AdminRights` | ❌ Inexistant | **Gestion droits** | 🟨 P2 |
| **Statut** | ✅ Détail triggers/lastRun | ❌ `roosync_get_status` (partiel) | **Visibilité** | 🟨 P2 |

#### C. Orchestration & Déploiement (`deploy-complete-system.ps1`)

| Fonctionnalité | Legacy (`deploy-complete-system.ps1`) | MCP (`roosync_init`) | Écart (Gap) | Criticité |
| :--- | :--- | :--- | :--- | :--- |
| **Prérequis** | ✅ Git, PS Version, Admin, Net | ❌ Partiel | **Robustesse** | 🟨 P2 |
| **Tests Préliminaires** | ✅ Exécution avant install | ❌ Inexistant | **Qualité** | 🟨 P2 |
| **Validation Post** | ✅ `Verify-Installation` | ❌ Inexistant | **Confiance** | 🟨 P2 |

## 4. Plan de Mise en Œuvre

### 4.1. Phase 1 : Cœur de Synchronisation (Settings & Merge)
**Objectif :** Rendre `roosync_apply_config` fonctionnel et sûr pour `settings.json`.

*   **Module `JsonMerger` (TypeScript)** :
    *   Portage de la logique `Merge-JsonObjects` de PowerShell.
    *   Support de la fusion profonde (Deep Merge).
    *   Gestion des tableaux (Remplacement vs Ajout vs Fusion par ID).
    *   Protection des clés sensibles (via liste noire ou détection heuristique).
*   **Intégration `ConfigSharingService`** :
    *   Implémenter `applyConfig`.
    *   Ajouter la gestion des backups automatiques avant application (`.backup_YYYYMMDD`).
    *   Ajouter le support du flag `dryRun` pour prévisualiser le merge.

### 4.2. Phase 2 : Gestion du Planificateur (Scheduler)
**Objectif :** Permettre la configuration de la synchronisation automatique depuis le MCP.

*   **Service `SchedulerManager`** :
    *   Abstraction des tâches planifiées (Windows Task Scheduler / Linux Cron).
    *   **Approche Hybride** : Le MCP ne pouvant souvent pas élever ses privilèges, il générera des scripts d'installation (`install-hook.ps1` / `install-hook.sh`) et vérifiera leur statut.
*   **Outils MCP** :
    *   `roosync_scheduler_status` : Vérifie si la tâche est active.
    *   `roosync_generate_scheduler_script` : Crée le script d'installation pour l'utilisateur.

### 4.3. Phase 3 : Orchestration & Santé
**Objectif :** Remplacer les scripts de déploiement globaux.

*   **Amélioration `roosync_init`** :
    *   Intégrer les vérifications de `deploy-complete-system.ps1` (Version Git, Version OS, dépendances).
*   **Nouvel outil `roosync_check_health`** :
    *   Diagnostic complet (droits, chemins, connectivité, état du scheduler).

### 4.4. Phase 4 : Nettoyage Legacy
**Objectif :** Supprimer la dette technique.

*   Archivage de `deploy-settings.ps1`, `setup-scheduler.ps1`, `deploy-complete-system.ps1` dans `archive/scripts/legacy-v2`.
*   Mise à jour de la documentation pour référencer uniquement les outils MCP.

## 5. Architecture Technique Cible

```mermaid
graph TD
    User[Utilisateur / Agent] --> MCP[Roo State Manager MCP]

    subgraph "Services MCP"
        ConfigService[ConfigSharingService]
        Scheduler[SchedulerManager]
        Health[HealthCheckService]
    end

    subgraph "Modules Core"
        Merger[JsonMerger (New)]
        Normalizer[ConfigNormalizationService]
        Diff[ConfigDiffService]
    end

    MCP --> roosync_apply_config
    MCP --> roosync_scheduler_status

    roosync_apply_config --> ConfigService
    ConfigService --> Normalizer
    ConfigService --> Merger

    roosync_scheduler_status --> Scheduler
```

## 6. Prochaines Étapes (Tâche 10)

1.  Créer le ticket pour l'implémentation de `JsonMerger` et `ConfigSharingService.applyConfig` (P0).
2.  Créer le ticket pour `SchedulerManager` (P1).
3.  Créer le ticket pour la migration de `Get-MachineInventory.ps1` vers un module TS natif (P1).