# Troubleshooting des Problèmes de Démarrage des Serveurs MCP

Ce document a pour but de référencer les erreurs communes rencontrées lors du démarrage des serveurs MCP et de fournir des solutions standardisées, principalement implémentées dans le script de déploiement `scripts/deployment/install-mcps.ps1`.

## 1. `quickfiles` - Erreur `Cannot find module`

**Symptôme :**
Le serveur `quickfiles` échoue au démarrage avec une erreur du type `Error: Cannot find module '.../build/index.js'`.

**Cause Racine :**
Ce problème survient car le serveur, écrit en TypeScript, n'a pas été compilé en JavaScript. Le processus de build, défini par le script `npm run build` dans `package.json`, nécessite des dépendances de développement (`devDependencies`) comme `typescript` pour s'exécuter. Si `npm install` est exécuté en mode production, ces dépendances ne sont pas installées, et la compilation échoue ou n'a pas lieu.

**Solution :**
Le script `scripts/deployment/install-mcps.ps1` a été modifié pour forcer l'installation des `devDependencies` pour tous les MCPs internes.

- **Commande d'installation :** `npm install --include=dev` est maintenant utilisé pour garantir que les outils de build sont toujours disponibles.

## 2. `github-projects-mcp` - Erreur de chargement du `.env` (ENOENT)

**Symptôme :**
Le serveur `github-projects-mcp` démarre mais affiche des avertissements indiquant qu'un token GitHub est manquant, souvent à cause d'une erreur `ENOENT` (Error NO ENTity) signifiant que le fichier `.env` attendu n'a pas été trouvé.

