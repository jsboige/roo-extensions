# Résolution des problèmes du MCP Git

<!-- START_SECTION: introduction -->
## Introduction

Ce document fournit des solutions aux problèmes courants rencontrés lors de l'utilisation du MCP Git avec Roo. Si vous rencontrez des difficultés, consultez les sections ci-dessous pour trouver des solutions.
<!-- END_SECTION: introduction -->

<!-- START_SECTION: installation_issues -->
## Problèmes d'installation

### Le package ne s'installe pas correctement

**Symptôme**: Erreurs lors de l'installation du package `@modelcontextprotocol/server-git`.

**Solutions possibles**:

1. **Vérifiez la version de Node.js**:
   ```bash
   node --version
   ```
   Assurez-vous d'utiliser Node.js v14.0.0 ou supérieur.

2. **Vérifiez la version de Git**:
   ```bash
   git --version
   ```
   Assurez-vous d'utiliser Git v2.20.0 ou supérieur.

3. **Mettez à jour npm**:
   ```bash
   npm install -g npm@latest
   ```

4. **Problèmes de permissions**:
   - Sur Linux/macOS:
     ```bash
     sudo npm install -g @modelcontextprotocol/server-git
     ```
   - Sur Windows, exécutez PowerShell en tant qu'administrateur

5. **Problèmes de dépendances**:
   ```bash
   npm cache clean --force
   npm install -g @modelcontextprotocol/server-git
   ```

### Git n'est pas trouvé dans le PATH

**Symptôme**: Le serveur MCP Git ne démarre pas avec une erreur indiquant que Git n'est pas trouvé.

**Solutions possibles**:

1. **Vérifiez que Git est installé**:
   ```bash
   git --version
   ```

2. **Vérifiez le chemin de Git**:
   ```bash
   # Sur Linux/macOS
   which git
   
   # Sur Windows
   where git
   ```

3. **Ajoutez Git au PATH**:
   - Sur Windows:
     1. Recherchez "Variables d'environnement" dans le menu Démarrer
     2. Cliquez sur "Modifier les variables d'environnement système"
     3. Cliquez sur "Variables d'environnement"
     4. Sélectionnez "Path" dans les variables système et cliquez sur "Modifier"
     5. Ajoutez le chemin vers le répertoire bin de Git (par exemple, `C:\Program Files\Git\bin`)
     6. Cliquez sur "OK" pour fermer toutes les fenêtres
   
   - Sur Linux/macOS:
     ```bash
     echo 'export PATH="/usr/local/bin:$PATH"' >> ~/.bashrc
     source ~/.bashrc
     ```

4. **Redémarrez votre terminal** ou votre ordinateur après avoir modifié le PATH
<!-- END_SECTION: installation_issues -->

<!-- START_SECTION: configuration_issues -->
## Problèmes de configuration

### Le serveur MCP ne se connecte pas à Roo

**Symptôme**: Le serveur MCP Git ne s'affiche pas comme connecté dans Roo.

**Solutions possibles**:

1. **Vérifiez la configuration MCP**:
   - Assurez-vous que le fichier de configuration MCP contient l'entrée correcte pour le MCP Git
   - Vérifiez que le chemin vers le fichier de configuration est correct

2. **Vérifiez que le serveur MCP est correctement lancé**:
   ```bash
   npx @modelcontextprotocol/server-git --debug
   ```
   Vérifiez s'il y a des erreurs dans la sortie.

3. **Redémarrez VS Code**:
   - Fermez et redémarrez VS Code pour recharger la configuration MCP

### Erreur "Git executable not found"

**Symptôme**: Le serveur MCP Git démarre mais affiche une erreur indiquant que l'exécutable Git n'est pas trouvé.

**Solutions possibles**:

1. **Spécifiez explicitement le chemin vers Git**:
   ```json
   "env": {
     "GIT_EXEC_PATH": "/chemin/vers/git"
   }
   ```

2. **Vérifiez que Git est accessible**:
   ```bash
   git --version
   ```

3. **Réinstallez Git** et assurez-vous qu'il est ajouté au PATH
<!-- END_SECTION: configuration_issues -->

