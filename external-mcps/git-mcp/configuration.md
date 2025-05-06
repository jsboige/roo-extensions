# Configuration du Git MCP Server

Ce document détaille les options de configuration disponibles pour le Git MCP Server.

## Variables d'environnement

Le Git MCP Server peut être configuré à l'aide de variables d'environnement. Vous pouvez les définir dans un fichier `.env` dans le répertoire du serveur ou les spécifier directement dans votre configuration Roo.

### Variables principales

| Variable | Description | Valeur par défaut |
|----------|-------------|-------------------|
| `MCP_TRANSPORT_TYPE` | Type de transport : `stdio` ou `http` | `stdio` |
| `MCP_HTTP_PORT` | Port pour le serveur HTTP (si `MCP_TRANSPORT_TYPE=http`) | `3010` |
| `MCP_HTTP_HOST` | Adresse hôte pour le serveur HTTP (si `MCP_TRANSPORT_TYPE=http`) | `127.0.0.1` |
| `MCP_ALLOWED_ORIGINS` | Liste d'origines autorisées pour CORS, séparées par des virgules (si `MCP_TRANSPORT_TYPE=http`) | (aucune) |
| `MCP_LOG_LEVEL` | Niveau de journalisation (`debug`, `info`, `notice`, `warning`, `error`, `crit`, `alert`, `emerg`) | `info` |
| `GIT_SIGN_COMMITS` | Activer la signature des commits (`true` ou `false`) | `false` |

## Configuration dans Roo

### Configuration avec transport stdio (par défaut)

```json
{
  "git": {
    "command": "node",
    "args": ["/chemin/vers/git-mcp-server/dist/index.js"],
    "env": {
      "MCP_TRANSPORT_TYPE": "stdio",
      "MCP_LOG_LEVEL": "info",
      "GIT_SIGN_COMMITS": "false"
    },
    "disabled": false
  }
}
```

### Configuration avec transport HTTP

```json
{
  "git": {
    "command": "node",
    "args": ["/chemin/vers/git-mcp-server/dist/index.js"],
    "env": {
      "MCP_TRANSPORT_TYPE": "http",
      "MCP_HTTP_PORT": "3010",
      "MCP_HTTP_HOST": "127.0.0.1",
      "MCP_LOG_LEVEL": "info",
      "GIT_SIGN_COMMITS": "false"
    },
    "disabled": false
  }
}
```

## Répertoire de travail par défaut

Par défaut, le Git MCP Server utilise le répertoire courant comme répertoire de travail pour les opérations Git. Vous pouvez définir un répertoire de travail spécifique pour une session en utilisant l'outil `git_set_working_dir`.

```
<use_mcp_tool>
<server_name>git</server_name>
<tool_name>git_set_working_dir</tool_name>
<arguments>
{
  "path": "/chemin/absolu/vers/votre/depot/git"
}
</arguments>
</use_mcp_tool>
```

Pour effacer le répertoire de travail défini et revenir au répertoire courant, utilisez l'outil `git_clear_working_dir`.

## Signature des commits

Si vous souhaitez que le Git MCP Server signe automatiquement les commits, vous devez :

1. Configurer Git sur le système hôte pour utiliser une clé GPG ou SSH pour la signature
2. Activer la signature des commits en définissant `GIT_SIGN_COMMITS=true`

Notez que la signature des commits nécessite une configuration Git côté serveur. Si la signature échoue, vous pouvez utiliser le paramètre `forceUnsignedOnFailure: true` avec l'outil `git_commit` pour créer un commit non signé en cas d'échec de la signature.

## Sécurité

Pour les opérations potentiellement destructives comme `git_clean` avec l'option `force: true` ou `git_reset` avec le mode `hard`, le Git MCP Server demande une confirmation explicite. Assurez-vous de comprendre les implications de ces opérations avant de les utiliser.