# Exemples d'utilisation du serveur MCP Git

Ce document présente des exemples concrets d'utilisation du serveur MCP Git avec Roo.

## Prérequis

Assurez-vous que:
- Le serveur MCP Git est correctement installé et configuré
- Vous avez un token d'accès personnel GitHub avec les permissions appropriées

## Exemples d'utilisation des outils

### Rechercher des dépôts GitHub

```xml
<use_mcp_tool>
<server_name>github.com/modelcontextprotocol/servers/tree/main/src/git</server_name>
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
<server_name>github.com/modelcontextprotocol/servers/tree/main/src/git</server_name>
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

### Lister les commits d'une branche

```xml
<use_mcp_tool>
<server_name>github.com/modelcontextprotocol/servers/tree/main/src/git</server_name>
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

### Créer ou mettre à jour un fichier

```xml
<use_mcp_tool>
<server_name>github.com/modelcontextprotocol/servers/tree/main/src/git</server_name>
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

### Créer un nouveau dépôt

```xml
<use_mcp_tool>
<server_name>github.com/modelcontextprotocol/servers/tree/main/src/git</server_name>
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

## Scénarios d'utilisation

### Scénario 1: Analyse de code source

Ce scénario montre comment utiliser le serveur MCP Git pour analyser un projet de code source:

```xml
<!-- Rechercher un dépôt spécifique -->
<use_mcp_tool>
<server_name>github.com/modelcontextprotocol/servers/tree/main/src/git</server_name>
<tool_name>search_repositories</tool_name>
<arguments>
{
  "query": "repo:username/repository"
}
</arguments>
</use_mcp_tool>

<!-- Lister les commits récents -->
<use_mcp_tool>
<server_name>github.com/modelcontextprotocol/servers/tree/main/src/git</server_name>
<tool_name>list_commits</tool_name>
<arguments>
{
  "owner": "username",
  "repo": "repository",
  "sha": "main"
}
</arguments>
</use_mcp_tool>

<!-- Obtenir le contenu d'un fichier spécifique -->
<use_mcp_tool>
<server_name>github.com/modelcontextprotocol/servers/tree/main/src/git</server_name>
<tool_name>get_file_contents</tool_name>
<arguments>
{
  "owner": "username",
  "repo": "repository",
  "path": "src/main.js"
}
</arguments>
</use_mcp_tool>

<!-- Rechercher du code spécifique dans le dépôt -->
<use_mcp_tool>
<server_name>github.com/modelcontextprotocol/servers/tree/main/src/git</server_name>
<tool_name>search_code</tool_name>
<arguments>
{
  "q": "function in:file language:javascript repo:username/repository"
}
</arguments>
</use_mcp_tool>
```

### Scénario 2: Contribution à un projet open source

Ce scénario montre comment utiliser le serveur MCP Git pour contribuer à un projet open source:

```xml
<!-- Rechercher un dépôt open source -->
<use_mcp_tool>
<server_name>github.com/modelcontextprotocol/servers/tree/main/src/git</server_name>
<tool_name>search_repositories</tool_name>
<arguments>
{
  "query": "topic:hacktoberfest language:python"
}
</arguments>
</use_mcp_tool>

<!-- Forker le dépôt -->
<use_mcp_tool>
<server_name>github.com/modelcontextprotocol/servers/tree/main/src/git</server_name>
<tool_name>fork_repository</tool_name>
<arguments>
{
  "owner": "original-owner",
  "repo": "open-source-project"
}
</arguments>
</use_mcp_tool>

<!-- Créer une branche pour la contribution -->
<use_mcp_tool>
<server_name>github.com/modelcontextprotocol/servers/tree/main/src/git</server_name>
<tool_name>create_branch</tool_name>
<arguments>
{
  "owner": "your-username",
  "repo": "open-source-project",
  "branch": "fix-issue-123",
  "from_branch": "main"
}
</arguments>
</use_mcp_tool>

<!-- Modifier un fichier -->
<use_mcp_tool>
<server_name>github.com/modelcontextprotocol/servers/tree/main/src/git</server_name>
<tool_name>create_or_update_file</tool_name>
<arguments>
{
  "owner": "your-username",
  "repo": "open-source-project",
  "path": "README.md",
  "content": "# Open Source Project\n\nThis project has been improved with a fix for issue #123.\n\n## Features\n\n- Existing feature\n- Fixed feature\n",
  "message": "Fix issue #123",
  "branch": "fix-issue-123"
}
</arguments>
</use_mcp_tool>

<!-- Créer une pull request -->
<use_mcp_tool>
<server_name>github.com/modelcontextprotocol/servers/tree/main/src/git</server_name>
<tool_name>create_pull_request</tool_name>
<arguments>
{
  "owner": "original-owner",
  "repo": "open-source-project",
  "title": "Fix issue #123",
  "body": "This pull request fixes issue #123 by improving the README documentation.",
  "head": "your-username:fix-issue-123",
  "base": "main"
}
</arguments>
</use_mcp_tool>
```

