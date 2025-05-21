# Guide de dépannage du serveur MCP Jupyter

<!-- START_SECTION: introduction -->
Ce guide de dépannage vous aidera à résoudre les problèmes courants rencontrés lors de l'utilisation du serveur MCP Jupyter. Il couvre les problèmes d'installation, de configuration, de connexion au serveur Jupyter, et d'utilisation des différents outils.
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
error TS2307: Cannot find module '@jupyterlab/services' or its corresponding type declarations.
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

2. Installez les dépendances spécifiques à Jupyter :
   ```bash
   npm install --save @jupyterlab/services
   ```

3. Vérifiez la version de TypeScript et mettez-la à jour si nécessaire :
   ```bash
   npm install --save-dev typescript@latest
   ```

4. Vérifiez les erreurs dans le code source et corrigez-les.

### Erreur d'installation de Jupyter

**Symptôme** : Erreurs lors de l'installation de Jupyter Notebook ou JupyterLab.

```
ERROR: Could not find a version that satisfies the requirement jupyter
```

**Causes possibles** :
- Python n'est pas installé ou n'est pas dans le PATH
- Version de Python incompatible
- Problèmes avec pip

**Solutions** :
1. Vérifiez que Python est installé et dans le PATH :
   ```bash
   python --version
   ```

2. Utilisez une version compatible de Python (3.6 ou supérieure) :
   ```bash
   # Sur Windows
   python -m pip install --upgrade pip
   python -m pip install jupyter
   
   # Sur macOS/Linux
   python3 -m pip install --upgrade pip
   python3 -m pip install jupyter
   ```

3. Utilisez un environnement virtuel pour éviter les conflits :
   ```bash
   python -m venv jupyter-env
   jupyter-env\Scripts\activate  # Windows
   source jupyter-env/bin/activate  # macOS/Linux
   pip install jupyter
   ```
<!-- END_SECTION: installation_issues -->

<!-- START_SECTION: jupyter_connection_issues -->
## Problèmes de connexion au serveur Jupyter

### Erreur "Cannot connect to Jupyter server"

**Symptôme** : Le serveur MCP Jupyter ne peut pas se connecter au serveur Jupyter.

```
Error: Cannot connect to Jupyter server at http://localhost:8888
```

**Causes possibles** :
- Le serveur Jupyter n'est pas en cours d'exécution
- L'URL du serveur Jupyter est incorrecte
- Le token d'authentification est incorrect
- Problèmes de réseau ou de pare-feu

**Solutions** :
1. Vérifiez que le serveur Jupyter est en cours d'exécution :
   ```bash
   # Vérifier les processus Jupyter en cours d'exécution
   # Sur Windows
   tasklist | findstr jupyter
   
   # Sur macOS/Linux
   ps aux | grep jupyter
   ```

2. Démarrez le serveur Jupyter s'il n'est pas en cours d'exécution :
   ```bash
   jupyter notebook --NotebookApp.token=test_token --NotebookApp.allow_origin='*' --no-browser
   ```

3. Vérifiez l'URL et le token dans la configuration du serveur MCP Jupyter :
   ```json
   {
     "jupyterServer": {
       "baseUrl": "http://localhost:8888",
       "token": "test_token"
     }
   }
   ```

4. Vérifiez que vous pouvez accéder au serveur Jupyter dans un navigateur :
   ```
   http://localhost:8888/api/kernels?token=test_token
   ```

5. Vérifiez les journaux du serveur Jupyter pour plus d'informations.

### Erreur "403 Forbidden"

**Symptôme** : Le serveur MCP Jupyter reçoit une erreur 403 Forbidden lors de la connexion au serveur Jupyter.

```
Error: Request failed with status code 403
```

**Causes possibles** :
- Le token d'authentification est incorrect
- Le serveur Jupyter n'autorise pas les requêtes CORS
- Problèmes de configuration du serveur Jupyter

**Solutions** :
1. Vérifiez que le token dans la configuration correspond exactement au token du serveur Jupyter :
   ```json
   {
     "jupyterServer": {
       "token": "test_token"  // Doit correspondre au token utilisé pour démarrer le serveur Jupyter
     }
   }
   ```

