# Utilisation du MCP Win-CLI

<!-- START_SECTION: introduction -->
## Introduction

Ce document détaille comment utiliser le MCP Win-CLI avec Roo. Le MCP Win-CLI permet à Roo d'exécuter des commandes dans différents shells Windows (PowerShell, CMD, Git Bash) et de gérer des connexions SSH, offrant ainsi une grande flexibilité pour interagir avec le système d'exploitation.
<!-- END_SECTION: introduction -->

<!-- START_SECTION: available_tools -->
## Outils disponibles

Le MCP Win-CLI expose les outils suivants:

| Outil | Description |
|-------|-------------|
| `execute_command` | Exécute une commande dans le shell spécifié |
| `get_command_history` | Récupère l'historique des commandes exécutées |
| `ssh_execute` | Exécute une commande sur un hôte distant via SSH |
| `ssh_disconnect` | Déconnecte d'un serveur SSH |
| `create_ssh_connection` | Crée une nouvelle connexion SSH |
| `read_ssh_connections` | Lit toutes les connexions SSH |
| `update_ssh_connection` | Met à jour une connexion SSH existante |
| `delete_ssh_connection` | Supprime une connexion SSH existante |
| `get_current_directory` | Récupère le répertoire de travail actuel |
<!-- END_SECTION: available_tools -->

<!-- START_SECTION: basic_usage -->
## Utilisation de base

### Exécution de commandes PowerShell

Pour exécuter une commande PowerShell simple:

```
Outil: execute_command
Arguments:
{
  "shell": "powershell",
  "command": "Get-Process | Select-Object -First 5"
}
```

Cette commande affichera les 5 premiers processus en cours d'exécution sur le système.

### Exécution de commandes CMD

Pour exécuter une commande dans l'invite de commandes Windows:

```
Outil: execute_command
Arguments:
{
  "shell": "cmd",
  "command": "dir /b"
}
```

Cette commande listera les fichiers du répertoire courant au format simple.

### Exécution de commandes Git Bash

Pour exécuter une commande dans Git Bash:

```
Outil: execute_command
Arguments:
{
  "shell": "gitbash",
  "command": "ls -la"
}
```

Cette commande affichera la liste détaillée des fichiers, y compris les fichiers cachés.

### Exécution dans un répertoire spécifique

Pour exécuter une commande dans un répertoire spécifique:

```
Outil: execute_command
Arguments:
{
  "shell": "powershell",
  "command": "Get-ChildItem",
  "workingDir": "C:\\Users\\Public\\Documents"
}
```

Cette commande listera les fichiers dans le répertoire `C:\Users\Public\Documents`.
<!-- END_SECTION: basic_usage -->

<!-- START_SECTION: command_chaining -->
## Chaînage de commandes

### Utilisation des séparateurs de commande

Pour exécuter plusieurs commandes séparées par `;`:

```
Outil: execute_command
Arguments:
{
  "shell": "powershell",
  "command": "Write-Host 'Première commande' ; Write-Host 'Deuxième commande'"
}
```

Cette commande exécutera les deux instructions `Write-Host` l'une après l'autre.

> **Note**: Les séparateurs de commande disponibles dépendent de la configuration du serveur MCP Win-CLI. Par défaut, seul le séparateur `;` est autorisé pour des raisons de sécurité. Consultez le fichier [CONFIGURATION.md](./CONFIGURATION.md) pour plus d'informations sur la personnalisation des séparateurs autorisés.

### Commandes complexes en PowerShell

```
Outil: execute_command
Arguments:
{
  "shell": "powershell",
  "command": "$content = Get-Content -Path 'C:\\temp\\exemple.txt'; Write-Host \"Le fichier contient $($content.Length) lignes\""
}
```

Cette commande lit le contenu d'un fichier et affiche le nombre de lignes qu'il contient.

### Commandes complexes en CMD

```
Outil: execute_command
Arguments:
{
  "shell": "cmd",
  "command": "type nul > test.txt & echo Hello World > test.txt & type test.txt"
}
```

Cette commande crée un fichier, y écrit du texte, puis affiche son contenu.
<!-- END_SECTION: command_chaining -->

<!-- START_SECTION: advanced_commands -->
## Commandes avancées

### PowerShell avancé

#### Requêtes HTTP

```
Outil: execute_command
Arguments:
{
  "shell": "powershell",
  "command": "Invoke-WebRequest -Uri 'https://api.github.com/zen' | Select-Object -ExpandProperty Content"
}
```

Cette commande effectue une requête HTTP à l'API GitHub et affiche la réponse.

#### Traitement JSON

```
Outil: execute_command
Arguments:
{
  "shell": "powershell",
  "command": "$json = '{\"name\":\"John\",\"age\":30}' | ConvertFrom-Json; Write-Host \"Nom: $($json.name), Age: $($json.age)\""
}
```

