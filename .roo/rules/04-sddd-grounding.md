# Regles SDDD - Grounding Conversationnel (Roo)

## Methodologie Triple Grounding

La methodologie **SDDD (Semantic-Driven Development Documentation)** repose sur trois types de grounding :

1. **Grounding Semantique** - Recherche dans la base de connaissances
2. **Grounding Conversationnel** - Analyse de l'historique des conversations ✨ **CES REGLES**
3. **Grounding Technique** - Lecture du code source

## Outils de Grounding Conversationnel (MCP roo-state-manager)

### 1. task_browse - Navigation dans l'arbre des taches

**Usage :** Explorer la hierarchie des conversations et identifier les taches pertinentes.

```xml
<!-- Voir l'arbre complet d'une conversation -->
<use_mcp_tool>
<server_name>roo-state-manager</server_name>
<tool_name>task_browse</tool_name>
<arguments>{
  "action": "tree",
  "conversation_id": "5d775623-...",
  "output_format": "ascii-tree",
  "show_metadata": true
}</arguments>
</use_mcp_tool>

<!-- Identifier la tache courante -->
<use_mcp_tool>
<server_name>roo-state-manager</server_name>
<tool_name>task_browse</tool_name>
<arguments>{
  "action": "current"
}</arguments>
</use_mcp_tool>
```

**Quand utiliser :**
- Au debut d'une investigation pour comprendre le contexte conversationnel
- Pour identifier les taches parent/enfant liees a un probleme
- Pour naviguer dans une hierarchie de sous-taches

**Metadonnees fournies :**
- Nombre de messages, taille totale (KB)
- Mode de conversation, workspace
- Derniere activite (timestamp)

---

### 2. view_conversation_tree - Squelette d'une conversation

**Usage :** Obtenir une vue condensee d'une conversation pour analyse rapide.

```xml
<!-- Mode skeleton avec smart truncation (RECOMMANDE) -->
<use_mcp_tool>
<server_name>roo-state-manager</server_name>
<tool_name>view_conversation_tree</tool_name>
<arguments>{
  "task_id": "5d775623-...",
  "detail_level": "skeleton",
  "smart_truncation": true,
  "max_output_length": 15000
}</arguments>
</use_mcp_tool>

<!-- Mode summary pour plus de details -->
<use_mcp_tool>
<server_name>roo-state-manager</server_name>
<tool_name>view_conversation_tree</tool_name>
<arguments>{
  "task_id": "5d775623-...",
  "detail_level": "summary",
  "smart_truncation": true,
  "max_output_length": 30000
}</arguments>
</use_mcp_tool>
```

**Modes detail_level :**
- `skeleton` : Squelette minimal (messages sans contenu detaille)
- `summary` : Resume des messages cles
- `full` : Contenu complet (attention au volume)

**Smart Truncation (NOUVEAU) :**
- Compression intelligente avec gradient exponentiel
- Preserve les extremes (debut/fin), tronque le centre
- Taux de compression typique : 40-60%
- **Toujours activer** pour conversations >15K chars

**Quand utiliser :**
- Pour comprendre le deroulement d'une conversation passee
- Pour identifier les etapes cles d'une investigation
- Pour analyser les patterns d'interaction User ↔ Assistant

---

### 3. roosync_summarize - Generation de resumes

**Usage :** Generer des resumes structures de conversations pour documentation.

```xml
<!-- Mode trace (statistiques + structure) -->
<use_mcp_tool>
<server_name>roo-state-manager</server_name>
<tool_name>roosync_summarize</tool_name>
<arguments>{
  "type": "trace",
  "taskId": "5d775623-...",
  "outputFormat": "markdown",
  "detailLevel": "Summary"
}</arguments>
</use_mcp_tool>

<!-- Mode cluster (pour grappes de taches) -->
<use_mcp_tool>
<server_name>roo-state-manager</server_name>
<tool_name>roosync_summarize</tool_name>
<arguments>{
  "type": "cluster",
  "taskId": "root-task-id",
  "clusterMode": "aggregated"
}</arguments>
</use_mcp_tool>
```

