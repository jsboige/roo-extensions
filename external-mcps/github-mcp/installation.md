# Installation du GitHub MCP Server

Ce guide détaille les étapes pour installer et configurer le GitHub MCP Server pour une utilisation avec Roo.

## Prérequis

1. **Docker** : Le GitHub MCP Server s'exécute dans un conteneur Docker. Si Docker n'est pas installé sur votre système, suivez les instructions sur [le site officiel de Docker](https://docs.docker.com/get-docker/).

2. **Token d'accès personnel GitHub (PAT)** : Vous aurez besoin d'un token GitHub avec les permissions appropriées.
   - Créez un token sur [https://github.com/settings/personal-access-tokens/new](https://github.com/settings/personal-access-tokens/new)
   - Accordez les permissions nécessaires selon vos besoins (repo, issues, pull_requests, etc.)

## Méthode 1 : Installation avec Docker (recommandée)

1. **Vérifiez que Docker est installé et en cours d'exécution** :
   ```bash
   docker --version
   ```

2. **Configurez le serveur MCP dans votre fichier de configuration Roo** :
   
   Ajoutez la configuration suivante à votre fichier `servers.json` :
   ```json
   {
     "github": {
       "command": "docker",
       "args": [
         "run",
         "-i",
         "--rm",
         "-e",
         "GITHUB_PERSONAL_ACCESS_TOKEN",
         "ghcr.io/github/github-mcp-server"
       ],
       "env": {
         "GITHUB_PERSONAL_ACCESS_TOKEN": "votre_token_github"
       }
     }
   }
   ```

3. **Remplacez `votre_token_github` par votre token d'accès personnel GitHub**.

## Méthode 2 : Installation à partir des sources

Si vous préférez ne pas utiliser Docker, vous pouvez compiler le serveur à partir des sources :

1. **Clonez le dépôt** :
   ```bash
   git clone https://github.com/github/github-mcp-server
   cd github-mcp-server
   ```

2. **Compilez le binaire** :
   ```bash
   go build -o github-mcp-server ./cmd/github-mcp-server
   ```

3. **Configurez le serveur MCP dans votre fichier de configuration Roo** :
   
   Ajoutez la configuration suivante à votre fichier `servers.json` :
   ```json
   {
     "github": {
       "command": "chemin/vers/github-mcp-server",
       "args": ["stdio"],
       "env": {
         "GITHUB_PERSONAL_ACCESS_TOKEN": "votre_token_github"
       }
     }
   }
   ```

4. **Remplacez `chemin/vers/github-mcp-server` par le chemin absolu vers le binaire compilé**.
5. **Remplacez `votre_token_github` par votre token d'accès personnel GitHub**.

## Vérification de l'installation

Pour vérifier que le GitHub MCP Server est correctement installé et configuré :

1. Redémarrez Roo ou rechargez la configuration
2. Essayez d'utiliser un outil GitHub MCP, par exemple :
   ```
   <use_mcp_tool>
   <server_name>github</server_name>
   <tool_name>get_me</tool_name>
   <arguments>
   {}
   </arguments>
   </use_mcp_tool>
   ```

Si vous recevez des informations sur votre compte GitHub, l'installation est réussie.

## Dépannage

- **Erreur "Cannot connect to the Docker daemon"** : Assurez-vous que le service Docker est en cours d'exécution.
- **Erreur d'authentification** : Vérifiez que votre token GitHub est valide et possède les permissions nécessaires.
- **Erreur "image not found"** : Assurez-vous que vous êtes connecté à Internet et que vous pouvez accéder à ghcr.io.