Cette commande traite une chaîne JSON et affiche les valeurs extraites.

### CMD avancé

#### Informations système

```
Outil: execute_command
Arguments:
{
  "shell": "cmd",
  "command": "systeminfo | findstr /B /C:\"OS Name\" /C:\"OS Version\""
}
```

Cette commande affiche le nom et la version du système d'exploitation.

### Git Bash avancé

#### Informations système

```
Outil: execute_command
Arguments:
{
  "shell": "gitbash",
  "command": "uname -a"
}
```

Cette commande affiche des informations sur le système d'exploitation.
<!-- END_SECTION: advanced_commands -->

<!-- START_SECTION: history_management -->
## Gestion de l'historique des commandes

### Récupération de l'historique

Pour récupérer l'historique des commandes exécutées:

```
Outil: get_command_history
Arguments:
{
  "limit": 5
}
```

Cette commande affichera les 5 dernières commandes exécutées.

### Paramètres de l'historique

| Paramètre | Description | Valeur par défaut |
|-----------|-------------|-------------------|
| `limit` | Nombre maximum de commandes à récupérer | `10` |

> **Note**: L'historique des commandes doit être activé dans la configuration du serveur MCP Win-CLI pour que cette fonctionnalité soit disponible.
<!-- END_SECTION: history_management -->

<!-- START_SECTION: ssh_management -->
## Gestion des connexions SSH

### Création d'une connexion SSH

Pour créer une nouvelle connexion SSH:

```
Outil: create_ssh_connection
Arguments:
{
  "connectionId": "mon-serveur",
  "connectionConfig": {
    "host": "192.168.1.100",
    "port": 22,
    "username": "utilisateur",
    "password": "motdepasse"
  }
}
```

Cette commande crée une nouvelle connexion SSH nommée "mon-serveur".

### Création d'une connexion SSH avec clé privée

```
Outil: create_ssh_connection
Arguments:
{
  "connectionId": "mon-serveur-securise",
  "connectionConfig": {
    "host": "192.168.1.101",
    "port": 22,
    "username": "utilisateur",
    "privateKeyPath": "C:\\Users\\votre-nom\\.ssh\\id_rsa",
    "passphrase": "votre-phrase-de-passe"
  }
}
```

### Lecture des connexions SSH

Pour lister toutes les connexions SSH configurées:

```
Outil: read_ssh_connections
Arguments:
{}
```

### Exécution d'une commande via SSH

Pour exécuter une commande sur un serveur distant via SSH:

```
Outil: ssh_execute
Arguments:
{
  "connectionId": "mon-serveur",
  "command": "ls -la"
}
```

Cette commande exécute `ls -la` sur le serveur distant via SSH.

### Déconnexion SSH

Pour fermer une connexion SSH:

```
Outil: ssh_disconnect
Arguments:
{
  "connectionId": "mon-serveur"
}
```

Cette commande ferme la connexion SSH avec le serveur "mon-serveur".

### Mise à jour d'une connexion SSH

Pour mettre à jour une connexion SSH existante:

```
Outil: update_ssh_connection
Arguments:
{
  "connectionId": "mon-serveur",
  "connectionConfig": {
    "host": "192.168.1.100",
    "port": 2222,
    "username": "nouvel-utilisateur",
    "password": "nouveau-mot-de-passe"
  }
}
```

### Suppression d'une connexion SSH

Pour supprimer une connexion SSH:

```
Outil: delete_ssh_connection
Arguments:
{
  "connectionId": "mon-serveur"
}
```
<!-- END_SECTION: ssh_management -->

<!-- START_SECTION: directory_management -->
## Gestion des répertoires

### Récupération du répertoire courant

Pour obtenir le répertoire de travail actuel du serveur MCP Win-CLI:

```
Outil: get_current_directory
Arguments:
{}
```

Cette commande affiche le répertoire de travail actuel du serveur MCP Win-CLI.

### Changement de répertoire

Pour changer de répertoire de travail pour une commande spécifique:

```
Outil: execute_command
Arguments:
{
  "shell": "powershell",
  "command": "Get-ChildItem",
  "workingDir": "C:\\Users\\Public\\Documents"
}
```

> **Note**: Le changement de répertoire avec `workingDir` n'est valable que pour la commande en cours. Pour changer de répertoire de manière permanente, utilisez les commandes `cd` ou `Set-Location` du shell.
<!-- END_SECTION: directory_management -->

<!-- START_SECTION: use_cases -->
## Cas d'utilisation

### Installation et configuration d'un package npm

```
Outil: execute_command
Arguments:
{
  "shell": "powershell",
  "command": "mkdir projet-test ; cd projet-test ; npm init -y ; npm install express ; echo \"const express = require('express'); const app = express(); app.get('/', (req, res) => res.send('Hello World')); app.listen(3000);\" > index.js ; node index.js",
  "workingDir": "C:\\temp"
}
```

