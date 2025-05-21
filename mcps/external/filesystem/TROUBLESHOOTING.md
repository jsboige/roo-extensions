# Résolution des problèmes du MCP Filesystem

<!-- START_SECTION: introduction -->
## Introduction

Ce document fournit des solutions aux problèmes courants rencontrés lors de l'utilisation du MCP Filesystem avec Roo. Si vous rencontrez des difficultés, consultez les sections ci-dessous pour trouver des solutions.
<!-- END_SECTION: introduction -->

<!-- START_SECTION: installation_issues -->
## Problèmes d'installation

### Le package ne s'installe pas correctement

**Symptôme**: Erreurs lors de l'installation du package `@modelcontextprotocol/server-filesystem`.

**Solutions possibles**:

1. **Vérifiez la version de Node.js**:
   ```bash
   node --version
   ```
   Assurez-vous d'utiliser Node.js v14.0.0 ou supérieur.

2. **Mettez à jour npm**:
   ```bash
   npm install -g npm@latest
   ```

3. **Problèmes de permissions**:
   - Sur Linux/macOS:
     ```bash
     sudo npm install -g @modelcontextprotocol/server-filesystem
     ```
   - Sur Windows, exécutez PowerShell en tant qu'administrateur

4. **Problèmes de dépendances**:
   ```bash
   npm cache clean --force
   npm install -g @modelcontextprotocol/server-filesystem
   ```

5. **Erreurs de compilation**:
   - Sur Linux/macOS:
     ```bash
     sudo apt-get install build-essential  # Pour Ubuntu/Debian
     ```
   - Sur Windows:
     ```bash
     npm install --global --production windows-build-tools
     ```

### Le serveur MCP ne se lance pas après l'installation

**Symptôme**: Le serveur MCP Filesystem ne démarre pas après l'installation.

**Solutions possibles**:

1. **Vérifiez l'installation**:
   ```bash
   npx @modelcontextprotocol/server-filesystem --version
   ```

2. **Installez localement dans le projet**:
   ```bash
   cd /chemin/vers/votre/projet
   npm install @modelcontextprotocol/server-filesystem
   npx @modelcontextprotocol/server-filesystem
   ```

3. **Vérifiez les conflits de version**:
   ```bash
   npm list -g | grep modelcontextprotocol
   ```
   Désinstallez les versions conflictuelles si nécessaire.
<!-- END_SECTION: installation_issues -->

<!-- START_SECTION: configuration_issues -->
## Problèmes de configuration

### Le serveur MCP ne se connecte pas à Roo

**Symptôme**: Le serveur MCP Filesystem ne s'affiche pas comme connecté dans Roo.

**Solutions possibles**:

1. **Vérifiez la configuration MCP**:
   - Assurez-vous que le fichier de configuration MCP contient l'entrée correcte pour le MCP Filesystem
   - Vérifiez que le chemin vers le fichier de configuration est correct

2. **Vérifiez que le serveur MCP est correctement lancé**:
   ```bash
   npx @modelcontextprotocol/server-filesystem --debug /chemin/vers/repertoire
   ```
   Vérifiez s'il y a des erreurs dans la sortie.

3. **Problèmes de chemin**:
   - Assurez-vous que les chemins des répertoires autorisés sont absolus et correctement formatés
   - Sur Windows, utilisez des doubles barres obliques inverses (`\\`) ou des barres obliques simples (`/`)

4. **Redémarrez VS Code**:
   - Fermez et redémarrez VS Code pour recharger la configuration MCP

### Erreur "No allowed directories specified"

**Symptôme**: Le serveur MCP démarre mais affiche une erreur indiquant qu'aucun répertoire autorisé n'est spécifié.

**Solutions possibles**:

1. **Spécifiez explicitement les répertoires autorisés**:
   ```json
   "args": [
     "-y",
     "@modelcontextprotocol/server-filesystem",
     "/chemin/vers/repertoire1",
     "/chemin/vers/repertoire2"
   ]
   ```

2. **Vérifiez le format des chemins**:
   - Utilisez des chemins absolus
   - Évitez les caractères spéciaux ou les espaces dans les chemins
   - Sur Windows, utilisez des doubles barres obliques inverses (`\\`) ou des barres obliques simples (`/`)

3. **Utilisez des variables d'environnement**:
   ```json
   "env": {
     "MCP_FILESYSTEM_ALLOWED_DIRS": "/chemin/vers/repertoire1,/chemin/vers/repertoire2"
   }
   ```
<!-- END_SECTION: configuration_issues -->

