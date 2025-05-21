# Serveurs MCP (Model Context Protocol)

Ce répertoire contient les serveurs MCP (Model Context Protocol) utilisés dans le projet.

## Organisation

Les serveurs MCP sont organisés en deux catégories principales :

- **internal/** - Serveurs MCP développés en interne
  - **servers/quickfiles-server/** - Serveur MCP pour manipuler rapidement plusieurs fichiers
  - **servers/jupyter-mcp-server/** - Serveur MCP pour interagir avec les notebooks Jupyter
  - **servers/jinavigator-server/** - Serveur MCP pour convertir des pages web en Markdown
  - **servers/github-projects-mcp/** - Serveur MCP pour interagir avec GitHub Projects

- **external/** - Serveurs MCP externes
  - **filesystem/** - Serveur MCP pour accéder au système de fichiers (documentation et code source)
  - **git/** - Serveur MCP Git (documentation et code source)
  - **github/** - Serveur MCP GitHub (documentation et code source)
  - **jupyter/** - Serveur MCP pour l'intégration avec Jupyter (documentation et scripts)
  - **searxng/** - Serveur MCP pour effectuer des recherches web via SearXNG
  - **win-cli/** - Serveur MCP pour exécuter des commandes CLI sur Windows (documentation et code source)

## Autres répertoires

- **docker/** - Documentation et scripts pour la conteneurisation des serveurs MCP
- **monitoring/** - Scripts pour surveiller l'état des serveurs MCP
- **scripts/** - Scripts utilitaires pour les serveurs MCP
- **tests/** - Scripts de test pour vérifier le bon fonctionnement des serveurs MCP
- **utils/** - Utilitaires pour les serveurs MCP

## Configuration

Les configurations des serveurs MCP sont définies dans le fichier `roo-config/settings/servers.json`.

## Documentation

- **INSTALLATION.md** - Instructions d'installation des serveurs MCP
- **TROUBLESHOOTING.md** - Guide de dépannage pour les serveurs MCP
- **MANUAL_START.md** - Instructions pour démarrer manuellement les serveurs MCP
- **OPTIMIZATIONS.md** - Recommandations pour optimiser les serveurs MCP
