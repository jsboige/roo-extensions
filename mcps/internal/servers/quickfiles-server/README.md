# QuickFiles MCP Server

Ce répertoire contient le serveur MCP pour manipuler rapidement plusieurs fichiers.

## Emplacement d'origine

Ce serveur était précédemment situé à l'emplacement suivant :
`d:/Dev/roo-extensions/mcps/mcp-servers/servers/quickfiles-server`

## Fonctionnalités

Le serveur QuickFiles MCP offre des fonctionnalités pour manipuler efficacement plusieurs fichiers :
- Lecture de plusieurs fichiers en une seule opération
- Listage du contenu de répertoires
- Édition de plusieurs fichiers
- Suppression de fichiers
- Extraction de contenu Markdown

## Dépendances

Ce serveur est une dépendance du serveur JinaNavigator. La relation de dépendance a été préservée dans cette nouvelle organisation.

## Configuration

Le serveur est configuré pour démarrer avec la commande :
```
node build/index.js
```

## Intégration

Ce serveur fait partie des serveurs MCP internes et est maintenant correctement placé dans le répertoire `mcps/internal/servers/`.