# Configuration du serveur MCP Filesystem

Ce guide détaille les options de configuration du serveur MCP Filesystem pour l'intégration avec Roo.

## Configuration dans le fichier MCP de Roo

La configuration du serveur MCP Filesystem se fait dans le fichier de configuration MCP de Roo, généralement situé à:

```
%APPDATA%\Code\User\globalStorage\rooveterinaryinc.roo-cline\settings\mcp_settings.json
```

Voici un exemple de configuration complète:

```json
{
  "mcpServers": {
    "github.com/modelcontextprotocol/servers/tree/main/src/filesystem": {
      "command": "cmd",
      "args": [
        "/c",
        "npx",
        "-y",
        "@modelcontextprotocol/server-filesystem",
        "C:\\chemin\\vers\\repertoire1,C:\\chemin\\vers\\repertoire2"
      ],
      "disabled": false,
      "autoApprove": [],
      "alwaysAllow": [
        "list_allowed_directories",
        "list_directory",
        "read_file",
        "search_files",
        "create_directory",
        "get_file_info",
        "edit_file"
      ],
      "transportType": "stdio"
    }
  }
}
```

## Options de configuration

### Répertoires autorisés

Le serveur MCP Filesystem est limité à des répertoires spécifiques pour des raisons de sécurité. Ces répertoires sont spécifiés comme arguments lors du lancement du serveur:

```
"args": [
  "/c",
  "npx",
  "-y",
  "@modelcontextprotocol/server-filesystem",
  "C:\\chemin\\vers\\repertoire1,C:\\chemin\\vers\\repertoire2"
]
```

Vous pouvez spécifier plusieurs répertoires en les séparant par des virgules.

### Outils autorisés

La liste `alwaysAllow` spécifie les outils qui peuvent être utilisés sans demander de confirmation à l'utilisateur:

```json
"alwaysAllow": [
  "list_allowed_directories",
  "list_directory",
  "read_file",
  "search_files",
  "create_directory",
  "get_file_info",
  "edit_file"
]
```

Voici la liste complète des outils disponibles:

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

### Approbation automatique

La liste `autoApprove` spécifie les outils qui sont automatiquement approuvés sans afficher de notification à l'utilisateur:

```json
"autoApprove": []
```

Par défaut, cette liste est vide, ce qui signifie que tous les outils nécessitent une notification à l'utilisateur.

### Désactivation du serveur

L'option `disabled` permet de désactiver temporairement le serveur MCP Filesystem:

```json
"disabled": false
```

Mettez cette valeur à `true` pour désactiver le serveur.

## Configuration avancée

### Utilisation avec des chemins relatifs

Le serveur MCP Filesystem prend en charge les chemins relatifs, mais ils sont résolus par rapport au répertoire de travail du serveur, pas par rapport au répertoire de travail de Roo. Pour éviter les confusions, il est recommandé d'utiliser des chemins absolus.

### Gestion des permissions

Le serveur MCP Filesystem hérite des permissions de l'utilisateur qui l'exécute. Assurez-vous que l'utilisateur a les permissions nécessaires pour accéder aux répertoires spécifiés.

### Configuration pour différents systèmes d'exploitation

#### Windows

Sur Windows, utilisez des chemins avec des doubles backslashes:

```
"C:\\chemin\\vers\\repertoire"
```

#### macOS et Linux

Sur macOS et Linux, utilisez des chemins avec des slashes:

```
"/chemin/vers/repertoire"
```

## Exemple de configuration complète

Voici un exemple de configuration complète pour le serveur MCP Filesystem:

```json
{
  "mcpServers": {
    "github.com/modelcontextprotocol/servers/tree/main/src/filesystem": {
      "command": "cmd",
      "args": [
        "/c",
        "npx",
        "-y",
        "@modelcontextprotocol/server-filesystem",
        "C:\\dev\\projets,C:\\Users\\utilisateur\\Documents"
      ],
      "disabled": false,
      "autoApprove": [
        "list_allowed_directories",
        "list_directory",
        "read_file"
      ],
      "alwaysAllow": [
        "list_allowed_directories",
        "list_directory",
        "read_file",
        "search_files",
        "create_directory",
        "get_file_info",
        "edit_file",
        "directory_tree"
      ],
      "transportType": "stdio"
    }
  }
}
```

Cette configuration:
- Autorise l'accès aux répertoires `C:\dev\projets` et `C:\Users\utilisateur\Documents`
- Approuve automatiquement les outils `list_allowed_directories`, `list_directory` et `read_file`
- Permet l'utilisation sans confirmation des outils listés dans `alwaysAllow`