# Installation du Git MCP Server

Ce guide détaille les étapes pour installer et configurer le Git MCP Server pour une utilisation avec Roo.

## Prérequis

1. **Node.js (>=18.0.0)** : Le Git MCP Server nécessite Node.js version 18.0.0 ou supérieure. Si Node.js n'est pas installé sur votre système, suivez les instructions sur [le site officiel de Node.js](https://nodejs.org/).

2. **Git** : Le Git MCP Server utilise Git en arrière-plan pour exécuter les commandes. Assurez-vous que Git est installé et accessible dans le PATH du système. Vous pouvez télécharger Git depuis [le site officiel de Git](https://git-scm.com/).

## Méthode 1 : Installation via npm (recommandée)

1. **Installez le package globalement** :
   ```bash
   npm install -g git-mcp-server
   ```

2. **Configurez le serveur MCP dans votre fichier de configuration Roo** :
   
   Ajoutez la configuration suivante à votre fichier `servers.json` :
   ```json
   {
     "git": {
       "command": "git-mcp-server",
       "args": [],
       "env": {
         "MCP_TRANSPORT_TYPE": "stdio"
       },
       "disabled": false
     }
   }
   ```

## Méthode 2 : Installation à partir des sources

1. **Clonez le dépôt** :
   ```bash
   git clone https://github.com/cyanheads/git-mcp-server.git
   cd git-mcp-server
   ```

2. **Installez les dépendances** :
   ```bash
   npm install
   ```

3. **Construisez le projet** :
   ```bash
   npm run build
   ```

4. **Configurez le serveur MCP dans votre fichier de configuration Roo** :
   
   Ajoutez la configuration suivante à votre fichier `servers.json` :
   ```json
   {
     "git": {
       "command": "node",
       "args": ["chemin/absolu/vers/git-mcp-server/dist/index.js"],
       "env": {
         "MCP_TRANSPORT_TYPE": "stdio"
       },
       "disabled": false
     }
   }
   ```

5. **Remplacez `chemin/absolu/vers/git-mcp-server` par le chemin absolu vers le dossier où vous avez cloné le dépôt**.

## Configuration avec transport HTTP (optionnel)

Si vous préférez utiliser le transport HTTP au lieu de stdio :

1. **Modifiez la configuration dans votre fichier `servers.json`** :
   ```json
   {
     "git": {
       "command": "node",
       "args": ["chemin/absolu/vers/git-mcp-server/dist/index.js"],
       "env": {
         "MCP_TRANSPORT_TYPE": "http",
         "MCP_HTTP_PORT": "3010",
         "MCP_HTTP_HOST": "127.0.0.1"
       },
       "disabled": false
     }
   }
   ```

## Vérification de l'installation

Pour vérifier que le Git MCP Server est correctement installé et configuré :

1. Redémarrez Roo ou rechargez la configuration
2. Essayez d'utiliser un outil Git MCP, par exemple :
   ```
   <use_mcp_tool>
   <server_name>git</server_name>
   <tool_name>git_status</tool_name>
   <arguments>
   {}
   </arguments>
   </use_mcp_tool>
   ```

Si vous recevez des informations sur l'état du dépôt Git, l'installation est réussie.

## Dépannage

- **Erreur "Command not found"** : Assurez-vous que Node.js et Git sont correctement installés et accessibles dans le PATH du système.
- **Erreur "Cannot find module"** : Vérifiez que toutes les dépendances ont été installées avec `npm install`.
- **Erreur de connexion avec le transport HTTP** : Vérifiez que le port spécifié n'est pas déjà utilisé par une autre application.