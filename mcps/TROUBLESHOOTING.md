<!-- START_SECTION: metadata -->
---
title: "Guide de dépannage global pour les serveurs MCP"
description: "Solutions aux problèmes courants rencontrés avec les serveurs MCP"
tags: #troubleshooting #mcp #guide #installation #configuration #performance #security
date_created: "2025-05-14"
date_updated: "2025-05-14"
version: "1.0.0"
author: "Équipe MCP"
---
<!-- END_SECTION: metadata -->

# Guide de dépannage global pour les serveurs MCP

<!-- START_SECTION: introduction -->
## Introduction

Ce guide de dépannage global est conçu pour vous aider à résoudre les problèmes courants rencontrés lors de l'installation, la configuration et l'utilisation des serveurs MCP (Model Context Protocol). Il couvre les problèmes génériques qui peuvent affecter tous les types de serveurs MCP, ainsi que des références vers les guides de dépannage spécifiques à chaque serveur.

Le Model Context Protocol (MCP) permet la communication entre les modèles d'IA et des serveurs externes qui fournissent des outils et des ressources supplémentaires. Ce guide vous aidera à diagnostiquer et résoudre les problèmes qui peuvent survenir dans cette communication.

### Comment utiliser ce guide

1. Identifiez la catégorie de votre problème (installation, configuration, utilisation, etc.)
2. Parcourez la section correspondante pour trouver des symptômes similaires aux vôtres
3. Suivez les solutions proposées étape par étape
4. Si le problème persiste, consultez le guide de dépannage spécifique au serveur MCP concerné

### Sommaire