2. Assurez-vous que le serveur Jupyter est démarré avec l'option `--NotebookApp.allow_origin='*'` :
   ```bash
   jupyter notebook --NotebookApp.token=test_token --NotebookApp.allow_origin='*' --no-browser
   ```

3. Redémarrez le serveur Jupyter et le serveur MCP Jupyter.

4. Vérifiez les journaux du serveur Jupyter pour plus d'informations sur l'erreur 403.

### Erreur "Connection timeout"

**Symptôme** : Le serveur MCP Jupyter rencontre un timeout lors de la connexion au serveur Jupyter.

```
Error: Connection timeout when connecting to Jupyter server
```

**Causes possibles** :
- Le serveur Jupyter est lent à répondre
- Problèmes de réseau
- Le serveur Jupyter est surchargé

**Solutions** :
1. Augmentez le timeout dans la configuration :
   ```json
   {
     "jupyterServer": {
       "timeout": 60000  // 60 secondes
     }
   }
   ```

2. Vérifiez la charge du serveur Jupyter et redémarrez-le si nécessaire.

3. Vérifiez votre connexion réseau.

### Erreur "CORS error"

**Symptôme** : Le serveur MCP Jupyter rencontre une erreur CORS lors de la connexion au serveur Jupyter.

```
Error: CORS error: No 'Access-Control-Allow-Origin' header is present
```

**Causes possibles** :
- Le serveur Jupyter n'est pas configuré pour autoriser les requêtes CORS
- Problèmes de configuration du serveur Jupyter

**Solutions** :
1. Assurez-vous que le serveur Jupyter est démarré avec l'option `--NotebookApp.allow_origin='*'` :
   ```bash
   jupyter notebook --NotebookApp.allow_origin='*' --no-browser
   ```

2. Pour une configuration plus sécurisée, spécifiez l'origine exacte :
   ```bash
   jupyter notebook --NotebookApp.allow_origin='http://localhost:3000' --no-browser
   ```

3. Si vous utilisez JupyterLab, utilisez les options équivalentes :
   ```bash
   jupyter lab --ServerApp.allow_origin='*' --no-browser
   ```
<!-- END_SECTION: jupyter_connection_issues -->

<!-- START_SECTION: offline_mode_issues -->
## Problèmes avec le mode hors ligne

### Fonctionnalités non disponibles en mode hors ligne

**Symptôme** : Certaines fonctionnalités ne sont pas disponibles lorsque le serveur est en mode hors ligne.

```
Error: This feature requires a connection to a Jupyter server, but the server is in offline mode
```

**Causes possibles** :
- Le serveur MCP Jupyter est en mode hors ligne
- Tentative d'utiliser des fonctionnalités qui nécessitent un serveur Jupyter

**Solutions** :
1. Désactivez le mode hors ligne dans la configuration :
   ```json
   {
     "offline": false,
     "jupyterServer": {
       "baseUrl": "http://localhost:8888",
       "token": "test_token"
     }
   }
   ```

2. Ou utilisez l'option de ligne de commande :
   ```bash
   npm start -- --offline false
   ```

3. Ou définissez la variable d'environnement :
   ```bash
   # Sur Windows
   set JUPYTER_MCP_OFFLINE=false
   
   # Sur macOS/Linux
   export JUPYTER_MCP_OFFLINE=false
   ```

4. Démarrez un serveur Jupyter si nécessaire :
   ```bash
   jupyter notebook --NotebookApp.token=test_token --NotebookApp.allow_origin='*' --no-browser
   ```

### Erreur lors du passage du mode hors ligne au mode en ligne

**Symptôme** : Erreurs lors du passage du mode hors ligne au mode en ligne.

```
Error: Failed to connect to Jupyter server after switching from offline mode
```

**Causes possibles** :
- Le serveur Jupyter n'est pas en cours d'exécution
- Problèmes de configuration

