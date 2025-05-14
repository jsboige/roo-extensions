# MCP GitHub

## Description
Le MCP GitHub permet d'interagir avec l'API GitHub via le protocole MCP (Model Context Protocol). Il offre des fonctionnalités pour gérer des dépôts GitHub, des issues, des pull requests, etc.

## Installation

```bash
npm install -g @modelcontextprotocol/server-github
```

## Configuration
Pour configurer le MCP GitHub, vous devez spécifier un token d'accès personnel GitHub avec les permissions appropriées.

## Utilisation
Le MCP GitHub expose plusieurs outils pour interagir avec GitHub :

- `create_or_update_file` : Créer ou mettre à jour un fichier dans un dépôt
- `search_repositories` : Rechercher des dépôts
- `create_repository` : Créer un nouveau dépôt
- `get_file_contents` : Obtenir le contenu d'un fichier ou d'un répertoire
- `push_files` : Pousser plusieurs fichiers dans un dépôt
- `create_issue` : Créer une nouvelle issue
- `create_pull_request` : Créer une pull request
- `fork_repository` : Forker un dépôt
- `create_branch` : Créer une nouvelle branche
- `list_commits` : Lister les commits d'une branche
- `list_issues` : Lister les issues d'un dépôt
- `update_issue` : Mettre à jour une issue existante
- `add_issue_comment` : Ajouter un commentaire à une issue
- `search_code` : Rechercher du code
- `search_issues` : Rechercher des issues et des pull requests
- `search_users` : Rechercher des utilisateurs
- `get_issue` : Obtenir les détails d'une issue
- `get_pull_request` : Obtenir les détails d'une pull request
- `list_pull_requests` : Lister les pull requests d'un dépôt
- `create_pull_request_review` : Créer une revue sur une pull request
- `merge_pull_request` : Fusionner une pull request
- `get_pull_request_files` : Obtenir la liste des fichiers modifiés dans une pull request
- `get_pull_request_status` : Obtenir le statut des vérifications d'une pull request
- `update_pull_request_branch` : Mettre à jour une branche de pull request
- `get_pull_request_comments` : Obtenir les commentaires d'une pull request
- `get_pull_request_reviews` : Obtenir les revues d'une pull request

## Sécurité
Le MCP GitHub utilise le token d'accès personnel configuré pour authentifier les requêtes à l'API GitHub.