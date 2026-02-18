# Regles SDDD - Grounding Conversationnel (Roo)

## Triple Grounding

**SDDD (Semantic Documentation Driven Development)** : 3 types de grounding a croiser systematiquement.

1. **Semantique** - `roosync_search(action: "semantic")` + search_files
2. **Conversationnel** - `conversation_browser` (CES REGLES)
3. **Technique** - read_file, search_files, execute_command (code = verite)

---

## Outils Conversationnels (MCP roo-state-manager)

### conversation_browser (outil unifie)

Remplace les anciens `task_browse`, `view_conversation_tree`, `roosync_summarize`.

| Action | Usage | Parametres cles |
|--------|-------|----------------|
| `tree` | Arbre des taches Roo | `conversation_id`, `output_format: "ascii-tree"` |
| `current` | Tache active | `workspace: "d:\\roo-extensions"` |
| `view` | Squelette conversation | `task_id`, `smart_truncation: true`, `max_output_length: 15000` |
| `summarize` | Resume/stats | `summarize_type: "trace"`, `taskId` |

```xml
<!-- Arbre des taches -->
<use_mcp_tool>
<server_name>roo-state-manager</server_name>
<tool_name>conversation_browser</tool_name>
<arguments>{"action": "tree", "conversation_id": "abc123...", "output_format": "ascii-tree"}</arguments>
</use_mcp_tool>

<!-- Squelette avec smart truncation (RECOMMANDE) -->
<use_mcp_tool>
<server_name>roo-state-manager</server_name>
<tool_name>conversation_browser</tool_name>
<arguments>{"action": "view", "task_id": "abc123...", "detail_level": "skeleton", "smart_truncation": true, "max_output_length": 15000}</arguments>
</use_mcp_tool>

<!-- Resume trace (statistiques) -->
<use_mcp_tool>
<server_name>roo-state-manager</server_name>
<tool_name>conversation_browser</tool_name>
<arguments>{"action": "summarize", "summarize_type": "trace", "taskId": "abc123..."}</arguments>
</use_mcp_tool>
```

**TOUJOURS activer `smart_truncation: true`** pour conversations >10K chars.

**Modes `view` detail_level :**
- `skeleton` : Minimal (par defaut, recommande)
- `summary` : Messages cles
- `full` : Complet (risque overflow sans smart truncation)

**Modes `summarize` :**
- `trace` : Stats (compression, breakdown User/Assistant/Tools)
- `cluster` : Grappes parent-enfant
- `synthesis` : **BUG CONNU** - ne pas utiliser

---

## Workflow SDDD

1. **Semantique** : `roosync_search` + docs existantes
2. **Conversationnel** : `conversation_browser(tree)` -> `conversation_browser(view, skeleton)` -> `conversation_browser(summarize, trace)`
3. **Technique** : read_file, search_files, tests unitaires

**Regle :** Ne jamais se contenter d'une seule source.

---

## Bonnes Pratiques

- Commencer par `tree` pour le contexte global
- Utiliser `skeleton` en premier, `summary` si besoin
- Generer des `trace` pour investigations >500 messages
- Ne PAS utiliser `full` sans smart truncation
- Ne PAS ignorer les metadonnees (timestamp, workspace, mode)

---

**Reference :** `.roo/README.md`
