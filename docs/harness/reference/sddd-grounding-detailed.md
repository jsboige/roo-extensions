# SDDD — Protocole Multi-Pass et Filtres (Reference)

**Source :** `.claude/rules/sddd-grounding.md` (version slim)
**Issue :** #1063

---

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

**Reference complete :** `docs/harness/reference/sddd-conversational-grounding.md` (344 lignes)
**Methodologie systeme :** `docs/roosync/PROTOCOLE_SDDD.md`
