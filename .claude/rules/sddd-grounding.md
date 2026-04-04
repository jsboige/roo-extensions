# SDDD - Triple Grounding (Obligatoire)

**Version:** 1.0.0 (condense depuis `.claude/docs/sddd-conversational-grounding.md`)
**Issue:** #1063

---

## Principe

**SDDD (Semantic Documentation Driven Development) :** Tout travail significatif doit croiser 3 sources :

1. **Semantique** — `codebase_search` + `roosync_search(action: "semantic")` : trouver par concept
2. **Conversationnel** — `conversation_browser` + traces Roo : historique de travail
3. **Technique** — Read, Grep, Glob, Bash, Git : code source = verite

**Regle absolue :** Ne jamais se contenter d'une seule source.

---

## Pattern Bookend (OBLIGATOIRE)

**`codebase_search` en DEBUT et FIN de chaque tache significative.**

**Debut :** Eviter de refaire un travail deja fait, comprendre le contexte.

**Fin :** Confirmer que le travail est indexe et retrouvable.

| Type de tache | Bookend |
|---------------|---------|
| Feature/fix/investigation | OUI (debut + fin) |
| Mise a jour doc | OUI (debut + fin) |
| Commit/push, reponse question | NON |

---

## codebase_search — Protocole Multi-Pass

**OBLIGATOIRE :** Toujours passer `workspace` explicitement (auto-detection pointe vers le serveur MCP).

**Limitations :** Chunks ~1000 chars, pas de chevauchement, requetes en francais peu performantes.

| Pass | But | Methode |
|------|-----|---------|
| 1 | Identifier le module | Requete conceptuelle large (anglais) |
| 2 | Zoom dans le module | `directory_prefix` + vocabulaire du code |
| 3 | Confirmer | Grep exact (noms de fonctions, types) |
| 4 | Variante | Reformuler avec synonymes si Pass 2 insuffisant |

**Conseils :** Vocabulaire du code > langage naturel. 5-10 mots cles, pas des phrases. `directory_prefix` divise l'espace par ~10.

---

## roosync_search — Recherche dans les Taches

```
roosync_search(action: "semantic", search_query: "concept")  # Par concept (Qdrant)
roosync_search(action: "text", search_query: "texte exact")  # Par texte (cache)
roosync_search(action: "diagnose")                           # Diagnostic index
```

**Filtres avances (`action: "semantic"`) :**

| Filtre | Usage |
|--------|-------|
| `has_errors: true` | Messages avec erreurs |
| `tool_name: "write_to_file"` | Historique d'un outil |
| `role: "user"`, `exclude_tool_results: true` | Messages utilisateur purs |
| `source: "roo"` ou `"claude-code"` | Filtrer par agent |
| `model: "opus"`, `start_date`, `end_date` | Par modele et periode |

---

## Workflow SDDD Complet

```
1. BOOKEND DEBUT : codebase_search (Pass 1 → Pass 2) + roosync_search(semantic)
2. CONVERSATIONNEL : conversation_browser(list) → IDs → view(skeleton)
3. TECHNIQUE : Read/Grep code source (Pass 3)
4. TRAVAIL : Implementer/corriger/documenter
5. BOOKEND FIN : codebase_search(query: "validation") → confirmer indexation
```

**Etape 2 :** `list` est OBLIGATOIRE en premier. Sans IDs, `view`/`tree`/`summarize` sont impossibles. `current` seul est insuffisant.

---

## Si un outil SDDD echoue

Signaler via protocole friction : `.claude/docs/friction-protocol.md`

---

**Reference complete :** `.claude/docs/sddd-conversational-grounding.md` (344 lignes, version detaillee)
**Methodologie systeme RooSync :** `docs/roosync/PROTOCOLE_SDDD.md`
