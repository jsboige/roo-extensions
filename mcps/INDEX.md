<!-- START_SECTION: metadata -->
---
title: "Documentation des MCPs (Model Context Protocol)"
description: "Point d'entrée principal pour la documentation des serveurs MCP"
tags: #documentation #mcp #index #guide
date_created: "2025-05-14"
date_updated: "2025-05-14"
version: "1.0.0"
author: "Équipe MCP"
---
<!-- END_SECTION: metadata -->

# Documentation des MCPs (Model Context Protocol)

<!-- START_SECTION: introduction -->
## Introduction

Bienvenue dans la documentation des serveurs MCP (Model Context Protocol). Ce répertoire contient l'ensemble des informations nécessaires pour comprendre, installer, configurer et utiliser les différents serveurs MCP disponibles dans le projet Roo.

### Qu'est-ce que MCP?

Le Model Context Protocol (MCP) est un protocole qui permet aux modèles de langage (LLM) d'interagir avec des outils et des ressources externes. Il définit un format standard pour:

1. La découverte d'outils et de ressources
2. L'invocation d'outils
3. L'accès aux ressources
4. La gestion des erreurs et des résultats

Ce protocole permet d'étendre considérablement les capacités des LLM en leur donnant accès à des fonctionnalités externes comme la recherche d'informations en temps réel, l'accès à des API, la manipulation de fichiers, l'analyse de code, et bien plus encore.
<!-- END_SECTION: introduction -->

<!-- START_SECTION: structure -->
## Structure de la Documentation

```
mcps/
├── INDEX.md                  # Ce document (point d'entrée principal)
├── README.md                 # Présentation générale des MCPs
├── INSTALLATION.md           # Guide d'installation global
├── TROUBLESHOOTING.md        # Guide de dépannage global
├── SEARCH.md                 # Guide de recherche dans la documentation
├── mcp-servers/              # MCPs internes
│   ├── INDEX.md              # Index des MCPs internes
│   ├── servers/
│   │   ├── quickfiles-server/
│   │   │   ├── README.md
│   │   │   ├── INSTALLATION.md
│   │   │   ├── CONFIGURATION.md
│   │   │   ├── USAGE.md
│   │   │   └── TROUBLESHOOTING.md
│   │   ├── jinavigator-server/
│   │   │   ├── README.md
│   │   │   ├── INSTALLATION.md
│   │   │   ├── CONFIGURATION.md
│   │   │   ├── USAGE.md
│   │   │   └── TROUBLESHOOTING.md
│   │   └── jupyter-mcp-server/
│   │       ├── README.md
│   │       ├── INSTALLATION.md
│   │       ├── CONFIGURATION.md
│   │       ├── USAGE.md
│   │       └── TROUBLESHOOTING.md
│   └── docs/                 # Documentation générale des MCPs internes
└── external/            # MCPs externes
    ├── README.md             # Présentation des MCPs externes
    ├── docker/
    │   ├── README.md
    │   ├── INSTALLATION.md
    │   ├── CONFIGURATION.md
    │   ├── USAGE.md
    │   └── TROUBLESHOOTING.md
    ├── filesystem/
    ├── git/
    ├── github/
    ├── searxng/
    └── win-cli/
```
<!-- END_SECTION: structure -->

<!-- START_SECTION: quickstart -->
## Démarrage Rapide

Cette section vous permet de commencer rapidement avec les MCPs sans avoir à parcourir toute la documentation.

### Installation rapide

```bash
# Cloner le sous-module mcp-servers
git submodule update --init --recursive mcps/mcp-servers

# Installer les dépendances principales
cd mcps/mcp-servers
npm install

# Installer tous les serveurs MCP
npm run install-all

# Configurer les serveurs
npm run setup-config
```

### Configuration rapide dans Roo

Ajoutez les serveurs MCP dans votre fichier `servers.json` de Roo :

```json
{
  "servers": [
    {
      "name": "quickfiles",
      "command": "cmd /c node D:\\chemin\\vers\\mcps\\mcp-servers\\servers\\quickfiles-server\\build\\index.js",
      "autostart": true
    },
    {
      "name": "jinavigator",
      "command": "cmd /c node D:\\chemin\\vers\\mcps\\mcp-servers\\servers\\jinavigator-server\\build\\index.js",
      "autostart": true
    },
    {
      "name": "jupyter",
      "command": "cmd /c node D:\\chemin\\vers\\mcps\\mcp-servers\\servers\\jupyter-mcp-server\\build\\index.js",
      "autostart": true
    }
  ]
}
```

### Exemples d'utilisation rapide

#### QuickFiles
```
Utilisateur: Peux-tu lire les fichiers de configuration dans le dossier config?

LLM: Je vais lire les fichiers de configuration pour vous.
[Utilisation de l'outil quickfiles-server.read_multiple_files]
Voici le contenu des fichiers de configuration...
```

#### JinaNavigator
```
Utilisateur: Peux-tu convertir la page d'accueil de GitHub en Markdown?

LLM: Je vais convertir cette page pour vous.
[Utilisation de l'outil jinavigator-server.convert_web_to_markdown]
Voici le contenu de la page GitHub en format Markdown...
```

#### Jupyter
```
Utilisateur: Crée un notebook Python qui analyse des données.

LLM: Je vais créer un notebook pour vous.
[Utilisation de l'outil jupyter-mcp-server.create_notebook]
J'ai créé un nouveau notebook avec du code pour analyser des données.
```
<!-- END_SECTION: quickstart -->

