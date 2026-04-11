# SDDD - Grounding Conversationnel (Roo)

**Version:** 3.0.0 (condensed from 2.1.0, aligned with .roo/rules/04-sddd-grounding.md)
**MAJ:** 2026-04-08

## Triple Grounding

**SDDD :** 3 sources à croiser systématiquement :

1. **Sémantique** — `roosync_search(action: "semantic")` + `codebase_search`
2. **Conversationnel** — `conversation_browser` (CES RÈGLES)
3. **Technique** — `search_files`, `read_file`, `execute_command` (code = vérité)

**Règle :** Ne jamais se contenter d'une seule source.

## conversation_browser

**POINT D'ENTREE OBLIGATOIRE : `list`** — Sans IDs, `view`/`tree`/`summarize` sont impossibles.

| Action | Usage | Paramètres clés |
| ------ | ----- | --------------- |
| **`list`** | **OBLIGATOIRE en premier** | `workspace`, `limit`, `contentPattern` |
| `tree` | Arbre des tâches | `conversation_id`, `output_format: "ascii-tree"` |
| `view` | Squelette conversation | `task_id`, `smart_truncation: true` |
| `summarize` | Résumé/stats | `summarize_type: "trace"`, `taskId` |

**Toujours `smart_truncation: true`** pour conversations >10K chars.

## detailLevel (post-fix #881)

| Niveau | Recommandation |
| ------ | -------------- |
| `Summary` | Recommandé |
| `Compact` / `NoTools` | Recommandé (NoTools = alias Compact depuis #881) |
| `Messages` / `UserOnly` | Compact |
| `Full` | **JAMAIS** (explosion) |

Toujours définir `truncationChars` quand `summarize_type != "trace"`.

## roosync_search — Filtres avancés (#636)

```
roosync_search(action: "semantic", search_query: "...", has_errors: true, start_date: "...", max_results: 10)
```

| Filtre | Usage |
| ------ | ----- |
| `has_errors: true` | Messages avec erreurs |
| `tool_name: "write_to_file"` | Historique d'un outil |
| `role: "user"`, `exclude_tool_results: true` | Messages utilisateur purs |
| `source: "roo"` ou `"claude-code"` | Filtrer par agent |
| `model: "opus"`, `start_date`, `end_date` | Par modèle et période |

## Pattern Bookend (OBLIGATOIRE)

**`codebase_search` en DEBUT et FIN de chaque tâche significative.**

- **Début :** Éviter de refaire un travail déjà fait, comprendre le contexte.
- **Fin :** Confirmer que le travail est indexé et retrouvable.

## codebase_search — Protocole Multi-Pass

**Toujours passer `workspace` explicitement.** Requêtes en anglais, 5-10 mots clés.

| Pass | But |
| ---- | --- |
| 1 | Requête large (identifier module) |
| 2 | `directory_prefix` + vocabulaire code (zoom) |
| 3 | `search_files` exact (confirmer) |
| 4 | Reformuler avec synonymes |

## Workflow SDDD

1. **Sémantique** : `codebase_search` (Pass 1→2) + `roosync_search(semantic)`
2. **Conversationnel** : `conversation_browser(list)` → IDs → `view(skeleton)`
3. **Technique** : `read_file`, `search_files`
4. **Travail** : Implémenter/corriger/documenter
5. **Bookend FIN** : `codebase_search` validation

---
**Historique versions complètes :** Git history avant 2026-04-08
