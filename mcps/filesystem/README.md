# MCP Filesystem pour Roo

Ce dossier contient la documentation et les instructions pour l'installation et la configuration du serveur MCP Filesystem utilisé avec Roo.

## Qu'est-ce que le MCP Filesystem ?

Le MCP Filesystem est un serveur Model Context Protocol (MCP) qui permet à Roo d'interagir directement avec le système de fichiers de votre ordinateur. Il offre un accès sécurisé et contrôlé aux opérations de fichiers, permettant à Roo de lire, écrire, modifier et gérer des fichiers et des répertoires dans les emplacements autorisés.

Le serveur MCP Filesystem est basé sur le package npm `@modelcontextprotocol/server-filesystem` et s'exécute localement sur votre machine.

## Fonctionnalités principales

- Lecture et écriture de fichiers
- Création et gestion de répertoires
- Recherche de contenu dans les fichiers
- Déplacement et renommage de fichiers
- Édition de fichiers existants
- Obtention d'informations sur les fichiers et répertoires
- Restriction d'accès aux répertoires spécifiés uniquement

## Outils disponibles

Le serveur MCP Filesystem fournit les outils suivants :

1. **list_allowed_directories** - Liste les répertoires auxquels le serveur a accès
2. **list_directory** - Liste les fichiers et répertoires dans un chemin spécifié
3. **read_file** - Lit le contenu d'un fichier
4. **search_files** - Recherche des fichiers correspondant à un motif
5. **create_directory** - Crée un nouveau répertoire
6. **get_file_info** - Obtient des informations sur un fichier ou un répertoire
7. **edit_file** - Modifie un fichier existant
8. **move_file** - Déplace ou renomme un fichier ou un répertoire
9. **write_file** - Écrit du contenu dans un fichier

## Structure du dossier

- `README.md` - Ce fichier d'introduction
- `installation.md` - Guide d'installation du serveur MCP Filesystem
- `configuration.md` - Guide de configuration du serveur MCP Filesystem
- `exemples.md` - Exemples d'utilisation du serveur MCP Filesystem
- `mcp-config-example.json` - Exemple de configuration MCP pour Roo

## Prérequis

- Node.js (version 14 ou supérieure)
- npm (généralement installé avec Node.js)
- VS Code avec l'extension Roo

## Configuration rapide

1. Installez le package npm requis :
   ```bash
   npm install -g @modelcontextprotocol/server-filesystem
   ```

2. Ouvrez le fichier de configuration MCP de Roo situé à :
   - Windows : `C:\Users\<username>\AppData\Roaming\Code\User\globalStorage\rooveterinaryinc.roo-cline\settings\mcp_settings.json` (remplacez `<username>` par votre nom d'utilisateur Windows)
   - macOS/Linux : `~/.config/Code/User/globalStorage/rooveterinaryinc.roo-cline/settings/mcp_settings.json`

3. Ajoutez ou modifiez la configuration du serveur "filesystem" en utilisant l'exemple fourni dans le fichier `mcp-config-example.json`

4. Redémarrez VS Code pour appliquer les changements

> **Important** : N'utilisez pas la variable d'environnement `%APPDATA%` dans les chemins de configuration MCP car elle n'est pas interprétée correctement dans ce contexte. Utilisez toujours le chemin absolu complet.

## Gestion des chemins avec différentes casses (D:\ vs d:\)

Un aspect important à noter lors de la configuration du MCP Filesystem est la gestion des chemins avec différentes casses, particulièrement sous Windows. Dans la configuration, vous remarquerez que deux chemins sont spécifiés :

```json
"args": [
  "/c",
  "npx",
  "-y",
  "@modelcontextprotocol/server-filesystem",
  "D:\\roo-extensions",
  "d:\\roo-extensions"
]
```

Ces deux chemins (`D:\\roo-extensions` et `d:\\roo-extensions`) représentent le même répertoire mais avec une casse différente pour la lettre du lecteur. Cette configuration est nécessaire car :

1. **Cohérence interne** : Certains outils ou bibliothèques peuvent normaliser les chemins en utilisant une casse spécifique.
2. **Résolution de chemins** : Le serveur MCP doit pouvoir faire correspondre les chemins indépendamment de la casse utilisée.
3. **Compatibilité entre systèmes** : Cela assure une meilleure compatibilité entre les systèmes sensibles à la casse (comme Linux) et ceux qui ne le sont pas (comme Windows).

Si vous rencontrez des erreurs liées aux chemins, assurez-vous que tous les chemins possibles sont correctement spécifiés dans la configuration.

## Sécurité et bonnes pratiques

- Limitez l'accès aux répertoires nécessaires uniquement
- Évitez de donner accès aux répertoires système ou sensibles
- Utilisez la liste `alwaysAllow` pour restreindre les opérations autorisées
- Vérifiez régulièrement les journaux pour détecter toute activité suspecte

Pour plus de détails sur la configuration et l'utilisation du MCP Filesystem, consultez les fichiers `configuration.md` et `exemples.md`.

## Liens utiles

- [Dépôt GitHub du MCP Filesystem](https://github.com/modelcontextprotocol/servers/tree/main/src/filesystem)
- [Documentation du Model Context Protocol](https://github.com/modelcontextprotocol/mcp)