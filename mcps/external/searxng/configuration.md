# Configuration du MCP SearXNG

<!-- START_SECTION: introduction -->
## Introduction

Ce document détaille les options de configuration disponibles pour le serveur MCP SearXNG et comment les personnaliser selon vos besoins. Une configuration appropriée vous permettra d'optimiser les performances, la sécurité et la pertinence des résultats de recherche.
<!-- END_SECTION: introduction -->

<!-- START_SECTION: basic_configuration -->
## Configuration de base

Le serveur MCP SearXNG utilise un fichier de configuration au format JSON qui peut être personnalisé pour modifier son comportement. Par défaut, le serveur utilise une configuration intégrée, mais vous pouvez créer votre propre fichier de configuration.

### Création d'un fichier de configuration personnalisé

1. Créez un fichier nommé `config.json` dans le répertoire de configuration:
   - Windows: `%USERPROFILE%\.mcp-searxng\config.json`
   - macOS/Linux: `~/.mcp-searxng/config.json`

2. Ajoutez votre configuration au format JSON. Voici un exemple de configuration de base:

```json
{
  "server": {
    "port": 3000,
    "host": "127.0.0.1"
  },
  "searxng": {
    "instance": "https://searx.be",
    "timeout": 10000,
    "userAgent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36"
  },
  "logging": {
    "level": "info",
    "file": null
  }
}
```

### Spécification du fichier de configuration

Vous pouvez spécifier explicitement un fichier de configuration lors du démarrage du serveur:

```bash
mcp-searxng --config /chemin/vers/votre/config.json
```

Cette option est utile si vous souhaitez utiliser plusieurs configurations différentes ou si vous préférez stocker votre configuration à un emplacement différent.
<!-- END_SECTION: basic_configuration -->

<!-- START_SECTION: configuration_options -->
## Options de configuration

### Configuration du serveur

| Option | Description | Valeur par défaut |
|--------|-------------|-------------------|
| `server.port` | Port sur lequel le serveur écoute | `0` (port aléatoire) |
| `server.host` | Adresse IP sur laquelle le serveur écoute | `127.0.0.1` |

Un port à `0` signifie que le système attribuera automatiquement un port disponible. Cela est utile pour éviter les conflits de port, mais peut rendre plus difficile la configuration d'autres services pour communiquer avec le serveur MCP.

### Configuration de SearXNG

| Option | Description | Valeur par défaut |
|--------|-------------|-------------------|
| `searxng.instance` | URL de l'instance SearXNG à utiliser | `https://searx.be` |
| `searxng.instances` | Liste d'instances SearXNG à utiliser (pour la rotation) | `null` |
| `searxng.rotationStrategy` | Stratégie de rotation des instances (`round-robin`, `random`) | `round-robin` |
| `searxng.timeout` | Délai d'attente pour les requêtes (en ms) | `10000` |
| `searxng.userAgent` | User-Agent à utiliser pour les requêtes | *User-Agent de navigateur moderne* |
| `searxng.language` | Langue par défaut pour les recherches | `all` |
| `searxng.safesearch` | Niveau de SafeSearch (0: désactivé, 1: modéré, 2: strict) | `0` |

### Configuration de la journalisation

| Option | Description | Valeur par défaut |
|--------|-------------|-------------------|
| `logging.level` | Niveau de journalisation (`error`, `warn`, `info`, `debug`) | `info` |
| `logging.file` | Fichier de journalisation (null pour la console) | `null` |

### Configuration des limites

| Option | Description | Valeur par défaut |
|--------|-------------|-------------------|
| `limits.requestsPerMinute` | Nombre maximum de requêtes par minute | `10` |
| `limits.concurrentRequests` | Nombre maximum de requêtes simultanées | `2` |
| `limits.resultsPerPage` | Nombre maximum de résultats par page | `10` |

### Configuration du proxy

| Option | Description | Valeur par défaut |
|--------|-------------|-------------------|
| `proxy.url` | URL du proxy à utiliser | `null` |
| `proxy.noProxy` | Liste des hôtes à exclure du proxy | `["localhost", "127.0.0.1"]` |
<!-- END_SECTION: configuration_options -->

<!-- START_SECTION: searxng_instances -->
## Utilisation d'instances SearXNG alternatives

Par défaut, le serveur MCP SearXNG utilise l'instance publique `https://searx.be`. Cependant, vous pouvez utiliser n'importe quelle instance SearXNG, y compris une instance que vous hébergez vous-même.

