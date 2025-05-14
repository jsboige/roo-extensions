# Git MCP Server pour Roo

Le Git MCP Server est un serveur implémentant le [Model Context Protocol (MCP)](https://modelcontextprotocol.io/introduction) qui permet à Roo d'interagir avec des dépôts Git locaux. Ce serveur permet d'effectuer des opérations Git courantes comme commit, push, pull, branch, status, etc.

## Fonctionnalités principales

- **Opérations Git de base** : status, add, commit, push, pull
- **Gestion des branches** : création, suppression, liste, checkout
- **Initialisation et clonage** : init, clone
- **Actions en masse** : exécution de plusieurs opérations Git en séquence

## Prérequis

- Git installé et configuré sur votre système
- Node.js (version 14 ou supérieure)
- npm (généralement installé avec Node.js)

## Installation

### Méthode 1 : Installation via NPX (recommandée)

La méthode la plus simple pour installer le serveur MCP Git est d'utiliser npx :

```bash
# Installation et exécution en une seule commande
npx git-mcp-server
```

### Méthode 2 : Installation globale via NPM

Si vous préférez installer le package globalement :

```bash
# Installation globale
npm install -g git-mcp-server

# Exécution après installation
git-mcp-server
```

### Méthode 3 : Installation locale dans un projet

Si vous souhaitez intégrer le serveur MCP Git dans un projet spécifique :

```bash
# Création d'un dossier pour le projet (si nécessaire)
mkdir git-mcp-project
cd git-mcp-project

# Initialisation du projet (si nécessaire)
npm init -y

# Installation locale
npm install git-mcp-server

# Exécution via npx
npx git-mcp-server
```

## Configuration dans Roo

### ⚠️ Points importants à noter

1. **Nom du serveur** : Utilisez un nom simple comme "git" plutôt qu'un chemin GitHub complet pour éviter les problèmes de configuration.
2. **Évitez le suffixe "-global"** : N'ajoutez pas "-global" au nom du serveur, car cela peut causer des problèmes de reconnaissance.
3. **Chemins absolus** : Utilisez des chemins absolus pour les répertoires Git, pas des variables d'environnement comme `%APPDATA%`.

### Configuration recommandée

Voici la configuration recommandée pour le serveur MCP Git dans Roo :

```json
{
  "git": {
    "command": "git-mcp-server",
    "args": [],
    "env": {
      "MCP_TRANSPORT_TYPE": "stdio",
      "MCP_LOG_LEVEL": "info",
      "GIT_SIGN_COMMITS": "false",
      "GIT_DEFAULT_PATH": "D:\\votre\\chemin\\projet"
    },
    "disabled": false,
    "autoApprove": [],
    "alwaysAllow": [
      "status",
      "add",
      "commit",
      "push",
      "pull",
      "branch_list",
      "branch_create",
      "branch_delete",
      "checkout",
      "init",
      "clone"
    ],
    "transportType": "stdio"
  }
}
```

### Configuration alternative (exécution directe)

Si vous rencontrez des problèmes avec la commande `git-mcp-server`, vous pouvez utiliser cette configuration alternative qui exécute directement le fichier JavaScript du serveur :

```json
{
  "git": {
    "command": "cmd",
    "args": [
      "/c",
      "node",
      "C:\\Users\\<username>\\AppData\\Roaming\\npm\\node_modules\\git-mcp-server\\dist\\index.js"
    ],
    "env": {
      "MCP_TRANSPORT_TYPE": "stdio",
      "MCP_LOG_LEVEL": "info",
      "GIT_SIGN_COMMITS": "false",
      "GIT_DEFAULT_PATH": "D:\\votre\\chemin\\projet"
    },
    "disabled": false,
    "autoApprove": [],
    "alwaysAllow": [
      "status",
      "add",
      "commit",
      "push",
      "pull",
      "branch_list",
      "branch_create",
      "branch_delete",
      "checkout",
      "init",
      "clone"
    ],
    "transportType": "stdio"
  }
}
```

> **Important** : Remplacez `<username>` par votre nom d'utilisateur Windows et `D:\\votre\\chemin\\projet` par le chemin absolu vers votre projet.

## Utilisation

### Exemples d'utilisation avec Roo

Voici quelques exemples de commandes que vous pouvez utiliser avec Roo pour interagir avec Git :

#### Vérifier le statut d'un dépôt

```
use_mcp_tool
server_name: git
tool_name: status
arguments: {
  "path": "D:\\votre\\chemin\\projet"
}
```

#### Ajouter des fichiers et faire un commit

```
use_mcp_tool
server_name: git
tool_name: bulk_action
arguments: {
  "path": "D:\\votre\\chemin\\projet",
  "actions": [
    {
      "type": "stage",
      "files": ["D:\\votre\\chemin\\projet\\fichier1.txt", "D:\\votre\\chemin\\projet\\fichier2.txt"]
    },
    {
      "type": "commit",
      "message": "Ajout de nouveaux fichiers"
    }
  ]
}
```

#### Créer une nouvelle branche et basculer dessus

```
use_mcp_tool
server_name: git
tool_name: branch_create
arguments: {
  "path": "D:\\votre\\chemin\\projet",
  "name": "nouvelle-fonctionnalite"
}

use_mcp_tool
server_name: git
tool_name: checkout
arguments: {
  "path": "D:\\votre\\chemin\\projet",
  "target": "nouvelle-fonctionnalite"
}
```

## Résolution des problèmes

### Le serveur ne démarre pas

- Vérifiez que Git est correctement installé : `git --version`
- Vérifiez que Node.js est correctement installé : `node --version`
- Essayez d'installer le package globalement : `npm install -g git-mcp-server`
- Vérifiez les journaux d'erreur dans la console

### Problèmes de configuration dans Roo

1. **Problème** : Erreur "Server not found" ou "Tool not found"
   **Solution** : Assurez-vous que le nom du serveur dans la configuration est simple (ex: "git") et non un chemin complet.

2. **Problème** : Erreur "Command not found"
   **Solution** : Utilisez la configuration alternative avec le chemin complet vers le fichier JavaScript.

3. **Problème** : Erreur "Path not found"
   **Solution** : Assurez-vous que le chemin dans `GIT_DEFAULT_PATH` est un chemin absolu valide et que les barres obliques inverses sont doublées (`\\`).

### Problèmes d'exécution des commandes Git

1. **Problème** : Erreur "Not a git repository"
   **Solution** : Assurez-vous que le chemin spécifié est un dépôt Git valide ou initialisez-le avec la commande `init`.

2. **Problème** : Erreur d'authentification lors du push
   **Solution** : Configurez Git avec vos identifiants (`git config --global user.name` et `git config --global user.email`) ou utilisez un gestionnaire d'identifiants.

## Ressources supplémentaires

- [Documentation Git](https://git-scm.com/doc)
- [Documentation MCP](https://modelcontextprotocol.io/introduction)