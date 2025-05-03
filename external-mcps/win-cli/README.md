# Win-CLI MCP pour Roo

Ce dossier contient la documentation et les instructions pour l'installation et la configuration du serveur MCP Win-CLI utilisé avec Roo.

## Qu'est-ce que Win-CLI ?

Win-CLI est un serveur MCP qui permet à Roo d'exécuter des commandes dans différents shells Windows (PowerShell, CMD, Git Bash). Il offre également des fonctionnalités pour la gestion des connexions SSH.

Ce serveur MCP est particulièrement utile pour les utilisateurs Windows qui souhaitent que Roo puisse interagir directement avec leur système d'exploitation via différents shells, sans être limité au shell par défaut.

## Fonctionnalités principales

- Exécution de commandes dans différents shells Windows :
  - PowerShell
  - CMD (Command Prompt)
  - Git Bash
- Gestion des connexions SSH
- Historique des commandes exécutées
- Exécution de commandes dans des répertoires spécifiques

## Outils disponibles

Le serveur MCP Win-CLI fournit les outils suivants :

1. **execute_command** - Exécute une commande dans le shell spécifié
2. **get_command_history** - Récupère l'historique des commandes exécutées
3. **ssh_execute** - Exécute une commande sur un hôte distant via SSH
4. **ssh_disconnect** - Déconnecte d'un serveur SSH
5. **create_ssh_connection** - Crée une nouvelle connexion SSH
6. **read_ssh_connections** - Lit toutes les connexions SSH
7. **update_ssh_connection** - Met à jour une connexion SSH existante
8. **delete_ssh_connection** - Supprime une connexion SSH existante
9. **get_current_directory** - Récupère le répertoire de travail actuel

## Structure du dossier

- `README.md` - Ce fichier d'introduction
- `installation.md` - Guide d'installation du serveur MCP Win-CLI
- `configuration.md` - Guide de configuration du serveur MCP Win-CLI
- `exemples.md` - Exemples d'utilisation du serveur MCP Win-CLI
- `securite.md` - Bonnes pratiques de sécurité pour l'utilisation du serveur MCP Win-CLI

## Liens utiles

- [Dépôt GitHub de Win-CLI MCP](https://github.com/simonb97/server-win-cli)
- [Documentation NPM](https://www.npmjs.com/package/@simonb97/server-win-cli)