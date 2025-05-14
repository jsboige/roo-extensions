# Configuration du GitHub MCP Server

Ce document détaille les options de configuration disponibles pour le GitHub MCP Server.

## Configuration des ensembles d'outils (Toolsets)

Le GitHub MCP Server permet d'activer ou désactiver des groupes spécifiques de fonctionnalités via l'option `--toolsets` ou la variable d'environnement `GITHUB_TOOLSETS`. Cela vous permet de contrôler quelles API GitHub sont accessibles à vos outils d'IA.

### Ensembles d'outils disponibles

| Ensemble d'outils | Description |
|-------------------|-------------|
| `repos` | Outils liés aux dépôts (opérations sur les fichiers, branches, commits) |
| `issues` | Outils liés aux issues (création, lecture, mise à jour, commentaires) |
| `users` | Outils liés aux utilisateurs GitHub |
| `pull_requests` | Opérations sur les pull requests (création, fusion, révision) |
| `code_security` | Alertes de scan de code et fonctionnalités de sécurité |
| `experiments` | Fonctionnalités expérimentales (non considérées comme stables) |

Par défaut, tous les ensembles d'outils sont activés.

### Spécifier les ensembles d'outils

#### Avec Docker (recommandé)

```json
{
  "github": {
    "command": "docker",
    "args": [
      "run",
      "-i",
      "--rm",
      "-e",
      "GITHUB_PERSONAL_ACCESS_TOKEN",
      "-e",
      "GITHUB_TOOLSETS=repos,issues,pull_requests",
      "ghcr.io/github/github-mcp-server"
    ],
    "env": {
      "GITHUB_PERSONAL_ACCESS_TOKEN": "votre_token_github"
    }
  }
}
```

#### Avec le binaire compilé

```json
{
  "github": {
    "command": "chemin/vers/github-mcp-server",
    "args": ["stdio", "--toolsets", "repos,issues,pull_requests"],
    "env": {
      "GITHUB_PERSONAL_ACCESS_TOKEN": "votre_token_github"
    }
  }
}
```

### L'ensemble d'outils "all"

L'ensemble d'outils spécial `all` peut être fourni pour activer tous les ensembles d'outils disponibles :

```json
{
  "github": {
    "command": "docker",
    "args": [
      "run",
      "-i",
      "--rm",
      "-e",
      "GITHUB_PERSONAL_ACCESS_TOKEN",
      "-e",
      "GITHUB_TOOLSETS=all",
      "ghcr.io/github/github-mcp-server"
    ],
    "env": {
      "GITHUB_PERSONAL_ACCESS_TOKEN": "votre_token_github"
    }
  }
}
```

## Découverte dynamique d'outils

Au lieu de démarrer avec tous les outils activés, vous pouvez activer la découverte dynamique des ensembles d'outils. Cette fonctionnalité permet à l'hôte MCP de lister et d'activer les ensembles d'outils en réponse à une requête utilisateur.

### Avec Docker

```json
{
  "github": {
    "command": "docker",
    "args": [
      "run",
      "-i",
      "--rm",
      "-e",
      "GITHUB_PERSONAL_ACCESS_TOKEN",
      "-e",
      "GITHUB_DYNAMIC_TOOLSETS=1",
      "ghcr.io/github/github-mcp-server"
    ],
    "env": {
      "GITHUB_PERSONAL_ACCESS_TOKEN": "votre_token_github"
    }
  }
}
```

### Avec le binaire compilé

```json
{
  "github": {
    "command": "chemin/vers/github-mcp-server",
    "args": ["stdio", "--dynamic-toolsets"],
    "env": {
      "GITHUB_PERSONAL_ACCESS_TOKEN": "votre_token_github"
    }
  }
}
```

## GitHub Enterprise Server

Si vous utilisez GitHub Enterprise Server, vous pouvez spécifier l'hôte avec le drapeau `--gh-host` ou la variable d'environnement `GITHUB_HOST`.

### Avec Docker

```json
{
  "github": {
    "command": "docker",
    "args": [
      "run",
      "-i",
      "--rm",
      "-e",
      "GITHUB_PERSONAL_ACCESS_TOKEN",
      "-e",
      "GITHUB_HOST=github.entreprise.com",
      "ghcr.io/github/github-mcp-server"
    ],
    "env": {
      "GITHUB_PERSONAL_ACCESS_TOKEN": "votre_token_github"
    }
  }
}
```

### Avec le binaire compilé

```json
{
  "github": {
    "command": "chemin/vers/github-mcp-server",
    "args": ["stdio", "--gh-host", "github.entreprise.com"],
    "env": {
      "GITHUB_PERSONAL_ACCESS_TOKEN": "votre_token_github"
    }
  }
}
```

## Internationalisation et remplacement des descriptions

Vous pouvez remplacer les descriptions des outils en créant un fichier `github-mcp-server-config.json` dans le même répertoire que le binaire ou en utilisant des variables d'environnement.

### Avec un fichier de configuration

Créez un fichier `github-mcp-server-config.json` :

```json
{
  "TOOL_ADD_ISSUE_COMMENT_DESCRIPTION": "Ajouter un commentaire à une issue",
  "TOOL_CREATE_BRANCH_DESCRIPTION": "Créer une nouvelle branche dans un dépôt GitHub"
}
```

### Avec des variables d'environnement

```json
{
  "github": {
    "command": "docker",
    "args": [
      "run",
      "-i",
      "--rm",
      "-e",
      "GITHUB_PERSONAL_ACCESS_TOKEN",
      "-e",
      "GITHUB_MCP_TOOL_ADD_ISSUE_COMMENT_DESCRIPTION=Ajouter un commentaire à une issue",
      "ghcr.io/github/github-mcp-server"
    ],
    "env": {
      "GITHUB_PERSONAL_ACCESS_TOKEN": "votre_token_github"
    }
  }
}
```

### Exporter les traductions actuelles

Pour exporter les traductions actuelles, exécutez le binaire avec le drapeau `--export-translations` :

```bash
./github-mcp-server --export-translations
```

Cela créera un fichier `github-mcp-server-config.json` avec toutes les descriptions actuelles.