### Instances publiques recommandées

Voici quelques instances publiques SearXNG fiables:

- `https://searx.be`
- `https://search.mdosch.de`
- `https://search.disroot.org`
- `https://searx.tiekoetter.com`
- `https://search.ononoki.org`

> **Note**: La disponibilité et la fiabilité des instances publiques peuvent varier dans le temps. Vérifiez régulièrement que l'instance que vous utilisez est toujours opérationnelle.

### Configuration d'une instance unique

Pour utiliser une instance SearXNG spécifique:

```json
{
  "searxng": {
    "instance": "https://search.mdosch.de"
  }
}
```

### Utilisation d'une instance locale

Si vous hébergez votre propre instance SearXNG, vous pouvez la configurer comme suit:

```json
{
  "searxng": {
    "instance": "http://localhost:8080"
  }
}
```

Héberger votre propre instance SearXNG offre plusieurs avantages:
- Contrôle total sur la configuration et les moteurs de recherche utilisés
- Pas de limitations de taux imposées par des instances publiques
- Confidentialité accrue car les requêtes ne quittent pas votre réseau
<!-- END_SECTION: searxng_instances -->

<!-- START_SECTION: advanced_configuration -->
## Configuration avancée

### Rotation d'instances

Pour améliorer la fiabilité et éviter les limitations de taux, vous pouvez configurer plusieurs instances SearXNG et le serveur alternera entre elles:

```json
{
  "searxng": {
    "instances": [
      "https://searx.be",
      "https://search.mdosch.de",
      "https://search.disroot.org"
    ],
    "rotationStrategy": "round-robin"
  }
}
```

Stratégies de rotation disponibles:
- `round-robin`: Utilise les instances à tour de rôle
- `random`: Choisit une instance aléatoire pour chaque requête

### Configuration du proxy

Si vous êtes derrière un proxy ou si vous souhaitez acheminer les requêtes via un proxy pour des raisons de confidentialité:

```json
{
  "proxy": {
    "url": "http://username:password@proxy.example.com:8080",
    "noProxy": ["localhost", "127.0.0.1"]
  }
}
```

### Limites de requêtes

Pour éviter de surcharger les instances SearXNG et pour respecter leurs limitations de taux:

```json
{
  "limits": {
    "requestsPerMinute": 10,
    "concurrentRequests": 2,
    "resultsPerPage": 10
  }
}
```

### Configuration du User-Agent

Certaines instances SearXNG peuvent bloquer les requêtes avec des User-Agents non standard. Vous pouvez configurer un User-Agent spécifique:

```json
{
  "searxng": {
    "userAgent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36"
  }
}
```

### Journalisation avancée

Pour un débogage détaillé ou pour conserver un historique des requêtes:

```json
{
  "logging": {
    "level": "debug",
    "file": "searxng-mcp.log",
    "rotation": {
      "maxSize": "10m",
      "maxFiles": 5
    }
  }
}
```
<!-- END_SECTION: advanced_configuration -->

<!-- START_SECTION: environment_variables -->
## Variables d'environnement

Le MCP SearXNG prend également en charge la configuration via des variables d'environnement, ce qui peut être utile pour les déploiements en conteneurs ou pour éviter de stocker des informations sensibles dans des fichiers:

| Variable | Description | Exemple |
|----------|-------------|---------|
| `MCP_SEARXNG_PORT` | Port du serveur | `MCP_SEARXNG_PORT=3000` |
| `MCP_SEARXNG_HOST` | Hôte du serveur | `MCP_SEARXNG_HOST=0.0.0.0` |
| `MCP_SEARXNG_INSTANCE` | URL de l'instance SearXNG | `MCP_SEARXNG_INSTANCE=https://searx.be` |
| `MCP_SEARXNG_TIMEOUT` | Timeout en ms | `MCP_SEARXNG_TIMEOUT=15000` |
| `MCP_SEARXNG_LOG_LEVEL` | Niveau de journalisation | `MCP_SEARXNG_LOG_LEVEL=debug` |
| `MCP_SEARXNG_LOG_FILE` | Fichier de journalisation | `MCP_SEARXNG_LOG_FILE=/var/log/searxng-mcp.log` |
| `HTTP_PROXY` | URL du proxy HTTP | `HTTP_PROXY=http://proxy.example.com:8080` |
| `HTTPS_PROXY` | URL du proxy HTTPS | `HTTPS_PROXY=http://proxy.example.com:8080` |
| `NO_PROXY` | Hôtes à exclure du proxy | `NO_PROXY=localhost,127.0.0.1` |

