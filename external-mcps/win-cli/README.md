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
- Accès direct aux ressources système via les URI

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

## Ressources directes

Le serveur MCP Win-CLI fournit également des ressources directes accessibles via des URI spécifiques :

1. **cli://currentdir** - Le répertoire de travail actuel du serveur CLI
2. **ssh://config** - Toutes les configurations de connexion SSH
3. **cli://config** - La configuration principale du serveur CLI (sans les données sensibles)

## Fonctionnalités optimales et limitations

### Ce qui fonctionne bien
- **Commandes simples** : Les commandes basiques dans tous les shells fonctionnent parfaitement
- **Ressources directes** : L'accès aux ressources via URI est rapide et fiable
- **Gestion SSH** : La création et gestion des connexions SSH est stable
- **Historique des commandes** : Le suivi des commandes exécutées est précis

### Limitations actuelles
- **Commandes complexes** : Les commandes avec plusieurs opérateurs de redirection ou pipes complexes peuvent parfois échouer
- **Commandes interactives** : Les commandes nécessitant une interaction utilisateur continue peuvent être instables
- **Séparateurs de commandes** : Seul le séparateur `;` est pleinement supporté dans la configuration par défaut
- **Performances** : Les commandes générant une sortie volumineuse peuvent ralentir le serveur

## Structure du dossier

- `README.md` - Ce fichier d'introduction
- `installation.md` - Guide d'installation du serveur MCP Win-CLI
- `configuration.md` - Guide de configuration du serveur MCP Win-CLI
- `exemples.md` - Exemples d'utilisation du serveur MCP Win-CLI
- `securite.md` - Bonnes pratiques de sécurité pour l'utilisation du serveur MCP Win-CLI

## Liens utiles

- [Dépôt GitHub de Win-CLI MCP](https://github.com/simonb97/server-win-cli)
- [Documentation NPM](https://www.npmjs.com/package/@simonb97/server-win-cli)