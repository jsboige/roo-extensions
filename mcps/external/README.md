# Documentation des MCPs Externes pour Roo

<!-- START_SECTION: introduction -->
## Introduction

Ce répertoire contient la documentation détaillée des serveurs MCP (Model Context Protocol) externes compatibles avec Roo. Les MCPs externes étendent les capacités de Roo en lui permettant d'interagir avec divers services et systèmes, comme Docker, Git, GitHub, le système de fichiers, les moteurs de recherche et les shells système.

Cette documentation est conçue pour vous aider à installer, configurer et utiliser efficacement ces MCPs externes avec Roo, ainsi qu'à résoudre les problèmes courants que vous pourriez rencontrer.
<!-- END_SECTION: introduction -->

<!-- START_SECTION: available_mcps -->
## MCPs Externes Disponibles

| MCP | Description | Fonctionnalités principales |
|-----|-------------|----------------------------|
| [Docker](./docker/) | Interaction avec Docker | Gestion des conteneurs, images, volumes et réseaux Docker |
| [Filesystem](./filesystem/) | Opérations sur le système de fichiers | Lecture, écriture, recherche et manipulation de fichiers |
| [Git](./git/) | Gestion de dépôts Git | Commits, branches, tags, push/pull, et autres opérations Git |
| [GitHub](./github/) | Interaction avec l'API GitHub | Gestion de dépôts, issues, pull requests et autres fonctionnalités GitHub |
| [SearXNG](./searxng/) | Recherche web privée | Recherche web via SearXNG et lecture de contenu web |
| [Win-CLI](./win-cli/) | Exécution de commandes Windows | Exécution de commandes dans différents shells Windows et gestion SSH |
<!-- END_SECTION: available_mcps -->

<!-- START_SECTION: documentation_structure -->
## Structure de la Documentation

Chaque MCP externe dispose d'une documentation complète organisée selon la structure suivante:

- **README.md** - Présentation générale, fonctionnalités et cas d'utilisation
- **INSTALLATION.md** - Instructions d'installation détaillées
- **CONFIGURATION.md** - Options de configuration et personnalisation
- **USAGE.md** - Exemples d'utilisation et bonnes pratiques
- **TROUBLESHOOTING.md** - Résolution des problèmes courants

Cette structure standardisée facilite la navigation et la recherche d'informations spécifiques pour chaque MCP.
<!-- END_SECTION: documentation_structure -->

<!-- START_SECTION: general_installation -->
## Installation Générale des MCPs

Bien que chaque MCP ait ses propres instructions d'installation spécifiques, voici les étapes générales pour installer et configurer un MCP externe:

1. **Installation du serveur MCP**:
   ```bash
   npm install -g @modelcontextprotocol/server-nom-du-mcp
   ```

2. **Configuration dans Roo**:
   - Ouvrez VS Code avec l'extension Roo
   - Accédez aux paramètres de Roo (via l'icône de menu ⋮)
   - Allez dans la section "MCP Servers"
   - Ajoutez une nouvelle configuration pour le serveur MCP
   - Sauvegardez les paramètres
   - Redémarrez VS Code

3. **Vérification**:
   - Assurez-vous que le serveur MCP apparaît dans la liste des serveurs connectés
   - Testez les fonctionnalités de base pour vérifier que tout fonctionne correctement

Pour des instructions détaillées spécifiques à chaque MCP, consultez le fichier INSTALLATION.md correspondant.
<!-- END_SECTION: general_installation -->

<!-- START_SECTION: best_practices -->
## Bonnes Pratiques

### Sécurité

- **Privilèges minimaux**: Configurez les MCPs avec les privilèges minimaux nécessaires
- **Validation des entrées**: Validez toutes les entrées avant de les utiliser dans des commandes
- **Stockage sécurisé**: Stockez les informations d'identification (tokens, mots de passe) de manière sécurisée
- **Mise à jour régulière**: Maintenez les MCPs à jour pour bénéficier des dernières corrections de sécurité

### Performance

- **Utilisation ciblée**: Utilisez le MCP le plus approprié pour chaque tâche
- **Optimisation des requêtes**: Limitez le nombre et la taille des requêtes pour éviter les problèmes de performance
- **Mise en cache**: Utilisez des mécanismes de mise en cache lorsque c'est possible
- **Gestion des ressources**: Fermez les connexions et libérez les ressources après utilisation

### Intégration avec Roo

- **Commandes claires**: Formulez des commandes claires et précises pour Roo
- **Vérification des résultats**: Vérifiez toujours les résultats des opérations
- **Gestion des erreurs**: Prévoyez des mécanismes de gestion des erreurs
- **Documentation**: Documentez vos workflows et configurations personnalisées
<!-- END_SECTION: best_practices -->

<!-- START_SECTION: troubleshooting -->
## Résolution des Problèmes Courants

### Problèmes de connexion

Si un serveur MCP ne se connecte pas à Roo:
- Vérifiez que le serveur MCP est correctement installé et en cours d'exécution
- Vérifiez la configuration dans le fichier `mcp_settings.json` de Roo
- Redémarrez VS Code pour recharger la configuration
- Consultez les journaux pour identifier les erreurs spécifiques

### Erreurs d'exécution

Si vous rencontrez des erreurs lors de l'utilisation d'un MCP:
- Vérifiez que vous utilisez la syntaxe correcte pour les commandes
- Assurez-vous que vous avez les permissions nécessaires
- Consultez la documentation spécifique du MCP pour les erreurs courantes
- Vérifiez les prérequis système (versions de logiciels, dépendances, etc.)

Pour une résolution plus détaillée des problèmes, consultez le fichier TROUBLESHOOTING.md de chaque MCP.
<!-- END_SECTION: troubleshooting -->

<!-- START_SECTION: contributing -->
## Contribution

Vous pouvez contribuer à l'amélioration de cette documentation de plusieurs façons:

1. **Signaler des erreurs**: Si vous trouvez des erreurs ou des informations obsolètes, signalez-les
2. **Proposer des améliorations**: Suggérez des améliorations pour rendre la documentation plus claire ou plus complète
3. **Ajouter des exemples**: Partagez des exemples d'utilisation pratiques des MCPs
4. **Documenter de nouveaux MCPs**: Contribuez à la documentation de nouveaux MCPs externes

Pour contribuer, veuillez suivre la structure de documentation standardisée et vous assurer que vos contributions sont claires, précises et utiles.
<!-- END_SECTION: contributing -->

<!-- START_SECTION: resources -->
## Ressources Supplémentaires

- [Documentation officielle de Roo](https://docs.roo.ai)
- [Spécification du Model Context Protocol](https://github.com/modelcontextprotocol/mcp)
- [Forum de la communauté Roo](https://community.roo.ai)
- [Dépôt GitHub des serveurs MCP](https://github.com/modelcontextprotocol/servers)
<!-- END_SECTION: resources -->