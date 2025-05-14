# MCP Git

## Description
Le MCP Git permet d'interagir avec des dépôts Git via le protocole MCP (Model Context Protocol). Il offre des fonctionnalités pour gérer des dépôts Git, effectuer des commits, des push, des pull, etc.

## Installation

```bash
npm install -g @modelcontextprotocol/server-git
```

## Configuration
Pour configurer le MCP Git, vous devez spécifier les paramètres d'authentification et les dépôts autorisés.

## Utilisation
Le MCP Git expose plusieurs outils pour manipuler les dépôts Git :

- `init` : Initialiser un nouveau dépôt Git
- `clone` : Cloner un dépôt existant
- `status` : Obtenir l'état du dépôt
- `add` : Ajouter des fichiers à l'index
- `commit` : Créer un commit
- `push` : Pousser les commits vers un dépôt distant
- `pull` : Récupérer les modifications d'un dépôt distant
- `branch_list` : Lister les branches
- `branch_create` : Créer une nouvelle branche
- `branch_delete` : Supprimer une branche
- `checkout` : Changer de branche ou restaurer des fichiers
- `tag_list` : Lister les tags
- `tag_create` : Créer un tag
- `tag_delete` : Supprimer un tag
- `remote_list` : Lister les dépôts distants
- `remote_add` : Ajouter un dépôt distant
- `remote_remove` : Supprimer un dépôt distant
- `stash_list` : Lister les stash
- `stash_save` : Sauvegarder les modifications dans un stash
- `stash_pop` : Appliquer et supprimer un stash
- `bulk_action` : Exécuter plusieurs opérations Git en séquence

## Sécurité
Le MCP Git utilise les informations d'authentification configurées pour accéder aux dépôts distants.