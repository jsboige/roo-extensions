# Installation du MCP SearXNG

<!-- START_SECTION: introduction -->
## Introduction

Ce guide détaille les étapes pour installer le serveur MCP SearXNG qui permet à Roo d'effectuer des recherches web et d'accéder au contenu des pages tout en respectant la vie privée des utilisateurs.
<!-- END_SECTION: introduction -->

<!-- START_SECTION: prerequisites -->
## Prérequis

Avant d'installer le MCP SearXNG, assurez-vous que les éléments suivants sont installés et configurés sur votre système:

- **Node.js**: Version 16.0.0 ou supérieure - [Installation officielle de Node.js](https://nodejs.org/)
- **npm**: Version 6.0.0 ou supérieure (généralement installé avec Node.js)
- **Roo**: Version compatible avec les MCPs externes
- **Une connexion Internet**: Nécessaire pour accéder aux instances SearXNG
<!-- END_SECTION: prerequisites -->

<!-- START_SECTION: installation_methods -->
## Méthodes d'installation

Il existe plusieurs méthodes pour installer le MCP SearXNG:

1. [Installation via NPX (recommandée)](#installation-via-npx)
2. [Installation globale via NPM](#installation-globale)
3. [Installation locale dans un projet](#installation-locale)
<!-- END_SECTION: installation_methods -->

<!-- START_SECTION: npx_installation -->
## Installation via NPX

La méthode la plus simple pour installer et exécuter le serveur MCP SearXNG est d'utiliser npx, qui permet d'exécuter des packages npm sans les installer globalement:

```bash
# Installation et exécution en une seule commande
npx mcp-searxng
```

Cette commande téléchargera et exécutera automatiquement le serveur MCP SearXNG. Vous pouvez l'utiliser directement dans votre terminal à chaque fois que vous souhaitez démarrer le serveur.

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
npm install -g mcp-searxng

# Exécution après installation
mcp-searxng
```

Avantages de cette méthode:
- Commande plus courte pour démarrer le serveur
- Disponible dans tous les répertoires
- Pas besoin de télécharger le package à chaque exécution

> **Note**: Sur Linux/macOS, vous devrez peut-être utiliser `sudo` pour l'installation globale:
> ```bash
> sudo npm install -g mcp-searxng
> ```
<!-- END_SECTION: global_installation -->

<!-- START_SECTION: local_installation -->
## Installation locale

Si vous souhaitez intégrer le serveur MCP SearXNG dans un projet spécifique:

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

Avantages de cette méthode:
- Isolation du package dans un projet spécifique
- Contrôle précis de la version utilisée
- Partage facile du projet avec d'autres développeurs
<!-- END_SECTION: local_installation -->

<!-- START_SECTION: verification -->
## Vérification de l'installation

Pour vérifier que le serveur MCP SearXNG est correctement installé et fonctionne:

1. Exécutez le serveur avec la commande appropriée selon votre méthode d'installation
2. Vous devriez voir un message similaire à:
   ```
   MCP SearXNG server started and listening on port XXXX
   ```
3. Dans Roo, le serveur devrait apparaître dans la liste des serveurs MCP disponibles

Pour tester manuellement le serveur:
```bash
# Vérifier la version
mcp-searxng --version

# Démarrer avec le mode débogage pour plus d'informations
mcp-searxng --debug
```
<!-- END_SECTION: verification -->

<!-- START_SECTION: roo_configuration -->
## Configuration dans Roo

Une fois le serveur MCP SearXNG installé, vous devez le configurer dans Roo:

### Configuration automatique (recommandée)

Si vous utilisez une version récente de Roo, le serveur MCP SearXNG peut être détecté automatiquement. Vérifiez dans les paramètres de Roo si le serveur apparaît dans la liste des serveurs MCP disponibles.

### Configuration manuelle

1. Ouvrez Roo dans VS Code
2. Accédez aux paramètres de Roo (via l'icône de menu ⋮)
3. Allez dans la section "MCP Servers"
4. Ajoutez un nouveau serveur avec les informations suivantes:

#### Pour l'installation globale:

- **Windows**:
  ```json
  {
    "name": "searxng",
    "type": "stdio",
    "command": "cmd",
    "args": ["/c", "mcp-searxng"],
    "enabled": true,
    "autoStart": true,
    "description": "Serveur MCP SearXNG pour les recherches web"
  }
  ```

- **macOS/Linux**:
  ```json
  {
    "name": "searxng",
    "type": "stdio",
    "command": "mcp-searxng",
    "enabled": true,
    "autoStart": true,
    "description": "Serveur MCP SearXNG pour les recherches web"
  }
  ```

#### Pour l'exécution directe avec Node.js:

- **Windows**:
  ```json
  {
    "name": "searxng",
    "type": "stdio",
    "command": "cmd",
    "args": ["/c", "node", "C:\\Users\\<username>\\AppData\\Roaming\\npm\\node_modules\\mcp-searxng\\dist\\index.js"],
    "enabled": true,
    "autoStart": true,
    "description": "Serveur MCP SearXNG pour les recherches web"
  }
  ```
  > **Note**: Remplacez `<username>` par votre nom d'utilisateur Windows. N'utilisez PAS la variable `%APPDATA%` car elle n'est pas interprétée correctement dans ce contexte.

- **macOS/Linux**:
  ```json
  {
    "name": "searxng",
    "type": "stdio",
    "command": "/bin/bash",
    "args": ["-c", "node $(npm root -g)/mcp-searxng/dist/index.js"],
    "enabled": true,
    "autoStart": true,
    "description": "Serveur MCP SearXNG pour les recherches web"
  }
  ```

5. Sauvegardez les paramètres
6. Redémarrez VS Code pour appliquer les changements
<!-- END_SECTION: roo_configuration -->

<!-- START_SECTION: batch_script -->
## Utilisation d'un script batch (Windows)

Si vous préférez utiliser un script batch pour lancer le serveur sur Windows:

1. Créez un fichier `run-searxng.bat` avec le contenu suivant:
   ```batch
   @echo off
   echo Démarrage du serveur MCP SearXNG...
   node "C:\Users\<username>\AppData\Roaming\npm\node_modules\mcp-searxng\dist\index.js"
   REM Remplacez <username> par votre nom d'utilisateur Windows
   ```

2. Configurez le serveur MCP dans Roo avec:
   ```json
   {
     "name": "searxng",
     "type": "stdio",
     "command": "cmd",
     "args": ["/c", "chemin\\vers\\run-searxng.bat"],
     "enabled": true,
     "autoStart": true,
     "description": "Serveur MCP SearXNG pour les recherches web"
   }
   ```

Ce script est particulièrement utile si vous rencontrez des problèmes avec les scripts de lancement générés par npm.
<!-- END_SECTION: batch_script -->

<!-- START_SECTION: update -->
## Mise à jour

Pour mettre à jour le serveur MCP SearXNG vers la dernière version:

```bash
# Si installé globalement
npm update -g mcp-searxng

# Si utilisé via npx
# Aucune action nécessaire, npx utilisera toujours la dernière version

# Si installé localement dans un projet
npm update mcp-searxng
```

Il est recommandé de vérifier régulièrement les mises à jour pour bénéficier des dernières fonctionnalités et corrections de bugs.
<!-- END_SECTION: update -->

<!-- START_SECTION: uninstallation -->
## Désinstallation

Pour désinstaller le serveur MCP SearXNG:

```bash
# Si installé globalement
npm uninstall -g mcp-searxng

# Si installé localement dans un projet
npm uninstall mcp-searxng
```

N'oubliez pas de supprimer également la configuration du serveur dans les paramètres de Roo.
<!-- END_SECTION: uninstallation -->

<!-- START_SECTION: troubleshooting -->
## Résolution des problèmes d'installation

### Le serveur ne démarre pas

- Vérifiez que Node.js est correctement installé: `node --version`
- Vérifiez que npm est correctement installé: `npm --version`
- Essayez d'installer le package globalement: `npm install -g mcp-searxng`
- Vérifiez les journaux d'erreur dans la console

### Problème connu: Scripts de lancement corrompus

Les scripts de lancement (`mcp-searxng`, `mcp-searxng.cmd`, `mcp-searxng.ps1`) peuvent parfois être corrompus ou vides. Dans ce cas, utilisez la méthode d'exécution directe avec Node.js comme décrit dans la section "Configuration dans Roo".

### Le serveur démarre mais n'est pas détecté par Roo

- Vérifiez que la commande dans la configuration de Roo est correcte
- Assurez-vous que le serveur est démarré avant d'ouvrir Roo
- Vérifiez les journaux de Roo pour voir s'il y a des erreurs de connexion

Pour une résolution plus détaillée des problèmes, consultez le fichier [TROUBLESHOOTING.md](./TROUBLESHOOTING.md).
<!-- END_SECTION: troubleshooting -->

<!-- START_SECTION: next_steps -->
## Prochaines étapes

Maintenant que vous avez installé le MCP SearXNG, vous pouvez:

1. [Configurer le MCP SearXNG](./CONFIGURATION.md)
2. [Apprendre à utiliser le MCP SearXNG](./USAGE.md)
3. [Explorer les cas d'utilisation avancés](./USAGE.md#cas-dutilisation)
<!-- END_SECTION: next_steps -->