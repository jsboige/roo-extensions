# Configuration du MCP Docker

<!-- START_SECTION: introduction -->
## Introduction

Ce document détaille les options de configuration du MCP Docker pour Roo. La configuration correcte du MCP Docker est essentielle pour permettre à Roo d'interagir efficacement avec Docker sur votre système.
<!-- END_SECTION: introduction -->

<!-- START_SECTION: mcp_configuration -->
## Configuration du serveur MCP

Pour configurer le MCP Docker dans Roo, vous devez ajouter une entrée dans le fichier de configuration MCP de Roo:

- Windows: `%APPDATA%\Code\User\globalStorage\rooveterinaryinc.roo-cline\settings\mcp_settings.json`
- macOS/Linux: `~/.config/Code/User/globalStorage/rooveterinaryinc.roo-cline/settings/mcp_settings.json`

Voici un exemple de configuration:

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

### Paramètres de configuration

| Paramètre | Description | Valeur par défaut |
|-----------|-------------|-------------------|
| `name` | Nom unique du serveur MCP | `mcp-server-local` |
| `type` | Type de communication avec le serveur MCP | `stdio` |
| `command` | Commande pour démarrer le serveur MCP | `docker` |
| `args` | Arguments de la commande | Voir exemple ci-dessus |
| `enabled` | Activer/désactiver le serveur MCP | `true` |
| `autoStart` | Démarrer automatiquement le serveur MCP | `true` |
| `description` | Description du serveur MCP | - |

> **Important**: Le montage du socket Docker (`-v /var/run/docker.sock:/var/run/docker.sock`) est essentiel pour permettre au MCP Docker d'interagir avec le démon Docker de l'hôte.
<!-- END_SECTION: mcp_configuration -->

<!-- START_SECTION: docker_socket -->
## Configuration du socket Docker

Le MCP Docker nécessite l'accès au socket Docker de l'hôte pour fonctionner correctement. Ce socket est monté dans le conteneur via l'option `-v /var/run/docker.sock:/var/run/docker.sock`.

### Emplacement du socket Docker

- Windows (avec Docker Desktop): `/var/run/docker.sock` (via WSL2)
- macOS (avec Docker Desktop): `/var/run/docker.sock`
- Linux: `/var/run/docker.sock` (par défaut)

### Permissions du socket Docker

Sur Linux, vous devrez peut-être ajuster les permissions du socket Docker pour permettre au MCP Docker d'y accéder:

```bash
sudo chmod 666 /var/run/docker.sock
```

> **Attention**: Cette commande rend le socket Docker accessible à tous les utilisateurs du système. Pour une configuration plus sécurisée, considérez l'utilisation de groupes Docker.
<!-- END_SECTION: docker_socket -->

<!-- START_SECTION: advanced_configuration -->
## Configuration avancée

### Utilisation d'un registre Docker privé

Si vous souhaitez utiliser une image Docker provenant d'un registre privé:

1. Connectez-vous au registre Docker:

```bash
docker login <registry-url>
```

2. Modifiez la configuration MCP pour utiliser l'image du registre privé:

```json
{
  "args": [
    "run",
    "-i",
    "--rm",
    "-v",
    "/var/run/docker.sock:/var/run/docker.sock",
    "<registry-url>/mcp-server:tag"
  ]
}
```

### Configuration des ressources Docker

Vous pouvez limiter les ressources utilisées par le conteneur MCP Docker en ajoutant des options à la configuration:

```json
{
  "args": [
    "run",
    "-i",
    "--rm",
    "--memory", "512m",
    "--cpus", "0.5",
    "-v",
    "/var/run/docker.sock:/var/run/docker.sock",
    "mcp-server:local"
  ]
}
```

### Configuration des variables d'environnement

Vous pouvez passer des variables d'environnement au conteneur MCP Docker:

```json
{
  "args": [
    "run",
    "-i",
    "--rm",
    "-e", "DEBUG=true",
    "-e", "LOG_LEVEL=debug",
    "-v",
    "/var/run/docker.sock:/var/run/docker.sock",
    "mcp-server:local"
  ]
}
```
<!-- END_SECTION: advanced_configuration -->

<!-- START_SECTION: security_considerations -->
## Considérations de sécurité

L'accès au socket Docker donne un contrôle significatif sur votre système. Voici quelques recommandations de sécurité:

1. **Limitez l'accès au socket Docker**: Utilisez des groupes et des permissions appropriés
2. **Utilisez des images Docker de confiance**: Vérifiez la source des images Docker que vous utilisez
3. **Mettez à jour régulièrement**: Assurez-vous que votre image MCP Docker est régulièrement mise à jour
4. **Surveillez l'activité**: Activez la journalisation pour surveiller l'activité du MCP Docker

Pour une configuration plus sécurisée, vous pouvez également:

- Utiliser un utilisateur non-root dans le conteneur
- Limiter les capacités du conteneur
- Utiliser des réseaux Docker isolés
<!-- END_SECTION: security_considerations -->

<!-- START_SECTION: troubleshooting -->
## Résolution des problèmes de configuration

Si vous rencontrez des problèmes avec la configuration du MCP Docker:

- **Erreur de connexion au socket Docker**: Vérifiez les permissions du socket Docker
- **Erreur de démarrage du conteneur**: Vérifiez que l'image Docker existe et est correctement nommée
- **Le MCP ne répond pas**: Vérifiez les logs du conteneur Docker pour identifier les erreurs

Pour plus de détails sur la résolution des problèmes, consultez le fichier [TROUBLESHOOTING.md](./TROUBLESHOOTING.md).
<!-- END_SECTION: troubleshooting -->

<!-- START_SECTION: next_steps -->
## Prochaines étapes

Maintenant que vous avez configuré le MCP Docker, vous pouvez:

1. [Apprendre à utiliser le MCP Docker](./USAGE.md)
2. [Explorer les cas d'utilisation avancés](./USAGE.md#cas-dutilisation-avancés)
<!-- END_SECTION: next_steps -->