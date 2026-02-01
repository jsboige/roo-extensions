# Règles GitHub CLI - Claude Code

## Migration MCP github-projects → gh CLI

**IMPORTANT : Le MCP github-projects a été remplacé par le CLI `gh` natif.**

### Pourquoi ?

- Le MCP github-projects (57 outils) est déprécié
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

| Projet | Numéro | ID Complet |
|--------|--------|------------|
| RooSync Multi-Agent Tasks | #67 | `PVT_kwHOADA1Xc4BLw3w` |
| RooSync Multi-Agent Coordination | #70 | `PVT_kwHOADA1Xc4BL7qS` |

### À NE PAS utiliser

Le MCP github-projects-mcp est déprécié. Utiliser exclusivement `gh` CLI.

## Référence

- Issue #368 : Migration gh CLI
- Documentation : https://cli.github.com/manual/
