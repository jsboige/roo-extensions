# Exemples d'utilisation du MCP Filesystem

Ce document fournit des exemples concrets d'utilisation des différentes fonctionnalités du serveur MCP Filesystem avec Roo.

## Préambule

Les exemples ci-dessous montrent comment Roo utilise les outils du MCP Filesystem. Ces exemples sont présentés sous forme de code XML que Roo utilise en interne, mais vous n'avez pas besoin de comprendre ou d'écrire ce code vous-même. Roo s'occupe de générer ces appels automatiquement en fonction de vos demandes en langage naturel.

## Liste des répertoires autorisés

Pour obtenir la liste des répertoires auxquels le serveur MCP Filesystem a accès :

```xml
<use_mcp_tool>
<server_name>github.com/modelcontextprotocol/servers/tree/main/src/filesystem</server_name>
<tool_name>list_allowed_directories</tool_name>
<arguments>
{}
</arguments>
</use_mcp_tool>
```

## Lister le contenu d'un répertoire

Pour lister les fichiers et sous-répertoires d'un répertoire :

```xml
<use_mcp_tool>
<server_name>github.com/modelcontextprotocol/servers/tree/main/src/filesystem</server_name>
<tool_name>list_directory</tool_name>
<arguments>
{
  "path": "chemin/vers/votre/repertoire"
}
</arguments>
</use_mcp_tool>
```

## Lire le contenu d'un fichier

Pour lire le contenu d'un fichier :

```xml
<use_mcp_tool>
<server_name>github.com/modelcontextprotocol/servers/tree/main/src/filesystem</server_name>
<tool_name>read_file</tool_name>
<arguments>
{
  "path": "chemin/vers/votre/fichier.txt"
}
</arguments>
</use_mcp_tool>
```

## Rechercher des fichiers

Pour rechercher des fichiers correspondant à un motif :

```xml
<use_mcp_tool>
<server_name>github.com/modelcontextprotocol/servers/tree/main/src/filesystem</server_name>
<tool_name>search_files</tool_name>
<arguments>
{
  "path": "chemin/vers/votre/repertoire",
  "pattern": "*.txt",
  "excludePatterns": ["node_modules", ".git"]
}
</arguments>
</use_mcp_tool>
```

## Créer un répertoire

Pour créer un nouveau répertoire :

```xml
<use_mcp_tool>
<server_name>github.com/modelcontextprotocol/servers/tree/main/src/filesystem</server_name>
<tool_name>create_directory</tool_name>
<arguments>
{
  "path": "chemin/vers/nouveau/repertoire"
}
</arguments>
</use_mcp_tool>
```

## Obtenir des informations sur un fichier

Pour obtenir des métadonnées sur un fichier ou un répertoire :

```xml
<use_mcp_tool>
<server_name>github.com/modelcontextprotocol/servers/tree/main/src/filesystem</server_name>
<tool_name>get_file_info</tool_name>
<arguments>
{
  "path": "chemin/vers/votre/fichier.txt"
}
</arguments>
</use_mcp_tool>
```

## Modifier un fichier existant

Pour modifier un fichier existant en remplaçant des parties spécifiques :

```xml
<use_mcp_tool>
<server_name>github.com/modelcontextprotocol/servers/tree/main/src/filesystem</server_name>
<tool_name>edit_file</tool_name>
<arguments>
{
  "path": "chemin/vers/votre/fichier.txt",
  "edits": [
    {
      "oldText": "texte à remplacer",
      "newText": "nouveau texte"
    }
  ],
  "dryRun": false
}
</arguments>
</use_mcp_tool>
```

Pour prévisualiser les modifications sans les appliquer, définissez `dryRun` sur `true`.

## Déplacer ou renommer un fichier

Pour déplacer ou renommer un fichier ou un répertoire :

```xml
<use_mcp_tool>
<server_name>github.com/modelcontextprotocol/servers/tree/main/src/filesystem</server_name>
<tool_name>move_file</tool_name>
<arguments>
{
  "source": "chemin/vers/source.txt",
  "destination": "chemin/vers/destination.txt"
}
</arguments>
</use_mcp_tool>
```

## Écrire dans un fichier

Pour écrire du contenu dans un fichier (crée le fichier s'il n'existe pas) :

```xml
<use_mcp_tool>
<server_name>github.com/modelcontextprotocol/servers/tree/main/src/filesystem</server_name>
<tool_name>write_file</tool_name>
<arguments>
{
  "path": "chemin/vers/votre/fichier.txt",
  "content": "Contenu à écrire dans le fichier."
}
</arguments>
</use_mcp_tool>
```

## Exemples de scénarios courants