### Scénario 3: Recherche de code et d'issues

Ce scénario montre comment utiliser le serveur MCP Git pour rechercher du code et des issues:

```xml
<!-- Rechercher des dépôts sur un sujet spécifique -->
<use_mcp_tool>
<server_name>github.com/modelcontextprotocol/servers/tree/main/src/git</server_name>
<tool_name>search_repositories</tool_name>
<arguments>
{
  "query": "topic:machine-learning language:python stars:>100"
}
</arguments>
</use_mcp_tool>

<!-- Rechercher du code spécifique -->
<use_mcp_tool>
<server_name>github.com/modelcontextprotocol/servers/tree/main/src/git</server_name>
<tool_name>search_code</tool_name>
<arguments>
{
  "q": "import tensorflow language:python"
}
</arguments>
</use_mcp_tool>

<!-- Rechercher des issues avec un label spécifique -->
<use_mcp_tool>
<server_name>github.com/modelcontextprotocol/servers/tree/main/src/git</server_name>
<tool_name>search_issues</tool_name>
<arguments>
{
  "q": "is:issue is:open label:bug language:python"
}
</arguments>
</use_mcp_tool>

<!-- Obtenir les détails d'une issue spécifique -->
<use_mcp_tool>
<server_name>github.com/modelcontextprotocol/servers/tree/main/src/git</server_name>
<tool_name>get_issue</tool_name>
<arguments>
{
  "owner": "username",
  "repo": "repository",
  "issue_number": 123
}
</arguments>
</use_mcp_tool>
```

## Différence avec le serveur MCP GitHub

Le serveur MCP Git et le serveur MCP GitHub utilisent le même package sous-jacent (`@modelcontextprotocol/server-github`), mais ils sont configurés avec des identifiants différents dans le fichier de configuration MCP de Roo:

- Le serveur MCP Git utilise l'identifiant `github.com/modelcontextprotocol/servers/tree/main/src/git`
- Le serveur MCP GitHub utilise l'identifiant `github.com/modelcontextprotocol/servers/tree/main/src/github`

Cette séparation permet d'avoir deux instances distinctes du même serveur, chacune avec sa propre configuration et ses propres permissions.

### Exemple d'utilisation combinée

Voici un exemple d'utilisation combinée des serveurs MCP Git et GitHub:

```xml
<!-- Utiliser le serveur MCP Git pour rechercher des dépôts -->
<use_mcp_tool>
<server_name>github.com/modelcontextprotocol/servers/tree/main/src/git</server_name>
<tool_name>search_repositories</tool_name>
<arguments>
{
  "query": "language:javascript stars:>1000"
}
</arguments>
</use_mcp_tool>

<!-- Utiliser le serveur MCP Git pour obtenir le contenu d'un fichier -->
<use_mcp_tool>
<server_name>github.com/modelcontextprotocol/servers/tree/main/src/git</server_name>
<tool_name>get_file_contents</tool_name>
<arguments>
{
  "owner": "username",
  "repo": "repository",
  "path": "src/main.js"
}
</arguments>
</use_mcp_tool>

<!-- Utiliser le serveur MCP GitHub pour créer un nouveau dépôt -->
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

<!-- Utiliser le serveur MCP GitHub pour créer un fichier dans le nouveau dépôt -->
<use_mcp_tool>
<server_name>github.com/modelcontextprotocol/servers/tree/main/src/github</server_name>
<tool_name>create_or_update_file</tool_name>
<arguments>
{
  "owner": "username",
  "repo": "nouveau-depot",
  "path": "src/main.js",
  "content": "console.log('Hello, world!');",
  "message": "Ajout d'un nouveau fichier",
  "branch": "main"
}
</arguments>
</use_mcp_tool>
```

## Bonnes pratiques

1. **Utilisez des tokens avec des permissions limitées**: N'accordez que les permissions nécessaires à votre token d'accès personnel GitHub.
2. **Évitez de stocker des informations sensibles**: N'incluez jamais de mots de passe, de tokens ou d'autres informations sensibles dans les fichiers que vous poussez sur GitHub.
3. **Utilisez des messages de commit descriptifs**: Les messages de commit doivent être clairs et descriptifs pour faciliter la compréhension des modifications.
4. **Testez vos modifications localement**: Avant de pousser des modifications sur GitHub, testez-les localement pour vous assurer qu'elles fonctionnent comme prévu.
5. **Utilisez le serveur approprié**: Utilisez le serveur MCP Git pour les opérations de lecture et le serveur MCP GitHub pour les opérations d'écriture, si vous avez configuré vos tokens avec des permissions différentes.