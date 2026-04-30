# Findability — Retrouvabilité des Décisions Historiques

**Version:** 1.0.0
**Issue:** #1819
**MAJ:** 2026-04-29

---

## Problème

Les décisions architecturales prises en sessions Claude Code interactives n'étaient PAS indexées dans Qdrant. Résultat : `roosync_search(semantic)` ne trouvait aucune trace de décisions comme la migration INTERCOM → dashboard.

## Cause racine

Les sessions Claude Code (JSONL dans `~/.claude/projects/*/`) n'étaient pas indexées dans la collection Qdrant `roo_tasks_semantic_index`. Seules les tâches Roo l'étaient.

## Solution

Indexation des sessions Claude via `roosync_indexing` avec `source: "claude-code"`.

### Format taskId

Le `task_id` pour les sessions Claude utilise le format : `claude-{projectName}`

Où `{projectName}` est le nom du répertoire projet dans `~/.claude/projects/`.

Exemples :
- `claude-c--dev-roo-extensions` → indexe toutes les sessions JSONL de ce projet
- `claude-c--dev-CoursIA` → indexe les sessions CoursIA

### Commande d'indexation

```
roosync_indexing(action: "index", source: "claude-code", task_id: "claude-{projectName}")
```

**Attention :** L'indexation est coûteuse (CPU + API embedding). Pour >1000 sessions, demander approbation user.

### Résultats observés (po-2026, 2026-04-29)

| Métrique | Valeur |
|----------|--------|
| Sessions indexées | 61 (roo-extensions) |
| Chunks générés | 4410 |
| Durée | ~29 min |
| Score meilleur résultat | 0.86 (good) |

## Procédure Multi-Pass pour Retrouvabilité

### Pass 1 : Recherche sémantique (source Claude)

```
roosync_search(action: "semantic", search_query: "...", source: "claude-code", max_results: 5)
```

Requêtes en anglais ou français. Le modèle embedding gère les deux.

### Pass 2 : Recherche sémantique (source Roo, en fallback)

```
roosync_search(action: "semantic", search_query: "...", source: "roo", max_results: 5)
```

Les tâches Roo peuvent référencer des décisions prises en sessions Claude.

### Pass 3 : Recherche textuelle (grep dans le cache)

```
roosync_search(action: "text", search_query: "exact phrase")
```

### Pass 4 : Dashboard archives

```
roosync_dashboard(action: "read_archive")
```

Les condensations automatiques archivent les messages anciens.

### Pass 5 : Git log / Grep (dernier recours)

```bash
git log --all --grep="keyword" --oneline
grep -r "keyword" docs/ .claude/rules/
```

## Vérification post-indexation

Après indexation, valider avec une requête concept-driven :

```
roosync_search(action: "semantic", search_query: "migration INTERCOM vers dashboard", source: "claude-code")
```

Score attendu : ≥0.80 (good) pour retrouver la décision pertinente en top 3.

## Déploiement cross-machine

Pour indexer les sessions Claude sur chaque machine :

```bash
# Sur chaque machine, dans une session Claude Code :
roosync_indexing(action: "index", source: "claude-code", task_id: "claude-{localProjectDir}")
```

Le projectDir varie par machine (`c--dev-roo-extensions`, `D--dev-roo-extensions`, etc.). Vérifier avec :

```bash
ls ~/.claude/projects/ | grep roo
```

---

**Dernière MAJ :** 2026-04-29 (po-2026, cycle 24ter)