**Solutions** :
1. Assurez-vous que le serveur Jupyter est en cours d'exécution avant de désactiver le mode hors ligne.

2. Redémarrez le serveur MCP Jupyter après avoir désactivé le mode hors ligne :
   ```bash
   npm start -- --offline false
   ```

3. Vérifiez la configuration du serveur Jupyter et du serveur MCP Jupyter.
<!-- END_SECTION: offline_mode_issues -->

<!-- START_SECTION: notebook_issues -->
## Problèmes avec les notebooks

### Erreur "File not found"

**Symptôme** : L'outil renvoie une erreur indiquant que le fichier notebook n'existe pas.

```
Error: ENOENT: no such file or directory, open '/path/to/notebook.ipynb'
```

**Causes possibles** :
- Le chemin du fichier est incorrect
- Le fichier n'existe pas
- Problèmes de permissions

**Solutions** :
1. Vérifiez que le chemin du fichier est correct et que le fichier existe :
   ```bash
   # Sur Windows
   dir /path/to/notebook.ipynb
   
   # Sur macOS/Linux
   ls -la /path/to/notebook.ipynb
   ```

2. Utilisez des chemins absolus ou relatifs au répertoire de travail du serveur MCP Jupyter.

3. Vérifiez les permissions du fichier :
   ```bash
   # Sur macOS/Linux
   ls -la /path/to/notebook.ipynb
   ```

4. Créez le fichier s'il n'existe pas :
   ```javascript
   await client.callTool('jupyter-mcp-server', 'create_notebook', {
     path: '/path/to/notebook.ipynb',
     kernel: 'python3'
   });
   ```

### Erreur "Invalid notebook format"

**Symptôme** : L'outil renvoie une erreur indiquant que le format du notebook est invalide.

```
Error: Invalid notebook format: unexpected token at line 1
```

**Causes possibles** :
- Le fichier n'est pas un notebook Jupyter valide
- Le fichier est corrompu
- Le fichier est vide

**Solutions** :
1. Vérifiez que le fichier est un notebook Jupyter valide (.ipynb) :
   ```bash
   cat /path/to/notebook.ipynb | head -n 10
   ```
   Le fichier doit commencer par `{` et contenir des champs comme `cells`, `metadata`, `nbformat`.

2. Essayez d'ouvrir le notebook dans Jupyter Notebook pour vérifier qu'il est valide.

3. Recréez le notebook si nécessaire :
   ```javascript
   await client.callTool('jupyter-mcp-server', 'create_notebook', {
     path: '/path/to/notebook.ipynb',
     kernel: 'python3'
   });
   ```

### Erreur lors de l'écriture d'un notebook

**Symptôme** : L'outil renvoie une erreur lors de l'écriture d'un notebook.

```
Error: EACCES: permission denied, open '/path/to/notebook.ipynb'
```

**Causes possibles** :
- Problèmes de permissions
- Le répertoire parent n'existe pas
- Le fichier est ouvert par une autre application

**Solutions** :
1. Vérifiez les permissions du fichier et du répertoire parent :
   ```bash
   # Sur macOS/Linux
   ls -la /path/to/
   ```

2. Créez le répertoire parent s'il n'existe pas :
   ```bash
   # Sur Windows
   mkdir /path/to/
   
   # Sur macOS/Linux
   mkdir -p /path/to/
   ```

3. Fermez toutes les applications qui pourraient avoir ouvert le fichier.

4. Utilisez un chemin différent pour écrire le notebook :
   ```javascript
   await client.callTool('jupyter-mcp-server', 'write_notebook', {
     path: '/path/to/notebook_new.ipynb',
     content: notebook
   });
   ```
<!-- END_SECTION: notebook_issues -->

<!-- START_SECTION: kernel_issues -->
## Problèmes avec les kernels

### Erreur "Kernel not found"

**Symptôme** : L'outil renvoie une erreur indiquant que le kernel n'existe pas.

```
Error: Kernel 'python3' not found
```

**Causes possibles** :
- Le kernel n'est pas installé
- Le kernel n'est pas disponible dans le serveur Jupyter
- Problèmes de configuration

