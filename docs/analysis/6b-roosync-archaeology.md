# 6b - Archéologie RooSync & Analyse de l'Existant

## 1. Contexte et Objectifs

Cette analyse vise à inventorier et classifier l'ensemble des scripts de gestion de configuration existants avant l'adoption complète du MCP `roo-state-manager`. L'objectif est d'identifier ce qui doit être migré, archivé ou supprimé pour assainir la base de code et sécuriser les processus de synchronisation.

## 2. Inventaire et Classification

### 2.1 Scripts Legacy / Obsolètes (À archiver)
Ces scripts ont été remplacés par des fonctionnalités natives du MCP ou des versions plus récentes.

*   **Gestion Git :**
    *   `scripts/git/01-*.ps1` à `scripts/git/12-*.ps1` : Scripts de migration datés d'octobre 2025.
    *   `scripts/git-safe-operations/*.ps1` : Ancienne suite d'opérations git sécurisées.
    *   `scripts/git/sync-round2-auto-A2-*.ps1` : Anciennes routines de synchro.
*   **Maintenance RooSync V1/V2 :**
    *   `RooSync/sync_roo_environment_v2.1.ps1` : Prédécesseur du MCP.
    *   `scripts/archive/migrations/*.ps1` : Scripts de migration explicites.
*   **Encoding Fixes :**
    *   `scripts/encoding/*.ps1` : Nombreux scripts unitaires pour corriger l'UTF-8, probablement consolidés.
*   **Déploiement :**
    *   `scripts/deployment/deploy-modes.ps1` : Obsolète face à la gestion des modes via MCP.

### 2.2 Scripts Fonctionnels (À Migrer/Intégrer)
Ces scripts contiennent une logique métier ou utilitaire qui ne semble pas encore totalement couverte par le MCP actuel.

*   **Monitoring Avancé :**
    *   `scripts/monitoring/dashboard-generator.ps1` : Génération de tableaux de bord (le MCP a `roosync_get_status` mais peut-être moins visuel ?).
    *   `scripts/monitoring/alert-system.ps1` : Système d'alerte proactif.
*   **Inventaire Système :**
    *   `scripts/inventory/Get-MachineInventory.ps1` : Collecte d'infos hardware/software. Essentiel pour `roosync_compare_config`.
*   **Documentation Automatisée :**
    *   `scripts/docs/create-navigation-index-sddd.ps1` : Génération d'index de documentation.
*   **Tests et Validation :**
    *   `scripts/validation/validate-mcp-implementations.js` : Validation structurelle des MCPs.
    *   `scripts/roosync/production-tests/*.ps1` : Suites de tests d'intégration.

### 2.3 Scripts Doublons (À consolider)
*   Versions multiples de scripts de diagnostic (`diagnostic-simple`, `diagnostic-complet`, etc.).
*   Scripts de "fix" ponctuels (`fix-ffmpeg-path.ps1`, `fix-broken-links.ps1`) qui devraient être des outils MCP idempotents.
*   Multiples versions de `roosync_*.ps1` dans `scripts/roosync/` qui semblent être des wrappers autour du code MCP ou des doublons de logic (ex: `roosync_export_baseline.ps1` existe aussi en TS dans le MCP).

## 3. Analyse des Risques : Chemins en Dur ("Hardcoded Paths")

L'analyse par recherche de motifs a révélé plusieurs scripts critiques utilisant des chemins absolus ou fragiles vers Google Drive.

**🚨 Risque Critique : Chemins Absolus Fragiles**
Les scripts suivants utilisent des chemins spécifiques à une machine ou une configuration de raccourci Drive (`.shortcut-targets-by-id`):

1.  `scripts/roosync/PHASE3B-ANALYSE-BASELINE.ps1`
2.  `scripts/roosync/PHASE3A-DIAGNOSTIC-ET-CORRECTIONS.ps1`
3.  `scripts/roosync/PHASE3A-CORRECTIONS-CRITIQUES.ps1`
4.  `scripts/roosync/PHASE3A-APPLICATION-CORRECTIONS-ORIGINALES.ps1`
5.  `scripts/roosync/PHASE3A-ANALYSE-RAPIDE.ps1`

