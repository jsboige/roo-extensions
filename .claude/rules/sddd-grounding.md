# Regles SDDD - Grounding Conversationnel (Roo)

**Version:** 4.0.0 (#2218 codebase_search SDDD bookend generalisé)
**MAJ:** 2026-05-16

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

**`codebase_search` en DEBUT et FIN de chaque tache significative (>50 LOC ou >3 fichiers).**

- **Debut :** Eviter de refaire un travail deja fait, comprendre le contexte.
  - Trouver la documentation existante (README, CLAUDE.md, docs/, ADRs)
  - Verifier que la tache n'a pas deja ete faite
  - Identifier le contexte : qui a travaille dessus, quelles decisions ont ete prises
- **Fin :** Confirmer que le travail est indexe et retrouvable.
  - S'assurer que le travail est coherent avec le reste du projet
  - Mettre a jour la documentation afferente si le travail la rend obsolete

## Wiki Karpathy / SDDD Documentaire

Apres chaque tache significative, si `codebase_search` en debut a trouve de la documentation existante :
- **Verifier** qu'elle est toujours a jour
- **Mettre a jour** si le travail l'a rendue obsolete
- **Documenter** les decisions prises et les approches rejetees

Ce pattern est analogue au "wiki Karpathy" : documenter comprehensivement ce qu'on apprend en construisant.

## Complementarite Grep vs codebase_search

| Besoin | Outil |
|--------|-------|
| Symbole exact, nom de fonction | `Grep` |
| Fichier par pattern | `Glob` |
| Concept, documentation, contexte | `codebase_search` |
| Historique conversations | `roosync_search(semantic)` |

`Grep` trouve des strings exacts mais pas les concepts. `codebase_search` decouvre la documentation meme sans connaitre les mots exacts.

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

1. **Bookend DEBUT** : `codebase_search` pour trouver docs existantes et verifier doublons
2. **Semantique** : `codebase_search` (Pass 1→2) + `roosync_search(semantic)`
3. **Conversationnel** : `conversation_browser(list)` → IDs → `view(skeleton)`
4. **Technique** : `read_file`, `search_files`
5. **Travail** : Implementer/corriger/documenter
6. **Bookend FIN** : `codebase_search` pour confirmer indexation + mettre a jour doc afferente

---
**Historique versions completes :** Git history avant 2026-04-08
