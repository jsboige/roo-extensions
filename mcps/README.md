# MCPs Externes

Ce dossier contient tous les MCPs (Model Context Protocol) externes disponibles pour étendre les capacités de Roo.

## MCPs disponibles

### SearXNG
- **Description** : Intégration avec le moteur de recherche SearXNG pour permettre à Roo d'effectuer des recherches web.
- **Fonctionnalités** : Recherche web, lecture de contenu d'URL.
- **Dossier** : [searxng/](./searxng/)

### Win-CLI
- **Description** : Intégration avec l'interface en ligne de commande Windows pour exécuter des commandes système.
- **Fonctionnalités** : Exécution de commandes PowerShell, CMD et Git Bash, gestion des connexions SSH.
- **Dossier** : [win-cli/](./win-cli/)

### Git
- **Description** : Intégration avec Git pour la gestion de versions.
- **Fonctionnalités** : Opérations Git courantes (clone, commit, push, pull, etc.).
- **Dossier** : [git/](./git/)

### GitHub
- **Description** : Intégration avec l'API GitHub pour interagir avec les dépôts GitHub.
- **Fonctionnalités** : Gestion des issues, pull requests, et autres fonctionnalités GitHub.
- **Dossier** : [github/](./github/)

## Utilisation avec l'architecture à 5 niveaux (N5)

Les MCPs externes peuvent être utilisés avec tous les niveaux de l'architecture N5, mais leur utilisation est optimisée selon le niveau de complexité :

- **Micro/Mini** : Utilisation basique des MCPs avec des requêtes simples
- **Medium** : Utilisation intermédiaire avec des requêtes plus complexes
- **Large/Oracle** : Utilisation avancée avec orchestration de plusieurs MCPs

## Installation

Chaque MCP a ses propres instructions d'installation. Consultez le README.md dans chaque sous-dossier pour des instructions spécifiques.

## Configuration

Pour configurer un MCP dans Roo, vous devez ajouter sa configuration dans le fichier `servers.json` de Roo. Voici un exemple de configuration :

```json
{
  "servers": [
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

## Développement de nouveaux MCPs

Pour développer un nouveau MCP, vous pouvez vous inspirer des MCPs existants. Un MCP doit implémenter le protocole MCP (Model Context Protocol) et exposer des outils et/ou des ressources.

## Dépannage

Si un MCP ne fonctionne pas correctement, vérifiez les points suivants :
1. Le MCP est-il correctement installé ?
2. Le MCP est-il correctement configuré dans `servers.json` ?
3. Le MCP est-il démarré ?
4. Y a-t-il des erreurs dans les logs ?

Pour plus d'informations, consultez le [guide d'utilisation des MCPs](../docs/guide-utilisation-mcps.md).
