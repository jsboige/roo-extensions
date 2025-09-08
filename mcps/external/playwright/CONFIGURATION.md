# Configuration du MCP Playwright

Ce document complète les informations d'installation et de compilation présentes dans le `README.md`.

## Méthodes de Lancement

Il existe deux principales manières de lancer le MCP Playwright, chacune avec ses avantages et inconvénients.

### 1. Lancement via `npx` (Simple mais potentiellement instable)

Cette méthode est simple car elle ne nécessite pas d'installation locale du paquet.

```json
"playwright": {
  "command": "npx",
  "args": [
    "-y",
    "@playwright/mcp",
    "--browser",
    "firefox"
  ]
}
```

**Problème Connu : Instabilité du cache `npx`**

Le démarrage via `npx` peut être instable. Le cache de `npx` peut se corrompre, menant à des échecs de démarrage intermittents avec des erreurs comme `ERR_MODULE_NOT_FOUND`.

**Solution : Stratégie de "préchauffage"**

Pour fiabiliser le lancement avec `npx`, une étape de "préchauffage" peut être ajoutée à un script de déploiement. Avant de démarrer le MCP, exécutez une commande `npx` inoffensive :

```powershell
npx -y @playwright/mcp --version
```
Cette commande force `npx` à télécharger et installer proprement le paquet s'il est manquant ou invalide, ce qui stabilise les lancements ultérieurs.

### 2. Lancement via Installation Locale (Recommandé)

Cette méthode est la plus robuste et la plus fiable.

1.  **Installation locale :**
    ```bash
    # Depuis la racine du projet
    npm install @playwright/mcp playwright
    ```

2.  **Configuration `mcp_settings.json` :**
    Pointez la commande directement vers le script `cli.js` du paquet installé localement, en utilisant `node`.
    ```json
    "playwright": {
      "command": "node",
      "args": [
        "D:/dev/roo-extensions/node_modules/@playwright/mcp/lib/cli.js",
        "--browser",
        "firefox"
      ]
    }