# Cartographie du Dépôt (Post-Refactorisation)

Ce document cartographie la structure rationalisée du dépôt après le projet de refactorisation des scripts. Il sert de guide pour comprendre le rôle de chaque répertoire d'outillage.

## Structure Finale de l'Outillage (`/scripts`)

Le répertoire `/scripts` est l'unique source de vérité pour tous les scripts PowerShell du projet. L'arborescence a été standardisée par fonction.

*   **`/scripts/deployment/`**: Contient l'outil unique pour le déploiement des configurations de Modes.
    *   `deploy-modes.ps1`

*   **`/scripts/diagnostic/`**: Héberge le script de diagnostic technique pour l'environnement.
    *   `run-diagnostic.ps1`

*   **`/scripts/encoding/`**: Contient l'outil pour corriger le contenu des fichiers mal encodés.
    *   `fix-file-encoding.ps1`

*   **`/scripts/maintenance/`**: Regroupe les outils de maintenance de haut niveau.
    *   `maintenance-workflow.ps1`: Orchestrateur interactif pour guider l'opérateur.
    *   `Invoke-WorkspaceMaintenance.ps1`: Outil pour le nettoyage et la réorganisation du workspace.
    *   `Invoke-GitMaintenance.ps1`: Outil pour l'analyse et le nettoyage du dépôt Git.
    *   `Update-ModeConfiguration.ps1`: Outil pour les mises à jour en masse des configurations de Modes.

*   **`/scripts/setup/`**: Contient le script pour la configuration initiale de l'environnement d'un développeur.
    *   `setup-encoding-workflow.ps1`

*   **`/scripts/validation/`**: Héberge les scripts de validation métier et fonctionnelle.
    *   `validate-deployed-modes.ps1`
    *   `validate-mcp-config.ps1`

*   **Autres**: Les répertoires comme `mcp`, `audit`, `demo-scripts` ont été conservés avec leurs rôles spécialisés.

---

## Résumé du Plan de Refactorisation Réalisé

Un travail de refactoring de l'outillage a été effectué pour simplifier le dépôt, réduire la confusion et faciliter la maintenance future.

### Problèmes Majeurs Corrigés

1.  **Duplication Massive d'Outils :** Les outils de gestion de l'encodage, de déploiement et de diagnostic qui existaient en multiples exemplaires (`scripts/`, `roo-config/`, `docs/guides/`) ont été supprimés au profit d'une source unique dans `/scripts`.
2.  **Versions Obsolètes :** Les multiples versions de scripts (`-v2`, `-fixed`, `-simple`) ont été fusionnées en des outils uniques et paramétrables.
3.  **Scripts de Migration :** Les scripts à usage unique ont été soit supprimés, soit consolidés dans les nouveaux outils de maintenance.
4.  **Fragmentation de la Logique :** La logique a été regroupée par fonction dans des répertoires dédiés et clairs.

### Actions Menées

1.  **Étape 1 : Consolidation des Scripts de Déploiement (`/deployment`)**
    *   Toute la logique de déploiement a été fusionnée dans `deploy-modes.ps1`.
    *   Une quinzaine de scripts redondants ont été supprimés.

2.  **Étape 2 : Rationalisation des Diagnostics (`/diagnostic` et `/validation`)**
    *   La logique de diagnostic a été séparée en "technique" et "métier".
    *   Un nouveau répertoire `scripts/validation/` a été créé pour la logique métier.
    *   Les outils de diagnostic technique ont été fusionnés dans `run-diagnostic.ps1`.

3.  **Étape 3 : Clarification des Scripts d'Encodage (`/encoding` et `/setup`)**
    *   La logique de configuration de l'environnement (profil PowerShell, Git) a été déplacée dans un nouveau répertoire `scripts/setup/` et consolidée dans `setup-encoding-workflow.ps1`.
    *   Tous les scripts de correction de contenu de fichiers ont été fusionnés dans `scripts/encoding/fix-file-encoding.ps1`.

4.  **Étape 4 : Refactorisation de la Maintenance (`/maintenance`)**
    *   Les dizaines de scripts de nettoyage, d'organisation, d'analyse Git et de mise à jour de configuration ont été fusionnés en trois outils puissants : `Invoke-WorkspaceMaintenance.ps1`, `Invoke-GitMaintenance.ps1`, et `Update-ModeConfiguration.ps1`.
    *   Le script `maintenance-workflow.ps1` a été promu en tant que point d'entrée interactif pour guider les opérateurs.

Ce travail de refactoring a permis de réduire le nombre de scripts de manière significative (plus de 50 scripts supprimés ou fusionnés), améliorant ainsi considérablement la lisibilité et la maintenabilité du projet.