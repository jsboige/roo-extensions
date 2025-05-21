# Configuration du serveur MCP Jupyter

<!-- START_SECTION: introduction -->
Ce document détaille les options de configuration disponibles pour le serveur MCP Jupyter. La configuration appropriée vous permettra d'optimiser les performances, de gérer les connexions au serveur Jupyter et d'adapter le comportement du serveur à vos besoins spécifiques.
<!-- END_SECTION: introduction -->

<!-- START_SECTION: config_file -->
## Fichier de configuration

Le serveur MCP Jupyter utilise un fichier de configuration au format JSON. Par défaut, ce fichier est nommé `config.json` et doit être placé dans le répertoire racine du serveur.

### Structure du fichier de configuration

```json
{
  "server": {
    "port": 3000,
    "host": "localhost",
    "cors": {
      "enabled": true,
      "origins": ["*"]
    }
  },
  "offline": false,
  "jupyterServer": {
    "baseUrl": "http://localhost:8888",
    "token": "votre_token_ici",
    "timeout": 30000,
    "retryAttempts": 3,
    "retryDelay": 1000
  },
  "performance": {
    "cacheEnabled": true,
    "cacheMaxAge": 300,
    "maxConcurrentOperations": 5
  },
  "logging": {
    "level": "info",
    "file": "jupyter-mcp.log",
    "console": true
  }
}
```

### Emplacement du fichier de configuration

Vous pouvez spécifier un emplacement personnalisé pour le fichier de configuration en utilisant l'option de ligne de commande `--config` :

```bash
node dist/index.js --config /chemin/vers/mon-config.json
```

Ou en définissant la variable d'environnement `JUPYTER_MCP_CONFIG` :

```bash
export JUPYTER_MCP_CONFIG=/chemin/vers/mon-config.json
node dist/index.js
```
<!-- END_SECTION: config_file -->

<!-- START_SECTION: server_options -->
## Options du serveur

### `server.port`

- **Type** : Nombre
- **Défaut** : `3000`
- **Description** : Port sur lequel le serveur MCP Jupyter écoutera les connexions.

### `server.host`

- **Type** : Chaîne
- **Défaut** : `"localhost"`
- **Description** : Adresse IP ou nom d'hôte sur lequel le serveur écoutera. Utilisez `"0.0.0.0"` pour écouter sur toutes les interfaces réseau.

### `server.cors`

- **Type** : Objet
- **Description** : Configuration CORS (Cross-Origin Resource Sharing) pour permettre les requêtes depuis d'autres domaines.

#### `server.cors.enabled`

- **Type** : Booléen
- **Défaut** : `true`
- **Description** : Active ou désactive le support CORS.

#### `server.cors.origins`

- **Type** : Tableau de chaînes
- **Défaut** : `["*"]`
- **Description** : Liste des origines autorisées pour les requêtes CORS. Utilisez `["*"]` pour autoriser toutes les origines.
<!-- END_SECTION: server_options -->

<!-- START_SECTION: offline_mode -->
## Mode hors ligne

### `offline`

- **Type** : Booléen
- **Défaut** : `false`
- **Description** : Active ou désactive le mode hors ligne. En mode hors ligne, le serveur MCP Jupyter ne tente pas de se connecter à un serveur Jupyter, ce qui évite les erreurs de connexion au démarrage.

Le mode hors ligne est particulièrement utile dans les environnements où le serveur Jupyter n'est pas toujours disponible, comme lors de l'utilisation avec VSCode/Roo. Dans ce mode, les fonctionnalités nécessitant un serveur Jupyter ne sont pas disponibles, mais le serveur MCP Jupyter peut toujours être utilisé pour manipuler les fichiers notebook.

Pour activer le mode hors ligne :

```json
{
  "offline": true
}
```

Pour désactiver le mode hors ligne et se connecter à un serveur Jupyter :

```json
{
  "offline": false,
  "jupyterServer": {
    "baseUrl": "http://localhost:8888",
    "token": "votre_token_ici"
  }
}
```
<!-- END_SECTION: offline_mode -->