**Modes disponibles :**
- `trace` : Resume simple avec statistiques (ratio compression, breakdown User/Assistant/Tools)
- `cluster` : Analyse de grappe de taches parent-enfant
- `synthesis` : ⚠️ Synthese LLM (bug connu, ne pas utiliser pour l'instant)

**Statistiques fournies :**
- Total sections, messages User/Assistant/Tools
- Taille totale, ratio de compression
- Breakdown en % (ex: 2.5% User, 20.5% Assistant, 77% Tools)

**Quand utiliser :**
- Pour documenter une investigation complexe
- Pour comprendre la repartition User/Assistant/Tools
- Pour identifier les conversations verboses (>1 MB)

---

## Workflow SDDD Recommande

### Phase 1 : Identification (Grounding Semantique)

1. Utiliser `roosync_search` (semantique) pour trouver les conversations pertinentes
2. Lire la documentation existante (docs/, CLAUDE.md)

### Phase 2 : Exploration (Grounding Conversationnel) ✨

1. **task_browse** → Identifier la conversation cible
2. **view_conversation_tree** (skeleton + smart truncation) → Comprendre la structure
3. **roosync_summarize** (trace) → Analyser les statistiques

### Phase 3 : Validation (Grounding Technique)

1. Lire le code source (read_file, search_files)
2. Verifier les tests unitaires
3. Valider la faisabilite technique

---

## Bonnes Pratiques

### ✅ A FAIRE

- **Toujours activer smart_truncation** pour conversations >10K chars
- Commencer par `task_browse` pour avoir le contexte global
- Utiliser `skeleton` en premier, puis `summary` si besoin de details
- Generer des resumes `trace` pour les investigations >500 messages

### ❌ A EVITER

- Ne PAS utiliser `detail_level: full` sans smart truncation (risque overflow)
- Ne PAS utiliser `roosync_summarize` mode `synthesis` (bug connu)
- Ne PAS ignorer les metadonnees (timestamp, workspace, mode)
- Ne PAS sauter le grounding conversationnel pour des taches complexes

---

## Exemples Concrets

### Investigation d'un Bug

```xml
<!-- 1. Trouver les conversations liees -->
<use_mcp_tool>
<server_name>roo-state-manager</server_name>
<tool_name>roosync_search</tool_name>
<arguments>{
  "action": "semantic",
  "search_query": "bug authentification"
}</arguments>
</use_mcp_tool>

<!-- 2. Explorer la conversation identifiee -->
<use_mcp_tool>
<server_name>roo-state-manager</server_name>
<tool_name>task_browse</tool_name>
<arguments>{
  "action": "tree",
  "conversation_id": "abc123..."
}</arguments>
</use_mcp_tool>

<!-- 3. Analyser le squelette -->
<use_mcp_tool>
<server_name>roo-state-manager</server_name>
<tool_name>view_conversation_tree</tool_name>
<arguments>{
  "task_id": "abc123...",
  "smart_truncation": true,
  "max_output_length": 15000
}</arguments>
</use_mcp_tool>

<!-- 4. Lire le code identifie dans la conversation -->
<read_file>
<path>src/auth/login.ts</path>
</read_file>
```

### Documentation d'une Feature

```xml
<!-- 1. Generer le resume de l'implementation -->
<use_mcp_tool>
<server_name>roo-state-manager</server_name>
<tool_name>roosync_summarize</tool_name>
<arguments>{
  "type": "trace",
  "taskId": "xyz789..."
}</arguments>
</use_mcp_tool>

<!-- 2. Extraire les statistiques pour la doc -->
<!-- → Copier le breakdown User/Assistant/Tools dans CHANGELOG.md -->

<!-- 3. Lire le code final -->
<search_files>
<path>src/</path>
<regex>export.*Feature</regex>
</search_files>
```

---

**Reference :** `.roo/README.md`
**Derniere mise a jour :** 2026-02-12
