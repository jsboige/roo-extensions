# Scripts pour les serveurs MCP

Ce répertoire contient des scripts utilitaires pour démarrer et configurer les serveurs MCP.

## Serveur Jupyter

### Prérequis

Pour utiliser le serveur Jupyter avec MCP, vous devez avoir installé :

- Python (version 3.6 ou supérieure)
- Jupyter Notebook

Si Jupyter n'est pas installé, vous pouvez l'installer avec l'une des commandes suivantes :

```bash
# Installation standard
pip install jupyter notebook

# Si vous rencontrez des problèmes de permission, essayez avec des privilèges d'administrateur
# Sur Windows (PowerShell en tant qu'administrateur)
pip install jupyter notebook

# Sur Windows (CMD en tant qu'administrateur)
pip install jupyter notebook

# Sur Linux/macOS
sudo pip install jupyter notebook
```

**Note importante** : Si vous voyez le message "Jupyter command `jupyter-notebook` not found" lors du démarrage du serveur, cela signifie que le package `notebook` n'est pas installé correctement. Assurez-vous de l'installer avec la commande ci-dessus.

### Démarrage du serveur Jupyter

Deux scripts sont fournis pour démarrer le serveur Jupyter avec les paramètres optimaux pour l'intégration MCP :

- `start-jupyter-server.ps1` (PowerShell)
- `start-jupyter-server.bat` (Batch)

#### Utilisation du script PowerShell

```powershell
cd chemin/vers/roo-extensions
.\mcps\scripts\start-jupyter-server.ps1
```

#### Utilisation du script Batch

```cmd
cd chemin/vers/roo-extensions
.\mcps\scripts\start-jupyter-server.bat
```

### Configuration

Les scripts démarrent le serveur Jupyter avec les paramètres suivants :

- **URL** : http://localhost:8888
- **Token** : simple-token-for-testing
- **Mode** : Sans navigateur
- **Origines croisées** : Autorisées
- **Accès distant** : Autorisé

### Intégration avec le serveur MCP Jupyter

Le serveur MCP Jupyter est configuré pour se connecter au serveur Jupyter à l'URL http://localhost:8888 avec le token "simple-token-for-testing". Cette configuration est définie dans le fichier `mcps/mcp-servers/jupyter-config.json`.

Si vous modifiez les paramètres du serveur Jupyter (port, token, etc.), vous devez également mettre à jour le fichier de configuration MCP correspondant.

### Vérification de l'intégration

Pour vérifier que l'intégration fonctionne correctement, vous pouvez exécuter les tests suivants :

```bash
node tests/mcp/test-jupyter-connection.js
node tests/mcp/test-jupyter-mcp-connect.js
```

### Résolution des problèmes

Si vous rencontrez des problèmes avec l'intégration entre le serveur Jupyter et le serveur MCP, vérifiez les points suivants :

1. Le serveur Jupyter est en cours d'exécution
2. Le token dans le fichier de configuration MCP correspond au token utilisé par le serveur Jupyter
3. Le port dans le fichier de configuration MCP correspond au port utilisé par le serveur Jupyter
4. Les origines croisées sont autorisées sur le serveur Jupyter

Pour plus d'informations sur la résolution des problèmes, consultez le fichier `tests/mcp/diagnose-jupyter-mcp.js`.