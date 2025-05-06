# Exemples d'utilisation du GitHub MCP Server avec Roo

Ce document présente des exemples concrets d'utilisation du GitHub MCP Server avec Roo pour interagir avec GitHub.

## Obtenir des informations sur l'utilisateur authentifié

```
<use_mcp_tool>
<server_name>github</server_name>
<tool_name>get_me</tool_name>
<arguments>
{}
</arguments>
</use_mcp_tool>
```

## Gestion des dépôts

### Lister les branches d'un dépôt

```
<use_mcp_tool>
<server_name>github</server_name>
<tool_name>list_branches</tool_name>
<arguments>
{
  "owner": "nom_utilisateur",
  "repo": "nom_depot"
}
</arguments>
</use_mcp_tool>
```

### Créer une nouvelle branche

```
<use_mcp_tool>
<server_name>github</server_name>
<tool_name>create_branch</tool_name>
<arguments>
{
  "owner": "nom_utilisateur",
  "repo": "nom_depot",
  "branch": "nouvelle-branche",
  "sha": "sha_du_commit_de_base"
}
</arguments>
</use_mcp_tool>
```

### Obtenir le contenu d'un fichier

```
<use_mcp_tool>
<server_name>github</server_name>
<tool_name>get_file_contents</tool_name>
<arguments>
{
  "owner": "nom_utilisateur",
  "repo": "nom_depot",
  "path": "chemin/vers/fichier.txt"
}
</arguments>
</use_mcp_tool>
```

### Créer ou mettre à jour un fichier

```
<use_mcp_tool>
<server_name>github</server_name>
<tool_name>create_or_update_file</tool_name>
<arguments>
{
  "owner": "nom_utilisateur",
  "repo": "nom_depot",
  "path": "chemin/vers/fichier.txt",
  "message": "Ajout/mise à jour du fichier",
  "content": "Contenu du fichier",
  "branch": "nom_branche"
}
</arguments>
</use_mcp_tool>
```

### Pousser plusieurs fichiers en un seul commit

```
<use_mcp_tool>
<server_name>github</server_name>
<tool_name>push_files</tool_name>
<arguments>
{
  "owner": "nom_utilisateur",
  "repo": "nom_depot",
  "branch": "nom_branche",
  "message": "Ajout de plusieurs fichiers",
  "files": [
    {
      "path": "chemin/vers/fichier1.txt",
      "content": "Contenu du fichier 1"
    },
    {
      "path": "chemin/vers/fichier2.txt",
      "content": "Contenu du fichier 2"
    }
  ]
}
</arguments>
</use_mcp_tool>
```

### Rechercher des dépôts

```
<use_mcp_tool>
<server_name>github</server_name>
<tool_name>search_repositories</tool_name>
<arguments>
{
  "query": "language:javascript stars:>1000"
}
</arguments>
</use_mcp_tool>
```

## Gestion des issues

### Créer une issue

```
<use_mcp_tool>
<server_name>github</server_name>
<tool_name>create_issue</tool_name>
<arguments>
{
  "owner": "nom_utilisateur",
  "repo": "nom_depot",
  "title": "Titre de l'issue",
  "body": "Description détaillée de l'issue",
  "labels": ["bug", "priorité-haute"]
}
</arguments>
</use_mcp_tool>
```

### Lister les issues d'un dépôt

```
<use_mcp_tool>
<server_name>github</server_name>
<tool_name>list_issues</tool_name>
<arguments>
{
  "owner": "nom_utilisateur",
  "repo": "nom_depot",
  "state": "open"
}
</arguments>
</use_mcp_tool>
```

### Ajouter un commentaire à une issue

```
<use_mcp_tool>
<server_name>github</server_name>
<tool_name>add_issue_comment</tool_name>
<arguments>
{
  "owner": "nom_utilisateur",
  "repo": "nom_depot",
  "issue_number": 42,
  "body": "Voici mon commentaire sur cette issue"
}
</arguments>
</use_mcp_tool>
```

## Gestion des pull requests

### Créer une pull request

```
<use_mcp_tool>
<server_name>github</server_name>
<tool_name>create_pull_request</tool_name>
<arguments>
{
  "owner": "nom_utilisateur",
  "repo": "nom_depot",
  "title": "Titre de la pull request",
  "body": "Description détaillée de la pull request",
  "head": "branche-avec-modifications",
  "base": "main"
}
</arguments>
</use_mcp_tool>
```

### Obtenir les détails d'une pull request

```
<use_mcp_tool>
<server_name>github</server_name>
<tool_name>get_pull_request</tool_name>
<arguments>
{
  "owner": "nom_utilisateur",
  "repo": "nom_depot",
  "pullNumber": 42
}
</arguments>
</use_mcp_tool>
```

