# Configuration du MCP GitHub

<!-- START_SECTION: introduction -->
## Introduction

Ce document détaille les options de configuration du MCP GitHub pour Roo. La configuration correcte du MCP GitHub est essentielle pour permettre à Roo d'interagir efficacement avec l'API GitHub et d'accéder aux fonctionnalités comme la gestion des dépôts, des issues, des pull requests, etc.
<!-- END_SECTION: introduction -->

<!-- START_SECTION: mcp_configuration -->
## Configuration du serveur MCP

Pour configurer le MCP GitHub dans Roo, vous devez ajouter une entrée dans le fichier de configuration MCP de Roo:

- Windows: `%APPDATA%\Code\User\globalStorage\rooveterinaryinc.roo-cline\settings\mcp_settings.json`
- macOS/Linux: `~/.config/Code/User/globalStorage/rooveterinaryinc.roo-cline\settings\mcp_settings.json`

Voici un exemple de configuration:

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

### Paramètres de configuration

| Paramètre | Description | Valeur par défaut |
|-----------|-------------|-------------------|
| `name` | Nom unique du serveur MCP | `github` |
| `type` | Type de communication avec le serveur MCP | `stdio` |
| `command` | Commande pour démarrer le serveur MCP | `npx` |
| `args` | Arguments de la commande | Voir exemple ci-dessus |
| `enabled` | Activer/désactiver le serveur MCP | `true` |
| `autoStart` | Démarrer automatiquement le serveur MCP | `true` |
| `description` | Description du serveur MCP | - |

> **Important**: Le token GitHub est sensible et ne doit pas être partagé. Pour une sécurité accrue, utilisez des variables d'environnement pour stocker le token plutôt que de l'inclure directement dans le fichier de configuration.
<!-- END_SECTION: mcp_configuration -->

<!-- START_SECTION: token_configuration -->
## Configuration du token GitHub

Le MCP GitHub nécessite un token d'accès personnel (PAT) GitHub pour interagir avec l'API GitHub. Vous pouvez spécifier ce token de plusieurs façons:

### 1. Via les arguments de ligne de commande

```json
"args": [
  "-y",
  "@modelcontextprotocol/server-github",
  "--token",
  "votre_token_github"
]
```

### 2. Via une variable d'environnement

```json
"env": {
  "GITHUB_TOKEN": "votre_token_github"
}
```

Ajoutez cette propriété `env` au même niveau que `name`, `type`, etc. dans la configuration du serveur MCP.

### 3. Via un fichier de configuration

```json
"args": [
  "-y",
  "@modelcontextprotocol/server-github",
  "--config",
  "/chemin/vers/config.json"
]
```

Où `config.json` contient:

```json
{
  "token": "votre_token_github"
}
```

### Permissions du token

Selon les fonctionnalités que vous souhaitez utiliser, votre token GitHub doit avoir différentes permissions:

| Fonctionnalité | Permissions requises |
|----------------|---------------------|
| Lecture des dépôts publics | Aucune permission spéciale |
| Lecture des dépôts privés | `repo` |
| Création/modification de dépôts | `repo` |
| Gestion des issues | `repo` |
| Gestion des pull requests | `repo` |
| Gestion des workflows | `workflow` |
| Accès aux organisations | `read:org` |
| Accès aux gists | `gist` |

Pour une sécurité optimale, accordez uniquement les permissions nécessaires à votre cas d'utilisation.
<!-- END_SECTION: token_configuration -->

<!-- START_SECTION: advanced_configuration -->
## Configuration avancée

### Options de ligne de commande

Le serveur MCP GitHub accepte plusieurs options de ligne de commande:

