# Win-CLI MCP pour Roo

Ce dossier contient la documentation et les instructions pour l'installation et la configuration du serveur MCP Win-CLI utilisé avec Roo.

## Qu'est-ce que Win-CLI ?

Win-CLI est un serveur MCP qui permet à Roo d'exécuter des commandes dans différents shells Windows (PowerShell, CMD, Git Bash). Il offre également des fonctionnalités pour la gestion des connexions SSH.

Ce serveur MCP est particulièrement utile pour les utilisateurs Windows qui souhaitent que Roo puisse interagir directement avec leur système d'exploitation via différents shells, sans être limité au shell par défaut.

## Fonctionnalités principales

- Exécution de commandes dans différents shells Windows :
  - PowerShell
  - CMD (Command Prompt)
  - Git Bash
- Gestion des connexions SSH
- Historique des commandes exécutées
- Exécution de commandes dans des répertoires spécifiques
- Accès direct aux ressources système via les URI

## Outils disponibles

Le serveur MCP Win-CLI fournit les outils suivants :

1. **execute_command** - Exécute une commande dans le shell spécifié
2. **get_command_history** - Récupère l'historique des commandes exécutées
3. **ssh_execute** - Exécute une commande sur un hôte distant via SSH
4. **ssh_disconnect** - Déconnecte d'un serveur SSH
5. **create_ssh_connection** - Crée une nouvelle connexion SSH
6. **read_ssh_connections** - Lit toutes les connexions SSH
7. **update_ssh_connection** - Met à jour une connexion SSH existante
8. **delete_ssh_connection** - Supprime une connexion SSH existante
9. **get_current_directory** - Récupère le répertoire de travail actuel

## Ressources directes

Le serveur MCP Win-CLI fournit également des ressources directes accessibles via des URI spécifiques :

1. **cli://currentdir** - Le répertoire de travail actuel du serveur CLI
2. **ssh://config** - Toutes les configurations de connexion SSH
3. **cli://config** - La configuration principale du serveur CLI (sans les données sensibles)

## Prérequis

- Node.js (version 14 ou supérieure)
- npm (généralement installé avec Node.js)
- Windows 10 ou 11
- PowerShell, CMD ou Git Bash installé (selon les shells que vous souhaitez utiliser)
- Pour les fonctionnalités SSH : OpenSSH Client installé

## Installation

Consultez le fichier [installation.md](./installation.md) pour les instructions détaillées d'installation.

## Configuration dans Roo

### ⚠️ Points importants à noter

1. **Nom du serveur** : Utilisez un nom simple comme "win-cli" plutôt qu'un chemin GitHub complet pour éviter les problèmes de configuration.
2. **Évitez le suffixe "-global"** : N'ajoutez pas "-global" au nom du serveur, car cela peut causer des problèmes de reconnaissance.
3. **Chemins absolus** : Utilisez des chemins absolus pour les fichiers, pas des variables d'environnement comme `%APPDATA%`.
4. **Sécurité** : Soyez prudent avec les commandes exécutées, car elles s'exécutent avec les mêmes privilèges que VS Code.

### Configuration recommandée (utilisant le script batch)

```json
{
  "win-cli": {
    "command": "cmd",
    "args": [
      "/c",
      "D:\\chemin\\vers\\external-mcps\\win-cli\\run-win-cli.bat"
    ],
    "disabled": false,
    "autoApprove": [],
    "alwaysAllow": [
      "execute_command",
      "get_command_history",
      "get_current_directory"
    ],
    "transportType": "stdio"
  }
}
```

### Configuration alternative (exécution directe)

Si vous rencontrez des problèmes avec le script batch, vous pouvez utiliser cette configuration alternative qui exécute directement le fichier JavaScript du serveur :

```json
{
  "win-cli": {
    "command": "cmd",
    "args": [
      "/c",
      "node",
      "C:\\Users\\<username>\\AppData\\Roaming\\npm\\node_modules\\@simonb97\\server-win-cli\\dist\\index.js"
    ],
    "disabled": false,
    "autoApprove": [],
    "alwaysAllow": [
      "execute_command",
      "get_command_history",
      "get_current_directory"
    ],
    "transportType": "stdio"
  }
}
```

