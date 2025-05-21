# Mode Hors Ligne pour le MCP Jupyter

Ce document explique comment utiliser le mode hors ligne du MCP Jupyter pour éliminer complètement les tentatives de connexion au serveur Jupyter.

## Problème résolu

Le MCP Jupyter tente par défaut de se connecter à un serveur Jupyter au démarrage et lors de l'utilisation de certaines fonctionnalités, ce qui peut entraîner des erreurs si aucun serveur n'est en cours d'exécution:

```
Erreur lors de la vérification de la version de l'API Jupyter: AxiosError: socket hang up
```

Le mode hors ligne amélioré élimine complètement toutes les tentatives de connexion au serveur Jupyter, y compris:
- Au démarrage du serveur MCP
- Lors de l'exécution de code
- Lors de la récupération des kernels disponibles
- Lors de la récupération des sessions actives
- Lors de toute autre opération nécessitant normalement une connexion

Cette approche garantit un fonctionnement stable même sans serveur Jupyter disponible.

## Options disponibles

### 1. Scripts avec paramètre `--offline`

Les scripts principaux ont été modifiés pour accepter un paramètre `--offline` qui active le mode hors ligne:

- `start-jupyter-mcp.bat --offline`
- `node scripts/mcp-starters/start-jupyter-mcp.js --offline`
- `./scripts/mcp-starters/start-jupyter-mcp.sh --offline`

Exemple:
```bash
# Windows
scripts\mcp-starters\start-jupyter-mcp.bat --offline

# Linux/macOS
./scripts/mcp-starters/start-jupyter-mcp.sh --offline

# JavaScript
node scripts/mcp-starters/start-jupyter-mcp.js --offline
```

### 2. Scripts dédiés au mode hors ligne

Des scripts dédiés ont été créés avec le mode hors ligne activé par défaut:

- `start-jupyter-mcp-offline.bat`
- `start-jupyter-mcp-offline.js`
- `start-jupyter-mcp-offline.sh`

Exemple:
```bash
# Windows
scripts\mcp-starters\start-jupyter-mcp-offline.bat

# Linux/macOS
./scripts/mcp-starters/start-jupyter-mcp-offline.sh

# JavaScript
node scripts/mcp-starters/start-jupyter-mcp-offline.js
```

### 3. Variable d'environnement

Vous pouvez également définir la variable d'environnement `JUPYTER_MCP_OFFLINE=true` avant de démarrer le serveur MCP:

```bash
# Windows
set JUPYTER_MCP_OFFLINE=true
scripts\mcp-starters\start-jupyter-mcp.bat

# Linux/macOS
export JUPYTER_MCP_OFFLINE=true
./scripts/mcp-starters/start-jupyter-mcp.sh
```

### 4. Option de ligne de commande

Si vous démarrez directement le serveur MCP Jupyter, vous pouvez utiliser l'option `--offline`:

```bash
cd servers/jupyter-mcp-server
node dist/index.js --offline
```

## Utilisation avec VSCode/Roo

Pour VSCode/Roo, il est recommandé d'utiliser le script `start-jupyter-mcp-vscode.bat` qui démarre automatiquement le MCP Jupyter en mode hors ligne.

## Fonctionnalités en mode hors ligne

En mode hors ligne, le MCP Jupyter fonctionne en mode dégradé avec simulation:

### Fonctionnalités disponibles
- Création et manipulation de notebooks (lecture, écriture, ajout/suppression de cellules)
- Simulation de kernels (création, arrêt, redémarrage)
- Simulation d'exécution de code (avec messages indiquant le mode hors ligne)
- Toutes les opérations de fichiers locaux

### Fonctionnalités limitées
- Exécution réelle de code Python (simulée avec des messages explicatifs)
- Accès aux kernels et sessions du serveur Jupyter
- Fonctionnalités interactives nécessitant un kernel actif

### Activation du mode complet

Pour utiliser les fonctionnalités complètes nécessitant un serveur Jupyter, vous devez:

1. Démarrer manuellement Jupyter Notebook:
   ```bash
   jupyter notebook
   ```

2. Redémarrer le MCP Jupyter en mode normal (sans l'option `--offline`):
   ```bash
   # Windows
   scripts\mcp-starters\start-jupyter-mcp.bat
   
   # Linux/macOS
   ./scripts/mcp-starters/start-jupyter-mcp.sh
   ```

## Configuration avancée

### Fichier de configuration

Le fichier de configuration `servers/jupyter-mcp-server/config.json` peut contenir les options suivantes:

```json
{
  "jupyterServer": {
    "baseUrl": "http://localhost:8888",
    "token": "votre_token_ici",
    "skipConnectionCheck": true,
    "offlineMode": true
  }
}
```

### Options de configuration

| Option | Description |
|--------|-------------|
| `baseUrl` | URL de base du serveur Jupyter |
| `token` | Token d'authentification pour le serveur Jupyter |
| `skipConnectionCheck` | Si `true`, désactive les vérifications de connexion au démarrage |
| `offlineMode` | Si `true`, active le mode hors ligne complet |

### Nouvelle option de ligne de commande

Une nouvelle option `--skip-connection-check` a été ajoutée pour désactiver uniquement les vérifications de connexion au démarrage sans activer le mode hors ligne complet:

```bash
node dist/index.js --skip-connection-check
```

### Variable d'environnement supplémentaire

```bash
# Windows
set JUPYTER_SKIP_CONNECTION_CHECK=true
scripts\mcp-starters\start-jupyter-mcp.bat

# Linux/macOS
export JUPYTER_SKIP_CONNECTION_CHECK=true
./scripts/mcp-starters/start-jupyter-mcp.sh
```

## Script de correction automatique

Le script `scripts/fix-jupyter-offline.js` configure automatiquement le mode hors ligne complet:

```bash
node scripts/fix-jupyter-offline.js
```

Ce script:
1. Configure le MCP Jupyter pour le mode hors ligne
2. Configure Roo pour utiliser le MCP Jupyter en mode hors ligne
3. Démarre le MCP Jupyter avec la nouvelle configuration