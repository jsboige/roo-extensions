# Exemples d'utilisation du serveur MCP Filesystem

Ce document présente des exemples concrets d'utilisation du serveur MCP Filesystem avec Roo.

## Prérequis

Assurez-vous que:
- Le serveur MCP Filesystem est correctement installé et configuré
- Les répertoires que vous souhaitez utiliser sont dans la liste des répertoires autorisés

## Exemples d'utilisation des outils

### Lister les répertoires autorisés

```xml
<use_mcp_tool>
<server_name>github.com/modelcontextprotocol/servers/tree/main/src/filesystem</server_name>
<tool_name>list_allowed_directories</tool_name>
<arguments>
{}
</arguments>
</use_mcp_tool>
```

### Lister le contenu d'un répertoire

```xml
<use_mcp_tool>
<server_name>github.com/modelcontextprotocol/servers/tree/main/src/filesystem</server_name>
<tool_name>list_directory</tool_name>
<arguments>
{
  "path": "C:\\chemin\\vers\\repertoire"
}
</arguments>
</use_mcp_tool>
```

### Obtenir une représentation arborescente d'un répertoire

```xml
<use_mcp_tool>
<server_name>github.com/modelcontextprotocol/servers/tree/main/src/filesystem</server_name>
<tool_name>directory_tree</tool_name>
<arguments>
{
  "path": "C:\\chemin\\vers\\repertoire"
}
</arguments>
</use_mcp_tool>
```

### Lire le contenu d'un fichier

```xml
<use_mcp_tool>
<server_name>github.com/modelcontextprotocol/servers/tree/main/src/filesystem</server_name>
<tool_name>read_file</tool_name>
<arguments>
{
  "path": "C:\\chemin\\vers\\fichier.txt"
}
</arguments>
</use_mcp_tool>
```

### Lire le contenu de plusieurs fichiers

```xml
<use_mcp_tool>
<server_name>github.com/modelcontextprotocol/servers/tree/main/src/filesystem</server_name>
<tool_name>read_multiple_files</tool_name>
<arguments>
{
  "paths": [
    "C:\\chemin\\vers\\fichier1.txt",
    "C:\\chemin\\vers\\fichier2.txt"
  ]
}
</arguments>
</use_mcp_tool>
```

### Écrire dans un fichier

```xml
<use_mcp_tool>
<server_name>github.com/modelcontextprotocol/servers/tree/main/src/filesystem</server_name>
<tool_name>write_file</tool_name>
<arguments>
{
  "path": "C:\\chemin\\vers\\fichier.txt",
  "content": "Contenu à écrire dans le fichier"
}
</arguments>
</use_mcp_tool>
```

### Modifier un fichier existant

```xml
<use_mcp_tool>
<server_name>github.com/modelcontextprotocol/servers/tree/main/src/filesystem</server_name>
<tool_name>edit_file</tool_name>
<arguments>
{
  "path": "C:\\chemin\\vers\\fichier.txt",
  "edits": [
    {
      "oldText": "Texte à remplacer",
      "newText": "Nouveau texte"
    }
  ]
}
</arguments>
</use_mcp_tool>
```

### Créer un répertoire

```xml
<use_mcp_tool>
<server_name>github.com/modelcontextprotocol/servers/tree/main/src/filesystem</server_name>
<tool_name>create_directory</tool_name>
<arguments>
{
  "path": "C:\\chemin\\vers\\nouveau_repertoire"
}
</arguments>
</use_mcp_tool>
```

### Déplacer ou renommer un fichier

```xml
<use_mcp_tool>
<server_name>github.com/modelcontextprotocol/servers/tree/main/src/filesystem</server_name>
<tool_name>move_file</tool_name>
<arguments>
{
  "source": "C:\\chemin\\vers\\fichier_source.txt",
  "destination": "C:\\chemin\\vers\\fichier_destination.txt"
}
</arguments>
</use_mcp_tool>
```

### Rechercher des fichiers

```xml
<use_mcp_tool>
<server_name>github.com/modelcontextprotocol/servers/tree/main/src/filesystem</server_name>
<tool_name>search_files</tool_name>
<arguments>
{
  "path": "C:\\chemin\\vers\\repertoire",
  "pattern": "*.txt",
  "excludePatterns": ["*.tmp"]
}
</arguments>
</use_mcp_tool>
```

### Obtenir des informations sur un fichier

