# Règles GitHub CLI - Roo Code

## Migration MCP github-projects → gh CLI

**IMPORTANT : Le MCP github-projects a été remplacé par le CLI `gh` natif.**

### Pourquoi ?

- Le MCP github-projects est déprécié (retiré depuis #368)
- Le CLI `gh` est plus léger, standard et maintenu
- Couverture équivalente : 12/15 fonctionnalités (80%)

### Commandes gh CLI

```bash
# Issues
gh issue list --repo jsboige/roo-extensions --state open
gh issue view 123 --repo jsboige/roo-extensions
gh issue create --title "Titre" --body "Description"
gh issue close 123

# Projects (GraphQL)
gh api graphql -f query='{ user(login: "jsboige") { projectV2(number: 67) { title items(first: 100) { totalCount } } } }'

# Pull Requests
gh pr list --repo jsboige/roo-extensions
gh pr view 123
gh pr create --title "Titre" --body "Description"
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

### À NE PAS utiliser

```bash
# NE PAS utiliser - MCP déprécié
mcp__github-projects-mcp__*
```

## Référence

- Issue #368 : Migration gh CLI
- Documentation : https://cli.github.com/manual/
