# Plan de Migration vers le Stockage Externe RooSync

**Date :** 09/12/2025
**Statut :** Brouillon
**Objectif :** Migrer le stockage des données RooSync du dépôt local vers un dossier partagé externe (Google Drive) et supprimer toutes les références codées en dur.

## 1. Analyse de l'Existant

L'analyse du code a révélé 128 occurrences de chemins codés en dur ou de références à `G:/Mon Drive/...` dans le projet.

### Zones Critiques Identifiées :
*   **Code Source (`mcps/internal/servers/roo-state-manager/src/`)** :
    *   `utils/server-helpers.ts` : Contient un fallback par défaut vers `G:/Mon Drive/...`.
    *   `services/InventoryCollector.ts` : Utilise un fallback codé en dur.
    *   `services/InventoryCollectorWrapper.ts` : Utilise un fallback codé en dur.
    *   `services/ConfigService.ts` : Logique de recherche de chemin complexe avec des fallbacks multiples.
*   **Tests (`tests/`, `mcps/.../tests/`)** :
    *   Nombreux tests unitaires et manuels utilisent des chemins codés en dur pour les mocks ou les configurations de test.
*   **Documentation (`docs/`)** :
    *   La documentation contient de nombreux exemples et instructions avec le chemin `G:/Mon Drive/...`.
*   **Scripts (`scripts/`)** :
    *   Certains scripts PowerShell d'initialisation ou de test utilisent le chemin en dur.

## 2. Stratégie de Refactoring

L'objectif est de centraliser la résolution du chemin dans une seule fonction et de forcer l'utilisation de la variable d'environnement `ROOSYNC_SHARED_PATH`.

### 2.1. Centralisation (`server-helpers.ts`)
Modifier `getSharedStatePath()` pour :
1.  Vérifier `process.env.ROOSYNC_SHARED_PATH`.
2.  Vérifier `process.env.ROOSYNC_SHARED_STATE_PATH` (rétrocompatibilité).
3.  **SUPPRIMER** le fallback par défaut vers `G:/Mon Drive/...`.
4.  Lever une erreur explicite si aucun chemin n'est configuré.

### 2.2. Mise à jour des Consommateurs
Remplacer toutes les utilisations de `process.env.ROOSYNC_SHARED_PATH || '...'` par un appel à `getSharedStatePath()`.
*   `InventoryCollector.ts`
*   `InventoryCollectorWrapper.ts`
*   `ConfigService.ts` (simplifier la logique de recherche)

## 3. Plan de Migration des Données

La migration des données se fera via un script PowerShell robuste.

### 3.1. Script de Migration (`scripts/migrate-roosync-storage.ps1`)
Ce script devra :
1.  Vérifier l'existence du dossier source local (`.shared-state`).
2.  Vérifier l'accessibilité du dossier cible (défini par `ROOSYNC_SHARED_PATH`).
3.  Copier les données (Robocopy ou Copy-Item avec vérification).
4.  Vérifier l'intégrité des données copiées.
5.  Renommer le dossier source (backup) au lieu de le supprimer immédiatement.

### 3.2. Structure Cible
La structure sur le stockage externe sera identique à la structure locale :
```
ROOSYNC_SHARED_PATH/
├── sync-config.json
├── sync-dashboard.json
├── sync-roadmap.md
├── inventories/
├── messages/
├── logs/
└── .baseline-complete/
```

## 4. Plan de Validation

### 4.1. Tests Unitaires
*   Mettre à jour les tests qui dépendent du chemin par défaut.
*   Configurer `process.env.ROOSYNC_SHARED_PATH` dans tous les environnements de test.

### 4.2. Tests d'Intégration
*   Vérifier que le serveur RooSync démarre correctement avec la variable d'environnement configurée.
*   Vérifier que les inventaires sont bien écrits dans le nouveau chemin.

### 4.3. Validation Manuelle
*   Vérifier l'accès aux fichiers via les outils MCP (`roosync_get_status`, etc.).

## 5. Mise à jour de la Documentation

Mettre à jour les guides pour refléter que `ROOSYNC_SHARED_PATH` est **obligatoire** et qu'il n'y a plus de valeur par défaut magique.
*   `README.md` du MCP RooStateManager.
*   Guides d'installation et de configuration.

## 6. Planning d'Exécution

1.  **Phase 1 : Préparation** (Création du script de migration, backup).
2.  **Phase 2 : Refactoring Code** (Modification `server-helpers.ts` et consommateurs).
3.  **Phase 3 : Migration Données** (Exécution du script).
4.  **Phase 4 : Validation** (Tests et vérifications).
5.  **Phase 5 : Nettoyage** (Suppression code mort et documentation obsolète).