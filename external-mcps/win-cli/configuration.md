# Guide de configuration du serveur MCP Win-CLI

Ce guide détaille les options de configuration disponibles pour le serveur MCP Win-CLI et comment les personnaliser selon vos besoins, notamment pour l'utilisation des séparateurs de commande.

## Configuration de base

Le serveur MCP Win-CLI utilise un fichier de configuration qui peut être personnalisé pour modifier son comportement. Par défaut, le serveur crée un fichier de configuration lors de sa première exécution.

### Localisation du fichier de configuration

Le fichier de configuration se trouve à l'emplacement suivant :

- Windows : `%USERPROFILE%\.win-cli-server\config.json`

Par exemple : `C:\Users\votre-nom\.win-cli-server\config.json`

### Structure du fichier de configuration

Le fichier de configuration est au format JSON et contient plusieurs sections :

```json
{
  "server": {
    "port": 0,
    "host": "127.0.0.1"
  },
  "shells": {
    "powershell": {
      "path": "powershell.exe",
      "args": ["-NoProfile", "-ExecutionPolicy", "Bypass", "-Command"]
    },
    "cmd": {
      "path": "cmd.exe",
      "args": ["/c"]
    },
    "gitbash": {
      "path": "C:\\Program Files\\Git\\bin\\bash.exe",
      "args": ["-c"]
    }
  },
  "security": {
    "allowedCommands": ["*"],
    "blockedCommands": [],
    "commandSeparators": [";", "&&", "||", "|"],
    "allowCommandChaining": true
  },
  "ssh": {
    "enabled": true,
    "connections": {}
  },
  "history": {
    "enabled": true,
    "maxEntries": 100
  },
  "logging": {
    "level": "info",
    "file": null
  }
}
```

## Configuration des séparateurs de commande

L'une des personnalisations importantes concerne les séparateurs de commande, qui permettent d'exécuter plusieurs commandes en une seule requête. Par défaut, Win-CLI bloque certains séparateurs pour des raisons de sécurité.

### Personnalisation des séparateurs autorisés

Pour personnaliser les séparateurs de commande autorisés, modifiez la section `security.commandSeparators` dans le fichier de configuration :

```json
"security": {
  "commandSeparators": [";", "&&", "||", "|"]
}
```

Les séparateurs courants sont :
- `;` - Exécute la commande suivante quelle que soit la réussite de la précédente
- `&&` - Exécute la commande suivante uniquement si la précédente a réussi
- `||` - Exécute la commande suivante uniquement si la précédente a échoué
- `|` - Redirige la sortie de la commande précédente vers l'entrée de la suivante (pipe)

### Activation/désactivation du chaînage de commandes

Vous pouvez activer ou désactiver complètement le chaînage de commandes avec le paramètre `security.allowCommandChaining` :

```json
"security": {
  "allowCommandChaining": true
}
```

- `true` : Le chaînage de commandes est autorisé (avec les séparateurs définis)
- `false` : Le chaînage de commandes est désactivé (tous les séparateurs sont bloqués)

## Configuration des shells

Vous pouvez personnaliser les shells disponibles et leurs paramètres :

### PowerShell

```json
"powershell": {
  "path": "powershell.exe",
  "args": ["-NoProfile", "-ExecutionPolicy", "Bypass", "-Command"]
}
```

### CMD (Command Prompt)

```json
"cmd": {
  "path": "cmd.exe",
  "args": ["/c"]
}
```

### Git Bash

```json
"gitbash": {
  "path": "C:\\Program Files\\Git\\bin\\bash.exe",
  "args": ["-c"]
}
```

Si Git est installé dans un emplacement différent, ajustez le chemin en conséquence.

## Configuration de la sécurité

### Commandes autorisées et bloquées

Vous pouvez définir des listes de commandes autorisées ou bloquées :

```json
"security": {
  "allowedCommands": ["*"],  // Toutes les commandes sont autorisées
  "blockedCommands": ["rm", "del", "format"]  // Ces commandes sont bloquées
}
```

- `allowedCommands` : Liste des commandes autorisées (`["*"]` pour toutes)
- `blockedCommands` : Liste des commandes explicitement bloquées

### Exemple de configuration sécurisée

Pour une configuration plus sécurisée, vous pouvez limiter les commandes autorisées :

```json
"security": {
  "allowedCommands": ["dir", "ls", "echo", "type", "cat"],
  "blockedCommands": [],
  "commandSeparators": [";"],
  "allowCommandChaining": true
}
```

Cette configuration n'autorise que les commandes de listage et d'affichage, et uniquement le séparateur `;`.

## Configuration SSH

