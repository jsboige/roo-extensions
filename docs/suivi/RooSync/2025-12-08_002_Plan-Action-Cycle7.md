# Plan d'Action - Cycle 7 : Implémentation Normalisation & Sync

**Date** : 2025-12-08
**Objectif** : Rendre la synchronisation RooSync intelligente et sûre.

## Phase 1 : Normalisation Avancée (Jours 1-2)

### 1.1. Amélioration `ConfigNormalizationService`
*   [ ] **Refactor** : Extraire la logique de détection de chemin dans une classe dédiée `PathNormalizer`.
*   [ ] **Feature** : Support des variables d'environnement étendues (`%APPDATA%`, `%LOCALAPPDATA%`, `$HOME`, `$XDG_CONFIG_HOME`).
*   [ ] **Feature** : Normalisation des chemins relatifs complexes (`./`, `../`).
*   [ ] **Test** : Ajouter des cas de tests pour les chemins mixtes Windows/Linux.

### 1.2. Gestion des Secrets
*   [ ] **Feature** : Implémenter `SecretDetector` pour identifier les clés sensibles (regex, entropie).
*   [ ] **Feature** : Créer un mécanisme de `SecretVault` (interface) pour stocker/récupérer les secrets locaux.
*   [ ] **Test** : Vérifier qu'aucun secret ne fuite dans la sortie normalisée.

## Phase 2 : Moteur de Diff Granulaire (Jours 3-4)

### 2.1. Service de Diff
*   [ ] **Create** : `ConfigDiffService.ts`.
*   [ ] **Algo** : Implémenter la comparaison récursive d'objets JSON.
*   [ ] **Feature** : Détection des types de changements (Add, Modify, Delete).
*   [ ] **Feature** : Gestion des tableaux (comparaison par identité vs position).

### 2.2. Rapport de Diff
*   [ ] **Struct** : Définir l'interface `DiffReport`.
*   [ ] **Feature** : Génération de rapports lisibles (JSON/Markdown).
*   [ ] **Test** : Valider la détection de changements sur des configs réelles.

## Phase 3 : Orchestration & Validation (Jours 5-6)

### 3.1. Intégration `ConfigSharingService`
*   [ ] **Update** : Intégrer `ConfigDiffService` dans le workflow `applyConfig`.
*   [ ] **Workflow** : Collecte -> Normalisation -> Diff -> (Validation) -> Application.

### 3.2. Outils CLI/MCP
*   [ ] **Tool** : `roosync_diff` (Preview des changements).
*   [ ] **Tool** : `roosync_sync` (Application avec validation).

## Phase 4 : Validation Distribuée (Jour 7)

### 4.1. Test E2E
*   [x] **Scenario** : Sync Windows -> Linux (Simulé).
*   [x] **Scenario** : Sync Linux -> Windows (Simulé).
*   [x] **Verify** : Vérifier l'intégrité des chemins et des secrets après sync.

## Livrables
*   Code source mis à jour (`roo-state-manager`).
*   Tests unitaires et d'intégration.
*   Documentation utilisateur mise à jour.