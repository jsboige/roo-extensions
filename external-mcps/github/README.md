# Serveur MCP GitHub

Le serveur MCP GitHub permet à Roo d'interagir avec l'API GitHub pour effectuer diverses opérations sur les dépôts, les fichiers, les issues et les pull requests. Ce serveur MCP facilite l'intégration de Roo avec GitHub pour la gestion de projets et le développement collaboratif.

## Fonctionnalités principales

- Recherche de dépôts GitHub
- Création et mise à jour de fichiers dans des dépôts
- Création de dépôts, branches, issues et pull requests
- Lecture du contenu des fichiers et répertoires
- Gestion des commits et des pull requests
- Recherche de code et d'issues

## Sécurité

Le serveur MCP GitHub utilise un token d'accès personnel GitHub pour authentifier les requêtes. Ce token doit être configuré avec les permissions appropriées pour les opérations que vous souhaitez effectuer.

## Prérequis

- Node.js (version 14 ou supérieure)
- NPM (version 6 ou supérieure)
- Un compte GitHub
- Un token d'accès personnel GitHub avec les permissions appropriées

## Installation rapide

```bash
npm install -g @modelcontextprotocol/server-github
```

Pour plus de détails sur l'installation, consultez le fichier [installation.md](installation.md).

## Configuration

Le serveur MCP GitHub nécessite un token d'accès personnel GitHub pour fonctionner. Pour plus de détails sur la configuration, consultez le fichier [configuration.md](configuration.md).

## Exemples d'utilisation

Pour des exemples d'utilisation du serveur MCP GitHub, consultez le fichier [exemples.md](exemples.md).

## Outils disponibles

Le serveur MCP GitHub fournit les outils suivants:

- `create_or_update_file`: Créer ou mettre à jour un fichier dans un dépôt GitHub
- `search_repositories`: Rechercher des dépôts GitHub
- `create_repository`: Créer un nouveau dépôt GitHub
- `get_file_contents`: Obtenir le contenu d'un fichier ou d'un répertoire
- `push_files`: Pousser plusieurs fichiers dans un dépôt en un seul commit
- `create_issue`: Créer une nouvelle issue dans un dépôt
- `create_pull_request`: Créer une nouvelle pull request
- `fork_repository`: Forker un dépôt
- `create_branch`: Créer une nouvelle branche
- `list_commits`: Lister les commits d'une branche
- `list_issues`: Lister les issues d'un dépôt
- `update_issue`: Mettre à jour une issue existante
- `add_issue_comment`: Ajouter un commentaire à une issue
- `search_code`: Rechercher du code dans des dépôts
- `search_issues`: Rechercher des issues et des pull requests
- `search_users`: Rechercher des utilisateurs GitHub
- `get_issue`: Obtenir les détails d'une issue
- `get_pull_request`: Obtenir les détails d'une pull request
- `list_pull_requests`: Lister les pull requests d'un dépôt
- `create_pull_request_review`: Créer une revue sur une pull request
- `merge_pull_request`: Fusionner une pull request
- `get_pull_request_files`: Obtenir la liste des fichiers modifiés dans une pull request
- `get_pull_request_status`: Obtenir le statut des vérifications d'une pull request
- `update_pull_request_branch`: Mettre à jour une branche de pull request
- `get_pull_request_comments`: Obtenir les commentaires d'une pull request
- `get_pull_request_reviews`: Obtenir les revues d'une pull request