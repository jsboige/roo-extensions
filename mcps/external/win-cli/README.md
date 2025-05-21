# MCP Win-CLI pour Roo

<!-- START_SECTION: introduction -->
## Introduction

Le MCP Win-CLI permet à Roo d'exécuter des commandes dans différents shells Windows (PowerShell, CMD, Git Bash) et de gérer des connexions SSH via le protocole MCP (Model Context Protocol). Il offre une interface complète pour interagir avec le système d'exploitation Windows et les serveurs distants directement depuis l'interface de conversation de Roo.

Ce MCP est particulièrement utile pour les utilisateurs Windows qui souhaitent que Roo puisse interagir directement avec leur système d'exploitation via différents shells, sans être limité au shell par défaut, et pour gérer des connexions SSH vers des serveurs distants.
<!-- END_SECTION: introduction -->

<!-- START_SECTION: features -->
## Fonctionnalités principales

- **Exécution de commandes dans différents shells Windows**:
  - PowerShell
  - CMD (Command Prompt)
  - Git Bash
- **Gestion des connexions SSH**:
  - Création et gestion de connexions SSH
  - Exécution de commandes sur des serveurs distants
  - Support des clés SSH et des mots de passe
- **Historique des commandes**:
  - Suivi des commandes exécutées
  - Récupération de l'historique des commandes
- **Sécurité avancée**:
  - Limitation des commandes autorisées
  - Configuration des séparateurs de commande
  - Protection contre les commandes dangereuses
- **Flexibilité d'exécution**:
  - Exécution dans des répertoires spécifiques
  - Chaînage de commandes
  - Récupération du répertoire de travail actuel
<!-- END_SECTION: features -->

<!-- START_SECTION: tools -->
## Outils disponibles

Le MCP Win-CLI expose les outils suivants:

| Outil | Description |
|-------|-------------|
| `execute_command` | Exécute une commande dans le shell spécifié |
| `get_command_history` | Récupère l'historique des commandes exécutées |
| `ssh_execute` | Exécute une commande sur un hôte distant via SSH |
| `ssh_disconnect` | Déconnecte d'un serveur SSH |
| `create_ssh_connection` | Crée une nouvelle connexion SSH |
| `read_ssh_connections` | Lit toutes les connexions SSH |
| `update_ssh_connection` | Met à jour une connexion SSH existante |
| `delete_ssh_connection` | Supprime une connexion SSH existante |
| `get_current_directory` | Récupère le répertoire de travail actuel |

Pour une description détaillée de chaque outil et des exemples d'utilisation, consultez le fichier [USAGE.md](./USAGE.md).
<!-- END_SECTION: tools -->

<!-- START_SECTION: structure -->
## Structure de la documentation

- [README.md](./README.md) - Ce fichier d'introduction
- [INSTALLATION.md](./INSTALLATION.md) - Guide d'installation du MCP Win-CLI
- [CONFIGURATION.md](./CONFIGURATION.md) - Guide de configuration du MCP Win-CLI
- [USAGE.md](./USAGE.md) - Exemples d'utilisation et bonnes pratiques
- [SECURITY.md](./SECURITY.md) - Bonnes pratiques de sécurité
- [TROUBLESHOOTING.md](./TROUBLESHOOTING.md) - Résolution des problèmes courants
- [run-win-cli.bat](./run-win-cli.bat) - Script batch pour démarrer facilement le serveur MCP Win-CLI
<!-- END_SECTION: structure -->

<!-- START_SECTION: quick_start -->
## Démarrage rapide

1. **Installation**:
   ```bash
   # Via NPX (recommandé)
   npx -y @simonb97/server-win-cli
   
   # Ou installation globale
   npm install -g @simonb97/server-win-cli
   ```

2. **Configuration**:
   Ajoutez la configuration suivante à votre fichier `mcp_settings.json`:
   ```json
   {
     "mcpServers": {
       "win-cli": {
         "command": "cmd",
         "args": ["/c", "npx", "-y", "@simonb97/server-win-cli"],
         "transportType": "stdio",
         "disabled": false
       }
     }
   }
   ```

