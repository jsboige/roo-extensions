# Résolution des problèmes du MCP Win-CLI

<!-- START_SECTION: introduction -->
## Introduction

Ce document fournit des solutions aux problèmes courants rencontrés lors de l'utilisation du MCP Win-CLI avec Roo. Si vous rencontrez des difficultés, consultez les sections ci-dessous pour trouver des solutions.
<!-- END_SECTION: introduction -->

<!-- START_SECTION: installation_issues -->
## Problèmes d'installation

### Le serveur ne démarre pas

**Symptôme**: Le serveur MCP Win-CLI ne démarre pas ou se termine immédiatement après le démarrage.

**Solutions possibles**:

1. **Vérifiez que Node.js est correctement installé**:
   ```bash
   node --version
   ```
   Assurez-vous d'utiliser Node.js v16.0.0 ou supérieur.

2. **Vérifiez que npm est correctement installé**:
   ```bash
   npm --version
   ```

3. **Problèmes de permissions**:
   - Sur Windows, exécutez PowerShell ou CMD en tant qu'administrateur
   - Vérifiez que vous avez les droits d'écriture dans le répertoire d'installation

4. **Réinstallez le package**:
   ```bash
   npm uninstall -g @simonb97/server-win-cli
   npm cache clean --force
   npm install -g @simonb97/server-win-cli
   ```

5. **Vérifiez les journaux d'erreur**:
   - Examinez la sortie de la console pour les messages d'erreur
   - Activez le mode débogage avec l'option `--debug`

### Erreurs lors de l'installation

**Symptôme**: Erreurs lors de l'installation du package `@simonb97/server-win-cli`.

**Solutions possibles**:

1. **Erreurs de dépendances**:
   ```bash
   npm cache clean --force
   npm install -g @simonb97/server-win-cli
   ```

2. **Problèmes de réseau**:
   - Vérifiez votre connexion Internet
   - Si vous êtes derrière un proxy, configurez npm pour l'utiliser:
     ```bash
     npm config set proxy http://proxy.example.com:8080
     npm config set https-proxy http://proxy.example.com:8080
     ```

3. **Problèmes de permissions**:
   - Sur Windows, exécutez PowerShell ou CMD en tant qu'administrateur
   - Vérifiez les permissions du répertoire npm global:
     ```bash
     npm config get prefix
     ```
<!-- END_SECTION: installation_issues -->

<!-- START_SECTION: configuration_issues -->
## Problèmes de configuration

### Le serveur n'est pas détecté par Roo

**Symptôme**: Le serveur MCP Win-CLI démarre mais n'est pas détecté par Roo.

**Solutions possibles**:

1. **Vérifiez la configuration dans Roo**:
   - Assurez-vous que le nom du serveur est correctement défini comme `win-cli`
   - Vérifiez que la commande et les arguments sont corrects
   - Assurez-vous que le serveur est activé (`disabled: false`)

2. **Problèmes de chemin**:
   - Assurez-vous que les chemins dans la configuration sont absolus et corrects
   - Sur Windows, utilisez des doubles barres obliques inverses (`\\`) ou des barres obliques simples (`/`) dans les chemins

3. **Redémarrez VS Code**:
   - Fermez et redémarrez VS Code pour recharger la configuration MCP

4. **Vérifiez les journaux de Roo**:
   - Examinez les journaux de Roo pour voir s'il y a des erreurs de connexion au serveur MCP

### Problèmes avec le fichier de configuration

**Symptôme**: Le serveur ne prend pas en compte votre configuration personnalisée.

**Solutions possibles**:

1. **Vérifiez le chemin du fichier de configuration**:
   - Assurez-vous que le fichier est à l'emplacement correct:
     - Windows: `%USERPROFILE%\.win-cli-server\config.json`

2. **Vérifiez la syntaxe JSON**:
   - Assurez-vous que votre fichier JSON est valide
   - Utilisez un validateur JSON en ligne pour vérifier la syntaxe

3. **Créez le répertoire parent si nécessaire**:
   ```bash
   mkdir "%USERPROFILE%\.win-cli-server"
   ```

4. **Réinitialisez la configuration**:
   - Supprimez le fichier de configuration existant
   - Redémarrez le serveur pour générer un nouveau fichier de configuration par défaut
<!-- END_SECTION: configuration_issues -->

