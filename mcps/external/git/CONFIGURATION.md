# Configuration du MCP Git

<!-- START_SECTION: introduction -->
## Introduction

Ce document détaille les options de configuration du MCP Git pour Roo. La configuration correcte du MCP Git est essentielle pour permettre à Roo d'interagir efficacement avec des dépôts Git locaux et distants.
<!-- END_SECTION: introduction -->

<!-- START_SECTION: mcp_configuration -->
## Configuration du serveur MCP

Pour configurer le MCP Git dans Roo, vous devez ajouter une entrée dans le fichier de configuration MCP de Roo:

- Windows: `%APPDATA%\Code\User\globalStorage\rooveterinaryinc.roo-cline\settings\mcp_settings.json`
- macOS/Linux: `~/.config/Code/User/globalStorage/rooveterinaryinc.roo-cline\settings\mcp_settings.json`

Voici un exemple de configuration:

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

### Paramètres de configuration

| Paramètre | Description | Valeur par défaut |
|-----------|-------------|-------------------|
| `name` | Nom unique du serveur MCP | `git` |
| `type` | Type de communication avec le serveur MCP | `stdio` |
| `command` | Commande pour démarrer le serveur MCP | `npx` |
| `args` | Arguments de la commande | Voir exemple ci-dessus |
| `enabled` | Activer/désactiver le serveur MCP | `true` |
| `autoStart` | Démarrer automatiquement le serveur MCP | `true` |
| `description` | Description du serveur MCP | - |
<!-- END_SECTION: mcp_configuration -->

<!-- START_SECTION: git_configuration -->
## Configuration de Git

Le MCP Git utilise la configuration Git de votre système. Vous pouvez personnaliser cette configuration pour améliorer l'expérience avec le MCP Git.

### Configuration de base

Configurez votre identité Git:

```bash
git config --global user.name "Votre Nom"
git config --global user.email "votre.email@exemple.com"
```

### Configuration de l'authentification

#### Authentification HTTPS

Pour les dépôts utilisant HTTPS, configurez un gestionnaire d'informations d'identification:

```bash
# Sur Windows
git config --global credential.helper wincred

# Sur macOS
git config --global credential.helper osxkeychain

# Sur Linux
git config --global credential.helper store
```

> **Note**: L'utilisation de `credential.helper store` stocke vos informations d'identification en texte clair sur le disque. Pour une sécurité accrue, utilisez `credential.helper cache` qui stocke temporairement les informations d'identification en mémoire.

#### Authentification SSH

Pour les dépôts utilisant SSH:

1. Générez une clé SSH si vous n'en avez pas déjà une:

```bash
ssh-keygen -t ed25519 -C "votre.email@exemple.com"
```

2. Ajoutez la clé à votre agent SSH:

```bash
# Sur Linux/macOS
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519

# Sur Windows (avec Git Bash)
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519
```

3. Ajoutez la clé publique à votre compte GitHub/GitLab/Bitbucket:

```bash
# Affichez la clé publique
cat ~/.ssh/id_ed25519.pub
```

Copiez la sortie et ajoutez-la à votre compte sur la plateforme Git.

### Configuration des alias

Vous pouvez configurer des alias Git pour simplifier les commandes fréquemment utilisées:

```bash
git config --global alias.co checkout
git config --global alias.br branch
git config --global alias.ci commit
git config --global alias.st status
```

### Configuration des fins de ligne

Pour éviter les problèmes de fins de ligne entre différents systèmes d'exploitation:

```bash
# Sur Windows
git config --global core.autocrlf true

# Sur macOS/Linux
git config --global core.autocrlf input
```

### Configuration du fusionnement et des conflits

Pour configurer l'outil de résolution de conflits:

```bash
# Utiliser VS Code comme outil de diff et de merge
git config --global merge.tool vscode
git config --global mergetool.vscode.cmd 'code --wait $MERGED'
git config --global diff.tool vscode
git config --global difftool.vscode.cmd 'code --wait --diff $LOCAL $REMOTE'
```
<!-- END_SECTION: git_configuration -->

<!-- START_SECTION: advanced_configuration -->
## Configuration avancée

### Options de ligne de commande

Le serveur MCP Git accepte plusieurs options de ligne de commande:

| Option | Description | Exemple |
|--------|-------------|---------|
| `--help` | Affiche l'aide | `npx @modelcontextprotocol/server-git --help` |
| `--version` | Affiche la version | `npx @modelcontextprotocol/server-git --version` |
| `--debug` | Active le mode débogage | `npx @modelcontextprotocol/server-git --debug` |
| `--log-level` | Définit le niveau de journalisation | `npx @modelcontextprotocol/server-git --log-level=debug` |

Pour utiliser ces options dans la configuration Roo, ajoutez-les aux arguments:

```json
"args": [
  "-y",
  "@modelcontextprotocol/server-git",
  "--debug",
  "--log-level=debug"
]
```

### Configuration des dépôts autorisés

Pour des raisons de sécurité, vous pouvez limiter les dépôts auxquels le MCP Git peut accéder:

```json
"args": [
  "-y",
  "@modelcontextprotocol/server-git",
  "--allowed-repos=/chemin/vers/repo1,/chemin/vers/repo2"
]
```

### Configuration des opérations autorisées

Vous pouvez limiter les opérations Git que le MCP Git peut effectuer:

```json
"args": [
  "-y",
  "@modelcontextprotocol/server-git",
  "--allowed-operations=status,log,pull,push"
]
```

