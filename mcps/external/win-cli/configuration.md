# Configuration du MCP Win-CLI

<!-- START_SECTION: introduction -->
## Introduction

Ce guide détaille les options de configuration disponibles pour le serveur MCP Win-CLI et comment les personnaliser selon vos besoins. Une configuration appropriée vous permettra d'optimiser l'utilisation des différents shells, de sécuriser l'exécution des commandes et de gérer efficacement les connexions SSH.
<!-- END_SECTION: introduction -->

<!-- START_SECTION: configuration_file -->
## Fichier de configuration

### Localisation du fichier de configuration

Le fichier de configuration se trouve à l'emplacement suivant:

- Windows: `%USERPROFILE%\.win-cli-server\config.json`

Par exemple: `C:\Users\votre-nom\.win-cli-server\config.json`

### Création du fichier de configuration

Le serveur MCP Win-CLI crée automatiquement un fichier de configuration avec des valeurs par défaut lors de sa première exécution. Vous pouvez également créer manuellement ce fichier:

1. Créez le répertoire `.win-cli-server` dans votre répertoire utilisateur:
   ```bash
   mkdir "%USERPROFILE%\.win-cli-server"
   ```

2. Créez un fichier `config.json` dans ce répertoire avec votre configuration personnalisée

### Structure du fichier de configuration

Le fichier de configuration est au format JSON et contient plusieurs sections:

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
<!-- END_SECTION: configuration_file -->

<!-- START_SECTION: server_configuration -->
## Configuration du serveur

La section `server` du fichier de configuration permet de définir les paramètres réseau du serveur MCP Win-CLI:

```json
"server": {
  "port": 0,
  "host": "127.0.0.1"
}
```

### Options disponibles

| Option | Description | Valeur par défaut |
|--------|-------------|-------------------|
| `port` | Port sur lequel le serveur écoute | `0` (port aléatoire) |
| `host` | Adresse IP sur laquelle le serveur écoute | `127.0.0.1` |

### Port aléatoire vs port fixe

- **Port aléatoire** (`port: 0`): Le système attribuera automatiquement un port disponible. Cette option est utile pour éviter les conflits de port, mais peut rendre plus difficile la configuration d'autres services pour communiquer avec le serveur MCP.

- **Port fixe** (ex: `port: 3000`): Vous pouvez spécifier un port fixe si vous avez besoin de configurer d'autres services pour communiquer avec le serveur MCP. Assurez-vous que le port choisi n'est pas déjà utilisé par un autre service.

### Sécurité réseau

Pour des raisons de sécurité, il est recommandé de laisser la valeur `host` à `127.0.0.1` (localhost) afin que le serveur ne soit accessible que depuis la machine locale. Si vous avez besoin que le serveur soit accessible depuis d'autres machines du réseau, vous pouvez définir `host` à `0.0.0.0`, mais cela présente des risques de sécurité supplémentaires.
<!-- END_SECTION: server_configuration -->

<!-- START_SECTION: shells_configuration -->
## Configuration des shells

La section `shells` du fichier de configuration permet de définir les shells disponibles et leurs paramètres:

```json
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
}
```

### PowerShell

```json
"powershell": {
  "path": "powershell.exe",
  "args": ["-NoProfile", "-ExecutionPolicy", "Bypass", "-Command"]
}
```

Les arguments par défaut pour PowerShell:
- `-NoProfile`: Ne charge pas le profil utilisateur, ce qui accélère le démarrage
- `-ExecutionPolicy Bypass`: Contourne la politique d'exécution pour permettre l'exécution de scripts
- `-Command`: Indique que ce qui suit est une commande à exécuter

### CMD (Command Prompt)

```json
"cmd": {
  "path": "cmd.exe",
  "args": ["/c"]
}
```

L'argument `/c` indique à CMD d'exécuter la commande spécifiée puis de se terminer.

### Git Bash

```json
"gitbash": {
  "path": "C:\\Program Files\\Git\\bin\\bash.exe",
  "args": ["-c"]
}
```

L'argument `-c` indique à Bash d'exécuter la commande spécifiée.

Si Git est installé dans un emplacement différent, ajustez le chemin en conséquence.

### Ajout d'un shell personnalisé

Vous pouvez ajouter d'autres shells en suivant le même format:

