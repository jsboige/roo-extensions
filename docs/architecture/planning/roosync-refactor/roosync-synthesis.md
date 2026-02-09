# Synthèse Complète du Système RooSync (État des Lieux)

Ce document dresse un portrait technique exhaustif du système RooSync, basé sur l'analyse approfondie du code source, des tests et de l'architecture.

## 1. Vue d'Ensemble Architecturale

RooSync est un système de gestion de configuration distribuée conçu pour synchroniser les environnements de développement entre plusieurs machines. Il repose sur un modèle **Singleton** centré sur `RooSyncService`, qui orchestre plusieurs sous-systèmes spécialisés et interagit avec un stockage partagé (Google Drive monté localement).

### 1.1 Architecture des Services

*   **RooSyncService** (`src/services/RooSyncService.ts`) : Point d'entrée unique (Singleton). Il initialise les managers, gère le cache et expose l'API unifiée pour les outils MCP.
*   **InventoryCollector** (`src/services/InventoryCollector.ts`) : Responsable de la collecte des données système (CPU, RAM, Disques, Softwares, Config Roo). Utilise un script PowerShell (`Get-MachineInventory.ps1`) et gère un cache local (TTL 1h) ainsi qu'une persistance JSON.
*   **DiffDetector** (`src/services/DiffDetector.ts`) : Moteur de comparaison sémantique. Il compare une Baseline et un Inventaire Machine, détecte les écarts et attribue une sévérité (CRITICAL, WARNING, INFO).
*   **SyncDecisionManager** (`src/services/roosync/SyncDecisionManager.ts`) : Gère le cycle de vie des décisions (Pending -> Approved -> Applied) et persiste l'état dans `sync-roadmap.md`. Il délègue l'exécution à `PowerShellExecutor`.
*   **ConfigComparator** (`src/services/roosync/ConfigComparator.ts`) : Couche d'abstraction pour la comparaison de configurations, supportant la comparaison "réelle" en chargeant la baseline.

### 1.2 La Dualité du Modèle de Données

Le système souffre d'une dette technique majeure : la coexistence de deux paradigmes de gestion de configuration.

1.  **Le Système "Legacy" (Nominatif)**
    *   **Baseline** : `sync-config.ref.json`.
    *   **Principe** : Une machine "Master" dont la configuration est copiée telle quelle.
    *   **Services** : `BaselineService`.
    *   **Outils** : `roosync_update_baseline`, `roosync_compare_config` (version actuelle).
    *   **Limite** : Couplage fort à une machine spécifique.

2.  **Le Système "Moderne" (Non-Nominatif)**
    *   **Baseline** : `non-nominative-baseline.json` + `configuration-profiles.json`.
    *   **Principe** : Abstraction par **Profils de Configuration** (ex: "Profil CPU High-Perf"). Les machines sont mappées à ces profils via un hash anonymisé.
    *   **Services** : `NonNominativeBaselineService`.
    *   **Outils** : 7 outils spécifiques (`create_non_nominative_baseline`, etc.) et `granular-diff.ts`.
    *   **Avantage** : Flexibilité, anonymisation, découplage machine/config.

### 1.3 Mécanisme de Déploiement

Le déploiement des changements repose sur une chaîne d'exécution :
`roosync_apply_decision` (MCP) -> `SyncDecisionManager` -> `PowerShellExecutor` -> `scripts/sync-manager.ps1` (`Apply-Decisions`).
Les tests d'intégration (`test-deployment-wrappers-dryrun.ts`) valident que ces scripts gèrent correctement les timeouts et le mode DryRun.

## 2. Cartographie des Outils (54 Outils)

L'API MCP expose une surface trop large et redondante :

*   **Outils Essentiels** : `init`, `collect_config`, `compare_config`, `list_diffs`, `approve/reject/apply_decision`.
*   **Outils "Non-Nominatifs" (7)** : `create/map/compare_non_nominative`, `migrate`, `validate`, `export`, `get_state`. *Redondants avec les essentiels.*
*   **Outils Granulaires (3)** : `granular_diff`, `validate_diff`, `export_diff`. *Trop bas niveau pour être exposés.*
*   **Outils de Messagerie (~5)** : `send_message`, `read_inbox`, etc. *Utiles mais hors cœur de métier Sync.*
*   **Outils Legacy/Debug** : `debug_dashboard`, `apply_config_legacy`, etc. *À supprimer.*

## 3. Couverture de Tests

Le système est bien testé, malgré son hétérogénéité :

*   **Tests Unitaires** : Couvrent bien les services (`DiffDetector`, `InventoryCollector`).
*   **Tests Non-Nominatifs** : `non-nominative-baseline.test.ts` et `non-nominative-tools.test.ts` valident toute la logique moderne.
*   **Tests de Sécurité** : `identity-protection-test.ts` valide l'unicité et les conflits.
*   **Tests d'Intégration** : `test-deployment-wrappers-dryrun.ts` valide l'exécution PowerShell.

## 4. Diagnostic

Le système est **fonctionnellement riche et robuste** (backend solide), mais **architecturalement confus** en surface (API MCP éclatée).
La consolidation doit consister à **masquer la complexité** du modèle non-nominatif derrière les outils standards, en faisant de ce modèle le moteur par défaut.