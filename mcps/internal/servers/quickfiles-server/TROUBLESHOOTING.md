# Guide de dépannage du serveur MCP QuickFiles

<!-- START_SECTION: introduction -->
Ce guide de dépannage vous aidera à résoudre les problèmes courants rencontrés lors de l'utilisation du serveur MCP QuickFiles. Il couvre les problèmes d'installation, de configuration, de connexion, et d'utilisation des différents outils.
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
   npm run build
   ```

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
<!-- END_SECTION: installation_issues -->

<!-- START_SECTION: startup_issues -->
## Problèmes de démarrage

### Le serveur ne démarre pas

**Symptôme** : Le serveur ne démarre pas ou se termine immédiatement après le démarrage.

**Causes possibles** :
- Port déjà utilisé
- Configuration incorrecte
- Erreurs dans le code

**Solutions** :
1. Vérifiez si le port est déjà utilisé :
   ```bash
   # Sur Windows
   netstat -ano | findstr :3000
   
   # Sur Linux/macOS
   lsof -i :3000
   ```
   Si le port est utilisé, changez le port dans la configuration ou arrêtez l'application qui l'utilise.

2. Vérifiez le fichier de configuration :
   ```bash
   cat config.json
   ```
   Assurez-vous que le format JSON est valide et que les options sont correctes.

3. Exécutez le serveur en mode debug pour voir les erreurs détaillées :
   ```bash
   node --inspect dist/index.js
   ```

4. Vérifiez les journaux pour plus de détails sur l'erreur :
   ```bash
   cat quickfiles.log
   ```

### Erreur "Address already in use"

**Symptôme** : Le serveur ne peut pas démarrer car le port est déjà utilisé.

### Erreur "Cannot find module './dist/index.js'"

**Symptôme** : Le serveur ne peut pas démarrer car le fichier compilé est introuvable.

```
Error: Cannot find module './dist/index.js'
```

**Causes possibles** :
- Le projet n'a pas été compilé
- Le chemin vers le fichier de démarrage est incorrect dans package.json

**Solutions** :
1. Compilez le projet :
   ```bash
   npm run build
   ```

2. Vérifiez le script de démarrage dans package.json :
   ```json
   {
     "scripts": {
       "start": "node dist/index.js"
     }
   }
   ```
   Assurez-vous que le chemin correspond à l'emplacement réel du fichier compilé.

3. Si le problème persiste, vérifiez la structure du répertoire dist :
   ```bash
   ls -la dist/
   ```
   Assurez-vous que le fichier index.js existe dans ce répertoire.
<!-- END_SECTION: startup_issues -->

<!-- START_SECTION: connection_issues -->
## Problèmes de connexion

### Impossible de se connecter au serveur

**Symptôme** : Le client MCP ne peut pas se connecter au serveur QuickFiles.

**Causes possibles** :
- Le serveur n'est pas en cours d'exécution
- Le serveur écoute sur une interface réseau différente
- Problèmes de réseau ou de pare-feu

**Solutions** :
1. Vérifiez que le serveur est en cours d'exécution :
   ```bash
   # Sur Windows
   netstat -ano | findstr :3000
   
   # Sur Linux/macOS
   lsof -i :3000
   ```

2. Assurez-vous que le serveur écoute sur la bonne interface :
   ```json
   {
     "server": {
       "host": "0.0.0.0",  // Écoute sur toutes les interfaces
       "port": 3000
     }
   }
   ```

3. Vérifiez les règles de pare-feu et assurez-vous que le port est ouvert :
   ```bash
   # Sur Windows
   netsh advfirewall firewall add rule name="QuickFiles MCP" dir=in action=allow protocol=TCP localport=3000
   
   # Sur Linux
   sudo ufw allow 3000/tcp
   ```

4. Testez la connexion avec curl :
   ```bash
   curl -X POST http://localhost:3000/mcp -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"mcp.discover","params":{},"id":1}'
   ```

### Erreur CORS

**Symptôme** : Erreurs CORS dans la console du navigateur lors de la connexion au serveur.

```
Access to fetch at 'http://localhost:3000/mcp' from origin 'http://localhost:8080' has been blocked by CORS policy
```

**Causes possibles** :
- Configuration CORS incorrecte ou manquante
- Origine non autorisée

**Solutions** :
1. Activez CORS dans la configuration du serveur :
   ```json
   {
     "server": {
       "cors": {
         "enabled": true,
         "origins": ["*"]
       }
     }
   }
   ```

2. Pour une configuration plus sécurisée, spécifiez les origines exactes :
   ```json
   {
     "server": {
       "cors": {
         "enabled": true,
         "origins": ["http://localhost:8080", "https://votre-application.com"]
       }
     }
   }
   ```

3. Redémarrez le serveur après avoir modifié la configuration.

### Erreur "Connection refused"

**Symptôme** : Le client ne peut pas se connecter au serveur avec l'erreur "Connection refused".

```
Error: connect ECONNREFUSED 127.0.0.1:3000
```

**Causes possibles** :
- Le serveur n'est pas en cours d'exécution
- Le serveur écoute sur un port différent
- Le serveur écoute sur une interface réseau différente

**Solutions** :
1. Vérifiez que le serveur est en cours d'exécution.

2. Vérifiez le port et l'interface configurés :
   ```bash
   cat config.json | grep -A 5 "server"
   ```

3. Essayez de vous connecter à l'adresse IP exacte plutôt qu'à localhost :
   ```javascript
   const client = new MCPClient();
   await client.connect('http://127.0.0.1:3000');
   ```

4. Si vous utilisez Docker, assurez-vous que les ports sont correctement exposés :
   ```bash
   docker run -p 3000:3000 quickfiles-mcp-server
   ```
<!-- END_SECTION: connection_issues -->

<!-- START_SECTION: tool_issues -->
## Problèmes avec les outils

### Problèmes avec `read_multiple_files`

#### Erreur "File not found"

**Symptôme** : L'outil renvoie une erreur indiquant que le fichier n'existe pas.

```
Erreur lors de la lecture du fichier: ENOENT: no such file or directory, open '...'
```

**Causes possibles** :
- Le chemin du fichier est incorrect
- Le fichier n'existe pas
- Le serveur n'a pas accès au répertoire contenant le fichier

**Solutions** :
1. Vérifiez que le chemin du fichier est correct et que le fichier existe :
   ```bash
   ls -la /chemin/vers/fichier
   ```

2. Assurez-vous que le chemin est relatif au répertoire de travail du serveur ou qu'il s'agit d'un chemin absolu autorisé.

3. Vérifiez que le répertoire contenant le fichier est dans la liste des chemins autorisés dans la configuration.

4. Vérifiez les permissions du fichier :
   ```bash
   ls -la /chemin/vers/fichier
   ```
   Assurez-vous que l'utilisateur qui exécute le serveur a les droits de lecture sur le fichier.

#### Erreur "Maximum file size exceeded"

**Symptôme** : L'outil renvoie une erreur indiquant que la taille maximale du fichier est dépassée.

```
Erreur lors de la lecture du fichier: Maximum file size exceeded (10 MB)
```

**Causes possibles** :
- Le fichier est trop volumineux par rapport à la limite configurée

**Solutions** :
1. Utilisez des extraits pour lire uniquement les parties nécessaires du fichier :
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

2. Augmentez la limite de taille de fichier dans la configuration :
   ```json
   {
     "performance": {
       "maxFileSizeBytes": 20971520  // 20 MB
     }
   }
   ```

3. Utilisez d'autres outils pour traiter les fichiers volumineux, comme des outils de streaming ou de traitement par lots.
```
Error: listen EADDRINUSE: address already in use :::3000
```

**Causes possibles** :
- Une autre instance du serveur est déjà en cours d'exécution
- Une autre application utilise le même port

**Solutions** :
1. Arrêtez l'application qui utilise le port :
   ```bash
   # Sur Windows
   FOR /F "tokens=5" %P IN ('netstat -ano ^| findstr :3000') DO taskkill /F /PID %P
   
   # Sur Linux/macOS
   kill $(lsof -t -i:3000)
   ```

2. Changez le port dans la configuration :
   ```json
   {
     "server": {
       "port": 3001
     }
   }
   ```

3. Démarrez le serveur avec un port différent :
   ```bash
   npm start -- --port 3001