```json
"shells": {
  "powershell": { ... },
  "cmd": { ... },
  "gitbash": { ... },
  "mon-shell-personnalise": {
    "path": "C:\\chemin\\vers\\mon-shell.exe",
    "args": ["-arg1", "-arg2"]
  }
}
```

Vous pourrez ensuite utiliser ce shell personnalisé avec l'outil `execute_command`:

```
Outil: execute_command
Arguments:
{
  "shell": "mon-shell-personnalise",
  "command": "ma-commande"
}
```
<!-- END_SECTION: shells_configuration -->

<!-- START_SECTION: security_configuration -->
## Configuration de la sécurité

La section `security` du fichier de configuration permet de définir les paramètres de sécurité du serveur MCP Win-CLI:

```json
"security": {
  "allowedCommands": ["*"],
  "blockedCommands": [],
  "commandSeparators": [";", "&&", "||", "|"],
  "allowCommandChaining": true
}
```

### Commandes autorisées et bloquées

- `allowedCommands`: Liste des commandes autorisées (`["*"]` pour toutes)
- `blockedCommands`: Liste des commandes explicitement bloquées

Pour limiter les commandes autorisées:

```json
"security": {
  "allowedCommands": ["dir", "ls", "echo", "type", "cat"],
  "blockedCommands": []
}
```

Pour bloquer des commandes spécifiques:

```json
"security": {
  "allowedCommands": ["*"],
  "blockedCommands": ["rm", "del", "rmdir", "format", "shutdown"]
}
```

### Séparateurs de commande

L'une des personnalisations importantes concerne les séparateurs de commande, qui permettent d'exécuter plusieurs commandes en une seule requête:

```json
"security": {
  "commandSeparators": [";"],
  "allowCommandChaining": true
}
```

Les séparateurs courants sont:
- `;` - Exécute la commande suivante quelle que soit la réussite de la précédente
- `&&` - Exécute la commande suivante uniquement si la précédente a réussi
- `||` - Exécute la commande suivante uniquement si la précédente a échoué
- `|` - Redirige la sortie de la commande précédente vers l'entrée de la suivante (pipe)

Pour une sécurité maximale, vous pouvez désactiver complètement le chaînage de commandes:

```json
"security": {
  "commandSeparators": [],
  "allowCommandChaining": false
}
```

### Configuration sécurisée recommandée

Pour une configuration plus sécurisée, vous pouvez limiter les commandes autorisées et les séparateurs:

```json
"security": {
  "allowedCommands": ["dir", "ls", "echo", "type", "cat", "npm", "node", "git"],
  "blockedCommands": ["rm", "del", "rmdir", "format", "shutdown"],
  "commandSeparators": [";"],
  "allowCommandChaining": true
}
```

Cette configuration n'autorise que les commandes spécifiées, bloque explicitement les commandes dangereuses, et n'autorise que le séparateur `;`.
<!-- END_SECTION: security_configuration -->

<!-- START_SECTION: ssh_configuration -->
## Configuration SSH

La section `ssh` du fichier de configuration permet de définir les paramètres SSH du serveur MCP Win-CLI:

