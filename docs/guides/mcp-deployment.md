# Guide de Déploiement des MCPs

Ce document décrit la procédure pour recompiler et déployer un serveur MCP, en prenant l'exemple de `roo-state-manager`.

## Contexte

Lors de mises à jour ou de modifications du code source d'un MCP, il est nécessaire de le recompiler pour que les changements soient pris en compte par l'application.

## Procédure de Recompilation

1.  **Naviguer vers le répertoire du MCP :**
    Ouvrez un terminal et placez-vous dans le répertoire du serveur MCP que vous souhaitez recompiler. Pour `roo-state-manager`, le chemin est :
    ```sh
    cd mcps/internal/servers/roo-state-manager
    ```

2.  **Installer les dépendances :**
    Assurez-vous que toutes les dépendances du projet sont à jour en exécutant la commande suivante :
    ```sh
    npm install
    ```

3.  **Compiler le serveur :**
    Lancez le script de compilation pour générer les fichiers JavaScript à partir des sources TypeScript.
    ```sh
    npm run build
    ```
    Cette commande s'appuie sur la configuration dans le `package.json` et exécute `tsc` (le compilateur TypeScript).

## Vérification de la Configuration

Le binaire compilé est généré dans le sous-dossier `build/`. Le chemin d'accès au script principal (`build/index.js`) doit correspondre à celui spécifié dans le fichier de configuration global des MCPs.

-   **Fichier de configuration :** `C:\Users\jsboi\AppData\Roaming\Code\User\globalStorage\rooveterinaryinc.roo-cline\settings\mcp_settings.json`
-   **Entrée concernée :** `roo-state-manager`

Dans la plupart des cas, le chemin de build est standard et ne nécessite pas de modification après une recompilation.