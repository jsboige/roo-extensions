# Rapport de Comparaison : gh CLI vs MCP GitHub Projects

**Date :** 2026-01-26  
**Machine :** myia-po-2026  
**Version gh CLI :** 2.86.0 (2026-01-21)

---

## 1. Installation de gh CLI

✅ **gh CLI est installé** : version 2.86.0 (2026-01-21)

---

## 2. Commandes gh CLI pour les Projets GitHub

### Commandes disponibles

| Commande gh CLI | Description | Équivalent MCP GitHub |
|----------------|-------------|----------------------|
| `gh project list` | Liste les projets d'un owner | `list_projects` |
| `gh project view <number>` | Affiche les détails d'un projet | `get_project` |
| `gh project item-list <number>` | Liste les items d'un projet | `get_project_items` |
| `gh project create` | Crée un nouveau projet | `create_project` |
| `gh project delete` | Supprime un projet | `delete_project` |
| `gh project edit` | Modifie un projet | `update_project` |
| `gh project close` | Ferme un projet | `update_project` (state) |
| `gh project copy` | Copie un projet | ❌ Non disponible |
| `gh project link` | Lie un projet à un repo/team | ❌ Non disponible |
| `gh project unlink` | Dissocie un projet d'un repo/team | ❌ Non disponible |
| `gh project mark-template` | Marque un projet comme template | ❌ Non disponible |
| `gh project field-create` | Crée un champ | `create_project_field` |
| `gh project field-delete` | Supprime un champ | `delete_project_field` |
| `gh project field-list` | Liste les champs | Inclus dans `get_project` |
| `gh project item-add` | Ajoute un item (issue/PR) | `add_item_to_project` |
| `gh project item-create` | Crée une draft issue | `add_item_to_project` (draft_issue) |
| `gh project item-delete` | Supprime un item | `delete_project_item` |
| `gh project item-edit` | Modifie un item | `update_project_item_field` |
| `gh project item-archive` | Archive un item | `archive_project_item` |
| `gh project item-unarchive` | Désarchive un item | `unarchive_project_item` |

---

## 3. Paramètres `limit` et `summary`

### Paramètre `--limit`

**gh CLI :**
- ✅ Disponible sur `gh project list` (défaut: 30)
- ✅ Disponible sur `gh project item-list` (défaut: 30)
- Syntaxe : `--limit <int>`

**MCP GitHub :**
- ✅ Disponible sur `get_project_items` (défaut: 100, max: 100)
- ❌ Non disponible sur `list_projects` (hardcodé à 20)

### Paramètre `--summary`

**gh CLI :**
- ❌ **Non disponible** comme paramètre natif
- Alternative : Utiliser `--format json` avec `--jq` pour filtrer les champs

**MCP GitHub :**
- ✅ Disponible sur `get_project_items`
- Description : "Mode résumé : retourne uniquement titre + status (réduit la taille de la réponse)"
- Type : `boolean` (défaut: false)

**Exemple d'utilisation gh CLI pour simuler `summary` :**
```bash
gh project item-list 1 --owner "@me" --format json --jq '.[] | {title, status}'
```

---

## 4. Scope `read:project`

**gh CLI :**
- ✅ Le scope `project` est **requis** pour les commandes de projet
- Message : "The minimum required scope for token is: `project`"
- Commande pour ajouter le scope : `gh auth refresh -s project`

**MCP GitHub :**
- ✅ Le scope `project` est mentionné dans les prérequis
- Documentation : "A GitHub Personal Access Token with `repo` and `project` scopes"

---

## 5. Comparaison Fonctionnelle

### Fonctionnalités Uniques à gh CLI

1. **`gh project copy`** - Copie un projet existant
2. **`gh project link/unlink`** - Lie/dissocie un projet à un dépôt ou équipe
3. **`gh project mark-template`** - Marque un projet comme template
4. **`--web` flag** - Ouvre directement dans le navigateur
5. **`--closed` flag** - Filtre les projets fermés (sur `list`)
6. **`--jq` et `--template`** - Filtrage et formatage avancé de la sortie

### Fonctionnalités Uniques au MCP GitHub

