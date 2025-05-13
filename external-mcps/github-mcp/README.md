# GitHub MCP Server pour Roo

Le GitHub MCP Server est un serveur implémentant le [Model Context Protocol (MCP)](https://modelcontextprotocol.io/introduction) qui permet une intégration transparente avec les API GitHub. Ce serveur permet aux modèles d'IA comme Roo d'interagir directement avec GitHub pour automatiser des tâches, extraire des données et interagir avec l'écosystème GitHub.

## Fonctionnalités principales

- **Interaction avec les dépôts GitHub** : création, modification et lecture de fichiers, gestion des branches et des commits
- **Gestion des issues** : création, lecture, mise à jour et commentaires sur les issues
- **Gestion des pull requests** : création, fusion, révision et commentaires sur les PR
- **Recherche de code** : recherche de code dans les dépôts GitHub
- **Sécurité du code** : accès aux alertes de sécurité et de scan de code
- **Gestion des utilisateurs** : recherche et information sur les utilisateurs GitHub

## Outils disponibles

Le serveur MCP GitHub fournit de nombreux outils, dont les plus couramment utilisés sont :

1. **create_or_update_file** - Crée ou met à jour un fichier dans un dépôt GitHub
2. **search_repositories** - Recherche des dépôts GitHub
3. **create_repository** - Crée un nouveau dépôt GitHub
4. **get_file_contents** - Récupère le contenu d'un fichier ou d'un répertoire
5. **push_files** - Pousse plusieurs fichiers vers un dépôt en un seul commit
6. **create_issue** - Crée une nouvelle issue dans un dépôt
7. **create_pull_request** - Crée une nouvelle pull request

## Prérequis

- Node.js (version 14 ou supérieure)
- npm (généralement installé avec Node.js)
- Un token d'accès personnel GitHub (PAT) avec les autorisations appropriées

## Installation

Consultez le fichier [installation.md](./installation.md) pour les instructions détaillées d'installation.

## Configuration dans Roo

### ⚠️ Points importants à noter

1. **Nom du serveur** : Utilisez un nom simple comme "github" plutôt qu'un chemin GitHub complet comme "github.com/modelcontextprotocol/servers/tree/main/src/github" pour éviter les problèmes de configuration.
2. **Évitez le suffixe "-global"** : N'ajoutez pas "-global" au nom du serveur, car cela peut causer des problèmes de reconnaissance.
3. **Sécurité du token** : Ne partagez jamais votre token GitHub et ne le stockez pas dans des fichiers publics.
4. **Chemins absolus** : Utilisez des chemins absolus pour les fichiers, pas des variables d'environnement.

### Configuration recommandée

```json
{
  "github": {
    "command": "cmd",
    "args": [
      "/c",
      "npx",
      "-y",
      "@modelcontextprotocol/server-github"
    ],
    "env": {
      "GITHUB_PERSONAL_ACCESS_TOKEN": "votre_token_github_ici"
    },
    "disabled": false,
    "autoApprove": [],
    "alwaysAllow": [
      "search_repositories",
      "get_file_contents",
      "create_repository",
      "create_or_update_file",
      "push_files",
      "create_issue",
      "create_pull_request"
    ],
    "transportType": "stdio"
  }
}
```

> **Important** : Remplacez `votre_token_github_ici` par votre token d'accès personnel GitHub. Ne partagez jamais ce token et ne le stockez pas dans des fichiers publics.

## Utilisation

Consultez le fichier [exemples.md](./exemples.md) pour des exemples concrets d'utilisation du GitHub MCP Server avec Roo.

### Exemples rapides

#### Rechercher des dépôts GitHub

```
use_mcp_tool
server_name: github
tool_name: search_repositories
arguments: {
  "query": "language:javascript stars:>1000"
}
```

#### Récupérer le contenu d'un fichier

```
use_mcp_tool
server_name: github
tool_name: get_file_contents
arguments: {
  "owner": "username",
  "repo": "repository",
  "path": "README.md"
}
```

#### Créer un nouveau dépôt

```
use_mcp_tool
server_name: github
tool_name: create_repository
arguments: {
  "name": "nouveau-projet",
  "description": "Un nouveau projet créé avec Roo",
  "private": true,
  "autoInit": true
}
```

## Résolution des problèmes

### Le serveur ne démarre pas

- Vérifiez que Node.js est correctement installé : `node --version`
- Vérifiez que npm est correctement installé : `npm --version`
- Essayez d'installer le package globalement : `npm install -g @modelcontextprotocol/server-github`
- Vérifiez les journaux d'erreur dans la console

### Problèmes d'authentification

1. **Problème** : Erreur "Bad credentials" ou "Unauthorized"
   **Solution** : Vérifiez que votre token GitHub est valide et a les autorisations nécessaires. Vous pouvez créer un nouveau token dans les paramètres de votre compte GitHub.

2. **Problème** : Erreur "Token not found"
   **Solution** : Assurez-vous que la variable d'environnement `GITHUB_PERSONAL_ACCESS_TOKEN` est correctement définie dans la configuration.

### Problèmes de configuration dans Roo

1. **Problème** : Erreur "Server not found" ou "Tool not found"
   **Solution** : Assurez-vous que le nom du serveur dans la configuration est simple (ex: "github") et non un chemin complet.

2. **Problème** : Erreur "Command not found"
   **Solution** : Vérifiez que le chemin vers la commande est correct et que le package est installé.

## Licence

Ce projet est distribué sous licence MIT. Voir le fichier [LICENSE](./server/LICENSE) pour plus de détails.