<!-- START_SECTION: jupyter_server_options -->
## Options du serveur Jupyter

### `jupyterServer.baseUrl`

- **Type** : Chaîne
- **Défaut** : `"http://localhost:8888"`
- **Description** : URL de base du serveur Jupyter auquel se connecter.

### `jupyterServer.token`

- **Type** : Chaîne
- **Défaut** : `""`
- **Description** : Token d'authentification pour le serveur Jupyter. Ce token doit correspondre à celui utilisé pour démarrer le serveur Jupyter.

### `jupyterServer.timeout`

- **Type** : Nombre
- **Défaut** : `30000` (30 secondes)
- **Description** : Délai d'attente en millisecondes avant qu'une requête au serveur Jupyter ne soit considérée comme ayant échoué.

### `jupyterServer.retryAttempts`

- **Type** : Nombre
- **Défaut** : `3`
- **Description** : Nombre maximal de tentatives de connexion au serveur Jupyter en cas d'échec.

### `jupyterServer.retryDelay`

- **Type** : Nombre
- **Défaut** : `1000` (1 seconde)
- **Description** : Délai en millisecondes entre les tentatives de connexion au serveur Jupyter.

### Exemple de configuration du serveur Jupyter

```json
"jupyterServer": {
  "baseUrl": "http://jupyter.example.com:8888",
  "token": "token_secret_et_complexe",
  "timeout": 60000,
  "retryAttempts": 5,
  "retryDelay": 2000
}
```

Cette configuration se connecte à un serveur Jupyter distant, utilise un token d'authentification personnalisé, augmente le timeout à 60 secondes, définit 5 tentatives de connexion avec un délai de 2 secondes entre chaque tentative.
<!-- END_SECTION: jupyter_server_options -->

<!-- START_SECTION: performance_options -->
## Options de performance

### `performance.cacheEnabled`

- **Type** : Booléen
- **Défaut** : `true`
- **Description** : Active ou désactive le cache des résultats de lecture de notebooks. Le cache permet d'éviter de relire les fichiers notebook du disque à chaque requête.

### `performance.cacheMaxAge`

- **Type** : Nombre
- **Défaut** : `300` (5 minutes)
- **Description** : Durée maximale en secondes pendant laquelle les résultats sont conservés dans le cache.

### `performance.maxConcurrentOperations`

- **Type** : Nombre
- **Défaut** : `5`
- **Description** : Nombre maximal d'opérations concurrentes que le serveur peut exécuter.

### Exemple de configuration de performance

```json
"performance": {
  "cacheEnabled": true,
  "cacheMaxAge": 600,
  "maxConcurrentOperations": 10
}
```

Cette configuration active le cache avec une durée de vie de 10 minutes et permet jusqu'à 10 opérations concurrentes.
<!-- END_SECTION: performance_options -->

<!-- START_SECTION: logging_options -->
## Options de journalisation

### `logging.level`

- **Type** : Chaîne
- **Valeurs possibles** : `"error"`, `"warn"`, `"info"`, `"debug"`, `"trace"`
- **Défaut** : `"info"`
- **Description** : Niveau de détail des journaux.

### `logging.file`

- **Type** : Chaîne
- **Défaut** : `"jupyter-mcp.log"`
- **Description** : Nom du fichier de journal. Si vide ou non défini, la journalisation dans un fichier est désactivée.

### `logging.console`

- **Type** : Booléen
- **Défaut** : `true`
- **Description** : Active ou désactive la journalisation dans la console.

### Exemple de configuration de journalisation

```json
"logging": {
  "level": "debug",
  "file": "logs/jupyter-mcp.log",
  "console": true
}
```

Cette configuration active la journalisation au niveau de détail "debug", écrit les journaux dans le fichier `logs/jupyter-mcp.log` et affiche également les journaux dans la console.
<!-- END_SECTION: logging_options -->

<!-- START_SECTION: environment_variables -->
## Variables d'environnement

