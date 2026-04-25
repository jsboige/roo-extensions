# Guide conversation_browser — Usage

**Version:** 1.0.0 (slim)
**Issue :** #1063, fix #881

---

## Point d'Entree OBLIGATOIRE

**TOUJOURS commencer par `list`** pour obtenir les IDs :

```
conversation_browser(action: "list", workspace: "C:/dev/roo-extensions", limit: 20)
```

Sans IDs, `view`/`tree`/`summarize` sont impossibles. `current` seul est insuffisant.

## Actions Principales

| Action | Usage | Parametres cles |
|--------|-------|-----------------|
| **`list`** | Lister taches recentes (OBLIGATOIRE en premier) | `limit`, `contentPattern` |
| `tree` | Arbre des taches | `conversation_id`, `output_format: "ascii-tree"` |
| `current` | Tache active | `workspace` |
| `view` | Squelette conversation | `task_id`, `smart_truncation: true` |
| `summarize` | Resume/stats | `summarize_type: "trace"`, `taskId` |

Niveaux recommandes : `Summary` ou `Compact`. Jamais `Full`.

---

**detailLevel complet, summarize_type, anti-patterns :** [`docs/harness/reference/conversation-browser-detailed.md`](docs/harness/reference/conversation-browser-detailed.md)
