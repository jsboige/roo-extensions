# MCP Playwright

Ce répertoire contient le MCP Playwright, installé en tant que sous-module Git.

Le MCP `playwright` fournit des outils pour piloter un navigateur web via l'API Playwright, permettant d'automatiser des tâches, d'effectuer des tests end-to-end ou de faire du web scraping.

Il est cloné depuis le dépôt officiel de Microsoft : [https://github.com/microsoft/playwright-mcp.git](https://github.com/microsoft/playwright-mcp.git)

## Configuration et Installation

### Prérequis

Le MCP Playwright nécessite Node.js et npm pour être compilé, car il s'agit d'un projet TypeScript.

### Installation et Compilation

**Important :** Le MCP Playwright n'est pas livré pré-compilé. Il faut l'installer et le compiler avant utilisation :

1. Naviguer vers le répertoire source :
   ```bash
   cd mcps/external/playwright/source
   ```

2. Installer les dépendances :
   ```bash
   npm install
   ```

3. Compiler le projet TypeScript :
   ```bash
   npm run build
   ```

Cette compilation génère les fichiers JavaScript dans le répertoire `lib/`.

### Configuration MCP

La configuration du serveur MCP doit pointer vers le fichier compilé :

```json
"playwright": {
    "command": "cmd",
    "args": [
        "/c",
        "node",
        "d:/Dev/roo-extensions/mcps/external/playwright/source/lib/index.js"
    ],
    "transportType": "stdio",
    "disabled": false,
    "autoStart": true,
    "description": "Serveur MCP pour l'automatisation web avec Playwright"
}
```

**Note :** La configuration doit pointer vers `lib/index.js` (fichier compilé) et non vers `index.js` ou `src/index.ts`.

## Problèmes Connus

### Erreur de Configuration

Si le MCP est configuré pour pointer vers `source/index.js` au lieu de `source/lib/index.js`, il ne fonctionnera pas car le fichier d'entrée principal n'est pas le fichier TypeScript source mais le fichier JavaScript compilé.

### Compilation Requise

Le projet étant en TypeScript, il nécessite une étape de compilation avant d'être utilisable. Cette étape n'est pas automatique et doit être effectuée manuellement.

## Nettoyage

Pour nettoyer les fichiers générés :

```bash
cd mcps/external/playwright/source
npm run clean
```

## Test du MCP

Pour valider le bon fonctionnement du MCP, vous pouvez tester les outils suivants :
- `browser_navigate` : Navigation vers une URL
- `browser_take_screenshot` : Capture d'écran
- `browser_close` : Fermeture du navigateur

## Structure du Projet

- `source/` : Code source du MCP Playwright (sous-module Git)
- `source/src/` : Code TypeScript source
- `source/lib/` : Code JavaScript compilé (généré)
- `source/package.json` : Configuration npm et scripts de build