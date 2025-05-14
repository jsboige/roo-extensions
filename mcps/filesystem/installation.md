# Installation du MCP Filesystem

Ce document explique comment installer et configurer le serveur MCP Filesystem pour une utilisation avec Roo.

## Prérequis

Avant d'installer le MCP Filesystem, assurez-vous que les prérequis suivants sont installés sur votre système :

1. **Node.js** (version 14 ou supérieure)
   - Téléchargement : [https://nodejs.org/](https://nodejs.org/)
   - Vérification : `node --version`

2. **npm** (généralement installé avec Node.js)
   - Vérification : `npm --version`

3. **VS Code** avec l'extension Roo
   - Téléchargement de VS Code : [https://code.visualstudio.com/](https://code.visualstudio.com/)
   - Installation de l'extension Roo : recherchez "Roo" dans l'onglet Extensions de VS Code

## Installation du package MCP Filesystem

Vous avez deux options pour installer le package MCP Filesystem :

### Option 1 : Installation globale (recommandée)

Installez le package globalement pour le rendre disponible dans tout votre système :

```bash
npm install -g @modelcontextprotocol/server-filesystem
```

Cette méthode est recommandée car elle permet d'utiliser le serveur MCP Filesystem depuis n'importe quel projet.

### Option 2 : Installation à la demande avec npx

Vous pouvez également utiliser npx pour exécuter le package sans l'installer globalement. C'est l'approche utilisée dans la configuration par défaut :

```bash
npx -y @modelcontextprotocol/server-filesystem <chemin1> <chemin2> ...
```

Cette méthode télécharge et exécute le package à la demande, ce qui est utile si vous ne voulez pas l'installer globalement.

## Configuration du MCP Filesystem

Une fois le package installé, vous devez configurer Roo pour utiliser le serveur MCP Filesystem.

### Étape 1 : Localiser le fichier de configuration MCP

Le fichier de configuration MCP de Roo est situé à :
- Windows : `C:\Users\<username>\AppData\Roaming\Code\User\globalStorage\rooveterinaryinc.roo-cline\settings\mcp_settings.json`
- macOS : `~/Library/Application Support/Code/User/globalStorage/rooveterinaryinc.roo-cline/settings/mcp_settings.json`
- Linux : `~/.config/Code/User/globalStorage/rooveterinaryinc.roo-cline/settings/mcp_settings.json`

Remplacez `<username>` par votre nom d'utilisateur.

### Étape 2 : Ajouter la configuration du MCP Filesystem

Ouvrez le fichier `mcp_settings.json` et ajoutez ou modifiez la configuration du serveur MCP Filesystem. Voici un exemple de configuration :

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
        "D:\\chemin\\vers\\votre\\repertoire",
        "d:\\chemin\\vers\\votre\\repertoire"
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
        "edit_file",
        "move_file",
        "write_file"
      ],
      "transportType": "stdio"
    }
  }
}
```

> **Note** : Si le fichier `mcp_settings.json` contient déjà d'autres configurations, assurez-vous de les préserver et d'ajouter uniquement la configuration du MCP Filesystem.

### Étape 3 : Personnaliser les chemins d'accès

Dans la configuration ci-dessus, remplacez `"D:\\chemin\\vers\\votre\\repertoire"` et `"d:\\chemin\\vers\\votre\\repertoire"` par les chemins des répertoires auxquels vous souhaitez que le serveur MCP ait accès.

Par exemple, si vous voulez donner accès à votre répertoire de projets :
- Windows : `"D:\\Projets"` et `"d:\\Projets"`
- macOS/Linux : `"/Users/votre-nom/Projets"`

> **Important** : Sous Windows, spécifiez les deux versions du chemin (majuscule et minuscule) pour la lettre du lecteur pour éviter les problèmes de résolution de chemins.

### Étape 4 : Adapter la configuration à votre système d'exploitation

#### Pour Windows

La configuration par défaut est adaptée à Windows. Assurez-vous que :
- `"command"` est défini sur `"cmd"`
- `"args"` commence par `["/c", ...]`
- Les chemins utilisent des barres obliques inversées doublées (`\\`)

#### Pour macOS/Linux

Pour macOS ou Linux, modifiez la configuration comme suit :

```json
{
  "mcpServers": {
    "github.com/modelcontextprotocol/servers/tree/main/src/filesystem": {
      "command": "npx",
      "args": [
        "-y",
        "@modelcontextprotocol/server-filesystem",
        "/chemin/vers/votre/repertoire"
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
        "edit_file",
        "move_file",
        "write_file"
      ],
      "transportType": "stdio"
    }
  }
}
```

Notez que sous macOS/Linux :
- `"command"` est défini directement sur `"npx"`
- Les chemins utilisent des barres obliques simples (`/`)
- Il n'est pas nécessaire de spécifier deux versions du chemin avec des casses différentes

### Étape 5 : Redémarrer VS Code

Après avoir modifié le fichier de configuration, redémarrez VS Code pour appliquer les changements.

## Vérification de l'installation

Pour vérifier que le MCP Filesystem est correctement installé et configuré, vous pouvez demander à Roo de lister les répertoires autorisés :

1. Ouvrez une conversation avec Roo dans VS Code
2. Demandez à Roo : "Peux-tu lister les répertoires autorisés par le MCP Filesystem ?"

Si tout est correctement configuré, Roo devrait utiliser l'outil `list_allowed_directories` du MCP Filesystem et afficher les répertoires que vous avez spécifiés dans la configuration.

## Installation avancée

### Utilisation avec un serveur MCP personnalisé

Si vous développez votre propre version du serveur MCP Filesystem ou si vous utilisez une version modifiée, vous pouvez spécifier le chemin vers votre script JavaScript au lieu d'utiliser npx :

```json
{
  "mcpServers": {
    "filesystem-custom": {
      "command": "node",
      "args": [
        "chemin/vers/votre/script.js",
        "D:\\chemin\\vers\\votre\\repertoire",
        "d:\\chemin\\vers\\votre\\repertoire"
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
        "edit_file",
        "move_file",
        "write_file"
      ],
      "transportType": "stdio"
    }
  }
}
```

### Configuration avec des variables d'environnement

Vous pouvez également utiliser des variables d'environnement pour configurer certains aspects du serveur MCP Filesystem :

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
        "D:\\chemin\\vers\\votre\\repertoire",
        "d:\\chemin\\vers\\votre\\repertoire"
      ],
      "env": {
        "MCP_LOG_LEVEL": "info",
        "MCP_TRANSPORT_TYPE": "stdio"
      },
      "disabled": false,
      "autoApprove": [],
      "alwaysAllow": [
        "list_allowed_directories",
        "list_directory",
        "read_file",
        "search_files",
        "create_directory",
        "get_file_info",
        "edit_file",
        "move_file",
        "write_file"
      ],
      "transportType": "stdio"
    }
  }
}
```