Vous pouvez également configurer le serveur MCP Jupyter en utilisant des variables d'environnement. Les variables d'environnement ont priorité sur les valeurs du fichier de configuration.

| Variable d'environnement | Description |
|--------------------------|-------------|
| `JUPYTER_MCP_PORT` | Port du serveur |
| `JUPYTER_MCP_HOST` | Hôte du serveur |
| `JUPYTER_MCP_OFFLINE` | Mode hors ligne (true/false) |
| `JUPYTER_SERVER_URL` | URL du serveur Jupyter |
| `JUPYTER_SERVER_TOKEN` | Token d'authentification du serveur Jupyter |
| `JUPYTER_SERVER_TIMEOUT` | Timeout des requêtes en millisecondes |
| `JUPYTER_MCP_LOG_LEVEL` | Niveau de journalisation |
| `JUPYTER_MCP_CONFIG` | Chemin vers le fichier de configuration |

### Exemple d'utilisation des variables d'environnement

```bash
export JUPYTER_MCP_PORT=4000
export JUPYTER_MCP_HOST=0.0.0.0
export JUPYTER_MCP_OFFLINE=false
export JUPYTER_SERVER_URL=http://localhost:8888
export JUPYTER_SERVER_TOKEN=votre_token_ici
export JUPYTER_SERVER_TIMEOUT=60000
export JUPYTER_MCP_LOG_LEVEL=debug
node dist/index.js
```
<!-- END_SECTION: environment_variables -->

<!-- START_SECTION: command_line_options -->
## Options de ligne de commande

Le serveur MCP Jupyter accepte également des options de ligne de commande qui ont priorité sur les variables d'environnement et les valeurs du fichier de configuration.

| Option | Description |
|--------|-------------|
| `--port <port>` | Port du serveur |
| `--host <host>` | Hôte du serveur |
| `--config <path>` | Chemin vers le fichier de configuration |
| `--log-level <level>` | Niveau de journalisation |
| `--offline <boolean>` | Mode hors ligne (true/false) |
| `--url <url>` | URL du serveur Jupyter |
| `--token <token>` | Token d'authentification du serveur Jupyter |
| `--help` | Affiche l'aide |

### Exemple d'utilisation des options de ligne de commande

```bash
node dist/index.js --port 4000 --host 0.0.0.0 --offline false --url http://localhost:8888 --token votre_token_ici --log-level debug
```
<!-- END_SECTION: command_line_options -->

<!-- START_SECTION: advanced_configuration -->
## Configuration avancée

### Configuration des outils MCP

Vous pouvez configurer des paramètres spécifiques pour chaque outil MCP exposé par le serveur Jupyter :

```json
"tools": {
  "read_notebook": {
    "cacheResults": true
  },
  "execute_cell": {
    "timeout": 60000,
    "maxOutputSize": 1000000
  },
  "execute_notebook": {
    "timeout": 300000,
    "maxConcurrentCells": 1
  }
}
```

### Configuration du serveur HTTP

Pour une configuration avancée du serveur HTTP sous-jacent :

```json
"http": {
  "keepAliveTimeout": 5000,
  "headersTimeout": 6000,
  "maxHeaderSize": 8192,
  "requestTimeout": 30000
}
```

### Configuration TLS/SSL

Pour activer HTTPS :

```json
"tls": {
  "enabled": true,
  "key": "/chemin/vers/key.pem",
  "cert": "/chemin/vers/cert.pem",
  "ca": "/chemin/vers/ca.pem",
  "passphrase": "mot_de_passe_optionnel"
}
```

### Configuration des kernels

Pour configurer les kernels Jupyter :

```json
"kernels": {
  "defaultKernel": "python3",
  "kernelTimeout": 60000,
  "kernelStartTimeout": 30000,
  "maxConcurrentKernels": 5
}
```
<!-- END_SECTION: advanced_configuration -->

<!-- START_SECTION: configuration_examples -->
## Exemples de configuration

### Configuration minimale

