# SDDD — Protocole Multi-Pass et Filtres (Reference)

**Source :** `.claude/rules/sddd-grounding.md` (version slim)
**Issue :** #1063 — enrichi le 2026-08-05 (déport v5.0.0 de la règle)

---

## conversation_browser — actions

| Action | Usage | Parametres cles |
| ------ | ----- | --------------- |
| **`list`** | **OBLIGATOIRE en premier** — sans IDs, le reste est impossible | `workspace`, `limit`, `contentPattern` |
| `tree` | Arbre des taches | `conversation_id`, `output_format: "ascii-tree"` |
| `view` | Squelette de conversation | `task_id`, `smart_truncation: true` |
| `summarize` | Resume / stats | `summarize_type: "trace"`, `taskId` |

Toujours `smart_truncation: true` au-dela de 10K chars.

## detailLevel (post-fix #881)

| Niveau | Recommandation |
| ------ | -------------- |
| `Summary` | Recommande |
| `Compact` / `NoTools` | Recommande (`NoTools` = alias de `Compact` depuis #881) |
| `Messages` / `UserOnly` | Compact |
| `Full` | **JAMAIS** (explosion de contexte) |

Toujours definir `truncationChars` quand `summarize_type != "trace"`.

## Grep vs codebase_search — complementarite

| Besoin | Outil |
|--------|-------|
| Symbole exact, nom de fonction | `Grep` |
| Fichier par pattern | `Glob` |
| Concept, documentation, contexte | `codebase_search` |
| Historique de conversations | `roosync_search(semantic)` |

`Grep` trouve des chaines exactes mais pas des concepts. `codebase_search` decouvre la documentation
meme sans en connaitre les mots exacts.

## Substituts a la lecture directe des JSONL (#1785)

**Ne JAMAIS lire un fichier JSONL/JSON de session directement** (regle complete :
`.roo/rules/27-no-direct-jsonl-read.md`).

| Besoin | Outil |
| ------ | ----- |
| Voir les sessions | `conversation_browser(action: "list")` |
| Lire une session | `conversation_browser(action: "view", task_id: ..., smart_truncation: true)` |
| Resumer | `conversation_browser(action: "summarize", summarize_type: "trace")` |
| Chercher | `roosync_search(action: "semantic", search_query: ...)` |

## codebase_search — Protocole Multi-Pass

**OBLIGATOIRE :** Toujours passer `workspace` explicitement.

| Pass | But | Methode |
|------|-----|---------|
| 1 | Identifier le module | Requete conceptuelle large (anglais) |
| 2 | Zoom dans le module | `directory_prefix` + vocabulaire du code |
| 3 | Confirmer | Grep exact (noms de fonctions, types) |
| 4 | Variante | Reformuler avec synonymes si Pass 2 insuffisant |

**Conseils :** Vocabulaire du code > langage naturel. 5-10 mots cles, pas des phrases. `directory_prefix` divise l'espace par ~10. Requetes en francais = mauvais resultats.

## roosync_search — Filtres avances (`action: "semantic"`)

| Filtre | Usage |
|--------|-------|
| `has_errors: true` | Messages avec erreurs |
| `tool_name: "write_to_file"` | Historique d'un outil |
| `role: "user"`, `exclude_tool_results: true` | Messages utilisateur purs |
| `source: "roo"` ou `"claude-code"` | Filtrer par agent |
| `model: "opus"`, `start_date`, `end_date` | Par modele et periode |

## Workflow SDDD Complet

```
1. BOOKEND DEBUT : codebase_search (Pass 1 → Pass 2) + roosync_search(semantic)
2. CONVERSATIONNEL : conversation_browser(list) → IDs → view(skeleton)
3. TECHNIQUE : Read/Grep code source (Pass 3)
4. TRAVAIL : Implementer/corriger/documenter
5. BOOKEND FIN : codebase_search → confirmer indexation
```

**Etape 2 :** `list` est OBLIGATOIRE en premier. Sans IDs, `view`/`tree`/`summarize` sont impossibles.

## Wiki Karpathy / SDDD documentaire

Apres chaque tache significative, si le bookend de debut a trouve de la documentation existante :
la **verifier**, la **mettre a jour** si le travail l'a rendue obsolete, et **documenter** les
decisions prises ainsi que les approches testees-et-rejetees.

**Reference complete :** `docs/harness/reference/sddd-conversational-grounding.md` (344 lignes)
**Methodologie systeme :** `docs/roosync/PROTOCOLE_SDDD.md`
