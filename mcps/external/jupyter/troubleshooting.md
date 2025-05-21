# Guide de dépannage du MCP Jupyter

Ce document fournit des solutions aux problèmes courants rencontrés lors de l'utilisation du MCP Jupyter, avec un accent particulier sur l'intégration avec VSCode.

## Table des matières

- [Guide de dépannage du MCP Jupyter](#guide-de-dépannage-du-mcp-jupyter)
  - [Table des matières](#table-des-matières)
  - [Problèmes de démarrage](#problèmes-de-démarrage)
    - [Le serveur MCP Jupyter ne démarre pas](#le-serveur-mcp-jupyter-ne-démarre-pas)
    - [Timeout lors du démarrage](#timeout-lors-du-démarrage)
    - [Erreur de port déjà utilisé](#erreur-de-port-déjà-utilisé)
  - [Problèmes de connexion](#problèmes-de-connexion)
    - [Erreur de connexion au serveur Jupyter](#erreur-de-connexion-au-serveur-jupyter)
    - [Erreur d'authentification (token invalide)](#erreur-dauthentification-token-invalide)
    - [Erreur "socket hang up"](#erreur-socket-hang-up)
  - [Problèmes spécifiques au mode VSCode](#problèmes-spécifiques-au-mode-vscode)
    - [Aucun kernel VSCode détecté](#aucun-kernel-vscode-détecté)
    - [Extensions VSCode manquantes](#extensions-vscode-manquantes)
    - [Erreur lors de l'exécution de code via VSCode](#erreur-lors-de-lexécution-de-code-via-vscode)
    - [Problèmes de détection des environnements Python](#problèmes-de-détection-des-environnements-python)
  - [Problèmes d'exécution de code](#problèmes-dexécution-de-code)
    - [Échec de l'exécution de code](#échec-de-lexécution-de-code)
    - [Dépendances manquantes](#dépendances-manquantes)
    - [Timeout lors de l'exécution](#timeout-lors-de-lexécution)
  - [Problèmes de configuration](#problèmes-de-configuration)
    - [Fichier de configuration corrompu](#fichier-de-configuration-corrompu)
    - [Erreur lors du chargement de la configuration](#erreur-lors-du-chargement-de-la-configuration)
  - [Outils de diagnostic](#outils-de-diagnostic)
    - [Scripts de test](#scripts-de-test)
    - [Logs du serveur](#logs-du-serveur)
    - [Vérification de la configuration](#vérification-de-la-configuration)
  - [Procédures de récupération](#procédures-de-récupération)
    - [Réinitialisation de la configuration](#réinitialisation-de-la-configuration)
    - [Nettoyage des kernels](#nettoyage-des-kernels)
    - [Réinstallation du MCP Jupyter](#réinstallation-du-mcp-jupyter)

## Problèmes de démarrage

### Le serveur MCP Jupyter ne démarre pas

**Symptômes**:
- Le script de démarrage se termine sans erreur, mais le serveur n'est pas accessible
- Message d'erreur indiquant que le serveur n'a pas pu démarrer

**Solutions**:
1. Vérifiez que Node.js est correctement installé et accessible dans le PATH
2. Vérifiez que le répertoire du MCP Jupyter existe et contient tous les fichiers nécessaires
3. Vérifiez les logs pour identifier d'éventuelles erreurs
4. Essayez de démarrer le serveur en mode hors ligne pour isoler les problèmes
5. Vérifiez que vous avez les droits d'accès nécessaires pour exécuter le script

### Timeout lors du démarrage

**Symptômes**:
- Le script de test ou le démarrage du serveur échoue avec un message de timeout
- Le serveur prend trop de temps à démarrer

**Solutions**:
1. Augmentez la valeur du timeout dans le script de test ou de démarrage
2. Vérifiez que le serveur Jupyter n'est pas déjà en cours d'exécution
3. Vérifiez les logs du serveur pour identifier d'éventuelles erreurs
4. Essayez de démarrer le serveur en mode hors ligne pour isoler les problèmes
5. Vérifiez que les ports utilisés ne sont pas déjà occupés par d'autres applications

### Erreur de port déjà utilisé

**Symptômes**:
- Message d'erreur indiquant que le port est déjà utilisé
- Le serveur ne démarre pas

**Solutions**:
1. Vérifiez si un autre processus utilise déjà le port configuré
   ```powershell
   netstat -ano | findstr :<port>
   ```
2. Arrêtez le processus qui utilise le port ou configurez le MCP Jupyter pour utiliser un autre port
3. Redémarrez votre ordinateur pour libérer tous les ports
4. Utilisez un port différent dans la configuration du MCP Jupyter

## Problèmes de connexion

### Erreur de connexion au serveur Jupyter

**Symptômes**:
- Message d'erreur indiquant que le serveur Jupyter n'est pas accessible
- Timeout lors de la tentative de connexion

**Solutions**:
1. Vérifiez que le serveur Jupyter est bien en cours d'exécution sur le port configuré
2. Vérifiez que l'URL du serveur Jupyter est correcte dans la configuration
3. Vérifiez que le pare-feu ne bloque pas la connexion
4. Essayez d'accéder directement à l'URL du serveur Jupyter dans un navigateur
5. Redémarrez le serveur Jupyter et le MCP Jupyter

### Erreur d'authentification (token invalide)

**Symptômes**:
- Message d'erreur indiquant que le token est invalide
- Erreur 403 Forbidden lors de la tentative de connexion

**Solutions**:
1. Vérifiez que le token dans la configuration correspond au token du serveur Jupyter
2. Récupérez le token correct à partir des logs du serveur Jupyter
3. Mettez à jour la configuration du MCP Jupyter avec le token correct
4. Redémarrez le MCP Jupyter pour appliquer les changements

### Erreur "socket hang up"

**Symptômes**:
- Message d'erreur "socket hang up" lors de la tentative de connexion
- La connexion est interrompue de manière inattendue

**Solutions**:
1. Vérifiez que le serveur Jupyter est toujours en cours d'exécution
2. Vérifiez que le réseau est stable
3. Augmentez les timeouts de connexion dans la configuration
4. Redémarrez le serveur Jupyter et le MCP Jupyter
5. Essayez d'utiliser le mode hors ligne pour isoler les problèmes

## Problèmes spécifiques au mode VSCode

### Aucun kernel VSCode détecté

**Symptômes**:
- Le script d'intégration VSCode ne trouve aucun kernel
- Message "Aucun kernel VSCode trouvé" dans les logs

**Solutions**:
1. Vérifiez que l'extension Python pour VSCode est installée
   ```
   %USERPROFILE%\.vscode\extensions\ms-python.python*
   ```
2. Vérifiez que l'extension Jupyter pour VSCode est installée
   ```
   %USERPROFILE%\.vscode\extensions\ms-toolsai.jupyter*
   ```
3. Créez au moins un environnement Python dans VSCode
4. Exécutez la commande "Python: Select Interpreter" dans VSCode pour configurer l'interpréteur
5. Vérifiez que les chemins d'accès aux extensions VSCode sont corrects dans le script `detect-vscode-kernels.ps1`
6. Redémarrez VSCode pour s'assurer que les extensions sont correctement chargées

### Extensions VSCode manquantes

**Symptômes**:
- Le script d'intégration VSCode ne trouve pas les extensions nécessaires
- Message d'erreur indiquant que les extensions ne sont pas trouvées

**Solutions**:
1. Installez l'extension Python pour VSCode depuis le marketplace
2. Installez l'extension Jupyter pour VSCode depuis le marketplace
3. Vérifiez que les extensions sont correctement installées
4. Redémarrez VSCode après l'installation des extensions
5. Vérifiez les chemins d'accès aux extensions dans le script `detect-vscode-kernels.ps1`

### Erreur lors de l'exécution de code via VSCode

**Symptômes**:
- L'exécution de code via le MCP Jupyter échoue
- Message d'erreur lors de l'exécution de code

**Solutions**:
1. Vérifiez que le kernel VSCode est correctement configuré
2. Vérifiez que l'environnement Python sélectionné dans VSCode est fonctionnel
3. Essayez d'exécuter le même code directement dans VSCode pour isoler le problème
4. Vérifiez que les dépendances nécessaires sont installées dans l'environnement Python
5. Redémarrez le serveur MCP Jupyter avec le script `start-jupyter-mcp-vscode.bat`

### Problèmes de détection des environnements Python

**Symptômes**:
- Aucun environnement Python n'est détecté par VSCode
- Le kernel Python n'est pas disponible dans le MCP Jupyter

**Solutions**:
1. Créez un nouvel environnement Python dans VSCode
2. Exécutez la commande "Python: Select Interpreter" dans VSCode
3. Vérifiez que Python est correctement installé sur votre système
4. Vérifiez que les variables d'environnement PATH sont correctement configurées
5. Redémarrez VSCode après avoir configuré l'environnement Python

## Problèmes d'exécution de code

### Échec de l'exécution de code

**Symptômes**:
- L'exécution de code via le MCP Jupyter échoue
- Message d'erreur lors de l'exécution de code

**Solutions**:
1. Vérifiez que le kernel est correctement démarré
2. Vérifiez que les dépendances nécessaires sont installées dans l'environnement Python
3. Consultez les logs du serveur Jupyter pour plus d'informations
4. Essayez d'exécuter le même code directement dans Jupyter Notebook pour isoler le problème
5. Vérifiez que le code est syntaxiquement correct

### Dépendances manquantes

**Symptômes**:
- Message d'erreur indiquant qu'un module Python est introuvable
- L'exécution de code échoue avec une erreur d'importation

**Solutions**:
1. Installez les dépendances manquantes dans l'environnement Python
   ```bash
   pip install <nom_du_module>
   ```
2. Vérifiez que l'environnement Python utilisé est le bon
3. Vérifiez que les dépendances sont compatibles entre elles
4. Redémarrez le kernel après l'installation des dépendances

### Timeout lors de l'exécution

**Symptômes**:
- L'exécution de code prend trop de temps et finit par échouer
- Message de timeout lors de l'exécution de code

**Solutions**:
1. Augmentez la valeur du timeout dans la configuration
2. Optimisez le code pour qu'il s'exécute plus rapidement
3. Divisez le code en plusieurs cellules plus petites
4. Vérifiez que le système a suffisamment de ressources (CPU, mémoire)
5. Redémarrez le kernel pour libérer de la mémoire

## Problèmes de configuration

### Fichier de configuration corrompu

**Symptômes**:
- Message d'erreur indiquant que le fichier de configuration est corrompu
- Le serveur ne démarre pas à cause d'une erreur de configuration

**Solutions**:
1. Restaurez la configuration à partir d'une sauvegarde
2. Créez une nouvelle configuration à partir de zéro
3. Vérifiez que le fichier de configuration est un JSON valide
4. Utilisez un validateur JSON pour vérifier la syntaxe du fichier

### Erreur lors du chargement de la configuration

**Symptômes**:
- Message d'erreur indiquant que la configuration n'a pas pu être chargée
- Le serveur démarre avec la configuration par défaut

**Solutions**:
1. Vérifiez que le fichier de configuration existe à l'emplacement attendu
2. Vérifiez que le fichier de configuration est accessible en lecture
3. Vérifiez que le fichier de configuration est un JSON valide
4. Redémarrez le serveur après avoir corrigé la configuration

## Outils de diagnostic

### Scripts de test

Le MCP Jupyter inclut plusieurs scripts de test pour vérifier le bon fonctionnement du serveur:

1. **Test de l'intégration VSCode**:
   ```bash
   node tests/mcp/test-jupyter-vscode-integration.js
   ```
   Ce script teste la détection des kernels VSCode, la connexion du MCP Jupyter aux kernels VSCode et l'exécution de code simple.

2. **Test de la connexion au serveur Jupyter**:
   ```bash
   node tests/mcp/test-jupyter-connection.js
   ```
   Ce script teste la connexion au serveur Jupyter configuré.

3. **Test du mode hors ligne**:
   ```bash
   node tests/mcp/test-jupyter-mcp-offline.js
   ```
   Ce script teste le fonctionnement du MCP Jupyter en mode hors ligne.

### Logs du serveur

Les logs du serveur MCP Jupyter peuvent fournir des informations précieuses pour le dépannage:

1. **Logs de démarrage**: Affichés dans la console lors du démarrage du serveur
2. **Logs d'exécution**: Affichés dans la console pendant l'exécution du serveur
3. **Logs de debug**: Activez le mode debug pour obtenir des logs plus détaillés
   ```bash
   set DEBUG=jupyter-mcp:*
   node mcps/mcp-servers/servers/jupyter-mcp-server/dist/index.js
   ```

### Vérification de la configuration

Vous pouvez vérifier la configuration actuelle du MCP Jupyter:

1. **Afficher la configuration**:
   ```bash
   type mcps/mcp-servers/servers/jupyter-mcp-server/config.json
   ```

2. **Vérifier la syntaxe JSON**:
   ```bash
   node -e "console.log(JSON.parse(require('fs').readFileSync('mcps/mcp-servers/servers/jupyter-mcp-server/config.json', 'utf8')))"
   ```

## Procédures de récupération

### Réinitialisation de la configuration

Si la configuration est corrompue ou cause des problèmes, vous pouvez la réinitialiser:

1. Supprimez le fichier de configuration actuel:
   ```bash
   del mcps/mcp-servers/servers/jupyter-mcp-server/config.json
   ```

2. Redémarrez le serveur avec le script d'intégration VSCode pour générer une nouvelle configuration:
   ```bash
   mcps/jupyter/start-jupyter-mcp-vscode.bat
   ```

### Nettoyage des kernels

Si vous rencontrez des problèmes avec les kernels, vous pouvez les nettoyer:

1. Arrêtez tous les kernels en cours d'exécution dans VSCode
2. Redémarrez VSCode
3. Exécutez la commande "Jupyter: Restart Kernel" dans VSCode
4. Redémarrez le serveur MCP Jupyter

### Réinstallation du MCP Jupyter

En dernier recours, vous pouvez réinstaller le MCP Jupyter:

1. Arrêtez le serveur MCP Jupyter
2. Sauvegardez votre configuration si nécessaire
3. Supprimez le répertoire du MCP Jupyter
4. Clonez à nouveau le dépôt
5. Installez les dépendances
6. Configurez le MCP Jupyter avec le script d'intégration VSCode