### Problèmes avec `list_directory_contents`

#### Résultats tronqués

**Symptôme** : Les résultats du listage de répertoires sont tronqués ou incomplets.

**Causes possibles** :
- La limite de lignes est atteinte
- Le répertoire contient trop de fichiers

**Solutions** :
1. Augmentez la valeur de `max_lines` dans la requête :
   ```javascript
   const result = await client.callTool('quickfiles-server', 'list_directory_contents', {
     paths: ['chemin/vers/repertoire'],
     max_lines: 5000  // Augmenter la limite
   });
   ```

2. Utilisez des filtres plus spécifiques pour réduire le nombre de résultats :
   ```javascript
   const result = await client.callTool('quickfiles-server', 'list_directory_contents', {
     paths: [
       {
         path: 'chemin/vers/repertoire',
         file_pattern: '*.js'  // Ne lister que les fichiers JavaScript
       }
     ]
   });
   ```

3. Divisez la requête en plusieurs requêtes plus petites, par exemple en listant les sous-répertoires séparément.

#### Erreur "Directory not found"

**Symptôme** : L'outil renvoie une erreur indiquant que le répertoire n'existe pas.

```
Erreur lors du listage du répertoire: ENOENT: no such file or directory, scandir '...'
```

**Causes possibles** :
- Le chemin du répertoire est incorrect
- Le répertoire n'existe pas
- Le serveur n'a pas accès au répertoire