### Configuration des branches protégées

Pour éviter les modifications accidentelles sur certaines branches:

```json
"args": [
  "-y",
  "@modelcontextprotocol/server-git",
  "--protected-branches=main,master,production"
]
```
<!-- END_SECTION: advanced_configuration -->

<!-- START_SECTION: environment_variables -->
## Variables d'environnement

Le MCP Git prend en charge plusieurs variables d'environnement pour sa configuration:

| Variable | Description | Exemple |
|----------|-------------|---------|
| `MCP_GIT_DEBUG` | Active le mode débogage | `MCP_GIT_DEBUG=true` |
| `MCP_GIT_LOG_LEVEL` | Définit le niveau de journalisation | `MCP_GIT_LOG_LEVEL=debug` |
| `MCP_GIT_ALLOWED_REPOS` | Dépôts autorisés (séparés par des virgules) | `MCP_GIT_ALLOWED_REPOS=/path1,/path2` |
| `MCP_GIT_ALLOWED_OPERATIONS` | Opérations autorisées (séparées par des virgules) | `MCP_GIT_ALLOWED_OPERATIONS=status,log,pull` |
| `MCP_GIT_PROTECTED_BRANCHES` | Branches protégées (séparées par des virgules) | `MCP_GIT_PROTECTED_BRANCHES=main,master` |

Pour utiliser ces variables d'environnement dans la configuration Roo:

```json
"env": {
  "MCP_GIT_DEBUG": "true",
  "MCP_GIT_LOG_LEVEL": "debug"
}
```

Ajoutez cette propriété `env` au même niveau que `name`, `type`, etc. dans la configuration du serveur MCP.
<!-- END_SECTION: environment_variables -->

<!-- START_SECTION: repository_configuration -->
## Configuration des dépôts

### Configuration des dépôts locaux

Pour optimiser l'utilisation du MCP Git avec des dépôts locaux:

1. **Initialisation d'un dépôt**:

```bash
git init /chemin/vers/nouveau/depot
cd /chemin/vers/nouveau/depot
git config user.name "Votre Nom"
git config user.email "votre.email@exemple.com"
```

2. **Configuration d'un dépôt existant**:

```bash
cd /chemin/vers/depot/existant
git config --local user.name "Votre Nom"
git config --local user.email "votre.email@exemple.com"
```

### Configuration des dépôts distants

Pour configurer des dépôts distants:

1. **Ajout d'un dépôt distant**:

```bash
cd /chemin/vers/depot/local
git remote add origin https://github.com/utilisateur/depot.git
```

2. **Configuration des URL de push et pull**:

```bash
git config remote.origin.pushurl https://github.com/utilisateur/depot.git
git config remote.origin.url https://github.com/utilisateur/depot.git
```

3. **Configuration du suivi de branche**:

```bash
git branch --set-upstream-to=origin/main main
```
<!-- END_SECTION: repository_configuration -->

<!-- START_SECTION: security_considerations -->
## Considérations de sécurité

L'accès à Git via le MCP présente certains risques de sécurité. Voici quelques recommandations:

### Limiter l'accès aux dépôts

Limitez l'accès aux dépôts contenant des informations sensibles:

```json
"args": [
  "-y",
  "@modelcontextprotocol/server-git",
  "--allowed-repos=/chemin/vers/repos/publics"
]
```

### Protéger les branches importantes

Protégez les branches importantes contre les modifications accidentelles:

```json
"args": [
  "-y",
  "@modelcontextprotocol/server-git",
  "--protected-branches=main,master,production"
]
```

### Sécuriser les informations d'identification

- Évitez de stocker des informations d'identification en texte clair
- Utilisez SSH plutôt que HTTPS lorsque c'est possible
- Utilisez des jetons d'accès personnels avec des permissions limitées plutôt que des mots de passe

### Auditer les opérations Git

Activez la journalisation pour surveiller les opérations Git:

```json
"args": [
  "-y",
  "@modelcontextprotocol/server-git",
  "--log-level=info"
]
```

### Mises à jour régulières

Maintenez le MCP Git et Git à jour pour bénéficier des dernières corrections de sécurité:

```bash
npm update -g @modelcontextprotocol/server-git
```
<!-- END_SECTION: security_considerations -->

<!-- START_SECTION: troubleshooting -->
## Résolution des problèmes de configuration

Si vous rencontrez des problèmes avec la configuration du MCP Git:

- **Le serveur MCP ne démarre pas**: Vérifiez que Git est correctement installé et accessible dans le PATH
- **Erreurs d'authentification**: Vérifiez vos informations d'identification Git et la configuration de l'authentification
- **Problèmes d'accès aux dépôts**: Vérifiez les permissions des répertoires et la configuration des dépôts autorisés
- **Erreurs lors des opérations Git**: Vérifiez les logs Git et les messages d'erreur

Pour plus de détails sur la résolution des problèmes, consultez le fichier [TROUBLESHOOTING.md](./TROUBLESHOOTING.md).
<!-- END_SECTION: troubleshooting -->

<!-- START_SECTION: next_steps -->
## Prochaines étapes

Maintenant que vous avez configuré le MCP Git, vous pouvez:

1. [Apprendre à utiliser le MCP Git](./USAGE.md)
2. [Explorer les cas d'utilisation avancés](./USAGE.md#cas-dutilisation-avancés)
<!-- END_SECTION: next_steps -->