<!-- START_SECTION: detailed_docs -->
## Documentation Détaillée

### MCPs Internes

Les MCPs internes sont développés et maintenus dans le cadre du projet. Ils sont conçus pour être légers, performants et faciles à utiliser.

| MCP | Description | Documentation |
|-----|-------------|---------------|
| **QuickFiles** | Manipulation rapide et efficace de fichiers multiples | [Documentation complète](./mcp-servers/servers/quickfiles-server/README.md) |
| **JinaNavigator** | Conversion de pages web en Markdown | [Documentation complète](./mcp-servers/servers/jinavigator-server/README.md) |
| **Jupyter** | Interaction avec des notebooks Jupyter | [Documentation complète](./mcp-servers/servers/jupyter-mcp-server/README.md) |

Pour plus d'informations sur les MCPs internes, consultez l'[index des MCPs internes](./mcp-servers/INDEX.md).

### MCPs Externes

Les MCPs externes sont des serveurs MCP tiers intégrés au projet. Ils fournissent des fonctionnalités supplémentaires pour interagir avec divers systèmes et services.

| MCP | Description | Documentation |
|-----|-------------|---------------|
| **Docker** | Interaction avec Docker | [Documentation complète](./external/docker/README.md) |
| **Filesystem** | Interaction avec le système de fichiers local | [Documentation complète](./external/filesystem/README.md) |
| **Git** | Opérations Git courantes | [Documentation complète](./external/git/README.md) |
| **GitHub** | Interaction avec l'API GitHub | [Documentation complète](./external/github/README.md) |
| **SearXNG** | Recherche web via SearXNG | [Documentation complète](./external/searxng/README.md) |
| **Win-CLI** | Exécution de commandes dans le terminal Windows | [Documentation complète](./external/win-cli/README.md) |

Pour plus d'informations sur les MCPs externes, consultez la [documentation des MCPs externes](./external/README.md).

### Guides d'installation

- [Guide d'installation global](./INSTALLATION.md)
- [Installation des MCPs internes](./mcp-servers/INSTALLATION.md)
- [Installation des MCPs externes](./external/INSTALLATION.md)

### Guides de configuration

- [Configuration des MCPs internes](./mcp-servers/CONFIGURATION.md)
- [Configuration des MCPs externes](./external/CONFIGURATION.md)
- [Configuration dans Roo](./CONFIGURATION_ROO.md)

### Guides d'utilisation

- [Utilisation des MCPs internes](./mcp-servers/USAGE.md)
- [Utilisation des MCPs externes](./external/USAGE.md)
- [Bonnes pratiques](./BEST_PRACTICES.md)

### Dépannage

- [Guide de dépannage global](./TROUBLESHOOTING.md)
- [Dépannage des MCPs internes](./mcp-servers/TROUBLESHOOTING.md)
- [Dépannage des MCPs externes](./external/TROUBLESHOOTING.md)
<!-- END_SECTION: detailed_docs -->

<!-- START_SECTION: resources -->
## Ressources

### Ressources Internes

- [Architecture MCP](./internal/docs/architecture.md)
- [Guide de contribution](./internal/CONTRIBUTING.md)
- [Tests et validation](./tests/README.md)
- [Exemples d'utilisation](./mcp-servers/examples/)

### Ressources Externes

- [Spécification MCP officielle](https://github.com/microsoft/mcp)
- [Documentation du protocole MCP](https://github.com/modelcontextprotocol/protocol)
- [Forum de support MCP](https://github.com/modelcontextprotocol/protocol/discussions)
- [Signaler un problème](https://github.com/modelcontextprotocol/protocol/issues)

### Outils et Utilitaires

- [Validateur MCP](https://github.com/modelcontextprotocol/validator)
- [Client MCP pour JavaScript](https://github.com/modelcontextprotocol/client-js)
- [SDK MCP pour Node.js](https://github.com/modelcontextprotocol/sdk-node)
<!-- END_SECTION: resources -->

<!-- START_SECTION: search -->
## Recherche dans la Documentation

Pour savoir comment rechercher efficacement dans cette documentation, consultez le [guide de recherche](./SEARCH.md).

### Tags Principaux

- #installation - Documents liés à l'installation des MCPs
- #configuration - Documents liés à la configuration des MCPs
- #usage - Documents liés à l'utilisation des MCPs
- #troubleshooting - Documents liés au dépannage des MCPs
- #quickfiles - Documents liés au MCP QuickFiles
- #jinavigator - Documents liés au MCP JinaNavigator
- #jupyter - Documents liés au MCP Jupyter
- #docker - Documents liés au MCP Docker
- #filesystem - Documents liés au MCP Filesystem
- #git - Documents liés au MCP Git
- #github - Documents liés au MCP GitHub
- #searxng - Documents liés au MCP SearXNG
- #win-cli - Documents liés au MCP Win-CLI
<!-- END_SECTION: search -->

<!-- START_SECTION: navigation -->
## Navigation

- [Accueil](./README.md)
- [Installation](./INSTALLATION.md)
- [Dépannage](./TROUBLESHOOTING.md)
- [Recherche](./SEARCH.md)
- [MCPs Internes](./mcp-servers/INDEX.md)
- [MCPs Externes](./external/README.md)
<!-- END_SECTION: navigation -->