<!-- START_SECTION: authentication_issues -->
## Problèmes d'authentification

### Erreur d'authentification avec les dépôts distants

**Symptôme**: Erreurs lors des opérations `push`, `pull` ou `clone` avec des dépôts distants.

**Solutions possibles**:

1. **Vérifiez vos informations d'identification Git**:
   ```bash
   git config --list | grep user
   ```

2. **Configurez l'authentification HTTPS**:
   ```bash
   # Sur Windows
   git config --global credential.helper wincred
   
   # Sur macOS
   git config --global credential.helper osxkeychain
   
   # Sur Linux
   git config --global credential.helper store
   ```

3. **Utilisez SSH au lieu de HTTPS**:
   ```bash
   # Générez une clé SSH si vous n'en avez pas
   ssh-keygen -t ed25519 -C "votre.email@exemple.com"
   
   # Ajoutez la clé à votre agent SSH
   ssh-add ~/.ssh/id_ed25519
   
   # Affichez la clé publique pour l'ajouter à GitHub/GitLab/etc.
   cat ~/.ssh/id_ed25519.pub
   
   # Modifiez l'URL du dépôt distant
   git remote set-url origin git@github.com:utilisateur/depot.git
   ```

4. **Utilisez un jeton d'accès personnel** pour GitHub/GitLab:
   - Créez un jeton d'accès personnel sur la plateforme Git
   - Utilisez le jeton comme mot de passe lors de l'authentification

### Problèmes avec les clés SSH

**Symptôme**: Erreurs d'authentification lors de l'utilisation de SSH.

**Solutions possibles**:

1. **Vérifiez que votre clé SSH est ajoutée à l'agent SSH**:
   ```bash
   ssh-add -l
   ```

2. **Vérifiez la connexion SSH**:
   ```bash
   ssh -T git@github.com
   ```

3. **Vérifiez les permissions des fichiers SSH** (sur Linux/macOS):
   ```bash
   chmod 600 ~/.ssh/id_ed25519
   chmod 644 ~/.ssh/id_ed25519.pub
   ```

4. **Utilisez un fichier de configuration SSH** pour gérer plusieurs clés:
   ```bash
   # Créez ou modifiez ~/.ssh/config
   Host github.com
     IdentityFile ~/.ssh/id_ed25519_github
     User git
   
   Host gitlab.com
     IdentityFile ~/.ssh/id_ed25519_gitlab
     User git
   ```
<!-- END_SECTION: authentication_issues -->

<!-- START_SECTION: operation_issues -->
## Problèmes d'opérations Git

### Erreurs lors des commits

**Symptôme**: Erreurs lors de la création de commits.

**Solutions possibles**:

1. **Vérifiez votre configuration Git**:
   ```bash
   git config --list | grep user
   ```
   Assurez-vous que `user.name` et `user.email` sont configurés.

2. **Vérifiez que des fichiers sont ajoutés à l'index**:
   ```
   Outil: status
   Arguments:
   {
     "path": "/chemin/vers/depot"
   }
   ```
   Assurez-vous qu'il y a des modifications à committer.

3. **Ajoutez des fichiers à l'index avant de committer**:
   ```
   Outil: add
   Arguments:
   {
     "path": "/chemin/vers/depot",
     "files": [
       "/chemin/vers/depot/fichier.txt"
     ]
   }
   ```

### Erreurs lors des push

**Symptôme**: Erreurs lors du push vers un dépôt distant.

**Solutions possibles**:

1. **Vérifiez que vous avez des commits à pousser**:
   ```
   Outil: status
   Arguments:
   {
     "path": "/chemin/vers/depot"
   }
   ```

2. **Récupérez d'abord les modifications distantes**:
   ```
   Outil: pull
   Arguments:
   {
     "path": "/chemin/vers/depot",
     "remote": "origin",
     "branch": "main"
   }
   ```

3. **Utilisez l'option `force` avec précaution** si nécessaire:
   ```
   Outil: push
   Arguments:
   {
     "path": "/chemin/vers/depot",
     "remote": "origin",
     "branch": "main",
     "force": true
   }
   ```
   > **Attention**: L'option `force` peut écraser des modifications distantes. Utilisez-la avec prudence.

