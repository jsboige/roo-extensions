# Configuration du serveur MCP Git

Ce guide détaille les options de configuration du serveur MCP Git pour l'intégration avec Roo.

## Configuration dans le fichier MCP de Roo

La configuration du serveur MCP Git se fait dans le fichier de configuration MCP de Roo, généralement situé à:

```
%APPDATA%\Code\User\globalStorage\rooveterinaryinc.roo-cline\settings\mcp_settings.json
```

Voici un exemple de configuration complète:

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

## Options de configuration

### Token d'accès personnel GitHub

Le serveur MCP Git nécessite un token d'accès personnel GitHub pour authentifier les requêtes. Ce token est spécifié dans la variable d'environnement `GITHUB_PERSONAL_ACCESS_TOKEN`:

```json
"env": {
  "GITHUB_PERSONAL_ACCESS_TOKEN": "votre_token_github"
}
```

Remplacez `votre_token_github` par votre token d'accès personnel GitHub.

### Outils autorisés

La liste `alwaysAllow` spécifie les outils qui peuvent être utilisés sans demander de confirmation à l'utilisateur:

```json
"alwaysAllow": [
  "search_repositories",
  "get_file_contents",
  "create_repository",
  "list_commits",
  "create_or_update_file"
]
```

Voici la liste complète des outils disponibles:

- `create_or_update_file`: Créer ou mettre à jour un fichier dans un dépôt GitHub
- `search_repositories`: Rechercher des dépôts GitHub
- `create_repository`: Créer un nouveau dépôt GitHub
- `get_file_contents`: Obtenir le contenu d'un fichier ou d'un répertoire
- `push_files`: Pousser plusieurs fichiers dans un dépôt en un seul commit
- `create_issue`: Créer une nouvelle issue dans un dépôt
- `create_pull_request`: Créer une nouvelle pull request
- `fork_repository`: Forker un dépôt
- `create_branch`: Créer une nouvelle branche
- `list_commits`: Lister les commits d'une branche
- `list_issues`: Lister les issues d'un dépôt
- `update_issue`: Mettre à jour une issue existante
- `add_issue_comment`: Ajouter un commentaire à une issue
- `search_code`: Rechercher du code dans des dépôts
- `search_issues`: Rechercher des issues et des pull requests
- `search_users`: Rechercher des utilisateurs GitHub
- `get_issue`: Obtenir les détails d'une issue
- `get_pull_request`: Obtenir les détails d'une pull request
- `list_pull_requests`: Lister les pull requests d'un dépôt
- `create_pull_request_review`: Créer une revue sur une pull request
- `merge_pull_request`: Fusionner une pull request
- `get_pull_request_files`: Obtenir la liste des fichiers modifiés dans une pull request
- `get_pull_request_status`: Obtenir le statut des vérifications d'une pull request
- `update_pull_request_branch`: Mettre à jour une branche de pull request
- `get_pull_request_comments`: Obtenir les commentaires d'une pull request
- `get_pull_request_reviews`: Obtenir les revues d'une pull request

### Approbation automatique

La liste `autoApprove` spécifie les outils qui sont automatiquement approuvés sans afficher de notification à l'utilisateur:

```json
"autoApprove": []
```

Par défaut, cette liste est vide, ce qui signifie que tous les outils nécessitent une notification à l'utilisateur.

### Désactivation du serveur

L'option `disabled` permet de désactiver temporairement le serveur MCP Git:

```json
"disabled": false
```

Mettez cette valeur à `true` pour désactiver le serveur.

## Différence avec le serveur MCP GitHub

Le serveur MCP Git et le serveur MCP GitHub utilisent le même package sous-jacent (`@modelcontextprotocol/server-github`), mais ils sont configurés avec des identifiants différents dans le fichier de configuration MCP de Roo:

