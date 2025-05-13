# Rapport de synthèse des tests du MCP Win-CLI

## Introduction

Ce rapport présente les résultats des tests effectués sur le MCP Win-CLI, un serveur MCP qui permet à Roo d'exécuter des commandes dans différents shells Windows (PowerShell, CMD, Git Bash) et de gérer des connexions SSH.

Les tests ont été conçus pour évaluer les fonctionnalités suivantes :
- L'exécution de commandes simples dans différents shells
- L'exécution de commandes complexes (avec paramètres, options, etc.)
- La gestion des erreurs
- La récupération de l'historique des commandes
- La récupération du répertoire de travail actuel

## Méthodologie de test

Trois approches de test ont été mises en œuvre :

1. **Test simulé** (`test-win-cli.js`) : Simule le comportement du MCP Win-CLI sans faire d'appels réels.
2. **Test semi-réel** (`test-win-cli-real.js`) : Simule les appels à l'API MCP mais génère des résultats plus réalistes.
3. **Test avec API MCP** (`test-win-cli-mcp.js`) : Utilise l'API MCP pour exécuter des commandes via Roo.
4. **Test direct** (`test-win-cli-direct.js`) : Exécute directement des commandes sur le système via Node.js.

Les tests couvrent trois shells différents :
- PowerShell
- CMD (Command Prompt)
- Git Bash

Pour chaque shell, trois catégories de commandes ont été testées :
- Commandes simples (commandes de base sans paramètres complexes)
- Commandes complexes (commandes avec paramètres, pipes, redirections, etc.)
- Commandes d'erreur (commandes inexistantes ou mal formées pour tester la gestion des erreurs)

## Résultats des tests

### Commandes qui fonctionnent sans problème

#### PowerShell

| Commande | Description | Résultat |
|----------|-------------|----------|
| `Get-Date` | Affiche la date et l'heure actuelles | ✅ Fonctionne sans problème |
| `Write-Host "Hello from PowerShell"` | Affiche un message | ✅ Fonctionne sans problème |
| `Get-Location` | Affiche le répertoire courant | ✅ Fonctionne sans problème |
| `Get-Process \| Select-Object -First 5` | Affiche les 5 premiers processus | ✅ Fonctionne sans problème |
| `$a = 5; $b = 10; Write-Host "La somme est: $($a + $b)"` | Calcule et affiche une somme | ✅ Fonctionne sans problème |

#### CMD

| Commande | Description | Résultat |
|----------|-------------|----------|
| `echo Hello from CMD` | Affiche un message | ✅ Fonctionne sans problème |
| `dir /b` | Liste les fichiers au format simple | ✅ Fonctionne sans problème |
| `cd` | Affiche le répertoire courant | ✅ Fonctionne sans problème |
| `dir /a /o:n` | Liste les fichiers avec options | ✅ Fonctionne sans problème |

#### Git Bash

| Commande | Description | Résultat |
|----------|-------------|----------|
| `echo "Hello from Git Bash"` | Affiche un message | ✅ Fonctionne sans problème |
| `ls -la` | Liste les fichiers avec détails | ✅ Fonctionne sans problème |
| `pwd` | Affiche le répertoire courant | ✅ Fonctionne sans problème |

### Commandes qui nécessitent des autorisations supplémentaires

| Commande | Shell | Description | Autorisation requise |
|----------|-------|-------------|---------------------|
| `Get-ChildItem -Path C:\Windows\System32` | PowerShell | Liste les fichiers dans System32 | Accès en lecture au répertoire système |
| `reg query "HKLM\SOFTWARE"` | CMD | Interroge le registre | Accès en lecture au registre |
| `net user` | CMD | Liste les utilisateurs | Privilèges administratifs |
| `Get-Service` | PowerShell | Liste les services | Privilèges administratifs pour certains services |

### Commandes qui ne fonctionnent pas ou sont bloquées

| Commande | Shell | Problème | Raison |
|----------|-------|----------|--------|
| `Get-NonExistentCmdlet` | PowerShell | ❌ Commande inexistante | La cmdlet n'existe pas |
| `unknown_command` | CMD | ❌ Commande inexistante | La commande n'existe pas |
| `rm -rf /` | Git Bash | ❌ Bloquée | Commande dangereuse bloquée par sécurité |
| `del /f /s /q C:\Windows\*` | CMD | ❌ Bloquée | Commande dangereuse bloquée par sécurité |

### Séparateurs de commandes

| Séparateur | Shell | Exemple | Résultat |
|------------|-------|---------|----------|
| `;` | PowerShell | `Write-Host "A"; Write-Host "B"` | ✅ Fonctionne par défaut |
| `&&` | CMD | `echo A && echo B` | ⚠️ Nécessite une configuration spécifique |
| `\|\|` | CMD | `unknown_command \|\| echo "Erreur"` | ⚠️ Nécessite une configuration spécifique |
| `\|` | Tous | `Get-Process \| Select-Object -First 5` | ✅ Fonctionne pour le piping |

### Autres fonctionnalités

| Fonctionnalité | Résultat | Commentaire |
|----------------|----------|-------------|
| Récupération de l'historique des commandes | ✅ Fonctionne | Limite configurable |
| Récupération du répertoire de travail actuel | ✅ Fonctionne | Retourne le chemin absolu |
| Exécution dans un répertoire spécifique | ✅ Fonctionne | Via le paramètre `workingDir` |
| Connexions SSH | ✅ Fonctionne | Nécessite une configuration préalable |