### Activation/désactivation de SSH

```json
"ssh": {
  "enabled": true
}
```

### Configuration des connexions SSH

Les connexions SSH sont stockées dans la section `ssh.connections` :

```json
"ssh": {
  "connections": {
    "mon-serveur": {
      "host": "192.168.1.100",
      "port": 22,
      "username": "utilisateur",
      "password": "motdepasse"
    }
  }
}
```

Pour des raisons de sécurité, il est recommandé d'utiliser des clés SSH plutôt que des mots de passe :

```json
"mon-serveur-securise": {
  "host": "192.168.1.101",
  "port": 22,
  "username": "utilisateur",
  "privateKeyPath": "C:\\Users\\votre-nom\\.ssh\\id_rsa"
}
```

## Configuration de l'historique

Vous pouvez configurer l'historique des commandes :

```json
"history": {
  "enabled": true,
  "maxEntries": 100
}
```

## Configuration de la journalisation

```json
"logging": {
  "level": "info",  // Niveaux possibles : error, warn, info, debug
  "file": "win-cli-server.log"  // null pour la console uniquement
}
```

## Exemple de configuration complète optimisée pour Roo

Voici un exemple de configuration optimisée pour l'utilisation avec Roo, avec les séparateurs de commande configurés comme demandé :

```json
{
  "server": {
    "port": 0,
    "host": "127.0.0.1"
  },
  "shells": {
    "powershell": {
      "path": "powershell.exe",
      "args": ["-NoProfile", "-ExecutionPolicy", "Bypass", "-Command"]
    },
    "cmd": {
      "path": "cmd.exe",
      "args": ["/c"]
    },
    "gitbash": {
      "path": "C:\\Program Files\\Git\\bin\\bash.exe",
      "args": ["-c"]
    }
  },
  "security": {
    "allowedCommands": ["*"],
    "blockedCommands": [],
    "commandSeparators": [";"],
    "allowCommandChaining": true
  },
  "ssh": {
    "enabled": true,
    "connections": {}
  },
  "history": {
    "enabled": true,
    "maxEntries": 1000
  },
  "logging": {
    "level": "info",
    "file": null
  }
}
```

Cette configuration :
- Autorise toutes les commandes
- N'autorise que le séparateur `;` pour le chaînage de commandes
- Active le support SSH
- Conserve un historique de 1000 commandes
- Utilise une journalisation de niveau info sans fichier journal

## Configuration dans Roo (mcp_settings.json)

En plus de la configuration du serveur MCP Win-CLI lui-même, il est nécessaire de configurer Roo pour qu'il puisse se connecter au serveur. Cette configuration se fait dans le fichier `mcp_settings.json` de Roo.

### Localisation du fichier mcp_settings.json

Le fichier `mcp_settings.json` se trouve généralement à l'emplacement suivant :

- Windows : `%USERPROFILE%\AppData\Roaming\Code\User\globalStorage\rooveterinaryinc.roo-cline\settings\mcp_settings.json`

Par exemple : `C:\Users\votre-nom\AppData\Roaming\Code\User\globalStorage\rooveterinaryinc.roo-cline\settings\mcp_settings.json`

### Configuration du serveur Win-CLI dans mcp_settings.json

Voici un exemple de configuration pour le serveur MCP Win-CLI dans le fichier `mcp_settings.json` :

```json
{
  "mcpServers": {
    "win-cli": {
      "autoApprove": [],
      "alwaysAllow": [
        "execute_command",
        "get_command_history",
        "ssh_execute",
        "ssh_disconnect",
        "create_ssh_connection",
        "read_ssh_connections",
        "update_ssh_connection",
        "delete_ssh_connection",
        "get_current_directory"
      ],
      "command": "cmd",
      "args": [
        "/c",
        "npx",
        "-y",
        "@simonb97/server-win-cli"
      ],
      "transportType": "stdio",
      "disabled": false
    }
  }
}
```

<<<<<<< HEAD
### Explication des paramètres

- `win-cli` : Nom du serveur MCP, utilisé pour l'identifier dans Roo
- `autoApprove` : Liste des outils qui seront automatiquement approuvés sans demander confirmation à l'utilisateur (vide par défaut pour des raisons de sécurité)
- `alwaysAllow` : Liste des outils fournis par le serveur MCP Win-CLI qui sont autorisés à être utilisés
- `command` : Commande utilisée pour démarrer le serveur (ici, `cmd`)
- `args` : Arguments passés à la commande pour démarrer le serveur
- `transportType` : Type de transport utilisé pour la communication avec le serveur (ici, `stdio`)
- `disabled` : Indique si le serveur est désactivé ou non

