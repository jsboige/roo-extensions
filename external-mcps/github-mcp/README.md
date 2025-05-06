# GitHub MCP Server pour Roo

Le GitHub MCP Server est un serveur implémentant le [Model Context Protocol (MCP)](https://modelcontextprotocol.io/introduction) qui permet une intégration transparente avec les API GitHub. Ce serveur permet aux modèles d'IA comme Roo d'interagir directement avec GitHub pour automatiser des tâches, extraire des données et interagir avec l'écosystème GitHub.

## Fonctionnalités principales

- **Interaction avec les dépôts GitHub** : création, modification et lecture de fichiers, gestion des branches et des commits
- **Gestion des issues** : création, lecture, mise à jour et commentaires sur les issues
- **Gestion des pull requests** : création, fusion, révision et commentaires sur les PR
- **Recherche de code** : recherche de code dans les dépôts GitHub
- **Sécurité du code** : accès aux alertes de sécurité et de scan de code
- **Gestion des utilisateurs** : recherche et information sur les utilisateurs GitHub

## Prérequis

- Docker installé et en cours d'exécution
- Un token d'accès personnel GitHub (PAT)

## Installation rapide

Consultez le fichier [installation.md](./installation.md) pour les instructions détaillées d'installation.

## Configuration

Consultez le fichier [configuration.md](./configuration.md) pour les options de configuration disponibles.

## Exemples d'utilisation

Consultez le fichier [exemples.md](./exemples.md) pour des exemples concrets d'utilisation du GitHub MCP Server avec Roo.

## Licence

Ce projet est distribué sous licence MIT. Voir le fichier [LICENSE](../github-mcp/server/LICENSE) pour plus de détails.