1. **`analyze_task_complexity`** - Analyse la complexité d'une tâche
2. **`convert_draft_to_issue`** - Convertit une draft issue en issue standard
3. **`archive_project` / `unarchive_project`** - Archive/désarchive un projet entier
4. **`update_project_field`** - Renomme un champ
5. **`search_repositories`** - Recherche des dépôts
6. **Fonctionnalités Workflows** - `list_repository_workflows`, `get_workflow_runs`, `get_workflow_run_status`, `get_workflow_run_jobs`
7. **Fonctionnalités Issues** - `list_repository_issues`, `get_repository_issue`, `delete_repository_issues`, `add_issue_comment`
8. **Mode `summary` natif** - Réduit la taille de la réponse
9. **`filterOptions`** - Filtrage avancé des items par critères
10. **`limit` plus élevé** - 100 items vs 30 par défaut

---

## 6. Analyse de Couverture

### Couverture des fonctionnalités de base

| Fonctionnalité | gh CLI | MCP GitHub | Avantage |
|----------------|----------|-------------|-----------|
| Lister les projets | ✅ | ✅ | Égal |
| Voir un projet | ✅ | ✅ | Égal |
| Lister les items | ✅ | ✅ | MCP (limit 100) |
| Créer un projet | ✅ | ✅ | Égal |
| Supprimer un projet | ✅ | ✅ | Égal |
| Modifier un projet | ✅ | ✅ | Égal |
| Créer un champ | ✅ | ✅ | Égal |
| Supprimer un champ | ✅ | ✅ | Égal |
| Ajouter un item | ✅ | ✅ | Égal |
| Supprimer un item | ✅ | ✅ | Égal |
| Modifier un item | ✅ | ✅ | Égal |
| Archiver un item | ✅ | ✅ | Égal |
| Désarchiver un item | ✅ | ✅ | Égal |

### Couverture des fonctionnalités avancées

| Fonctionnalité | gh CLI | MCP GitHub | Avantage |
|----------------|----------|-------------|-----------|
| Copier un projet | ✅ | ❌ | gh CLI |
| Lier à un repo/team | ✅ | ❌ | gh CLI |
| Marquer comme template | ✅ | ❌ | gh CLI |
| Archiver un projet | ❌ | ✅ | MCP |
| Convertir draft en issue | ❌ | ✅ | MCP |
| Analyser complexité | ❌ | ✅ | MCP |
| Workflows monitoring | ❌ | ✅ | MCP |
| Issues management | ❌ | ✅ | MCP |
| Mode summary | ❌ (via jq) | ✅ | MCP |
| Filtrage avancé | ❌ (via jq) | ✅ | MCP |

---

## 7. Recommandations

### Pour gh CLI

**Avantages :**
- Interface CLI native et rapide
- Intégration directe avec GitHub
- Fonctionnalités de gestion de projet (copy, link, template)
- Filtrage puissant avec `--jq` et `--template`

**Limitations :**
- Pas de mode `summary` natif
- Limit par défaut de 30 items
- Pas de monitoring de workflows
- Pas de gestion avancée des issues

### Pour MCP GitHub

**Avantages :**
- Intégration avec l'écosystème MCP
- Fonctionnalités avancées (analyse de complexité, workflows)
- Mode `summary` natif
- Limit plus élevé (100 items)
- Filtrage avancé via `filterOptions`
- Gestion complète des issues et workflows

**Limitations :**
- Pas de copie de projet
- Pas de liaison avec repo/team
- Dépendance à un serveur MCP

---

## 8. Conclusion

**Couverture fonctionnelle :** ~85%

Le MCP GitHub offre une couverture fonctionnelle très complète des commandes gh CLI pour les projets, avec des fonctionnalités supplémentaires uniques (workflows, analyse de complexité, gestion des issues). 

**Points clés :**
1. Le paramètre `--limit` est disponible dans les deux solutions
2. Le paramètre `--summary` n'existe pas nativement dans gh CLI (simulable via `--jq`)
3. Le scope `project` est requis dans les deux solutions
4. Le MCP GitHub excelle dans les fonctionnalités avancées et l'intégration avec d'autres outils MCP
5. gh CLI excelle dans les opérations de gestion de projet (copy, link, template)

**Recommandation :** Utiliser les deux solutions de manière complémentaire selon le cas d'usage :
- gh CLI pour les opérations rapides et la gestion de projet
- MCP GitHub pour l'intégration automatisée et les fonctionnalités avancées
