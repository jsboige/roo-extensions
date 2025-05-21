# Utilisation du serveur MCP Jupyter

Ce document explique comment utiliser les scripts pour démarrer le serveur Jupyter et le client MCP Jupyter de manière découplée.

## Architecture découplée

L'architecture a été modifiée pour découpler le serveur Jupyter du client MCP Jupyter:

1. Le serveur Jupyter est démarré séparément et fonctionne de manière autonome
2. Le client MCP Jupyter se connecte au serveur Jupyter existant
3. La configuration de connexion est stockée dans un fichier `config.json`

## Connexion à n'importe quel serveur Jupyter

Le client MCP Jupyter peut maintenant se connecter à n'importe quel serveur Jupyter existant, qu'il ait été démarré par nos scripts ou non. Vous pouvez spécifier l'URL et le token du serveur Jupyter de plusieurs façons :

1. **Via le script de connexion** : Utiliser `start-jupyter-mcp-connect.bat` pour se connecter à un serveur existant
2. **Via des paramètres de ligne de commande** : `node dist/index.js --url http://localhost:8888 --token abc123`
3. **Via des variables d'environnement** : `JUPYTER_SERVER_URL` et `JUPYTER_SERVER_TOKEN`
4. **Via le fichier de configuration** : Modifier `config.json`

## Mode hors ligne pour VSCode/Roo

Pour éviter les erreurs de connexion au démarrage de VSCode/Roo, le client MCP Jupyter est configuré pour démarrer en mode hors ligne par défaut. Dans ce mode :

- Aucune tentative de connexion à un serveur Jupyter n'est effectuée
- Les fonctionnalités nécessitant un serveur Jupyter ne sont pas disponibles
- Aucun message d'erreur de connexion n'est affiché

## Démarrage manuel recommandé

Pour utiliser toutes les fonctionnalités du MCP Jupyter, nous recommandons d'utiliser le script de démarrage manuel :

```
scripts/mcp-starters/start-jupyter-manual.bat
```

Ce script vous offre plusieurs options :
1. Démarrer uniquement le serveur Jupyter
2. Démarrer uniquement le client MCP Jupyter
3. Démarrer les deux composants
4. Connecter le client MCP à un serveur Jupyter existant
5. Quitter

## Scripts disponibles

### `start-jupyter-server.bat`

Ce script démarre uniquement un serveur Jupyter pour les tests:

```
scripts/mcp-starters/start-jupyter-server.bat
```

- Vérifie si Jupyter est installé
- Démarre un serveur Jupyter Notebook sans navigateur
- Affiche l'URL d'accès au serveur Jupyter

### `start-jupyter-mcp-client.bat`

Ce script démarre uniquement le client MCP Jupyter:

```
scripts/mcp-starters/start-jupyter-mcp-client.bat
```

- Vérifie si un serveur Jupyter est en cours d'exécution
- Propose de démarrer un serveur Jupyter si nécessaire
- Vérifie si le serveur MCP Jupyter est compilé
- Crée un fichier de configuration par défaut s'il n'existe pas
- Démarre le client MCP Jupyter qui se connecte au serveur Jupyter existant

### `start-jupyter-mcp-connect.bat`

Ce script permet de connecter le client MCP Jupyter à n'importe quel serveur Jupyter existant:

```
scripts/mcp-starters/start-jupyter-mcp-connect.bat
```

- Demande l'URL et le token du serveur Jupyter
- Crée un fichier de configuration avec ces informations
- Démarre le client MCP Jupyter avec les paramètres spécifiés

### `start-jupyter-mcp-vscode.bat`

Ce script est utilisé par VSCode/Roo pour démarrer le client MCP Jupyter en mode hors ligne:

```
scripts/mcp-starters/start-jupyter-mcp-vscode.bat
```

- Démarre le client MCP Jupyter en mode hors ligne
- Évite les tentatives de connexion au serveur Jupyter
- Évite les messages d'erreur de connexion

## Options de ligne de commande

Le client MCP Jupyter accepte les options de ligne de commande suivantes:

```
node dist/index.js [options]

Options:
  --url <url>       URL du serveur Jupyter (ex: http://localhost:8888)
  --token <token>   Token d'authentification du serveur Jupyter
  --offline         Démarrer en mode hors ligne (sans tentatives de connexion)
  --config <path>   Chemin vers un fichier de configuration personnalisé
  --help            Afficher cette aide
```

## Variables d'environnement

Le client MCP Jupyter reconnaît les variables d'environnement suivantes:

- `JUPYTER_SERVER_URL` : URL du serveur Jupyter
- `JUPYTER_SERVER_TOKEN` : Token d'authentification du serveur Jupyter
- `JUPYTER_MCP_OFFLINE` : Définir à 'true' pour le mode hors ligne
- `JUPYTER_MCP_CONFIG` : Chemin vers un fichier de configuration personnalisé

## Configuration

Le client MCP Jupyter utilise un fichier de configuration `config.json` situé dans le répertoire `servers/jupyter-mcp-server/` pour se connecter au serveur Jupyter:

```json
{
  "jupyterServer": {
    "baseUrl": "http://localhost:8888",
    "token": "votre_token_ici"
  }
}
```

- `baseUrl`: URL du serveur Jupyter (par défaut: `http://localhost:8888`)
- `token`: Token d'authentification du serveur Jupyter (vide par défaut)

Pour obtenir le token, consultez la sortie du serveur Jupyter lors de son démarrage ou accédez à `http://localhost:8888` dans votre navigateur.

## Configuration VSCode/Roo

La configuration VSCode/Roo a été modifiée pour utiliser le script `start-jupyter-mcp-vscode.bat` qui démarre le client MCP Jupyter en mode hors ligne. Cela évite les erreurs de connexion au démarrage.

Si vous souhaitez désactiver complètement le démarrage automatique du client MCP Jupyter, modifiez le fichier `mcp_settings.json` et changez `"disabled": false` en `"disabled": true`.

## Utilisation typique

1. **Pour une utilisation normale avec VSCode/Roo** :
   - Le client MCP Jupyter démarre automatiquement en mode hors ligne
   - Aucune erreur de connexion n'est affichée
   - Les fonctionnalités nécessitant un serveur Jupyter ne sont pas disponibles

2. **Pour utiliser toutes les fonctionnalités avec un nouveau serveur Jupyter** :
   - Exécutez le script de démarrage manuel : `scripts/mcp-starters/start-jupyter-manual.bat`
   - Choisissez l'option 3 pour démarrer à la fois le serveur Jupyter et le client MCP
   - Le client MCP Jupyter est maintenant disponible pour Roo avec toutes ses fonctionnalités

3. **Pour se connecter à un serveur Jupyter existant** :
   - Exécutez le script de démarrage manuel : `scripts/mcp-starters/start-jupyter-manual.bat`
   - Choisissez l'option 4 pour connecter le client MCP à un serveur existant
   - Spécifiez l'URL et le token du serveur Jupyter
   - Le client MCP Jupyter est maintenant connecté au serveur existant

## Notes

- Si le serveur Jupyter utilise un token, vous devez le spécifier pour établir la connexion
- Le client MCP Jupyter ne tentera pas de démarrer son propre serveur Jupyter
- Le mode hors ligne permet d'éviter les erreurs de connexion au démarrage de VSCode/Roo
- La priorité des paramètres est: ligne de commande > variables d'environnement > fichier de configuration