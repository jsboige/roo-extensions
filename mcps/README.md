<!-- START_SECTION: metadata -->
---
title: "MCPs (Model Context Protocol)"
description: "Documentation des serveurs MCP pour étendre les capacités des modèles de langage"
tags: #documentation #mcp #overview
date_created: "2025-05-14"
date_updated: "2025-05-14"
version: "1.0.0"
author: "Équipe MCP"
---
<!-- END_SECTION: metadata -->

# MCPs (Model Context Protocol)

Ce répertoire contient l'ensemble des serveurs MCP (Model Context Protocol) disponibles pour étendre les capacités des modèles de langage (LLM) dans le projet Roo.

> **Documentation complète** : Pour une documentation complète et organisée, consultez le [fichier INDEX.md](./INDEX.md) qui sert de point d'entrée principal pour toute la documentation des MCPs.

## Qu'est-ce que MCP?

Le Model Context Protocol (MCP) est un protocole qui permet aux modèles de langage (LLM) d'interagir avec des outils et des ressources externes. Il définit un format standard pour:

1. La découverte d'outils et de ressources
2. L'invocation d'outils
3. L'accès aux ressources
4. La gestion des erreurs et des résultats

Ce protocole permet d'étendre considérablement les capacités des LLM en leur donnant accès à des fonctionnalités externes comme la recherche d'informations en temps réel, l'accès à des API, la manipulation de fichiers, l'analyse de code, et bien plus encore.

## Structure du répertoire

Le répertoire `mcps` est organisé comme suit:

### MCPs (`mcps/mcp-servers`)

Ce sous-module contient tous les serveurs MCP développés et maintenus dans le cadre du projet. Ces serveurs sont conçus pour être légers, performants et faciles à utiliser.

#### MCPs Internes
Serveurs développés en interne:
- **QuickFiles**: Manipulation rapide et efficace de fichiers multiples
- **JinaNavigator**: Conversion de pages web en Markdown
- **Jupyter**: Interaction avec des notebooks Jupyter
- **GitHub Projects**: Gestion des projets GitHub (prototype)

#### MCPs Externes
Serveurs externes intégrés au projet:
- **Docker**: Interaction avec Docker via le protocole MCP
- **Filesystem**: Interaction avec le système de fichiers local
- **Git**: Opérations Git courantes (clone, commit, push, pull, etc.)
- **GitHub**: Interaction avec l'API GitHub (issues, pull requests, etc.)
- **SearXNG**: Recherche web via le moteur de recherche SearXNG
- **Win-CLI**: Exécution de commandes dans le terminal Windows

[En savoir plus sur les MCPs](./mcp-servers/README.md)

### Documentation des MCPs externes (`mcps/external-mcps`)

Ce répertoire contient la documentation des serveurs MCP externes intégrés au projet.

[En savoir plus sur les MCPs externes](./external-mcps/README.md)

## Description des MCPs disponibles

### MCPs Internes

#### QuickFiles Server
Un serveur MCP qui fournit des méthodes pour lire rapidement le contenu de répertoires et fichiers multiples:
- Lecture de plusieurs fichiers en une seule requête
- Extraction de portions spécifiques de fichiers
- Listage détaillé du contenu des répertoires
- Édition de fichiers multiples avec application de diffs

[Documentation QuickFiles](./mcp-servers/servers/quickfiles-server/README.md)

#### JinaNavigator Server
Un serveur MCP qui utilise l'API Jina pour convertir des pages web en Markdown:
- Conversion de pages web en format Markdown
- Extraction de portions spécifiques du contenu
- Accès via URI au format jina://{url}
- Extraction du plan hiérarchique des titres

[Documentation JinaNavigator](./mcp-servers/servers/jinavigator-server/README.md)

#### Jupyter MCP Server
Un serveur MCP qui permet d'interagir avec des notebooks Jupyter:
- Gestion des notebooks (lecture, création, modification)
- Gestion des kernels (démarrage, arrêt, interruption)
- Exécution de code (cellules individuelles ou notebooks complets)
- Récupération des sorties textuelles et riches (images, HTML, etc.)

[Documentation Jupyter MCP](./mcp-servers/servers/jupyter-mcp-server/README.md)

#### GitHub Projects MCP Server
Un serveur MCP qui permet d'interagir avec GitHub Projects v2:
- Gestion des projets (lister, créer, obtenir les détails)
- Gestion des éléments (ajouter des issues, pull requests ou notes)
- Mise à jour des champs des éléments (statut, priorité, date, etc.)
- Accès aux données des projets via des URIs standardisés

[Documentation GitHub Projects](./mcp-servers/servers/github-projects-mcp/README.md)

