# MCP GitHub pour Roo

<!-- START_SECTION: introduction -->
## Introduction

Le MCP GitHub permet à Roo d'interagir avec l'API GitHub via le protocole MCP (Model Context Protocol). Il offre une interface complète pour gérer des dépôts, des issues, des pull requests et bien d'autres fonctionnalités GitHub directement depuis l'interface de conversation de Roo.

Ce MCP est essentiel pour les développeurs qui souhaitent intégrer la gestion de leurs projets GitHub dans leurs workflows avec Roo, permettant une collaboration fluide et une automatisation des tâches GitHub courantes.
<!-- END_SECTION: introduction -->

<!-- START_SECTION: features -->
## Fonctionnalités principales

- **Gestion des dépôts**: Créer, rechercher et forker des dépôts GitHub
- **Gestion des fichiers**: Créer, mettre à jour et obtenir le contenu des fichiers
- **Gestion des issues**: Créer, lister, mettre à jour et commenter des issues
- **Gestion des pull requests**: Créer, lister, réviser et fusionner des pull requests
- **Gestion des branches**: Créer des branches et lister les commits
- **Recherche**: Rechercher des dépôts, du code, des issues et des utilisateurs
- **Automatisation**: Effectuer des opérations GitHub en masse
<!-- END_SECTION: features -->

<!-- START_SECTION: tools -->
## Outils disponibles

Le MCP GitHub expose les outils suivants:

| Catégorie | Outils |
|-----------|--------|
| **Dépôts** | `search_repositories`, `create_repository`, `fork_repository` |
| **Fichiers** | `get_file_contents`, `create_or_update_file`, `push_files` |
| **Issues** | `create_issue`, `list_issues`, `update_issue`, `add_issue_comment`, `get_issue`, `search_issues` |
| **Pull Requests** | `create_pull_request`, `list_pull_requests`, `get_pull_request`, `create_pull_request_review`, `merge_pull_request` |
| **Branches** | `create_branch`, `list_commits` |
| **Recherche** | `search_code`, `search_users` |

Pour une description détaillée de chaque outil et des exemples d'utilisation, consultez le fichier [USAGE.md](./USAGE.md).
<!-- END_SECTION: tools -->

<!-- START_SECTION: structure -->
## Structure de la documentation

- [README.md](./README.md) - Ce fichier d'introduction
- [INSTALLATION.md](./INSTALLATION.md) - Guide d'installation du MCP GitHub
- [CONFIGURATION.md](./CONFIGURATION.md) - Guide de configuration du MCP GitHub
- [USAGE.md](./USAGE.md) - Exemples d'utilisation et bonnes pratiques
- [TROUBLESHOOTING.md](./TROUBLESHOOTING.md) - Résolution des problèmes courants
<!-- END_SECTION: structure -->

<!-- START_SECTION: quick_start -->
## Démarrage rapide

1. **Installation**:
   ```bash
   npm install -g @modelcontextprotocol/server-github
   ```

2. **Création d'un token GitHub**:
   - Accédez à GitHub > Settings > Developer settings > Personal access tokens
   - Cliquez sur "Generate new token"
   - Sélectionnez les permissions nécessaires (au minimum `repo` pour les dépôts privés)
   - Copiez le token généré

3. **Configuration**:
   Ajoutez la configuration suivante à votre fichier `mcp_settings.json`:
   ```json
   {
     "mcpServers": [
       {
         "name": "github",
         "type": "stdio",
         "command": "npx",
         "args": [
           "-y",
           "@modelcontextprotocol/server-github",
           "--token",
           "votre_token_github"
         ],
         "enabled": true,
         "autoStart": true,
         "description": "Serveur MCP pour interagir avec GitHub"
       }
     ]
   }
   ```

4. **Utilisation**:
   Redémarrez VS Code et commencez à utiliser les outils GitHub dans Roo.

Pour des instructions détaillées, consultez les fichiers [INSTALLATION.md](./INSTALLATION.md) et [CONFIGURATION.md](./CONFIGURATION.md).
<!-- END_SECTION: quick_start -->

