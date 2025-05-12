# Serveur MCP Filesystem

Le serveur MCP Filesystem permet à Roo d'interagir avec le système de fichiers local. Il offre des fonctionnalités pour lire, écrire, rechercher et manipuler des fichiers et des répertoires sur la machine locale.

## Fonctionnalités principales

- Lecture de fichiers
- Écriture et modification de fichiers
- Recherche de fichiers et de contenu
- Listage de répertoires
- Création de répertoires
- Obtention d'informations sur les fichiers

## Sécurité

Le serveur MCP Filesystem est limité à des répertoires spécifiques configurés lors de son lancement. Cela garantit que Roo ne peut accéder qu'aux fichiers et répertoires autorisés.

## Prérequis

- Node.js (version 14 ou supérieure)
- NPM (version 6 ou supérieure)

## Installation rapide

```bash
npm install -g @modelcontextprotocol/server-filesystem
```

Pour plus de détails sur l'installation, consultez le fichier [installation.md](installation.md).

## Configuration

Le serveur MCP Filesystem nécessite une configuration pour spécifier les répertoires auxquels il a accès. Pour plus de détails sur la configuration, consultez le fichier [configuration.md](configuration.md).

## Exemples d'utilisation

Pour des exemples d'utilisation du serveur MCP Filesystem, consultez le fichier [exemples.md](exemples.md).

## Outils disponibles

Le serveur MCP Filesystem fournit les outils suivants:

- `read_file`: Lire le contenu d'un fichier
- `read_multiple_files`: Lire le contenu de plusieurs fichiers
- `write_file`: Écrire dans un fichier
- `edit_file`: Modifier un fichier existant
- `create_directory`: Créer un répertoire
- `list_directory`: Lister le contenu d'un répertoire
- `directory_tree`: Obtenir une représentation arborescente d'un répertoire
- `move_file`: Déplacer ou renommer un fichier
- `search_files`: Rechercher des fichiers
- `get_file_info`: Obtenir des informations sur un fichier
- `list_allowed_directories`: Lister les répertoires autorisés