- [Introduction](#introduction)
- [Problèmes d'installation](#problèmes-dinstallation)
- [Problèmes de configuration](#problèmes-de-configuration)
- [Problèmes d'utilisation](#problèmes-dutilisation)
- [Problèmes d'intégration avec Roo](#problèmes-dintégration-avec-roo)
- [Problèmes de Données](#problèmes-de-données)
- [Problèmes de performance](#problèmes-de-performance)
- [Problèmes de sécurité](#problèmes-de-sécurité)
- [Commandes de diagnostic](#commandes-de-diagnostic)
- [Guides de dépannage spécifiques](#guides-de-dépannage-spécifiques)
<!-- END_SECTION: introduction -->

<!-- START_SECTION: installation_issues -->
## Problèmes d'installation

### Erreur "Module not found"

**Symptôme** : Lors du démarrage du serveur, vous obtenez une erreur indiquant qu'un module n'a pas été trouvé.

```
Error: Cannot find module '@modelcontextprotocol/sdk'
```

**Causes possibles** :
- Les dépendances n'ont pas été installées correctement
- Le projet n'a pas été compilé après l'installation
- Le module est manquant dans le fichier package.json

**Solutions** :
1. Réinstallez les dépendances :
   ```bash
   npm ci
   ```

2. Si cela ne résout pas le problème, essayez une installation propre :
   ```bash
   rm -rf node_modules package-lock.json
   npm install
   ```

3. Vérifiez que le module est bien listé dans les dépendances du fichier package.json et ajoutez-le si nécessaire :
   ```bash
   npm install --save @modelcontextprotocol/sdk
   ```

4. Compilez le projet :
   ```bash
### Erreur de compilation TypeScript

**Symptôme** : Erreurs lors de la compilation du projet avec `npm run build`.

```
error TS2307: Cannot find module '@modelcontextprotocol/sdk' or its corresponding type declarations.
```

**Causes possibles** :
- Types TypeScript manquants
- Version incompatible de TypeScript
- Erreurs dans le code source

**Solutions** :
1. Installez les types manquants :
   ```bash
   npm install --save-dev @types/node
   ```

2. Vérifiez la version de TypeScript et mettez-la à jour si nécessaire :
   ```bash
   npm install --save-dev typescript@latest
   ```

3. Vérifiez les erreurs dans le code source et corrigez-les.

4. Si les erreurs persistent, essayez de réinitialiser la configuration TypeScript :
   ```bash
   rm tsconfig.json
   npx tsc --init
   ```
   Puis ajoutez les options nécessaires au nouveau fichier tsconfig.json.

### Erreur "Permission denied"

**Symptôme** : Erreurs de permission lors de l'installation ou de l'exécution.

```
EACCES: permission denied, access '/usr/local/lib/node_modules'
```

**Causes possibles** :
- Permissions insuffisantes pour installer des packages globaux
- Permissions insuffisantes pour accéder aux répertoires du projet

**Solutions** :
1. Pour les installations globales, utilisez sudo (non recommandé) ou configurez npm pour utiliser un répertoire global dans votre dossier personnel :
   ```bash
   mkdir ~/.npm-global
   npm config set prefix '~/.npm-global'
   export PATH=~/.npm-global/bin:$PATH
   ```
   Ajoutez la dernière ligne à votre fichier ~/.profile ou ~/.bashrc.

2. Corrigez les permissions du répertoire du projet :
   ```bash
   sudo chown -R $(whoami) .
   ```

3. Utilisez nvm (Node Version Manager) pour gérer les installations de Node.js sans nécessiter de privilèges root.

### Erreur d'installation de dépendances spécifiques

**Symptôme** : Erreurs lors de l'installation de dépendances spécifiques à certains serveurs MCP.

**Causes possibles** :
- Dépendances système manquantes
- Incompatibilité de versions
- Problèmes de réseau

**Solutions** :
1. Installez les dépendances système requises :
   ```bash
   # Pour les serveurs basés sur Python (comme Jupyter)
   sudo apt-get install python3 python3-pip python3-dev

   # Pour les serveurs qui utilisent des bibliothèques de traitement d'image
   sudo apt-get install libcairo2-dev libjpeg-dev libpango1.0-dev libgif-dev build-essential g++
   ```

2. Vérifiez les versions compatibles dans la documentation du serveur MCP.

3. Si vous rencontrez des problèmes de réseau, essayez d'utiliser un miroir npm différent :
   ```bash
   npm config set registry https://registry.npmjs.org/
   ```

4. Pour les serveurs qui utilisent Python (comme Jupyter), utilisez un environnement virtuel :
   ```bash
   python -m venv mcp-env
   source mcp-env/bin/activate  # Sur Linux/macOS
   mcp-env\Scripts\activate     # Sur Windows
   ```

### Problèmes de chemin Python et alias Windows

**Symptôme** : Un MCP basé sur Python (ex: `markitdown`) ne démarre pas car PowerShell sélectionne un "alias d'exécution d'application" (`python.exe` dans `C:\Users\...\AppData\Local\Microsoft\WindowsApps\`) qui renvoie vers le Microsoft Store au lieu d'un véritable interpréteur.

**Cause Racine** : La commande `Get-Command python` ne distingue pas les vrais exécutables des alias du Microsoft Store.

**Solutions** :
1.  **Détection Fiable (via script)** : Utiliser un script qui teste chaque exécutable `python` trouvé (`Get-Command -All`) avec `--version` pour valider qu'il s'agit d'un interpréteur fonctionnel, en ignorant les chemins contenant `\WindowsApps\`. Le chemin de l'exécutable valide doit être utilisé explicitement dans la configuration du MCP.
2.  **Environnement Virtuel Dédié** : La meilleure pratique est de créer un environnement virtuel (avec `conda` ou `venv`) et d'installer les dépendances du MCP à l'intérieur. La configuration du MCP doit ensuite pointer directement vers l'exécutable Python de cet environnement, par exemple : `C:/Users/user/.conda/envs/mcp-markitdown/python.exe`.

### Instabilité du cache `npx`

**Symptôme** : Le démarrage d'un MCP via `npx` (ex: `playwright`) échoue de manière intermittente, parfois avec une erreur `ERR_MODULE_NOT_FOUND`, surtout après avoir nettoyé le cache `_npx`.

**Cause Racine** : `npx` peut avoir du mal à réinstaller à la volée des paquets s'il est instable.

**Solutions** :
1.  **Stratégie de "préchauffage" (via script)** : Avant de démarrer le MCP, exécutez une commande `npx` inoffensive comme `npx -y @playwright/mcp --version`. Cela force `npx` à télécharger et installer proprement le paquet dans le cache s'il est manquant ou invalide. Le MCP peut alors être démarré de manière fiable.
2.  **Installation Locale** : Pour une robustesse maximale, installez le paquet localement dans le projet (`npm install @playwright/mcp`) et modifiez la configuration du MCP pour qu'elle pointe directement vers le script `cli.js` avec `node`, par exemple : `D:/dev/roo-extensions/node_modules/@playwright/mcp/lib/cli.js`.
<!-- END_SECTION: installation_issues -->

<!-- START_SECTION: configuration_issues -->
## Problèmes de configuration

### Erreur "Configuration file not found"

**Symptôme** : Le serveur ne démarre pas car il ne trouve pas le fichier de configuration.

```
Error: Configuration file not found at /path/to/config.json
```

**Causes possibles** :
- Le fichier de configuration n'existe pas
- Le chemin vers le fichier de configuration est incorrect
- Le serveur n'a pas les permissions pour lire le fichier

**Solutions** :
1. Vérifiez que le fichier de configuration existe :
   ```bash
   ls -la /path/to/config.json
   ```

2. Créez un fichier de configuration par défaut :
   ```bash
   cp config.example.json config.json
   ```

3. Spécifiez explicitement le chemin du fichier de configuration lors du démarrage :
   ```bash
   npm start -- --config /path/to/config.json
   ```

4. Vérifiez les permissions du fichier :
   ```bash
   chmod 644 /path/to/config.json
   ```

### Erreur "Invalid configuration"

**Symptôme** : Le serveur ne démarre pas car la configuration est invalide.

```
Error: Invalid configuration: "port" must be a number
```

**Causes possibles** :
- Format JSON invalide
- Valeurs de configuration incorrectes
- Options de configuration manquantes

**Solutions** :
1. Vérifiez que le fichier de configuration est un JSON valide :
   ```bash
   cat config.json | jq
   ```
   Si jq n'est pas installé, vous pouvez utiliser `python -m json.tool` ou un validateur JSON en ligne.

2. Corrigez les valeurs incorrectes selon les messages d'erreur.

3. Assurez-vous que toutes les options requises sont présentes en consultant la documentation.

4. Utilisez un fichier de configuration minimal pour démarrer, puis ajoutez progressivement d'autres options :
   ```json
   {
     "server": {
       "port": 3000,
       "host": "localhost"
     }
   }
   ```

### Problèmes de ports

**Symptôme** : Le serveur ne peut pas démarrer car le port est déjà utilisé.

```
Error: listen EADDRINUSE: address already in use :::3000
```

**Causes possibles** :
- Une autre instance du serveur est déjà en cours d'exécution
- Une autre application utilise le même port
- Le port nécessite des privilèges élevés (ports < 1024)

**Solutions** :
1. Vérifiez si le port est déjà utilisé :
   ```bash
   # Sur Windows
   netstat -ano | findstr :3000
   
   # Sur Linux/macOS
   lsof -i :3000
   ```

2. Arrêtez l'application qui utilise le port :
   ```bash
   # Sur Windows
   FOR /F "tokens=5" %P IN ('netstat -ano ^| findstr :3000') DO taskkill /F /PID %P
   
   # Sur Linux/macOS
   kill $(lsof -t -i:3000)
   ```

3. Changez le port dans la configuration :
   ```json
   {
     "server": {
       "port": 3001
     }
   }
   ```

4. Pour utiliser un port < 1024 sans privilèges root :
   ```bash
   # Sur Linux
   sudo setcap 'cap_net_bind_service=+ep' $(which node)
   ```

### Problèmes de chemins

**Symptôme** : Le serveur ne peut pas accéder aux fichiers ou répertoires spécifiés dans la configuration.

```
Error: ENOENT: no such file or directory, open '/path/to/file'
```

**Causes possibles** :
- Les chemins sont incorrects
- Les chemins sont relatifs au mauvais répertoire
- Les fichiers ou répertoires n'existent pas
- Problèmes de permissions

**Solutions** :
1. Utilisez des chemins absolus plutôt que relatifs :
   ```json
   {
     "paths": {
       "data": "/home/user/mcp-server/data"
     }
   }
   ```

2. Vérifiez que les répertoires existent et créez-les si nécessaire :
   ```bash
   mkdir -p /path/to/directory
   ```

3. Vérifiez les permissions :
   ```bash
   chmod -R 755 /path/to/directory
   ```

4. Si vous utilisez des chemins relatifs, assurez-vous qu'ils sont relatifs au répertoire de travail du serveur :
   ```bash
   cd /path/to/server
   npm start
   ```

### Incompatibilité des chemins de fichiers entre OS (Windows)

**Symptôme** : Un serveur MCP (par exemple, `searxng`) démarre mais n'expose aucun outil, ou échoue à s'initialiser correctement uniquement sur Windows. Les logs peuvent être peu explicites.

**Cause Racine** :
Le code source du MCP peut contenir une logique de comparaison de chemins qui n'est pas compatible avec Windows. Par exemple, une comparaison entre `import.meta.url` (qui utilise des slashes `/` et un préfixe `file:///`) et `process.argv[1]` (qui utilise des backslashes `\` sous Windows) peut échouer. Cela peut empêcher la fonction principale du serveur de s'exécuter.

**Solutions** :
1.  **Diagnostic** :
   Si un MCP fonctionne sur Linux/macOS mais pas sur Windows, suspectez un problème de chemin. Ajoutez des logs au point d'entrée du serveur pour inspecter et comparer les variables de chemin (`import.meta.url`, `process.argv[1]`, `__filename`, etc.).

2.  **Correction du Code (si possible)** :
   La meilleure solution est de corriger le code du MCP pour normaliser les chemins avant de les comparer. Le module `path` de Node.js et la fonction `pathToFileURL` sont utiles pour cela.
   ```javascript
   import { pathToFileURL } from 'url';

   // Condition de démarrage robuste
   if (import.meta.url === pathToFileURL(process.argv[1]).href) {
     // ... démarrer le serveur
   }
   ```

3.  **Contournement par la Configuration** :
   Parfois, la manière dont le processus est lancé peut contourner le problème. Par exemple, utiliser `npx` peut résoudre les problèmes de chemin que `node` seul ne résout pas.
   Dans `mcp_settings.json`, préférez une commande comme :
   ```json
   "command": "cmd",
   "args": ["/c", "npx", "-y", "mcp-searxng"]
   ```
   plutôt qu'un appel direct à `node` avec le chemin du script.

### Problèmes de configuration de tokens d'API

**Symptôme** : Un MCP qui interagit avec une API (ex: `github-projects-mcp`) échoue avec des erreurs de "rate limit" ou d'authentification, même si un token semble être configuré.

**Cause Racine** : Le serveur MCP reçoit la chaîne de caractères littérale de la variable d'environnement (ex: `"${env:GITHUB_TOKEN}"`) au lieu de sa valeur résolue (ex: `"ghp_..."`). Le client API est donc instancié avec un token invalide et effectue des requêtes non authentifiées, qui sont très rapidement limitées.

**Solutions** :
1.  **Utiliser un fichier `.env`** : La méthode la plus fiable est de définir les tokens dans un fichier `.env` à la racine du serveur MCP. Assurez-vous que le MCP est configuré pour charger ce fichier au démarrage (souvent avec une bibliothèque comme `dotenv`).
2.  **Vérifier la Résolution des Variables** : Si vous devez utiliser des variables d'environnement globales, assurez-vous que l'environnement d'exécution de Roo les résout correctement avant de démarrer le MCP.
3.  **Logique de Résolution dans le MCP** : Idéalement, le MCP lui-même devrait inclure une logique pour détecter si un token est une chaîne de substitution non résolue et tenter de la résoudre lui-même en lisant `process.env`.
<!-- END_SECTION: configuration_issues -->
<!-- START_SECTION: usage_issues -->
## Problèmes d'utilisation

### Erreur "Method not found"

**Symptôme** : Lors de l'appel d'un outil MCP, vous recevez une erreur indiquant que la méthode n'existe pas.

```
Error: Method 'server_name.tool_name' not found
```

**Causes possibles** :
- Le nom du serveur ou de l'outil est incorrect
- L'outil n'est pas disponible dans ce serveur
- Le serveur n'est pas correctement enregistré

**Solutions** :
1. Vérifiez le nom exact du serveur et de l'outil dans la documentation.

2. Utilisez la méthode `mcp.discover` pour lister les serveurs et outils disponibles :
   ```javascript
   const result = await client.call('mcp.discover', {});
   console.log(JSON.stringify(result, null, 2));
   ```

3. Assurez-vous que le serveur est correctement démarré et enregistré.

4. Vérifiez que vous utilisez la syntaxe correcte pour appeler l'outil :
   ```javascript
   // Syntaxe correcte
   const result = await client.callTool('server_name', 'tool_name', params);
   ```

### Erreur "Invalid parameters"

**Symptôme** : Lors de l'appel d'un outil MCP, vous recevez une erreur indiquant que les paramètres sont invalides.

```
Error: Invalid parameters: 'required_param' is required
```

**Causes possibles** :
- Un paramètre requis est manquant
- Un paramètre a un type incorrect
- Un paramètre a une valeur invalide

**Solutions** :
1. Consultez la documentation de l'outil pour connaître les paramètres requis et leur format.

2. Utilisez la méthode `mcp.discover` pour obtenir le schéma des paramètres :
   ```javascript
   const result = await client.call('mcp.discover', {});
   const toolSchema = result.servers['server_name'].tools['tool_name'].params;
   console.log(JSON.stringify(toolSchema, null, 2));
   ```

3. Assurez-vous que tous les paramètres requis sont fournis et ont le bon type :
   ```javascript
   // Exemple avec tous les paramètres requis
   const result = await client.callTool('server_name', 'tool_name', {
     required_param: 'value',
     optional_param: 42
   });
   ```

4. Vérifiez les valeurs des paramètres pour vous assurer qu'elles respectent les contraintes (min/max, format, etc.).

### Erreur "Connection refused"

**Symptôme** : Impossible de se connecter au serveur MCP.

```
Error: connect ECONNREFUSED 127.0.0.1:3000
```

**Causes possibles** :
- Le serveur n'est pas en cours d'exécution
- Le serveur écoute sur un port différent
- Le serveur écoute sur une interface réseau différente
- Problèmes de réseau ou de pare-feu

**Solutions** :
1. Vérifiez que le serveur est en cours d'exécution :
   ```bash
   # Sur Windows
   tasklist | findstr node
   
   # Sur Linux/macOS
   ps aux | grep node
   ```

2. Vérifiez le port et l'interface configurés :
   ```bash
   cat config.json | grep -A 5 "server"
   ```

3. Essayez de vous connecter à l'adresse IP exacte plutôt qu'à localhost :
   ```javascript
   const client = new MCPClient();
   await client.connect('http://127.0.0.1:3000');
   ```

4. Vérifiez les règles de pare-feu et assurez-vous que le port est ouvert :
   ```bash
   # Sur Windows
   netsh advfirewall firewall add rule name="MCP Server" dir=in action=allow protocol=TCP localport=3000
   
   # Sur Linux
   sudo ufw allow 3000/tcp
   ```

### Erreur "Timeout"

**Symptôme** : Les appels aux outils MCP échouent avec une erreur de timeout.

```
Error: Request timed out after 30000ms
```

**Causes possibles** :
- L'opération prend trop de temps
- Le serveur est surchargé
- Problèmes de réseau
- Le serveur est bloqué ou ne répond pas

**Solutions** :
1. Augmentez le timeout dans la configuration du client :
   ```javascript
   const client = new MCPClient({
     timeout: 60000  // 60 secondes
   });
   ```

2. Optimisez l'opération pour qu'elle s'exécute plus rapidement.

3. Vérifiez la charge du serveur et augmentez les ressources si nécessaire.

4. Implémentez une logique de nouvelle tentative avec backoff exponentiel :
   ```javascript
   async function callWithRetry(server, tool, params, maxRetries = 3, initialDelay = 1000) {
     let retries = 0;
     while (retries < maxRetries) {
       try {
         return await client.callTool(server, tool, params);
       } catch (error) {
         if (error.message.includes('timeout') && retries < maxRetries - 1) {
           const delay = initialDelay * Math.pow(2, retries);
           console.log(`Request timed out. Retrying in ${delay}ms...`);
           await new Promise(resolve => setTimeout(resolve, delay));
           retries++;
         } else {
           throw error;
         }
       }
     }
   }
   ```

### Problèmes avec les ressources

**Symptôme** : Erreurs lors de l'accès aux ressources MCP.

```
Error: Resource not found: resource://server_name/resource_path
```

**Causes possibles** :
- L'URI de la ressource est incorrect
- La ressource n'existe pas
- Le serveur n'est pas correctement configuré pour fournir cette ressource

**Solutions** :
1. Vérifiez le format de l'URI de la ressource :
   ```javascript
   // Format correct
   const uri = 'resource://server_name/resource_path';
   ```

2. Utilisez la méthode `mcp.discover` pour lister les ressources disponibles :
   ```javascript
   const result = await client.call('mcp.discover', {});
   const resources = result.servers['server_name'].resources;
   console.log(JSON.stringify(resources, null, 2));
   ```

3. Assurez-vous que le serveur est correctement configuré pour fournir cette ressource.

4. Vérifiez les permissions d'accès à la ressource dans la configuration du serveur.
<!-- END_SECTION: usage_issues -->

<!-- START_SECTION: integration_issues -->
## Problèmes d'intégration avec Roo

### Erreur "Server not found"

**Symptôme** : Roo ne peut pas trouver le serveur MCP.

```
Error: Server 'server_name' not found
```

**Causes possibles** :
- Le serveur n'est pas en cours d'exécution
- Le serveur n'est pas correctement enregistré dans la configuration de Roo
- Problèmes de connexion entre Roo et le serveur

**Solutions** :
1. Vérifiez que le serveur MCP est en cours d'exécution :
   ```bash
   # Sur Windows
   tasklist | findstr node
   
   # Sur Linux/macOS
   ps aux | grep node
   ```

2. Vérifiez la configuration des serveurs dans Roo :
   ```bash
   cat ~/.roo/servers.json
   ```
   Assurez-vous que le serveur est correctement configuré avec le bon nom et la bonne URL.

3. Redémarrez le serveur MCP et Roo.

4. Testez la connexion au serveur MCP directement :
   ```bash
   curl -X POST http://localhost:3000/mcp -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"mcp.discover","params":{},"id":1}'
   ```

### Erreur "Tool execution failed"

**Symptôme** : Roo ne peut pas exécuter un outil MCP.

```
Error: Tool execution failed: server_name.tool_name
```

**Causes possibles** :
- Problèmes de communication entre Roo et le serveur MCP
- Erreur dans l'outil MCP
- Paramètres incorrects

**Solutions** :
1. Vérifiez les journaux du serveur MCP pour plus de détails sur l'erreur.

2. Testez l'outil directement avec le client MCP :
   ```javascript
   const { MCPClient } = require('@modelcontextprotocol/client');
   
   async function testTool() {
     const client = new MCPClient();
     await client.connect('http://localhost:3000');
     try {
       const result = await client.callTool('server_name', 'tool_name', params);
       console.log(result);
     } catch (error) {
       console.error(error);
     }
   }
   
   testTool();
   ```

3. Vérifiez que les paramètres fournis par Roo sont corrects.

4. Mettez à jour le serveur MCP et Roo vers les dernières versions.

### Problèmes de configuration de Roo

**Symptôme** : Roo ne reconnaît pas correctement les serveurs ou outils MCP.

**Causes possibles** :
- Configuration incorrecte dans Roo
- Incompatibilité de versions
- Problèmes de découverte des serveurs

**Solutions** :
1. Vérifiez la configuration des serveurs dans Roo :
   ```bash
   cat ~/.roo/servers.json
   ```

2. Assurez-vous que le format de la configuration est correct :
   ```json
   {
     "servers": [
       {
         "name": "server_name",
         "url": "http://localhost:3000",
         "type": "stdio"
       }
     ]
   }
   ```

3. Redémarrez Roo après avoir modifié la configuration.

4. Utilisez l'API de découverte pour vérifier que le serveur est correctement configuré :
   ```bash
   curl -X POST http://localhost:3000/mcp -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"mcp.discover","params":{},"id":1}'
   ```

### Problèmes de permissions

**Symptôme** : Roo ne peut pas accéder à certaines fonctionnalités du serveur MCP.

**Causes possibles** :
- Restrictions de sécurité dans le serveur MCP
- Problèmes de permissions au niveau du système de fichiers
- Configuration incorrecte des chemins autorisés

**Solutions** :
1. Vérifiez la configuration de sécurité du serveur MCP :
   ```json
   {
     "security": {
       "allowedPaths": ["/path/to/allowed/directory"],
       "disallowedPatterns": ["\\.env$", "\\.git/"]
     }
   }
   ```

2. Assurez-vous que Roo et le serveur MCP sont exécutés avec les mêmes permissions utilisateur.

3. Vérifiez les permissions des fichiers et répertoires auxquels le serveur MCP tente d'accéder.

4. Configurez correctement les chemins autorisés dans le serveur MCP pour inclure les répertoires nécessaires à Roo.

### Le serveur MCP ne se met pas à jour après modification (Hot-Reload)

**Symptôme** : Après avoir modifié le code source d'un MCP interne (ex: `roo-state-manager`), recompilé (`npm run build`), et redémarré les MCPs, les modifications ne sont pas prises en compte. Les nouvelles fonctionnalités ou les correctifs n'apparaissent pas.

**Causes possibles** :
- **Problème de Cache :** Le gestionnaire de processus (ex: `roo-state-manager`) peut avoir un mécanisme de cache qui n'est pas correctement invalidé.
- **Mauvaise Gestion de Version :** Le mécanisme de détection de changement peut être défectueux. Par exemple, s'il se base sur un timestamp et que les modifications sont trop rapides, le changement peut ne pas être détecté.

**Solution : Versioning Dynamique**
La solution la plus robuste est d'implémenter un système de versioning dynamique pour chaque MCP interne.

1.  **Incrémenter la Version :** Après chaque modification significative du code, incrémentez la version dans le fichier `package.json` du MCP concerné (ex: de `1.0.1` à `1.0.2`).

2.  **Importer la Version :** Dans le code du MCP, importez dynamiquement cette version.
```typescript
// Exemple dans index.ts
import { version } from '../package.json';

// Utilisez cette version dans la logique de démarrage ou de découverte
console.log(`Démarrage du serveur MCP version ${version}`);
```

3.  **Utiliser la Version dans la Configuration :** Le gestionnaire de MCPs (`roo-state-manager`) doit lire cette version et l'utiliser pour décider s'il doit recharger le serveur. Assurez-vous que la configuration dans `mcp_settings.json` reflète la nouvelle version pour forcer le rechargement.
```json
"roo-state-manager": {
  "enabled": true,
  "command": "node",
  "args": ["./dist/index.js"],
  "version": "1.0.2" // Mettre à jour cette version
}
```
Cette approche garantit que chaque build avec une nouvelle version invalide systématiquement les caches et force le rechargement du code mis à jour.
<!-- END_SECTION: integration_issues -->
<!-- START_SECTION: data_issues -->
## Problèmes de Données

### Erreur `SyntaxError: Unexpected token '﻿'` lors du parsing JSON

**Symptôme** : Un serveur MCP (souvent `roo-state-manager` qui lit de nombreux fichiers d'historique) échoue au démarrage avec une erreur de parsing JSON qui semble pointer vers un caractère invisible au début du fichier.

```
SyntaxError: Unexpected token '﻿', "﻿[{"role":"... is not valid JSON
```

**Cause Racine** :
Cette erreur est presque toujours causée par la présence d'un **BOM (Byte Order Mark) UTF-8** au début d'un fichier JSON. Le BOM est un caractère invisible (`U+FEFF`) que certains éditeurs ou processus (comme la restauration de fichiers sous Windows) peuvent ajouter. Le parseur JSON standard de Node.js ne le gère pas et le considère comme un token invalide.

**Solutions** :
1.  **Identification des fichiers corrompus** :
Il est nécessaire de scanner les fichiers potentiellement affectés pour détecter la présence du BOM. Un script est souvent nécessaire pour le faire en masse.

2.  **Nettoyage des fichiers** :
Les fichiers identifiés doivent être ré-enregistrés sans le BOM. La plupart des éditeurs de code modernes (comme VS Code) permettent de choisir l'encodage "UTF-8" (sans BOM).

3.  **Script de Réparation Automatisé** :
Pour les cas de corruption massive (par exemple, sur les fichiers `api_conversation_history.json`), un script de réparation est la solution la plus efficace. Un script PowerShell, `scripts/repair/repair-conversation-bom.ps1`, a été développé pour cette tâche.
```powershell
# Exécuter en mode diagnostic pour lister les fichiers corrompus
./scripts/repair/repair-conversation-bom.ps1 -WhatIf

# Exécuter en mode réparation pour nettoyer les fichiers
./scripts/repair/repair-conversation-bom.ps1
```
Consultez la documentation du script pour plus de détails.

4.  **Prévention** :
- Configurez vos outils et éditeurs pour sauvegarder les fichiers en **UTF-8 sans BOM**.
- Soyez vigilant lors de la restauration de fichiers ou du transfert entre différents systèmes d'exploitation.
<!-- END_SECTION: data_issues -->
<!-- START_SECTION: performance_issues -->
## Problèmes de performance

### Lenteur générale

**Symptôme** : Le serveur MCP répond lentement à toutes les requêtes.

**Causes possibles** :
- Ressources système insuffisantes
- Trop de requêtes simultanées
- Problèmes de configuration
- Fuites de mémoire

**Solutions** :
1. Vérifiez l'utilisation des ressources système :
   ```bash
   # Sur Linux
   top
   
   # Sur Windows
   taskmgr
   ```

2. Limitez le nombre d'opérations concurrentes dans la configuration :
   ```json
   {
     "performance": {
       "maxConcurrentOperations": 5
     }
   }
   ```

3. Activez le cache pour améliorer les performances des opérations répétées :
   ```json
   {
     "performance": {
       "cacheEnabled": true,
       "cacheMaxAge": 300
     }
   }
   ```

4. Augmentez les ressources allouées au serveur (mémoire, CPU).

5. Utilisez un profiler pour identifier les goulots d'étranglement :
   ```bash
   node --prof dist/index.js
   # Après exécution
   node --prof-process isolate-*.log > profile.txt
   ```

### Problèmes de mémoire

**Symptôme** : Le serveur consomme beaucoup de mémoire ou se bloque avec des erreurs de mémoire insuffisante.

```
FATAL ERROR: JavaScript heap out of memory
```

**Causes possibles** :
- Traitement de données trop volumineuses
- Fuites de mémoire
- Limites de mémoire Node.js trop basses

**Solutions** :
1. Augmentez la mémoire disponible pour Node.js :
   ```bash
   export NODE_OPTIONS="--max-old-space-size=4096"
   npm start
   ```

2. Utilisez des techniques de streaming pour traiter les fichiers volumineux plutôt que de les charger entièrement en mémoire.

3. Implémentez des limites de taille pour les opérations :
   ```json
   {
     "performance": {
       "maxFileSizeBytes": 10485760,  // 10 MB
       "maxTotalSizeBytes": 104857600  // 100 MB
     }
   }
   ```

4. Utilisez des outils comme `heapdump` pour analyser l'utilisation de la mémoire :
   ```javascript
   const heapdump = require('heapdump');
   heapdump.writeSnapshot('./heap-' + Date.now() + '.heapsnapshot');
   ```

### Problèmes de réseau

**Symptôme** : Latence élevée, timeouts, erreurs de connexion.

**Causes possibles** :
- Problèmes de réseau
- Serveur distant lent
- Trop de connexions simultanées

**Solutions** :
1. Vérifiez votre connexion réseau et la latence vers le serveur :
   ```bash
   ping server_host
   ```

2. Utilisez un cache pour réduire les requêtes réseau :
   ```json
   {
     "performance": {
       "cacheEnabled": true,
       "cacheMaxAge": 300
     }
   }
   ```

3. Implémentez une logique de nouvelle tentative avec backoff exponentiel pour les requêtes réseau.

4. Utilisez des connexions persistantes plutôt que de créer une nouvelle connexion pour chaque requête.

5. Optimisez la taille des données transmises en compressant les requêtes et les réponses :
   ```json
   {
     "server": {
       "compression": true
     }
   }
   ```

### Problèmes de traitement de fichiers volumineux

**Symptôme** : Lenteur ou erreurs lors du traitement de fichiers volumineux.

**Causes possibles** :
- Fichiers trop volumineux pour être chargés en mémoire
- Opérations inefficaces sur les fichiers
- Disque lent

**Solutions** :
1. Utilisez des techniques de streaming pour traiter les fichiers par morceaux :
   ```javascript
   const fs = require('fs');
   const readline = require('readline');
   
   const fileStream = fs.createReadStream('large-file.txt');
   const rl = readline.createInterface({
     input: fileStream,
     crlfDelay: Infinity
   });
   
   rl.on('line', (line) => {
     // Traiter chaque ligne individuellement
     processLine(line);
   });
   ```

2. Utilisez des extraits pour lire uniquement les parties nécessaires des fichiers :
   ```javascript
   const result = await client.callTool('quickfiles-server', 'read_multiple_files', {
     paths: [
       {
         path: 'chemin/vers/fichier.txt',
         excerpts: [
           { start: 1, end: 100 },  // Lire uniquement les 100 premières lignes
         ]
       }
     ]
   });
   ```

3. Utilisez un disque SSD pour améliorer les performances de lecture/écriture.

4. Implémentez un traitement par lots pour les opérations sur de grandes quantités de données.
<!-- END_SECTION: performance_issues -->

<!-- START_SECTION: security_issues -->
## Problèmes de sécurité

### Accès non autorisé

**Symptôme** : Le serveur MCP permet l'accès à des fichiers ou des ressources qui devraient être restreints.

**Causes possibles** :
- Configuration de sécurité incorrecte ou manquante
- Chemins autorisés trop permissifs
- Motifs d'exclusion insuffisants

**Solutions** :
1. Configurez correctement les chemins autorisés :
   ```json
   {
     "security": {
       "allowedPaths": [
         "/chemin/vers/repertoire1",
         "/chemin/vers/repertoire2"
       ]
     }
   }
   ```

2. Ajoutez des motifs d'exclusion pour les fichiers sensibles :
   ```json
   {
     "security": {
       "disallowedPatterns": [
         "\\.env$",
         "\\.git/",
         "node_modules/",
         "passwords\\.txt$",
         "config\\.json$"
       ]
     }
   }
   ```

3. Utilisez des chemins absolus plutôt que relatifs pour éviter les attaques par traversée de répertoire.

4. Redémarrez le serveur après avoir modifié la configuration de sécurité.

### Problèmes d'authentification

**Symptôme** : N'importe qui peut se connecter au serveur et utiliser les outils.

**Causes possibles** :
- Absence d'authentification
- Configuration d'authentification incorrecte

**Solutions** :
1. Mettez en place un proxy inverse (comme Nginx) avec authentification devant le serveur MCP.

2. Limitez l'accès au serveur par IP :
   ```json
   {
     "security": {
       "allowedIPs": ["127.0.0.1", "192.168.1.0/24"]
     }
   }
   ```

3. Utilisez un VPN ou SSH tunneling pour accéder au serveur à distance de manière sécurisée.

4. Implémentez un mécanisme d'authentification personnalisé (nécessite des modifications du code).

### Exposition de données sensibles

**Symptôme** : Le serveur expose des données sensibles dans les réponses ou les journaux.

**Causes possibles** :
- Journalisation excessive
- Absence de filtrage des données sensibles
- Accès à des fichiers contenant des données sensibles

**Solutions** :
1. Réduisez le niveau de journalisation en production :
   ```json
   {
     "logging": {
       "level": "info"  // Évitez "debug" ou "trace" en production
     }
   }
   ```

2. Ajoutez des motifs d'exclusion pour les fichiers contenant des données sensibles :
   ```json
   {
     "security": {
       "disallowedPatterns": [
         "\\.env$",
         "credentials\\.json$",
         "passwords\\.txt$"
       ]
     }
   }
   ```

3. Mettez en place un mécanisme de masquage des données sensibles dans les journaux.

4. Utilisez HTTPS pour chiffrer les communications entre le client et le serveur.

### Vulnérabilités des dépendances

**Symptôme** : Des alertes de sécurité apparaissent lors de l'audit des dépendances.

**Causes possibles** :
- Dépendances obsolètes
- Vulnérabilités connues dans les packages utilisés

**Solutions** :
1. Exécutez régulièrement un audit de sécurité :
   ```bash
   npm audit
   ```

2. Mettez à jour les dépendances vulnérables :
   ```bash
   npm audit fix
   ```

3. Pour les cas plus complexes, utilisez `npm audit fix --force` ou mettez à jour manuellement les dépendances.

4. Utilisez des outils comme Dependabot ou Snyk pour surveiller automatiquement les vulnérabilités.
<!-- END_SECTION: security_issues -->

<!-- START_SECTION: diagnostic_commands -->
## Commandes de diagnostic

Cette section présente des commandes utiles pour diagnostiquer les problèmes courants avec les serveurs MCP.

### Vérification de l'état du serveur

```bash
# Vérifier si le serveur est en cours d'exécution
ps aux | grep node  # Linux/macOS
tasklist | findstr node  # Windows

# Vérifier les ports utilisés
netstat -tulpn | grep LISTEN  # Linux
netstat -ano | findstr LISTENING  # Windows

# Vérifier l'utilisation des ressources
top  # Linux/macOS
taskmgr  # Windows
```

### Diagnostic réseau

```bash
# Vérifier la connectivité au serveur
ping localhost
curl -I http://localhost:3000

# Tester l'API MCP
curl -X POST http://localhost:3000/mcp -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"mcp.discover","params":{},"id":1}'

# Vérifier les connexions actives
lsof -i :3000  # Linux/macOS
netstat -ano | findstr :3000  # Windows
```

### Diagnostic Node.js

```bash
# Vérifier la version de Node.js
node --version

# Vérifier les modules installés
npm list --depth=0

# Vérifier les vulnérabilités
npm audit

# Exécuter avec plus de journalisation
NODE_DEBUG=* node dist/index.js
```

### Diagnostic des fichiers de configuration

```bash
# Vérifier la syntaxe JSON
cat config.json | jq

# Vérifier les permissions des fichiers
ls -la config.json  # Linux/macOS
icacls config.json  # Windows

# Créer une configuration par défaut
cp config.example.json config.json
```

### Diagnostic des journaux

```bash
# Afficher les dernières lignes des journaux
tail -n 100 server.log

# Rechercher des erreurs dans les journaux
grep "ERROR" server.log
grep "Exception" server.log

# Suivre les journaux en temps réel
tail -f server.log
```

### Diagnostic de performance

```bash
# Profiler l'application
node --prof dist/index.js
node --prof-process isolate-*.log > profile.txt

# Générer un heap dump
node --inspect dist/index.js
# Puis dans Chrome DevTools, Memory tab, prendre un snapshot

# Surveiller l'utilisation de la mémoire
node --trace-gc dist/index.js
```

### Utilisation des outils de diagnostic du système de surveillance

Le système de surveillance des serveurs MCP fournit plusieurs outils de diagnostic pour identifier et résoudre les problèmes:

#### Vérification de l'état des serveurs

```powershell
# Vérifier l'état de tous les serveurs MCP
.\mcps\monitoring\monitor-mcp-servers.ps1 -CheckOnly

# Vérifier l'état d'un serveur spécifique
.\mcps\monitoring\monitor-mcp-servers.ps1 -CheckOnly -ServerName "win-cli"
```

#### Analyse des journaux de surveillance

```powershell
# Afficher les dernières entrées des journaux de surveillance
Get-Content -Tail 50 .\mcps\monitoring\logs\mcp-monitor-$(Get-Date -Format "yyyy-MM-dd").log

# Rechercher des erreurs dans les journaux
Select-String -Path .\mcps\monitoring\logs\mcp-monitor-*.log -Pattern "ERROR"

# Analyser les alertes récentes
Get-Content .\mcps\monitoring\alerts\mcp-alerts-$(Get-Date -Format "yyyy-MM-dd").log
```

#### Tests de connectivité

```powershell
# Tester la connectivité à tous les serveurs MCP
.\mcps\monitoring\test-mcp-connectivity.ps1

# Tester la connectivité à un serveur spécifique
.\mcps\monitoring\test-mcp-connectivity.ps1 -ServerName "jupyter"
```

#### Génération de rapports de diagnostic

```powershell
# Générer un rapport de diagnostic complet
.\mcps\monitoring\generate-diagnostic-report.ps1

# Générer un rapport pour un serveur spécifique
.\mcps\monitoring\generate-diagnostic-report.ps1 -ServerName "quickfiles"
```

#### Interface web de surveillance

Le système de surveillance inclut également une interface web pour visualiser l'état des serveurs MCP:

1. Démarrez l'interface web:
   ```powershell
   .\mcps\monitoring\start-monitoring-dashboard.ps1
   ```

2. Accédez à l'interface dans votre navigateur:
   ```
   http://localhost:8080/dashboard
   ```

L'interface web fournit:
- Un tableau de bord avec l'état de tous les serveurs
- Des graphiques de performance
- Un historique des alertes
- Des outils de diagnostic interactifs
<!-- END_SECTION: diagnostic_commands -->

<!-- START_SECTION: specific_guides -->
## Procédures de récupération en cas de panne

Cette section décrit les procédures à suivre pour récupérer d'une panne d'un ou plusieurs serveurs MCP.

### Récupération automatique

Le système de surveillance peut redémarrer automatiquement les serveurs défaillants:

```powershell
# Activer la récupération automatique pour tous les serveurs
.\mcps\monitoring\monitor-mcp-servers.ps1 -RestartServers

# Activer la récupération automatique avec notification par email
.\mcps\monitoring\monitor-mcp-servers.ps1 -RestartServers -EmailAlert
```

### Récupération manuelle

Si la récupération automatique échoue ou n'est pas activée, suivez ces étapes pour récupérer manuellement:

#### 1. Diagnostic initial

```powershell
# Vérifier l'état de tous les serveurs
.\mcps\monitoring\monitor-mcp-servers.ps1 -CheckOnly

# Générer un rapport de diagnostic
.\mcps\monitoring\generate-diagnostic-report.ps1
```

#### 2. Arrêt des serveurs défaillants

```powershell
# Arrêter un serveur spécifique
.\mcps\monitoring\stop-mcp-server.ps1 -ServerName "jupyter"

# Arrêter tous les serveurs
.\mcps\monitoring\stop-all-mcp-servers.ps1
```

#### 3. Nettoyage des ressources

```powershell
# Nettoyer les ressources d'un serveur spécifique
.\mcps\monitoring\cleanup-mcp-server.ps1 -ServerName "quickfiles"

# Nettoyer les fichiers temporaires
Remove-Item -Path .\mcps\mcp-servers\servers\*\temp\* -Recurse -Force
```

#### 4. Redémarrage des serveurs

```powershell
# Redémarrer un serveur spécifique
.\mcps\monitoring\start-mcp-server.ps1 -ServerName "win-cli"

# Redémarrer tous les serveurs
.\mcps\monitoring\start-all-mcp-servers.ps1
```

#### 5. Vérification post-récupération

```powershell
# Vérifier l'état après redémarrage
.\mcps\monitoring\monitor-mcp-servers.ps1 -CheckOnly

# Exécuter des tests de validation
.\mcps\tests\run-validation-tests.ps1
```

### Récupération après corruption de données

Si les données d'un serveur MCP sont corrompues:

1. Arrêtez le serveur concerné
2. Sauvegardez les données corrompues pour analyse
3. Restaurez à partir d'une sauvegarde récente:
   ```powershell
   .\mcps\monitoring\restore-mcp-data.ps1 -ServerName "jupyter" -BackupDate "2025-05-15"
   ```
4. Si aucune sauvegarde n'est disponible, réinitialisez les données:
   ```powershell
   .\mcps\monitoring\reset-mcp-data.ps1 -ServerName "jupyter"
   ```
5. Redémarrez le serveur et vérifiez son fonctionnement

### Récupération après mise à jour défaillante

Si une mise à jour d'un serveur MCP échoue:

1. Arrêtez le serveur concerné
2. Revenez à la version précédente:
   ```powershell
   .\mcps\monitoring\rollback-mcp-server.ps1 -ServerName "quickfiles" -Version "previous"
   ```
3. Redémarrez le serveur et vérifiez son fonctionnement
4. Analysez les logs pour comprendre la cause de l'échec

### Récupération après panne système

En cas de panne système complète:

1. Redémarrez le système d'exploitation
2. Vérifiez l'intégrité du système de fichiers
3. Démarrez les serveurs MCP dans cet ordre:
   - Serveurs de base (Filesystem, Win-CLI)
   - Serveurs de données (QuickFiles, Jupyter)
   - Serveurs d'API (GitHub, SearXNG)
4. Vérifiez l'état de tous les serveurs
5. Exécutez des tests de validation complets

---

## Patterns de Débogage Appliqués (Synthèse Post-Réparation Janvier 2025)

Suite à une campagne de fiabilisation de plusieurs serveurs MCP, les patterns de diagnostic et de résolution suivants se sont avérés particulièrement efficaces. Pour une analyse complète, [consultez la synthèse SDDD dédiée](../docs/missions/2025-01-13-synthese-reparations-mcp-sddd.md).

### 1. Incohérence Build TypeScript vs. Configuration MCP (`roo-state-manager`)
- **Symptôme :** Erreur `Cannot find module` au démarrage du MCP, bien que les fichiers compilés existent.
- **Diagnostic :** La structure des répertoires en sortie (`build/src/`) ne correspondait pas au chemin attendu par le point d'entrée du `tsconfig.json`. Le serveur cherchait `./tools/index.js` au lieu de `../src/tools/index.js`.
- **Solution Efficace :** Mettre à jour le chemin dans `mcp_settings.json` pour pointer vers le point d'entrée correct (`.../build/src/index.js`). Cette solution est minimalement invasive et évite de modifier la configuration de build potentiellement partagée.
- **Leçon :** Toujours valider le chemin d'exécution final d'un MCP compilé par rapport à sa configuration de lancement.

### 2. Erreur de Configuration par Variable d'Environnement (`office-powerpoint`)
- **Symptôme :** Le serveur échoue à l'initialisation avec une erreur indiquant qu'une ressource ou un chemin est introuvable.
- **Diagnostic :** Le serveur dépendait d'un chemin vers un répertoire de ressources (ex: des templates PowerPoint), qui devait être fourni via une variable d'environnement (`PPT_TEMPLATE_PATH`). Cette variable n'était pas définie dans la configuration du MCP.
- **Solution Efficace :** Ajouter la variable d'environnement requise directement dans la section `env` de la configuration du serveur dans `mcp_settings.json`.
- **Leçon :** Pour les MCPs externes ou basés sur Python, vérifier systématiquement s'ils dépendent de variables d'environnement pour leur configuration et s'assurer qu'elles sont correctement injectées.

### 3. Incompatibilité de Protocole ou de Point d'Entrée (`jupyter-papermill-mcp-server`)
- **Symptôme :** Le serveur démarre sans erreur apparente, mais la communication avec le client Roo échoue, ou les outils ne sont pas exposés correctement.
- **Diagnostic :** L'historique du projet a montré l'existence de plusieurs points d'entrée (`main.py`, `main_working.py`, `main_fixed.py`), indiquant des tentatives de correction. L'analyse a révélé que le point d'entrée utilisé implémentait une version non standard ou dépréciée du protocole MCP.
- **Solution Efficace :** Changer le point d'entrée dans l'argument de commande de `mcp_settings.json` pour utiliser le script corrigé (`main_fixed.py`), qui contient l'implémentation conforme du protocole.
- **Leçon :** Quand un serveur semble "silencieusement" défaillant, vérifier le point d'entrée exact et l'historique des fichiers associés. Une réparation a peut-être déjà été effectuée mais pas appliquée dans la configuration de lancement.
## Guides de dépannage spécifiques

Cette section fournit des liens vers les guides de dépannage spécifiques à chaque serveur MCP. Consultez ces guides pour des informations plus détaillées sur les problèmes spécifiques à chaque serveur.

### Serveurs MCP internes

| Serveur | Guide de dépannage |
|---------|-------------------|
| QuickFiles | [Guide de dépannage QuickFiles](mcp-servers/servers/quickfiles-server/TROUBLESHOOTING.md) |
| JinaNavigator | [Guide de dépannage JinaNavigator](mcp-servers/servers/jinavigator-server/TROUBLESHOOTING.md) |
| Jupyter | [Guide de dépannage Jupyter](mcp-servers/servers/jupyter-mcp-server/TROUBLESHOOTING.md) |

### Serveurs MCP externes

| Serveur | Guide de dépannage |
|---------|-------------------|
| Docker | [Guide de dépannage Docker](external/docker/TROUBLESHOOTING.md) |
| Filesystem | [Guide de dépannage Filesystem](external/filesystem/TROUBLESHOOTING.md) |
| Git | [Guide de dépannage Git](external/git/TROUBLESHOOTING.md) |
| GitHub | [Guide de dépannage GitHub](external/github/TROUBLESHOOTING.md) |
| Win-CLI | [Guide de dépannage Win-CLI](external/win-cli/TROUBLESHOOTING.md) |
| Jupyter | [Guide de dépannage Jupyter](internal/servers/jupyter-mcp-server/TROUBLESHOOTING.md) |

### Ressources supplémentaires

- [Documentation officielle du protocole MCP](https://github.com/modelcontextprotocol/protocol)
- [Forum de support MCP](https://github.com/modelcontextprotocol/protocol/discussions)
- [Signaler un problème](https://github.com/modelcontextprotocol/protocol/issues)
- [Guide d'optimisation des MCPs](./OPTIMIZATIONS.md)
- [Documentation du système de surveillance](./monitoring/README.md)

Si vous rencontrez un problème qui n'est pas couvert par ce guide ou les guides spécifiques, n'hésitez pas à ouvrir une issue sur le dépôt GitHub correspondant ou à contacter l'équipe de support.
<!-- END_SECTION: specific_guides -->

<!-- START_SECTION: navigation -->
## Navigation

- [Index principal](./INDEX.md)
- [Accueil](./README.md)
- [Guide de recherche](./SEARCH.md)
- [MCPs Internes](./mcp-servers/INDEX.md)
- [MCPs Externes](./external/README.md)
<!-- END_SECTION: navigation -->