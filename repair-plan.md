# Plan de Réparation Git

## Situation
- **Dépôt principal :** `rebase` interactif interrompu.
- **Conflit :** Le sous-module `mcps/external/mcp-server-ftp` a divergé entre la branche locale (commit `42558afe`) et la branche distante (commit `3abcadb8`).
- **État du sous-module :** Propre (`working tree clean`), aucune modification locale en attente.

## Objectif
Résoudre le conflit de `rebase` en choisissant la version du sous-module correspondant au travail de refactorisation local (`42558afe`) et finaliser la synchronisation.

## Plan d'Action Séquentiel

1.  **Étape 1 : Résoudre le conflit en choisissant "notre" version**
    -   **Description :** Forcer Git à accepter la version du sous-module de notre branche locale (celle incluant la refactorisation).
    -   **Commande :** `git checkout --ours -- mcps/external/mcp-server-ftp`

2.  **Étape 2 : Synchroniser les fichiers du sous-module**
    -   **Description :** Mettre à jour le contenu du répertoire du sous-module pour qu'il corresponde au commit `42558afe` sélectionné à l'étape précédente.
    -   **Commande :** `git submodule update --init mcps/external/mcp-server-ftp`

3.  **Étape 3 : Poursuivre et finaliser le Rebase**
    -   **Description :** Une fois le conflit marqué comme résolu, continuer le processus de `rebase` pour appliquer les commits restants.
    -   **Commande :** `git rebase --continue`

4.  **Étape 4 : Valider l'état final**
    -   **Description :** Vérifier que le dépôt principal est propre, que le `rebase` est terminé et que tous les sous-modules sont dans un état cohérent.
    -   **Commande :** `git status`