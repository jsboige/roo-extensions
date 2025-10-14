# Guide de Configuration des MCPs

Ce guide explique comment configurer et utiliser les différents MCPs (Model Context Protocol) disponibles dans le projet.

## Table des matières

1. [JinaNavigator](#jinavigator)
2. [Jupyter](#jupyter)
3. [Win-CLI](#win-cli)
4. [Autres MCPs](#autres-mcps)

## JinaNavigator

JinaNavigator est un MCP qui permet de convertir des pages web en Markdown en utilisant l'API Jina.

### Installation

1. Assurez-vous que Node.js est installé sur votre système.
2. Naviguez vers le répertoire du serveur JinaNavigator:
   ```bash
   cd mcps/mcp-servers/servers/jinavigator-server
   ```
3. Installez les dépendances:
   ```bash
   npm install
   ```
4. Compilez le serveur:
   ```bash
   npm run build
   ```

### Configuration

1. Créez un fichier `config.json` dans le répertoire du serveur JinaNavigator:
   ```json
   {
     "server": {
       "port": 3000,
       "host": "localhost"
     },
     "api": {
       "baseUrl": "https://r.jina.ai/"
     }
   }
   ```
   - `port`: Le port sur lequel le serveur HTTP écoutera (par défaut: 3000)
   - `host`: L'hôte sur lequel le serveur HTTP écoutera (par défaut: localhost)
   - `baseUrl`: L'URL de base de l'API Jina (par défaut: https://r.jina.ai/)

### Démarrage

Pour démarrer le serveur JinaNavigator, exécutez:
```bash
cd mcps/jinavigator
.\run-jinavigator.bat
```

Ou directement:
```bash
node mcps/mcp-servers/servers/jinavigator-server/dist/index.js
```

### Fonctionnalités

JinaNavigator expose les outils suivants:
- `convert_web_to_markdown`: Convertit une page web en Markdown
- `access_jina_resource`: Accède au contenu Markdown via un URI au format jina://{url}
- `multi_convert`: Convertit plusieurs pages web en parallèle
- `extract_markdown_outline`: Extrait le plan hiérarchique des titres markdown

### Dépannage

Si le serveur JinaNavigator ne démarre pas correctement:
1. Vérifiez que toutes les dépendances sont installées
2. Vérifiez que le fichier de configuration est correctement formaté
3. Vérifiez les logs pour identifier les erreurs

## Jupyter

Jupyter MCP est un serveur qui permet d'interagir avec des notebooks Jupyter.

### Installation

1. Assurez-vous que Node.js et Jupyter sont installés sur votre système.
2. Naviguez vers le répertoire du serveur Jupyter MCP:
   ```bash
   cd mcps/mcp-servers/servers/jupyter-mcp-server
   ```
3. Installez les dépendances:
   ```bash
   npm install
   ```
4. Compilez le serveur:
   ```bash
   npm run build
   ```

### Configuration

1. Créez un fichier `config.json` dans le répertoire du serveur Jupyter MCP:
   ```json
   {
     "jupyterServer": {
       "baseUrl": "http://localhost:8888",
       "token": "test_token"
     },
     "server": {
       "port": 3000,
       "host": "localhost"
     },
     "offline": true
   }
   ```
   - `jupyterServer.baseUrl`: L'URL du serveur Jupyter (par défaut: http://localhost:8888)
   - `jupyterServer.token`: Le token d'authentification du serveur Jupyter
   - `server.port`: Le port sur lequel le serveur HTTP écoutera (par défaut: 3000)
   - `server.host`: L'hôte sur lequel le serveur HTTP écoutera (par défaut: localhost)
   - `offline`: Si true, le serveur fonctionnera en mode hors ligne (sans tentatives de connexion au serveur Jupyter)

### Démarrage du serveur Jupyter

Avant de démarrer le serveur Jupyter MCP, vous devez démarrer un serveur Jupyter:
```bash
jupyter notebook --NotebookApp.token=test_token --NotebookApp.allow_origin='*' --no-browser
```

### Démarrage du serveur MCP

Pour démarrer le serveur Jupyter MCP, exécutez:
```bash
cd mcps/jupyter
.\run-jupyter.bat
```

Ou directement:
```bash
node mcps/mcp-servers/servers/jupyter-mcp-server/dist/index.js
```

### Fonctionnalités

Jupyter MCP expose les outils suivants:
- Outils de notebook: `create_notebook`, `read_notebook`, `write_notebook`, `add_cell`, `update_cell`, `remove_cell`
- Outils de kernel: `list_kernels`, `start_kernel`, `stop_kernel`, `restart_kernel`, `interrupt_kernel`
- Outils d'exécution: `execute_cell`, `execute_notebook`, `execute_notebook_cell`

### Dépannage

Si le serveur Jupyter MCP ne démarre pas correctement:
1. Vérifiez que Jupyter est correctement installé (`jupyter --version`)
2. Vérifiez que le serveur Jupyter est en cours d'exécution (`jupyter notebook list`)
3. Vérifiez que toutes les dépendances sont installées
4. Vérifiez que le fichier de configuration est correctement formaté
5. Vérifiez les logs pour identifier les erreurs

## Win-CLI

Win-CLI est un MCP qui permet d'exécuter des commandes shell sur Windows.

### Installation

1. Assurez-vous que Node.js est installé sur votre système.
2. Installez le serveur Win-CLI:
   ```bash
   npm install -g @simonb97/server-win-cli
   ```

### Configuration

Le fichier de configuration de Win-CLI se trouve à l'emplacement `%USERPROFILE%\.win-cli-server\config.json`.

Pour autoriser tous les opérateurs (`&`, `|`, `;`, `` ` ``), assurez-vous que les tableaux `blockedOperators` sont vides pour chaque shell:
```json
"shells": {
  "powershell": {
    "enabled": true,
    "command": "powershell.exe",
    "args": [
      "-NoProfile",
      "-NonInteractive",
      "-Command"
    ],
    "blockedOperators": []
  },
  "cmd": {
    "enabled": true,
    "command": "cmd.exe",
    "args": [
      "/c"
    ],
    "blockedOperators": []
  },
  "gitbash": {
    "enabled": true,
    "command": "C:\\Program Files\\Git\\bin\\bash.exe",
    "args": [
      "-c"
    ],
    "blockedOperators": []
  }
}
```

### Démarrage

Pour démarrer le serveur Win-CLI, exécutez:
```bash
cd mcps/external-mcps/win-cli
.\run-win-cli.bat
```

Ou directement:
```bash
npx @simonb97/server-win-cli
```

### Fonctionnalités

Win-CLI expose les outils suivants:
- `execute_command`: Exécute une commande shell
- `get_command_history`: Récupère l'historique des commandes exécutées
- `ssh_execute`: Exécute une commande sur un hôte distant via SSH
- `ssh_disconnect`: Déconnecte d'un serveur SSH
- `create_ssh_connection`: Crée une nouvelle connexion SSH
- `read_ssh_connections`: Lit toutes les connexions SSH
- `update_ssh_connection`: Met à jour une connexion SSH existante
- `delete_ssh_connection`: Supprime une connexion SSH existante
- `get_current_directory`: Récupère le répertoire de travail actuel

### Utilisation des opérateurs dans les commandes

Voici comment utiliser les opérateurs dans les différents shells:

#### PowerShell
- `;` pour exécuter des commandes séquentiellement: `Get-Process; Get-Service`
- `|` pour rediriger la sortie: `Get-Process | Select-Object -First 3`
- `-and` pour les conditions logiques: `(Test-Path 'C:\Windows') -and (Test-Path 'C:\Program Files')`

#### CMD
- `&` pour exécuter des commandes séquentiellement: `dir /b & echo Test`
- `&&` pour exécuter des commandes séquentiellement (conditionnellement): `dir /b && echo Test`
- `|` pour rediriger la sortie: `dir | findstr /i windows`

#### Git Bash
- `;` pour exécuter des commandes séquentiellement: `ls -la; echo Test`
- `&&` pour exécuter des commandes séquentiellement (conditionnellement): `ls -la && echo Test`
- `|` pour rediriger la sortie: `ls -la | grep test`

### Dépannage

Si le serveur Win-CLI ne démarre pas correctement:
1. Vérifiez que le fichier de configuration est correctement formaté
2. Vérifiez les logs pour identifier les erreurs
3. Assurez-vous que les chemins des shells sont corrects

## Playwright

Playwright MCP permet de contrôler un navigateur (Chromium, Firefox, WebKit) pour automatiser des actions web.

### Installation

Le MCP Playwright est installé via `npx` lors de sa première exécution, mais il est recommandé d'installer le package `@playwright/mcp` pour une meilleure gestion.

```bash
npm install @playwright/mcp
```

### Configuration

Voici la configuration recommandée pour le MCP Playwright dans votre fichier `mcp_settings.json`. Cette configuration utilise `npx` pour s'assurer que la dernière version du client MCP de Playwright est toujours utilisée.

```json
"playwright": {
  "enabled": true,
  "command": "npx",
  "args": [
    "-y",
    "@playwright/mcp",
    "--browser",
    "chromium"
  ]
}
```

- **`command: "npx"`**: Utilise `npx` pour exécuter le package.
- **`args`**:
    - `"-y"`: Accepte automatiquement l'installation du package `@playwright/mcp` si ce n'est pas déjà fait.
    - `"--browser", "chromium"`: Spécifie le navigateur à utiliser. C'est une étape importante pour éviter les erreurs si plusieurs navigateurs sont installés ou si le navigateur par défaut n'est pas celui attendu.

### Dépannage

**Symptôme**: Le MCP échoue avec une erreur `Request timed out`.

**Cause Racine**: La configuration de démarrage est incorrecte. Une erreur commune est d'essayer de lancer `playwright run-server`, qui est un serveur HTTP, alors que le `roo-state-manager` attend une communication via `stdio`.

**Solution**: Utilisez toujours la commande de démarrage recommandée ci-dessus, qui fait appel au client MCP officiel (`@playwright/mcp`) conçu pour une intégration `stdio`.

## SearXNG

SearXNG MCP fournit une interface de recherche web via une instance SearXNG.

### Installation

Le MCP SearXNG est installé via `npx` lors de sa première exécution.

```bash
npm install mcp-searxng
```

### Configuration

Voici la configuration recommandée pour le MCP SearXNG dans votre fichier `mcp_settings.json`.

```json
"searxng": {
  "enabled": true,
  "command": "cmd",
  "args": [
    "/c",
    "npx",
    "-y",
    "mcp-searxng"
  ]
}
```

- **`command: "cmd"`** et **`args: ["/c", ...]`**: Cette configuration est spécifiquement conçue pour contourner des problèmes de compatibilité de chemins de fichiers sous Windows. L'utilisation de `cmd /c npx` assure que le processus est lancé dans un environnement qui résout correctement les chemins.
- **Variable d'environnement `SEARXNG_URL`**: Ce MCP nécessite que la variable d'environnement `SEARXNG_URL` soit définie et pointe vers votre instance SearXNG (par exemple, `https://searxng.example.com`). Assurez-vous que cette variable est accessible par l'environnement qui exécute le MCP.

### Dépannage

**Symptôme**: Le serveur se connecte mais crash avec l'erreur `MCP error -32000: Connection closed`. N'expose aucun outil.

**Cause Racine Identifiée (Jan 2025)**: Incompatibilité Windows dans la condition de démarrage du serveur. Le problème technique précis :
- `import.meta.url` retourne : `file:///C:/Users/.../index.js`
- `process.argv[1]` retourne : `C:\Users\...\index.js`
- La condition `if (import.meta.url === \`file://${process.argv[1]}\`)` ne correspond jamais sur Windows.

**Solutions**:

1. **Solution recommandée**: Utiliser la commande de démarrage `cmd /c npx -y mcp-searxng` comme configuré ci-dessus.

2. **Solution alternative** (si modification du package nécessaire): Corriger la normalisation des chemins dans le fichier source :
   ```javascript
   const normalizedPath = process.argv[1].replace(/\\/g, '/');
   const expectedUrl = `file:///${normalizedPath}`;
   if (import.meta.url === expectedUrl) { ... }
   ```

3. **Diagnostic**: Tester directement avec `node "C:\Users\jsboi\AppData\Roaming\npm\node_modules\mcp-searxng\dist\index.js"`

**Variables d'environnement**: Assurez-vous que `SEARXNG_URL` est définie et accessible.

**Problème connexe - Corruption BOM**: Si le fichier `mcp_settings.json` devient invalide après modification, voir [Guide d'urgence MCP](guides/GUIDE-URGENCE-MCP.md).

## Autres MCPs

Pour les autres MCPs disponibles (Filesystem, GitHub, Docker), consultez leur documentation respective dans le répertoire `mcps/external-mcps/`.

## Conclusion

Ce guide vous a montré comment configurer et utiliser les différents MCPs disponibles dans le projet. Si vous rencontrez des problèmes, n'hésitez pas à consulter les logs et la documentation spécifique à chaque MCP.