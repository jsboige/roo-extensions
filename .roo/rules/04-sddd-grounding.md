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
| **`list`** | **POINT D'ENTREE OBLIGATOIRE** - Lister les taches pour obtenir les IDs | `workspace`, `limit`, `contentPattern` |
| `tree` | Arbre des taches Roo | `conversation_id`, `output_format: "ascii-tree"` |
| `current` | Tache active | `workspace: "d:\\roo-extensions"` |
| `view` | Squelette conversation | `task_id`, `smart_truncation: true`, `max_output_length: 15000` |
| `summarize` | Resume/stats | `summarize_type: "trace"`, `taskId` |

### REGLE CRITIQUE : `list` comme point d'entree

**Sans IDs, tu es aveugle.** TOUJOURS commencer par `list` avant d'utiliser `tree`, `view` ou `summarize`.

```xml
<!-- PREMIER appel obligatoire : lister les taches recentes -->
<use_mcp_tool>
<server_name>roo-state-manager</server_name>
<tool_name>conversation_browser</tool_name>
<arguments>{"action": "list", "workspace": "d:\\roo-extensions", "limit": 20}</arguments>
</use_mcp_tool>

<!-- Chercher par contenu specifique -->
<use_mcp_tool>
<server_name>roo-state-manager</server_name>
<tool_name>conversation_browser</tool_name>
<arguments>{"action": "list", "contentPattern": "write_to_file", "limit": 30}</arguments>
</use_mcp_tool>
```

**Anti-pattern :** Aller directement a `view` ou `tree` sans avoir liste. `current` seul est insuffisant (retourne la plus ancienne tache ouverte).

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

## Pattern Bookend (OBLIGATOIRE pour toute tache significative)

**`codebase_search` doit etre utilise en DEBUT et en FIN de chaque tache significative.**

### En debut de tache (Contexte)

Avant de commencer, chercher ce qui existe deja :

```xml
<use_mcp_tool>
<server_name>roo-state-manager</server_name>
<tool_name>codebase_search</tool_name>
<arguments>{"query": "description conceptuelle de la tache", "workspace": "d:\\roo-extensions"}</arguments>
</use_mcp_tool>
```

**But :** Eviter de refaire un travail deja fait, comprendre le contexte existant, trouver les fichiers pertinents.

### En fin de tache (Validation)

Apres avoir termine, verifier que le travail est visible :

```xml
<use_mcp_tool>
<server_name>roo-state-manager</server_name>
<tool_name>codebase_search</tool_name>
<arguments>{"query": "concept implemente/corrige", "workspace": "d:\\roo-extensions"}</arguments>
</use_mcp_tool>
```

**But :** Confirmer que le code/la doc est indexe et retrouvable. Si le resultat ne remonte pas, l'indexation n'a pas eu lieu ou la documentation est insuffisante.

### Quand appliquer le bookend

| Type de tache | Bookend obligatoire |
|---------------|-------------------|
| Feature/fix dans le code | OUI (debut + fin) |
| Investigation de bug | OUI (debut seulement) |
| Mise a jour de doc | OUI (eviter doublons) |
| Simple commit/push | NON (tache mecanique) |

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
2. **Conversationnel** : `conversation_browser(list)` → obtenir IDs → `conversation_browser(view, skeleton)` → `conversation_browser(summarize, trace)` si besoin
3. **Technique** : read_file, search_files, tests unitaires

**IMPORTANT :** L'etape 2 COMMENCE par `list`. Sans IDs, les appels suivants sont impossibles.

**Regle :** Ne jamais se contenter d'une seule source.

---

## Bonnes Pratiques

- **Commencer par `list`** pour obtenir les IDs des taches recentes (OBLIGATOIRE)
- Utiliser `tree` pour le contexte global une fois les IDs connus
- Utiliser `skeleton` en premier, `summary` si besoin
- Generer des `trace` pour investigations >500 messages
- Ne PAS utiliser `full` sans smart truncation
- Ne PAS ignorer les metadonnees (timestamp, workspace, mode)
- Combiner `codebase_search` (concept) avec `search_files` (exact) pour meilleure couverture
- Toujours passer `workspace` explicitement a `codebase_search`

---

**Reference :** `.roo/README.md`
