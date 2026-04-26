# conversation_browser — Reference Detaillee

**Source :** `.claude/rules/conversation-browser-guide.md` (version slim)
**Issue :** #1063, fix #881

---

## detailLevel — Reference Complete

**TOUJOURS activer `smart_truncation: true`** pour conversations >10K chars.
**TOUJOURS definir `truncationChars`** quand `summarize_type != "trace"`.

| Niveau | Contenu | Recommandation |
|--------|---------|----------------|
| **`Summary`** | Vue condensee | Recommande |
| **`Compact`** | Messages + outils resumes (nom + statut) | Recommande (#881) |
| **`NoTools`** | Alias vers `Compact` (fix #881) | OK maintenant |
| **`NoResults`** | Messages + params sans resultats | Compact |
| **`Messages`** | Messages seulement | Tres compact |
| **`UserOnly`** | Messages utilisateur seulement | Plus compact |
| **`NoToolParams`** | Params masques, resultats complets | Debug seulement |
| **`Full`** | Tout inclus | JAMAIS (explosion contextuelle) |

## summarize_type

| Type | Usage | truncationChars |
|------|-------|-----------------|
| `trace` | Stats (messages par type, taille, breakdown) | Pas requis |
| `cluster` | Grappes parent-enfant | Recommande |
| `synthesis` | Pipeline LLM (requiert `OPENAI_API_KEY`) | Recommande |

**Bug connu :** `synthesis` peut echouer. Preferer `trace`.

## Anti-Patterns

- Deviner les IDs de taches
- Utiliser `current` comme seul point d'entree
- Aller a `view`/`tree` sans `list` prealable
- Utiliser `Full` sans `smart_truncation`
- Ignorer les metadonnees (timestamp, workspace, mode)

**Reference complete :** `docs/harness/reference/sddd-conversational-grounding.md` (344 lignes)
