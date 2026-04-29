# INTERDICTION : Lecture Directe des Fichiers Session JSONL

**Version:** 1.0.0
**Issue :** #1785
**MAJ :** 2026-04-29

---

## Regle Absolue

**NE JAMAIS lire les fichiers JSONL/JSON de session directement** avec `read_file`, `execute_command` (`Get-Content`, `cat`, `type`), ou tout autre methode d'acces fichier.

### Repertoires PROTEGES (lecture INTERDITE)

| Repertoire | Contenu | Taille typique |
| ---------- | ------- | -------------- |
| `.roo/tasks/` | Sessions Roo (JSON) | 1-100 MB chacune |
| `~/.claude/projects/` | Sessions Claude Code (JSONL) | 10-300 MB chacune |
| `.claude/projects/` | Sessions Claude Code (JSONL) | 10-300 MB chacune |

**Pourquoi :** Meme `-TotalCount 30` sur un fichier JSONL de 100 MB injecte des dizaines de KB de JSON brut dans le contexte. Resultat : explosion contexte → compaction → perte d'instructions → boucle meta-analyste en cascade.

### Exception

Fichiers de configuration (`*.json` < 100 KB) = OK via `read_file`. Exemples : `package.json`, `tsconfig.json`, `.roo/mcp.json`.

---

## Outils MCP Autorises (REMPLACEMENT)

### conversation_browser — Exploration de sessions

**Workflow obligatoire : `list` → `view`/`summarize`**

```
// ETAPE 1 : Lister les sessions (OBLIGATOIRE en premier)
conversation_browser(action: "list", limit: 20)

// ETAPE 2a : Voir une session specifique (obtenir task_id depuis list)
conversation_browser(action: "view", task_id: "abc123", smart_truncation: true)

// ETAPE 2b : Resumer une session
conversation_browser(action: "summarize", summarize_type: "trace", taskId: "abc123")

// ETAPE 2c : Arbre parent-enfant
conversation_browser(action: "tree", conversation_id: "conv-456", output_format: "ascii-tree")
```

| Action | Quand l'utiliser | Parametres importants |
| ------ | ---------------- | --------------------- |
| `list` | TOUJOURS en premier | `limit: 20`, `contentPattern: "mot-cle"` |
| `view` | Lire le contenu d'une session | `task_id`, `smart_truncation: true`, `detail_level: "Summary"` |
| `summarize` | Resume/stats d'une session | `summarize_type: "trace"`, `taskId` |
| `tree` | Arbre des sous-taches | `conversation_id`, `output_format: "ascii-tree"` |
| `current` | Session active | `workspace` |

### roosync_search — Recherche dans les sessions

```
// Recherche semantique (par concept)
roosync_search(action: "semantic", search_query: "migration INTERCOM dashboard", max_results: 10)

// Recherche textuelle (mots exacts)
roosync_search(action: "text", search_query: "atomicWriteFileSync", max_results: 5)
```

### codebase_search — Recherche dans le code source

```
codebase_search(query: "heartbeat atomic write", workspace: "C:/dev/roo-extensions")
```

---

## Exemples Concrets

### Exemple 1 : Investiguer un bug signale

**MAUVAIS (INTERDIT) :**
```
execute_command(shell="powershell", command="Get-Content .roo/tasks/task-abc.json -TotalCount 50")
```

**BON :**
```
// 1. Trouver la session
conversation_browser(action: "list", contentPattern: "heartbeat", limit: 10)

// 2. Voir le resume
conversation_browser(action: "summarize", summarize_type: "trace", taskId: "task-xyz789")

// 3. Si detail necessaire, voir avec troncature intelligente
conversation_browser(action: "view", task_id: "task-xyz789", smart_truncation: true, detail_level: "Summary")
```

### Exemple 2 : Chercher une decision historique

**MAUVAIS (INTERDIT) :**
```
read_file(path=".claude/projects/session-2026-03.jsonl")
```

**BON :**
```
roosync_search(action: "semantic", search_query: "decision condensation threshold 75 percent", max_results: 5)
```

### Exemple 3 : Analyser l'historique d'un fichier

**MAUVAIS (INTERDIT) :**
```
execute_command(shell="powershell", command="Get-ChildItem ~/.claude/projects -Recurse -Filter *.jsonl | Select-String 'HeartbeatService'")
```

**BON :**
```
roosync_search(action: "text", search_query: "HeartbeatService", max_results: 10)
```

---

## Niveaux de Detail (view/summarize)

| Niveau | Recommandation | Contexte consomme |
| ------ | -------------- | ----------------- |
| `Summary` | **Recommande** | Faible |
| `Compact` / `NoTools` | OK | Moyen |
| `Messages` / `UserOnly` | Utiliser avec precaution | Eleve |
| `Full` | **JAMAIS** | Explosion (~100KB+) |

**Toujours** utiliser `smart_truncation: true` pour les sessions >10K chars.

---

## References croisees

- **Claude Code** : `.claude/rules/conversation-browser-guide.md` — guide equivalent pour Claude
- **Claude Code** : `.claude/rules/sddd-grounding.md` — protocole SDDD complet
- **Roo** : `04-sddd-grounding.md` — regles SDDD Roo (section INTERDICTION)
- **Documentation** : `docs/harness/reference/conversation-browser-detailed.md` — reference complete
