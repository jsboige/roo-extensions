# MCP Git pour Roo

<!-- START_SECTION: introduction -->
## Introduction

Le MCP Git permet à Roo d'interagir avec des dépôts Git via le protocole MCP (Model Context Protocol). Il offre une interface complète pour gérer des dépôts Git, effectuer des commits, des push, des pull, et bien d'autres opérations Git directement depuis l'interface de conversation de Roo.

Ce MCP est essentiel pour les développeurs qui souhaitent intégrer la gestion de version dans leurs workflows avec Roo, permettant une collaboration fluide et un suivi efficace des modifications de code.
<!-- END_SECTION: introduction -->

<!-- START_SECTION: features -->
## Fonctionnalités principales

- **Gestion des dépôts**: Initialiser, cloner et gérer des dépôts Git
- **Gestion des commits**: Ajouter des fichiers à l'index et créer des commits
- **Synchronisation**: Pousser et récupérer des modifications depuis des dépôts distants
- **Gestion des branches**: Créer, lister, basculer et supprimer des branches
- **Gestion des tags**: Créer, lister et supprimer des tags
- **Gestion des dépôts distants**: Ajouter, lister et supprimer des dépôts distants
- **Gestion des stash**: Sauvegarder, lister et appliquer des modifications temporaires
- **Actions en masse**: Exécuter plusieurs opérations Git en séquence
<!-- END_SECTION: features -->

<!-- START_SECTION: tools -->
## Outils disponibles

Le MCP Git expose les outils suivants:

| Catégorie | Outils |
|-----------|--------|
| **Dépôts** | `init`, `clone`, `status` |
| **Commits** | `add`, `commit` |
| **Synchronisation** | `push`, `pull` |
| **Branches** | `branch_list`, `branch_create`, `branch_delete`, `checkout` |
| **Tags** | `tag_list`, `tag_create`, `tag_delete` |
| **Dépôts distants** | `remote_list`, `remote_add`, `remote_remove` |
| **Stash** | `stash_list`, `stash_save`, `stash_pop` |
| **Actions en masse** | `bulk_action` |

Pour une description détaillée de chaque outil et des exemples d'utilisation, consultez le fichier [USAGE.md](./USAGE.md).
<!-- END_SECTION: tools -->

<!-- START_SECTION: structure -->
## Structure de la documentation

- [README.md](./README.md) - Ce fichier d'introduction
- [INSTALLATION.md](./INSTALLATION.md) - Guide d'installation du MCP Git
- [CONFIGURATION.md](./CONFIGURATION.md) - Guide de configuration du MCP Git
- [USAGE.md](./USAGE.md) - Exemples d'utilisation et bonnes pratiques
- [TROUBLESHOOTING.md](./TROUBLESHOOTING.md) - Résolution des problèmes courants
<!-- END_SECTION: structure -->

<!-- START_SECTION: quick_start -->
## Démarrage rapide

1. **Installation**:
   ```bash
   npm install -g @modelcontextprotocol/server-git
   ```

2. **Configuration**:
   Ajoutez la configuration suivante à votre fichier `mcp_settings.json`:
   ```json
   {
     "mcpServers": [
       {
         "name": "git",
         "type": "stdio",
         "command": "npx",
         "args": [
           "-y",
           "@modelcontextprotocol/server-git"
         ],
         "enabled": true,
         "autoStart": true,
         "description": "Serveur MCP pour interagir avec Git"
       }
     ]
   }
   ```

3. **Utilisation**:
   Redémarrez VS Code et commencez à utiliser les outils Git dans Roo.

Pour des instructions détaillées, consultez les fichiers [INSTALLATION.md](./INSTALLATION.md) et [CONFIGURATION.md](./CONFIGURATION.md).
<!-- END_SECTION: quick_start -->

<!-- START_SECTION: use_cases -->
## Cas d'utilisation

Le MCP Git est particulièrement utile pour:

- **Gestion de version**: Suivre les modifications de code et collaborer avec d'autres développeurs
- **Développement de fonctionnalités**: Créer des branches pour développer des fonctionnalités isolées
- **Déploiement**: Automatiser les processus de déploiement basés sur Git
- **Collaboration**: Faciliter la collaboration entre développeurs via des dépôts partagés
- **Sauvegarde**: Maintenir des sauvegardes distribuées de votre code
- **Intégration continue**: S'intégrer dans des workflows CI/CD

Pour des exemples détaillés, consultez le fichier [USAGE.md](./USAGE.md#cas-dutilisation).
<!-- END_SECTION: use_cases -->

<!-- START_SECTION: integration -->
## Intégration avec Roo

Le MCP Git s'intègre parfaitement avec Roo, permettant des interactions naturelles en langage courant. Voici quelques exemples de demandes que vous pouvez faire à Roo:

- "Clone le dépôt https://github.com/utilisateur/depot.git"
- "Crée une nouvelle branche appelée feature/search"
- "Ajoute tous les fichiers modifiés et crée un commit avec le message 'Ajout de la fonctionnalité de recherche'"
- "Pousse mes modifications vers origin"
- "Montre-moi l'état actuel du dépôt"
- "Liste toutes les branches du projet"

Roo traduira automatiquement ces demandes en appels aux outils appropriés du MCP Git.
<!-- END_SECTION: integration -->

<!-- START_SECTION: security -->
## Considérations de sécurité

L'utilisation du MCP Git implique certains risques de sécurité qu'il est important de prendre en compte:

- **Informations d'identification**: Évitez de stocker des informations d'identification en texte clair
- **Branches protégées**: Configurez des protections pour les branches importantes
- **Informations sensibles**: Évitez de committer des informations sensibles (mots de passe, clés API, etc.)
- **Audit**: Activez la journalisation pour surveiller les opérations Git
- **Permissions**: Limitez l'accès aux dépôts contenant des informations sensibles

Pour une utilisation sécurisée:
- Utilisez SSH plutôt que HTTPS lorsque c'est possible
- Utilisez des jetons d'accès personnels avec des permissions limitées
- Signez vos commits pour garantir leur authenticité
- Maintenez Git et le MCP Git à jour avec les dernières corrections de sécurité

Pour plus de détails sur la sécurité, consultez les sections correspondantes dans [CONFIGURATION.md](./CONFIGURATION.md#considérations-de-sécurité) et [USAGE.md](./USAGE.md#considérations-de-sécurité).
<!-- END_SECTION: security -->

<!-- START_SECTION: troubleshooting -->
## Résolution des problèmes

Si vous rencontrez des problèmes avec le MCP Git:

- Consultez le fichier [TROUBLESHOOTING.md](./TROUBLESHOOTING.md) pour des solutions aux problèmes courants
- Vérifiez que Git est correctement installé et accessible dans le PATH
- Assurez-vous que votre configuration Git est correcte
- Examinez les logs du serveur MCP pour identifier les erreurs

Pour une aide plus détaillée, consultez la section [Obtenir de l'aide](./TROUBLESHOOTING.md#obtenir-de-laide).
<!-- END_SECTION: troubleshooting -->

<!-- START_SECTION: links -->
## Liens utiles

- [Documentation officielle de Git](https://git-scm.com/doc)
- [Dépôt GitHub du MCP Git](https://github.com/modelcontextprotocol/servers/tree/main/src/git)
- [Spécification du Model Context Protocol](https://github.com/modelcontextprotocol/mcp)
- [Documentation de Roo](https://docs.roo.ai)
<!-- END_SECTION: links -->