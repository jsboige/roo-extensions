---
name: github-status
description: Consulte l'état du GitHub Project #67 et des issues via gh CLI pour roo-extensions. Utilise ce skill pendant un tour de sync, pour vérifier l'avancement global, ou pour mettre à jour le statut d'une tâche. Phrase déclencheur : "github status", "état du projet", "issues ouvertes", "progression #67".
metadata:
  author: "Roo Extensions Team"
  version: "2.0.0"
  compatibility:
    surfaces: ["claude-code", "claude.ai"]
    restrictions: "Requiert GitHub CLI (gh) avec scope project"
---

# Skill : GitHub Status

Consulte l'etat du GitHub Project #67 et des issues via `gh` CLI.

---

## Quand utiliser

- Pendant un tour de sync (Phase 4)
- Pour verifier l'avancement global du projet
- Pour chercher des issues specifiques
- Pour mettre a jour le statut d'une tache

---

## Contexte

- **Projet principal :** "RooSync Multi-Agent Tasks" (#67)
- **Project ID :** `PVT_kwHOADA1Xc4BLw3w`
- **Owner :** jsboige
- **Repository :** jsboige/roo-extensions

### IDs critiques (Status field)

- **Field ID :** `PVTSSF_lAHOADA1Xc4BLw3wzg7PYHY`
- **Options :**
  - `f75ad846` = Todo
  - `47fc9ee4` = In Progress
  - `98236657` = Done

---

## Workflow

### Phase 0 : Grounding Sémantique (Bookend Début)

**OBLIGATOIRE avant toute consultation GitHub.**

```
codebase_search(query: "github issues project status tracking progress", workspace: "d:\\roo-extensions")
```

But : Identifier les patterns de suivi GitHub, les issues récentes, et les configurations Project.

### Etape 1 : Progression globale

```bash
gh api graphql -f query='{ user(login: "jsboige") { projectV2(number: 67) { title items(first: 200) { totalCount nodes { fieldValues(first: 10) { nodes { ... on ProjectV2ItemFieldSingleSelectValue { name } } } } } } } }'
```

Compter les items par statut (Todo, In Progress, Done) et calculer le pourcentage.

### Etape 2 : Issues recentes

```bash
gh issue list --repo jsboige/roo-extensions --state open --limit 20
```

### Etape 3 : Details d'une issue specifique (si besoin)

```bash
gh issue view <numero> --repo jsboige/roo-extensions
```

### Rapport

```
## GitHub Project #67 Status

### Progression : X/Y DONE (Z%)
- Todo : A items
- In Progress : B items
- Done : C items

### Issues recentes
| # | Titre | Labels | Derniere activite |
|---|-------|--------|-------------------|
| ... | ... | ... | ... |

### Incoherences detectees
- [tache X annoncee Done mais encore Todo dans GitHub]
```

---

## Mises a jour (Phase 5 du sync-tour)

### Marquer une tache Done

```bash
gh api graphql -f query='mutation { updateProjectV2ItemFieldValue(input: { projectId: "PVT_kwHOADA1Xc4BLw3w", itemId: "<ITEM_ID>", fieldId: "PVTSSF_lAHOADA1Xc4BLw3wzg7PYHY", value: { singleSelectOptionId: "98236657" } }) { projectV2Item { id } } }'
```

### Marquer une tache In Progress

Meme commande avec `optionId: "47fc9ee4"`.

### Commenter une issue

```bash
gh issue comment <numero> --repo jsboige/roo-extensions --body "Commentaire"
```

### Creer une issue (VALIDATION OBLIGATOIRE)

```bash
gh issue create --repo jsboige/roo-extensions --title "Titre" --body "$(cat <<'EOF'
Description detaillee...
EOF
)"
```

**AVANT de creer :** Demander validation utilisateur explicite. Exception : bugs critiques bloquants.

---

## Commandes de reference

### Fermer une issue

```bash
gh issue close <numero> --repo jsboige/roo-extensions
```

---

## Regles

- Utiliser TOUJOURS `gh` CLI (le MCP github-projects-mcp est DEPRECIE)
- Ne creer de nouvelles issues qu'apres validation utilisateur
- Retourner un rapport condense
- Utiliser les heredocs pour les bodies multilignes (eviter problemes d'echappement)

---

## Phase 6 : Validation Sémantique (Bookend Fin)

**OBLIGATOIRE après consultation GitHub.**

```
codebase_search(query: "github project issues status done inprogress", workspace: "d:\\roo-extensions")
```

But : Confirmer que les issues consultées et les statuts mis à jour sont cohérents avec l'index.