Ce workflow complet:
1. Crée un nouveau répertoire
2. Initialise un projet npm
3. Installe Express
4. Crée un fichier index.js avec une application Express simple
5. Démarre l'application

### Analyse de l'utilisation du disque

```
Outil: execute_command
Arguments:
{
  "shell": "powershell",
  "command": "$folders = Get-ChildItem -Directory ; foreach ($folder in $folders) { $size = (Get-ChildItem $folder.FullName -Recurse -File | Measure-Object -Property Length -Sum).Sum / 1MB ; Write-Host \"$($folder.Name): $([math]::Round($size, 2)) MB\" }"
}
```

Ce workflow analyse la taille de tous les dossiers dans le répertoire courant et affiche leur taille en mégaoctets.

### Gestion d'un serveur distant via SSH

```
Outil: create_ssh_connection
Arguments:
{
  "connectionId": "serveur-web",
  "connectionConfig": {
    "host": "192.168.1.100",
    "port": 22,
    "username": "admin",
    "privateKeyPath": "C:\\Users\\votre-nom\\.ssh\\id_rsa"
  }
}
```

```
Outil: ssh_execute
Arguments:
{
  "connectionId": "serveur-web",
  "command": "sudo systemctl status nginx"
}
```

```
Outil: ssh_execute
Arguments:
{
  "connectionId": "serveur-web",
  "command": "sudo systemctl restart nginx"
}
```

Ce workflow permet de vérifier et redémarrer un service Nginx sur un serveur distant.
<!-- END_SECTION: use_cases -->

<!-- START_SECTION: best_practices -->
## Bonnes pratiques

### Choix du shell approprié

1. **PowerShell** est recommandé pour:
   - Tâches d'administration Windows
   - Manipulation d'objets complexes (JSON, XML, etc.)
   - Accès aux fonctionnalités .NET
   - Scripts avancés avec gestion d'erreurs

2. **CMD** est recommandé pour:
   - Compatibilité maximale avec les anciens systèmes Windows
   - Scripts batch simples
   - Commandes Windows de base

3. **Git Bash** est recommandé pour:
   - Commandes Unix-like sur Windows
   - Opérations Git
   - Scripts shell bash

### Sécurité des commandes

1. **Évitez les commandes destructives** sans confirmation
2. **Validez les entrées utilisateur** avant de les utiliser dans des commandes
3. **Utilisez des chemins absolus** pour éviter les problèmes de chemin relatif
4. **Limitez l'utilisation des séparateurs de commande** aux cas nécessaires
5. **Préférez les commandes idempotentes** qui peuvent être exécutées plusieurs fois sans effets secondaires

### Gestion des erreurs

1. **Vérifiez les codes de retour** des commandes
2. **Utilisez try/catch en PowerShell** pour gérer les erreurs
3. **Journalisez les erreurs** pour faciliter le débogage

### Performance

1. **Évitez les commandes qui génèrent beaucoup de sortie**
2. **Limitez le nombre de connexions SSH simultanées**
3. **Fermez les connexions SSH** lorsqu'elles ne sont plus nécessaires
<!-- END_SECTION: best_practices -->

<!-- START_SECTION: troubleshooting -->
## Résolution des problèmes

### Problèmes courants

1. **Les commandes échouent**:
   - Vérifiez la syntaxe de la commande
   - Assurez-vous que la commande est autorisée dans la configuration
   - Vérifiez que le shell spécifié est disponible

2. **Les séparateurs de commande ne fonctionnent pas**:
   - Vérifiez que le séparateur est autorisé dans la configuration
   - Utilisez le bon séparateur pour le shell utilisé

3. **Problèmes avec les chemins Windows**:
   - Utilisez des doubles barres obliques inverses (`\\`) ou des barres obliques simples (`/`)
   - Entourez les chemins contenant des espaces de guillemets

Pour une résolution plus détaillée des problèmes, consultez le fichier [TROUBLESHOOTING.md](./TROUBLESHOOTING.md).
<!-- END_SECTION: troubleshooting -->

<!-- START_SECTION: integration_with_roo -->
## Intégration avec Roo

Le MCP Win-CLI s'intègre parfaitement avec Roo, permettant des interactions naturelles en langage courant. Voici quelques exemples de demandes que vous pouvez faire à Roo:

- "Exécute la commande 'Get-Process' en PowerShell"
- "Liste les fichiers du répertoire C:\Users\Public"
- "Crée une connexion SSH vers mon serveur web"
- "Vérifie l'état du service nginx sur mon serveur web via SSH"
- "Montre-moi l'historique des commandes récentes"

Roo traduira automatiquement ces demandes en appels aux outils appropriés du MCP Win-CLI.
<!-- END_SECTION: integration_with_roo -->