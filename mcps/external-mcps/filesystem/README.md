# MCP Filesystem

## Description
Le MCP Filesystem permet d'interagir avec le système de fichiers local via le protocole MCP (Model Context Protocol). Il offre des fonctionnalités pour lire, écrire, modifier et gérer des fichiers et répertoires.

## Installation

```bash
npm install -g @modelcontextprotocol/server-filesystem
```

## Configuration
Pour configurer le MCP Filesystem, vous devez spécifier les répertoires autorisés pour l'accès aux fichiers.

## Utilisation
Le MCP Filesystem expose plusieurs outils pour manipuler les fichiers :

- `read_file` : Lire le contenu d'un fichier
- `write_file` : Écrire dans un fichier
- `edit_file` : Modifier un fichier existant
- `create_directory` : Créer un répertoire
- `list_directory` : Lister le contenu d'un répertoire
- `directory_tree` : Obtenir une vue arborescente d'un répertoire
- `move_file` : Déplacer ou renommer un fichier
- `search_files` : Rechercher des fichiers
- `get_file_info` : Obtenir des informations sur un fichier

## Sécurité
Le MCP Filesystem limite l'accès aux répertoires spécifiés dans la configuration pour éviter les accès non autorisés.