**Motif problématique :** `../../Drive/.shortcut-targets-by-id/1jEQqHabwXrIukTEI1vE05gWsJNYNNFVB/.shared-state/...`
**Impact :** Ces scripts échoueront systématiquement sur toute autre machine ou si le montage Drive change.

**⚠️ Risque Modéré : Valeurs par défaut codées en dur**
D'autres scripts définissent des valeurs par défaut qui peuvent masquer une mauvaise configuration de l'environnement :

1.  `scripts/migrate-roosync-storage.ps1` (propose `G:\Mon Drive\RooSync\.shared-state` en fallback interactif).
2.  `scripts/messaging/07-update-env-messaging.ps1` (Définit `G:/Mon Drive/Synchronisation/RooSync/.shared-state`).

## 4. Gap Analysis (Scripts vs MCP)

| Fonctionnalité | État MCP (`roo-state-manager`) | État Scripts (`scripts/`) | Écart / Action Requise |
| :--- | :--- | :--- | :--- |
| **Synchro Baseline** | ✅ Complet (`roosync_update_baseline`, etc.) | ⚠️ `scripts/roosync/roosync_*.ps1` (wrappers ?) | Vérifier si les scripts PS1 appellent le MCP ou réimplémentent la logique. |
| **Comparaison Config** | ✅ `roosync_compare_config` | ✅ `scripts/inventory/Get-MachineInventory.ps1` | Le MCP utilise probablement ce script ou une logique similaire. À confirmer. |
| **Monitoring/Dash** | ⚠️ Basique (`get_status`) | ✅ Avancé (`dashboard-generator.ps1`) | **Gap :** Le MCP manque de visualisation riche ou de génération de rapport HTML/MD complexe. |
| **Documentation** | ❌ Pas d'outil dédié | ✅ `scripts/docs/*` | **Gap :** Intégrer la génération d'index SDDD dans le MCP. |
| **Maintenance Git** | ❌ Hors scope MCP principal | ✅ `scripts/git/*` | Garder les scripts Git essentiels hors du MCP, ou créer un outil `git_maintenance`. |

## 5. Recommandations Préliminaires

1.  **Nettoyage Immédiat (Phase 1) :**
    *   ✅ **[FAIT]** Déplacer tous les scripts `scripts/git/` datés (octobre 2025) vers `archive/scripts/legacy-git`.
    *   ✅ **[FAIT]** Déplacer les scripts de migration `scripts/archive/migrations` vers `archive/scripts/migrations`.
    *   ✅ **[FAIT]** Archivage de `RooSync/sync_roo_environment_v2.1.ps1` et `scripts/deployment/deploy-modes.ps1` dans `archive/scripts/legacy`.

2.  **Correction des Chemins (Phase 2) :**
    *   Modifier tous les scripts identifiés en section 3 pour utiliser **exclusivement** la variable d'environnement `$env:ROOSYNC_SHARED_PATH`.
    *   Ajouter une validation au début des scripts : si la variable n'est pas définie, échouer proprement avec un message d'erreur explicite.
    *   **Action Prioritaire :** Réécrire `scripts/roosync/PHASE3B-ANALYSE-BASELINE.ps1` et ses pairs pour supprimer les chemins `../../Drive/.shortcut-targets-by-id/...`.

3.  **Migration vers MCP (Phase 3) :**
    *   Porter `scripts/inventory/Get-MachineInventory.ps1` en TypeScript ou l'intégrer comme ressource binaire du MCP pour garantir sa disponibilité.
    *   Analyser `scripts/monitoring/dashboard-generator.ps1` pour voir comment ses fonctionnalités de reporting peuvent enrichir `roosync_get_status`.

4.  **Standardisation :**
    *   Supprimer les wrappers PowerShell (`scripts/roosync/*.ps1`) si le MCP peut être appelé directement ou via un alias simple.
    *   Documenter l'usage exclusif du MCP pour les opérations de synchro dans `docs/developer-guide.md`.