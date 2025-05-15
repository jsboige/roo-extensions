# Guide d'installation du serveur MCP Win-CLI

Ce guide détaille les étapes pour installer le serveur MCP Win-CLI qui permet à Roo d'exécuter des commandes dans différents shells Windows et de gérer des connexions SSH.

## Prérequis

- Node.js (version 16 ou supérieure)
- npm (généralement installé avec Node.js)
- Windows 10 ou 11
- PowerShell (préinstallé sur Windows)
- Git Bash (optionnel, nécessaire pour utiliser ce shell)

## Installation

### Méthode 1 : Installation via NPX (recommandée)

La méthode la plus simple pour installer et exécuter le serveur MCP Win-CLI est d'utiliser npx, qui permet d'exécuter des packages npm sans les installer globalement.

```bash
# Installation et exécution en une seule commande
npx -y @simonb97/server-win-cli
```

Cette commande téléchargera et exécutera automatiquement le serveur MCP Win-CLI. Vous pouvez l'utiliser directement dans votre terminal à chaque fois que vous souhaitez démarrer le serveur.

### Méthode 2 : Installation globale via NPM

Si vous préférez installer le package globalement pour pouvoir l'exécuter facilement à tout moment :

```bash
# Installation globale
npm install -g @simonb97/server-win-cli

# Exécution après installation
win-cli-server
```

### Méthode 3 : Installation locale dans un projet

Si vous souhaitez intégrer le serveur MCP Win-CLI dans un projet spécifique :

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

## Vérification de l'installation

Pour vérifier que le serveur MCP Win-CLI est correctement installé et fonctionne :

1. Exécutez le serveur avec la commande appropriée selon votre méthode d'installation
2. Vous devriez voir un message indiquant que le serveur est démarré et en attente de connexions
3. Dans Roo, le serveur devrait apparaître dans la liste des serveurs MCP disponibles

## Configuration dans Roo

Une fois le serveur MCP Win-CLI installé, vous devez le configurer dans Roo :

1. Ouvrez Roo dans VS Code
2. Accédez aux paramètres de Roo (via l'icône de menu ⋮)
3. Allez dans la section "MCP Servers"
4. Ajoutez un nouveau serveur avec les informations suivantes :
   - Nom : `win-cli`
   - Type : `stdio`
   - Commande : `cmd /c npx -y @simonb97/server-win-cli`
   - Activé : `true`
   - Démarrage automatique : `true` (optionnel)
5. Sauvegardez les paramètres
6. Redémarrez VS Code pour appliquer les changements

## Utilisation du script batch run-win-cli.bat

Pour simplifier le démarrage du serveur MCP Win-CLI, un script batch `run-win-cli.bat` est fourni dans le répertoire `mcps/external-mcps/win-cli/`. Ce script permet de démarrer le serveur en un seul clic sans avoir à taper la commande complète.

### Contenu du script

Le script `run-win-cli.bat` contient les commandes suivantes :

```batch
@echo off
echo Démarrage du serveur MCP Win-CLI...
npx -y @simonb97/server-win-cli
```

### Utilisation du script

Pour utiliser le script :

1. Naviguez jusqu'au répertoire `mcps/external-mcps/win-cli/` dans l'explorateur de fichiers
2. Double-cliquez sur le fichier `run-win-cli.bat`
3. Une fenêtre de terminal s'ouvrira et le serveur MCP Win-CLI démarrera automatiquement

### Création d'un raccourci (optionnel)

Vous pouvez également créer un raccourci vers ce script sur votre bureau ou dans votre barre des tâches pour un accès encore plus rapide :

1. Faites un clic droit sur le fichier `run-win-cli.bat`
2. Sélectionnez "Créer un raccourci"
3. Déplacez le raccourci créé vers l'emplacement de votre choix

## Installation des shells supplémentaires

### Git Bash

Si vous souhaitez utiliser Git Bash avec Win-CLI, vous devez l'installer :

1. Téléchargez Git pour Windows depuis [le site officiel](https://git-scm.com/download/win)
2. Exécutez l'installateur et suivez les instructions
3. Assurez-vous de sélectionner l'option pour installer Git Bash
4. Après l'installation, vérifiez que Git Bash est disponible en l'ouvrant depuis le menu Démarrer

## Résolution des problèmes

### Le serveur ne démarre pas

- Vérifiez que Node.js est correctement installé : `node --version`
- Vérifiez que npm est correctement installé : `npm --version`
- Essayez d'installer le package globalement : `npm install -g @simonb97/server-win-cli`
- Vérifiez les journaux d'erreur dans la console

### Le serveur démarre mais n'est pas détecté par Roo

- Vérifiez que la commande dans la configuration de Roo est correcte
- Assurez-vous que le serveur est démarré avant d'ouvrir Roo
- Vérifiez les journaux de Roo pour voir s'il y a des erreurs de connexion

### Problèmes avec les shells

- Pour PowerShell : vérifiez que l'exécution de scripts est autorisée (`Get-ExecutionPolicy`)
- Pour CMD : vérifiez que cmd.exe est accessible dans le PATH
- Pour Git Bash : vérifiez que Git est correctement installé et que Git Bash est accessible

## Mise à jour

Pour mettre à jour le serveur MCP Win-CLI vers la dernière version :

```bash
# Si installé globalement
npm update -g @simonb97/server-win-cli

# Si utilisé via npx
# Aucune action nécessaire, npx utilisera toujours la dernière version

# Si installé localement dans un projet
npm update @simonb97/server-win-cli
```

## Vérification et test de l'installation

Après avoir installé et configuré le serveur MCP Win-CLI, il est important de vérifier que tout fonctionne correctement.

### Vérification de l'installation

1. Démarrez le serveur MCP Win-CLI en utilisant l'une des méthodes suivantes :
   - Via le script batch : double-cliquez sur `run-win-cli.bat`
   - Via npx : exécutez `npx -y @simonb97/server-win-cli` dans un terminal
   - Via la commande globale (si installé globalement) : exécutez `win-cli-server` dans un terminal

2. Vérifiez que le serveur démarre correctement et affiche un message de confirmation similaire à :
   ```
   MCP Server Win-CLI démarré et en attente de connexions...
   ```

### Test des fonctionnalités

Pour tester que le serveur fonctionne correctement avec Roo :

1. Assurez-vous que le serveur MCP Win-CLI est en cours d'exécution
2. Ouvrez VS Code avec l'extension Roo
3. Dans Roo, essayez d'utiliser l'outil `execute_command` avec une commande simple comme :
   ```
   {
     "shell": "powershell",
     "command": "Get-Date"
   }
   ```
4. Vérifiez que la commande s'exécute correctement et que le résultat est affiché dans Roo

### Redémarrage de VS Code

Après avoir configuré le serveur MCP Win-CLI dans les paramètres de Roo, il est nécessaire de redémarrer VS Code pour que les changements soient pris en compte :

1. Fermez complètement VS Code
2. Redémarrez VS Code
3. Vérifiez que le serveur MCP Win-CLI est connecté en consultant les journaux de Roo ou en essayant d'utiliser l'un des outils fournis par le serveur

## Désinstallation

Pour désinstaller le serveur MCP Win-CLI :

```bash
# Si installé globalement
npm uninstall -g @simonb97/server-win-cli

# Si installé localement dans un projet
npm uninstall @simonb97/server-win-cli