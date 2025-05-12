# Exemples d'utilisation du serveur MCP GitHub

Ce document présente des exemples concrets d'utilisation du serveur MCP GitHub avec Roo.

## Prérequis

Assurez-vous que:
- Le serveur MCP GitHub est correctement installé et configuré
- Vous avez un token d'accès personnel GitHub avec les permissions appropriées

## Exemples d'utilisation des outils

### Rechercher des dépôts GitHub

```xml
<use_mcp_tool>
<server_name>github.com/modelcontextprotocol/servers/tree/main/src/github</server_name>
<tool_name>search_repositories</tool_name>
<arguments>
{
  "query": "language:javascript stars:>1000"
}
</arguments>
</use_mcp_tool>
```

### Obtenir le contenu d'un fichier

```xml
<use_mcp_tool>
<server_name>github.com/modelcontextprotocol/servers/tree/main/src/github</server_name>
<tool_name>get_file_contents</tool_name>
<arguments>
{
  "owner": "username",
  "repo": "repository",
  "path": "path/to/file.js"
}
</arguments>
</use_mcp_tool>
```

### Créer un nouveau dépôt

```xml
<use_mcp_tool>
<server_name>github.com/modelcontextprotocol/servers/tree/main/src/github</server_name>
<tool_name>create_repository</tool_name>
<arguments>
{
  "name": "nouveau-depot",
  "description": "Description du nouveau dépôt",
  "private": false,
  "autoInit": true
}
</arguments>
</use_mcp_tool>
```

### Créer ou mettre à jour un fichier

```xml
<use_mcp_tool>
<server_name>github.com/modelcontextprotocol/servers/tree/main/src/github</server_name>
<tool_name>create_or_update_file</tool_name>
<arguments>
{
  "owner": "username",
  "repo": "repository",
  "path": "path/to/file.js",
  "content": "console.log('Hello, world!');",
  "message": "Ajout d'un nouveau fichier",
  "branch": "main"
}
</arguments>
</use_mcp_tool>
```

### Pousser plusieurs fichiers en un seul commit

```xml
<use_mcp_tool>
<server_name>github.com/modelcontextprotocol/servers/tree/main/src/github</server_name>
<tool_name>push_files</tool_name>
<arguments>
{
  "owner": "username",
  "repo": "repository",
  "branch": "main",
  "files": [
    {
      "path": "file1.js",
      "content": "console.log('File 1');"
    },
    {
      "path": "file2.js",
      "content": "console.log('File 2');"
    }
  ],
  "message": "Ajout de plusieurs fichiers"
}
</arguments>
</use_mcp_tool>
```

### Créer une issue

```xml
<use_mcp_tool>
<server_name>github.com/modelcontextprotocol/servers/tree/main/src/github</server_name>
<tool_name>create_issue</tool_name>
<arguments>
{
  "owner": "username",
  "repo": "repository",
  "title": "Titre de l'issue",
  "body": "Description de l'issue",
  "labels": ["bug", "help wanted"]
}
</arguments>
</use_mcp_tool>
```

### Créer une pull request

```xml
<use_mcp_tool>
<server_name>github.com/modelcontextprotocol/servers/tree/main/src/github</server_name>
<tool_name>create_pull_request</tool_name>
<arguments>
{
  "owner": "username",
  "repo": "repository",
  "title": "Titre de la pull request",
  "body": "Description de la pull request",
  "head": "feature-branch",
  "base": "main"
}
</arguments>
</use_mcp_tool>
```

### Forker un dépôt

```xml
<use_mcp_tool>
<server_name>github.com/modelcontextprotocol/servers/tree/main/src/github</server_name>
<tool_name>fork_repository</tool_name>
<arguments>
{
  "owner": "username",
  "repo": "repository"
}
</arguments>
</use_mcp_tool>
```

### Créer une branche

```xml
<use_mcp_tool>
<server_name>github.com/modelcontextprotocol/servers/tree/main/src/github</server_name>
<tool_name>create_branch</tool_name>
<arguments>
{
  "owner": "username",
  "repo": "repository",
  "branch": "nouvelle-branche",
  "from_branch": "main"
}
</arguments>
</use_mcp_tool>
```

