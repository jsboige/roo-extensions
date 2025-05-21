# Serveurs MCP (Model Context Protocol)

Ce répertoire contient la documentation, les tests et les ressources liées aux serveurs MCP (Model Context Protocol) utilisés dans le projet Roo Extensions.

## Qu'est-ce qu'un MCP ?

Le Model Context Protocol (MCP) est un protocole qui permet à Roo de communiquer avec des serveurs externes pour étendre ses capacités. Ces serveurs peuvent fournir des fonctionnalités supplémentaires comme la recherche web, l'exécution de commandes système, la manipulation de fichiers, et bien plus encore.

## Nouveautés et modifications récentes

Plusieurs améliorations importantes ont été apportées à l'infrastructure MCP :

- **Système de surveillance** : Un nouveau système de surveillance a été mis en place pour détecter et résoudre automatiquement les problèmes avec les serveurs MCP.
- **Serveurs HTTP** : Support amélioré pour les serveurs MCP basés sur HTTP, avec une meilleure gestion des connexions et des timeouts.
- **Optimisations de performance** : Réduction de la consommation de ressources et amélioration des temps de réponse (voir [OPTIMIZATIONS.md](./OPTIMIZATIONS.md)).
- **Documentation améliorée** : Guides de dépannage plus détaillés et documentation spécifique pour chaque serveur MCP.
- **Nouveaux outils de diagnostic** : Outils pour identifier et résoudre rapidement les problèmes courants.

## Types de serveurs MCP

Dans ce projet, nous distinguons deux types de serveurs MCP :

### MCPs internes

Les MCPs internes sont développés dans le sous-module `mcp-servers` de ce dépôt. Nous avons un contrôle total sur leur code source, leur développement et leur maintenance.

| MCP | Description | État |
|-----|------------|------|
| [QuickFiles](./mcp-servers/servers/quickfiles-server/) | Manipulation rapide de fichiers multiples | ✅ Fonctionnel |
| [JinaNavigator](./mcp-servers/servers/jinavigator-server/) | Conversion de pages web en Markdown | ✅ Fonctionnel |
| [Jupyter](./mcp-servers/servers/jupyter-mcp-server/) | Interaction avec des notebooks Jupyter | ✅ Fonctionnel |

### MCPs externes

Les MCPs externes sont des serveurs développés par d'autres équipes ou organisations. Ce dépôt ne contient que les informations d'installation, de configuration et d'utilisation pour ces serveurs.

| MCP | Description | État |
|-----|------------|------|
| [SearXNG](./external-mcps/searxng/) | Recherche web multi-moteurs | ✅ Fonctionnel |
| [Win-CLI](./external-mcps/win-cli/) | Exécution de commandes système Windows | ✅ Fonctionnel |
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
├── OPTIMIZATIONS.md          # Optimisations et améliorations de performance
├── SEARCH.md                 # Guide de recherche dans la documentation
├── TEST-RESULTS.md           # Résultats des derniers tests
├── monitoring/               # Système de surveillance des MCPs
│   ├── README.md             # Documentation du système de surveillance
│   ├── monitor-mcp-servers.js # Script JavaScript de surveillance
│   ├── monitor-mcp-servers.ps1 # Script PowerShell de surveillance
│   ├── logs/                 # Journaux de surveillance
│   └── alerts/               # Alertes générées
├── mcp-servers/              # MCPs internes
│   └── servers/
│       ├── quickfiles-server/
│       ├── jupyter-mcp-server/
│       ├── jinavigator-server/
│       └── ...
├── external-mcps/            # MCPs externes
│   ├── github/
│   ├── searxng/
│   ├── win-cli/
│   ├── jupyter/
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

## Système de surveillance des MCPs

Un nouveau système de surveillance a été mis en place pour détecter et résoudre automatiquement les problèmes avec les serveurs MCP. Ce système offre les fonctionnalités suivantes :

### Fonctionnalités principales

- **Surveillance automatique** : Vérification régulière de l'état des serveurs MCP
- **Détection des problèmes** : Identification des serveurs qui ne répondent pas ou qui ont planté
- **Redémarrage automatique** : Possibilité de redémarrer automatiquement les serveurs défaillants
- **Journalisation** : Enregistrement détaillé des événements et des problèmes
- **Alertes** : Génération d'alertes en cas de problèmes persistants

### Utilisation du système de surveillance

Pour utiliser le système de surveillance, vous pouvez exécuter le script PowerShell :

```powershell
# Surveillance simple
.\mcps\monitoring\monitor-mcp-servers.ps1

# Surveillance avec redémarrage automatique
.\mcps\monitoring\monitor-mcp-servers.ps1 -RestartServers

# Surveillance silencieuse (logs uniquement)
.\mcps\monitoring\monitor-mcp-servers.ps1 -LogOnly
```

Pour plus d'informations sur le système de surveillance, consultez la [documentation dédiée](./monitoring/README.md).

## Serveurs HTTP

Les serveurs MCP basés sur HTTP ont été améliorés avec les fonctionnalités suivantes :

- **Gestion améliorée des connexions** : Meilleure gestion des connexions simultanées et des timeouts
- **Support HTTPS** : Possibilité d'utiliser des connexions sécurisées
- **Compression** : Support de la compression des données pour réduire la bande passante
- **Authentification** : Mécanismes d'authentification améliorés
- **Logging avancé** : Journalisation détaillée des requêtes et des réponses

Pour configurer un serveur MCP HTTP, utilisez le format suivant dans votre fichier de configuration :

```json
{
  "server": {
    "type": "http",
    "port": 3000,
    "host": "localhost",
    "compression": true,
    "https": {
      "enabled": false,
      "key": "path/to/key.pem",
      "cert": "path/to/cert.pem"
    }
  }
}
```

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
- [Guide d'optimisation des MCPs](./OPTIMIZATIONS.md)
