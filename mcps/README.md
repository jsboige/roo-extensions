# Serveurs MCP (Model Context Protocol)

## Table des matières

1. [Introduction](#introduction)
2. [Organisation](#organisation)
   - [MCPs internes](#mcps-internes)
   - [MCPs externes](#mcps-externes)
3. [Fonctionnalités](#fonctionnalités)
4. [Installation](#installation)
5. [Configuration](#configuration)
6. [Utilisation](#utilisation)
   - [QuickFiles](#quickfiles)
   - [JinaNavigator](#jinavigator)
   - [Jupyter](#jupyter)
   - [SearXNG](#searxng)
   - [Win-CLI](#win-cli)
7. [Structure](#structure)
8. [Intégration](#intégration)
9. [Dépannage](#dépannage)
10. [Ressources supplémentaires](#ressources-supplémentaires)

## Introduction

Ce répertoire contient les serveurs MCP (Model Context Protocol) utilisés dans le projet Roo Extensions. Les serveurs MCP étendent les capacités de Roo en fournissant des fonctionnalités supplémentaires via un protocole standardisé. Ils permettent à Roo d'interagir avec des systèmes externes, d'accéder à des données et d'exécuter des opérations spécialisées.

## Organisation

Les serveurs MCP sont organisés en deux catégories principales :

### MCPs internes

Développés spécifiquement pour ce projet :

- **QuickFiles** (`internal/servers/quickfiles-server/`) - Serveur MCP pour manipuler rapidement plusieurs fichiers
- **Jupyter** (`internal/servers/jupyter-mcp-server/`) - Serveur MCP pour interagir avec les notebooks Jupyter
- **JinaNavigator** (`internal/servers/jinavigator-server/`) - Serveur MCP pour convertir des pages web en Markdown
- **GitHub Projects** (`internal/servers/github-projects-mcp/`) - Serveur MCP pour interagir avec GitHub Projects

### MCPs externes

Intégrés depuis des sources externes :

- **Filesystem** (`external/filesystem/`) - Serveur MCP pour accéder au système de fichiers
- **Git** (`external/git/`) - Serveur MCP pour les opérations Git
- **GitHub** (`external/github/`) - Serveur MCP pour interagir avec l'API GitHub
- **Jupyter** (`internal/servers/jupyter-mcp-server/`) - Serveur MCP pour l'intégration avec Jupyter (maintenant interne)
- **SearXNG** (`external/searxng/`) - Serveur MCP pour effectuer des recherches web
- **Win-CLI** (`external/win-cli/`) - Serveur MCP pour exécuter des commandes CLI sur Windows

## Fonctionnalités

Les serveurs MCP offrent un large éventail de fonctionnalités :

- **Manipulation de fichiers** - Lecture, écriture, recherche et modification de fichiers
- **Conversion web vers Markdown** - Transformation de pages web en format Markdown
- **Interaction avec Jupyter** - Création et exécution de notebooks Jupyter
- **Recherche web** - Requêtes de recherche via SearXNG
- **Exécution de commandes** - Exécution de commandes système sur Windows
- **Opérations Git et GitHub** - Interaction avec les dépôts Git et l'API GitHub
- **Accès au système de fichiers** - Opérations avancées sur le système de fichiers

## Installation

Pour installer les serveurs MCP :

1. Assurez-vous d'avoir Node.js installé (version 16 ou supérieure)
2. Clonez ce dépôt si ce n'est pas déjà fait
3. Installez les dépendances :

```bash
cd mcps
npm install
```

Pour des instructions détaillées, consultez le fichier [INSTALLATION.md](docs/INSTALLATION.md).

## Configuration

Les configurations des serveurs MCP sont définies dans le fichier `roo-config/settings/servers.json`. Voici un exemple de configuration :

```json
{
  "servers": [
    {
      "name": "quickfiles",
      "command": "node c:/dev/roo-extensions/mcps/internal/servers/quickfiles-server/build/index.js",
      "autoStart": true
    },
    {
      "name": "jinavigator",
      "command": "node c:/dev/roo-extensions/mcps/internal/servers/jinavigator-server/dist/index.js",
      "autoStart": true
    }
  ]
}
```

## Utilisation

Voici quelques exemples d'utilisation des principaux serveurs MCP :

### QuickFiles

```javascript
// Lire plusieurs fichiers en une seule requête
<use_mcp_tool>
<server_name>quickfiles</server_name>
<tool_name>read_multiple_files</tool_name>
<arguments>
{
  "paths": ["src/app.js", "src/utils.js"],
  "show_line_numbers": true
}
</arguments>
</use_mcp_tool>

// Rechercher dans des fichiers
<use_mcp_tool>
<server_name>quickfiles</server_name>
<tool_name>search_in_files</tool_name>
<arguments>
{
  "paths": ["src/"],
  "pattern": "function\\s+main\\(\\)",
  "use_regex": true
}
</arguments>
</use_mcp_tool>
```

### JinaNavigator

```javascript
// Convertir une page web en Markdown
<use_mcp_tool>
<server_name>jinavigator</server_name>
<tool_name>convert_web_to_markdown</tool_name>
<arguments>
{
  "url": "https://example.com"
}
</arguments>
</use_mcp_tool>
```

### Jupyter

```javascript
// Créer un nouveau notebook
<use_mcp_tool>
<server_name>jupyter</server_name>
<tool_name>create_notebook</tool_name>
<arguments>
{
  "path": "notebooks/analysis.ipynb",
  "kernel": "python3"
}
</arguments>
</use_mcp_tool>

// Exécuter une cellule de code
<use_mcp_tool>
<server_name>jupyter</server_name>
<tool_name>execute_cell</tool_name>
<arguments>
{
  "kernel_id": "kernel-id",
  "code": "import pandas as pd\ndf = pd.read_csv('data.csv')\ndf.head()"
}
</arguments>
</use_mcp_tool>
```

### SearXNG

```javascript
// Effectuer une recherche web
<use_mcp_tool>
<server_name>searxng</server_name>
<tool_name>searxng_web_search</tool_name>
<arguments>
{
  "query": "Model Context Protocol",
  "time_range": "month"
}
</arguments>
</use_mcp_tool>
```

### Win-CLI

```javascript
// Exécuter une commande PowerShell
<use_mcp_tool>
<server_name>win-cli</server_name>
<tool_name>execute_command</tool_name>
<arguments>
{
  "shell": "powershell",
  "command": "Get-Process | Select-Object -First 5"
}
</arguments>
</use_mcp_tool>
```

## Structure

```
mcps/
├── internal/                   # MCPs développés en interne
│   └── servers/
│       ├── quickfiles-server/  # Serveur MCP pour fichiers multiples
│       ├── jinavigator-server/ # Serveur MCP pour conversion web
│       ├── jupyter-mcp-server/ # Serveur MCP pour Jupyter
│       └── github-projects-mcp/ # Serveur MCP pour GitHub Projects
├── external/                   # MCPs externes
│   ├── filesystem/             # MCP système de fichiers
│   ├── git/                    # MCP Git
│   ├── github/                 # MCP GitHub
│   ├── jupyter/                # MCP Jupyter externe
│   ├── searxng/                # MCP SearXNG
│   └── win-cli/                # MCP CLI Windows
├── docker/                     # Conteneurisation des serveurs MCP
├── monitoring/                 # Surveillance des serveurs MCP
├── scripts/                    # Scripts utilitaires
├── tests/                      # Tests des serveurs MCP
└── utils/                      # Utilitaires communs
```

## Intégration

Les serveurs MCP s'intègrent avec les autres composants du projet Roo Extensions de plusieurs façons :

1. **Avec les modes Roo** : Les modes personnalisés peuvent utiliser les capacités des serveurs MCP pour effectuer des tâches spécifiques. Par exemple, le mode Architect peut utiliser JinaNavigator pour rechercher des informations techniques, tandis que le mode Code peut utiliser QuickFiles pour manipuler efficacement plusieurs fichiers de code.

2. **Avec le système de profils** : Les profils peuvent être configurés pour activer ou désactiver certains serveurs MCP en fonction des besoins spécifiques de l'utilisateur ou du projet.

3. **Avec la démo d'initiation** : Les exemples de la démo utilisent les serveurs MCP pour illustrer les capacités avancées de Roo, comme la recherche web, la manipulation de fichiers et l'exécution de commandes système.

4. **Avec les tests automatisés** : Le système de tests utilise les serveurs MCP pour valider le bon fonctionnement de l'ensemble du système Roo Extensions.

## Dépannage

Si vous rencontrez des problèmes avec les serveurs MCP :

1. Vérifiez que le serveur est correctement démarré
2. Consultez les logs dans le répertoire `logs/`
3. Assurez-vous que la configuration dans `servers.json` est correcte
4. Vérifiez les dépendances requises pour chaque serveur

Pour des instructions détaillées de dépannage, consultez le fichier [TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md).

## Ressources supplémentaires

- [README principal](../README.md)
- [Documentation des modes Roo](../roo-modes/README.md)
- [Documentation de la configuration Roo](../roo-config/README.md)
- [Documentation des tests](../tests/README.md)
- [INSTALLATION.md](docs/INSTALLATION.md) - Instructions d'installation détaillées
- [TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) - Guide de dépannage
- [MANUAL_START.md](docs/MANUAL_START.md) - Instructions pour démarrer manuellement les serveurs
- [OPTIMIZATIONS.md](docs/OPTIMIZATIONS.md) - Recommandations d'optimisation