<!-- START_SECTION: shell_issues -->
## Problèmes avec les shells

### PowerShell ne fonctionne pas correctement

**Symptôme**: Les commandes PowerShell échouent ou ne s'exécutent pas comme prévu.

**Solutions possibles**:

1. **Vérifiez la politique d'exécution PowerShell**:
   ```powershell
   Get-ExecutionPolicy
   ```
   Si la politique est restrictive, modifiez-la temporairement:
   ```powershell
   Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
   ```

2. **Vérifiez le chemin de PowerShell**:
   ```bash
   where powershell
   ```
   Assurez-vous que le chemin correspond à celui dans votre configuration.

3. **Problèmes avec les caractères spéciaux**:
   - Échappez correctement les caractères spéciaux dans les commandes PowerShell
   - Utilisez des guillemets simples pour les chaînes littérales et des guillemets doubles pour les chaînes avec variables

4. **Problèmes de profil PowerShell**:
   - Utilisez l'option `-NoProfile` pour éviter les problèmes liés au profil utilisateur
   - Vérifiez si des erreurs apparaissent lors du chargement du profil

### CMD ne fonctionne pas correctement

**Symptôme**: Les commandes CMD échouent ou ne s'exécutent pas comme prévu.

**Solutions possibles**:

1. **Vérifiez le chemin de CMD**:
   ```bash
   where cmd
   ```
   Assurez-vous que le chemin correspond à celui dans votre configuration.

2. **Problèmes avec les caractères spéciaux**:
   - Échappez correctement les caractères spéciaux dans les commandes CMD
   - Utilisez `^` pour échapper les caractères spéciaux

3. **Problèmes d'encodage**:
   - Utilisez l'option `/U` pour forcer l'encodage Unicode
   - Vérifiez la page de code active avec `chcp`

### Git Bash ne fonctionne pas correctement

**Symptôme**: Les commandes Git Bash échouent ou ne s'exécutent pas comme prévu.

**Solutions possibles**:

1. **Vérifiez que Git Bash est installé**:
   - Vérifiez si le fichier `bash.exe` existe à l'emplacement spécifié dans la configuration

2. **Vérifiez le chemin de Git Bash**:
   - Le chemin par défaut est généralement `C:\Program Files\Git\bin\bash.exe`
   - Si Git est installé à un autre emplacement, mettez à jour la configuration

3. **Problèmes avec les chemins Windows**:
   - Git Bash utilise des chemins de style Unix, convertissez les chemins Windows si nécessaire
   - Utilisez `/c/Users/...` au lieu de `C:\Users\...`
<!-- END_SECTION: shell_issues -->

<!-- START_SECTION: command_issues -->
## Problèmes d'exécution de commandes

### Les commandes échouent avec des erreurs

**Symptôme**: Les commandes échouent avec des messages d'erreur.

**Solutions possibles**:

1. **Vérifiez la syntaxe de la commande**:
   - Assurez-vous que la commande est correctement formatée pour le shell utilisé
   - Vérifiez les espaces, guillemets et caractères spéciaux

2. **Problèmes de permissions**:
   - Vérifiez que vous avez les permissions nécessaires pour exécuter la commande
   - Certaines commandes nécessitent des privilèges d'administrateur

3. **Problèmes de chemin**:
   - Utilisez des chemins absolus plutôt que relatifs
   - Vérifiez que les fichiers et répertoires référencés existent

4. **Commandes bloquées**:
   - Vérifiez si la commande est dans la liste des commandes bloquées dans la configuration
   - Modifiez la configuration pour autoriser la commande si nécessaire

### Les séparateurs de commande ne fonctionnent pas

**Symptôme**: Les séparateurs de commande comme `;` ou `&&` ne fonctionnent pas.

**Solutions possibles**:

1. **Vérifiez la configuration des séparateurs**:
   - Assurez-vous que le séparateur que vous utilisez est dans la liste `commandSeparators`
   - Vérifiez que `allowCommandChaining` est défini sur `true`

2. **Utilisez le bon séparateur pour le shell**:
   - PowerShell: `;`
   - CMD: `&` ou `&&`
   - Git Bash: `;` ou `&&`

3. **Échappez correctement les séparateurs**:
   - Dans certains cas, les séparateurs doivent être échappés
   - Utilisez des guillemets autour des commandes complexes

### Les commandes longues sont tronquées

