# MCPs Externes pour Roo

Ce dossier contient la documentation et les instructions pour l'installation et la configuration des serveurs MCP (Model Context Protocol) externes utilisés avec Roo.

## Qu'est-ce qu'un MCP ?

Le Model Context Protocol (MCP) est un protocole qui permet à Roo de communiquer avec des serveurs externes pour étendre ses capacités. Ces serveurs peuvent fournir des outils supplémentaires et des ressources qui ne sont pas disponibles nativement dans Roo.

## MCPs Externes vs MCPs Internes

Les MCPs externes sont des outils tiers qui ont été adaptés pour fonctionner avec Roo. Ils nécessitent une installation et une configuration spécifiques, généralement via npm ou d'autres gestionnaires de paquets. Contrairement aux [MCPs internes](../internal-mcps/README.md) qui sont développés spécifiquement pour Roo dans des dépôts dédiés, les MCPs externes sont maintenus par des tiers et peuvent être utilisés indépendamment de Roo.

## Structure du dossier

Ce dossier est organisé par serveur MCP externe :

- `git-mcp/` - Documentation pour le serveur MCP Git (opérations Git locales)
- `github-mcp/` - Documentation pour le serveur MCP GitHub (API GitHub)
- `searxng/` - Documentation pour le serveur MCP SearXNG (recherche web)
- `win-cli/` - Documentation pour le serveur MCP Win-CLI (commandes Windows)

Chaque sous-dossier contient :
- Un guide d'installation
- Un guide de configuration
- Des exemples d'utilisation
- Des notes sur les personnalisations spécifiques

## Serveurs MCP disponibles

### Git MCP

Git MCP est un serveur MCP qui permet à Roo d'interagir avec des dépôts Git locaux. Il offre des fonctionnalités pour effectuer des opérations Git courantes comme commit, push, pull, branch, status, diff, etc. Ce serveur est particulièrement utile pour automatiser les workflows Git et intégrer la gestion de version dans les tâches de développement.

### GitHub MCP

GitHub MCP est un serveur MCP qui permet à Roo d'interagir avec l'API GitHub. Il offre des fonctionnalités pour la gestion des dépôts, des issues, des pull requests, et d'autres ressources GitHub. Ce serveur est utile pour automatiser les workflows GitHub et intégrer GitHub dans les tâches de développement.

### SearXNG

SearXNG est un métamoteur de recherche qui permet d'effectuer des recherches web via différents moteurs de recherche. Le serveur MCP SearXNG permet à Roo d'effectuer des recherches web et d'accéder aux résultats.

### Win-CLI

Win-CLI est un serveur MCP qui permet à Roo d'exécuter des commandes dans différents shells Windows (PowerShell, CMD, Git Bash). Il offre également des fonctionnalités pour la gestion des connexions SSH.

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