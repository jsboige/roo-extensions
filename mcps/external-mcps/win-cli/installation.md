# Installation du MCP Win-CLI

<!-- START_SECTION: introduction -->
## Introduction

Ce guide détaille les étapes pour installer le serveur MCP Win-CLI qui permet à Roo d'exécuter des commandes dans différents shells Windows (PowerShell, CMD, Git Bash) et de gérer des connexions SSH. Le MCP Win-CLI est un outil puissant qui étend les capacités de Roo en lui permettant d'interagir directement avec votre système d'exploitation.
<!-- END_SECTION: introduction -->

<!-- START_SECTION: prerequisites -->
## Prérequis

Avant d'installer le MCP Win-CLI, assurez-vous que les éléments suivants sont installés et configurés sur votre système:

- **Node.js**: Version 16.0.0 ou supérieure - [Installation officielle de Node.js](https://nodejs.org/)
- **npm**: Version 6.0.0 ou supérieure (généralement installé avec Node.js)
- **Windows 10 ou 11**: Le MCP Win-CLI est conçu pour fonctionner sur les versions récentes de Windows
- **PowerShell**: Préinstallé sur Windows 10 et 11
- **Git Bash** (optionnel): Nécessaire uniquement si vous souhaitez utiliser ce shell - [Installation de Git pour Windows](https://git-scm.com/download/win)
- **Roo**: Version compatible avec les MCPs externes
<!-- END_SECTION: prerequisites -->

<!-- START_SECTION: installation_methods -->
## Méthodes d'installation

Il existe plusieurs méthodes pour installer le MCP Win-CLI:

1. [Installation via NPX (recommandée)](#installation-via-npx)
2. [Installation globale via NPM](#installation-globale)
3. [Installation locale dans un projet](#installation-locale)
<!-- END_SECTION: installation_methods -->

<!-- START_SECTION: npx_installation -->
## Installation via NPX

La méthode la plus simple pour installer et exécuter le serveur MCP Win-CLI est d'utiliser npx, qui permet d'exécuter des packages npm sans les installer globalement:

```bash
# Installation et exécution en une seule commande
npx -y @simonb97/server-win-cli
```

Cette commande téléchargera et exécutera automatiquement le serveur MCP Win-CLI. Vous pouvez l'utiliser directement dans votre terminal à chaque fois que vous souhaitez démarrer le serveur.

Avantages de cette méthode:
- Pas d'installation permanente nécessaire
- Utilise toujours la dernière version disponible
- Pas de problèmes de permissions
<!-- END_SECTION: npx_installation -->

<!-- START_SECTION: global_installation -->
## Installation globale

Si vous préférez installer le package globalement pour pouvoir l'exécuter facilement à tout moment:

```bash
# Installation globale
npm install -g @simonb97/server-win-cli

# Exécution après installation
win-cli-server
```

Avantages de cette méthode:
- Commande plus courte pour démarrer le serveur
- Disponible dans tous les répertoires
- Pas besoin de télécharger le package à chaque exécution

> **Note**: Sur Windows, vous devrez peut-être exécuter PowerShell ou CMD en tant qu'administrateur pour installer des packages npm globalement.
<!-- END_SECTION: global_installation -->

<!-- START_SECTION: local_installation -->
## Installation locale

Si vous souhaitez intégrer le serveur MCP Win-CLI dans un projet spécifique:

```bash
# Création d'un dossier pour le projet (si nécessaire)
mkdir win-cli-project
cd win-cli-project

# Initialisation du projet (si nécessaire)
npm init -y

# Installation locale
npm install @simonb97/server-win-cli

# Exécution via npx
npx server-win-cli
```

Avantages de cette méthode:
- Isolation du package dans un projet spécifique
- Contrôle précis de la version utilisée
- Partage facile du projet avec d'autres développeurs
<!-- END_SECTION: local_installation -->

<!-- START_SECTION: verification -->
## Vérification de l'installation

Pour vérifier que le serveur MCP Win-CLI est correctement installé et fonctionne:

1. Exécutez le serveur avec la commande appropriée selon votre méthode d'installation
2. Vous devriez voir un message similaire à:
   ```
   MCP Server Win-CLI démarré et en attente de connexions...
   ```
3. Dans Roo, le serveur devrait apparaître dans la liste des serveurs MCP disponibles

Pour tester manuellement le serveur:
```bash
# Vérifier la version
win-cli-server --version

# Démarrer avec le mode débogage pour plus d'informations
win-cli-server --debug
```
<!-- END_SECTION: verification -->

<!-- START_SECTION: roo_configuration -->
## Configuration dans Roo

Une fois le serveur MCP Win-CLI installé, vous devez le configurer dans Roo:

1. Ouvrez Roo dans VS Code
2. Accédez aux paramètres de Roo (via l'icône de menu ⋮)
3. Allez dans la section "MCP Servers"
4. Ajoutez un nouveau serveur avec les informations suivantes:
   - Nom: `win-cli`
   - Type: `stdio`
   - Commande: `cmd /c npx -y @simonb97/server-win-cli`
   - Activé: `true`
   - Démarrage automatique: `true` (optionnel)
5. Sauvegardez les paramètres
6. Redémarrez VS Code pour appliquer les changements

### Configuration complète

Pour simplifier le démarrage du serveur MCP Win-CLI, un script batch `run-win-cli.bat` est fourni dans le répertoire `mcps/external-mcps/win-cli/`. Ce script permet de démarrer le serveur en un seul clic sans avoir à taper la commande complète.

Voici un exemple de configuration complète pour le fichier `mcp_settings.json`:

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

> **Note**: Le fichier `mcp_settings.json` se trouve généralement à l'emplacement suivant:
> - Windows: `%USERPROFILE%\AppData\Roaming\Code\User\globalStorage\rooveterinaryinc.roo-cline\settings\mcp_settings.json`
<!-- END_SECTION: roo_configuration -->

<!-- START_SECTION: batch_script -->
## Utilisation d'un script batch

Pour simplifier le démarrage du serveur MCP Win-CLI, vous pouvez utiliser un script batch:

### Création du script batch

Créez un fichier `run-win-cli.bat` avec le contenu suivant:

```batch
@echo off
echo Démarrage du serveur MCP Win-CLI...
npx -y @simonb97/server-win-cli
```

### Utilisation du script

Pour utiliser le script:

1. Naviguez jusqu'au répertoire `mcps/external-mcps/win-cli/` dans l'explorateur de fichiers
2. Double-cliquez sur le fichier `run-win-cli.bat`
3. Une fenêtre de terminal s'ouvrira et le serveur MCP Win-CLI démarrera automatiquement

### Configuration de Roo avec le script batch

Vous pouvez également configurer Roo pour utiliser le script batch:

```json
{
  "mcpServers": {
    "win-cli": {
      "command": "cmd",
      "args": [
        "/c",
        "chemin\\vers\\run-win-cli.bat"
      ],
      "transportType": "stdio",
      "disabled": false
    }
  }
}
```

Remplacez `chemin\\vers\\` par le chemin absolu vers le répertoire contenant le script.

### Création d'un raccourci (optionnel)

Vous pouvez également créer un raccourci vers ce script sur votre bureau ou dans votre barre des tâches pour un accès encore plus rapide:

1. Faites un clic droit sur le fichier `run-win-cli.bat`
2. Sélectionnez "Créer un raccourci"
3. Déplacez le raccourci créé vers l'emplacement de votre choix
<!-- END_SECTION: batch_script -->

<!-- START_SECTION: additional_shells -->
## Installation des shells supplémentaires

### Git Bash

Si vous souhaitez utiliser Git Bash avec Win-CLI:

1. Téléchargez Git pour Windows depuis [le site officiel](https://git-scm.com/download/win)
2. Exécutez l'installateur et suivez les instructions
3. Assurez-vous de sélectionner l'option pour installer Git Bash
4. Après l'installation, vérifiez que Git Bash est disponible en l'ouvrant depuis le menu Démarrer

### Configuration des shells dans le fichier de configuration

Après avoir installé les shells supplémentaires, vous devrez peut-être ajuster leur chemin dans le fichier de configuration du MCP Win-CLI:

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

Si Git est installé dans un emplacement différent, ajustez le chemin en conséquence.
<!-- END_SECTION: additional_shells -->

<!-- START_SECTION: testing -->
## Vérification et test de l'installation

Après avoir installé et configuré le serveur MCP Win-CLI, il est important de vérifier que tout fonctionne correctement.

### Test des fonctionnalités

Pour tester que le serveur fonctionne correctement avec Roo:

1. Assurez-vous que le serveur MCP Win-CLI est en cours d'exécution
2. Ouvrez VS Code avec l'extension Roo
3. Dans Roo, essayez d'utiliser l'outil `execute_command` avec une commande simple comme:
   ```
   {
     "shell": "powershell",
     "command": "Get-Date"
   }
   ```
4. Vérifiez que la commande s'exécute correctement et que le résultat est affiché dans Roo

### Test des différents shells

Testez chacun des shells disponibles pour vous assurer qu'ils fonctionnent correctement:

1. **PowerShell**:
   ```
   {
     "shell": "powershell",
     "command": "Get-Process | Select-Object -First 5"
   }
   ```

2. **CMD**:
   ```
   {
     "shell": "cmd",
     "command": "dir /b"
   }
   ```

3. **Git Bash** (si installé):
   ```
   {
     "shell": "gitbash",
     "command": "ls -la"
   }
   ```
<!-- END_SECTION: testing -->

<!-- START_SECTION: update -->
## Mise à jour

Pour mettre à jour le serveur MCP Win-CLI vers la dernière version:

```bash
# Si installé globalement
npm update -g @simonb97/server-win-cli

# Si utilisé via npx
# Aucune action nécessaire, npx utilisera toujours la dernière version

# Si installé localement dans un projet
npm update @simonb97/server-win-cli
```

Il est recommandé de vérifier régulièrement les mises à jour pour bénéficier des dernières fonctionnalités et corrections de bugs.
<!-- END_SECTION: update -->

<!-- START_SECTION: uninstallation -->
## Désinstallation

Pour désinstaller le serveur MCP Win-CLI:

```bash
# Si installé globalement
npm uninstall -g @simonb97/server-win-cli

# Si installé localement dans un projet
npm uninstall @simonb97/server-win-cli
```

N'oubliez pas de supprimer également la configuration du serveur dans les paramètres de Roo.
<!-- END_SECTION: uninstallation -->

<!-- START_SECTION: troubleshooting -->
## Résolution des problèmes d'installation

### Le serveur ne démarre pas

- Vérifiez que Node.js est correctement installé: `node --version`
- Vérifiez que npm est correctement installé: `npm --version`
- Essayez d'installer le package globalement: `npm install -g @simonb97/server-win-cli`
- Vérifiez les journaux d'erreur dans la console

### Le serveur démarre mais n'est pas détecté par Roo

- Vérifiez que la commande dans la configuration de Roo est correcte
- Assurez-vous que le serveur est démarré avant d'ouvrir Roo
- Vérifiez les journaux de Roo pour voir s'il y a des erreurs de connexion

### Problèmes avec les shells

- Pour PowerShell: vérifiez que l'exécution de scripts est autorisée (`Get-ExecutionPolicy`)
- Pour CMD: vérifiez que cmd.exe est accessible dans le PATH
- Pour Git Bash: vérifiez que Git est correctement installé et que Git Bash est accessible

Pour une résolution plus détaillée des problèmes, consultez le fichier [TROUBLESHOOTING.md](./TROUBLESHOOTING.md).
<!-- END_SECTION: troubleshooting -->

<!-- START_SECTION: next_steps -->
## Prochaines étapes

Maintenant que vous avez installé le MCP Win-CLI, vous pouvez:

1. [Configurer le MCP Win-CLI](./CONFIGURATION.md)
2. [Apprendre à utiliser le MCP Win-CLI](./USAGE.md)
3. [Explorer les considérations de sécurité](./SECURITY.md)
<!-- END_SECTION: next_steps -->