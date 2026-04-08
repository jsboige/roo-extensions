# Regles GitHub CLI - Roo Code

**Version:** 2.0.0 (condensed from 1.0.0, aligned with .claude/rules/)
**MAJ:** 2026-04-08

## Migration MCP → gh CLI

MCP `github-projects` RETIRE (#368). Utiliser `gh` CLI natif. Scope `project` obligatoire : `gh auth refresh -s project`.

## IDs Project #67

| Field | ID | Options |
| ----- | -- | ------- |
| Status | `PVTSSF_lAHOADA1Xc4BLw3wzg7PYHY` | Todo=`f75ad846`, In Progress=`47fc9ee4`, Done=`98236657` |
| Machine | `PVTSSF_lAHOADA1Xc4BLw3wzg9nHu8` | ai01=`ae516a70`, po2023=`2b4454e0`, po2024=`91dd0acf`, po2025=`4f388455`, po2026=`bc8df25a`, web1=`e3cd0cd0`, All=`175c5fe1`, Any=`4c242ac6` |
| Agent | `PVTSSF_lAHOADA1Xc4BLw3wzg9icmA` | Roo=`102d5164`, Claude=`cf1eae0a`, Both=`33d72521` |
| Model | `PVTSSF_lAHOADA1Xc4BLw3wzg-jMsU` | haiku=`2574677f`, sonnet=`e4cc2b49`, opus=`9404892d` |
| Execution | `PVTSSF_lAHOADA1Xc4BLw3wzg-jMss` | interactive=`7655267d`, scheduled=`27c8f64e`, both=`98b54b15` |
| Deadline | `PVTF_lAHOADA1Xc4BLw3wzg-jMsw` | (Date type) |

**Project ID :** `PVT_kwHOADA1Xc4BLw3w` | **Seul #67 existe** (pas #70).

## GraphQL — Type Union

`ProjectV2ItemFieldSingleSelectValue.field` est un type union. Utiliser fragment inline :

```graphql
fieldValues(first: 10) {
  nodes {
    ... on ProjectV2ItemFieldSingleSelectValue {
      name
      field { ... on ProjectV2SingleSelectField { name } }
    }
  }
}
```

## Operations courantes

```bash
# Trouver ITEM_ID d'une issue
gh api graphql -f query='{ user(login: "jsboige") { projectV2(number: 67) { items(first: 100) { nodes { id content { ... on Issue { number } } } } } } }'

# Mettre a jour un champ
gh api graphql -f query='mutation { updateProjectV2ItemFieldValue(input: { projectId: "PVT_kwHOADA1Xc4BLw3w", itemId: "{ITEM_ID}", fieldId: "{FIELD_ID}", value: { singleSelectOptionId: "{OPTION_ID}" } }) { projectV2Item { id } } }'
```

## REGLE CRITIQUE : Pas de fichiers temporaires (#706)

**INTERDIT :** Creer `query.graphql`, `query.json` dans le workspace.
**CORRECT :** Requetes inline sur une seule ligne, ou variable PowerShell avec heredoc.

## Pagination (>100 items)

```graphql
items(first: 100) { nodes { ... } pageInfo { hasNextPage endCursor } }
# Page suivante : items(first: 100, after: "CURSOR")
```

---
**Historique versions completes :** Git history avant 2026-04-08
