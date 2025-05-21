# Serveurs MCP Internes

Ce répertoire contient les serveurs MCP développés en interne pour le projet.

## Organisation

Les serveurs MCP internes sont organisés dans le sous-répertoire `servers/` :

- **servers/quickfiles-server/** - Serveur MCP pour manipuler rapidement plusieurs fichiers
- **servers/jupyter-mcp-server/** - Serveur MCP pour interagir avec les notebooks Jupyter
- **servers/jinavigator-server/** - Serveur MCP pour convertir des pages web en Markdown
- **servers/github-projects-mcp/** - Serveur MCP pour interagir avec GitHub Projects

## Dépendances

- Le serveur JinaNavigator dépend du serveur QuickFiles. Cette dépendance est gérée via npm.

## Installation

Chaque serveur MCP interne dispose de sa propre documentation d'installation dans son répertoire respectif.

## Configuration

Les configurations des serveurs MCP internes sont définies dans le fichier `roo-config/settings/servers.json`.

## Utilisation

Consultez les fichiers README.md et USAGE.md dans chaque sous-répertoire pour des instructions spécifiques sur l'utilisation de chaque serveur MCP.

## Tests

Le répertoire `tests/` contient des scripts de test pour vérifier le bon fonctionnement des serveurs MCP internes.

## Documentation

Le répertoire `docs/` contient de la documentation supplémentaire sur les serveurs MCP internes.