| Option | Description | Exemple |
|--------|-------------|---------|
| `--help` | Affiche l'aide | `npx @modelcontextprotocol/server-github --help` |
| `--version` | Affiche la version | `npx @modelcontextprotocol/server-github --version` |
| `--token` | Spécifie le token GitHub | `npx @modelcontextprotocol/server-github --token votre_token` |
| `--config` | Spécifie un fichier de configuration | `npx @modelcontextprotocol/server-github --config config.json` |
| `--debug` | Active le mode débogage | `npx @modelcontextprotocol/server-github --debug` |
| `--log-level` | Définit le niveau de journalisation | `npx @modelcontextprotocol/server-github --log-level=debug` |
| `--port` | Définit le port d'écoute (mode HTTP) | `npx @modelcontextprotocol/server-github --port=3000` |
| `--host` | Définit l'hôte d'écoute (mode HTTP) | `npx @modelcontextprotocol/server-github --host=0.0.0.0` |

Pour utiliser ces options dans la configuration Roo, ajoutez-les aux arguments:

```json
"args": [
  "-y",
  "@modelcontextprotocol/server-github",
  "--token",
  "votre_token_github",
  "--debug",
  "--log-level=debug"
]
```

### Configuration des limites de taux

L'API GitHub impose des limites de taux (rate limits) sur les requêtes. Le MCP GitHub gère automatiquement ces limites, mais vous pouvez configurer son comportement:

```json
"args": [
  "-y",
  "@modelcontextprotocol/server-github",
  "--token",
  "votre_token_github",
  "--rate-limit-strategy=exponential-backoff"
]
```

Stratégies disponibles:
- `wait`: Attend que la limite de taux soit réinitialisée (par défaut)
- `error`: Renvoie une erreur lorsque la limite est atteinte
- `exponential-backoff`: Utilise une stratégie de recul exponentiel

### Configuration du proxy

Si vous êtes derrière un proxy, vous pouvez configurer le MCP GitHub pour l'utiliser:

```json
"env": {
  "GITHUB_TOKEN": "votre_token_github",
  "HTTP_PROXY": "http://proxy.exemple.com:8080",
  "HTTPS_PROXY": "http://proxy.exemple.com:8080"
}
```

### Configuration de l'entreprise GitHub

Si vous utilisez GitHub Enterprise, vous pouvez configurer l'URL de base de l'API:

```json
"args": [
  "-y",
  "@modelcontextprotocol/server-github",
  "--token",
  "votre_token_github",
  "--api-url",
  "https://github.entreprise.com/api/v3"
]
```
<!-- END_SECTION: advanced_configuration -->

<!-- START_SECTION: environment_variables -->
## Variables d'environnement

Le MCP GitHub prend en charge plusieurs variables d'environnement pour sa configuration:

| Variable | Description | Exemple |
|----------|-------------|---------|
| `GITHUB_TOKEN` | Token d'accès personnel GitHub | `GITHUB_TOKEN=ghp_1234567890abcdef` |
| `GITHUB_API_URL` | URL de base de l'API GitHub | `GITHUB_API_URL=https://github.entreprise.com/api/v3` |
| `HTTP_PROXY` | URL du proxy HTTP | `HTTP_PROXY=http://proxy.exemple.com:8080` |
| `HTTPS_PROXY` | URL du proxy HTTPS | `HTTPS_PROXY=http://proxy.exemple.com:8080` |
| `NO_PROXY` | Hôtes à exclure du proxy | `NO_PROXY=localhost,127.0.0.1` |
| `MCP_GITHUB_DEBUG` | Active le mode débogage | `MCP_GITHUB_DEBUG=true` |
| `MCP_GITHUB_LOG_LEVEL` | Définit le niveau de journalisation | `MCP_GITHUB_LOG_LEVEL=debug` |

Pour utiliser ces variables d'environnement dans la configuration Roo:

```json
"env": {
  "GITHUB_TOKEN": "votre_token_github",
  "MCP_GITHUB_DEBUG": "true",
  "MCP_GITHUB_LOG_LEVEL": "debug"
}
```
<!-- END_SECTION: environment_variables -->

<!-- START_SECTION: multi_account -->
## Configuration multi-comptes

