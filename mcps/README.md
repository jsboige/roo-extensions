# Serveurs MCP (Model Context Protocol)

Ce répertoire contient la documentation, les tests et les ressources liées aux serveurs MCP (Model Context Protocol) utilisés dans le projet Roo Extensions.

## Qu'est-ce qu'un MCP ?

Le Model Context Protocol (MCP) est un protocole qui permet à Roo de communiquer avec des serveurs externes pour étendre ses capacités. Ces serveurs peuvent fournir des fonctionnalités supplémentaires comme la recherche web, l'exécution de commandes système, la manipulation de fichiers, et bien plus encore.

## Serveurs MCP disponibles

D'après les tests effectués, les serveurs MCP suivants sont configurés dans le projet :

1. **searxng** - Pour effectuer des recherches web via SearXNG
2. **win-cli** - Pour exécuter des commandes CLI sur Windows
3. **quickfiles** - Pour manipuler rapidement plusieurs fichiers
4. **jupyter** - Pour interagir avec des notebooks Jupyter
5. **jinavigator** - Pour convertir des pages web en Markdown
6. **filesystem** - Pour interagir avec le système de fichiers
7. **git** - Pour effectuer des opérations Git
8. **github** - Pour interagir avec l'API GitHub

## Structure du répertoire

- **`tests/`** - Scripts de test pour vérifier le bon fonctionnement des serveurs MCP
  - `test-quickfiles.js` - Tests pour le MCP QuickFiles
  - `test-jinavigator.js` - Tests pour le MCP JinaNavigator
  - `test-jupyter.js` - Tests pour le MCP Jupyter
  - `run-all-tests.ps1` - Script PowerShell pour exécuter tous les tests
  - `reports/` - Rapports de test générés
- **`SEARCH.md`** - Guide de recherche dans la documentation MCP
- **`TEST-RESULTS.md`** - Résultats des derniers tests effectués sur les serveurs MCP

## Installation et configuration

Pour installer et configurer les serveurs MCP, consultez le [Guide d'utilisation des MCPs](../docs/guides/guide-utilisation-mcps.md).

## Tests

Pour tester les serveurs MCP, consultez le [README des tests](./tests/README.md).

## Fonctionnalités par serveur

### SearXNG
- Recherche web multi-moteurs
- Filtrage par date et type de contenu
- Extraction de contenu web

### Win-CLI
- Exécution de commandes PowerShell, CMD et Git Bash
- Gestion des connexions SSH
- Accès aux fonctionnalités système

### QuickFiles
- Lecture de fichiers multiples en une seule requête
- Listage de répertoires avec options avancées
- Édition et suppression de fichiers multiples
- Recherche dans les fichiers avec contexte

### Jupyter
- Création et manipulation de notebooks Jupyter
- Exécution de code dans des kernels
- Gestion des kernels (démarrage, arrêt, redémarrage)

### JinaNavigator
- Conversion de pages web en Markdown
- Extraction de plans hiérarchiques
- Conversion multiple de pages web

### Filesystem
- Lecture et écriture de fichiers
- Création de répertoires
- Recherche de fichiers
- Manipulation de fichiers (déplacement, suppression)

### Git
- Opérations Git (clone, commit, push, pull)
- Gestion des branches et des tags
- Résolution de conflits

### GitHub
- Gestion des issues et pull requests
- Accès aux informations des dépôts
- Gestion des workflows

## Intégration avec Roo

Les serveurs MCP sont intégrés à Roo via le protocole MCP. Pour plus d'informations sur l'intégration, consultez le [Guide d'utilisation des MCPs](../docs/guides/guide-utilisation-mcps.md).

## Dépannage

Si vous rencontrez des problèmes avec les serveurs MCP, consultez le [Rapport de test des serveurs MCPs](./TEST-RESULTS.md) pour voir les problèmes connus et les solutions recommandées.

## Ressources supplémentaires

- [Guide de recherche dans la documentation MCP](./SEARCH.md)
- [Documentation de la structure de configuration Roo](../docs/guides/documentation-structure-configuration-roo.md)
- [Rapport d'état des MCPs](../docs/rapport-etat-mcps.md)
