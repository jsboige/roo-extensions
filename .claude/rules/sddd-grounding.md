# Regles SDDD - Grounding Conversationnel (Roo)

**Version:** 3.0.0 (condensed from 2.1.0, aligned with .claude/rules/sddd-grounding.md)
**MAJ:** 2026-04-08

## Triple Grounding

**SDDD :** 3 sources a croiser systematiquement :

1. **Semantique** — `roosync_search(action: "semantic")` + `codebase_search`
2. **Conversationnel** — `conversation_browser` (CES REGLES)
3. **Technique** — `search_files`, `read_file`, `execute_command` (code = verite)

**Regle :** Ne jamais se contenter d'une seule source.

## conversation_browser

**POINT D'ENTREE OBLIGATOIRE : `list`** — Sans IDs, `view`/`tree`/`summarize` sont impossibles.

| Action | Usage | Parametres cles |
| ------ | ----- | --------------- |
| **`list`** | **OBLIGATOIRE en premier** | `workspace`, `limit`, `contentPattern` |
| `tree` | Arbre des taches | `conversation_id`, `output_format: "ascii-tree"` |
| `view` | Squelette conversation | `task_id`, `smart_truncation: true` |
| `summarize` | Resume/stats | `summarize_type: "trace"`, `taskId` |

**Toujours `smart_truncation: true`** pour conversations >10K chars.

## detailLevel (post-fix #881)

| Niveau | Recommandation |
| ------ | -------------- |
| `Summary` | Recommande |
| `Compact` / `NoTools` | Recommande (NoTools = alias Compact depuis #881) |
| `Messages` / `UserOnly` | Compact |
| `Full` | **JAMAIS** (explosion) |

Toujours definir `truncationChars` quand `summarize_type != "trace"`.

## roosync_search — Filtres avances (#636)

```
roosync_search(action: "semantic", search_query: "...", has_errors: true, start_date: "...", max_results: 10)
```

| Filtre | Usage |
| ------ | ----- |
| `has_errors: true` | Messages avec erreurs |
| `tool_name: "write_to_file"` | Historique d'un outil |
| `role: "user"`, `exclude_tool_results: true` | Messages utilisateur purs |
| `source: "roo"` ou `"claude-code"` | Filtrer par agent |
| `model: "opus"`, `start_date`, `end_date` | Par modele et periode |

## Pattern Bookend (OBLIGATOIRE)

**`codebase_search` en DEBUT et FIN de chaque tache significative.**

- **Debut :** Eviter de refaire un travail deja fait, comprendre le contexte.
- **Fin :** Confirmer que le travail est indexe et retrouvable.

## codebase_search — Protocole Multi-Pass

**Toujours passer `workspace` explicitement.** Requetes en anglais, 5-10 mots cles.

| Pass | But |
| ---- | --- |
| 1 | Requete large (identifier module) |
| 2 | `directory_prefix` + vocabulaire code (zoom) |
| 3 | `search_files` exact (confirmer) |
| 4 | Reformuler avec synonymes |

## INTERDICTION : Lecture directe JSONL (#1785)

**NE JAMAIS lire les fichiers JSONL/JSON de session directement** — voir regles completes dans `27-no-direct-jsonl-read.md`.

| Besoin | Outil |
| ------ | ----- |
| Voir les sessions | `conversation_browser(action: "list")` |
| Lire une session | `conversation_browser(action: "view", task_id: "...", smart_truncation: true)` |
| Resumer | `conversation_browser(action: "summarize", summarize_type: "trace")` |
| Chercher | `roosync_search(action: "semantic", search_query: "...")` |

## Workflow SDDD

1. **Semantique** : `codebase_search` (Pass 1→2) + `roosync_search(semantic)`
2. **Conversationnel** : `conversation_browser(list)` → IDs → `view(skeleton)`
3. **Technique** : `read_file`, `search_files`
4. **Travail** : Implementer/corriger/documenter
5. **Bookend FIN** : `codebase_search` validation

---
**Historique versions completes :** Git history avant 2026-04-08
