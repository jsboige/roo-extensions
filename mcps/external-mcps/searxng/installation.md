# Guide d'installation du serveur MCP SearXNG

Ce guide détaille les étapes pour installer le serveur MCP SearXNG qui permet à Roo d'effectuer des recherches web.

## Prérequis

- Node.js (version 16 ou supérieure)
- npm (généralement installé avec Node.js)
- Une connexion Internet

## Installation

### Méthode 1 : Installation via NPX (recommandée)

La méthode la plus simple pour installer le serveur MCP SearXNG est d'utiliser npx, qui permet d'exécuter des packages npm sans les installer globalement.

```bash
# Installation et exécution en une seule commande
npx mcp-searxng
```

Cette commande téléchargera et exécutera automatiquement le serveur MCP SearXNG. Vous pouvez l'utiliser directement dans votre terminal à chaque fois que vous souhaitez démarrer le serveur.

### Méthode 2 : Installation globale via NPM

Si vous préférez installer le package globalement pour pouvoir l'exécuter facilement à tout moment :

```bash
# Installation globale
npm install -g mcp-searxng

# Exécution après installation
mcp-searxng
```

### Méthode 3 : Installation locale dans un projet

Si vous souhaitez intégrer le serveur MCP SearXNG dans un projet spécifique :

```bash
# Création d'un dossier pour le projet (si nécessaire)
mkdir mcp-searxng-project
cd mcp-searxng-project

# Initialisation du projet (si nécessaire)
npm init -y

# Installation locale
npm install mcp-searxng

# Exécution via npx
npx mcp-searxng
```

## Vérification de l'installation

Pour vérifier que le serveur MCP SearXNG est correctement installé et fonctionne :

1. Exécutez le serveur avec la commande appropriée selon votre méthode d'installation
2. Vous devriez voir un message indiquant que le serveur est démarré et en attente de connexions
3. Dans Roo, le serveur devrait apparaître dans la liste des serveurs MCP disponibles

## Configuration dans Roo

Une fois le serveur MCP SearXNG installé, vous devez le configurer dans Roo :

1. Ouvrez Roo dans VS Code
2. Accédez aux paramètres de Roo (via l'icône de menu ⋮)
3. Allez dans la section "MCP Servers"
4. Ajoutez un nouveau serveur avec les informations suivantes :
   - Nom : `searxng`
   - Type : `stdio`
   - Commande : `cmd` (Windows) ou `/bin/bash` (macOS/Linux)
   - Arguments : `/c node "C:\Users\<username>\AppData\Roaming\npm\node_modules\mcp-searxng\dist\index.js"` (Windows) ou `-c "node $(npm root -g)/mcp-searxng/dist/index.js"` (macOS/Linux)
   - Note : Remplacez `<username>` par votre nom d'utilisateur Windows. N'utilisez PAS la variable `%APPDATA%` car elle n'est pas interprétée correctement dans ce contexte.
   - Activé : `true`
   - Démarrage automatique : `true` (optionnel)
5. Sauvegardez les paramètres
6. Redémarrez VS Code pour appliquer les changements

### Utilisation du script batch (alternative pour Windows)

Si vous préférez utiliser un script batch pour lancer le serveur, vous pouvez :

1. Créer un fichier `run-searxng.bat` avec le contenu suivant :
   ```batch
   @echo off
   echo Démarrage du serveur MCP SearXNG...
   node "C:\Users\<username>\AppData\Roaming\npm\node_modules\mcp-searxng\dist\index.js"
   REM Remplacez <username> par votre nom d'utilisateur Windows
   ```

2. Configurer le serveur MCP dans Roo avec :
   - Commande : `cmd`
   - Arguments : `/c chemin\vers\run-searxng.bat`

## Résolution des problèmes

### Le serveur ne démarre pas

- Vérifiez que Node.js est correctement installé : `node --version`
- Vérifiez que npm est correctement installé : `npm --version`
- Essayez d'installer le package globalement : `npm install -g mcp-searxng`
- Vérifiez les journaux d'erreur dans la console
- **Problème connu** : Les scripts de lancement (`mcp-searxng`, `mcp-searxng.cmd`, `mcp-searxng.ps1`) peuvent être corrompus ou vides. Dans ce cas, utilisez la méthode d'exécution directe avec Node.js comme décrit dans la section "Configuration dans Roo".

### Le serveur démarre mais n'est pas détecté par Roo

- Vérifiez que la commande dans la configuration de Roo est correcte
- Assurez-vous que le serveur est démarré avant d'ouvrir Roo
- Vérifiez les journaux de Roo pour voir s'il y a des erreurs de connexion

### Les recherches échouent

- Vérifiez votre connexion Internet
- Assurez-vous que le serveur SearXNG est accessible (il peut être bloqué par un pare-feu)
- Essayez de redémarrer le serveur MCP SearXNG

## Mise à jour

Pour mettre à jour le serveur MCP SearXNG vers la dernière version :

```bash
# Si installé globalement
npm update -g mcp-searxng

# Si utilisé via npx
# Aucune action nécessaire, npx utilisera toujours la dernière version

# Si installé localement dans un projet
npm update mcp-searxng
```

## Désinstallation

Pour désinstaller le serveur MCP SearXNG :

```bash
# Si installé globalement
npm uninstall -g mcp-searxng

# Si installé localement dans un projet
npm uninstall mcp-searxng