<!-- START_SECTION: access_issues -->
## Problèmes d'accès aux fichiers

### Erreur "Path not allowed"

**Symptôme**: Erreur indiquant que le chemin n'est pas autorisé lors de l'accès à un fichier.

**Solutions possibles**:

1. **Vérifiez les répertoires autorisés**:
   ```
   Outil: list_allowed_directories
   Arguments: {}
   ```

2. **Assurez-vous que le chemin est dans un répertoire autorisé**:
   - Le chemin doit être un sous-répertoire d'un des répertoires autorisés
   - Vérifiez les majuscules/minuscules sur les systèmes sensibles à la casse

3. **Utilisez des chemins absolus**:
   - Convertissez les chemins relatifs en chemins absolus
   - Évitez les séquences de traversée de répertoire (`../`)

4. **Ajoutez le répertoire parent aux répertoires autorisés**:
   - Modifiez la configuration pour inclure le répertoire parent du fichier auquel vous essayez d'accéder

### Erreur "Permission denied"

**Symptôme**: Erreur de permission lors de l'accès à un fichier ou un répertoire.

**Solutions possibles**:

1. **Vérifiez les permissions du fichier**:
   ```bash
   # Sur Linux/macOS
   ls -la /chemin/vers/fichier
   ```

2. **Ajustez les permissions du fichier**:
   ```bash
   # Sur Linux/macOS
   chmod 644 /chemin/vers/fichier
   chmod 755 /chemin/vers/repertoire
   ```

3. **Vérifiez le propriétaire du fichier**:
   ```bash
   # Sur Linux/macOS
   chown votre_utilisateur:votre_groupe /chemin/vers/fichier
   ```

4. **Exécutez VS Code avec des privilèges élevés** (à utiliser avec précaution):
   - Sur Windows, exécutez VS Code en tant qu'administrateur
   - Sur Linux/macOS, exécutez VS Code avec `sudo` (non recommandé pour une utilisation régulière)

### Erreur "File not found"

**Symptôme**: Erreur indiquant que le fichier n'existe pas.

**Solutions possibles**:

1. **Vérifiez que le chemin est correct**:
   - Vérifiez l'orthographe et la casse du chemin
   - Utilisez `list_directory` pour voir le contenu du répertoire parent

2. **Créez les répertoires parents si nécessaire**:
   ```
   Outil: create_directory
   Arguments:
   {
     "path": "/chemin/vers/nouveau/repertoire"
   }
   ```

3. **Vérifiez si le fichier existe réellement**:
   ```bash
   # Sur Linux/macOS/Windows
   ls -la /chemin/vers/fichier  # ou dir sur Windows
   ```
<!-- END_SECTION: access_issues -->

<!-- START_SECTION: operation_issues -->
## Problèmes d'opérations sur les fichiers

### Erreur lors de l'écriture dans un fichier

**Symptôme**: Erreur lors de l'utilisation de `write_file` ou `edit_file`.

**Solutions possibles**:

1. **Vérifiez les permissions d'écriture**:
   ```
   Outil: get_file_info
   Arguments:
   {
     "path": "/chemin/vers/fichier.txt"
   }
   ```

2. **Vérifiez si le fichier est verrouillé par un autre processus**:
   - Fermez toutes les applications qui pourraient utiliser le fichier
   - Sur Windows, utilisez `handle` ou `Process Explorer` pour identifier les processus qui utilisent le fichier

3. **Créez d'abord les répertoires parents**:
   ```
   Outil: create_directory
   Arguments:
   {
     "path": "/chemin/vers/nouveau/repertoire"
   }
   ```

4. **Utilisez `edit_file` avec `dryRun: true`** pour tester les modifications:
   ```
   Outil: edit_file
   Arguments:
   {
     "path": "/chemin/vers/fichier.txt",
     "edits": [
       {
         "oldText": "texte à remplacer",
         "newText": "nouveau texte"
       }
     ],
     "dryRun": true
   }
   ```

### Problèmes avec `edit_file`

**Symptôme**: Les modifications avec `edit_file` ne sont pas appliquées correctement.

**Solutions possibles**:

1. **Vérifiez que le texte à remplacer correspond exactement**:
   - Le texte à remplacer doit correspondre exactement, y compris les espaces, tabulations et sauts de ligne
   - Utilisez `read_file` pour obtenir le contenu exact du fichier

2. **Problèmes d'encodage**:
   - Assurez-vous que le fichier est encodé en UTF-8
   - Évitez les caractères spéciaux ou utilisez des séquences d'échappement appropriées

