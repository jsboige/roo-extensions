# Regles SDDD - Grounding Conversationnel (Roo)

**Version:** 2.1.0 (2026-02-23)

## Triple Grounding

**SDDD (Semantic Documentation Driven Development)** : 3 types de grounding a croiser systematiquement.

1. **Semantique** - `roosync_search(action: "semantic")` + codebase_search (MCP roo-state-manager)
2. **Conversationnel** - `conversation_browser` (MCP roo-state-manager - CES REGLES)
3. **Technique** - search_files, read_file, execute_command (outils NATIFS Roo Code - code = verite)

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
- `synthesis` : Pipeline LLM (OpenAI gpt-4o-mini) avec enrichissement algorithmique. Nécessite `OPENAI_API_KEY` dans .env. Réimplémenté #767.

---

## Recommandations conversation_browser(summarize) - CRITIQUE (#881)

**✅ FIX #881 APPLIQUÉ :** `detailLevel: "NoTools"` maintenant alias vers `Compact` qui résume les résultats d'outils.

**Ancien comportement (pré-fix) :** `NoTools` gardait tous les résultats complets → explosion 309 KB+ pour 23 messages.
**Nouveau comportement (post-fix) :** `NoTools` → `CompactReportingStrategy` qui résume (nom + statut + taille, pas contenu).

**Utilisation recommandée :**
```xml
<use_mcp_tool>
<server_name>roo-state-manager</server_name>
<tool_name>conversation_browser</tool_name>
<arguments>{"action": "summarize", "summarize_type": "trace", "detailLevel": "Summary", "truncationChars": 10000, "taskId": "abc123..."}</arguments>
</use_mcp_tool>
```

### Niveaux `detailLevel`

