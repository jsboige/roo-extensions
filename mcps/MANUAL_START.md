# Guide de démarrage manuel des serveurs MCP

Ce document explique comment démarrer manuellement les serveurs MCP depuis le répertoire de développement, les étapes à suivre en cas d'échec de la synchronisation, et les commandes spécifiques pour chaque serveur.

## Prérequis

- Node.js installé (version 14 ou supérieure recommandée)
- NPM installé
- Accès au répertoire de développement `d:\dev\roo-extensions\mcps`

## Démarrage manuel des serveurs MCP

### 1. JinaNavigator MCP

Le serveur JinaNavigator nécessite une compilation TypeScript avant son démarrage.

```batch
cd d:\dev\roo-extensions\mcps\mcp-servers\servers\jinavigator-server
npm run build
node dist\index.js
```

### 2. Jupyter MCP

Le serveur Jupyter MCP peut être démarré en mode normal ou en mode hors ligne.

**Mode normal:**
```batch
cd d:\dev\roo-extensions\mcps\mcp-servers\servers\jupyter-mcp-server
node dist\index.js
```

**Mode hors ligne:**
```batch
cd d:\dev\roo-extensions\mcps\mcp-servers\servers\jupyter-mcp-server
node dist\index.js --offline
```

### 3. QuickFiles MCP

```batch
cd d:\dev\roo-extensions\mcps\mcp-servers\servers\quickfiles-server
node build\index.js
```

## En cas d'échec de la synchronisation

Si la synchronisation des configurations échoue (via le script `sync-mcp-config.ps1`), suivez ces étapes:

### 1. Vérifier l'espace disque disponible

```powershell
Get-WmiObject -Class Win32_LogicalDisk | Format-Table DeviceID, FreeSpace, Size
```

Si l'espace disque est insuffisant (moins de 50 Mo), libérez de l'espace ou utilisez l'option de synchronisation vers un emplacement temporaire.

### 2. Synchronisation manuelle

Si la synchronisation automatique échoue, vous pouvez copier manuellement les fichiers:

```powershell
# Copier le fichier de configuration
Copy-Item -Path "d:\Dev\roo-extensions\mcps\scripts\new_mcp_settings.json" -Destination "C:\Users\jsboi\AppData\Roaming\Code\User\globalStorage\rooveterinaryinc.roo-cline\settings\mcp_settings.json" -Force

# Copier les scripts de démarrage
Copy-Item -Path "d:\Dev\roo-extensions\mcps\scripts\mcp-starters\*.bat" -Destination "C:\Users\jsboi\AppData\Roaming\Code\User\globalStorage\rooveterinaryinc.roo-cline\mcp-starters" -Force
```

### 3. Utiliser l'emplacement temporaire

Si la synchronisation a été effectuée vers un emplacement temporaire, copiez les fichiers depuis cet emplacement:

```powershell
# Copier depuis l'emplacement temporaire
Copy-Item -Path "$env:TEMP\roo-mcp-sync-temp\mcp_settings.json" -Destination "C:\Users\jsboi\AppData\Roaming\Code\User\globalStorage\rooveterinaryinc.roo-cline\settings\mcp_settings.json" -Force
Copy-Item -Path "$env:TEMP\roo-mcp-sync-temp\*.bat" -Destination "C:\Users\jsboi\AppData\Roaming\Code\User\globalStorage\rooveterinaryinc.roo-cline\mcp-starters" -Force
```

## Vérification du fonctionnement

Pour vérifier que les serveurs MCP fonctionnent correctement, vous pouvez exécuter les commandes suivantes:

### JinaNavigator MCP
```batch
curl http://localhost:3001/status
```

### Jupyter MCP
```batch
curl http://localhost:3002/status
```

### QuickFiles MCP
```batch
curl http://localhost:3003/status
```

## Résolution des problèmes courants

### 1. Port déjà utilisé

Si un port est déjà utilisé, vous pouvez trouver et arrêter le processus qui l'utilise:

```powershell
# Trouver le processus qui utilise un port spécifique (ex: 3001)
netstat -ano | findstr :3001

# Arrêter le processus avec l'ID trouvé
taskkill /PID <ID_PROCESSUS> /F
```

### 2. Erreurs de compilation TypeScript

Si vous rencontrez des erreurs lors de la compilation TypeScript:

```batch
cd d:\dev\roo-extensions\mcps\mcp-servers\servers\jinavigator-server
npm install
npm run clean
npm run build
```

### 3. Problèmes de dépendances Node.js

En cas de problèmes avec les dépendances:

```batch
cd d:\dev\roo-extensions\mcps\mcp-servers\servers\<nom-du-serveur>
npm ci