**Symptôme**: Les commandes longues sont tronquées ou ne s'exécutent pas complètement.

**Solutions possibles**:

1. **Divisez les commandes longues**:
   - Utilisez plusieurs commandes plus courtes au lieu d'une seule commande longue
   - Utilisez des séparateurs de commande pour chaîner les commandes

2. **Utilisez des fichiers de script**:
   - Créez un fichier de script (.ps1, .bat, .sh) contenant les commandes
   - Exécutez le script au lieu des commandes directement

3. **Augmentez la limite de longueur de commande**:
   - Pour CMD, utilisez un fichier batch avec `@echo off` en première ligne
   - Pour PowerShell, utilisez un script .ps1
<!-- END_SECTION: command_issues -->

<!-- START_SECTION: ssh_issues -->
## Problèmes SSH

### Échec de connexion SSH

**Symptôme**: Les connexions SSH échouent avec des erreurs d'authentification ou de connexion.

**Solutions possibles**:

1. **Vérifiez les informations de connexion**:
   - Assurez-vous que l'hôte, le port, le nom d'utilisateur et le mot de passe sont corrects
   - Vérifiez que le serveur SSH est accessible depuis votre réseau

2. **Problèmes d'authentification par clé**:
   - Vérifiez que le chemin vers la clé privée est correct
   - Assurez-vous que la clé privée a les bonnes permissions
   - Vérifiez que la clé publique est correctement installée sur le serveur distant

3. **Problèmes de format de clé**:
   - Assurez-vous que la clé est au format OpenSSH
   - Convertissez la clé si nécessaire:
     ```bash
     ssh-keygen -p -m PEM -f /chemin/vers/cle
     ```

4. **Problèmes de phrase de passe**:
   - Assurez-vous que la phrase de passe est correcte
   - Si vous n'utilisez pas de phrase de passe, assurez-vous que le champ est vide ou null

### Échec d'exécution de commandes SSH

**Symptôme**: Les commandes SSH échouent ou ne renvoient pas de résultat.

**Solutions possibles**:

1. **Vérifiez que la connexion est établie**:
   - Utilisez `read_ssh_connections` pour vérifier l'état de la connexion
   - Reconnectez-vous si nécessaire