**Cause Racine :**
Le serveur est conçu pour charger ses secrets (comme les tokens d'API) depuis un fichier `.env` situé à sa racine. Le script d'installation initial n'automatisait pas la création de ce fichier.

**Solution :**
Une étape a été ajoutée dans `scripts/deployment/install-mcps.ps1` pour créer automatiquement le fichier `.env` lors de l'installation du serveur `github-projects-mcp`.

- **Logique d'installation :** Après `npm install`, le script écrit le contenu nécessaire dans `mcps/internal/servers/github-projects-mcp/.env`.
- **Configuration du `cwd` :** Le script s'assure également que le `cwd` (Current Working Directory) dans `mcp_settings.json` pointe bien vers le répertoire du MCP, permettant au processus `node` de trouver le `.env` au bon endroit.

## 3. `playwright` - Instabilité du cache `npx` et `ERR_MODULE_NOT_FOUND`

**Symptôme :**
Le démarrage du MCP `playwright` via `npx` échoue de manière intermittente. La suppression manuelle du cache `%LOCALAPPDATA%\npm-cache\_npx` provoque une erreur `ERR_MODULE_NOT_FOUND`, car `npx` ne parvient pas à réinstaller correctement le paquet à la volée.

**Cause Racine :**
La stratégie précédente consistant à supprimer le cache `_npx` s'est avérée trop agressive et instable. Elle peut corrompre l'état interne de `npm`/`npx`, rendant les installations "à la volée" (`-y`) peu fiables. L'erreur `ERR_MODULE_NOT_FOUND` indique que même si `npx` tente de télécharger le paquet, il n'est pas correctement installé ou référencé au moment de l'exécution.

**Solution Robuste (Stratégie de préchauffage) :**
La nouvelle approche, implémentée dans `scripts/deployment/install-mcps.ps1`, vise à garantir que le paquet est présent et valide dans le cache *avant* le démarrage du MCP, sans recourir à une suppression destructrice.

- **Abandon du nettoyage de cache :** La suppression du répertoire `_npx` a été complètement retirée du script.
- **Ajout d'une étape de "préchauffage" :** Juste avant la génération du fichier `mcp_settings.json`, une commande inoffensive est exécutée : `npx -y @playwright/mcp --version`. Cette commande a pour effet de forcer `npx` à vérifier la présence de `@playwright/mcp` dans le cache. S'il est manquant ou invalide, `npx` le télécharge et l'installe proprement. L'exécution se termine après avoir affiché la version, laissant un paquet propre et prêt à l'emploi dans le cache pour le vrai démarrage du MCP.
- **Commande Simplifiée :** La commande dans `mcp_settings.json` reste `npx -y @playwright/mcp --browser firefox`, s'appuyant sur le cache fraîchement validé.

**Solution Alternative (Lancement Manuel Fiable) :**
Si `npx` continue d'être instable, une approche plus robuste consiste à installer le paquet localement dans le projet et à le lancer directement avec `node`.
1.  **Installation locale :** `npm install --prefix . @playwright/mcp playwright`
2.  **Configuration `mcp_settings.json` :**
   ```json
   "playwright": {
     "command": "node",
     "args": [
       "D:/dev/roo-extensions/node_modules/@playwright/mcp/lib/cli.js",
       "--browser",
       "firefox"
     ],
     // ... autres propriétés
   }
   ```

## 4. `markitdown` - Détection de Python piégée par les alias Windows

**Symptôme :**
Le MCP `markitdown` ne démarre pas, car la commande `Get-Command` de PowerShell sélectionne un "alias d'exécution d'application" (`python.exe` dans `C:\Users\...\AppData\Local\Microsoft\WindowsApps\`) qui n'est pas un véritable exécutable mais un simple renvoi vers le Microsoft Store.

**Cause Racine :**
La commande `(Get-Command python3, python, py).Source` ne fait pas la distinction entre un véritable interpréteur Python et les alias installés par Windows pour les applications du Store. Ces alias ne peuvent pas être exécutés avec des arguments comme `--version`, provoquant l'échec de la détection ou du démarrage du MCP.

**Solution Robuste (Détection par validation) :**
Le script `scripts/deployment/install-mcps.ps1` utilise une nouvelle fonction PowerShell, `Find-ViablePythonExecutable`, pour fiabiliser la détection.

- **Recherche Exhaustive :** La fonction utilise `Get-Command python3, python, py -All` pour lister *tous* les candidats possibles, pas seulement le premier.
- **Filtrage des Alias du Store :** Elle ignore explicitement tout candidat dont le chemin source contient `\WindowsApps\`.
- **Test d'Exécution :** Pour chaque candidat restant, elle tente d'exécuter `& $candidate.Source --version` dans un bloc `try/catch`. Le premier candidat qui s'exécute sans erreur et renvoie un code de sortie de `0` est considéré comme valide.
- **Configuration Explicite :** Le chemin absolu de cet exécutable validé est ensuite utilisé pour la configuration de `markitdown` dans `mcp_settings.json`, garantissant que Roo lance un interpréteur Python fonctionnel.

**Solution Alternative (Environnement Conda dédié) :**
Pour isoler complètement les dépendances et garantir la stabilité, la création d'un environnement Conda dédié est la meilleure approche.
1.  **Créer et Activer l'Environnement :**
   ```powershell
   conda create -n mcp-markitdown python=3.9
   conda activate mcp-markitdown
   ```
2.  **Installer les dépendances :**
   ```powershell
   pip install markitdown-mcp
   ```
3.  **Configuration `mcp_settings.json` :**
   Pointez la commande vers l'exécutable Python de l'environnement Conda.
   ```json
   "markitdown": {
     "command": "C:/Users/jsboi/.conda/envs/mcp-markitdown/python.exe",
     "args": [
       "-m",
       "markitdown_mcp"
     ],
     // ... autres propriétés
   }
   ```

## 5. `roo-state-manager` - Timeout au démarrage

**Symptôme :**
Le serveur `roo-state-manager` ne parvient pas à démarrer et génère une erreur de `timeout`.

**Cause Racine :**
Au premier démarrage, le serveur tente de scanner l'ensemble des conversations Roo stockées sur le disque pour construire un "cache de squelettes" en mémoire. Cette opération peut être très longue si le nombre de conversations est élevé, dépassant ainsi le délai de démarrage alloué au MCP.

**Solution :**
La solution consiste à pré-construire ce cache de manière asynchrone après l'installation, plutôt que de bloquer le démarrage initial.

- **Action Manuelle Recommandée :** Après une nouvelle installation ou une mise à jour majeure, il est recommandé d'exécuter manuellement l'outil `build_skeleton_cache` via Roo. Cette opération peut prendre du temps mais ne devra être effectuée qu'une seule fois. Les démarrages suivants seront quasi-instantanés car le serveur se contentera de charger le cache depuis le disque.
- **Amélioration du Script :** Le script `install-mcps.ps1` ne force plus de logique complexe pour ce MCP. La responsabilité de la gestion du cache est laissée au serveur lui-même et à l'action de l'utilisateur, ce qui est une approche plus robuste.
## 6. `jupyter-mcp` - Échecs en cascade (ECONNREFUSED, 403, 404, Cache)

Le dépannage de `jupyter-mcp` est complexe car il implique une chaîne de dépendances : l'extension Roo, le processus MCP (Node.js/TypeScript) et le serveur Jupyter externe (Python).

### 6.1. Erreur `ECONNREFUSED`

**Symptôme :**
Le MCP démarre mais échoue immédiatement avec une erreur `ECONNREFUSED`, indiquant qu'il ne peut pas se connecter au serveur Jupyter sur `localhost:8888`.

**Cause Racine :**
Aucun serveur Jupyter n'écoute sur le port `8888`. Cela peut se produire si :
1.  Aucun serveur Jupyter n'est lancé.
2.  Un programme de bureau comme `JupyterLab.exe` est utilisé, lequel n'ouvre pas de port réseau.
3.  Le serveur Jupyter est lancé sur un port différent.

**Solution : Lancement manuel via Conda**
La solution la plus fiable est de gérer le serveur Jupyter dans un environnement Conda dédié et de le lancer manuellement.

1.  **Créer un environnement Conda :**
    ```powershell
    conda create --name mcp-jupyter python=3.9
    conda activate mcp-jupyter
    ```

2.  **Installer JupyterLab :**
    ```powershell
    pip install jupyterlab
    ```

3.  **Lancer le serveur Jupyter (sans authentification) :**
    Créez un terminal PowerShell dédié et exécutez la commande suivante. Laissez ce terminal ouvert en arrière-plan.
    ```powershell
    conda activate mcp-jupyter
    jupyter-lab --no-browser --ServerApp.token='' --ServerApp.password='' --ServerApp.disable_check_xsrf=True
    ```

### 6.2. Erreur `403 Forbidden`

**Symptôme :**
Le MCP se connecte, mais toutes les requêtes API échouent avec une erreur `403 Forbidden`.

**Cause Racine :**
Le serveur Jupyter est configuré par défaut pour exiger une authentification par token pour sécuriser son API. Le MCP peut ne pas fournir le bon token, surtout lors de la détection automatique.

**Solution :**
La commande de lancement ci-dessus (`--ServerApp.token='' --ServerApp.password=''`) désactive complètement l'authentification, ce qui est acceptable pour un usage en local et résout ce problème.

### 6.3. Erreur `404 Not Found` et problème de rechargement de code

**Symptôme :**
Après avoir corrigé une URL d'API incorrecte dans le code source TypeScript du MCP, l'erreur `404` persiste. Même après recompilation, le MCP semble toujours utiliser l'ancien code défectueux.

**Cause Racine :**
L'extension Roo semble avoir un mécanisme de cache très agressif pour les processus MCP. Ni `touch_mcp_settings`, ni la désactivation/réactivation du MCP ne semblent forcer de manière fiable un rechargement du code depuis le disque.

**Solution (Diagnostic et Dépannage en Développement) :**
Lorsque des modifications sont apportées au code source TypeScript du MCP `jupyter-mcp`, une séquence stricte est nécessaire pour s'assurer qu'elles sont appliquées :

1.  **Appliquer les modifications** au(x) fichier(s) `.ts` dans `mcps/internal/servers/jupyter-mcp-server/src/`.
2.  **Recompiler le projet** pour mettre à jour le fichier `dist/index.js` :
    ```powershell
    npm run build --prefix mcps/internal/servers/jupyter-mcp-server
    ```
3.  **Tuer tous les processus MCP orphelins :** C'est l'étape la plus cruciale. Utilisez PowerShell pour trouver et terminer tous les processus `node` qui exécutent le `jupyter-mcp`.
    ```powershell
    Get-CimInstance Win32_Process -Filter "CommandLine LIKE '%jupyter-mcp-server%'" | ForEach-Object { Stop-Process -Id $_.ProcessId -Force }
    ```
4.  **Tester :** Ré-exécutez l'outil qui posait problème. L'extension devrait maintenant démarrer un nouveau processus MCP frais qui utilisera le code JavaScript fraîchement compilé.

---