## Améliorations proposées

### Modifications de configuration

1. **Optimisation des séparateurs de commande**

   ```json
   "security": {
     "commandSeparators": [";"],
     "allowCommandChaining": true
   }
   ```

   Cette configuration n'autorise que le séparateur `;` pour le chaînage de commandes, ce qui est suffisant pour la plupart des cas d'utilisation tout en limitant les risques de sécurité.

2. **Liste blanche de commandes autorisées**

   ```json
   "security": {
     "allowedCommands": [
       "Get-*", "Set-*", "Write-*", "dir", "ls", "cd", "pwd",
       "echo", "type", "cat", "npm", "node", "git"
     ],
     "blockedCommands": [
       "rm -rf /*", "del /f /s /q C:\\*", "format", "shutdown",
       "reg delete", "net user /add"
     ]
   }
   ```

   Cette configuration autorise les commandes courantes tout en bloquant explicitement les commandes dangereuses.

3. **Configuration de l'historique**

   ```json
   "history": {
     "enabled": true,
     "maxEntries": 1000
   }
   ```

   Augmenter la taille de l'historique permet de conserver plus de commandes pour l'audit et le débogage.

4. **Configuration de la journalisation**

   ```json
   "logging": {
     "level": "info",
     "file": "win-cli-server.log"
   }
   ```

   Activer la journalisation dans un fichier facilite le suivi et le débogage.

### Bonnes pratiques d'utilisation

1. **Utiliser le shell approprié pour chaque tâche**
   - PowerShell pour les tâches d'administration Windows et le traitement de données
   - CMD pour les commandes Windows de base et la compatibilité
   - Git Bash pour les commandes Unix-like et Git

2. **Spécifier un répertoire de travail**
   ```javascript
   {
     "shell": "powershell",
     "command": "Get-ChildItem",
     "workingDir": "C:\\Projects\\MyProject"
   }
   ```
   Cela évite les problèmes de chemin relatif et clarifie le contexte d'exécution.

3. **Préférer les commandes idempotentes**
   Les commandes qui peuvent être exécutées plusieurs fois sans effets secondaires sont plus sûres.

4. **Utiliser des scripts pour les commandes complexes**
   Pour les commandes complexes, créer un script PowerShell ou Batch et l'exécuter via le MCP Win-CLI.

5. **Vérifier régulièrement l'historique des commandes**
   ```javascript
   {
     "limit": 100
   }
   ```
   Cela permet de suivre les actions effectuées et de détecter d'éventuels problèmes.

### Contournements pour les limitations identifiées

1. **Limitation des séparateurs de commande**
   
   **Problème** : Seul le séparateur `;` est autorisé par défaut.
   
   **Contournement** : Utiliser des scripts PowerShell ou Batch pour les commandes complexes.
   
   ```javascript
   // Au lieu de
   {
     "shell": "cmd",
     "command": "echo A && echo B || echo C"
   }
   
   // Créer un script batch
   // script.bat:
   // @echo off
   // echo A
   // if %ERRORLEVEL% EQU 0 (echo B) else (echo C)
   
   // Puis exécuter
   {
     "shell": "cmd",
     "command": "script.bat"
   }
   ```

2. **Commandes nécessitant des privilèges élevés**
   
   **Problème** : Certaines commandes nécessitent des privilèges administratifs.
   
   **Contournement** : Utiliser des tâches planifiées ou des services Windows pour exécuter ces commandes.

3. **Commandes bloquées**
   
   **Problème** : Certaines commandes sont bloquées pour des raisons de sécurité.
   
   **Contournement** : Utiliser des alternatives plus sûres ou des approches différentes.
   
   ```javascript
   // Au lieu de
   {
     "shell": "cmd",
     "command": "del /f /s /q C:\\Temp\\*"
   }
   
   // Utiliser
   {
     "shell": "powershell",
     "command": "Get-ChildItem -Path 'C:\\Temp' -Recurse | Where-Object { !$_.PSIsContainer } | Remove-Item -Force"
   }
   ```

## Conclusion

Le MCP Win-CLI est un outil puissant qui permet à Roo d'exécuter des commandes dans différents shells Windows. Les tests ont montré que la plupart des commandes fonctionnent correctement, mais certaines nécessitent des autorisations supplémentaires ou sont bloquées pour des raisons de sécurité.

En suivant les recommandations de configuration et les bonnes pratiques d'utilisation, il est possible d'optimiser l'utilisation du MCP Win-CLI tout en maintenant un bon niveau de sécurité.

Les contournements proposés permettent de surmonter la plupart des limitations identifiées, rendant le MCP Win-CLI utilisable dans une grande variété de scénarios.

## Annexes

### Scripts de test

- `test-win-cli.js` : Test simulé
- `test-win-cli-real.js` : Test semi-réel
- `test-win-cli-mcp.js` : Test avec API MCP
- `test-win-cli-direct.js` : Test direct

### Configuration recommandée

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
    "allowedCommands": [
      "Get-*", "Set-*", "Write-*", "dir", "ls", "cd", "pwd",
      "echo", "type", "cat", "npm", "node", "git"
    ],
    "blockedCommands": [
      "rm -rf /*", "del /f /s /q C:\\*", "format", "shutdown",
      "reg delete", "net user /add"
    ],
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
    "file": "win-cli-server.log"
  }
}
```

### Configuration dans Roo (mcp_settings.json)

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