### MCPs Externes

#### Docker
MCP pour interagir avec Docker, permettant de gérer des conteneurs, des images et des volumes.

#### Filesystem
MCP pour interagir avec le système de fichiers local, offrant des opérations avancées sur les fichiers et répertoires.

#### Git
MCP pour interagir avec des dépôts Git, permettant d'effectuer toutes les opérations Git courantes.

#### GitHub
MCP pour interagir avec l'API GitHub, permettant de gérer des issues, des pull requests et d'autres fonctionnalités GitHub.

#### SearXNG
MCP pour interagir avec le moteur de recherche SearXNG, permettant d'effectuer des recherches web et d'accéder à du contenu en ligne.

#### Win-CLI
MCP pour exécuter des commandes dans le terminal Windows, offrant un accès complet aux fonctionnalités du système d'exploitation.

## Installation et configuration

### Prérequis généraux
- Node.js 14.x ou supérieur
- npm 6.x ou supérieur
- Git

### Installation des MCPs

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

Pour des instructions d'installation spécifiques à chaque serveur MCP, consultez leur documentation respective dans le sous-module `mcps/mcp-servers/servers`.

### Configuration dans Roo

Pour configurer un MCP dans Roo, vous devez ajouter sa configuration dans le fichier `servers.json` de Roo. Voici un exemple de configuration:

```json
{
  "servers": [
    {
      "name": "quickfiles",
      "command": "cmd /c \"cd /d %~dp0\\..\\mcps\\mcp-servers\\servers\\quickfiles-server && run-quickfiles.bat\"",
      "autostart": true
    },
    {
      "name": "jinavigator",
      "command": "cmd /c \"cd /d %~dp0\\..\\mcps\\mcp-servers\\servers\\jinavigator-server && run-jinavigator.bat\"",
      "autostart": true
    },
    {
      "name": "jupyter",
      "command": "cmd /c \"cd /d %~dp0\\..\\mcps\\mcp-servers\\servers\\jupyter-mcp-server && run-jupyter.bat\"",
      "autostart": false
    },
    {
      "name": "searxng",
      "command": "cmd /c npx -y mcp-searxng",
      "autostart": true
    },
    {
      "name": "win-cli",
      "command": "cmd /c npx -y @simonb97/server-win-cli",
      "autostart": true
    }
  ]
}
```

Notez que les chemins ont été mis à jour pour utiliser les scripts batch créés dans les dossiers des serveurs MCP.

## Utilisation

Une fois les serveurs MCP configurés et démarrés, ils peuvent être utilisés par les modèles de langage compatibles avec le protocole MCP. Les outils et ressources exposés par chaque serveur MCP sont automatiquement découverts et peuvent être utilisés dans les conversations avec le modèle.

### Exemples d'utilisation

#### QuickFiles Server
```
Utilisateur: Peux-tu lire les fichiers de configuration dans le dossier config?

LLM: Je vais lire les fichiers de configuration pour vous.
[Utilisation de l'outil quickfiles-server.read_multiple_files]
Voici le contenu des fichiers de configuration...
```

#### Jupyter MCP Server
```
Utilisateur: Crée un notebook Python qui analyse des données.

LLM: Je vais créer un notebook pour vous.
[Utilisation de l'outil jupyter-mcp-server.create_notebook]
J'ai créé un nouveau notebook avec du code pour analyser des données.
```

#### JinaNavigator Server
```
Utilisateur: Peux-tu convertir la page d'accueil de GitHub en Markdown?

LLM: Je vais convertir cette page pour vous.
[Utilisation de l'outil jinavigator-server.convert_web_to_markdown]
Voici le contenu de la page GitHub en format Markdown...
```

## Dépannage

Si un MCP ne fonctionne pas correctement, vérifiez les points suivants:
1. Le MCP est-il correctement installé?
2. Le MCP est-il correctement configuré dans `servers.json`?
3. Le MCP est-il démarré?
4. Y a-t-il des erreurs dans les logs?

Pour plus d'informations sur le dépannage:
- [Guide de dépannage général](./mcp-servers/docs/troubleshooting.md)
- [Guide de dépannage du MCP Jupyter](./mcp-servers/docs/jupyter-mcp-troubleshooting.md)

## Ressources

- [Index de la documentation](./INDEX.md) - Point d'entrée principal pour toute la documentation
- [Guide de recherche](./SEARCH.md) - Comment rechercher efficacement dans la documentation
- [Spécification MCP officielle](https://github.com/microsoft/mcp)
- [Documentation sur l'architecture MCP](./mcp-servers/docs/architecture.md)
- [Guide de contribution](./mcp-servers/CONTRIBUTING.md)