| Niveau | Contenu | Cas d'usage |
|--------|---------|------------|
| **`Full`** | Tout inclus | ❌ JAMAIS (explosion) |
| **`NoTools`** | ✅ FIXÉ - Alias vers Compact (résumé outils) | ✅ Maintenant OK |
| **`Compact`** | Messages + outils résumés (nom + statut) | ✅ Recommandé (#881) |
| **`NoToolParams`** | Ancien NoTools (params masqués, résultats complets) | ⚠️ Pour debug |
| **`NoResults`** | Messages + params (sans résultats) | ✅ Compact |
| **`Messages`** | Messages seulement | ✅ Très compact |
| **`Summary`** | Vue condensée | ✅ Recommandé |
| **`UserOnly`** | Messages utilisateur seulement | ✅ Plus compact |

**Règle :** TOUJOURS définir `truncationChars` quand `summarize_type != "trace"`.
`summarize_type: "trace"` génère stats lisibles (messages par type, taille, breakdown) — utiliser pour rapports métriques.

---

## Filtres Avances roosync_search (#636)

**Disponibles avec `action: "semantic"` :**

```xml
<!-- Frictions recentes : messages utilisateurs avec erreurs (ideal meta-analyse) -->
<use_mcp_tool>
<server_name>roo-state-manager</server_name>
<tool_name>roosync_search</tool_name>
<arguments>{"action": "semantic", "search_query": "probleme erreur echec impossible bloque", "has_errors": true, "start_date": "YYYY-MM-DD", "max_results": 10}</arguments>
</use_mcp_tool>

<!-- Historique d'un outil specifique -->
<use_mcp_tool>
<server_name>roo-state-manager</server_name>
<tool_name>roosync_search</tool_name>
<arguments>{"action": "semantic", "search_query": "write_to_file resultat", "tool_name": "write_to_file", "max_results": 5}</arguments>
</use_mcp_tool>

<!-- Messages utilisateur uniquement (sans resultats d'outils, plus compact) -->
<use_mcp_tool>
<server_name>roo-state-manager</server_name>
<tool_name>roosync_search</tool_name>
<arguments>{"action": "semantic", "search_query": "...", "role": "user", "exclude_tool_results": true}</arguments>
</use_mcp_tool>

<!-- Filtrer par source (Roo ou Claude Code) -->
<use_mcp_tool>
<server_name>roo-state-manager</server_name>
<tool_name>roosync_search</tool_name>
<arguments>{"action": "semantic", "search_query": "escalade", "source": "roo"}</arguments>
</use_mcp_tool>

<!-- Filtrer par modele et periode temporelle -->
<use_mcp_tool>
<server_name>roo-state-manager</server_name>
<tool_name>roosync_search</tool_name>
<arguments>{"action": "semantic", "search_query": "...", "model": "opus", "start_date": "2026-03-01", "end_date": "2026-03-17"}</arguments>
</use_mcp_tool>

<!-- Deep dive dans une conversation specifique -->
<use_mcp_tool>
<server_name>roo-state-manager</server_name>
<tool_name>roosync_search</tool_name>
<arguments>{"action": "semantic", "search_query": "...", "conversation_id": "TASK_ID"}</arguments>
</use_mcp_tool>
```

### Patterns de Requete Courants (#637)

| Pattern | Parametres cles | Usage |
|---------|----------------|-------|
| **Friction recente** | `has_errors:true + start_date:{hier}` | Meta-analyst quotidien |
| **Historique outil** | `tool_name:"write_to_file"` | Diagnostic boucle recurrente |
| **Messages purs** | `exclude_tool_results:true + role:user` | Analyse squelette conversation |
| **Sessions Claude** | `source:"claude-code"` | Recherche dans sessions Claude uniquement |
| **Sessions Roo** | `source:"roo"` | Recherche dans taches Roo uniquement |
| **Par modele** | `model:"opus"` | Sessions opus uniquement |
| **Fenetre temporelle** | `start_date + end_date` | Analyse tendance sur periode |
| **Dans tache** | `conversation_id:"{ID}"` | Fouiller une tache specifique |

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

## Recherche Semantique Multi-Pass (codebase_search - MCP)

Les fichiers sont indexes par chunks de ~1000 chars (tree-sitter). Une seule requete large est souvent insuffisante.

**Limitations connues :**
- Les fichiers sont decoupes en chunks de ~1000 chars (MAX_BLOCK_CHARS, non configurable)
- Pas de chevauchement entre chunks → les concepts qui traversent plusieurs fonctions sont fragmentes
- Les requetes en francais performent mal (le code et les embeddings sont en anglais)
- Scores typiques : 0.60-0.80 pour des resultats pertinents

### Protocole en 4 passes

1. **Pass 1 - Requete large** (sans directory_prefix) : identifier le module/repertoire
   ```xml
   <use_mcp_tool>
   <server_name>roo-state-manager</server_name>
   <tool_name>codebase_search</tool_name>
   <arguments>{"query": "message sending inter-machine communication", "workspace": "d:\\roo-extensions"}</arguments>
   </use_mcp_tool>
   ```
   **But :** identifier le repertoire/module pertinent. Utiliser des termes generiques en anglais.
   **Analyse :** Analyser les `file_path` des resultats pour identifier les prefixes de repertoire communs.

2. **Pass 2 - Zoom** (avec directory_prefix + vocabulaire code) : cibler le fichier
   ```xml
   <use_mcp_tool>
   <server_name>roo-state-manager</server_name>
   <tool_name>codebase_search</tool_name>
   <arguments>{"query": "format result success message sent priority timestamp", "workspace": "d:\\roo-extensions", "directory_prefix": "src/tools/roosync"}</arguments>
   </use_mcp_tool>
   ```
   **But :** cibler le module identifie en Pass 1 avec du vocabulaire specifique au code (noms de fonctions, variables, types).

3. **Pass 3 - Grep confirmation** : verite technique avec search_files exact
   ```xml
   <use_mcp_tool>
   <server_name>roo-state-manager</server_name>
   <tool_name>search_files</tool_name>
   <arguments>{"pattern": "function handleSendMessage", "path": "mcps/internal/servers/roo-state-manager/src"}</arguments>
   </use_mcp_tool>
   ```
   **But :** confirmer et completer avec une recherche exacte.

4. **Pass 4 - Variante** : reformuler si Pass 2 insuffisante
   ```xml
   <use_mcp_tool>
   <server_name>roo-state-manager</server_name>
   <tool_name>codebase_search</tool_name>
   <arguments>{"query": "sendMessage reply amend message manager", "workspace": "d:\\roo-extensions", "directory_prefix": "src/tools/roosync"}</arguments>
   </use_mcp_tool>
   ```
   **But :** reformuler avec des synonymes ou des noms de fonctions/classes decouverts en Pass 1-3.

### Quand utiliser chaque combinaison

| Situation | Approche recommandee |
|-----------|---------------------|
| Fichier/fonction connus | search_files direct (pas besoin de semantique) |
| Concept connu, localisation inconnue | Pass 1 → Pass 2 |
| Exploration d'un domaine | Pass 1 seule (analyser les resultats) |
| Fichier introuvable apres Pass 2 | Pass 3 (search_files) puis Pass 4 (variante) |
| Validation post-implementation | Pass 1 avec le concept implemente |

### Conseils pour les requetes

- **Toujours en anglais** : les embeddings sont entraines sur du code anglophone
- **Vocabulaire du code > langage naturel** : `"heartbeat machine registration alive"` > `"how to register a machine heartbeat"`
- **Noms concrets** : inclure noms de fonctions, types, variables quand connus
- **Pas trop long** : 5-10 mots cles, pas des phrases completes
- **`directory_prefix` divise par ~10 l'espace de recherche** : toujours l'utiliser en Pass 2

---

## Workflow SDDD

1. **Semantique** : `roosync_search` + `codebase_search` (multi-pass si besoin) + docs existantes
2. **Conversationnel** : `conversation_browser(list)` → obtenir IDs → `conversation_browser(view, skeleton)` → `conversation_browser(summarize, trace)` si besoin
3. **Technique** : read_file, search_files, tests unitaires

**IMPORTANT :** L'etape 2 COMMENCE par `list`. Sans IDs, les appels suivants sont impossibles.

**IMPORTANT (etape 2) :** `list` est le PREMIER appel obligatoire du grounding conversationnel. Sans lui, les IDs de taches sont inconnus et les appels `view`/`tree`/`summarize` sont impossibles. `current` seul est insuffisant (retourne la plus ancienne tache ouverte, pas forcement la plus pertinente).

**Combinaison semantique + technique :** Les Passes 1-2 (codebase_search) identifient les zones pertinentes par concept. La Pass 3 (search_files) confirme et complete avec precision. Ne jamais se fier uniquement a l'un ou l'autre.

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

---

## Reference Croisee - SDDD RooSync

**Ce document** (`.roo/rules/04-sddd-grounding.md`) est le **protocole opérationnel Roo** pour le triple grounding SDDD. Il couvre les outils spécifiques à Roo :
- `conversation_browser` (outil unifie)
- `bookend pattern` (début et fin de tâche)
- `protocole multi-pass` pour `codebase_search`
- `filtres avances` pour `roosync_search` (#636)

**Pour la méthodologie SDDD au niveau RooSync** (gh CLI, orchestrator obligations, project workflow), voir :
- [docs/roosync/PROTOCOLE_SDDD.md](../../docs/roosync/PROTOCOLE_SDDD.md) (v2.7.0)

**Version Claude Code** : [`.claude/rules/sddd-conversational-grounding.md`](../../.claude/rules/sddd-conversational-grounding.md) — protocole opérationnel Claude Code avec les memes outils.

**Les deux documents sont complementaires** :
- **PROTOCOLE_SDDD.md** : Méthodologie système RooSync (tous agents, gh CLI, workflow projet)
- **Ce fichier** : Protocole opérationnel Roo (`conversation_browser`, `bookend`, multi-pass, filtres avances)

---

**Derniere mise a jour :** 2026-03-30 (enrichissement filtres #636 + recommandations #881)
