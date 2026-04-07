# Règles GitHub CLI - Roo Code

**Version:** 1.0.0
**MAJ:** 2026-04-08

## Migration MCP github-projects → gh CLI

**IMPORTANT : Le MCP github-projects a été remplacé par le CLI `gh` natif.**

### Pourquoi ?

- Le MCP github-projects est déprécié (retiré depuis #368)
- Le CLI `gh` est plus léger, standard et maintenu
- Couverture équivalente : 12/15 fonctionnalités (80%)

### Prérequis : Scope `project`

**Le CLI `gh` doit avoir le scope `project` pour accéder aux GitHub Projects :**

```bash
# Vérifier les scopes actuels
gh auth status

# Ajouter le scope project si manquant
gh auth refresh --hostname github.com -s project
```

Sans ce scope, toutes les requêtes GraphQL sur `projectV2` échoueront avec une erreur 403.

### Commandes gh CLI

```bash
# Issues
gh issue list --repo jsboige/roo-extensions --state open
gh issue view 123 --repo jsboige/roo-extensions
gh issue create --title "Titre" --body "Description"
gh issue close 123

# Projects (GraphQL) - ATTENTION au type union pour les champs
gh api graphql -f query='{ user(login: "jsboige") { projectV2(number: 67) { title items(first: 100) { totalCount } } } }'

# Pull Requests
gh pr list --repo jsboige/roo-extensions
gh pr view 123
gh pr create --title "Titre" --body "Description"
```

### GraphQL : Type Union pour les Champs (IMPORTANT)

Depuis une mise à jour de l'API GitHub, `ProjectV2ItemFieldSingleSelectValue.field` est un **type union**. Il faut utiliser un fragment inline :

```graphql
# CORRECT (avec fragment inline)
fieldValues(first: 10) {
  nodes {
    ... on ProjectV2ItemFieldSingleSelectValue {
      name
      field { ... on ProjectV2SingleSelectField { name } }
    }
  }
}

# INCORRECT (erreur "Selections can't be made directly on unions")
fieldValues(first: 10) {
  nodes {
    ... on ProjectV2ItemFieldSingleSelectValue {
      name
      field { name }  # CASSE - field est un union type
    }
  }
}
```

### IDs des Projects GitHub

| Projet | Numéro | ID Complet | Statut |
|--------|--------|------------|--------|
| RooSync Multi-Agent Tasks | #67 | `PVT_kwHOADA1Xc4BLw3w` | **ACTIF** |
| RooSync Multi-Agent Coordination | #70 | `PVT_kwHOADA1Xc4BL7qS` | **SUPPRIMÉ** |

**Seul le Project #67 existe.** Ne pas référencer #70.

### Field IDs (Project #67)

| Field | ID | Options |
|-------|----|---------|
| Status | `PVTSSF_lAHOADA1Xc4BLw3wzg7PYHY` | Todo=`f75ad846`, In Progress=`47fc9ee4`, Done=`98236657` |
| Machine | `PVTSSF_lAHOADA1Xc4BLw3wzg9nHu8` | ai01=`ae516a70`, po2023=`2b4454e0`, po2024=`91dd0acf`, po2025=`4f388455`, po2026=`bc8df25a`, web1=`e3cd0cd0`, All=`175c5fe1`, Any=`4c242ac6` |
| Agent | `PVTSSF_lAHOADA1Xc4BLw3wzg9icmA` | Roo=`102d5164`, Claude=`cf1eae0a`, Both=`33d72521` |
| Model | `PVTSSF_lAHOADA1Xc4BLw3wzg-jMsU` | haiku=`2574677f`, sonnet=`e4cc2b49`, opus=`9404892d` |
| Execution | `PVTSSF_lAHOADA1Xc4BLw3wzg-jMss` | interactive=`7655267d`, scheduled=`27c8f64e`, both=`98b54b15` |
| Deadline | `PVTF_lAHOADA1Xc4BLw3wzg-jMsw` | (Date type — use `date` value instead of `singleSelectOptionId`) |

### Pagination (>100 items)

L'API GitHub limite à 100 items par requête. Pour les projets avec plus de 100 items :

```graphql
# Première page
items(first: 100) { nodes { ... } pageInfo { hasNextPage endCursor } }
# Pages suivantes
items(first: 100, after: "CURSOR") { ... }
```

### Trouver l'ITEM_ID d'une issue dans le projet

Pour mettre à jour les champs Machine/Agent/Status d'une issue, il faut d'abord obtenir son `ITEM_ID` dans le projet :

```bash
# Chercher parmi les items du projet (paginer si >100)
gh api graphql -f query='{ user(login: "jsboige") { projectV2(number: 67) { items(first: 100) { nodes { id content { ... on Issue { number } } } } } } }'
# L'ITEM_ID est le champ "id" de l'item dont content.number correspond au numéro de l'issue
```

### Mettre à jour les champs d'une issue dans le projet

```bash
# Mettre le statut "In Progress"
gh api graphql -f query='mutation { updateProjectV2ItemFieldValue(input: { projectId: "PVT_kwHOADA1Xc4BLw3w", itemId: "{ITEM_ID}", fieldId: "PVTSSF_lAHOADA1Xc4BLw3wzg7PYHY", value: { singleSelectOptionId: "47fc9ee4" } }) { projectV2Item { id } } }'

# Mettre la Machine (ex: myia-po-2025 = 4f388455)
gh api graphql -f query='mutation { updateProjectV2ItemFieldValue(input: { projectId: "PVT_kwHOADA1Xc4BLw3w", itemId: "{ITEM_ID}", fieldId: "PVTSSF_lAHOADA1Xc4BLw3wzg9nHu8", value: { singleSelectOptionId: "4f388455" } }) { projectV2Item { id } } }'

# Mettre l'Agent (Claude Code = cf1eae0a)
gh api graphql -f query='mutation { updateProjectV2ItemFieldValue(input: { projectId: "PVT_kwHOADA1Xc4BLw3w", itemId: "{ITEM_ID}", fieldId: "PVTSSF_lAHOADA1Xc4BLw3wzg9icmA", value: { singleSelectOptionId: "cf1eae0a" } }) { projectV2Item { id } } }'
```

### ⚠️ RÈGLE CRITIQUE : Pas de fichiers temporaires dans le workspace (Fix #706)

**INTERDIT : Créer des fichiers temporaires dans le workspace racine pour les requêtes GraphQL.**

Les patterns suivants polluent le statut git et causent des boucles d'erreur :

```bash
# INTERDIT - crée query.graphql dans le workspace
write_to_file query.graphql '{ user(login: "jsboige") { ... } }'
gh api graphql -f query=$(cat query.graphql)

# INTERDIT - crée query.json, query-gh-projects-output.json
echo '{"query": "..."}' > query.json
gh api graphql < query.json
```

**CORRECT : Utiliser les requêtes inline avec une seule apostrophe :**

```bash
# CORRECT - requête inline sur une ligne
gh api graphql -f query='{ user(login: "jsboige") { projectV2(number: 67) { title } } }'

# CORRECT - requête multi-ligne avec heredoc (win-cli PowerShell)
$query = @"
{
  user(login: "jsboige") {
    projectV2(number: 67) {
      items(first: 100) {
        nodes { id content { ... on Issue { number } } }
      }
    }
  }
}
"@
gh api graphql -f query=$query

# CORRECT - execute_command avec variable PowerShell
execute_command(shell="powershell", command='$q = "{ user(login: \"jsboige\") { projectV2(number: 67) { title } } }"; gh api graphql -f query=$q')
```

**Si des fichiers temporaires sont nécessaires absolument :** Utiliser un répertoire dédié hors workspace (ex: `$env:TEMP\roo-gh-queries\`) et nettoyer après usage.

**Règle mémoire :** Toute requête `gh api graphql` doit être auto-suffisante — pas d'état externe, pas de fichiers à nettoyer.

### À NE PAS utiliser

```bash
# NE PAS utiliser - MCP déprécié
mcp__github-projects-mcp__*
```

## Référence

- Issue #368 : Migration gh CLI
- Issue #706 : Bug fichiers temporaires workspace (Fix 2026-03-14)
- Documentation : https://cli.github.com/manual/