Si vous devez interagir avec plusieurs comptes GitHub, vous pouvez configurer plusieurs instances du MCP GitHub:

```json
{
  "mcpServers": [
    {
      "name": "github-personal",
      "type": "stdio",
      "command": "npx",
      "args": [
        "-y",
        "@modelcontextprotocol/server-github",
        "--token",
        "votre_token_personnel"
      ],
      "enabled": true,
      "autoStart": true,
      "description": "Serveur MCP pour le compte GitHub personnel"
    },
    {
      "name": "github-work",
      "type": "stdio",
      "command": "npx",
      "args": [
        "-y",
        "@modelcontextprotocol/server-github",
        "--token",
        "votre_token_professionnel"
      ],
      "enabled": true,
      "autoStart": true,
      "description": "Serveur MCP pour le compte GitHub professionnel"
    }
  ]
}
```

Vous pouvez ensuite spécifier quel serveur MCP utiliser lors de l'appel aux outils:

```
Outil: search_repositories
Serveur MCP: github-personal
Arguments:
{
  "query": "user:votre-nom-utilisateur"
}
```
<!-- END_SECTION: multi_account -->

<!-- START_SECTION: security_considerations -->
## Considérations de sécurité

L'accès à l'API GitHub via un token présente certains risques de sécurité. Voici quelques recommandations:

### Protection du token

- **Ne partagez jamais votre token** dans des dépôts publics, des messages, etc.
- **Utilisez des variables d'environnement** plutôt que d'inclure le token directement dans les fichiers de configuration
- **Stockez le token de manière sécurisée**, par exemple dans un gestionnaire de mots de passe ou un coffre-fort de secrets
- **Définissez une date d'expiration** pour votre token lors de sa création
- **Utilisez des tokens différents** pour différents environnements (développement, production, etc.)

### Limitation des permissions

- **Accordez uniquement les permissions nécessaires** à votre token
- **Évitez les permissions d'écriture** si vous n'avez besoin que de lire des données
- **Limitez l'accès aux dépôts** si possible, plutôt que d'accorder l'accès à tous les dépôts

### Audit et surveillance

- **Vérifiez régulièrement les tokens actifs** dans vos paramètres GitHub
- **Révoquez immédiatement les tokens compromis**
- **Activez la journalisation** pour surveiller l'utilisation du MCP GitHub
- **Examinez régulièrement les logs** pour détecter toute activité suspecte

### Mises à jour régulières

- **Maintenez le MCP GitHub à jour** pour bénéficier des dernières corrections de sécurité
- **Renouvelez régulièrement vos tokens** pour limiter l'impact d'une éventuelle compromission
<!-- END_SECTION: security_considerations -->

<!-- START_SECTION: troubleshooting -->
## Résolution des problèmes de configuration

Si vous rencontrez des problèmes avec la configuration du MCP GitHub:

- **Erreur d'authentification**: Vérifiez que votre token GitHub est valide et dispose des autorisations nécessaires
- **Erreur de connexion à l'API GitHub**: Vérifiez votre connexion Internet et les éventuelles restrictions de pare-feu
- **Le serveur MCP ne démarre pas**: Vérifiez que le package est correctement installé et que la commande est correcte
- **Erreur "Rate limit exceeded"**: Attendez que la limite de taux soit réinitialisée ou utilisez un token avec des limites plus élevées

Pour plus de détails sur la résolution des problèmes, consultez le fichier [TROUBLESHOOTING.md](./TROUBLESHOOTING.md).
<!-- END_SECTION: troubleshooting -->

<!-- START_SECTION: next_steps -->
## Prochaines étapes

Maintenant que vous avez configuré le MCP GitHub, vous pouvez:

1. [Apprendre à utiliser le MCP GitHub](./USAGE.md)
2. [Explorer les cas d'utilisation avancés](./USAGE.md#cas-dutilisation-avancés)
<!-- END_SECTION: next_steps -->