### Erreurs lors des pull

**Symptôme**: Erreurs lors du pull depuis un dépôt distant.

**Solutions possibles**:

1. **Vérifiez que vous n'avez pas de modifications non commitées**:
   ```
   Outil: status
   Arguments:
   {
     "path": "/chemin/vers/depot"
   }
   ```

2. **Sauvegardez vos modifications dans un stash si nécessaire**:
   ```
   Outil: stash_save
   Arguments:
   {
     "path": "/chemin/vers/depot",
     "message": "Modifications en cours"
   }
   ```

3. **Utilisez l'option `--allow-unrelated-histories`** si vous fusionnez des historiques non liés:
   ```bash
   cd /chemin/vers/depot
   git pull origin main --allow-unrelated-histories
   ```
<!-- END_SECTION: operation_issues -->

<!-- START_SECTION: merge_conflicts -->
## Conflits de fusion

### Résolution des conflits de fusion

**Symptôme**: Erreurs de conflit lors d'un merge, pull ou rebase.

**Solutions possibles**:

1. **Identifiez les fichiers en conflit**:
   ```
   Outil: status
   Arguments:
   {
     "path": "/chemin/vers/depot"
   }
   ```

2. **Résolvez les conflits manuellement**:
   - Ouvrez les fichiers en conflit dans un éditeur
   - Recherchez les marqueurs de conflit (`<<<<<<<`, `=======`, `>>>>>>>`)
   - Modifiez le fichier pour résoudre le conflit
   - Supprimez les marqueurs de conflit

3. **Marquez les conflits comme résolus**:
   ```
   Outil: add
   Arguments:
   {
     "path": "/chemin/vers/depot",
     "files": [
       "/chemin/vers/depot/fichier_en_conflit.txt"
     ]
   }
   ```

4. **Terminez la fusion**:
   ```
   Outil: commit
   Arguments:
   {
     "path": "/chemin/vers/depot",
     "message": "Résolution des conflits de fusion"
   }
   ```

### Annulation d'une fusion en cours

**Symptôme**: Vous souhaitez annuler une fusion en cours avec des conflits.

**Solutions possibles**:

1. **Annulez la fusion**:
   ```bash
   cd /chemin/vers/depot
   git merge --abort
   ```

2. **Annulez un rebase**:
   ```bash
   cd /chemin/vers/depot
   git rebase --abort
   ```

3. **Annulez un pull avec fusion**:
   ```bash
   cd /chemin/vers/depot
   git reset --hard HEAD
   ```
   > **Attention**: Cette commande annule toutes les modifications non commitées.
<!-- END_SECTION: merge_conflicts -->

<!-- START_SECTION: branch_issues -->
## Problèmes de branches

### Erreur "Branch not found"

**Symptôme**: Erreur indiquant que la branche spécifiée n'existe pas.

**Solutions possibles**:

1. **Vérifiez les branches disponibles**:
   ```
   Outil: branch_list
   Arguments:
   {
     "path": "/chemin/vers/depot"
   }
   ```

2. **Créez la branche si elle n'existe pas**:
   ```
   Outil: branch_create
   Arguments:
   {
     "path": "/chemin/vers/depot",
     "name": "nouvelle-branche"
   }
   ```

3. **Vérifiez si la branche existe sur le dépôt distant**:
   ```bash
   cd /chemin/vers/depot
   git fetch origin
   git branch -a
   ```

### Problèmes de suivi de branche

**Symptôme**: Les branches locales ne suivent pas correctement les branches distantes.

**Solutions possibles**:

1. **Configurez le suivi de branche**:
   ```bash
   cd /chemin/vers/depot
   git branch --set-upstream-to=origin/main main
   ```

2. **Créez une nouvelle branche avec suivi**:
   ```
   Outil: branch_create
   Arguments:
   {
     "path": "/chemin/vers/depot",
     "name": "nouvelle-branche",
     "track": true
   }
   ```