### Scénario 1 : Créer un projet simple

Voici comment Roo pourrait utiliser le MCP Filesystem pour créer un projet simple :

1. Créer un répertoire pour le projet :
```xml
<use_mcp_tool>
<server_name>github.com/modelcontextprotocol/servers/tree/main/src/filesystem</server_name>
<tool_name>create_directory</tool_name>
<arguments>
{
  "path": "mon-projet"
}
</arguments>
</use_mcp_tool>
```

2. Créer un fichier HTML :
```xml
<use_mcp_tool>
<server_name>github.com/modelcontextprotocol/servers/tree/main/src/filesystem</server_name>
<tool_name>write_file</tool_name>
<arguments>
{
  "path": "mon-projet/index.html",
  "content": "<!DOCTYPE html>\n<html>\n<head>\n  <title>Mon Projet</title>\n</head>\n<body>\n  <h1>Bienvenue sur mon projet</h1>\n</body>\n</html>"
}
</arguments>
</use_mcp_tool>
```

3. Créer un fichier CSS :
```xml
<use_mcp_tool>
<server_name>github.com/modelcontextprotocol/servers/tree/main/src/filesystem</server_name>
<tool_name>write_file</tool_name>
<arguments>
{
  "path": "mon-projet/style.css",
  "content": "body {\n  font-family: Arial, sans-serif;\n  margin: 0;\n  padding: 20px;\n}\n\nh1 {\n  color: #333;\n}"
}
</arguments>
</use_mcp_tool>
```

### Scénario 2 : Modifier un fichier de configuration

1. Lire le fichier de configuration existant :
```xml
<use_mcp_tool>
<server_name>github.com/modelcontextprotocol/servers/tree/main/src/filesystem</server_name>
<tool_name>read_file</tool_name>
<arguments>
{
  "path": "config.json"
}
</arguments>
</use_mcp_tool>
```

2. Modifier une valeur dans le fichier :
```xml
<use_mcp_tool>
<server_name>github.com/modelcontextprotocol/servers/tree/main/src/filesystem</server_name>
<tool_name>edit_file</tool_name>
<arguments>
{
  "path": "config.json",
  "edits": [
    {
      "oldText": "\"port\": 3000",
      "newText": "\"port\": 8080"
    }
  ]
}
</arguments>
</use_mcp_tool>
```

### Scénario 3 : Rechercher et remplacer dans plusieurs fichiers

1. Rechercher des fichiers contenant un certain texte :
```xml
<use_mcp_tool>
<server_name>github.com/modelcontextprotocol/servers/tree/main/src/filesystem</server_name>
<tool_name>search_files</tool_name>
<arguments>
{
  "path": "src",
  "pattern": "*.js",
  "excludePatterns": ["node_modules"]
}
</arguments>
</use_mcp_tool>
```

2. Pour chaque fichier trouvé, remplacer un texte spécifique :
```xml
<use_mcp_tool>
<server_name>github.com/modelcontextprotocol/servers/tree/main/src/filesystem</server_name>
<tool_name>edit_file</tool_name>
<arguments>
{
  "path": "src/fichier1.js",
  "edits": [
    {
      "oldText": "ancienneAPI",
      "newText": "nouvelleAPI"
    }
  ]
}
</arguments>
</use_mcp_tool>
```

## Bonnes pratiques

1. **Vérifiez toujours les chemins** : Assurez-vous que les chemins que vous utilisez sont dans les répertoires autorisés.

2. **Utilisez `dryRun: true` pour les modifications importantes** : Avant d'appliquer des modifications à des fichiers importants, utilisez l'option `dryRun: true` avec `edit_file` pour prévisualiser les changements.

3. **Sauvegardez avant de modifier** : Pour les modifications importantes, créez une copie de sauvegarde des fichiers avant de les modifier.

4. **Utilisez des chemins relatifs** : Dans la mesure du possible, utilisez des chemins relatifs plutôt que des chemins absolus pour une meilleure portabilité.

5. **Gérez les erreurs** : Soyez prêt à gérer les erreurs qui peuvent survenir lors des opérations sur les fichiers, comme les problèmes de permissions ou les fichiers manquants.

## Conclusion

Ces exemples montrent comment utiliser les différentes fonctionnalités du MCP Filesystem avec Roo. En pratique, vous n'avez pas besoin d'écrire ces commandes XML vous-même - il vous suffit de demander à Roo en langage naturel ce que vous voulez faire, et Roo utilisera automatiquement les outils appropriés du MCP Filesystem pour accomplir la tâche.

Pour plus d'informations sur la configuration du MCP Filesystem, consultez le fichier `configuration.md`.