**Solutions** :
1. Vérifiez les kernels disponibles :
   ```javascript
   const result = await client.callTool('jupyter-mcp-server', 'list_kernels', {});
   console.log(result.available_kernels);
   ```

2. Installez le kernel manquant :
   ```bash
   # Pour Python
   pip install ipykernel
   python -m ipykernel install --user
   
   # Pour R
   R -e "install.packages('IRkernel'); IRkernel::installspec()"
   ```

3. Redémarrez le serveur Jupyter après l'installation d'un nouveau kernel.

4. Utilisez un kernel disponible :
   ```javascript
   await client.callTool('jupyter-mcp-server', 'start_kernel', {
     kernel_name: 'python3'  // Ou un autre kernel disponible
   });
   ```

### Erreur "Kernel connection timeout"

**Symptôme** : L'outil renvoie une erreur de timeout lors de la connexion au kernel.

```
Error: Timeout waiting for kernel to connect
```

**Causes possibles** :
- Le kernel est lent à démarrer
- Le serveur Jupyter est surchargé
- Problèmes de ressources système

**Solutions** :
1. Augmentez le timeout dans la configuration :
   ```json
   {
     "jupyterServer": {
       "timeout": 60000  // 60 secondes
     }
   }
   ```

2. Vérifiez la charge du système et libérez des ressources si nécessaire.

3. Redémarrez le serveur Jupyter.

4. Utilisez un kernel plus léger si possible.

### Erreur "Kernel died"

**Symptôme** : Le kernel s'arrête de manière inattendue pendant l'exécution.

```
Error: Kernel died with exit code 1
```

**Causes possibles** :
- Erreur dans le code exécuté
- Manque de mémoire
- Problèmes de ressources système
- Bug dans le kernel

**Solutions** :
1. Vérifiez le code exécuté pour détecter les erreurs.

2. Augmentez la mémoire disponible pour le kernel :
   ```bash
   # Sur macOS/Linux
   export JUPYTER_RESOURCE_LIMIT_MEM=4G
   ```

3. Redémarrez le kernel :
   ```javascript
   await client.callTool('jupyter-mcp-server', 'restart_kernel', {
     kernel_id: kernelId
   });
   ```

4. Utilisez un kernel plus stable si possible.

### Erreur lors de l'interruption d'un kernel

**Symptôme** : L'outil renvoie une erreur lors de l'interruption d'un kernel.

```
Error: Failed to interrupt kernel
```

**Causes possibles** :
- Le kernel ne répond pas
- Problèmes de communication avec le serveur Jupyter
- Bug dans le kernel

**Solutions** :
1. Essayez de redémarrer le kernel :
   ```javascript
   await client.callTool('jupyter-mcp-server', 'restart_kernel', {
     kernel_id: kernelId
   });
   ```

2. Si cela ne fonctionne pas, arrêtez le kernel :
   ```javascript
   await client.callTool('jupyter-mcp-server', 'stop_kernel', {
     kernel_id: kernelId
   });
   ```

3. En dernier recours, redémarrez le serveur Jupyter.
<!-- END_SECTION: kernel_issues -->

<!-- START_SECTION: execution_issues -->
## Problèmes d'exécution de code

### Erreur lors de l'exécution d'une cellule

**Symptôme** : L'outil renvoie une erreur lors de l'exécution d'une cellule.

```
Error: Cell execution failed: NameError: name 'undefined_variable' is not defined
```

**Causes possibles** :
- Erreur dans le code exécuté
- Dépendances manquantes
- Variables non définies
- Problèmes de kernel

**Solutions** :
1. Vérifiez le code exécuté pour détecter les erreurs :
   ```python
   # Exemple de correction
   undefined_variable = 42  # Définir la variable avant de l'utiliser
   print(undefined_variable)
   ```

2. Installez les dépendances manquantes :
   ```python
   # Dans une cellule de notebook
   !pip install numpy pandas matplotlib
   ```

3. Exécutez les cellules dans l'ordre pour définir les variables avant de les utiliser.

