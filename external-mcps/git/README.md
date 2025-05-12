# Serveur MCP Git

Le serveur MCP Git permet à Roo d'interagir avec l'API GitHub pour effectuer diverses opérations sur les dépôts, les fichiers, les issues et les pull requests. Ce serveur MCP est basé sur le même package que le serveur MCP GitHub (`@modelcontextprotocol/server-github`), mais il est configuré avec un identifiant différent pour permettre une utilisation distincte.

## Fonctionnalités principales

- Recherche de dépôts GitHub
- Création et mise à jour de fichiers dans des dépôts
- Création de dépôts, branches, issues et pull requests
- Lecture du contenu des fichiers et répertoires
- Gestion des commits et des pull requests
- Recherche de code et d'issues

## Sécurité

Le serveur MCP Git utilise un token d'accès personnel GitHub pour authentifier les requêtes. Ce token doit être configuré avec les permissions appropriées pour les opérations que vous souhaitez effectuer.

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

Le serveur MCP Git nécessite un token d'accès personnel GitHub pour fonctionner. Pour plus de détails sur la configuration, consultez le fichier [configuration.md](configuration.md).

## Exemples d'utilisation

Pour des exemples d'utilisation du serveur MCP Git, consultez le fichier [exemples.md](exemples.md).

## Différence avec le serveur MCP GitHub

Le serveur MCP Git et le serveur MCP GitHub utilisent le même package sous-jacent (`@modelcontextprotocol/server-github`), mais ils sont configurés avec des identifiants différents dans le fichier de configuration MCP de Roo. Cela permet d'avoir deux instances distinctes du même serveur, chacune avec sa propre configuration et ses propres permissions.

Cette séparation peut être utile dans plusieurs cas:
- Utiliser différents tokens d'accès personnel GitHub avec différentes permissions
- Configurer différents ensembles d'outils autorisés pour chaque serveur
- Séparer les opérations de lecture (via le serveur Git) des opérations d'écriture (via le serveur GitHub)

## Outils disponibles

Le serveur MCP Git fournit les mêmes outils que le serveur MCP GitHub:

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