```json
"ssh": {
  "enabled": true,
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

### Activation/désactivation de SSH

```json
"ssh": {
  "enabled": true
}
```

Définissez `enabled` à `false` si vous n'avez pas besoin des fonctionnalités SSH.

### Configuration des connexions SSH

Les connexions SSH sont stockées dans la section `ssh.connections`:

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

Pour des raisons de sécurité, il est recommandé d'utiliser des clés SSH plutôt que des mots de passe:

```json
"mon-serveur-securise": {
  "host": "192.168.1.101",
  "port": 22,
  "username": "utilisateur",
  "privateKeyPath": "C:\\Users\\votre-nom\\.ssh\\id_rsa",
  "passphrase": "votre-phrase-de-passe"
}
```

### Options de connexion SSH

| Option | Description | Valeur par défaut |
|--------|-------------|-------------------|
| `host` | Adresse IP ou nom d'hôte du serveur SSH | (Requis) |
| `port` | Port SSH | `22` |
| `username` | Nom d'utilisateur pour la connexion SSH | (Requis) |
| `password` | Mot de passe pour la connexion SSH | `null` |
| `privateKeyPath` | Chemin vers la clé privée SSH | `null` |
| `passphrase` | Phrase de passe pour la clé privée SSH | `null` |
| `keepaliveInterval` | Intervalle en millisecondes pour les paquets keepalive | `60000` |
| `readyTimeout` | Délai d'attente en millisecondes pour la connexion | `20000` |

> **Note**: Pour des raisons de sécurité, il est recommandé de ne pas stocker de mots de passe en texte clair dans le fichier de configuration. Utilisez plutôt des clés SSH avec des phrases de passe.
<!-- END_SECTION: ssh_configuration -->

<!-- START_SECTION: history_configuration -->
## Configuration de l'historique

La section `history` du fichier de configuration permet de définir les paramètres de l'historique des commandes:

```json
"history": {
  "enabled": true,
  "maxEntries": 100
}
```

### Options disponibles

| Option | Description | Valeur par défaut |
|--------|-------------|-------------------|
| `enabled` | Active ou désactive l'historique des commandes | `true` |
| `maxEntries` | Nombre maximum de commandes à conserver dans l'historique | `100` |

### Considérations de sécurité

L'historique des commandes peut contenir des informations sensibles. Si vous travaillez avec des données sensibles, vous pouvez:
- Désactiver l'historique: `"enabled": false`
- Limiter le nombre d'entrées: `"maxEntries": 10`
- Nettoyer régulièrement l'historique
<!-- END_SECTION: history_configuration -->

<!-- START_SECTION: logging_configuration -->
## Configuration de la journalisation

La section `logging` du fichier de configuration permet de définir les paramètres de journalisation:

```json
"logging": {
  "level": "info",
  "file": "win-cli-server.log"
}
```

### Options disponibles

| Option | Description | Valeur par défaut |
|--------|-------------|-------------------|
| `level` | Niveau de journalisation (`error`, `warn`, `info`, `debug`) | `info` |
| `file` | Fichier de journalisation (null pour la console uniquement) | `null` |

### Niveaux de journalisation

- `error`: Uniquement les erreurs
- `warn`: Erreurs et avertissements
- `info`: Erreurs, avertissements et informations générales
- `debug`: Toutes les informations, y compris les détails de débogage

### Journalisation dans un fichier

Pour enregistrer les journaux dans un fichier:

```json
"logging": {
  "level": "info",
  "file": "C:\\logs\\win-cli-server.log"
}
```

Pour la journalisation dans la console uniquement:

```json
"logging": {
  "level": "info",
  "file": null
}
```

### Rotation des journaux

Si votre version du MCP Win-CLI prend en charge la rotation des journaux:

```json
"logging": {
  "level": "info",
  "file": "win-cli-server.log",
  "rotation": {
    "maxSize": "10m",
    "maxFiles": 5
  }
}
```
<!-- END_SECTION: logging_configuration -->

<!-- START_SECTION: roo_integration -->
## Configuration dans Roo (mcp_settings.json)

En plus de la configuration du serveur MCP Win-CLI lui-même, il est nécessaire de configurer Roo pour qu'il puisse se connecter au serveur. Cette configuration se fait dans le fichier `mcp_settings.json` de Roo.

### Localisation du fichier mcp_settings.json

Le fichier `mcp_settings.json` se trouve généralement à l'emplacement suivant:

- Windows: `%USERPROFILE%\AppData\Roaming\Code\User\globalStorage\rooveterinaryinc.roo-cline\settings\mcp_settings.json`

Par exemple: `C:\Users\votre-nom\AppData\Roaming\Code\User\globalStorage\rooveterinaryinc.roo-cline\settings\mcp_settings.json`

### Configuration du serveur Win-CLI dans mcp_settings.json

Voici un exemple de configuration pour le serveur MCP Win-CLI dans le fichier `mcp_settings.json`:

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

### Explication des paramètres

- `win-cli`: Nom du serveur MCP, utilisé pour l'identifier dans Roo
- `autoApprove`: Liste des outils qui seront automatiquement approuvés sans demander confirmation à l'utilisateur (vide par défaut pour des raisons de sécurité)
- `alwaysAllow`: Liste des outils fournis par le serveur MCP Win-CLI qui sont autorisés à être utilisés
- `command`: Commande utilisée pour démarrer le serveur (ici, `cmd`)
- `args`: Arguments passés à la commande pour démarrer le serveur
- `transportType`: Type de transport utilisé pour la communication avec le serveur (ici, `stdio`)
- `disabled`: Indique si le serveur est désactivé ou non

### Utilisation du script batch dans la configuration

Vous pouvez également configurer Roo pour utiliser le script batch `run-win-cli.bat` au lieu de la commande npx directe:

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
        "chemin\\vers\\mcps\\win-cli\\run-win-cli.bat"
      ],
      "transportType": "stdio",
      "disabled": false
    }
  }
}
```