3. **Fichier trop grand**:
   - Divisez les modifications en plusieurs opérations plus petites
   - Utilisez `write_file` pour les fichiers très grands si nécessaire

### Erreur "File too large"

**Symptôme**: Erreur indiquant que le fichier est trop grand lors de la lecture ou de l'écriture.

**Solutions possibles**:

1. **Utilisez des extraits de fichier** avec `read_multiple_files`:
   ```
   Outil: read_multiple_files
   Arguments:
   {
     "paths": [
       {
         "path": "/chemin/vers/grand_fichier.log",
         "excerpts": [
           {
             "start": 1,
             "end": 100
           }
         ]
       }
     ]
   }
   ```

2. **Augmentez les limites de taille** dans la configuration:
   ```json
   "args": [
     "-y",
     "@modelcontextprotocol/server-filesystem",
     "--max-file-size=100mb",
     "--max-read-size=50mb",
     "/chemin/vers/repertoire"
   ]
   ```

3. **Divisez le fichier** en plusieurs fichiers plus petits:
   ```bash
   # Sur Linux/macOS
   split -b 10m /chemin/vers/grand_fichier.log /chemin/vers/fichier_partie_
   ```
<!-- END_SECTION: operation_issues -->

<!-- START_SECTION: performance_issues -->
## Problèmes de performance

### Opérations lentes sur les fichiers

**Symptôme**: Les opérations sur les fichiers sont anormalement lentes.

**Solutions possibles**:

1. **Utilisez `read_multiple_files`** au lieu de plusieurs appels à `read_file`:
   ```
   Outil: read_multiple_files
   Arguments:
   {
     "paths": [
       "/chemin/vers/fichier1.txt",
       "/chemin/vers/fichier2.txt"
     ]
   }
   ```

2. **Limitez la profondeur de récursion** pour `directory_tree` et `search_files`:
   ```
   Outil: directory_tree
   Arguments:
   {
     "path": "/chemin/vers/repertoire",
     "maxDepth": 3
   }
   ```

3. **Utilisez des motifs d'exclusion** pour `search_files`:
   ```
   Outil: search_files
   Arguments:
   {
     "path": "/chemin/vers/repertoire",
     "pattern": "*.js",
     "excludePatterns": ["node_modules", "dist", ".git"]
   }
   ```

4. **Évitez les opérations sur des répertoires volumineux**:
   - Ciblez des sous-répertoires spécifiques plutôt que des répertoires racine
   - Utilisez des motifs de recherche plus spécifiques

### Problèmes de mémoire

**Symptôme**: Erreurs de mémoire ou ralentissements importants lors de l'utilisation du MCP Filesystem.

**Solutions possibles**:

1. **Limitez la taille des fichiers** lus ou écrits:
   ```json
   "args": [
     "-y",
     "@modelcontextprotocol/server-filesystem",
     "--max-file-size=10mb",
     "--max-read-size=5mb",
     "/chemin/vers/repertoire"
   ]
   ```

2. **Utilisez des extraits de fichier** pour les grands fichiers:
   ```
   Outil: read_multiple_files
   Arguments:
   {
     "paths": [
       {
         "path": "/chemin/vers/grand_fichier.log",
         "excerpts": [
           {
             "start": 1000,
             "end": 2000
           }
         ]
       }
     ]
   }
   ```

3. **Redémarrez le serveur MCP** régulièrement:
   - Désactivez et réactivez le serveur MCP dans Roo
   - Redémarrez VS Code pour libérer la mémoire
<!-- END_SECTION: performance_issues -->

<!-- START_SECTION: security_issues -->
## Problèmes de sécurité

### Accès non autorisé aux fichiers

**Symptôme**: Le MCP Filesystem accède à des fichiers qui ne devraient pas être accessibles.

**Solutions possibles**:

1. **Limitez strictement les répertoires autorisés**:
   ```json
   "args": [
     "-y",
     "@modelcontextprotocol/server-filesystem",
     "/chemin/vers/repertoire/specifique"
   ]
   ```

2. **Évitez d'autoriser l'accès à des répertoires sensibles**:
   - Ne pas inclure `/etc`, `/var`, `C:\Windows`, etc.
   - Créez des répertoires dédiés pour les opérations du MCP Filesystem

3. **Vérifiez régulièrement les répertoires autorisés**:
   ```
   Outil: list_allowed_directories
   Arguments: {}
   ```

### Problèmes de permissions

**Symptôme**: Problèmes liés aux permissions des fichiers créés ou modifiés.

**Solutions possibles**:

