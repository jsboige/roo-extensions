# Installation du serveur MCP Filesystem

Ce guide détaille les étapes pour installer et configurer le serveur MCP Filesystem qui permet à Roo d'interagir avec le système de fichiers local.

## Prérequis

- Node.js (version 14 ou supérieure)
- NPM (version 6 ou supérieure)

## Installation

### 1. Installation via NPM

Le moyen le plus simple d'installer le serveur MCP Filesystem est d'utiliser NPM:

```bash
npm install -g @modelcontextprotocol/server-filesystem
```

Cette commande installe le serveur MCP Filesystem globalement sur votre système, ce qui vous permet de l'exécuter depuis n'importe quel répertoire.

### 2. Vérification de l'installation

Pour vérifier que l'installation s'est bien déroulée, vous pouvez exécuter:

```bash
npx @modelcontextprotocol/server-filesystem --help
```

Cette commande devrait afficher l'aide du serveur MCP Filesystem avec les options disponibles.

## Configuration dans Roo

Pour utiliser le serveur MCP Filesystem avec Roo, vous devez l'ajouter à la configuration MCP de Roo. Voici comment procéder:

1. Ouvrez le fichier de configuration MCP de Roo:
   ```
   %APPDATA%\Code\User\globalStorage\rooveterinaryinc.roo-cline\settings\mcp_settings.json
   ```

2. Ajoutez la configuration du serveur MCP Filesystem:
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
           "C:\\chemin\\vers\\repertoire\\autorise"
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

3. Remplacez `C:\\chemin\\vers\\repertoire\\autorise` par le chemin du répertoire auquel vous souhaitez que le serveur MCP Filesystem ait accès. Vous pouvez spécifier plusieurs répertoires en les séparant par des virgules.

4. Ajustez la liste `alwaysAllow` selon les outils que vous souhaitez autoriser sans confirmation.

## Installation manuelle (alternative)

Si vous préférez ne pas installer le package globalement, vous pouvez également l'utiliser directement avec `npx`:

```bash
npx @modelcontextprotocol/server-filesystem C:\\chemin\\vers\\repertoire\\autorise
```

## Dépannage

### Problème: Le serveur MCP Filesystem n'est pas reconnu

Si vous obtenez une erreur indiquant que le serveur MCP Filesystem n'est pas reconnu, assurez-vous que:

1. Node.js et NPM sont correctement installés
2. Le package `@modelcontextprotocol/server-filesystem` est installé
3. Le chemin vers Node.js est dans votre variable d'environnement PATH

### Problème: Erreur d'accès refusé

Si vous obtenez une erreur d'accès refusé lors de l'utilisation du serveur MCP Filesystem, assurez-vous que:

1. Le répertoire que vous essayez d'accéder est dans la liste des répertoires autorisés
2. Vous avez les permissions nécessaires pour accéder à ce répertoire

## Mise à jour

Pour mettre à jour le serveur MCP Filesystem vers la dernière version, utilisez:

```bash
npm update -g @modelcontextprotocol/server-filesystem
```

## Désinstallation

Si vous souhaitez désinstaller le serveur MCP Filesystem, utilisez:

```bash
npm uninstall -g @modelcontextprotocol/server-filesystem