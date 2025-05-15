# MCP Filesystem pour Roo

<!-- START_SECTION: introduction -->
## Introduction

Le MCP Filesystem permet à Roo d'interagir avec le système de fichiers local via le protocole MCP (Model Context Protocol). Il offre une interface complète pour lire, écrire, modifier et gérer des fichiers et répertoires directement depuis l'interface de conversation de Roo.

Ce MCP est essentiel pour permettre à Roo d'accéder aux fichiers locaux de manière sécurisée et contrôlée, en limitant l'accès aux répertoires spécifiés dans la configuration.
<!-- END_SECTION: introduction -->

<!-- START_SECTION: features -->
## Fonctionnalités principales

- **Lecture de fichiers**: Lire le contenu de fichiers individuels ou multiples
- **Écriture de fichiers**: Créer ou modifier des fichiers avec un nouveau contenu
- **Édition de fichiers**: Modifier des portions spécifiques de fichiers existants
- **Gestion de répertoires**: Créer, lister et explorer des structures de répertoires
- **Recherche de fichiers**: Rechercher des fichiers correspondant à des motifs spécifiques
- **Métadonnées de fichiers**: Obtenir des informations détaillées sur les fichiers et répertoires
- **Sécurité intégrée**: Limitation de l'accès aux répertoires autorisés uniquement
<!-- END_SECTION: features -->

<!-- START_SECTION: tools -->
## Outils disponibles

Le MCP Filesystem expose les outils suivants:

| Catégorie | Outils |
|-----------|--------|
| **Lecture** | `read_file`, `read_multiple_files` |
| **Écriture** | `write_file`, `edit_file` |
| **Répertoires** | `create_directory`, `list_directory`, `directory_tree` |
| **Gestion de fichiers** | `move_file`, `search_files`, `get_file_info` |
| **Configuration** | `list_allowed_directories` |

Pour une description détaillée de chaque outil et des exemples d'utilisation, consultez le fichier [USAGE.md](./USAGE.md).
<!-- END_SECTION: tools -->

<!-- START_SECTION: structure -->
## Structure de la documentation

- [README.md](./README.md) - Ce fichier d'introduction
- [INSTALLATION.md](./INSTALLATION.md) - Guide d'installation du MCP Filesystem
- [CONFIGURATION.md](./CONFIGURATION.md) - Guide de configuration du MCP Filesystem
- [USAGE.md](./USAGE.md) - Exemples d'utilisation et bonnes pratiques
- [TROUBLESHOOTING.md](./TROUBLESHOOTING.md) - Résolution des problèmes courants
<!-- END_SECTION: structure -->

<!-- START_SECTION: quick_start -->
## Démarrage rapide

1. **Installation**:
   ```bash
   npm install -g @modelcontextprotocol/server-filesystem
   ```

2. **Configuration**:
   Ajoutez la configuration suivante à votre fichier `mcp_settings.json`:
   ```json
   {
     "mcpServers": [
       {
         "name": "filesystem",
         "type": "stdio",
         "command": "npx",
         "args": [
           "-y",
           "@modelcontextprotocol/server-filesystem",
           "/chemin/vers/repertoire/autorise"
         ],
         "enabled": true,
         "autoStart": true,
         "description": "Serveur MCP pour accéder au système de fichiers"
       }
     ]
   }
   ```

3. **Utilisation**:
   Redémarrez VS Code et commencez à utiliser les outils du système de fichiers dans Roo.

Pour des instructions détaillées, consultez les fichiers [INSTALLATION.md](./INSTALLATION.md) et [CONFIGURATION.md](./CONFIGURATION.md).
<!-- END_SECTION: quick_start -->

<!-- START_SECTION: use_cases -->
## Cas d'utilisation

Le MCP Filesystem est particulièrement utile pour:

- **Développement de logiciels**: Accéder et modifier des fichiers de code source
- **Gestion de projets**: Explorer et organiser des structures de projets
- **Analyse de données**: Lire et traiter des fichiers de données
- **Documentation**: Créer et mettre à jour des fichiers de documentation
- **Configuration**: Modifier des fichiers de configuration
- **Automatisation**: Effectuer des opérations de fichiers dans le cadre de workflows automatisés

Pour des exemples détaillés, consultez le fichier [USAGE.md](./USAGE.md#cas-dutilisation).
<!-- END_SECTION: use_cases -->

<!-- START_SECTION: integration -->
## Intégration avec Roo

Le MCP Filesystem s'intègre parfaitement avec Roo, permettant des interactions naturelles en langage courant. Voici quelques exemples de demandes que vous pouvez faire à Roo:

- "Montre-moi le contenu du fichier config.json"
- "Crée un nouveau répertoire pour mon projet"
- "Liste tous les fichiers JavaScript dans le répertoire src"
- "Modifie le fichier README.md pour mettre à jour la section d'installation"
- "Recherche tous les fichiers contenant le mot 'TODO' dans le projet"

Roo traduira automatiquement ces demandes en appels aux outils appropriés du MCP Filesystem.
<!-- END_SECTION: integration -->

<!-- START_SECTION: security -->
## Considérations de sécurité

L'accès au système de fichiers présente des risques de sécurité importants. Le MCP Filesystem implémente plusieurs mesures de sécurité:

- **Limitation des répertoires**: Accès limité aux répertoires explicitement autorisés
- **Validation des chemins**: Prévention des attaques par traversée de répertoire
- **Contrôle des opérations**: Restrictions sur les types d'opérations autorisées
- **Journalisation**: Enregistrement des opérations effectuées pour l'audit

Pour une utilisation sécurisée:
- N'autorisez l'accès qu'aux répertoires strictement nécessaires
- Évitez d'autoriser l'accès aux répertoires système ou sensibles
- Utilisez des répertoires dédiés pour les opérations du MCP Filesystem
- Maintenez le MCP Filesystem à jour avec les dernières corrections de sécurité

Pour plus de détails sur la sécurité, consultez les sections correspondantes dans [CONFIGURATION.md](./CONFIGURATION.md#considérations-de-sécurité) et [USAGE.md](./USAGE.md#considérations-de-sécurité).
<!-- END_SECTION: security -->

<!-- START_SECTION: troubleshooting -->
## Résolution des problèmes

Si vous rencontrez des problèmes avec le MCP Filesystem:

- Consultez le fichier [TROUBLESHOOTING.md](./TROUBLESHOOTING.md) pour des solutions aux problèmes courants
- Vérifiez que les répertoires autorisés sont correctement configurés
- Assurez-vous que les chemins utilisés sont dans des répertoires autorisés
- Examinez les logs du serveur MCP pour identifier les erreurs

Pour une aide plus détaillée, consultez la section [Obtenir de l'aide](./TROUBLESHOOTING.md#obtenir-de-laide).
<!-- END_SECTION: troubleshooting -->

<!-- START_SECTION: links -->
## Liens utiles

- [Dépôt GitHub du MCP Filesystem](https://github.com/modelcontextprotocol/servers/tree/main/src/filesystem)
- [Spécification du Model Context Protocol](https://github.com/modelcontextprotocol/mcp)
- [Documentation de Node.js sur le système de fichiers](https://nodejs.org/api/fs.html)
- [Documentation de Roo](https://docs.roo.ai)
<!-- END_SECTION: links -->