> **Important** : Remplacez `<username>` par votre nom d'utilisateur Windows.

## Utilisation

Consultez le fichier [exemples.md](./exemples.md) pour des exemples concrets d'utilisation du serveur MCP Win-CLI avec Roo.

### Exemples rapides

#### Exécuter une commande PowerShell

```
use_mcp_tool
server_name: win-cli
tool_name: execute_command
arguments: {
  "command": "Get-Process | Sort-Object -Property CPU -Descending | Select-Object -First 5",
  "shell": "powershell"
}
```

#### Exécuter une commande CMD

```
use_mcp_tool
server_name: win-cli
tool_name: execute_command
arguments: {
  "command": "dir /b /s *.json",
  "shell": "cmd",
  "cwd": "D:\\mon\\projet"
}
```

#### Obtenir l'historique des commandes

```
use_mcp_tool
server_name: win-cli
tool_name: get_command_history
arguments: {}
```

## Fonctionnalités optimales et limitations

### Ce qui fonctionne bien
- **Commandes simples** : Les commandes basiques dans tous les shells fonctionnent parfaitement
- **Ressources directes** : L'accès aux ressources via URI est rapide et fiable
- **Gestion SSH** : La création et gestion des connexions SSH est stable
- **Historique des commandes** : Le suivi des commandes exécutées est précis

### Limitations actuelles
- **Commandes complexes** : Les commandes avec plusieurs opérateurs de redirection ou pipes complexes peuvent parfois échouer
- **Commandes interactives** : Les commandes nécessitant une interaction utilisateur continue peuvent être instables
- **Séparateurs de commandes** : Seul le séparateur `;` est pleinement supporté dans la configuration par défaut
- **Performances** : Les commandes générant une sortie volumineuse peuvent ralentir le serveur

## Résolution des problèmes

### Le serveur ne démarre pas

- Vérifiez que Node.js est correctement installé : `node --version`
- Vérifiez que npm est correctement installé : `npm --version`
- Essayez d'installer le package globalement : `npm install -g @simonb97/server-win-cli`
- Vérifiez les journaux d'erreur dans la console

### Problèmes d'exécution des commandes

1. **Problème** : Erreur "Command not found" ou "Command failed"
   **Solution** : Vérifiez que la commande existe dans le shell spécifié et que vous avez les permissions nécessaires pour l'exécuter.

2. **Problème** : Commande bloquée ou sans réponse
   **Solution** : Évitez les commandes interactives qui attendent une entrée utilisateur. Utilisez des flags pour rendre les commandes non-interactives (ex: `-y`, `-force`, etc.).

3. **Problème** : Erreur avec les chemins de fichiers
   **Solution** : Utilisez des chemins absolus et doublez les barres obliques inverses (`\\`) dans les chemins Windows.

### Problèmes de configuration dans Roo

1. **Problème** : Erreur "Server not found" ou "Tool not found"
   **Solution** : Assurez-vous que le nom du serveur dans la configuration est simple (ex: "win-cli") et non un chemin complet.

2. **Problème** : Erreur "Command not found"
   **Solution** : Vérifiez que le chemin vers la commande est correct et que le package est installé.

## Structure du dossier

- `README.md` - Ce fichier d'introduction
- `installation.md` - Guide d'installation du serveur MCP Win-CLI
- `configuration.md` - Guide de configuration du serveur MCP Win-CLI
- `exemples.md` - Exemples d'utilisation du serveur MCP Win-CLI
- `securite.md` - Bonnes pratiques de sécurité pour l'utilisation du serveur MCP Win-CLI
- `run-win-cli.bat` - Script batch pour démarrer facilement le serveur MCP Win-CLI

## Liens utiles

- [Dépôt GitHub de Win-CLI MCP](https://github.com/simonb97/server-win-cli)
- [Documentation NPM](https://www.npmjs.com/package/@simonb97/server-win-cli)
- [Documentation PowerShell](https://docs.microsoft.com/fr-fr/powershell/)
- [Documentation CMD](https://docs.microsoft.com/fr-fr/windows-server/administration/windows-commands/windows-commands)