**Solutions** :
1. Vérifiez que le chemin du répertoire est correct et que le répertoire existe :
   ```bash
   ls -la /chemin/vers/repertoire
   ```

2. Assurez-vous que le chemin est relatif au répertoire de travail du serveur ou qu'il s'agit d'un chemin absolu autorisé.

3. Vérifiez que le répertoire est dans la liste des chemins autorisés dans la configuration.

4. Vérifiez les permissions du répertoire :
   ```bash
   ls -la /chemin/vers/
   ```
   Assurez-vous que l'utilisateur qui exécute le serveur a les droits de lecture sur le répertoire.

### Problèmes avec `edit_multiple_files`

#### Aucune modification appliquée

**Symptôme** : L'outil ne modifie pas les fichiers comme prévu, mais ne renvoie pas d'erreur.

**Causes possibles** :
- La chaîne de recherche ne correspond pas exactement au texte dans le fichier
- Le fichier n'existe pas ou n'est pas accessible en écriture
- Le serveur n'a pas les permissions nécessaires

**Solutions** :
1. Vérifiez le contenu exact du fichier avant d'appliquer les modifications :
   ```javascript
   const content = await client.callTool('quickfiles-server', 'read_multiple_files', {
     paths: ['chemin/vers/fichier.txt']
   });
   console.log(content.result);
   ```

2. Assurez-vous que la chaîne de recherche correspond exactement au texte dans le fichier, y compris les espaces, les tabulations et les sauts de ligne.

3. Vérifiez les permissions du fichier :
   ```bash
   ls -la /chemin/vers/fichier.txt
   ```
   Assurez-vous que l'utilisateur qui exécute le serveur a les droits d'écriture sur le fichier.

4. Essayez d'utiliser des expressions régulières plus souples si le texte exact est difficile à cibler.

#### Erreur "Permission denied"

**Symptôme** : L'outil renvoie une erreur de permission lors de la modification d'un fichier.

```
Erreur lors de l'édition du fichier: EACCES: permission denied, open '...'
```

**Causes possibles** :
- Le serveur n'a pas les permissions nécessaires pour modifier le fichier
- Le fichier est en lecture seule
- Le fichier est verrouillé par une autre application

**Solutions** :
1. Vérifiez les permissions du fichier :
   ```bash
   ls -la /chemin/vers/fichier.txt
   ```

2. Modifiez les permissions du fichier pour permettre l'écriture :
   ```bash
   chmod u+w /chemin/vers/fichier.txt
   ```

3. Assurez-vous que le fichier n'est pas ouvert en mode exclusif par une autre application.

4. Exécutez le serveur avec des privilèges plus élevés (non recommandé pour la production) :
   ```bash
   sudo npm start
   ```

### Problèmes avec `delete_files`

#### Erreur "Permission denied"

**Symptôme** : L'outil renvoie une erreur de permission lors de la suppression d'un fichier.

```
Erreur lors de la suppression du fichier: EACCES: permission denied, unlink '...'
```

**Causes possibles** :
- Le serveur n'a pas les permissions nécessaires pour supprimer le fichier
- Le fichier est en lecture seule
- Le fichier est verrouillé par une autre application

**Solutions** :
1. Vérifiez les permissions du fichier et du répertoire parent :
   ```bash
   ls -la /chemin/vers/
   ls -la /chemin/vers/fichier.txt
   ```

2. Modifiez les permissions du fichier pour permettre la suppression :
   ```bash
   chmod u+w /chemin/vers/fichier.txt
   ```

3. Assurez-vous que le fichier n'est pas ouvert par une autre application.

4. Exécutez le serveur avec des privilèges plus élevés (non recommandé pour la production) :
   ```bash
   sudo npm start
   ```

#### Fichier non supprimé

**Symptôme** : L'outil indique que le fichier a été supprimé, mais le fichier existe toujours.