3. **Vérifiez la configuration de suivi**:
   ```bash
   cd /chemin/vers/depot
   git branch -vv
   ```
<!-- END_SECTION: branch_issues -->

<!-- START_SECTION: remote_issues -->
## Problèmes de dépôts distants

### Erreur "Remote not found"

**Symptôme**: Erreur indiquant que le dépôt distant spécifié n'existe pas.

**Solutions possibles**:

1. **Vérifiez les dépôts distants configurés**:
   ```
   Outil: remote_list
   Arguments:
   {
     "path": "/chemin/vers/depot"
   }
   ```

2. **Ajoutez le dépôt distant s'il n'existe pas**:
   ```
   Outil: remote_add
   Arguments:
   {
     "path": "/chemin/vers/depot",
     "name": "origin",
     "url": "https://github.com/utilisateur/depot.git"
   }
   ```

3. **Vérifiez l'URL du dépôt distant**:
   ```bash
   cd /chemin/vers/depot
   git remote -v
   ```

### Problèmes de connexion aux dépôts distants

**Symptôme**: Erreurs de connexion lors des opérations avec des dépôts distants.

**Solutions possibles**:

1. **Vérifiez votre connexion Internet**

2. **Vérifiez que l'URL du dépôt distant est correcte**:
   ```bash
   cd /chemin/vers/depot
   git remote -v
   ```

3. **Utilisez HTTPS au lieu de SSH** ou vice versa:
   ```bash
   # De SSH à HTTPS
   git remote set-url origin https://github.com/utilisateur/depot.git
   
   # De HTTPS à SSH
   git remote set-url origin git@github.com:utilisateur/depot.git
   ```

4. **Vérifiez les paramètres du proxy** si vous êtes derrière un proxy:
   ```bash
   git config --global http.proxy http://proxy.exemple.com:8080
   ```
<!-- END_SECTION: remote_issues -->

<!-- START_SECTION: performance_issues -->
## Problèmes de performance

### Opérations Git lentes

**Symptôme**: Les opérations Git sont anormalement lentes.

**Solutions possibles**:

1. **Nettoyez votre dépôt**:
   ```bash
   cd /chemin/vers/depot
   git gc --aggressive
   ```

2. **Utilisez des clones superficiels** pour les grands dépôts:
   ```bash
   git clone --depth 1 https://github.com/utilisateur/depot.git
   ```

3. **Utilisez des clones partiels** pour les monorepos:
   ```bash
   git clone --filter=blob:none https://github.com/utilisateur/depot.git
   ```

4. **Limitez le nombre de fichiers suivis**:
   - Utilisez des fichiers `.gitignore` appropriés
   - Excluez les répertoires volumineux comme `node_modules`

### Problèmes avec les grands fichiers

**Symptôme**: Problèmes de performance avec des dépôts contenant de grands fichiers.

**Solutions possibles**:

1. **Utilisez Git LFS** pour les grands fichiers:
   ```bash
   # Installation de Git LFS
   git lfs install
   
   # Suivi des grands fichiers
   git lfs track "*.psd"
   git lfs track "*.zip"
   
   # Ajout du fichier .gitattributes
   git add .gitattributes
   ```

2. **Nettoyez l'historique** des grands fichiers (avec précaution):
   ```bash
   git filter-branch --tree-filter 'rm -f grands-fichiers/*.zip' HEAD
   ```
   > **Attention**: Cette commande modifie l'historique Git. Utilisez-la avec prudence.

3. **Utilisez des sous-modules** pour les dépendances volumineuses:
   ```bash
   git submodule add https://github.com/utilisateur/grande-dependance.git
   ```
<!-- END_SECTION: performance_issues -->

<!-- START_SECTION: advanced_troubleshooting -->
## Dépannage avancé

### Déboguer le serveur MCP Git

Pour déboguer le serveur MCP Git:

1. **Démarrez le serveur en mode débogage**:
   ```bash
   npx @modelcontextprotocol/server-git --debug --log-level=debug
   ```

2. **Examinez les logs**:
   - Les logs seront affichés dans la console
   - Recherchez les erreurs ou avertissements