### Fusionner une pull request

```
<use_mcp_tool>
<server_name>github</server_name>
<tool_name>merge_pull_request</tool_name>
<arguments>
{
  "owner": "nom_utilisateur",
  "repo": "nom_depot",
  "pullNumber": 42,
  "commit_title": "Fusion de la PR #42",
  "commit_message": "Cette PR ajoute la fonctionnalité X",
  "merge_method": "merge"
}
</arguments>
</use_mcp_tool>
```

### Créer une revue sur une pull request

```
<use_mcp_tool>
<server_name>github</server_name>
<tool_name>create_pull_request_review</tool_name>
<arguments>
{
  "owner": "nom_utilisateur",
  "repo": "nom_depot",
  "pullNumber": 42,
  "body": "Excellente PR, j'approuve ces changements",
  "event": "APPROVE"
}
</arguments>
</use_mcp_tool>
```

## Recherche de code

### Rechercher du code dans GitHub

```
<use_mcp_tool>
<server_name>github</server_name>
<tool_name>search_code</tool_name>
<arguments>
{
  "query": "language:python function:process_data repo:nom_utilisateur/nom_depot"
}
</arguments>
</use_mcp_tool>
```

## Sécurité du code

### Lister les alertes de scan de code

```
<use_mcp_tool>
<server_name>github</server_name>
<tool_name>list_code_scanning_alerts</tool_name>
<arguments>
{
  "owner": "nom_utilisateur",
  "repo": "nom_depot",
  "state": "open"
}
</arguments>
</use_mcp_tool>
```

## Utilisation des ressources

### Accéder au contenu d'un dépôt

```
<access_mcp_resource>
<server_name>github</server_name>
<uri>repo://nom_utilisateur/nom_depot/contents/chemin/vers/fichier.txt</uri>
</access_mcp_resource>
```

### Accéder au contenu d'un dépôt sur une branche spécifique

```
<access_mcp_resource>
<server_name>github</server_name>
<uri>repo://nom_utilisateur/nom_depot/refs/heads/nom_branche/contents/chemin/vers/fichier.txt</uri>
</access_mcp_resource>
```

## Scénarios d'utilisation avancés

### Automatisation de la création d'une issue avec analyse de code

```
# 1. Rechercher du code potentiellement problématique
<use_mcp_tool>
<server_name>github</server_name>
<tool_name>search_code</tool_name>
<arguments>
{
  "query": "repo:nom_utilisateur/nom_depot language:javascript TODO"
}
</arguments>
</use_mcp_tool>

# 2. Créer une issue pour chaque TODO trouvé
<use_mcp_tool>
<server_name>github</server_name>
<tool_name>create_issue</tool_name>
<arguments>
{
  "owner": "nom_utilisateur",
  "repo": "nom_depot",
  "title": "Résoudre les TODOs dans le code",
  "body": "J'ai trouvé des TODOs dans le code qui doivent être résolus:\n\n- TODO dans fichier.js ligne 42\n- TODO dans autre_fichier.js ligne 17",
  "labels": ["tech-debt"]
}
</arguments>
</use_mcp_tool>
```

### Création d'une PR avec plusieurs modifications

```
# 1. Créer une nouvelle branche
<use_mcp_tool>
<server_name>github</server_name>
<tool_name>create_branch</tool_name>
<arguments>
{
  "owner": "nom_utilisateur",
  "repo": "nom_depot",
  "branch": "feature/nouvelle-fonctionnalite",
  "sha": "sha_du_commit_main"
}
</arguments>
</use_mcp_tool>

# 2. Pousser plusieurs fichiers
<use_mcp_tool>
<server_name>github</server_name>
<tool_name>push_files</tool_name>
<arguments>
{
  "owner": "nom_utilisateur",
  "repo": "nom_depot",
  "branch": "feature/nouvelle-fonctionnalite",
  "message": "Ajout de la nouvelle fonctionnalité",
  "files": [
    {
      "path": "src/nouvelle_fonctionnalite.js",
      "content": "// Code de la nouvelle fonctionnalité"
    },
    {
      "path": "test/nouvelle_fonctionnalite.test.js",
      "content": "// Tests pour la nouvelle fonctionnalité"
    }
  ]
}
</arguments>
</use_mcp_tool>

# 3. Créer une pull request
<use_mcp_tool>
<server_name>github</server_name>
<tool_name>create_pull_request</tool_name>
<arguments>
{
  "owner": "nom_utilisateur",
  "repo": "nom_depot",
  "title": "Ajout de la nouvelle fonctionnalité",
  "body": "Cette PR ajoute la nouvelle fonctionnalité X avec ses tests",
  "head": "feature/nouvelle-fonctionnalite",
  "base": "main"
}
</arguments>
</use_mcp_tool>