4. Redémarrez le kernel si nécessaire :
   ```javascript
   await client.callTool('jupyter-mcp-server', 'restart_kernel', {
     kernel_id: kernelId
   });
   ```

### Timeout lors de l'exécution d'une cellule

**Symptôme** : L'outil renvoie une erreur de timeout lors de l'exécution d'une cellule.

```
Error: Cell execution timed out after 30000ms
```

**Causes possibles** :
- Le code exécuté prend trop de temps
- Boucle infinie dans le code
- Calculs intensifs

**Solutions** :
1. Augmentez le timeout dans la configuration :
   ```json
   {
     "jupyterServer": {
       "timeout": 60000  // 60 secondes
     }
   }
   ```

2. Optimisez le code pour qu'il s'exécute plus rapidement.

3. Divisez les calculs intensifs en plusieurs cellules.

4. Utilisez des échantillons de données plus petits pour les tests.

### Erreur de mémoire lors de l'exécution

**Symptôme** : Le kernel s'arrête avec une erreur de mémoire lors de l'exécution.

```
Error: Kernel died with exit code 137 (Out of memory)
```

**Causes possibles** :
- Le code utilise trop de mémoire
- Fuites de mémoire dans le code
- Ressources système insuffisantes

**Solutions** :
1. Optimisez l'utilisation de la mémoire dans le code :
   ```python
   # Exemple d'optimisation
   import numpy as np
   
   # Au lieu de
   # data = np.ones((100000, 100000))  # 80 Go de mémoire
   
   # Utilisez
   data = np.ones((10000, 10000))  # 800 Mo de mémoire
   ```

2. Libérez la mémoire explicitement :
   ```python
   import gc
   del large_variable
   gc.collect()
   ```

3. Augmentez la mémoire disponible pour le kernel.

4. Utilisez des techniques de traitement par lots pour les grands ensembles de données.

### Problèmes avec les sorties riches

**Symptôme** : Les sorties riches (images, HTML, etc.) ne sont pas correctement affichées ou provoquent des erreurs.

```
Error: Failed to process output of type 'display_data'
```

**Causes possibles** :
- Problèmes de sérialisation des sorties
- Sorties trop volumineuses
- Formats de sortie non supportés

**Solutions** :
1. Utilisez des formats de sortie standard :
   ```python
   # Au lieu de widgets interactifs complexes
   import matplotlib.pyplot as plt
   plt.plot([1, 2, 3, 4])
   plt.show()
   ```

2. Limitez la taille des sorties :
   ```python
   # Réduire la résolution des images
   plt.figure(figsize=(8, 6), dpi=100)  # Au lieu de dpi=300
   ```

3. Utilisez des formats de sortie textuels lorsque c'est possible :
   ```python
   # Au lieu d'afficher un DataFrame complet
   print(df.head())  # Afficher seulement les 5 premières lignes
   ```
<!-- END_SECTION: execution_issues -->

<!-- START_SECTION: advanced_troubleshooting -->
## Dépannage avancé

### Analyse des journaux

Les journaux du serveur MCP Jupyter et du serveur Jupyter peuvent fournir des informations précieuses pour diagnostiquer les problèmes.

#### Journaux du serveur MCP Jupyter

1. Augmentez le niveau de détail des journaux pour le débogage :
   ```json
   {
     "logging": {
       "level": "debug",
       "file": "jupyter-mcp-debug.log",
       "console": true
     }
   }
   ```

2. Analysez les journaux pour identifier les erreurs :
   ```bash
   grep "ERROR" jupyter-mcp.log
   ```

3. Suivez les journaux en temps réel pendant l'exécution :
   ```bash
   tail -f jupyter-mcp.log
   ```

#### Journaux du serveur Jupyter

1. Démarrez le serveur Jupyter avec l'option `--debug` :
   ```bash
   jupyter notebook --debug --NotebookApp.token=test_token --NotebookApp.allow_origin='*' --no-browser
   ```

2. Consultez les journaux du serveur Jupyter pour identifier les erreurs.