**Causes possibles** :
- Problème de cache du système de fichiers
- Le fichier a été recréé immédiatement après la suppression
- Le chemin du fichier est incorrect

**Solutions** :
1. Vérifiez que le fichier existe toujours :
   ```bash
   ls -la /chemin/vers/fichier.txt
   ```

2. Essayez de supprimer le fichier manuellement :
   ```bash
   rm /chemin/vers/fichier.txt
   ```

3. Vérifiez qu'aucune autre application ne recrée le fichier automatiquement.

4. Redémarrez le serveur et réessayez.
<!-- END_SECTION: tool_issues -->

<!-- START_SECTION: performance_issues -->
## Problèmes de performance

### Lenteur générale

**Symptôme** : Le serveur répond lentement à toutes les requêtes.

**Causes possibles** :
- Ressources système insuffisantes
- Trop de requêtes simultanées
- Problèmes de configuration

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

### Lenteur lors de la lecture de fichiers volumineux

**Symptôme** : Les opérations de lecture de fichiers volumineux sont très lentes ou provoquent des timeouts.

**Causes possibles** :
- Fichiers trop volumineux pour être chargés en mémoire
- Limitations de mémoire de Node.js
- Disque lent

**Solutions** :
1. Utilisez des extraits pour lire uniquement les parties nécessaires des fichiers :
   ```javascript
   const result = await client.callTool('quickfiles-server', 'read_multiple_files', {
     paths: [
       {
         path: 'chemin/vers/fichier.txt',
         excerpts: [
           { start: 1, end: 100 },
           { start: 500, end: 600 }
         ]
       }
     ]
   });
   ```

2. Limitez le nombre de lignes lues :
   ```javascript
   const result = await client.callTool('quickfiles-server', 'read_multiple_files', {
     paths: ['chemin/vers/fichier.txt'],
     max_lines_per_file: 1000
   });
   ```

3. Augmentez la mémoire disponible pour Node.js :
   ```bash
   export NODE_OPTIONS="--max-old-space-size=4096"
   npm start
   ```

4. Utilisez un disque SSD pour améliorer les performances de lecture.
### Lenteur lors du listage de répertoires volumineux

**Symptôme** : Les opérations de listage de répertoires contenant de nombreux fichiers sont très lentes.

**Causes possibles** :
- Trop de fichiers dans le répertoire
- Récursion profonde
- Disque lent

**Solutions** :
1. Évitez de lister récursivement des répertoires volumineux :
   ```javascript
   const result = await client.callTool('quickfiles-server', 'list_directory_contents', {
     paths: [
       {
         path: 'chemin/vers/repertoire',
         recursive: false  // Ne pas lister récursivement
       }
     ]
   });
   ```

2. Utilisez des motifs glob spécifiques pour filtrer les fichiers :
   ```javascript
   const result = await client.callTool('quickfiles-server', 'list_directory_contents', {
     paths: [
       {
         path: 'chemin/vers/repertoire',
         file_pattern: '*.js'  // Ne lister que les fichiers JavaScript
       }
     ]
   });
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

4. Utilisez un disque SSD pour améliorer les performances de lecture.
<!-- END_SECTION: performance_issues -->

<!-- START_SECTION: security_issues -->
## Problèmes de sécurité

### Accès non autorisé aux fichiers

**Symptôme** : Le serveur permet d'accéder à des fichiers qui devraient être restreints.

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
1. Mettez en place un proxy inverse (comme Nginx) avec authentification devant le serveur QuickFiles.

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

3. Mettez en place un mécanisme de masquage des données sensibles dans les journaux (nécessite des modifications du code).

4. Utilisez HTTPS pour chiffrer les communications entre le client et le serveur.
<!-- END_SECTION: security_issues -->

<!-- START_SECTION: advanced_troubleshooting -->
## Dépannage avancé

### Analyse des journaux

Les journaux du serveur QuickFiles peuvent fournir des informations précieuses pour diagnostiquer les problèmes. Par défaut, les journaux sont écrits dans le fichier `quickfiles.log` dans le répertoire du serveur.

1. Augmentez le niveau de détail des journaux pour le débogage :
   ```json
   {
     "logging": {
       "level": "debug",
       "file": "quickfiles-debug.log",
       "console": true
     }
   }
   ```

2. Analysez les journaux pour identifier les erreurs :
   ```bash
   grep "ERROR" quickfiles.log
   ```

3. Suivez les journaux en temps réel pendant l'exécution :
   ```bash
   tail -f quickfiles.log
   ```

4. Utilisez des outils comme `logrotate` pour gérer les fichiers de journaux volumineux.

### Débogage avec Node.js Inspector

Pour un débogage plus approfondi, vous pouvez utiliser l'inspecteur de Node.js :

1. Démarrez le serveur en mode débogage :
   ```bash
   node --inspect dist/index.js
   ```

2. Ouvrez Chrome et accédez à `chrome://inspect`.

