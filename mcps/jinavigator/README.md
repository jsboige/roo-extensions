# Serveur MCP JinaNavigator

## Description

JinaNavigator est un serveur MCP (Model Context Protocol) qui permet la conversion de pages web en format Markdown. Il facilite l'extraction de contenu structuré à partir de sites web, permettant aux modèles de langage d'analyser et de traiter plus efficacement l'information en ligne.

## Fonctionnalités principales

- Conversion de pages web en Markdown
- Extraction de sections spécifiques de pages web
- Conversion de plusieurs pages web en une seule requête
- Accès au contenu web via un URI au format jina://

## Installation

Le serveur JinaNavigator est intégré en tant que sous-module Git dans le projet roo-extensions. Aucune installation supplémentaire n'est nécessaire.

## Démarrage

Pour démarrer le serveur JinaNavigator, exécutez le script batch suivant:

```batch
mcps/jinavigator/run-jinavigator.bat
```

Alternativement, le serveur peut être démarré automatiquement via la configuration dans `roo-config/settings/servers.json`.

## Configuration

La configuration du serveur JinaNavigator se fait dans le fichier `roo-config/settings/servers.json`. Voici un exemple de configuration:

```json
{
  "name": "jinavigator",
  "type": "stdio",
  "command": "cmd /c node c:/dev/roo-extensions/mcps/mcp-servers/servers/jinavigator-server/dist/index.js",
  "enabled": true,
  "autoStart": true,
  "description": "Serveur MCP pour convertir des pages web en Markdown"
}
```

## Utilisation

Le serveur JinaNavigator expose plusieurs outils qui peuvent être utilisés par les modèles de langage:

### convert_web_to_markdown

Convertit une page web en Markdown en utilisant l'API Jina.

```json
{
  "url": "https://example.com",
  "start_line": 10,  // optionnel
  "end_line": 50     // optionnel
}
```

### access_jina_resource

Accède au contenu Markdown d'une page web via un URI au format jina://{url}.

```json
{
  "uri": "jina://https://example.com",
  "start_line": 10,  // optionnel
  "end_line": 50     // optionnel
}
```

### multi_convert

Convertit plusieurs pages web en Markdown en une seule requête.

```json
{
  "urls": [
    {
      "url": "https://example.com",
      "start_line": 10,
      "end_line": 50
    },
    {
      "url": "https://another-example.com"
    }
  ]
}
```

## Dépannage

Si vous rencontrez des problèmes avec le serveur JinaNavigator:

1. Vérifiez que le chemin dans le script de démarrage est correct
2. Assurez-vous que Node.js est correctement installé
3. Vérifiez les logs pour identifier d'éventuelles erreurs
4. Assurez-vous que l'URL que vous essayez de convertir est accessible

## Ressources additionnelles

Pour plus d'informations sur l'utilisation des serveurs MCP, consultez le guide d'utilisation général des MCPs dans `docs/guide-utilisation-mcps.md`.