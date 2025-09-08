# Configuration du MCP Markitdown

## Dépendances

Le MCP Markitdown est basé sur Python. Il est donc nécessaire d'avoir un interpréteur Python fonctionnel sur le système.

## Configuration de l'interpréteur Python

Sur Windows, il est courant d'avoir des "alias d'exécution d'application" qui pointent vers le Microsoft Store au lieu d'un véritable exécutable Python. Cela peut empêcher le MCP de démarrer.

Il y a deux façons de configurer correctement l'interpréteur Python :

### 1. Détection automatique (via script)

Un script de déploiement peut être utilisé pour trouver un interpréteur Python valide sur le système. Ce script doit :
- Lister toutes les installations de Python disponibles.
- Ignorer les alias du Microsoft Store (qui se trouvent généralement dans `\WindowsApps\`).
- Tester chaque exécutable restant avec une commande comme `python --version` pour s'assurer qu'il est fonctionnel.
- Utiliser le chemin absolu de l'exécutable valide dans la configuration du MCP.

### 2. Environnement Virtuel Dédié (Recommandé)

La méthode la plus robuste et la plus recommandée est d'utiliser un environnement virtuel dédié (avec `conda` ou `venv`). Cela permet d'isoler les dépendances du MCP et d'éviter les conflits.

1.  **Créer et Activer l'Environnement :**
    ```powershell
    conda create -n mcp-markitdown python=3.9
    conda activate mcp-markitdown
    ```

2.  **Installer les dépendances :**
    ```powershell
    pip install markitdown-mcp
    ```

3.  **Configuration `mcp_settings.json` :**
    Pointez la commande vers l'exécutable Python de l'environnement Conda.
    ```json
    "markitdown": {
      "command": "C:/Users/jsboi/.conda/envs/mcp-markitdown/python.exe",
      "args": [
        "-m",
        "markitdown_mcp"
      ]
    }