Remplacez `chemin\\vers\\` par le chemin absolu vers le répertoire contenant le script.
<!-- END_SECTION: roo_integration -->

<!-- START_SECTION: example_configurations -->
## Exemples de configurations

### Configuration optimisée pour Roo

Voici un exemple de configuration optimisée pour l'utilisation avec Roo, avec les séparateurs de commande configurés comme demandé:

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

### Configuration sécurisée

Pour un environnement où la sécurité est une priorité:

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
    }
  },
  "security": {
    "allowedCommands": [
      "dir", "ls", "type", "cat", "echo",
      "npm", "node", "git", "dotnet"
    ],
    "blockedCommands": [
      "rm", "del", "rmdir", "format", "shutdown",
      "reboot", "reg", "net user", "net localgroup"
    ],
    "commandSeparators": [],
    "allowCommandChaining": false
  },
  "ssh": {
    "enabled": false,
    "connections": {}
  },
  "history": {
    "enabled": true,
    "maxEntries": 50
  },
  "logging": {
    "level": "debug",
    "file": "C:\\logs\\win-cli-server.log"
  }
}
```

### Configuration pour le développement

Pour un environnement de développement avec des fonctionnalités étendues:

```json
{
  "server": {
    "port": 3000,
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
    },
    "python": {
      "path": "python.exe",
      "args": ["-c"]
    }
  },
  "security": {
    "allowedCommands": ["*"],
    "blockedCommands": ["format", "shutdown", "reboot"],
    "commandSeparators": [";", "&&", "||", "|"],
    "allowCommandChaining": true
  },
  "ssh": {
    "enabled": true,
    "connections": {
      "dev-server": {
        "host": "192.168.1.100",
        "port": 22,
        "username": "dev",
        "privateKeyPath": "C:\\Users\\votre-nom\\.ssh\\id_rsa"
      }
    }
  },
  "history": {
    "enabled": true,
    "maxEntries": 1000
  },
  "logging": {
    "level": "debug",
    "file": null
  }
}
```
<!-- END_SECTION: example_configurations -->

<!-- START_SECTION: applying_changes -->
## Application des modifications

Après avoir modifié le fichier de configuration:

1. Sauvegardez le fichier
2. Redémarrez le serveur MCP Win-CLI
3. Vérifiez que les modifications sont prises en compte

Si vous avez modifié la configuration dans Roo, redémarrez également VS Code pour appliquer les changements.
<!-- END_SECTION: applying_changes -->

<!-- START_SECTION: troubleshooting -->
## Résolution des problèmes

### Problèmes de syntaxe JSON

Si le serveur ne démarre pas après modification du fichier de configuration:
- Vérifiez la syntaxe JSON (virgules, accolades, etc.)
- Utilisez un validateur JSON en ligne
- Restaurez la configuration par défaut et réappliquez vos modifications progressivement

### Problèmes de séparateurs de commande

Si les séparateurs de commande ne fonctionnent pas comme prévu:
- Vérifiez que `allowCommandChaining` est défini sur `true`
- Vérifiez que le séparateur que vous utilisez est dans la liste `commandSeparators`
- Testez avec une commande simple comme `echo Hello ; echo World`

### Problèmes de chemins

Si les shells ne sont pas trouvés:
- Vérifiez que les chemins vers les exécutables des shells sont corrects
- Utilisez des doubles barres obliques inverses (`\\`) dans les chemins Windows
- Vérifiez que les shells sont correctement installés sur votre système

Pour une résolution plus détaillée des problèmes, consultez le fichier [TROUBLESHOOTING.md](./TROUBLESHOOTING.md).
<!-- END_SECTION: troubleshooting -->

<!-- START_SECTION: next_steps -->
## Prochaines étapes

Maintenant que vous avez configuré le MCP Win-CLI, vous pouvez:

1. [Apprendre à utiliser le MCP Win-CLI](./USAGE.md)
2. [Explorer les considérations de sécurité](./SECURITY.md)
3. [Résoudre les problèmes courants](./TROUBLESHOOTING.md)
<!-- END_SECTION: next_steps -->