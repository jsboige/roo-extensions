# Installation du serveur MCP Git

Ce guide détaille les étapes pour installer et configurer le serveur MCP Git qui permet à Roo d'interagir avec l'API GitHub.

## Prérequis

- Node.js (version 14 ou supérieure)
- NPM (version 6 ou supérieure)
- Un compte GitHub
- Un token d'accès personnel GitHub avec les permissions appropriées

## Création d'un token d'accès personnel GitHub

Avant d'installer le serveur MCP Git, vous devez créer un token d'accès personnel GitHub:

1. Connectez-vous à votre compte GitHub
2. Accédez à **Settings** > **Developer settings** > **Personal access tokens** > **Tokens (classic)**
3. Cliquez sur **Generate new token** > **Generate new token (classic)**
4. Donnez un nom à votre token (par exemple, "Roo MCP Git")
5. Sélectionnez les permissions suivantes (selon vos besoins):
   - `repo` (accès complet aux dépôts)
   - `workflow` (si vous souhaitez gérer les workflows GitHub Actions)
   - `read:org` (pour accéder aux informations de l'organisation)
   - `gist` (pour créer et gérer des gists)
6. Cliquez sur **Generate token**
7. **Important**: Copiez le token généré et conservez-le en lieu sûr. Vous ne pourrez plus le voir après avoir quitté cette page.

## Installation

### 1. Installation via NPM

Le serveur MCP Git utilise le même package que le serveur MCP GitHub. Pour l'installer, utilisez NPM:

```bash
npm install -g @modelcontextprotocol/server-github
```

Cette commande installe le serveur MCP GitHub globalement sur votre système, ce qui vous permet de l'exécuter depuis n'importe quel répertoire.

### 2. Vérification de l'installation

Pour vérifier que l'installation s'est bien déroulée, vous pouvez exécuter:

```bash
npx @modelcontextprotocol/server-github --help
```

Cette commande devrait afficher l'aide du serveur avec les options disponibles.

## Configuration dans Roo

Pour utiliser le serveur MCP Git avec Roo, vous devez l'ajouter à la configuration MCP de Roo. Voici comment procéder:

1. Ouvrez le fichier de configuration MCP de Roo:
   ```
   %APPDATA%\Code\User\globalStorage\rooveterinaryinc.roo-cline\settings\mcp_settings.json
   ```

2. Ajoutez la configuration du serveur MCP Git:
   ```json
   {
     "mcpServers": {
       "github.com/modelcontextprotocol/servers/tree/main/src/git": {
         "command": "cmd",
         "args": [
           "/c",
           "npx",
           "-y",
           "@modelcontextprotocol/server-github"
         ],
         "env": {
           "GITHUB_PERSONAL_ACCESS_TOKEN": "votre_token_github"
         },
         "disabled": false,
         "autoApprove": [],
         "alwaysAllow": [
           "search_repositories",
           "get_file_contents",
           "create_repository",
           "list_commits",
           "create_or_update_file"
         ],
         "transportType": "stdio"
       }
     }
   }
   ```

3. Remplacez `votre_token_github` par le token d'accès personnel GitHub que vous avez créé précédemment.

4. Ajustez la liste `alwaysAllow` selon les outils que vous souhaitez autoriser sans confirmation.

## Différence avec le serveur MCP GitHub

Le serveur MCP Git et le serveur MCP GitHub utilisent le même package sous-jacent (`@modelcontextprotocol/server-github`), mais ils sont configurés avec des identifiants différents dans le fichier de configuration MCP de Roo:

- Le serveur MCP Git utilise l'identifiant `github.com/modelcontextprotocol/servers/tree/main/src/git`
- Le serveur MCP GitHub utilise l'identifiant `github.com/modelcontextprotocol/servers/tree/main/src/github`

Cette séparation permet d'avoir deux instances distinctes du même serveur, chacune avec sa propre configuration et ses propres permissions.

## Installation manuelle (alternative)

Si vous préférez ne pas installer le package globalement, vous pouvez également l'utiliser directement avec `npx`:

```bash
npx @modelcontextprotocol/server-github
```

Assurez-vous que la variable d'environnement `GITHUB_PERSONAL_ACCESS_TOKEN` est définie avant d'exécuter cette commande:

```bash
# Windows (PowerShell)
$env:GITHUB_PERSONAL_ACCESS_TOKEN="votre_token_github"

# Windows (CMD)
set GITHUB_PERSONAL_ACCESS_TOKEN=votre_token_github

# Linux/macOS
export GITHUB_PERSONAL_ACCESS_TOKEN=votre_token_github
```

## Dépannage

### Problème: Le serveur MCP Git n'est pas reconnu

Si vous obtenez une erreur indiquant que le serveur MCP Git n'est pas reconnu, assurez-vous que:

1. Node.js et NPM sont correctement installés
2. Le package `@modelcontextprotocol/server-github` est installé
3. Le chemin vers Node.js est dans votre variable d'environnement PATH

### Problème: Erreur d'authentification

Si vous obtenez une erreur d'authentification lors de l'utilisation du serveur MCP Git, assurez-vous que:

1. Le token d'accès personnel GitHub est correctement configuré
2. Le token n'a pas expiré
3. Le token a les permissions nécessaires pour les opérations que vous essayez d'effectuer

### Problème: Conflit avec le serveur MCP GitHub

Si vous avez configuré à la fois le serveur MCP Git et le serveur MCP GitHub, assurez-vous que:

1. Les deux serveurs utilisent des identifiants différents dans le fichier de configuration MCP de Roo
2. Vous utilisez le bon identifiant de serveur dans vos appels d'outils MCP

## Mise à jour

Pour mettre à jour le serveur MCP Git vers la dernière version, utilisez:

```bash
npm update -g @modelcontextprotocol/server-github
```

## Désinstallation

Si vous souhaitez désinstaller le serveur MCP Git, utilisez:

```bash
npm uninstall -g @modelcontextprotocol/server-github
```

Notez que cette commande désinstallera également le serveur MCP GitHub si vous l'utilisez.

## Sécurité

Gardez à l'esprit que votre token d'accès personnel GitHub donne accès à votre compte GitHub. Ne le partagez jamais et ne l'incluez pas dans des fichiers qui pourraient être partagés ou versionnés (comme des dépôts Git publics).

Pour plus de sécurité, vous pouvez:
- Limiter les permissions du token au strict nécessaire
- Définir une date d'expiration pour le token
- Révoquer le token lorsque vous n'en avez plus besoin