```json
{
  "offline": true
}
```

Cette configuration minimale démarre le serveur en mode hors ligne, sans tenter de se connecter à un serveur Jupyter.

### Configuration de développement

```json
{
  "server": {
    "port": 3000,
    "host": "localhost",
    "cors": {
      "enabled": true,
      "origins": ["*"]
    }
  },
  "offline": false,
  "jupyterServer": {
    "baseUrl": "http://localhost:8888",
    "token": "test_token"
  },
  "logging": {
    "level": "debug",
    "console": true
  }
}
```

Cette configuration est adaptée pour le développement, avec une journalisation détaillée et une connexion à un serveur Jupyter local.

### Configuration de production

```json
{
  "server": {
    "port": 3000,
    "host": "0.0.0.0",
    "cors": {
      "enabled": true,
      "origins": ["https://votre-application.com"]
    }
  },
  "offline": false,
  "jupyterServer": {
    "baseUrl": "https://jupyter.example.com:8888",
    "token": "token_secret_et_complexe",
    "timeout": 60000,
    "retryAttempts": 3,
    "retryDelay": 2000
  },
  "performance": {
    "cacheEnabled": true,
    "cacheMaxAge": 3600,
    "maxConcurrentOperations": 10
  },
  "logging": {
    "level": "info",
    "file": "/var/log/jupyter-mcp/server.log",
    "console": false
  },
  "tls": {
    "enabled": true,
    "key": "/etc/ssl/private/server.key",
    "cert": "/etc/ssl/certs/server.crt"
  }
}
```

Cette configuration est adaptée pour un environnement de production, avec HTTPS, des restrictions CORS, une journalisation dans un fichier et une connexion à un serveur Jupyter distant sécurisé.

### Configuration pour VSCode/Roo

```json
{
  "server": {
    "port": 3000,
    "host": "localhost"
  },
  "offline": true,
  "logging": {
    "level": "error",
    "console": true
  }
}
```

Cette configuration est adaptée pour une utilisation avec VSCode/Roo, en mode hors ligne pour éviter les erreurs de connexion au démarrage.
<!-- END_SECTION: configuration_examples -->

<!-- START_SECTION: best_practices -->
## Bonnes pratiques

### Sécurité

- Utilisez un token d'authentification fort pour le serveur Jupyter
- Limitez les origines CORS aux domaines de confiance en production
- Activez TLS/SSL en production
- Ne stockez pas le token d'authentification directement dans le fichier de configuration, utilisez plutôt une variable d'environnement

### Performance

- Activez le cache (`performance.cacheEnabled`) pour améliorer les performances des opérations répétées
- Ajustez `performance.maxConcurrentOperations` en fonction des capacités de votre système
- Limitez le nombre de cellules exécutées simultanément pour éviter de surcharger le serveur Jupyter

### Journalisation

- Utilisez le niveau `"info"` en production et `"debug"` en développement
- Configurez la rotation des journaux pour éviter que les fichiers de journal ne deviennent trop volumineux
- Assurez-vous que les répertoires de journaux existent et sont accessibles en écriture

### Déploiement

- Utilisez un gestionnaire de processus comme PM2 pour gérer le cycle de vie du serveur
- Mettez en place un proxy inverse (comme Nginx ou Apache) devant le serveur MCP Jupyter en production
- Configurez des limites de ressources appropriées pour éviter les abus
- Mettez en place une surveillance et des alertes pour détecter les problèmes
<!-- END_SECTION: best_practices -->

<!-- START_SECTION: next_steps -->
## Prochaines étapes

Maintenant que vous avez configuré le serveur MCP Jupyter, vous pouvez :

1. [Apprendre à utiliser le serveur](USAGE.md) avec des exemples pratiques
2. [Consulter le guide de dépannage](TROUBLESHOOTING.md) en cas de problèmes
3. [Explorer les cas d'utilisation avancés](../docs/jupyter-mcp-use-cases.md) pour tirer le meilleur parti du serveur
<!-- END_SECTION: next_steps -->