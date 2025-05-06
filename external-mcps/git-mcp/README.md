# Git MCP Server pour Roo

Le Git MCP Server est un serveur implémentant le [Model Context Protocol (MCP)](https://modelcontextprotocol.io/introduction) qui permet une intégration transparente avec Git. Ce serveur permet aux modèles d'IA comme Roo d'interagir directement avec des dépôts Git locaux pour automatiser des tâches de gestion de version, extraire des données et effectuer des opérations Git courantes.

## Fonctionnalités principales

- **Opérations Git de base** : clone, commit, push, pull, branch, diff, log, status, etc.
- **Gestion des branches** : création, suppression, renommage, checkout
- **Gestion des commits** : création, visualisation, cherry-pick
- **Gestion des dépôts** : initialisation, clonage, configuration des remotes
- **Gestion des fichiers** : ajout, modification, suppression, staging
- **Opérations avancées** : merge, rebase, stash, reset, tag

## Prérequis

- [Node.js (>=18.0.0)](https://nodejs.org/)
- [Git](https://git-scm.com/) installé et accessible dans le PATH du système

## Installation rapide

Consultez le fichier [installation.md](./installation.md) pour les instructions détaillées d'installation.

## Configuration

Consultez le fichier [configuration.md](./configuration.md) pour les options de configuration disponibles.

## Exemples d'utilisation

Consultez le fichier [exemples.md](./exemples.md) pour des exemples concrets d'utilisation du Git MCP Server avec Roo.

## Licence

Ce projet est distribué sous licence Apache 2.0. Voir le fichier [LICENSE](./server/LICENSE) pour plus de détails.