### Lister les commits d'une branche

```xml
<use_mcp_tool>
<server_name>github.com/modelcontextprotocol/servers/tree/main/src/github</server_name>
<tool_name>list_commits</tool_name>
<arguments>
{
  "owner": "username",
  "repo": "repository",
  "sha": "main"
}
</arguments>
</use_mcp_tool>
```

### Rechercher du code

```xml
<use_mcp_tool>
<server_name>github.com/modelcontextprotocol/servers/tree/main/src/github</server_name>
<tool_name>search_code</tool_name>
<arguments>
{
  "q": "function in:file language:javascript repo:username/repository"
}
</arguments>
</use_mcp_tool>
```

## Scénarios d'utilisation

### Scénario 1: Création d'un nouveau projet

Ce scénario montre comment utiliser le serveur MCP GitHub pour créer un nouveau projet:

```xml
<!-- Créer un nouveau dépôt -->
<use_mcp_tool>
<server_name>github.com/modelcontextprotocol/servers/tree/main/src/github</server_name>
<tool_name>create_repository</tool_name>
<arguments>
{
  "name": "mon-nouveau-projet",
  "description": "Un nouveau projet créé avec Roo",
  "private": false,
  "autoInit": true
}
</arguments>
</use_mcp_tool>

<!-- Ajouter plusieurs fichiers -->
<use_mcp_tool>
<server_name>github.com/modelcontextprotocol/servers/tree/main/src/github</server_name>
<tool_name>push_files</tool_name>
<arguments>
{
  "owner": "username",
  "repo": "mon-nouveau-projet",
  "branch": "main",
  "files": [
    {
      "path": "index.html",
      "content": "<!DOCTYPE html>\n<html>\n<head>\n  <title>Mon Nouveau Projet</title>\n</head>\n<body>\n  <h1>Bienvenue sur mon nouveau projet</h1>\n</body>\n</html>"
    },
    {
      "path": "styles.css",
      "content": "body {\n  font-family: Arial, sans-serif;\n  margin: 0;\n  padding: 20px;\n}\n\nh1 {\n  color: #333;\n}"
    },
    {
      "path": "script.js",
      "content": "console.log('Projet initialisé avec succès!');"
    }
  ],
  "message": "Initialisation du projet avec les fichiers de base"
}
</arguments>
</use_mcp_tool>

<!-- Créer une issue pour les tâches à faire -->
<use_mcp_tool>
<server_name>github.com/modelcontextprotocol/servers/tree/main/src/github</server_name>
<tool_name>create_issue</tool_name>
<arguments>
{
  "owner": "username",
  "repo": "mon-nouveau-projet",
  "title": "Tâches à faire",
  "body": "- [ ] Ajouter une navigation\n- [ ] Créer une page de contact\n- [ ] Implémenter un formulaire",
  "labels": ["enhancement"]
}
</arguments>
</use_mcp_tool>
```

### Scénario 2: Contribution à un projet existant

Ce scénario montre comment utiliser le serveur MCP GitHub pour contribuer à un projet existant:

