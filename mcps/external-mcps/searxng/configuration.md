# Guide de configuration du serveur MCP SearXNG

Ce guide détaille les options de configuration disponibles pour le serveur MCP SearXNG et comment les personnaliser selon vos besoins.

## Configuration de base

Le serveur MCP SearXNG utilise un fichier de configuration qui peut être personnalisé pour modifier son comportement. Par défaut, le serveur utilise une configuration intégrée, mais vous pouvez créer votre propre fichier de configuration.

### Création d'un fichier de configuration personnalisé

1. Créez un fichier nommé `searxng-config.json` dans votre répertoire personnel :
   - Windows : `%USERPROFILE%\.mcp-searxng\config.json`
   - macOS/Linux : `~/.mcp-searxng/config.json`

2. Ajoutez votre configuration au format JSON. Voici un exemple de configuration de base :

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

## Options de configuration

### Configuration du serveur

| Option | Description | Valeur par défaut |
|--------|-------------|-------------------|
| `server.port` | Port sur lequel le serveur écoute | `0` (port aléatoire) |
| `server.host` | Adresse IP sur laquelle le serveur écoute | `127.0.0.1` |

### Configuration de SearXNG

| Option | Description | Valeur par défaut |
|--------|-------------|-------------------|
| `searxng.instance` | URL de l'instance SearXNG à utiliser | `https://searx.be` |
| `searxng.timeout` | Délai d'attente pour les requêtes (en ms) | `10000` |
| `searxng.userAgent` | User-Agent à utiliser pour les requêtes | *User-Agent de navigateur moderne* |
| `searxng.language` | Langue par défaut pour les recherches | `all` |
| `searxng.safesearch` | Niveau de SafeSearch (0: désactivé, 1: modéré, 2: strict) | `0` |

### Configuration de la journalisation

| Option | Description | Valeur par défaut |
|--------|-------------|-------------------|
| `logging.level` | Niveau de journalisation (`error`, `warn`, `info`, `debug`) | `info` |
| `logging.file` | Fichier de journalisation (null pour la console) | `null` |

## Utilisation d'instances SearXNG alternatives

Par défaut, le serveur MCP SearXNG utilise l'instance publique `https://searx.be`. Cependant, vous pouvez utiliser n'importe quelle instance SearXNG, y compris une instance que vous hébergez vous-même.

### Instances publiques recommandées

- `https://searx.be`
- `https://search.mdosch.de`
- `https://search.disroot.org`
- `https://searx.tiekoetter.com`

### Utilisation d'une instance locale

Si vous hébergez votre propre instance SearXNG, vous pouvez la configurer comme suit :

```json
{
  "searxng": {
    "instance": "http://localhost:8080"
  }
}
```

## Configuration avancée

### Proxy

Vous pouvez configurer un proxy pour toutes les requêtes :

```json
{
  "proxy": {
    "url": "http://username:password@proxy.example.com:8080",
    "noProxy": ["localhost", "127.0.0.1"]
  }
}
```

### Rotation d'instances

Vous pouvez configurer plusieurs instances SearXNG et le serveur alternera entre elles :

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

### Limites de requêtes

Vous pouvez configurer des limites pour éviter de surcharger les instances SearXNG :

```json
{
  "limits": {
    "requestsPerMinute": 10,
    "concurrentRequests": 2,
    "resultsPerPage": 10
  }
}
```

## Intégration avec Roo

Pour que Roo utilise votre configuration personnalisée, assurez-vous que le serveur MCP SearXNG est correctement configuré dans les paramètres de Roo :

```json
{
  "name": "searxng",
  "type": "stdio",
  "command": "cmd /c mcp-searxng",
  "enabled": true,
  "autoStart": true
}
```

## Résolution des problèmes

### Problèmes d'accès aux instances SearXNG

Si vous rencontrez des problèmes pour accéder à une instance SearXNG :

1. Vérifiez que l'instance est accessible dans votre navigateur
2. Essayez une autre instance
3. Vérifiez les paramètres de proxy de votre réseau
4. Augmentez la valeur de `searxng.timeout` si l'instance est lente

### Journalisation détaillée

Pour obtenir plus d'informations sur les problèmes, activez la journalisation détaillée :

```json
{
  "logging": {
    "level": "debug",
    "file": "searxng-mcp.log"
  }
}
```

Cela créera un fichier journal détaillé que vous pourrez consulter pour diagnostiquer les problèmes.