### Débogage avec Node.js Inspector

Pour un débogage plus approfondi du serveur MCP Jupyter :

1. Démarrez le serveur en mode débogage :
   ```bash
   node --inspect dist/index.js
   ```

2. Ouvrez Chrome et accédez à `chrome://inspect`.

3. Cliquez sur "Open dedicated DevTools for Node" pour ouvrir les outils de développement.

4. Utilisez les outils de développement pour définir des points d'arrêt, inspecter des variables et suivre l'exécution du code.

### Vérification de la connectivité

Pour vérifier la connectivité entre le serveur MCP Jupyter et le serveur Jupyter :

1. Vérifiez que le serveur Jupyter est accessible :
   ```bash
   curl -I http://localhost:8888/api/kernels?token=test_token
   ```

2. Vérifiez les informations du serveur Jupyter :
   ```bash
   curl http://localhost:8888/api/kernelspecs?token=test_token
   ```

3. Testez la création d'un kernel :
   ```bash
   curl -X POST http://localhost:8888/api/kernels?token=test_token -H "Content-Type: application/json" -d '{"name":"python3"}'
   ```

### Réinitialisation complète

Si tous les autres dépannages échouent, essayez une réinitialisation complète :

1. Arrêtez le serveur MCP Jupyter et le serveur Jupyter.

2. Supprimez les fichiers temporaires et les journaux :
   ```bash
   rm -f jupyter-mcp.log
   rm -rf ~/.jupyter/runtime/
   ```

3. Redémarrez le serveur Jupyter avec des options propres :
   ```bash
   jupyter notebook --NotebookApp.token=test_token --NotebookApp.allow_origin='*' --no-browser
   ```

4. Redémarrez le serveur MCP Jupyter avec la configuration par défaut :
   ```bash
   npm start
   ```
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

### Codes d'erreur spécifiques à Jupyter MCP

| Code | Description | Solution |
|------|-------------|----------|
| -32001 | JupyterConnectionError | Problème de connexion au serveur Jupyter | Vérifiez que le serveur Jupyter est en cours d'exécution et accessible |
| -32002 | KernelNotFoundError | Le kernel spécifié n'existe pas | Vérifiez les kernels disponibles et installez-le si nécessaire |
| -32003 | KernelConnectionError | Problème de connexion au kernel | Redémarrez le kernel ou le serveur Jupyter |
| -32004 | NotebookNotFoundError | Le notebook spécifié n'existe pas | Vérifiez le chemin du fichier et créez-le si nécessaire |
| -32005 | InvalidNotebookError | Le format du notebook est invalide | Vérifiez le contenu du fichier notebook |
| -32006 | ExecutionError | Erreur lors de l'exécution de code | Vérifiez le code exécuté pour détecter les erreurs |
| -32007 | OfflineModeError | Fonctionnalité non disponible en mode hors ligne | Désactivez le mode hors ligne ou utilisez uniquement les fonctionnalités disponibles |
| -32008 | TimeoutError | Timeout lors d'une opération | Augmentez le timeout ou optimisez l'opération |
<!-- END_SECTION: common_error_codes -->

<!-- START_SECTION: next_steps -->
## Prochaines étapes

Si vous avez résolu votre problème, vous pouvez maintenant :

1. [Configurer le serveur](CONFIGURATION.md) selon vos besoins
2. [Apprendre à utiliser le serveur](USAGE.md) avec des exemples pratiques
3. [Explorer les cas d'utilisation avancés](../docs/jupyter-mcp-use-cases.md) pour tirer le meilleur parti du serveur

Si vous n'avez pas pu résoudre votre problème :

1. Consultez les [issues GitHub](https://github.com/jsboige/jsboige-mcp-servers/issues) pour voir si d'autres utilisateurs ont rencontré le même problème
2. Ouvrez une nouvelle issue en fournissant des détails sur votre problème, les étapes pour le reproduire et les journaux pertinents
3. Contactez l'équipe de support pour obtenir de l'aide supplémentaire
<!-- END_SECTION: next_steps -->