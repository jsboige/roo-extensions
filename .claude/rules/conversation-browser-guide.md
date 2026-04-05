# Guide conversation_browser — Usage et Fix #881

**Version:** 1.0.0
**Issue:** #1063
**Contexte:** Fix #881 applique — `detailLevel: "NoTools"` maintenant alias vers `Compact`

---

## Point d'Entree OBLIGATOIRE

**TOUJOURS commencer par `list`** pour obtenir les IDs de taches :

```
conversation_browser(action: "list", workspace: "C:/dev/roo-extensions", limit: 20)
```

Sans IDs, `view`/`tree`/`summarize` sont impossibles. `current` seul est insuffisant (retourne la plus ancienne tache ouverte).

**Recherche par contenu :**
```
conversation_browser(action: "list", contentPattern: "mot-cle", limit: 30)
```

---

## Actions Principales

| Action | Usage | Parametres cles |
|--------|-------|-----------------|
| **`list`** | Lister taches recentes (OBLIGATOIRE en premier) | `limit`, `contentPattern` |
| `tree` | Arbre des taches | `conversation_id`, `output_format: "ascii-tree"` |
| `current` | Tache active | `workspace` |
| `view` | Squelette conversation | `task_id`, `smart_truncation: true` |
| `summarize` | Resume/stats | `summarize_type: "trace"`, `taskId` |

---

## detailLevel — Reference Post-Fix #881

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

---

## summarize_type

| Type | Usage | truncationChars |
|------|-------|-----------------|
| `trace` | Stats (messages par type, taille, breakdown) | Pas requis |
| `cluster` | Grappes parent-enfant | Recommande |
| `synthesis` | Pipeline LLM (requiert `OPENAI_API_KEY`) | Recommande |

**Bug connu :** `synthesis` peut echouer. Preferer `trace` pour les rapports metriques.

---

## Anti-Patterns

- Deviner les IDs de taches
- Utiliser `current` comme seul point d'entree
- Aller a `view`/`tree` sans `list` prealable
- Utiliser `Full` sans `smart_truncation`
- Ignorer les metadonnees (timestamp, workspace, mode)

---

**Reference complete :** `docs/harness/reference/sddd-conversational-grounding.md` (344 lignes)
