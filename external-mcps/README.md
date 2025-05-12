# MCPs Externes pour Roo

Ce dossier contient la documentation et les instructions pour l'installation et la configuration des serveurs MCP (Model Context Protocol) externes utilisés avec Roo. Ces MCPs sont pleinement intégrés dans l'architecture à 5 niveaux (n5) et optimisés pour chaque niveau de complexité.

## Qu'est-ce qu'un MCP ?

Le Model Context Protocol (MCP) est un protocole qui permet à Roo de communiquer avec des serveurs externes pour étendre ses capacités. Ces serveurs peuvent fournir des outils supplémentaires et des ressources qui ne sont pas disponibles nativement dans Roo.

## Structure du dossier

Ce dossier est organisé par serveur MCP :

- `searxng/` - Documentation pour le serveur MCP SearXNG (recherche web)
- `win-cli/` - Documentation pour le serveur MCP Win-CLI (commandes Windows)
- (D'autres serveurs MCP seront ajoutés au fur et à mesure)

Chaque sous-dossier contient :
- Un guide d'installation
- Un guide de configuration
- Des exemples d'utilisation
- Des notes sur les personnalisations spécifiques

## Serveurs MCP disponibles

### SearXNG

SearXNG est un métamoteur de recherche qui permet d'effectuer des recherches web via différents moteurs de recherche. Le serveur MCP SearXNG permet à Roo d'effectuer des recherches web et d'accéder aux résultats.

**Intégration avec l'architecture n5** :
- Utilisé prioritairement dans les niveaux MEDIUM à ORACLE
- Optimisé pour la recherche d'informations contextuelles
- Permet de réduire la consommation de tokens en fournissant des informations ciblées

### Win-CLI

Win-CLI est un serveur MCP qui permet à Roo d'exécuter des commandes dans différents shells Windows (PowerShell, CMD, Git Bash). Il offre également des fonctionnalités pour la gestion des connexions SSH.

**Intégration avec l'architecture n5** :
- Utilisé dans tous les niveaux de complexité
- Prioritaire par rapport aux outils standards de terminal
- Optimisé pour l'exécution efficace de commandes système
- Permet une meilleure gestion des ressources système

### Autres MCPs en développement

D'autres serveurs MCP sont en cours de développement pour étendre davantage les capacités de Roo dans l'architecture à 5 niveaux :
- **QuickFiles** - Pour la manipulation efficace de fichiers
- **JinaNavigator** - Pour la navigation et l'extraction de contenu web

## Comment ajouter un nouveau serveur MCP

Pour ajouter un nouveau serveur MCP à cette documentation :

1. Créez un nouveau sous-dossier avec le nom du serveur MCP
2. Ajoutez un fichier `README.md` décrivant le serveur MCP
3. Ajoutez un guide d'installation (`installation.md`)
4. Ajoutez un guide de configuration (`configuration.md`)
5. Ajoutez des exemples d'utilisation (`exemples.md`)
6. Mettez à jour ce fichier README.md pour inclure le nouveau serveur MCP

## Contribution

N'hésitez pas à contribuer à cette documentation en ajoutant de nouveaux serveurs MCP ou en améliorant la documentation existante.

## Utilisation dans l'architecture à 5 niveaux

Pour plus d'informations sur l'utilisation optimale des MCPs dans l'architecture à 5 niveaux, consultez le document `docs/guide-utilisation-mcps.md` à la racine du projet.

Ce guide détaille :
- La stratégie d'utilisation des MCPs selon le niveau de complexité
- Les bonnes pratiques pour optimiser les performances
- Les cas d'usage recommandés pour chaque MCP
- Les exemples d'intégration dans différents scénarios