# Stratégie de Commit et Réorganisation

Ce document détaille le plan d'action pour réorganiser et commiter les modifications en attente. L'objectif est de structurer le dépôt pour isoler les personnalisations du code source principal du sous-module `roo-code`, afin de faciliter la maintenance et les futures Pull Requests.

## Étape 1 : Réorganisation des Fichiers

Avant tout commit, nous allons réorganiser les fichiers pour les placer dans une structure logique. **Ces actions seront exécutées par l'agent en mode `code`**.

1.  **Créer le répertoire de personnalisation :**
    *   Un répertoire `roo-code-customization` sera créé à la racine pour contenir tous les scripts, documents et investigations spécifiques à notre fork.

2.  **Déplacer les scripts et documents de déploiement :**
    *   Les fichiers `deploy-fix.ps1`, `deploy-fix.Tests.ps1` et les documents de conception associés (`deployment-script-*.md`) seront déplacés dans `roo-code-customization/`.

3.  **Centraliser la documentation d'investigation :**
    *   Le rapport `incident-report-condensation-revert.md` sera déplacé dans `roo-code-customization/`.
    *   Tout le contenu du répertoire `roo-code/myia/` sera déplacé dans `roo-code-customization/`.

4.  **Nettoyer l'ancienne structure :**
    *   Le répertoire `roo-code/myia/` sera supprimé après le déplacement de son contenu.

## Étape 2 : Plan de Commit

Une fois la réorganisation effectuée, les commits suivants seront réalisés.

### Commit 1 : `feat(custom): introduce customization and investigation structure` (Dépôt Principal)

Ce premier commit enregistre la nouvelle structure de personnalisation.

*   **Fichiers à ajouter :**
    ```bash
    git add roo-code-customization/
    ```
*   **Message de commit :**
    ```
    feat(custom): introduce customization and investigation structure
    ```

### Commit 2 : `fix(search): correct escaping and improve provider stability` (Sous-module `roo-code`)

Ce commit isole les modifications de code pur dans le sous-module.

*   **Fichiers à ajouter (dans `roo-code`) :**
    ```bash
    git add src/core/webview/ClineProvider.ts src/services/search/file-search.ts
    ```
*   **Message de commit :**
    ```
    fix(search): correct escaping and improve provider stability
    ```

### Commit 3 : `chore: update submodule and restore config` (Dépôt Principal)

Ce commit finalise l'opération en mettant à jour la référence du sous-module et en restaurant la configuration de l'IDE.

*   **Actions de nettoyage préalables :**
    1.  Supprimer `.roomodes.bugged`.
    2.  Restaurer la version de `.roomodes` suivie par Git.
*   **Fichiers à ajouter :**
    ```bash
    git add roo-code
    git add .roomodes
    ```
*   **Message de commit :**
    ```
    chore: update submodule and restore config