3. **Utilisation**:
   Redémarrez VS Code et commencez à utiliser les outils de commande dans Roo.

Pour des instructions détaillées, consultez les fichiers [INSTALLATION.md](./INSTALLATION.md) et [CONFIGURATION.md](./CONFIGURATION.md).
<!-- END_SECTION: quick_start -->

<!-- START_SECTION: use_cases -->
## Cas d'utilisation

Le MCP Win-CLI est particulièrement utile pour:

- **Administration système**: Exécuter des commandes d'administration Windows directement depuis Roo
- **Développement logiciel**: Gérer des projets, exécuter des tests, compiler du code
- **Gestion de serveurs**: Se connecter à des serveurs distants via SSH et exécuter des commandes
- **Automatisation**: Créer des workflows automatisés combinant plusieurs commandes
- **Analyse de données**: Exécuter des scripts PowerShell pour analyser des données
- **Gestion de fichiers**: Manipuler des fichiers et répertoires sur le système local

Pour des exemples détaillés, consultez le fichier [USAGE.md](./USAGE.md#cas-dutilisation).
<!-- END_SECTION: use_cases -->

<!-- START_SECTION: shell_comparison -->
## Comparaison des shells

Le MCP Win-CLI prend en charge plusieurs shells, chacun ayant ses propres avantages:

### PowerShell

PowerShell est recommandé pour:
- Tâches d'administration Windows
- Manipulation d'objets complexes (JSON, XML, etc.)
- Accès aux fonctionnalités .NET
- Scripts avancés avec gestion d'erreurs

Exemple:
```
Outil: execute_command
Arguments:
{
  "shell": "powershell",
  "command": "Get-Process | Where-Object { $_.CPU -gt 10 } | Sort-Object CPU -Descending | Select-Object -First 5"
}
```

### CMD (Command Prompt)

CMD est recommandé pour:
- Compatibilité maximale avec les anciens systèmes Windows
- Scripts batch simples
- Commandes Windows de base

Exemple:
```
Outil: execute_command
Arguments:
{
  "shell": "cmd",
  "command": "dir /s /b *.txt"
}
```

### Git Bash

Git Bash est recommandé pour:
- Commandes Unix-like sur Windows
- Opérations Git
- Scripts shell bash

Exemple:
```
Outil: execute_command
Arguments:
{
  "shell": "gitbash",
  "command": "find . -name '*.js' | xargs grep 'function'"
}
```
<!-- END_SECTION: shell_comparison -->

<!-- START_SECTION: security -->
## Considérations de sécurité

L'utilisation du MCP Win-CLI implique certains risques de sécurité qu'il est important de prendre en compte:

- **Exécution de commandes dangereuses**: Limitez les commandes autorisées pour éviter les suppressions accidentelles ou les modifications système critiques
- **Injection de commandes**: Validez toutes les entrées avant de les utiliser dans des commandes
- **Élévation de privilèges**: Exécutez le serveur avec les privilèges minimaux nécessaires
- **Fuite d'informations sensibles**: Soyez prudent avec l'historique des commandes et les journaux
- **Séparateurs de commande**: Limitez les séparateurs autorisés pour réduire les risques d'injection

Pour une utilisation sécurisée:
- Configurez les commandes autorisées et bloquées
- Limitez les séparateurs de commande (idéalement uniquement `;`)
- Utilisez des clés SSH plutôt que des mots de passe
- Activez la journalisation pour l'audit

Pour plus de détails sur la sécurité, consultez le fichier [SECURITY.md](./SECURITY.md).
<!-- END_SECTION: security -->

<!-- START_SECTION: troubleshooting -->
## Résolution des problèmes

Si vous rencontrez des problèmes avec le MCP Win-CLI:

- **Le serveur ne démarre pas**: Vérifiez l'installation de Node.js et npm
- **Erreurs d'exécution de commandes**: Vérifiez la syntaxe et les permissions
- **Problèmes avec les shells**: Vérifiez que les shells sont correctement installés et configurés
- **Problèmes SSH**: Vérifiez les informations de connexion et les clés SSH
- **Séparateurs de commande**: Vérifiez la configuration des séparateurs autorisés

Pour une résolution plus détaillée des problèmes, consultez le fichier [TROUBLESHOOTING.md](./TROUBLESHOOTING.md).

## Surveillance et diagnostic

Le MCP Win-CLI est intégré au système de surveillance des serveurs MCP, ce qui permet de:

- **Détection automatique des problèmes**: Le système vérifie régulièrement si le serveur Win-CLI est en cours d'exécution et répond correctement
- **Redémarrage automatique**: En cas de défaillance, le serveur peut être redémarré automatiquement
- **Journalisation**: Les événements et erreurs sont enregistrés dans des fichiers de log centralisés
- **Alertes**: Des alertes sont générées en cas de problèmes persistants

### Utilisation du système de surveillance

Pour surveiller le serveur MCP Win-CLI:

```powershell
# Surveillance simple
.\mcps\monitoring\monitor-mcp-servers.ps1

# Surveillance avec redémarrage automatique
.\mcps\monitoring\monitor-mcp-servers.ps1 -RestartServers

# Surveillance silencieuse (logs uniquement)
.\mcps\monitoring\monitor-mcp-servers.ps1 -LogOnly
```

### Redémarrage manuel

Si vous devez redémarrer manuellement le serveur Win-CLI:

```bash
# Arrêter le serveur (si nécessaire)
taskkill /F /IM node.exe /FI "WINDOWTITLE eq *server-win-cli*"

# Démarrer le serveur
cd C:\dev\roo-extensions
npx -y @simonb97/server-win-cli
```

Pour plus d'informations sur le système de surveillance, consultez la [documentation dédiée](../../monitoring/README.md).
<!-- END_SECTION: troubleshooting -->

<!-- START_SECTION: integration -->
## Intégration avec Roo

Le MCP Win-CLI s'intègre parfaitement avec Roo, permettant des interactions naturelles en langage courant. Voici quelques exemples de demandes que vous pouvez faire à Roo:

- "Exécute la commande 'Get-Process' en PowerShell"
- "Liste les fichiers du répertoire C:\Users\Public"
- "Crée une connexion SSH vers mon serveur web"
- "Vérifie l'état du service nginx sur mon serveur web via SSH"
- "Montre-moi l'historique des commandes récentes"
- "Exécute ce script PowerShell et analyse les résultats"
- "Connecte-toi au serveur de production et vérifie l'espace disque disponible"
- "Exécute une commande Git pour cloner ce dépôt"

Roo traduira automatiquement ces demandes en appels aux outils appropriés du MCP Win-CLI.

### Nouvelles fonctionnalités

Le MCP Win-CLI a été enrichi avec plusieurs nouvelles fonctionnalités:

- **Exécution parallèle de commandes**: Possibilité d'exécuter plusieurs commandes en parallèle pour améliorer les performances
- **Gestion améliorée des timeouts**: Configuration fine des timeouts pour les commandes longues
- **Support pour les scripts complexes**: Meilleure gestion des scripts PowerShell et Bash complexes
- **Historique enrichi**: Historique des commandes avec plus de métadonnées (durée d'exécution, code de retour, etc.)
- **Intégration avec le système de surveillance**: Détection et résolution automatique des problèmes
<!-- END_SECTION: integration -->

<!-- START_SECTION: links -->
## Liens utiles

- [Dépôt GitHub de Win-CLI MCP](https://github.com/simonb97/server-win-cli)
- [Documentation NPM](https://www.npmjs.com/package/@simonb97/server-win-cli)
- [Documentation PowerShell](https://docs.microsoft.com/en-us/powershell/)
- [Documentation CMD](https://docs.microsoft.com/en-us/windows-server/administration/windows-commands/windows-commands)
- [Documentation Git Bash](https://git-scm.com/docs)
<!-- END_SECTION: links -->