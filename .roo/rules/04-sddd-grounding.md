# Regles SDDD - Grounding Conversationnel (Roo)

**Version:** 2.1.0 (2026-02-23)

## Triple Grounding

**SDDD (Semantic Documentation Driven Development)** : 3 types de grounding a croiser systematiquement.

1. **Semantique** - `roosync_search(action: "semantic")` + search_files / codebase_search
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

## Recherche Semantique Multi-Pass (codebase_search)

Les fichiers sont indexes par chunks de ~1000 chars (tree-sitter). Une seule requete large est souvent insuffisante.

**Protocole en 4 passes :**

1. **Pass 1 - Requete large** (sans directory_prefix) : identifier le module/repertoire
   ```xml
   <use_mcp_tool>
   <server_name>roo-state-manager</server_name>
   <tool_name>codebase_search</tool_name>
   <arguments>{"query": "message sending communication", "workspace": "d:\\roo-extensions"}</arguments>
   </use_mcp_tool>
   ```

2. **Pass 2 - Zoom** (avec directory_prefix + vocabulaire code) : cibler le fichier
   ```xml
   <use_mcp_tool>
   <server_name>roo-state-manager</server_name>
   <tool_name>codebase_search</tool_name>
   <arguments>{"query": "format result success priority", "workspace": "d:\\roo-extensions", "directory_prefix": "src/tools/roosync"}</arguments>
   </use_mcp_tool>
   ```

3. **Pass 3 - Grep confirmation** : verite technique avec search_files exact
4. **Pass 4 - Variante** : reformuler si Pass 2 insuffisante

**Conseils :**
- Requetes en anglais (embeddings anglophones)
- Vocabulaire du code > langage naturel
- `directory_prefix` divise l'espace de recherche par ~10
- Scores typiques : 0.60-0.80 pour resultats pertinents

---

## Workflow SDDD

1. **Semantique** : `roosync_search` + `codebase_search` (multi-pass si besoin) + docs existantes
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
- Combiner `codebase_search` (concept) avec `search_files` (exact) pour meilleure couverture
- Toujours passer `workspace` explicitement a `codebase_search`

---

**Reference :** `.roo/README.md`
