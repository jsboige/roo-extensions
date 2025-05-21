# Configuration du MCP Filesystem

Ce document explique comment configurer correctement le serveur MCP Filesystem pour une utilisation avec Roo.

## Emplacement du fichier de configuration

Le fichier de configuration MCP de Roo est situé à :
- Windows : `C:\Users\<username>\AppData\Roaming\Code\User\globalStorage\rooveterinaryinc.roo-cline\settings\mcp_settings.json`
- macOS/Linux : `~/.config/Code/User/globalStorage/rooveterinaryinc.roo-cline/settings/mcp_settings.json`

## Structure de la configuration

Voici la structure de base de la configuration pour le MCP Filesystem :

```json
{
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
```

## Paramètres de configuration

### Paramètres principaux

| Paramètre | Description |
|-----------|-------------|
| `command` | La commande à exécuter pour démarrer le serveur MCP. Sur Windows, généralement `cmd`. |
| `args` | Les arguments à passer à la commande. |
| `disabled` | Si `true`, le serveur MCP est désactivé. |
| `autoApprove` | Liste des opérations qui sont automatiquement approuvées sans demander à l'utilisateur. |
| `alwaysAllow` | Liste des opérations autorisées pour ce serveur MCP. |
| `transportType` | Le type de transport utilisé pour la communication avec le serveur MCP. Généralement `stdio`. |

### Arguments spécifiques au MCP Filesystem

Les arguments spécifiques au MCP Filesystem sont :

```json
"args": [
  "/c",
  "npx",
  "-y",
  "@modelcontextprotocol/server-filesystem",
  "D:\\chemin\\vers\\votre\\repertoire",
  "d:\\chemin\\vers\\votre\\repertoire"
]
```

- `/c` : Indique à cmd d'exécuter la commande spécifiée puis de se terminer.
- `npx` : Exécute un package npm sans l'installer globalement.
- `-y` : Répond automatiquement "oui" aux questions d'installation.
- `@modelcontextprotocol/server-filesystem` : Le package npm du serveur MCP Filesystem.
- `"D:\\chemin\\vers\\votre\\repertoire"` et `"d:\\chemin\\vers\\votre\\repertoire"` : Les chemins des répertoires auxquels le serveur MCP a accès. Ces chemins doivent être absolus.

## Gestion des chemins avec différentes casses

Un aspect important de la configuration du MCP Filesystem est la gestion des chemins avec différentes casses, particulièrement sous Windows. Dans la configuration, vous remarquerez que deux chemins sont spécifiés :

```json
"args": [
  "...",
  "D:\\chemin\\vers\\votre\\repertoire",
  "d:\\chemin\\vers\\votre\\repertoire"
]
```

Ces deux chemins représentent le même répertoire mais avec une casse différente pour la lettre du lecteur. Cette configuration est nécessaire pour assurer que le serveur MCP puisse résoudre correctement les chemins indépendamment de la casse utilisée.

### Pourquoi c'est important

1. **Cohérence des chemins** : Windows n'est pas sensible à la casse pour les chemins de fichiers, mais le serveur MCP peut l'être.
2. **Résolution de chemins relatifs** : Lorsque Roo utilise des chemins relatifs, le serveur MCP doit pouvoir les résoudre correctement.
3. **Compatibilité entre systèmes** : Cette approche assure une meilleure compatibilité entre les systèmes sensibles à la casse (comme Linux) et ceux qui ne le sont pas (comme Windows).

### Bonnes pratiques

- Spécifiez toujours les deux versions du chemin (majuscule et minuscule) pour la lettre du lecteur.
- Utilisez des chemins absolus plutôt que des chemins relatifs.
- Évitez d'utiliser des variables d'environnement comme `%APPDATA%` dans les chemins.

## Opérations autorisées

Le paramètre `alwaysAllow` définit les opérations que le serveur MCP est autorisé à effectuer. Voici les opérations disponibles pour le MCP Filesystem :

| Opération | Description |
|-----------|-------------|
| `list_allowed_directories` | Liste les répertoires auxquels le serveur a accès. |
| `list_directory` | Liste les fichiers et répertoires dans un chemin spécifié. |
| `read_file` | Lit le contenu d'un fichier. |
| `search_files` | Recherche des fichiers correspondant à un motif. |
| `create_directory` | Crée un nouveau répertoire. |
| `get_file_info` | Obtient des informations sur un fichier ou un répertoire. |
| `edit_file` | Modifie un fichier existant. |
| `move_file` | Déplace ou renomme un fichier ou un répertoire. |
| `write_file` | Écrit du contenu dans un fichier. |

### Considérations de sécurité

Pour des raisons de sécurité, vous pouvez limiter les opérations autorisées en fonction de vos besoins. Par exemple, si vous ne voulez pas que Roo puisse modifier des fichiers, vous pouvez retirer `edit_file`, `move_file` et `write_file` de la liste `alwaysAllow`.

## Configuration pour différents systèmes d'exploitation

### Windows

```json
{
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
    "transportType": "stdio"
  }
}
```

### macOS/Linux

```json
{
  "github.com/modelcontextprotocol/servers/tree/main/src/filesystem": {
    "command": "npx",
    "args": [
      "-y",
      "@modelcontextprotocol/server-filesystem",
      "/chemin/vers/votre/repertoire"
    ],
    "transportType": "stdio"
  }
}
```

## Dépannage

### Problèmes courants et solutions

1. **Erreur "Access denied" ou "Permission denied"**
   - Vérifiez que les chemins spécifiés dans la configuration sont accessibles par l'utilisateur qui exécute VS Code.
   - Assurez-vous que les opérations que vous essayez d'effectuer sont incluses dans la liste `alwaysAllow`.

2. **Erreur "Path not allowed"**
   - Le chemin que vous essayez d'accéder n'est pas dans la liste des répertoires autorisés.
   - Ajoutez le répertoire parent à la liste des arguments dans la configuration.

3. **Problèmes de résolution de chemins**
   - Assurez-vous que les deux versions du chemin (majuscule et minuscule) sont spécifiées pour la lettre du lecteur sous Windows.
   - Utilisez des chemins absolus plutôt que des chemins relatifs.

4. **Le serveur MCP ne démarre pas**
   - Vérifiez que Node.js et npm sont correctement installés.
   - Essayez d'installer le package globalement : `npm install -g @modelcontextprotocol/server-filesystem`.
   - Vérifiez les journaux de VS Code pour plus d'informations sur l'erreur.

## Conclusion

Une configuration correcte du MCP Filesystem est essentielle pour permettre à Roo d'interagir avec le système de fichiers de manière sécurisée et efficace. Assurez-vous de suivre les bonnes pratiques et de limiter l'accès aux répertoires nécessaires uniquement.

Pour des exemples d'utilisation du MCP Filesystem, consultez le fichier `exemples.md`.