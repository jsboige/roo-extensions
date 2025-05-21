# Configuration du serveur MCP JinaNavigator

<!-- START_SECTION: introduction -->
Ce document détaille les options de configuration disponibles pour le serveur MCP JinaNavigator. La configuration appropriée vous permettra d'optimiser les performances, de gérer les connexions à l'API Jina et d'adapter le comportement du serveur à vos besoins spécifiques.
<!-- END_SECTION: introduction -->

<!-- START_SECTION: config_file -->
## Fichier de configuration

Le serveur JinaNavigator utilise un fichier de configuration au format JSON. Par défaut, ce fichier est nommé `config.json` et doit être placé dans le répertoire racine du serveur.

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
  "jina": {
    "apiUrl": "https://r.jina.ai/",
    "apiKey": "",
    "timeout": 30000,
    "maxRetries": 3,
    "concurrentRequests": 5
  },
  "performance": {
    "cacheEnabled": true,
    "cacheMaxAge": 3600,
    "maxUrlsPerRequest": 50
  },
  "logging": {
    "level": "info",
    "file": "jinavigator.log",
    "console": true
  }
}
```

### Emplacement du fichier de configuration

Vous pouvez spécifier un emplacement personnalisé pour le fichier de configuration en utilisant l'option de ligne de commande `--config` :

```bash
node dist/index.js --config /chemin/vers/mon-config.json
```

Ou en définissant la variable d'environnement `JINAVIGATOR_CONFIG` :

```bash
export JINAVIGATOR_CONFIG=/chemin/vers/mon-config.json
node dist/index.js
```
<!-- END_SECTION: config_file -->

<!-- START_SECTION: server_options -->
## Options du serveur

### `server.port`

- **Type** : Nombre
- **Défaut** : `3000`
- **Description** : Port sur lequel le serveur MCP JinaNavigator écoutera les connexions.

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

<!-- START_SECTION: jina_options -->
## Options de l'API Jina

### `jina.apiUrl`

- **Type** : Chaîne
- **Défaut** : `"https://r.jina.ai/"`
- **Description** : URL de l'API Jina utilisée pour convertir les pages web en Markdown.

### `jina.apiKey`

- **Type** : Chaîne
- **Défaut** : `""`
- **Description** : Clé API pour l'authentification auprès de l'API Jina. Laissez vide si aucune clé n'est nécessaire.

### `jina.timeout`

- **Type** : Nombre
- **Défaut** : `30000` (30 secondes)
- **Description** : Délai d'attente en millisecondes avant qu'une requête à l'API Jina ne soit considérée comme ayant échoué.

### `jina.maxRetries`

- **Type** : Nombre
- **Défaut** : `3`
- **Description** : Nombre maximal de tentatives de connexion à l'API Jina en cas d'échec.

### `jina.concurrentRequests`

- **Type** : Nombre
- **Défaut** : `5`
- **Description** : Nombre maximal de requêtes simultanées à l'API Jina.

### Exemple de configuration de l'API Jina

```json
"jina": {
  "apiUrl": "https://r.jina.ai/",
  "apiKey": "votre_clé_api_ici",
  "timeout": 60000,
  "maxRetries": 5,
  "concurrentRequests": 10
}
```

Cette configuration utilise une clé API personnalisée, augmente le timeout à 60 secondes, définit 5 tentatives de connexion et permet 10 requêtes simultanées à l'API Jina.
<!-- END_SECTION: jina_options -->

<!-- START_SECTION: performance_options -->
## Options de performance

### `performance.cacheEnabled`

- **Type** : Booléen
- **Défaut** : `true`
- **Description** : Active ou désactive le cache des résultats de conversion. Le cache permet d'éviter de reconvertir des pages web déjà converties récemment.

### `performance.cacheMaxAge`

- **Type** : Nombre
- **Défaut** : `3600` (1 heure)
- **Description** : Durée maximale en secondes pendant laquelle les résultats sont conservés dans le cache.

### `performance.maxUrlsPerRequest`

- **Type** : Nombre
- **Défaut** : `50`
- **Description** : Nombre maximal d'URLs pouvant être traitées en une seule requête avec l'outil `multi_convert`.

### Exemple de configuration de performance

```json
"performance": {
  "cacheEnabled": true,
  "cacheMaxAge": 7200,
  "maxUrlsPerRequest": 25
}
```

Cette configuration active le cache avec une durée de vie de 2 heures et limite le nombre d'URLs par requête à 25.
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
- **Défaut** : `"jinavigator.log"`
- **Description** : Nom du fichier de journal. Si vide ou non défini, la journalisation dans un fichier est désactivée.

### `logging.console`

- **Type** : Booléen
- **Défaut** : `true`
- **Description** : Active ou désactive la journalisation dans la console.

### Exemple de configuration de journalisation

```json
"logging": {
  "level": "debug",
  "file": "logs/jinavigator.log",
  "console": true
}
```

Cette configuration active la journalisation au niveau de détail "debug", écrit les journaux dans le fichier `logs/jinavigator.log` et affiche également les journaux dans la console.
<!-- END_SECTION: logging_options -->

<!-- START_SECTION: environment_variables -->
## Variables d'environnement

Vous pouvez également configurer le serveur JinaNavigator en utilisant des variables d'environnement. Les variables d'environnement ont priorité sur les valeurs du fichier de configuration.

| Variable d'environnement | Description |
|--------------------------|-------------|
| `JINAVIGATOR_PORT` | Port du serveur |
| `JINAVIGATOR_HOST` | Hôte du serveur |
| `JINAVIGATOR_API_URL` | URL de l'API Jina |
| `JINAVIGATOR_API_KEY` | Clé API pour l'API Jina |
| `JINAVIGATOR_TIMEOUT` | Timeout des requêtes en millisecondes |
| `JINAVIGATOR_MAX_RETRIES` | Nombre maximal de tentatives |
| `JINAVIGATOR_CACHE_ENABLED` | Active ou désactive le cache (true/false) |
| `JINAVIGATOR_LOG_LEVEL` | Niveau de journalisation |
| `JINAVIGATOR_CONFIG` | Chemin vers le fichier de configuration |

### Exemple d'utilisation des variables d'environnement

```bash
export JINAVIGATOR_PORT=4000
export JINAVIGATOR_HOST=0.0.0.0
export JINAVIGATOR_API_KEY=votre_clé_api_ici
export JINAVIGATOR_TIMEOUT=60000
export JINAVIGATOR_LOG_LEVEL=debug
node dist/index.js
```
<!-- END_SECTION: environment_variables -->

<!-- START_SECTION: command_line_options -->
## Options de ligne de commande

Le serveur JinaNavigator accepte également des options de ligne de commande qui ont priorité sur les variables d'environnement et les valeurs du fichier de configuration.

| Option | Description |
|--------|-------------|
| `--port <port>` | Port du serveur |
| `--host <host>` | Hôte du serveur |
| `--config <path>` | Chemin vers le fichier de configuration |
| `--log-level <level>` | Niveau de journalisation |
| `--api-url <url>` | URL de l'API Jina |
| `--api-key <key>` | Clé API pour l'API Jina |
| `--help` | Affiche l'aide |

### Exemple d'utilisation des options de ligne de commande

```bash
node dist/index.js --port 4000 --host 0.0.0.0 --log-level debug --api-key votre_clé_api_ici
```
<!-- END_SECTION: command_line_options -->

<!-- START_SECTION: advanced_configuration -->
## Configuration avancée

### Configuration des outils MCP

Vous pouvez configurer des paramètres spécifiques pour chaque outil MCP exposé par le serveur JinaNavigator :

```json
"tools": {
  "convert_web_to_markdown": {
    "defaultTimeout": 30000,
    "maxContentLength": 1000000
  },
  "multi_convert": {
    "maxUrls": 25,
    "parallelRequests": 5
  },
  "access_jina_resource": {
    "defaultTimeout": 30000,
    "cacheResults": true
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

### Configuration du proxy

Si vous êtes derrière un proxy, vous pouvez le configurer dans le fichier de configuration :

```json
"proxy": {
  "http": "http://proxy.example.com:8080",
  "https": "http://proxy.example.com:8080",
  "no_proxy": "localhost,127.0.0.1"
}
```
<!-- END_SECTION: advanced_configuration -->

<!-- START_SECTION: configuration_examples -->
## Exemples de configuration

### Configuration minimale

```json
{
  "server": {
    "port": 3000,
    "host": "localhost"
  }
}
```

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
  "jina": {
    "timeout": 60000,
    "maxRetries": 5
  },
  "logging": {
    "level": "debug",
    "console": true
  }
}
```

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
  "jina": {
    "apiKey": "votre_clé_api_ici",
    "timeout": 30000,
    "maxRetries": 3,
    "concurrentRequests": 10
  },
  "performance": {
    "cacheEnabled": true,
    "cacheMaxAge": 7200,
    "maxUrlsPerRequest": 25
  },
  "logging": {
    "level": "info",
    "file": "/var/log/jinavigator/server.log",
    "console": false
  },
  "tls": {
    "enabled": true,
    "key": "/etc/ssl/private/server.key",
    "cert": "/etc/ssl/certs/server.crt"
  }
}
```
<!-- END_SECTION: configuration_examples -->

<!-- START_SECTION: best_practices -->
## Bonnes pratiques

### Performance

- Activez le cache (`performance.cacheEnabled`) pour améliorer les performances des opérations répétées
- Ajustez `jina.concurrentRequests` en fonction des capacités de votre système et des limites de l'API Jina
- Limitez `performance.maxUrlsPerRequest` à une valeur raisonnable pour éviter les timeouts et les erreurs de mémoire
- Utilisez des extraits de contenu avec `start_line` et `end_line` pour les pages web volumineuses

### Sécurité

- Utilisez HTTPS en production en configurant TLS/SSL
- Limitez les origines CORS aux domaines de confiance en production
- Ne stockez pas votre clé API Jina directement dans le fichier de configuration, utilisez plutôt une variable d'environnement
- Mettez en place un proxy inverse (comme Nginx) devant le serveur JinaNavigator en production

### Journalisation

- Utilisez le niveau `"info"` en production et `"debug"` en développement
- Configurez la rotation des journaux pour éviter que les fichiers de journal ne deviennent trop volumineux
- Assurez-vous que les répertoires de journaux existent et sont accessibles en écriture

### Déploiement

- Utilisez un gestionnaire de processus comme PM2 pour gérer le cycle de vie du serveur
- Configurez des limites de ressources appropriées pour éviter les abus
- Mettez en place une surveillance et des alertes pour détecter les problèmes
<!-- END_SECTION: best_practices -->

<!-- START_SECTION: next_steps -->
## Prochaines étapes

Maintenant que vous avez configuré le serveur JinaNavigator, vous pouvez :

1. [Apprendre à utiliser le serveur](USAGE.md) avec des exemples pratiques
2. [Consulter le guide de dépannage](TROUBLESHOOTING.md) en cas de problèmes
3. [Explorer les cas d'utilisation avancés](../docs/jinavigator-use-cases.md) pour tirer le meilleur parti du serveur
<!-- END_SECTION: next_steps -->