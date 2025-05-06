# Exemples d'utilisation du Git MCP Server avec Roo

Ce document présente des exemples concrets d'utilisation du Git MCP Server avec Roo pour interagir avec des dépôts Git.

## Configuration du répertoire de travail

```
<use_mcp_tool>
<server_name>git</server_name>
<tool_name>git_set_working_dir</tool_name>
<arguments>
{
  "path": "C:/Users/username/projects/mon-projet"
}
</arguments>
</use_mcp_tool>
```

## Opérations de base

### Vérifier l'état du dépôt

```
<use_mcp_tool>
<server_name>git</server_name>
<tool_name>git_status</tool_name>
<arguments>
{}
</arguments>
</use_mcp_tool>
```

### Cloner un dépôt

```
<use_mcp_tool>
<server_name>git</server_name>
<tool_name>git_clone</tool_name>
<arguments>
{
  "repositoryUrl": "https://github.com/utilisateur/depot.git",
  "targetPath": "C:/Users/username/projects/nouveau-depot"
}
</arguments>
</use_mcp_tool>
```

### Initialiser un nouveau dépôt

```
<use_mcp_tool>
<server_name>git</server_name>
<tool_name>git_init</tool_name>
<arguments>
{
  "path": "C:/Users/username/projects/nouveau-projet",
  "initialBranch": "main"
}
</arguments>
</use_mcp_tool>
```

## Gestion des branches

### Lister les branches

```
<use_mcp_tool>
<server_name>git</server_name>
<tool_name>git_branch</tool_name>
<arguments>
{
  "mode": "list",
  "all": true
}
</arguments>
</use_mcp_tool>
```

### Créer une nouvelle branche

```
<use_mcp_tool>
<server_name>git</server_name>
<tool_name>git_branch</tool_name>
<arguments>
{
  "mode": "create",
  "branchName": "feature/nouvelle-fonctionnalite",
  "startPoint": "main"
}
</arguments>
</use_mcp_tool>
```

### Basculer vers une branche

```
<use_mcp_tool>
<server_name>git</server_name>
<tool_name>git_checkout</tool_name>
<arguments>
{
  "branchOrPath": "feature/nouvelle-fonctionnalite"
}
</arguments>
</use_mcp_tool>
```

## Gestion des fichiers

### Ajouter des fichiers à l'index

```
<use_mcp_tool>
<server_name>git</server_name>
<tool_name>git_add</tool_name>
<arguments>
{
  "files": ["fichier1.txt", "dossier/fichier2.js"]
}
</arguments>
</use_mcp_tool>
```

### Créer un commit

```
<use_mcp_tool>
<server_name>git</server_name>
<tool_name>git_commit</tool_name>
<arguments>
{
  "message": "Ajout de nouvelles fonctionnalités",
  "author": "Nom <email@exemple.com>"
}
</arguments>
</use_mcp_tool>
```

## Synchronisation avec les dépôts distants

### Configurer un dépôt distant

```
<use_mcp_tool>
<server_name>git</server_name>
<tool_name>git_remote</tool_name>
<arguments>
{
  "mode": "add",
  "name": "origin",
  "url": "https://github.com/utilisateur/depot.git"
}
</arguments>
</use_mcp_tool>
```

### Pousser des modifications

```
<use_mcp_tool>
<server_name>git</server_name>
<tool_name>git_push</tool_name>
<arguments>
{
  "remote": "origin",
  "branch": "feature/nouvelle-fonctionnalite",
  "setUpstream": true
}
</arguments>
</use_mcp_tool>
```

### Récupérer des modifications

```
<use_mcp_tool>
<server_name>git</server_name>
<tool_name>git_pull</tool_name>
<arguments>
{
  "remote": "origin",
  "branch": "main"
}
</arguments>
</use_mcp_tool>
```

## Historique et différences

### Afficher l'historique des commits

```
<use_mcp_tool>
<server_name>git</server_name>
<tool_name>git_log</tool_name>
<arguments>
{
  "maxCount": 10
}
</arguments>
</use_mcp_tool>
```

### Afficher les différences

```
<use_mcp_tool>
<server_name>git</server_name>
<tool_name>git_diff</tool_name>
<arguments>
{
  "commit1": "HEAD~1",
  "commit2": "HEAD"
}
</arguments>
</use_mcp_tool>
```

