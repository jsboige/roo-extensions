# MCP Docker pour Roo

<!-- START_SECTION: introduction -->
## Introduction

Le MCP Docker permet à Roo d'interagir avec Docker via le protocole MCP (Model Context Protocol). Il offre une interface complète pour gérer des conteneurs, des images, des volumes et des réseaux Docker directement depuis l'interface de conversation de Roo.

Ce MCP est basé sur l'image Docker développée par ckreiling, adaptée pour fonctionner avec Roo et exposer toutes les fonctionnalités Docker nécessaires.
<!-- END_SECTION: introduction -->

<!-- START_SECTION: features -->
## Fonctionnalités principales

- **Gestion des conteneurs**: Créer, démarrer, arrêter et supprimer des conteneurs
- **Gestion des images**: Télécharger, construire et supprimer des images Docker
- **Gestion des volumes**: Créer et gérer des volumes pour le stockage persistant
- **Gestion des réseaux**: Créer et configurer des réseaux Docker
- **Docker Compose**: Gérer des applications multi-conteneurs avec Docker Compose
- **Logs et monitoring**: Accéder aux logs et surveiller l'état des conteneurs
- **Exécution de commandes**: Exécuter des commandes dans des conteneurs en cours d'exécution
<!-- END_SECTION: features -->

<!-- START_SECTION: tools -->
## Outils disponibles

Le MCP Docker expose les outils suivants:

| Catégorie | Outils |
|-----------|--------|
| **Conteneurs** | `docker_run`, `docker_ps`, `docker_stop`, `docker_rm`, `docker_logs`, `docker_exec` |
| **Images** | `docker_images`, `docker_pull`, `docker_build`, `docker_rmi` |
| **Volumes** | `docker_volume_ls`, `docker_volume_create`, `docker_volume_rm` |
| **Réseaux** | `docker_network_ls`, `docker_network_create`, `docker_network_rm` |
| **Docker Compose** | `docker_compose_up`, `docker_compose_down` |
| **Inspection** | `docker_inspect` |

Pour une description détaillée de chaque outil et des exemples d'utilisation, consultez le fichier [USAGE.md](./USAGE.md).
<!-- END_SECTION: tools -->

<!-- START_SECTION: structure -->
## Structure de la documentation

- [README.md](./README.md) - Ce fichier d'introduction
- [INSTALLATION.md](./INSTALLATION.md) - Guide d'installation du MCP Docker
- [CONFIGURATION.md](./CONFIGURATION.md) - Guide de configuration du MCP Docker
- [USAGE.md](./USAGE.md) - Exemples d'utilisation et bonnes pratiques
- [TROUBLESHOOTING.md](./TROUBLESHOOTING.md) - Résolution des problèmes courants
- [build-mcp-server-docker.ps1](./build-mcp-server-docker.ps1) - Script PowerShell pour construire l'image Docker
<!-- END_SECTION: structure -->

<!-- START_SECTION: quick_start -->
## Démarrage rapide

1. **Installation**:
   ```powershell
   .\build-mcp-server-docker.ps1
   ```

2. **Configuration**:
   Ajoutez la configuration suivante à votre fichier `mcp_settings.json`:
   ```json
   {
     "mcpServers": [
       {
         "name": "mcp-server-local",
         "type": "stdio",
         "command": "docker",
         "args": [
           "run",
           "-i",
           "--rm",
           "-v",
           "/var/run/docker.sock:/var/run/docker.sock",
           "mcp-server:local"
         ],
         "enabled": true,
         "autoStart": true,
         "description": "Serveur MCP local pour Docker"
       }
     ]
   }
   ```

3. **Utilisation**:
   Redémarrez VS Code et commencez à utiliser les outils Docker dans Roo.

Pour des instructions détaillées, consultez les fichiers [INSTALLATION.md](./INSTALLATION.md) et [CONFIGURATION.md](./CONFIGURATION.md).
<!-- END_SECTION: quick_start -->

<!-- START_SECTION: use_cases -->
## Cas d'utilisation

Le MCP Docker est particulièrement utile pour:

- **Développement d'applications**: Créer et gérer des environnements de développement isolés
- **Déploiement**: Déployer des applications dans des conteneurs
- **Tests**: Exécuter des tests dans des environnements isolés et reproductibles
- **CI/CD**: Intégrer Docker dans des pipelines d'intégration continue
- **Microservices**: Gérer des architectures de microservices
- **Bases de données**: Déployer et gérer des bases de données dans des conteneurs

Pour des exemples détaillés, consultez le fichier [USAGE.md](./USAGE.md#cas-dutilisation).
<!-- END_SECTION: use_cases -->

<!-- START_SECTION: integration -->
## Intégration avec Roo

Le MCP Docker s'intègre parfaitement avec Roo, permettant des interactions naturelles en langage courant. Voici quelques exemples de demandes que vous pouvez faire à Roo:

- "Démarre un conteneur nginx sur le port 8080"
- "Montre-moi les conteneurs en cours d'exécution"
- "Arrête le conteneur mon-nginx"
- "Télécharge l'image postgres:13"
- "Crée un volume pour les données de ma base de données"

Roo traduira automatiquement ces demandes en appels aux outils appropriés du MCP Docker.
<!-- END_SECTION: integration -->

<!-- START_SECTION: security -->
## Considérations de sécurité

L'accès au socket Docker donne un contrôle significatif sur votre système. Voici quelques recommandations de sécurité:

- **Limitez l'accès au socket Docker**: Utilisez des groupes et des permissions appropriés
- **Utilisez des images Docker de confiance**: Vérifiez la source des images Docker que vous utilisez
- **Mettez à jour régulièrement**: Assurez-vous que votre image MCP Docker est régulièrement mise à jour
- **Surveillez l'activité**: Activez la journalisation pour surveiller l'activité du MCP Docker

Pour plus de détails sur la sécurité, consultez les sections correspondantes dans [CONFIGURATION.md](./CONFIGURATION.md#considérations-de-sécurité) et [USAGE.md](./USAGE.md#considérations-de-sécurité).
<!-- END_SECTION: security -->

<!-- START_SECTION: troubleshooting -->
## Résolution des problèmes

Si vous rencontrez des problèmes avec le MCP Docker:

- Consultez le fichier [TROUBLESHOOTING.md](./TROUBLESHOOTING.md) pour des solutions aux problèmes courants
- Vérifiez que Docker est en cours d'exécution sur votre système
- Assurez-vous que le socket Docker est accessible au conteneur MCP
- Examinez les logs du conteneur MCP Docker pour identifier les erreurs

Pour une aide plus détaillée, consultez la section [Obtenir de l'aide](./TROUBLESHOOTING.md#obtenir-de-laide).
<!-- END_SECTION: troubleshooting -->

<!-- START_SECTION: links -->
## Liens utiles

- [Documentation officielle de Docker](https://docs.docker.com/)
- [Spécification du Model Context Protocol](https://github.com/modelcontextprotocol/mcp)
- [Dépôt GitHub de ckreiling/mcp-server-docker](https://github.com/ckreiling/mcp-server-docker)
- [Documentation de Roo](https://docs.roo.ai)
<!-- END_SECTION: links -->