### Utilisation du script batch dans la configuration

Vous pouvez également configurer Roo pour utiliser le script batch `run-win-cli.bat` au lieu de la commande npx directe :

```json
{
  "mcpServers": {
    "win-cli": {
      "autoApprove": [],
      "alwaysAllow": [
        "execute_command",
        "get_command_history",
        "ssh_execute",
        "ssh_disconnect",
        "create_ssh_connection",
        "read_ssh_connections",
        "update_ssh_connection",
        "delete_ssh_connection",
        "get_current_directory"
      ],
      "command": "cmd",
      "args": [
        "/c",
        "chemin\\vers\\external-mcps\\win-cli\\run-win-cli.bat"
      ],
      "transportType": "stdio",
      "disabled": false
    }
=======
### Explication des paramètres

- `win-cli` : Nom du serveur MCP, utilisé pour l'identifier dans Roo
- `autoApprove` : Liste des outils qui seront automatiquement approuvés sans demander confirmation à l'utilisateur (vide par défaut pour des raisons de sécurité)
- `alwaysAllow` : Liste des outils fournis par le serveur MCP Win-CLI qui sont autorisés à être utilisés
- `command` : Commande utilisée pour démarrer le serveur (ici, `cmd`)
- `args` : Arguments passés à la commande pour démarrer le serveur
- `transportType` : Type de transport utilisé pour la communication avec le serveur (ici, `stdio`)
- `disabled` : Indique si le serveur est désactivé ou non

### Utilisation du script batch dans la configuration

Vous pouvez également configurer Roo pour utiliser le script batch `run-win-cli.bat` au lieu de la commande npx directe :

```json
{
  "mcpServers": {
    "win-cli": {
      "autoApprove": [],
      "alwaysAllow": [
        "execute_command",
        "get_command_history",
        "ssh_execute",
        "ssh_disconnect",
        "create_ssh_connection",
        "read_ssh_connections",
        "update_ssh_connection",
        "delete_ssh_connection",
        "get_current_directory"
      ],
      "command": "cmd",
      "args": [
        "/c",
        "chemin\\vers\\external-mcps\\win-cli\\run-win-cli.bat"
      ],
      "transportType": "stdio",
      "disabled": false
    }
>>>>>>> 6bb8c4a8d5ed77761b5c2552312f55a719a7082b
  }
}
```

Remplacez `chemin\\vers\\` par le chemin absolu vers le répertoire contenant le script.

### Modification de la configuration

Pour modifier la configuration du serveur MCP Win-CLI dans Roo :

1. Ouvrez VS Code
2. Accédez aux paramètres de Roo (via l'icône de menu ⋮)
3. Allez dans la section "MCP Servers"
4. Modifiez les paramètres du serveur "win-cli" selon vos besoins
5. Sauvegardez les paramètres
6. Redémarrez VS Code pour appliquer les changements

### Optimisation des commandes complexes

Cette configuration :
- Augmente le délai d'attente pour les commandes longues (30 secondes)
- Limite la taille maximale de sortie pour éviter les problèmes de mémoire
- Définit une taille de tampon appropriée pour les sorties volumineuses
- Active la division automatique des commandes complexes

### Optimisation des séparateurs de commande

Si vous rencontrez des problèmes avec les séparateurs de commande, vous pouvez utiliser cette configuration plus restrictive mais plus stable :

```json
{
  "security": {
    "commandSeparators": [";"],
    "allowCommandChaining": true,
    "maxCommandsPerChain": 3,
    "validateEachCommand": true
  }
}
```

Cette configuration :
- N'autorise que le séparateur `;`
- Limite le nombre de commandes par chaîne à 3
- Valide chaque commande individuellement avant exécution

## Application des modifications

Après avoir modifié le fichier de configuration :

1. Sauvegardez le fichier
2. Redémarrez le serveur MCP Win-CLI
3. Vérifiez que les modifications sont prises en compte

## Résolution des problèmes

### Problèmes de syntaxe JSON

Si le serveur ne démarre pas après modification du fichier de configuration :
- Vérifiez la syntaxe JSON (virgules, accolades, etc.)
- Utilisez un validateur JSON en ligne
- Restaurez la configuration par défaut et réappliquez vos modifications progressivement

### Problèmes de séparateurs de commande

Si les séparateurs de commande ne fonctionnent pas comme prévu :
- Vérifiez que `allowCommandChaining` est défini sur `true`
- Vérifiez que le séparateur que vous utilisez est dans la liste `commandSeparators`
- Testez avec une commande simple comme `echo Hello ; echo World`