## Opérations avancées

### Fusionner des branches

```
<use_mcp_tool>
<server_name>git</server_name>
<tool_name>git_merge</tool_name>
<arguments>
{
  "branch": "feature/nouvelle-fonctionnalite",
  "commitMessage": "Fusion de la fonctionnalité X"
}
</arguments>
</use_mcp_tool>
```

### Rebaser une branche

```
<use_mcp_tool>
<server_name>git</server_name>
<tool_name>git_rebase</tool_name>
<arguments>
{
  "upstream": "main"
}
</arguments>
</use_mcp_tool>
```

### Gérer les stash

```
<use_mcp_tool>
<server_name>git</server_name>
<tool_name>git_stash</tool_name>
<arguments>
{
  "mode": "save",
  "message": "Sauvegarde des modifications en cours"
}
</arguments>
</use_mcp_tool>
```

### Appliquer un stash

```
<use_mcp_tool>
<server_name>git</server_name>
<tool_name>git_stash</tool_name>
<arguments>
{
  "mode": "apply",
  "stashRef": "stash@{0}"
}
</arguments>
</use_mcp_tool>
```

### Créer un tag

```
<use_mcp_tool>
<server_name>git</server_name>
<tool_name>git_tag</tool_name>
<arguments>
{
  "mode": "create",
  "tagName": "v1.0.0",
  "message": "Version 1.0.0",
  "annotate": true
}
</arguments>
</use_mcp_tool>
```

## Scénarios d'utilisation avancés

### Workflow de développement de fonctionnalité

```
# 1. Créer une nouvelle branche de fonctionnalité
<use_mcp_tool>
<server_name>git</server_name>
<tool_name>git_branch</tool_name>
<arguments>
{
  "mode": "create",
  "branchName": "feature/nouvelle-fonctionnalite",
  "startPoint": "main"
}
</arguments>
</use_mcp_tool>

# 2. Basculer vers la nouvelle branche
<use_mcp_tool>
<server_name>git</server_name>
<tool_name>git_checkout</tool_name>
<arguments>
{
  "branchOrPath": "feature/nouvelle-fonctionnalite"
}
</arguments>
</use_mcp_tool>

# 3. Ajouter des fichiers modifiés
<use_mcp_tool>
<server_name>git</server_name>
<tool_name>git_add</tool_name>
<arguments>
{
  "files": ["src/nouvelle-fonctionnalite.js", "test/nouvelle-fonctionnalite.test.js"]
}
</arguments>
</use_mcp_tool>

# 4. Créer un commit
<use_mcp_tool>
<server_name>git</server_name>
<tool_name>git_commit</tool_name>
<arguments>
{
  "message": "Implémentation de la nouvelle fonctionnalité"
}
</arguments>
</use_mcp_tool>

# 5. Pousser la branche vers le dépôt distant
<use_mcp_tool>
<server_name>git</server_name>
<tool_name>git_push</tool_name>
<arguments>
{
  "remote": "origin",
  "branch": "feature/nouvelle-fonctionnalite",
  "setUpstream": true
}
</arguments>
</use_mcp_tool>
```

### Résolution de conflits de fusion

```
# 1. Tenter une fusion
<use_mcp_tool>
<server_name>git</server_name>
<tool_name>git_merge</tool_name>
<arguments>
{
  "branch": "feature/autre-fonctionnalite"
}
</arguments>
</use_mcp_tool>

# 2. Vérifier l'état après un conflit
<use_mcp_tool>
<server_name>git</server_name>
<tool_name>git_status</tool_name>
<arguments>
{}
</arguments>
</use_mcp_tool>

# 3. Après résolution manuelle des conflits, ajouter les fichiers résolus
<use_mcp_tool>
<server_name>git</server_name>
<tool_name>git_add</tool_name>
<arguments>
{
  "files": ["fichier-avec-conflit.js"]
}
</arguments>
</use_mcp_tool>

# 4. Terminer la fusion
<use_mcp_tool>
<server_name>git</server_name>
<tool_name>git_commit</tool_name>
<arguments>
{
  "message": "Résolution des conflits de fusion"
}
</arguments>
</use_mcp_tool>