## Dépannage

### Problèmes courants et solutions

1. **Erreur "Command not found" ou "npx not found"**
   - Vérifiez que Node.js et npm sont correctement installés.
   - Essayez d'installer le package globalement : `npm install -g @modelcontextprotocol/server-filesystem`.

2. **Erreur "Access denied" ou "Permission denied"**
   - Vérifiez que les chemins spécifiés dans la configuration sont accessibles par l'utilisateur qui exécute VS Code.
   - Sous Windows, essayez d'exécuter VS Code en tant qu'administrateur.

3. **Le serveur MCP ne démarre pas**
   - Vérifiez les journaux de VS Code pour plus d'informations sur l'erreur.
   - Assurez-vous que la configuration dans `mcp_settings.json` est correcte et que le format JSON est valide.

4. **Roo ne peut pas accéder à certains fichiers**
   - Vérifiez que les chemins des fichiers sont dans les répertoires autorisés spécifiés dans la configuration.
   - Assurez-vous que les opérations que vous essayez d'effectuer sont incluses dans la liste `alwaysAllow`.

### Journaux de débogage

Pour obtenir plus d'informations sur les erreurs, vous pouvez activer les journaux de débogage en ajoutant la variable d'environnement `MCP_LOG_LEVEL` :

```json
"env": {
  "MCP_LOG_LEVEL": "debug"
}
```

Les niveaux de journalisation disponibles sont : `error`, `warn`, `info`, `debug`.

## Conclusion

Vous avez maintenant installé et configuré le serveur MCP Filesystem pour une utilisation avec Roo. Pour plus d'informations sur la configuration et l'utilisation du MCP Filesystem, consultez les fichiers `configuration.md` et `exemples.md`.

Si vous rencontrez des problèmes ou si vous avez des questions, n'hésitez pas à consulter la documentation officielle du Model Context Protocol ou à demander de l'aide à la communauté Roo.