```xml
<!-- Forker le dépôt -->
<use_mcp_tool>
<server_name>github.com/modelcontextprotocol/servers/tree/main/src/github</server_name>
<tool_name>fork_repository</tool_name>
<arguments>
{
  "owner": "original-owner",
  "repo": "projet-existant"
}
</arguments>
</use_mcp_tool>

<!-- Créer une branche pour la contribution -->
<use_mcp_tool>
<server_name>github.com/modelcontextprotocol/servers/tree/main/src/github</server_name>
<tool_name>create_branch</tool_name>
<arguments>
{
  "owner": "username",
  "repo": "projet-existant",
  "branch": "feature-nouvelle-fonctionnalite",
  "from_branch": "main"
}
</arguments>
</use_mcp_tool>

<!-- Modifier un fichier -->
<use_mcp_tool>
<server_name>github.com/modelcontextprotocol/servers/tree/main/src/github</server_name>
<tool_name>create_or_update_file</tool_name>
<arguments>
{
  "owner": "username",
  "repo": "projet-existant",
  "path": "README.md",
  "content": "# Projet Existant\n\nCe projet a été amélioré avec une nouvelle fonctionnalité.\n\n## Fonctionnalités\n\n- Fonctionnalité existante\n- Nouvelle fonctionnalité\n",
  "message": "Mise à jour du README avec la nouvelle fonctionnalité",
  "branch": "feature-nouvelle-fonctionnalite"
}
</arguments>
</use_mcp_tool>

<!-- Créer une pull request -->
<use_mcp_tool>
<server_name>github.com/modelcontextprotocol/servers/tree/main/src/github</server_name>
<tool_name>create_pull_request</tool_name>
<arguments>
{
  "owner": "original-owner",
  "repo": "projet-existant",
  "title": "Ajout d'une nouvelle fonctionnalité",
  "body": "Cette pull request ajoute une nouvelle fonctionnalité au projet.\n\n## Modifications\n\n- Mise à jour du README\n- Ajout de la nouvelle fonctionnalité\n\n## Tests\n\nLa fonctionnalité a été testée et fonctionne comme prévu.",
  "head": "username:feature-nouvelle-fonctionnalite",
  "base": "main"
}
</arguments>
</use_mcp_tool>
```

### Scénario 3: Gestion d'issues et de pull requests

Ce scénario montre comment utiliser le serveur MCP GitHub pour gérer des issues et des pull requests:

```xml
<!-- Lister les issues ouvertes -->
<use_mcp_tool>
<server_name>github.com/modelcontextprotocol/servers/tree/main/src/github</server_name>
<tool_name>list_issues</tool_name>
<arguments>
{
  "owner": "username",
  "repo": "repository",
  "state": "open"
}
</arguments>
</use_mcp_tool>

<!-- Ajouter un commentaire à une issue -->
<use_mcp_tool>
<server_name>github.com/modelcontextprotocol/servers/tree/main/src/github</server_name>
<tool_name>add_issue_comment</tool_name>
<arguments>
{
  "owner": "username",
  "repo": "repository",
  "issue_number": 1,
  "body": "Je travaille sur cette issue. Voici ce que j'ai fait jusqu'à présent:\n\n- Implémenté la fonctionnalité A\n- Testé la fonctionnalité B\n\nJe devrais avoir terminé d'ici demain."
}
</arguments>
</use_mcp_tool>

<!-- Lister les pull requests ouvertes -->
<use_mcp_tool>
<server_name>github.com/modelcontextprotocol/servers/tree/main/src/github</server_name>
<tool_name>list_pull_requests</tool_name>
<arguments>
{
  "owner": "username",
  "repo": "repository",
  "state": "open"
}
</arguments>
</use_mcp_tool>

<!-- Créer une revue sur une pull request -->
<use_mcp_tool>
<server_name>github.com/modelcontextprotocol/servers/tree/main/src/github</server_name>
<tool_name>create_pull_request_review</tool_name>
<arguments>
{
  "owner": "username",
  "repo": "repository",
  "pull_number": 1,
  "body": "J'ai examiné cette pull request et tout semble bon. Quelques suggestions mineures ci-dessous.",
  "event": "COMMENT",
  "comments": [
    {
      "path": "file.js",
      "line": 10,
      "body": "Peut-être ajouter un commentaire ici pour expliquer ce que fait cette fonction?"
    }
  ]
}
</arguments>
</use_mcp_tool>
```

## Bonnes pratiques

1. **Utilisez des tokens avec des permissions limitées**: N'accordez que les permissions nécessaires à votre token d'accès personnel GitHub.
2. **Évitez de stocker des informations sensibles**: N'incluez jamais de mots de passe, de tokens ou d'autres informations sensibles dans les fichiers que vous poussez sur GitHub.
3. **Utilisez des messages de commit descriptifs**: Les messages de commit doivent être clairs et descriptifs pour faciliter la compréhension des modifications.
4. **Testez vos modifications localement**: Avant de pousser des modifications sur GitHub, testez-les localement pour vous assurer qu'elles fonctionnent comme prévu.
5. **Utilisez des branches pour les fonctionnalités**: Créez une nouvelle branche pour chaque fonctionnalité ou correction de bug pour faciliter la gestion des modifications.