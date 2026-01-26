# Guide de Migration : MCP github-projects → gh CLI

**Date** : 2026-01-24
**Tâche** : T87 - Créer un guide de migration gh CLI
**Priorité** : 1

---

## Table des Matières

1. [Introduction](#1-introduction)
2. [Pourquoi Migrer ?](#2-pourquoi-migrer)
3. [Tableau d'Équivalences](#3-tableau-déquivalences)
4. [Guide d'Installation](#4-guide-dinstallation)
5. [Guide d'Authentification](#5-guide-dauthentification)
6. [Exemples Concrets](#6-exemples-concrets)
7. [Recommandations de Migration](#7-recommandations-de-migration)
8. [Annexes](#8-annexes)

---

## 1. Introduction

Ce guide documente la migration du MCP `github-projects` vers l'outil en ligne de commande officiel de GitHub, **gh CLI**.

**Contexte** : L'analyse T86 a révélé qu'aucun mode Roo personnalisé n'utilise actuellement MCP github-projects. Ce guide facilite la transition vers gh CLI pour toute utilisation future.

---

## 2. Pourquoi Migrer ?

### 2.1 Comparaison MCP github-projects vs gh CLI

| Aspect | MCP github-projects | gh CLI |
|--------|---------------------|---------|
| **Maintenance** | Code TypeScript à maintenir | Maintenu par GitHub |
| **Mises à jour** | Manuelles | Automatiques |
| **Performance** | Via Node.js | Natif Go |
| **Dépendances** | Node.js, npm | Binaire unique |
| **Authentification** | GITHUB_TOKEN | gh auth login |
| **Complexité** | 57 outils MCP | Commandes unifiées |
| **Documentation** | Propriétaire | Officielle GitHub |
| **Support** | Communauté interne | Support GitHub officiel |

### 2.2 Avantages de gh CLI

1. **Maintenance réduite** : Plus besoin de maintenir le code TypeScript du MCP
2. **Mises à jour automatiques** : `gh upgrade` pour les dernières fonctionnalités
3. **Performance supérieure** : Binaire Go compilé nativement
4. **Authentification simplifiée** : `gh auth login` avec support OAuth
5. **Documentation officielle** : Accès à la documentation GitHub complète
6. **Écosystème étendu** : Extensions et plugins disponibles

---

## 3. Tableau d'Équivalences

### 3.1 Gestion de Projets

| Outil MCP | Description | Équivalent gh CLI | Exemple |
|-----------|-------------|------------------|---------|
| `list_projects` | Lister les projets d'un utilisateur/org | `gh project list` | `gh project list --owner myorg` |
| `create_project` | Créer un nouveau projet | `gh project create` | `gh project create --title "Mon Projet" --owner myorg` |
| `get_project` | Récupérer les détails d'un projet | `gh project view` | `gh project view 123 --owner myorg` |
| `update_project` | Modifier titre/description/état | `gh project edit` | `gh project edit 123 --title "Nouveau Titre" --owner myorg` |
| `delete_project` | Supprimer un projet | `gh project delete` | `gh project delete 123 --owner myorg` |
| `archive_project` | Archiver un projet | `gh project close` | `gh project close 123 --owner myorg` |
| `unarchive_project` | Ré-ouvrir un projet | `gh project reopen` | `gh project reopen 123 --owner myorg` |

### 3.2 Gestion d'Items

| Outil MCP | Description | Équivalent gh CLI | Exemple |
|-----------|-------------|------------------|---------|
| `get_project_items` | Obtenir les items d'un projet | `gh project item-list` | `gh project item-list 123 --owner myorg` |
| `add_item_to_project` | Ajouter un item (issue/PR/note) | `gh project item-add` | `gh project item-add 123 --owner myorg --id 456` |
| `delete_project_item` | Supprimer un item | `gh project item-delete` | `gh project item-delete 123 --owner myorg --id 456` |
| `archive_project_item` | Archiver un item | `gh project item-archive` | `gh project item-archive 123 --owner myorg --id 456` |
| `unarchive_project_item` | Désarchiver un item | `gh project item-unarchive` | `gh project item-unarchive 123 --owner myorg --id 456` |

### 3.3 Gestion de Champs

| Outil MCP | Description | Équivalent gh CLI | Exemple |
|-----------|-------------|------------------|---------|
| `create_project_field` | Créer un nouveau champ | `gh project field-create` | `gh project field-create 123 --owner myorg --name "Priorité" --data-type SINGLE_SELECT` |
| `update_project_field` | Renommer un champ | `gh project field-edit` | `gh project field-edit 123 --owner myorg --field-id 789 --name "Nouveau Nom"` |
| `delete_project_field` | Supprimer un champ | `gh project field-delete` | `gh project field-delete 123 --owner myorg --field-id 789` |
| `update_project_item_field` | Mettre à jour la valeur d'un champ | `gh project item-edit` | `gh project item-edit 123 --owner myorg --id 456 --field-id 789 --value "Haute"` |

### 3.4 Gestion d'Issues

| Outil MCP | Description | Équivalent gh CLI | Exemple |
|-----------|-------------|------------------|---------|
| `create_issue` | Créer une issue et l'ajouter à un projet | `gh issue create --project` | `gh issue create --title "Bug" --body "Description" --project 123 --repo owner/repo` |
| `update_issue_state` | Modifier l'état d'une issue | `gh issue close` / `gh issue reopen` | `gh issue close 42 --repo owner/repo` |
| `list_repository_issues` | Lister les issues d'un dépôt | `gh issue list` | `gh issue list --repo owner/repo --state open` |
| `get_repository_issue` | Récupérer les détails d'une issue | `gh issue view` | `gh issue view 42 --repo owner/repo` |
| `delete_repository_issues` | Supprimer plusieurs issues | `gh issue delete` | `gh issue delete 42 43 44 --repo owner/repo` |

### 3.5 Workflows

| Outil MCP | Description | Équivalent gh CLI | Exemple |
|-----------|-------------|------------------|---------|
| `list_repository_workflows` | Lister les workflows d'un dépôt | `gh workflow list` | `gh workflow list --repo owner/repo` |
| `get_workflow_runs` | Récupérer les exécutions d'un workflow | `gh run list` | `gh run list --repo owner/repo --workflow test.yml` |
| `get_workflow_run_status` | Obtenir le statut d'une exécution | `gh run view` | `gh run view 12345 --repo owner/repo` |
| `get_workflow_run_jobs` | Récupérer les jobs d'une exécution | `gh run view --log` | `gh run view 12345 --repo owner/repo --log` |

### 3.6 Recherche

| Outil MCP | Description | Équivalent gh CLI | Exemple |
|-----------|-------------|------------------|---------|
| `search_repositories` | Rechercher des dépôts | `gh search repos` | `gh search repos "topic:javascript stars:>1000"` |
| `list_repositories` | Lister les dépôts d'un utilisateur/org | `gh repo list` | `gh repo list myorg --limit 50` |

### 3.7 Autres Outils MCP

| Outil MCP | Description | Équivalent gh CLI | Exemple |
|-----------|-------------|------------------|---------|
| `analyze_task_complexity` | Analyser la complexité d'une tâche | Script personnalisé | N/A |
| `convert_draft_to_issue` | Convertir une note en issue | `gh issue create` | `gh issue create --title "Titre" --body "Contenu"` |

---

## 4. Guide d'Installation

### 4.1 Windows

```powershell
# Via winget
winget install --id GitHub.cli

# Via Scoop
scoop install gh

# Via Chocolatey
choco install gh-cli
```

### 4.2 Vérification de l'installation

```powershell
gh --version
# gh version 2.60.1 (2024-12-18)
```

### 4.3 Mise à jour

```powershell
gh upgrade
```

---

## 5. Guide d'Authentification

### 5.1 Authentification standard

```powershell
gh auth login
```

**Options interactives** :
1. GitHub.com ou GitHub Enterprise ?
2. HTTPS ou SSH ?
3. Login avec navigateur ou token ?

### 5.2 Authentification avec token

```powershell
gh auth login --with-token < token.txt
```

### 5.3 Vérification de l'authentification

```powershell
gh auth status
```

### 5.4 Déconnexion

```powershell
gh auth logout
```

---

## 6. Exemples Concrets

### 6.1 Pattern : Créer un projet et ajouter des issues

**MCP github-projects** :
```typescript
// Créer un projet
const project = await create_project({
  owner: "myorg",
  title: "Nouveau Projet"
});

// Créer une issue et l'ajouter au projet
await create_issue({
  repositoryName: "myorg/myrepo",
  title: "Bug critique",
  body: "Description du bug",
  projectId: project.id
});
```

**gh CLI** :
```bash
# Créer un projet
gh project create --title "Nouveau Projet" --owner myorg --json id --jq '.id' > project_id.txt

# Créer une issue et l'ajouter au projet
PROJECT_ID=$(cat project_id.txt)
gh issue create --title "Bug critique" --body "Description du bug" --project $PROJECT_ID --repo myorg/myrepo
```

### 6.2 Pattern : Lister les items d'un projet avec filtres

**MCP github-projects** :
```typescript
const items = await get_project_items({
  owner: "myorg",
  project_id: "123",
  filterOptions: {
    status: "Done"
  }
});
```

**gh CLI** :
```bash
gh project item-list 123 --owner myorg --format json --jq '.items[] | select(.status == "Done")'
```

### 6.3 Pattern : Mettre à jour un champ d'un item

**MCP github-projects** :
```typescript
await update_project_item_field({
  owner: "myorg",
  project_id: "123",
  item_id: "456",
  field_id: "789",
  field_type: "single_select",
  option_id: "priority_high"
});
```

**gh CLI** :
```bash
gh project item-edit 123 --owner myorg --id 456 --field-id 789 --value "Haute"
```

### 6.4 Pattern : Lister les workflows et leurs exécutions

**MCP github-projects** :
```typescript
const workflows = await list_repository_workflows({
  owner: "myorg",
  repo: "myrepo"
});

const runs = await get_workflow_runs({
  owner: "myorg",
  repo: "myrepo",
  workflow_id: workflows[0].id
});
```

**gh CLI** :
```bash
# Lister les workflows
gh workflow list --repo myorg/myrepo

# Lister les exécutions d'un workflow spécifique
gh run list --repo myorg/myrepo --workflow test.yml --limit 10
```

### 6.5 Pattern : Rechercher des dépôts

**MCP github-projects** :
```typescript
const repos = await search_repositories({
  query: "topic:javascript stars:>1000"
});
```

**gh CLI** :
```bash
gh search repos "topic:javascript stars:>1000" --limit 20
```

### 6.6 Pattern : Gérer les issues d'un dépôt

**MCP github-projects** :
```typescript
// Lister les issues ouvertes
const issues = await list_repository_issues({
  owner: "myorg",
  repo: "myrepo",
  state: "open"
});

// Fermer une issue
await update_issue_state({
  owner: "myorg",
  issueId: "42",
  state: "CLOSED"
});
```

**gh CLI** :
```bash
# Lister les issues ouvertes
gh issue list --repo myorg/myrepo --state open

# Fermer une issue
gh issue close 42 --repo myorg/myrepo
```

---

## 7. Recommandations de Migration

### 7.1 Phase 1 : Préparation (Immédiat)

1. **Installer gh CLI** sur toutes les machines
   ```powershell
   winget install --id GitHub.cli
   ```

2. **Authentifier gh CLI**
   ```powershell
   gh auth login
   ```

3. **Tester les commandes de base**
   ```powershell
   gh --version
   gh auth status
   gh repo list
   ```

4. **Documenter les patterns d'usage** actuels
   - Identifier les opérations MCP github-projects utilisées
   - Créer des scripts de test gh CLI équivalents

### 7.2 Phase 2 : Migration (Court terme)

1. **Remplacer les appels MCP par gh CLI** dans la documentation
   - Mettre à jour `docs/roosync/PROTOCOLE_SDDD.md`
   - Mettre à jour `docs/roosync/guides/GLOSSAIRE.md`

2. **Créer des scripts d'aide** pour les opérations courantes
   ```powershell
   # scripts/github-helpers.ps1
   function New-GitHubProject {
       param([string]$Title, [string]$Owner)
       gh project create --title $Title --owner $Owner --json id --jq '.id'
   }
   ```

3. **Désactiver le MCP github-projects**
   - Mettre `"enabled": false` dans `roo-config/settings/servers.json`

### 7.3 Phase 3 : Nettoyage (Long terme)

1. **Archiver la documentation MCP github-projects**
   - Déplacer vers `archive/mcps/github-projects/`
   - Conserver pour référence historique

2. **Supprimer le code MCP github-projects**
   - `mcps/internal/servers/github-projects-mcp/`
   - Tests associés

3. **Nettoyer les dépendances**
   - Supprimer du `package.json` racine si applicable

---

## 8. Annexes

### 8.1 Références

- **Documentation gh CLI** : https://cli.github.com/manual/
- **GitHub Projects API** : https://docs.github.com/en/graphql/guides/using-the-graphql-api-for-projects
- **Issue GitHub** : #368 (Migration gh CLI vs MCP github-projects)
- **Spécifications** : [`roo-config/specifications/mcp-integrations-priority.md`](../../roo-config/specifications/mcp-integrations-priority.md)

### 8.2 Scripts Utiles

#### Script : Créer un projet et ajouter des issues

```powershell
# scripts/github/create-project-with-issues.ps1
param(
    [Parameter(Mandatory=$true)]
    [string]$Owner,

    [Parameter(Mandatory=$true)]
    [string]$Repo,

    [Parameter(Mandatory=$true)]
    [string]$ProjectTitle
)

# Créer le projet
$projectId = gh project create --title $ProjectTitle --owner $Owner --json id --jq '.id'
Write-Host "Projet créé avec ID: $projectId"

# Créer une issue et l'ajouter au projet
gh issue create --title "Issue de test" --body "Issue créée via script" --project $projectId --repo "$Owner/$Repo"
Write-Host "Issue créée et ajoutée au projet"
```

#### Script : Lister les items d'un projet

```powershell
# scripts/github/list-project-items.ps1
param(
    [Parameter(Mandatory=$true)]
    [string]$Owner,

    [Parameter(Mandatory=$true)]
    [int]$ProjectId,

    [string]$Status = "all"
)

gh project item-list $ProjectId --owner $Owner --format json | jq '.items[] | select(.status == "'$Status'" or "'$Status'" == "all")'
```

### 8.3 FAQ

**Q : Puis-je utiliser gh CLI dans des scripts PowerShell ?**
R : Oui, gh CLI fonctionne parfaitement avec PowerShell. Utilisez l'opérateur de backtick `` ` `` pour les commandes multi-lignes.

**Q : Comment gérer l'authentification dans des scripts automatisés ?**
R : Utilisez `gh auth login --with-token` avec un token GitHub PAT (Personal Access Token) stocké de manière sécurisée.

**Q : gh CLI supporte-t-il toutes les fonctionnalités de MCP github-projects ?**
R : La plupart des fonctionnalités sont supportées. Pour les cas spécifiques non couverts, utilisez l'API GitHub directement via `gh api`.

**Q : Comment migrer les données existantes ?**
R : Les données sont stockées sur GitHub, pas dans le MCP. Aucune migration de données n'est nécessaire.

---

## Conclusion

La migration de MCP github-projects vers gh CLI est **simple et recommandée** pour les raisons suivantes :

1. **Maintenance réduite** : Plus de code TypeScript à maintenir
2. **Performance supérieure** : Binaire Go natif
3. **Support officiel** : Documentation et support GitHub
4. **Mises à jour automatiques** : `gh upgrade`

**Complexité de la migration** : FAIBLE
**Impact sur les modes** : AUCUN (aucun mode n'utilise github-projects)

Pour toute question ou assistance, consultez la documentation gh CLI officielle ou contactez l'équipe de développement.