- Le serveur MCP Git utilise l'identifiant `github.com/modelcontextprotocol/servers/tree/main/src/git`
- Le serveur MCP GitHub utilise l'identifiant `github.com/modelcontextprotocol/servers/tree/main/src/github`

Cette séparation permet d'avoir deux instances distinctes du même serveur, chacune avec sa propre configuration et ses propres permissions.

### Cas d'utilisation typiques

Voici quelques cas d'utilisation typiques pour cette séparation:

1. **Séparation des permissions**:
   - Serveur MCP Git: Token avec permissions de lecture seule pour les opérations de consultation
   - Serveur MCP GitHub: Token avec permissions complètes pour les opérations d'écriture

2. **Séparation des outils autorisés**:
   - Serveur MCP Git: Autoriser uniquement les outils de lecture (`search_repositories`, `get_file_contents`, etc.)
   - Serveur MCP GitHub: Autoriser tous les outils, y compris ceux d'écriture

3. **Utilisation de différents comptes GitHub**:
   - Serveur MCP Git: Token associé à un compte personnel
   - Serveur MCP GitHub: Token associé à un compte d'organisation

## Configuration avancée

### Utilisation avec GitHub Enterprise

Si vous utilisez GitHub Enterprise, vous pouvez configurer l'URL de base de l'API en définissant la variable d'environnement `GITHUB_API_URL`:

```json
"env": {
  "GITHUB_PERSONAL_ACCESS_TOKEN": "votre_token_github",
  "GITHUB_API_URL": "https://github.enterprise.com/api/v3"
}
```

### Gestion des permissions

Le serveur MCP Git utilise les permissions associées à votre token d'accès personnel GitHub. Assurez-vous que le token a les permissions nécessaires pour les opérations que vous souhaitez effectuer.

Voici les permissions recommandées pour différents cas d'utilisation:

#### Lecture seule

Pour les opérations de lecture seule (recherche, lecture de fichiers, etc.), les permissions suivantes sont suffisantes:

- `public_repo` (pour les dépôts publics)
- `repo:read` (pour les dépôts privés)

#### Écriture

Pour les opérations d'écriture (création de fichiers, issues, pull requests, etc.), les permissions suivantes sont nécessaires:

- `repo` (accès complet aux dépôts)
- `workflow` (si vous souhaitez gérer les workflows GitHub Actions)

## Exemple de configuration complète

Voici un exemple de configuration complète pour le serveur MCP Git avec des permissions limitées à la lecture:

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
        "GITHUB_PERSONAL_ACCESS_TOKEN": "votre_token_github_lecture_seule"
      },
      "disabled": false,
      "autoApprove": [
        "search_repositories",
        "get_file_contents"
      ],
      "alwaysAllow": [
        "search_repositories",
        "get_file_contents",
        "list_commits",
        "search_code",
        "search_issues",
        "search_users",
        "list_issues",
        "list_pull_requests",
        "get_issue",
        "get_pull_request"
      ],
      "transportType": "stdio"
    }
  }
}
```

Cette configuration:
- Utilise un token d'accès personnel GitHub avec des permissions limitées à la lecture
- Approuve automatiquement les outils `search_repositories` et `get_file_contents`
- Permet l'utilisation sans confirmation des outils de lecture listés dans `alwaysAllow`

## Bonnes pratiques de sécurité

1. **Limitez les permissions du token**: N'accordez que les permissions nécessaires à votre token d'accès personnel GitHub.
2. **Définissez une date d'expiration**: Définissez une date d'expiration pour votre token afin de limiter les risques en cas de compromission.
3. **Utilisez des variables d'environnement**: Évitez de stocker votre token directement dans le fichier de configuration. Utilisez plutôt des variables d'environnement ou un gestionnaire de secrets.
4. **Révoquez les tokens inutilisés**: Révoquez régulièrement les tokens que vous n'utilisez plus.
5. **Surveillez l'activité**: Surveillez régulièrement l'activité de votre compte GitHub pour détecter toute activité suspecte.