3. Cliquez sur "Open dedicated DevTools for Node" pour ouvrir les outils de développement.

4. Utilisez les outils de développement pour définir des points d'arrêt, inspecter des variables et suivre l'exécution du code.

### Profilage des performances

Pour identifier les goulots d'étranglement de performance :

1. Générez un profil CPU :
   ```bash
   node --prof dist/index.js
   ```

2. Exécutez les opérations qui posent problème.

3. Arrêtez le serveur et analysez le profil :
   ```bash
   node --prof-process isolate-*.log > profile.txt
   ```

4. Examinez le fichier profile.txt pour identifier les fonctions qui consomment le plus de CPU.

### Tests de charge

Pour tester les performances et la stabilité du serveur sous charge :

1. Utilisez des outils comme Apache Bench ou wrk pour générer une charge :
   ```bash
   ab -n 1000 -c 10 -p payload.json -T application/json http://localhost:3000/mcp
   ```

2. Surveillez l'utilisation des ressources pendant le test :
   ```bash
   top -p $(pgrep -f "node.*index.js")
   ```

3. Analysez les résultats pour identifier les problèmes de performance et ajustez la configuration en conséquence.
<!-- END_SECTION: advanced_troubleshooting -->

<!-- START_SECTION: common_error_codes -->
## Codes d'erreur courants

### Codes d'erreur standard du protocole MCP

| Code | Nom | Description | Solution |
|------|-----|-------------|----------|
| -32700 | ParseError | Erreur d'analyse JSON | Vérifiez le format JSON de la requête |
| -32600 | InvalidRequest | La requête n'est pas valide | Vérifiez la structure de la requête MCP |
| -32601 | MethodNotFound | La méthode demandée n'existe pas | Vérifiez le nom de la méthode et les outils disponibles |
| -32602 | InvalidParams | Les paramètres fournis sont invalides | Vérifiez les paramètres de la requête |
| -32603 | InternalError | Erreur interne du serveur | Consultez les journaux pour plus de détails |
| -32000 | ServerError | Erreur générique du serveur | Consultez les journaux pour plus de détails |

### Codes d'erreur spécifiques à QuickFiles

| Code | Description | Solution |
|------|-------------|----------|
| -32001 | FileNotFound | Le fichier spécifié n'existe pas | Vérifiez le chemin du fichier |
| -32002 | DirectoryNotFound | Le répertoire spécifié n'existe pas | Vérifiez le chemin du répertoire |
| -32003 | AccessDenied | Accès refusé au fichier ou au répertoire | Vérifiez les permissions et les chemins autorisés |
| -32004 | FileSizeLimitExceeded | La taille du fichier dépasse la limite configurée | Utilisez des extraits ou augmentez la limite |
| -32005 | TotalSizeLimitExceeded | La taille totale des fichiers dépasse la limite configurée | Réduisez le nombre de fichiers ou augmentez la limite |
| -32006 | InvalidPath | Le chemin spécifié n'est pas valide | Vérifiez le format du chemin |
| -32007 | PathNotAllowed | Le chemin spécifié n'est pas dans la liste des chemins autorisés | Ajoutez le chemin à la liste des chemins autorisés |
| -32008 | PatternDisallowed | Le chemin correspond à un motif interdit | Modifiez le chemin ou le motif interdit |
<!-- END_SECTION: common_error_codes -->

<!-- START_SECTION: next_steps -->
## Prochaines étapes

Si vous avez résolu votre problème, vous pouvez maintenant :

1. [Configurer le serveur](CONFIGURATION.md) selon vos besoins
2. [Apprendre à utiliser le serveur](USAGE.md) avec des exemples pratiques
3. [Explorer les cas d'utilisation avancés](../docs/quickfiles-use-cases.md) pour tirer le meilleur parti du serveur

Si vous n'avez pas pu résoudre votre problème :

1. Consultez les [issues GitHub](https://github.com/jsboige/jsboige-mcp-servers/issues) pour voir si d'autres utilisateurs ont rencontré le même problème
2. Ouvrez une nouvelle issue en fournissant des détails sur votre problème, les étapes pour le reproduire et les journaux pertinents
3. Contactez l'équipe de support pour obtenir de l'aide supplémentaire
<!-- END_SECTION: next_steps -->