3. **Utilisez des variables d'environnement de débogage**:
   ```bash
   export MCP_GIT_DEBUG=true
   export MCP_GIT_LOG_LEVEL=debug
   npx @modelcontextprotocol/server-git
   ```

### Déboguer les opérations Git

Pour déboguer les opérations Git:

1. **Activez la journalisation Git**:
   ```bash
   export GIT_TRACE=1
   export GIT_CURL_VERBOSE=1
   ```

2. **Exécutez les commandes Git manuellement**:
   ```bash
   cd /chemin/vers/depot
   git status
   git remote -v
   git fetch --verbose
   ```

3. **Vérifiez la configuration Git**:
   ```bash
   git config --list
   ```

### Réinitialisation d'un dépôt corrompu

Si un dépôt Git est corrompu:

1. **Vérifiez l'intégrité du dépôt**:
   ```bash
   cd /chemin/vers/depot
   git fsck
   ```

2. **Essayez de réparer le dépôt**:
   ```bash
   git gc --aggressive
   git prune
   git fsck --full
   ```

3. **En dernier recours, clonez à nouveau le dépôt**:
   ```bash
   cd /chemin/vers/parent
   mv depot depot_backup
   git clone https://github.com/utilisateur/depot.git
   ```
<!-- END_SECTION: advanced_troubleshooting -->

<!-- START_SECTION: common_errors -->
## Erreurs courantes

### "fatal: not a git repository"

**Cause**: La commande Git est exécutée en dehors d'un dépôt Git.

**Solutions**:
- Vérifiez que vous êtes dans le bon répertoire
- Initialisez un dépôt Git si nécessaire avec `git init`
- Vérifiez que le chemin du dépôt est correct dans les arguments de l'outil

### "fatal: refusing to merge unrelated histories"

**Cause**: Tentative de fusion de deux dépôts sans historique commun.

**Solutions**:
- Utilisez l'option `--allow-unrelated-histories` avec `git pull`
- Créez un commit de fusion manuel
- Réinitialisez l'un des dépôts et recommencez

### "error: failed to push some refs"

**Cause**: Le dépôt distant contient des modifications que vous n'avez pas localement.

**Solutions**:
- Récupérez d'abord les modifications avec `git pull`
- Résolvez les conflits si nécessaire
- Utilisez `git push --force` avec précaution si vous êtes sûr de vouloir écraser les modifications distantes

### "fatal: remote origin already exists"

**Cause**: Tentative d'ajouter un dépôt distant avec un nom déjà utilisé.

**Solutions**:
- Utilisez un nom différent pour le nouveau dépôt distant
- Supprimez d'abord le dépôt distant existant avec `git remote remove origin`
- Mettez à jour l'URL du dépôt distant existant avec `git remote set-url origin nouvelle-url`

### "fatal: Authentication failed"

**Cause**: Informations d'identification incorrectes ou manquantes.

**Solutions**:
- Vérifiez vos informations d'identification
- Configurez un gestionnaire d'informations d'identification
- Utilisez SSH au lieu de HTTPS
- Utilisez un jeton d'accès personnel au lieu d'un mot de passe
<!-- END_SECTION: common_errors -->

<!-- START_SECTION: getting_help -->
## Obtenir de l'aide

Si vous ne parvenez pas à résoudre votre problème avec les solutions ci-dessus:

1. **Consultez la documentation officielle**:
   - [Documentation Git](https://git-scm.com/doc)
   - [Documentation du Model Context Protocol](https://github.com/modelcontextprotocol/mcp)
   - [Documentation de Roo](https://docs.roo.ai)

2. **Communauté et forums**:
   - [Forum de la communauté Roo](https://community.roo.ai)
   - [GitHub Issues du MCP Git](https://github.com/modelcontextprotocol/servers/issues)
   - [Stack Overflow - Tag Git](https://stackoverflow.com/questions/tagged/git)

3. **Signaler un bug**:
   - Ouvrez une issue sur le dépôt GitHub du MCP Git
   - Incluez des informations détaillées sur le problème, les étapes pour le reproduire et les logs pertinents
<!-- END_SECTION: getting_help -->