<!-- START_SECTION: use_cases -->
## Cas d'utilisation

Le MCP GitHub est particulièrement utile pour:

- **Gestion de projets**: Créer et gérer des dépôts, des issues et des pull requests
- **Collaboration**: Faciliter la collaboration entre développeurs via GitHub
- **Revue de code**: Examiner et commenter des pull requests
- **Automatisation**: Automatiser des tâches GitHub répétitives
- **Documentation**: Créer et mettre à jour la documentation dans des dépôts GitHub
- **Recherche de code**: Trouver des exemples de code ou des solutions dans GitHub

Pour des exemples détaillés, consultez le fichier [USAGE.md](./USAGE.md#cas-dutilisation).
<!-- END_SECTION: use_cases -->

<!-- START_SECTION: integration -->
## Intégration avec Roo

Le MCP GitHub s'intègre parfaitement avec Roo, permettant des interactions naturelles en langage courant. Voici quelques exemples de demandes que vous pouvez faire à Roo:

- "Crée un nouveau dépôt GitHub appelé mon-projet"
- "Recherche des dépôts JavaScript avec plus de 1000 étoiles"
- "Crée une issue dans mon-projet pour signaler un bug dans la fonction de recherche"
- "Crée une pull request pour fusionner ma branche feature/search dans main"
- "Montre-moi les derniers commits dans mon-projet"
- "Liste les issues ouvertes dans mon-projet avec le label bug"

Roo traduira automatiquement ces demandes en appels aux outils appropriés du MCP GitHub.
<!-- END_SECTION: integration -->

<!-- START_SECTION: security -->
## Considérations de sécurité

L'utilisation du MCP GitHub implique certains risques de sécurité qu'il est important de prendre en compte:

- **Protection du token**: Ne partagez jamais votre token GitHub dans des dépôts publics ou des messages
- **Permissions minimales**: Accordez uniquement les permissions nécessaires à votre token
- **Renouvellement régulier**: Renouvelez régulièrement votre token pour limiter les risques
- **Audit**: Surveillez l'utilisation de votre token pour détecter toute activité suspecte
- **Validation des entrées**: Validez toutes les entrées avant de les envoyer à l'API GitHub

Pour une utilisation sécurisée:
- Utilisez des variables d'environnement pour stocker votre token
- Créez des tokens différents pour différents environnements
- Définissez une date d'expiration pour vos tokens
- Révoquez immédiatement les tokens compromis

Pour plus de détails sur la sécurité, consultez les sections correspondantes dans [CONFIGURATION.md](./CONFIGURATION.md#considérations-de-sécurité) et [USAGE.md](./USAGE.md#considérations-de-sécurité).
<!-- END_SECTION: security -->

<!-- START_SECTION: troubleshooting -->
## Résolution des problèmes

Si vous rencontrez des problèmes avec le MCP GitHub:

- Consultez le fichier [TROUBLESHOOTING.md](./TROUBLESHOOTING.md) pour des solutions aux problèmes courants
- Vérifiez que votre token GitHub est valide et dispose des permissions nécessaires
- Assurez-vous que vous n'avez pas dépassé les limites de taux de l'API GitHub
- Examinez les logs du serveur MCP pour identifier les erreurs

Pour une aide plus détaillée, consultez la section [Obtenir de l'aide](./TROUBLESHOOTING.md#obtenir-de-laide).
<!-- END_SECTION: troubleshooting -->

<!-- START_SECTION: links -->
## Liens utiles

- [Documentation officielle de l'API GitHub](https://docs.github.com/en/rest)
- [Dépôt GitHub du MCP GitHub](https://github.com/modelcontextprotocol/servers/tree/main/src/github)
- [Spécification du Model Context Protocol](https://github.com/modelcontextprotocol/mcp)
- [Documentation de Roo](https://docs.roo.ai)
<!-- END_SECTION: links -->