```xml
<use_mcp_tool>
<server_name>github.com/modelcontextprotocol/servers/tree/main/src/filesystem</server_name>
<tool_name>get_file_info</tool_name>
<arguments>
{
  "path": "C:\\chemin\\vers\\fichier.txt"
}
</arguments>
</use_mcp_tool>
```

## Scénarios d'utilisation

### Scénario 1: Analyse de code source

Ce scénario montre comment utiliser le serveur MCP Filesystem pour analyser un projet de code source:

```xml
<!-- Lister les fichiers du projet -->
<use_mcp_tool>
<server_name>github.com/modelcontextprotocol/servers/tree/main/src/filesystem</server_name>
<tool_name>directory_tree</tool_name>
<arguments>
{
  "path": "C:\\chemin\\vers\\projet"
}
</arguments>
</use_mcp_tool>

<!-- Rechercher tous les fichiers JavaScript -->
<use_mcp_tool>
<server_name>github.com/modelcontextprotocol/servers/tree/main/src/filesystem</server_name>
<tool_name>search_files</tool_name>
<arguments>
{
  "path": "C:\\chemin\\vers\\projet",
  "pattern": "*.js"
}
</arguments>
</use_mcp_tool>

<!-- Lire le contenu d'un fichier JavaScript spécifique -->
<use_mcp_tool>
<server_name>github.com/modelcontextprotocol/servers/tree/main/src/filesystem</server_name>
<tool_name>read_file</tool_name>
<arguments>
{
  "path": "C:\\chemin\\vers\\projet\\src\\main.js"
}
</arguments>
</use_mcp_tool>
```

### Scénario 2: Création et modification de fichiers

Ce scénario montre comment utiliser le serveur MCP Filesystem pour créer et modifier des fichiers:

```xml
<!-- Créer un nouveau répertoire -->
<use_mcp_tool>
<server_name>github.com/modelcontextprotocol/servers/tree/main/src/filesystem</server_name>
<tool_name>create_directory</tool_name>
<arguments>
{
  "path": "C:\\chemin\\vers\\nouveau_projet"
}
</arguments>
</use_mcp_tool>

<!-- Créer un nouveau fichier -->
<use_mcp_tool>
<server_name>github.com/modelcontextprotocol/servers/tree/main/src/filesystem</server_name>
<tool_name>write_file</tool_name>
<arguments>
{
  "path": "C:\\chemin\\vers\\nouveau_projet\\index.js",
  "content": "console.log('Hello, world!');"
}
</arguments>
</use_mcp_tool>

<!-- Modifier le fichier -->
<use_mcp_tool>
<server_name>github.com/modelcontextprotocol/servers/tree/main/src/filesystem</server_name>
<tool_name>edit_file</tool_name>
<arguments>
{
  "path": "C:\\chemin\\vers\\nouveau_projet\\index.js",
  "edits": [
    {
      "oldText": "console.log('Hello, world!');",
      "newText": "console.log('Hello, Roo!');"
    }
  ]
}
</arguments>
</use_mcp_tool>
```

### Scénario 3: Recherche de contenu dans des fichiers

Ce scénario montre comment utiliser le serveur MCP Filesystem pour rechercher du contenu dans des fichiers:

```xml
<!-- Rechercher tous les fichiers contenant le mot "TODO" -->
<use_mcp_tool>
<server_name>github.com/modelcontextprotocol/servers/tree/main/src/filesystem</server_name>
<tool_name>search_files</tool_name>
<arguments>
{
  "path": "C:\\chemin\\vers\\projet",
  "pattern": "*.*",
  "content": "TODO"
}
</arguments>
</use_mcp_tool>
```

## Bonnes pratiques

1. **Utilisez des chemins absolus**: Pour éviter les confusions, utilisez toujours des chemins absolus.
2. **Vérifiez les répertoires autorisés**: Avant d'utiliser le serveur MCP Filesystem, vérifiez quels répertoires sont autorisés.
3. **Gérez les erreurs**: Prévoyez toujours un plan B en cas d'erreur lors de l'utilisation du serveur MCP Filesystem.
4. **Limitez les accès**: N'autorisez que les répertoires nécessaires pour des raisons de sécurité.
5. **Utilisez les outils appropriés**: Choisissez l'outil le plus adapté à votre besoin (par exemple, utilisez `read_multiple_files` au lieu de plusieurs appels à `read_file`).