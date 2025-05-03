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