# Serveurs MCP (Model Context Protocol)

Ce répertoire contient la documentation, les tests et les ressources liées aux serveurs MCP (Model Context Protocol) utilisés dans le projet Roo Extensions.

## Qu'est-ce qu'un MCP ?

Le Model Context Protocol (MCP) est un protocole qui permet à Roo de communiquer avec des serveurs externes pour étendre ses capacités. Ces serveurs peuvent fournir des fonctionnalités supplémentaires comme la recherche web, l'exécution de commandes système, la manipulation de fichiers, et bien plus encore.

## Types de serveurs MCP

Dans ce projet, nous distinguons deux types de serveurs MCP :

### MCPs internes

Les MCPs internes sont développés dans le sous-module `mcp-servers` de ce dépôt. Nous avons un contrôle total sur leur code source, leur développement et leur maintenance.

| MCP | Description | État |
|-----|------------|------|
| [QuickFiles](./mcp-servers/servers/quickfiles-server/) | Manipulation rapide de fichiers multiples | ✅ Fonctionnel |
| [JinaNavigator](./mcp-servers/servers/jupyter-mcp-server/) | Conversion de pages web en Markdown | ⚠️ Partiellement fonctionnel |
| [Jupyter](./mcp-servers/servers/jupyter-mcp-server/) | Interaction avec des notebooks Jupyter | ⚠️ Partiellement fonctionnel |

### MCPs externes

Les MCPs externes sont des serveurs développés par d'autres équipes ou organisations. Ce dépôt ne contient que les informations d'installation, de configuration et d'utilisation pour ces serveurs.

| MCP | Description | État |
|-----|------------|------|
| [SearXNG](./external-mcps/searxng/) | Recherche web multi-moteurs | ✅ Fonctionnel |
| [Win-CLI](./external-mcps/win-cli/) | Exécution de commandes système Windows | ⚠️ Partiellement fonctionnel |
| [Filesystem](./external-mcps/filesystem/) | Interaction avec le système de fichiers | ✅ Fonctionnel |
| [Git](./external-mcps/git/) | Opérations Git | ✅ Fonctionnel |
| [GitHub](./external-mcps/github/) | Interaction avec l'API GitHub | ✅ Fonctionnel |
| [Docker](./external-mcps/docker/) | Gestion de conteneurs Docker | ✅ Fonctionnel |

## Structure du répertoire

```
mcps/
├── INDEX.md                  # Point d'entrée principal
├── README.md                 # Ce document
├── INSTALLATION.md           # Guide d'installation global
├── TROUBLESHOOTING.md        # Guide de dépannage global
├── SEARCH.md                 # Guide de recherche dans la documentation
├── TEST-RESULTS.md           # Résultats des derniers tests
├── mcp-servers/              # MCPs internes
│   └── servers/
│       ├── quickfiles-server/
│       ├── jupyter-mcp-server/
│       └── ...
├── external-mcps/            # MCPs externes
│   ├── github/
│   ├── searxng/
│   ├── win-cli/
│   └── ...
└── tests/                    # Scripts de test pour les MCPs
    ├── test-quickfiles.js
    ├── test-jinavigator.js
    ├── test-jupyter.js
    ├── reports/              # Rapports de test générés
    └── ...
```

## Installation et configuration

### MCPs internes

Pour installer et configurer les MCPs internes, suivez les instructions spécifiques à chaque serveur :

1. [Installation de QuickFiles](./mcp-servers/servers/quickfiles-server/INSTALLATION.md)
2. [Installation de JinaNavigator](./mcp-servers/servers/jinavigator-server/INSTALLATION.md)
3. [Installation de Jupyter](./mcp-servers/servers/jupyter-mcp-server/INSTALLATION.md)

### MCPs externes

Pour installer et configurer les MCPs externes, suivez les instructions spécifiques à chaque serveur :

1. [Installation de SearXNG](./external-mcps/searxng/installation.md)
2. [Installation de Win-CLI](./external-mcps/win-cli/installation.md)
3. [Installation de GitHub](./external-mcps/github/INSTALLATION.md)

Pour des instructions générales sur l'installation et la configuration des serveurs MCP, consultez le [Guide d'utilisation des MCPs](../docs/guides/guide-utilisation-mcps.md).

## Tests

Pour tester les serveurs MCP, consultez le [README des tests](./tests/README.md). Les tests permettent de vérifier le bon fonctionnement des serveurs MCP et de détecter les problèmes potentiels.

## Fonctionnalités par serveur

### MCPs internes

#### QuickFiles
- Lecture de fichiers multiples en une seule requête
- Listage de répertoires avec options avancées
- Édition et suppression de fichiers multiples
- Recherche dans les fichiers avec contexte
- Extraction de structure Markdown

#### JinaNavigator
- Conversion de pages web en Markdown
- Extraction de plans hiérarchiques
- Conversion multiple de pages web

#### Jupyter
- Création et manipulation de notebooks Jupyter
- Exécution de code dans des kernels
- Gestion des kernels (démarrage, arrêt, redémarrage)

### MCPs externes

#### SearXNG
- Recherche web multi-moteurs
- Filtrage par date et type de contenu
- Extraction de contenu web

#### Win-CLI
- Exécution de commandes PowerShell, CMD et Git Bash
- Gestion des connexions SSH
- Accès aux fonctionnalités système

#### Filesystem
- Lecture et écriture de fichiers
- Création de répertoires
- Recherche de fichiers
- Manipulation de fichiers (déplacement, suppression)

#### Git
- Opérations Git (clone, commit, push, pull)
- Gestion des branches et des tags
- Résolution de conflits

#### GitHub
- Gestion des issues et pull requests
- Accès aux informations des dépôts
- Gestion des workflows

#### Docker
- Gestion des conteneurs Docker
- Création et déploiement d'images
- Surveillance des conteneurs

## Intégration avec Roo

Les serveurs MCP sont intégrés à Roo via le protocole MCP. Pour plus d'informations sur l'intégration, consultez le [Guide d'utilisation des MCPs](../docs/guides/guide-utilisation-mcps.md).

## Dépannage

Si vous rencontrez des problèmes avec les serveurs MCP, consultez les guides de dépannage spécifiques :

### MCPs internes
- [Dépannage QuickFiles](./mcp-servers/servers/quickfiles-server/TROUBLESHOOTING.md)
- [Dépannage JinaNavigator](./mcp-servers/servers/jinavigator-server/TROUBLESHOOTING.md)
- [Dépannage Jupyter](./mcp-servers/servers/jupyter-mcp-server/TROUBLESHOOTING.md)

### MCPs externes
- [Dépannage SearXNG](./external-mcps/searxng/TROUBLESHOOTING.md)
- [Dépannage Win-CLI](./external-mcps/win-cli/TROUBLESHOOTING.md)
- [Dépannage GitHub](./external-mcps/github/TROUBLESHOOTING.md)

Pour des problèmes généraux, consultez le [Guide de dépannage global](./TROUBLESHOOTING.md) et le [Rapport de test des serveurs MCPs](./TEST-RESULTS.md).

## Ressources supplémentaires

- [Guide de recherche dans la documentation MCP](./SEARCH.md)
- [Documentation de la structure de configuration Roo](../docs/guides/documentation-structure-configuration-roo.md)
- [Rapport d'état des MCPs](../docs/rapport-etat-mcps.md)
- [Documentation officielle du protocole MCP](https://github.com/modelcontextprotocol/protocol)