Les variables d'environnement ont priorité sur les valeurs du fichier de configuration.
<!-- END_SECTION: environment_variables -->

<!-- START_SECTION: roo_integration -->
## Intégration avec Roo

Pour que Roo utilise votre configuration personnalisée, assurez-vous que le serveur MCP SearXNG est correctement configuré dans les paramètres de Roo:

```json
{
  "mcpServers": [
    {
      "name": "searxng",
      "type": "stdio",
      "command": "cmd",
      "args": ["/c", "mcp-searxng", "--config", "/chemin/vers/config.json"],
      "enabled": true,
      "autoStart": true,
      "description": "Serveur MCP SearXNG pour les recherches web"
    }
  ]
}
```

Vous pouvez également passer des options de configuration directement via les arguments:

```json
{
  "mcpServers": [
    {
      "name": "searxng",
      "type": "stdio",
      "command": "cmd",
      "args": [
        "/c", 
        "mcp-searxng", 
        "--instance", 
        "https://search.mdosch.de",
        "--timeout",
        "15000"
      ],
      "enabled": true,
      "autoStart": true,
      "description": "Serveur MCP SearXNG pour les recherches web"
    }
  ]
}
```
<!-- END_SECTION: roo_integration -->

<!-- START_SECTION: security_considerations -->
## Considérations de sécurité

### Protection de la vie privée

SearXNG est conçu pour respecter la vie privée des utilisateurs, mais certaines précautions supplémentaires peuvent être prises:

1. **Utilisez HTTPS** pour les instances SearXNG afin de chiffrer les requêtes
2. **Évitez de stocker des logs** contenant des requêtes de recherche sensibles
3. **Utilisez un proxy** pour masquer votre adresse IP lors des requêtes

### Limitations d'accès

Si vous hébergez votre propre instance SearXNG ou si vous partagez votre configuration MCP:

1. **Limitez l'accès au serveur** en le liant uniquement à `127.0.0.1`
2. **Utilisez un pare-feu** pour bloquer les connexions non autorisées
3. **Évitez d'exposer le serveur MCP** sur Internet

### Authentification

Si vous utilisez une instance SearXNG qui nécessite une authentification:

```json
{
  "searxng": {
    "instance": "https://instance-privee.example.com",
    "auth": {
      "username": "utilisateur",
      "password": "mot_de_passe"
    }
  }
}
```

> **Important**: Ne stockez pas de mots de passe en texte clair dans des fichiers de configuration partagés ou des dépôts publics. Utilisez plutôt des variables d'environnement ou des coffres-forts de secrets.
<!-- END_SECTION: security_considerations -->

<!-- START_SECTION: troubleshooting -->
## Résolution des problèmes

### Problèmes d'accès aux instances SearXNG

Si vous rencontrez des problèmes pour accéder à une instance SearXNG:

1. Vérifiez que l'instance est accessible dans votre navigateur
2. Essayez une autre instance
3. Vérifiez les paramètres de proxy de votre réseau
4. Augmentez la valeur de `searxng.timeout` si l'instance est lente

### Journalisation détaillée

Pour obtenir plus d'informations sur les problèmes, activez la journalisation détaillée:

```json
{
  "logging": {
    "level": "debug",
    "file": "searxng-mcp.log"
  }
}
```

Cela créera un fichier journal détaillé que vous pourrez consulter pour diagnostiquer les problèmes.

### Démarrage en mode débogage

Vous pouvez également démarrer le serveur en mode débogage:

```bash
mcp-searxng --debug
```

Cette option affichera des informations détaillées sur le fonctionnement du serveur, les requêtes envoyées et les réponses reçues.

Pour une résolution plus détaillée des problèmes, consultez le fichier [TROUBLESHOOTING.md](./TROUBLESHOOTING.md).
<!-- END_SECTION: troubleshooting -->

<!-- START_SECTION: next_steps -->
## Prochaines étapes

Maintenant que vous avez configuré le MCP SearXNG, vous pouvez:

1. [Apprendre à utiliser le MCP SearXNG](./USAGE.md)
2. [Explorer les cas d'utilisation avancés](./USAGE.md#cas-dutilisation)
3. [Résoudre les problèmes courants](./TROUBLESHOOTING.md)
<!-- END_SECTION: next_steps -->