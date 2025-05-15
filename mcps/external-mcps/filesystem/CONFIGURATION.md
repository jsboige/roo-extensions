# Configuration du MCP Filesystem

<!-- START_SECTION: introduction -->
## Introduction

Ce document détaille les options de configuration du MCP Filesystem pour Roo. La configuration correcte du MCP Filesystem est essentielle pour permettre à Roo d'interagir avec le système de fichiers de manière sécurisée et efficace.
<!-- END_SECTION: introduction -->

<!-- START_SECTION: mcp_configuration -->
## Configuration du serveur MCP

Pour configurer le MCP Filesystem dans Roo, vous devez ajouter une entrée dans le fichier de configuration MCP de Roo:

- Windows: `%APPDATA%\Code\User\globalStorage\rooveterinaryinc.roo-cline\settings\mcp_settings.json`
- macOS/Linux: `~/.config/Code/User/globalStorage/rooveterinaryinc.roo-cline\settings\mcp_settings.json`

Voici un exemple de configuration:

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
        "/chemin/vers/repertoire/autorise1",
        "/chemin/vers/repertoire/autorise2"
      ],
      "enabled": true,
      "autoStart": true,
      "description": "Serveur MCP pour accéder au système de fichiers"
    }
  ]
}
```

### Paramètres de configuration

| Paramètre | Description | Valeur par défaut |
|-----------|-------------|-------------------|
| `name` | Nom unique du serveur MCP | `filesystem` |
| `type` | Type de communication avec le serveur MCP | `stdio` |
| `command` | Commande pour démarrer le serveur MCP | `npx` |
| `args` | Arguments de la commande | Voir exemple ci-dessus |
| `enabled` | Activer/désactiver le serveur MCP | `true` |
| `autoStart` | Démarrer automatiquement le serveur MCP | `true` |
| `description` | Description du serveur MCP | - |

> **Important**: Les chemins spécifiés après `@modelcontextprotocol/server-filesystem` sont les répertoires autorisés pour l'accès au système de fichiers. Le serveur MCP Filesystem ne permettra l'accès qu'à ces répertoires et leurs sous-répertoires.
<!-- END_SECTION: mcp_configuration -->

<!-- START_SECTION: allowed_directories -->
## Configuration des répertoires autorisés

Le MCP Filesystem limite l'accès aux répertoires spécifiés dans la configuration pour des raisons de sécurité. Vous devez explicitement spécifier les répertoires auxquels le MCP Filesystem est autorisé à accéder.

### Spécification des répertoires

Les répertoires autorisés sont spécifiés comme arguments supplémentaires lors du démarrage du serveur MCP:

```json
"args": [
  "-y",
  "@modelcontextprotocol/server-filesystem",
  "/chemin/vers/repertoire/autorise1",
  "/chemin/vers/repertoire/autorise2"
]
```

### Chemins absolus vs relatifs

Il est recommandé d'utiliser des chemins absolus pour les répertoires autorisés afin d'éviter toute ambiguïté:

- Windows: `C:\\Users\\username\\Documents`
- macOS/Linux: `/home/username/documents`

Si vous utilisez des chemins relatifs, ils seront résolus par rapport au répertoire de travail actuel de VS Code.

### Répertoires multiples

Vous pouvez spécifier plusieurs répertoires autorisés en les ajoutant comme arguments supplémentaires:

```json
"args": [
  "-y",
  "@modelcontextprotocol/server-filesystem",
  "/chemin/vers/repertoire1",
  "/chemin/vers/repertoire2",
  "/chemin/vers/repertoire3"
]
```

### Accès récursif

L'autorisation d'accès à un répertoire inclut automatiquement l'accès à tous ses sous-répertoires. Par exemple, si vous autorisez `/home/username/projects`, le MCP Filesystem pourra également accéder à `/home/username/projects/app1`, `/home/username/projects/app2`, etc.
<!-- END_SECTION: allowed_directories -->

<!-- START_SECTION: advanced_configuration -->
## Configuration avancée

### Options de ligne de commande

Le serveur MCP Filesystem accepte plusieurs options de ligne de commande:

| Option | Description | Exemple |
|--------|-------------|---------|
| `--help` | Affiche l'aide | `npx @modelcontextprotocol/server-filesystem --help` |
| `--version` | Affiche la version | `npx @modelcontextprotocol/server-filesystem --version` |
| `--debug` | Active le mode débogage | `npx @modelcontextprotocol/server-filesystem --debug /chemin` |
| `--log-level` | Définit le niveau de journalisation | `npx @modelcontextprotocol/server-filesystem --log-level=debug /chemin` |

Pour utiliser ces options dans la configuration Roo, ajoutez-les aux arguments:

```json
"args": [
  "-y",
  "@modelcontextprotocol/server-filesystem",
  "--debug",
  "--log-level=debug",
  "/chemin/vers/repertoire"
]
```

### Configuration des limites

Vous pouvez configurer certaines limites pour le MCP Filesystem:

```json
"args": [
  "-y",
  "@modelcontextprotocol/server-filesystem",
  "--max-file-size=10mb",
  "--max-read-size=5mb",
  "/chemin/vers/repertoire"
]
```

| Option | Description | Valeur par défaut |
|--------|-------------|-------------------|
| `--max-file-size` | Taille maximale des fichiers à écrire | `50mb` |
| `--max-read-size` | Taille maximale des fichiers à lire | `10mb` |
| `--max-depth` | Profondeur maximale pour la récursion des répertoires | `10` |
<!-- END_SECTION: advanced_configuration -->

<!-- START_SECTION: environment_variables -->
## Variables d'environnement

Le MCP Filesystem prend en charge plusieurs variables d'environnement pour sa configuration:

| Variable | Description | Exemple |
|----------|-------------|---------|
| `MCP_FILESYSTEM_DEBUG` | Active le mode débogage | `MCP_FILESYSTEM_DEBUG=true` |
| `MCP_FILESYSTEM_LOG_LEVEL` | Définit le niveau de journalisation | `MCP_FILESYSTEM_LOG_LEVEL=debug` |
| `MCP_FILESYSTEM_MAX_FILE_SIZE` | Taille maximale des fichiers à écrire | `MCP_FILESYSTEM_MAX_FILE_SIZE=10mb` |
| `MCP_FILESYSTEM_MAX_READ_SIZE` | Taille maximale des fichiers à lire | `MCP_FILESYSTEM_MAX_READ_SIZE=5mb` |
| `MCP_FILESYSTEM_ALLOWED_DIRS` | Répertoires autorisés (séparés par des virgules) | `MCP_FILESYSTEM_ALLOWED_DIRS=/path1,/path2` |

Pour utiliser ces variables d'environnement dans la configuration Roo:

```json
"env": {
  "MCP_FILESYSTEM_DEBUG": "true",
  "MCP_FILESYSTEM_LOG_LEVEL": "debug"
}
```

Ajoutez cette propriété `env` au même niveau que `name`, `type`, etc. dans la configuration du serveur MCP.
<!-- END_SECTION: environment_variables -->

<!-- START_SECTION: security_considerations -->
## Considérations de sécurité

L'accès au système de fichiers présente des risques de sécurité importants. Voici quelques recommandations:

### Limiter les répertoires autorisés

Ne donnez accès qu'aux répertoires strictement nécessaires. Évitez d'autoriser l'accès à:
- Répertoires système (`/etc`, `C:\Windows`, etc.)
- Répertoires contenant des informations sensibles
- Répertoires home complets

### Utiliser des répertoires dédiés

Créez des répertoires dédiés pour les opérations du MCP Filesystem:

```bash
mkdir -p ~/roo-workspace
```

Puis autorisez uniquement ce répertoire:

```json
"args": [
  "-y",
  "@modelcontextprotocol/server-filesystem",
  "/home/username/roo-workspace"
]
```

### Permissions des fichiers

Sur Linux/macOS, assurez-vous que les permissions des fichiers sont correctement configurées:

```bash
chmod 750 ~/roo-workspace
```

### Surveillance des activités

Activez la journalisation pour surveiller les activités du MCP Filesystem:

```json
"args": [
  "-y",
  "@modelcontextprotocol/server-filesystem",
  "--log-level=info",
  "/chemin/vers/repertoire"
]
```

### Mises à jour régulières

Maintenez le MCP Filesystem à jour pour bénéficier des dernières corrections de sécurité:

```bash
npm update -g @modelcontextprotocol/server-filesystem
```
<!-- END_SECTION: security_considerations -->

<!-- START_SECTION: troubleshooting -->
## Résolution des problèmes de configuration

Si vous rencontrez des problèmes avec la configuration du MCP Filesystem:

- **Erreur "Access denied"**: Vérifiez que les répertoires autorisés sont correctement spécifiés et accessibles
- **Erreur "Path not allowed"**: Assurez-vous que le chemin que vous essayez d'accéder est dans un répertoire autorisé
- **Le serveur MCP ne démarre pas**: Vérifiez que le package est correctement installé et que la commande est correcte
- **Problèmes de permissions**: Vérifiez les permissions des répertoires et fichiers

Pour plus de détails sur la résolution des problèmes, consultez le fichier [TROUBLESHOOTING.md](./TROUBLESHOOTING.md).
<!-- END_SECTION: troubleshooting -->

<!-- START_SECTION: next_steps -->
## Prochaines étapes

Maintenant que vous avez configuré le MCP Filesystem, vous pouvez:

1. [Apprendre à utiliser le MCP Filesystem](./USAGE.md)
2. [Explorer les cas d'utilisation avancés](./USAGE.md#cas-dutilisation-avancés)
<!-- END_SECTION: next_steps -->