1. **Ajustez les permissions par défaut** (sur Linux/macOS):
   ```bash
   umask 022  # Permet la lecture pour tous, l'écriture uniquement pour le propriétaire
   ```

2. **Vérifiez les permissions après création**:
   ```
   Outil: get_file_info
   Arguments:
   {
     "path": "/chemin/vers/fichier.txt"
   }
   ```

3. **Utilisez des répertoires avec des permissions appropriées**:
   ```bash
   mkdir -p ~/roo-workspace
   chmod 750 ~/roo-workspace
   ```
<!-- END_SECTION: security_issues -->

<!-- START_SECTION: advanced_troubleshooting -->
## Dépannage avancé

### Déboguer le serveur MCP Filesystem

Pour déboguer le serveur MCP Filesystem:

1. **Démarrez le serveur en mode débogage**:
   ```bash
   npx @modelcontextprotocol/server-filesystem --debug --log-level=debug /chemin/vers/repertoire
   ```

2. **Examinez les logs**:
   - Les logs seront affichés dans la console
   - Recherchez les erreurs ou avertissements

3. **Utilisez des variables d'environnement de débogage**:
   ```bash
   export MCP_FILESYSTEM_DEBUG=true
   export MCP_FILESYSTEM_LOG_LEVEL=debug
   npx @modelcontextprotocol/server-filesystem /chemin/vers/repertoire
   ```

### Tester le serveur MCP manuellement

Pour tester le serveur MCP Filesystem sans Roo:

1. **Démarrez le serveur dans un terminal**:
   ```bash
   npx @modelcontextprotocol/server-filesystem /chemin/vers/repertoire
   ```

2. **Envoyez des requêtes manuelles**:
   - Utilisez un client MCP de test ou un script personnalisé
   - Envoyez des requêtes JSON formatées selon le protocole MCP

3. **Vérifiez la réponse du serveur**:
   - Assurez-vous que le serveur répond correctement aux requêtes
   - Vérifiez les erreurs ou les comportements inattendus
<!-- END_SECTION: advanced_troubleshooting -->

<!-- START_SECTION: common_errors -->
## Erreurs courantes

### "Error: ENOENT: no such file or directory"

**Cause**: Le fichier ou le répertoire spécifié n'existe pas.

**Solutions**:
- Vérifiez que le chemin est correct
- Créez le fichier ou le répertoire s'il n'existe pas
- Vérifiez les permissions du répertoire parent

### "Error: EACCES: permission denied"

**Cause**: Permissions insuffisantes pour accéder au fichier ou au répertoire.

**Solutions**:
- Vérifiez les permissions du fichier ou du répertoire
- Ajustez les permissions si nécessaire
- Exécutez VS Code avec des privilèges appropriés

### "Error: EISDIR: illegal operation on a directory"

**Cause**: Tentative d'effectuer une opération de fichier sur un répertoire.

**Solutions**:
- Vérifiez que le chemin pointe vers un fichier et non un répertoire
- Utilisez les outils appropriés pour les répertoires (`list_directory`, `create_directory`, etc.)

### "Error: ENOTDIR: not a directory"

**Cause**: Tentative d'effectuer une opération de répertoire sur un fichier.

**Solutions**:
- Vérifiez que le chemin pointe vers un répertoire et non un fichier
- Utilisez les outils appropriés pour les fichiers (`read_file`, `write_file`, etc.)

### "Error: EBUSY: resource busy or locked"

**Cause**: Le fichier est utilisé par un autre processus.

**Solutions**:
- Fermez toutes les applications qui pourraient utiliser le fichier
- Attendez que le fichier soit libéré
- Redémarrez VS Code ou votre ordinateur si nécessaire
<!-- END_SECTION: common_errors -->

<!-- START_SECTION: getting_help -->
## Obtenir de l'aide

Si vous ne parvenez pas à résoudre votre problème avec les solutions ci-dessus:

1. **Consultez la documentation officielle**:
   - [Documentation du Model Context Protocol](https://github.com/modelcontextprotocol/mcp)
   - [Documentation de Roo](https://docs.roo.ai)

2. **Communauté et forums**:
   - [Forum de la communauté Roo](https://community.roo.ai)
   - [GitHub Issues du MCP Filesystem](https://github.com/modelcontextprotocol/servers/issues)

3. **Signaler un bug**:
   - Ouvrez une issue sur le dépôt GitHub du MCP Filesystem
   - Incluez des informations détaillées sur le problème, les étapes pour le reproduire et les logs pertinents
<!-- END_SECTION: getting_help -->