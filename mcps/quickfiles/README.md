# Serveur MCP QuickFiles

## Description

QuickFiles est un serveur MCP (Model Context Protocol) qui permet la manipulation efficace de fichiers et répertoires. Il offre des fonctionnalités optimisées pour travailler avec plusieurs fichiers simultanément, effectuer des recherches, et gérer des opérations sur les fichiers de manière performante.

## Fonctionnalités principales

- Lecture de plusieurs fichiers en une seule requête
- Listage optimisé des contenus de répertoires
- Suppression de fichiers en lot
- Édition de plusieurs fichiers en une seule opération

## Installation

Le serveur QuickFiles est intégré en tant que sous-module Git dans le projet roo-extensions. Aucune installation supplémentaire n'est nécessaire.

## Démarrage

Pour démarrer le serveur QuickFiles, exécutez le script batch suivant:

```batch
mcps/quickfiles/run-quickfiles.bat
```

Alternativement, le serveur peut être démarré automatiquement via la configuration dans `roo-config/settings/servers.json`.

## Configuration

La configuration du serveur QuickFiles se fait dans le fichier `roo-config/settings/servers.json`. Voici un exemple de configuration:

```json
{
  "name": "quickfiles",
  "type": "stdio",
  "command": "cmd /c node c:/dev/roo-extensions/mcps/mcp-servers/servers/quickfiles-server/build/index.js",
  "enabled": true,
  "autoStart": true,
  "description": "Serveur MCP pour manipuler rapidement plusieurs fichiers"
}
```

## Utilisation

Le serveur QuickFiles expose plusieurs outils qui peuvent être utilisés par les modèles de langage:

### read_multiple_files

Lit plusieurs fichiers en une seule requête avec numérotation de lignes optionnelle et extraits de fichiers.

### list_directory_contents

Liste tous les fichiers et répertoires sous un chemin donné, avec la taille des fichiers et le nombre de lignes.

### delete_files

Supprime une liste de fichiers en une seule opération.

### edit_multiple_files

Édite plusieurs fichiers en une seule opération en appliquant des diffs.

## Dépannage

Si vous rencontrez des problèmes avec le serveur QuickFiles:

1. Vérifiez que le chemin dans le script de démarrage est correct
2. Assurez-vous que Node.js est correctement installé
3. Vérifiez les logs pour identifier d'éventuelles erreurs

## Ressources additionnelles

Pour plus d'informations sur l'utilisation des serveurs MCP, consultez le guide d'utilisation général des MCPs dans `docs/guide-utilisation-mcps.md`.