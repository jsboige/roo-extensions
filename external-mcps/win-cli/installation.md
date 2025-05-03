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

## Désinstallation

Pour désinstaller le serveur MCP Win-CLI :

```bash
# Si installé globalement
npm uninstall -g @simonb97/server-win-cli

# Si installé localement dans un projet
npm uninstall @simonb97/server-win-cli