2. **Problèmes de permissions sur le serveur distant**:
   - Vérifiez que l'utilisateur a les permissions nécessaires pour exécuter la commande
   - Utilisez `sudo` si nécessaire (et si l'utilisateur en a le droit)

3. **Problèmes de shell distant**:
   - Certaines commandes peuvent nécessiter un shell interactif
   - Utilisez des commandes compatibles avec un shell non interactif
<!-- END_SECTION: ssh_issues -->

<!-- START_SECTION: performance_issues -->
## Problèmes de performance

### Le serveur est lent à répondre

**Symptôme**: Le serveur MCP Win-CLI prend beaucoup de temps pour répondre aux requêtes.

**Solutions possibles**:

1. **Réduisez la taille de l'historique des commandes**:
   ```json
   "history": {
     "maxEntries": 50
   }
   ```

2. **Désactivez les fonctionnalités non utilisées**:
   - Désactivez SSH si vous ne l'utilisez pas
   - Réduisez le niveau de journalisation

3. **Vérifiez les ressources système**:
   - Assurez-vous que votre système a suffisamment de mémoire et de CPU disponibles
   - Fermez les applications inutilisées

### Consommation excessive de ressources

**Symptôme**: Le serveur MCP Win-CLI consomme beaucoup de CPU ou de mémoire.

**Solutions possibles**:

1. **Limitez le nombre de connexions SSH simultanées**:
   - Fermez les connexions SSH inutilisées avec `ssh_disconnect`

2. **Évitez les commandes qui génèrent beaucoup de sortie**:
   - Filtrez la sortie des commandes (par exemple, utilisez `| Select-Object -First 10` en PowerShell)
   - Utilisez des commandes plus spécifiques

3. **Redémarrez régulièrement le serveur**:
   - Si le serveur est utilisé pendant de longues périodes, redémarrez-le périodiquement
<!-- END_SECTION: performance_issues -->

<!-- START_SECTION: common_errors -->
## Erreurs courantes

### "Command not allowed"

**Cause**: La commande que vous essayez d'exécuter est bloquée par la configuration de sécurité.

**Solutions**:
- Vérifiez la liste des commandes autorisées dans la configuration
- Modifiez la configuration pour autoriser la commande si nécessaire
- Utilisez une commande alternative qui est autorisée

### "Command separator not allowed"

**Cause**: Le séparateur de commande que vous utilisez n'est pas autorisé par la configuration.

**Solutions**:
- Vérifiez la liste des séparateurs autorisés dans la configuration
- Modifiez la configuration pour autoriser le séparateur si nécessaire
- Utilisez un séparateur autorisé ou divisez la commande en plusieurs appels

### "Shell not found"

**Cause**: Le shell spécifié n'est pas trouvé ou n'est pas configuré correctement.

**Solutions**:
- Vérifiez que le shell est correctement installé
- Vérifiez le chemin du shell dans la configuration
- Utilisez un shell différent qui est disponible

### "Working directory not found"

**Cause**: Le répertoire de travail spécifié n'existe pas ou n'est pas accessible.

**Solutions**:
- Vérifiez que le répertoire existe
- Vérifiez les permissions du répertoire
- Utilisez un répertoire différent ou créez le répertoire s'il n'existe pas

### "SSH connection failed"

**Cause**: La connexion SSH a échoué en raison de problèmes d'authentification ou de réseau.

**Solutions**:
- Vérifiez les informations de connexion
- Vérifiez que le serveur SSH est accessible
- Vérifiez les clés SSH ou les mots de passe
<!-- END_SECTION: common_errors -->

<!-- START_SECTION: advanced_troubleshooting -->
## Dépannage avancé

### Débogage du serveur

Pour déboguer le serveur MCP Win-CLI:

1. **Démarrez le serveur en mode débogage**:
   ```bash
   npx -y @simonb97/server-win-cli --debug
   ```

2. **Activez la journalisation détaillée**:
   ```json
   "logging": {
     "level": "debug",
     "file": "win-cli-server.log"
   }
   ```

3. **Examinez les journaux**:
   - Recherchez les erreurs ou avertissements
   - Suivez le flux d'exécution des commandes

### Analyse des problèmes de communication

Si vous rencontrez des problèmes de communication entre Roo et le serveur MCP Win-CLI:

1. **Vérifiez que le serveur est en cours d'exécution**:
   - Vérifiez les processus en cours d'exécution
   - Vérifiez que le serveur écoute sur le port attendu

2. **Vérifiez la configuration de transport**:
   - Assurez-vous que `transportType` est défini sur `stdio` dans la configuration de Roo
   - Vérifiez que la commande et les arguments sont corrects

3. **Testez la communication directement**:
   - Créez un script simple qui communique avec le serveur MCP
   - Vérifiez si le serveur répond correctement

### Réinitialisation complète

Si tous les autres dépannages échouent, vous pouvez essayer une réinitialisation complète:

1. **Désinstallez le serveur MCP Win-CLI**:
   ```bash
   npm uninstall -g @simonb97/server-win-cli
   ```

2. **Supprimez les fichiers de configuration**:
   ```bash
   rmdir /s /q "%USERPROFILE%\.win-cli-server"
   ```

3. **Supprimez la configuration dans Roo**:
   - Modifiez le fichier `mcp_settings.json` pour supprimer la configuration du serveur Win-CLI

4. **Réinstallez le serveur et reconfigurez-le**:
   - Suivez les instructions d'installation et de configuration depuis le début
<!-- END_SECTION: advanced_troubleshooting -->

<!-- START_SECTION: getting_help -->
## Obtenir de l'aide

Si vous ne parvenez pas à résoudre votre problème avec les solutions ci-dessus:

1. **Consultez la documentation officielle**:
   - [Dépôt GitHub de Win-CLI MCP](https://github.com/simonb97/server-win-cli)
   - [Documentation NPM](https://www.npmjs.com/package/@simonb97/server-win-cli)

2. **Communauté et forums**:
   - [Forum de la communauté Roo](https://community.roo.ai)
   - [GitHub Issues de Win-CLI MCP](https://github.com/simonb97/server-win-cli/issues)

3. **Signaler un bug**:
   - Ouvrez une issue sur le dépôt GitHub du MCP Win-CLI
   - Incluez des informations détaillées sur le problème, les étapes pour le reproduire et les logs pertinents
<!-- END_SECTION: getting_help -->