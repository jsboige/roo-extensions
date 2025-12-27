# Instructions de Déploiement - Cycle 8 (Phase 1)

**Priorité :** CRITIQUE
**Date :** 2025-12-08
**Contexte :** Activation de la synchronisation granulaire et normalisation des configurations.

## Actions Requises (Tous les Agents)

Veuillez exécuter les commandes suivantes immédiatement :

1.  **Mise à jour du Code :**
    ```bash
    git pull origin main
    git submodule update --init --recursive
    ```

2.  **Recompilation :**
    ```bash
    npm run build:all
    ```

3.  **Redémarrage :**
    *   Redémarrez vos serveurs MCP (Reload Window ou Restart Extension Host).

4.  **Collecte de Configuration :**
    *   Une fois redémarré, exécutez l'outil : `roosync_collect_config`.
    *   Confirmez le succès dans ce fichier (en ajoutant une coche [x] à votre nom si liste présente, ou en commentaire).