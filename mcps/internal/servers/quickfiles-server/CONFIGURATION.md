<!-- START_SECTION: metadata -->
---
title: "Configuration du serveur MCP QuickFiles"
description: "Options de configuration détaillées pour le serveur MCP QuickFiles"
tags: #configuration #quickfiles #mcp #guide #security #performance #logging
date_created: "2025-05-14"
date_updated: "2025-05-14"
version: "1.0.0"
author: "Équipe MCP"
---
<!-- END_SECTION: metadata -->

# Configuration du serveur MCP QuickFiles

<!-- START_SECTION: introduction -->
Ce document détaille les options de configuration disponibles pour le serveur MCP QuickFiles. La configuration appropriée vous permettra d'optimiser les performances, de sécuriser l'accès aux fichiers et d'adapter le comportement du serveur à vos besoins spécifiques.
<!-- END_SECTION: introduction -->

<!-- START_SECTION: config_file -->
## Fichier de configuration

Le serveur QuickFiles utilise un fichier de configuration au format JSON. Par défaut, ce fichier est nommé `config.json` et doit être placé dans le répertoire racine du serveur.

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
  "security": {
    "allowedPaths": [
      "/chemin/vers/repertoire1",
      "/chemin/vers/repertoire2"
    ],
    "disallowedPatterns": [
      "\\.env$",
      "\\.git/",
      "node_modules/"
    ]
  },
  "performance": {
    "maxFileSizeBytes": 10485760,
    "maxTotalFilesBytes": 104857600,
    "maxConcurrentOperations": 10,
    "cacheEnabled": true,
    "cacheMaxAge": 300
  },
  "logging": {
    "level": "info",
    "file": "quickfiles.log",
    "console": true
  }
}
```

### Emplacement du fichier de configuration

Vous pouvez spécifier un emplacement personnalisé pour le fichier de configuration en utilisant l'option de ligne de commande `--config` :

```bash
node dist/index.js --config /chemin/vers/mon-config.json
```

Ou en définissant la variable d'environnement `QUICKFILES_CONFIG` :

```bash
export QUICKFILES_CONFIG=/chemin/vers/mon-config.json
node dist/index.js
```
<!-- END_SECTION: config_file -->

<!-- START_SECTION: server_options -->
## Options du serveur

### `server.port`

- **Type** : Nombre
- **Défaut** : `3000`
- **Description** : Port sur lequel le serveur MCP QuickFiles écoutera les connexions.

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

<!-- START_SECTION: security_options -->
## Options de sécurité

### `security.allowedPaths`

- **Type** : Tableau de chaînes
- **Défaut** : `[]` (aucune restriction)
- **Description** : Liste des chemins de répertoires auxquels le serveur est autorisé à accéder. Si vide, aucune restriction n'est appliquée.

### `security.disallowedPatterns`

- **Type** : Tableau de chaînes (expressions régulières)
- **Défaut** : `["\\.env$", "\\.git/", "node_modules/"]`
- **Description** : Liste des motifs de fichiers ou répertoires auxquels le serveur n'est pas autorisé à accéder, même s'ils se trouvent dans un chemin autorisé.

### Exemple de configuration de sécurité

```json
"security": {
  "allowedPaths": [
    "/home/user/projects",
    "/var/data/shared"
  ],
  "disallowedPatterns": [
    "\\.env$",
    "\\.git/",
    "node_modules/",
    "passwords\\.txt$",
    "config\\.json$"
  ]
}
```

Cette configuration permet au serveur d'accéder uniquement aux répertoires `/home/user/projects` et `/var/data/shared`, tout en interdisant l'accès aux fichiers `.env`, aux répertoires `.git` et `node_modules`, ainsi qu'aux fichiers `passwords.txt` et `config.json`.
<!-- END_SECTION: security_options -->

<!-- START_SECTION: performance_options -->
## Options de performance

### `performance.maxFileSizeBytes`

- **Type** : Nombre
- **Défaut** : `10485760` (10 Mo)
- **Description** : Taille maximale en octets d'un fichier individuel que le serveur peut lire. Les fichiers plus volumineux seront tronqués.

### `performance.maxTotalFilesBytes`

- **Type** : Nombre
- **Défaut** : `104857600` (100 Mo)
- **Description** : Taille totale maximale en octets de tous les fichiers que le serveur peut lire en une seule opération.

### `performance.maxConcurrentOperations`

- **Type** : Nombre
- **Défaut** : `10`
- **Description** : Nombre maximal d'opérations de fichier concurrentes que le serveur peut exécuter.

### `performance.cacheEnabled`

- **Type** : Booléen
- **Défaut** : `true`
- **Description** : Active ou désactive le cache des résultats de listage de répertoires et de lecture de fichiers.

### `performance.cacheMaxAge`

- **Type** : Nombre
- **Défaut** : `300` (5 minutes)
- **Description** : Durée maximale en secondes pendant laquelle les résultats sont conservés dans le cache.

### Exemple de configuration de performance

```json
"performance": {
  "maxFileSizeBytes": 20971520,
  "maxTotalFilesBytes": 209715200,
  "maxConcurrentOperations": 20,
  "cacheEnabled": true,
  "cacheMaxAge": 600
}
```

Cette configuration augmente les limites de taille de fichier à 20 Mo par fichier et 200 Mo au total, permet 20 opérations concurrentes et configure le cache pour conserver les résultats pendant 10 minutes.
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
- **Défaut** : `"quickfiles.log"`
- **Description** : Nom du fichier de journal. Si vide ou non défini, la journalisation dans un fichier est désactivée.

### `logging.console`

- **Type** : Booléen
- **Défaut** : `true`
- **Description** : Active ou désactive la journalisation dans la console.

### Exemple de configuration de journalisation

```json
"logging": {
  "level": "debug",
  "file": "logs/quickfiles.log",
  "console": true
}
```

Cette configuration active la journalisation au niveau de détail "debug", écrit les journaux dans le fichier `logs/quickfiles.log` et affiche également les journaux dans la console.
<!-- END_SECTION: logging_options -->

<!-- START_SECTION: environment_variables -->
## Variables d'environnement

Vous pouvez également configurer le serveur QuickFiles en utilisant des variables d'environnement. Les variables d'environnement ont priorité sur les valeurs du fichier de configuration.

| Variable d'environnement | Description |
|--------------------------|-------------|
| `QUICKFILES_PORT` | Port du serveur |
| `QUICKFILES_HOST` | Hôte du serveur |
| `QUICKFILES_ALLOWED_PATHS` | Chemins autorisés (séparés par des virgules) |
| `QUICKFILES_MAX_FILE_SIZE` | Taille maximale de fichier en octets |
| `QUICKFILES_LOG_LEVEL` | Niveau de journalisation |
| `QUICKFILES_CONFIG` | Chemin vers le fichier de configuration |

### Exemple d'utilisation des variables d'environnement

```bash
export QUICKFILES_PORT=4000
export QUICKFILES_HOST=0.0.0.0
export QUICKFILES_ALLOWED_PATHS=/home/user/projects,/var/data/shared
export QUICKFILES_MAX_FILE_SIZE=20971520
export QUICKFILES_LOG_LEVEL=debug
node dist/index.js
```
<!-- END_SECTION: environment_variables -->

<!-- START_SECTION: command_line_options -->
## Options de ligne de commande

Le serveur QuickFiles accepte également des options de ligne de commande qui ont priorité sur les variables d'environnement et les valeurs du fichier de configuration.

| Option | Description |
|--------|-------------|
| `--port <port>` | Port du serveur |
| `--host <host>` | Hôte du serveur |
| `--config <path>` | Chemin vers le fichier de configuration |
| `--log-level <level>` | Niveau de journalisation |
| `--allowed-paths <paths>` | Chemins autorisés (séparés par des virgules) |
| `--help` | Affiche l'aide |

### Exemple d'utilisation des options de ligne de commande

```bash
node dist/index.js --port 4000 --host 0.0.0.0 --log-level debug --allowed-paths /home/user/projects,/var/data/shared
```
<!-- END_SECTION: command_line_options -->

<!-- START_SECTION: advanced_configuration -->
## Configuration avancée

### Configuration des outils MCP

Vous pouvez configurer des paramètres spécifiques pour chaque outil MCP exposé par le serveur QuickFiles :

```json
"tools": {
  "read_multiple_files": {
    "defaultMaxLinesPerFile": 2000,
    "defaultMaxTotalLines": 5000,
    "defaultShowLineNumbers": true
  },
  "list_directory_contents": {
    "defaultMaxLines": 2000,
    "defaultSortBy": "name",
    "defaultSortOrder": "asc"
  },
  "delete_files": {
    "confirmationRequired": true,
    "maxFilesPerOperation": 100
  },
  "edit_multiple_files": {
    "maxFilesPerOperation": 50,
    "maxDiffsPerFile": 20,
    "backupEnabled": true
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
  "security": {
    "allowedPaths": [
      "/chemin/vers/projets"
    ]
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
  "security": {
    "allowedPaths": [
      "/var/data/app"
    ],
    "disallowedPatterns": [
      "\\.env$",
      "\\.git/",
      "node_modules/",
      "secrets/"
    ]
  },
  "performance": {
    "maxFileSizeBytes": 5242880,
    "maxTotalFilesBytes": 52428800,
    "maxConcurrentOperations": 5,
    "cacheEnabled": true,
    "cacheMaxAge": 3600
  },
  "logging": {
    "level": "info",
    "file": "/var/log/quickfiles/server.log",
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

### Sécurité

- Limitez l'accès aux répertoires nécessaires uniquement en utilisant `security.allowedPaths`
- Utilisez des expressions régulières précises dans `security.disallowedPatterns` pour bloquer l'accès aux fichiers sensibles
- Activez TLS/SSL en production
- Limitez les origines CORS aux domaines de confiance en production

### Performance

- Ajustez `performance.maxFileSizeBytes` et `performance.maxTotalFilesBytes` en fonction de vos besoins et des ressources disponibles
- Activez le cache (`performance.cacheEnabled`) pour améliorer les performances des opérations répétées
- Ajustez `performance.maxConcurrentOperations` en fonction des capacités de votre système

### Journalisation

- Utilisez le niveau `"info"` en production et `"debug"` en développement
- Configurez la rotation des journaux pour éviter que les fichiers de journal ne deviennent trop volumineux
- Assurez-vous que les répertoires de journaux existent et sont accessibles en écriture

### Déploiement

- Utilisez un gestionnaire de processus comme PM2 pour gérer le cycle de vie du serveur
- Mettez en place un proxy inverse (comme Nginx) devant le serveur QuickFiles en production
- Configurez des limites de ressources appropriées pour éviter les abus
<!-- END_SECTION: best_practices -->

<!-- START_SECTION: next_steps -->
## Prochaines étapes

Maintenant que vous avez configuré le serveur QuickFiles, vous pouvez :

1. [Apprendre à utiliser le serveur](USAGE.md) avec des exemples pratiques
2. [Consulter le guide de dépannage](TROUBLESHOOTING.md) en cas de problèmes
3. [Explorer les cas d'utilisation avancés](../docs/quickfiles-use-cases.md) pour tirer le meilleur parti du serveur
<!-- END_SECTION: next_steps -->

<!-- START_SECTION: navigation -->
## Navigation

- [Index principal](../../../INDEX.md)
- [Index des MCPs internes](../../INDEX.md)
- [Documentation QuickFiles](./README.md)
- [Installation](./INSTALLATION.md)
- [Utilisation](./USAGE.md)
- [Dépannage](./TROUBLESHOOTING.md)
- [Guide de recherche](../../../SEARCH.md)
<!-- END_SECTION: navigation -->