# Règles SDDD - Grounding Conversationnel (Claude Code)

## Méthodologie Triple Grounding

La méthodologie **SDDD (Semantic-Driven Development Documentation)** repose sur trois types de grounding :

1. **Grounding Sémantique** - Recherche dans la base de connaissances
2. **Grounding Conversationnel** - Analyse de l'historique des conversations ✨ **CES RÈGLES**
3. **Grounding Technique** - Lecture du code source

## Outils de Grounding Conversationnel

### 1. task_browse - Navigation dans l'arbre des tâches

**Usage :** Explorer la hiérarchie des conversations et identifier les tâches pertinentes.

```bash
# Voir l'arbre complet d'une conversation
mcp__roo-state-manager__task_browse(
  action: "tree",
  conversation_id: "5d775623-...",
  output_format: "ascii-tree",
  show_metadata: true
)

# Identifier la tâche courante
mcp__roo-state-manager__task_browse(
  action: "current"
)
```

**Quand utiliser :**
- Au début d'une investigation pour comprendre le contexte conversationnel
- Pour identifier les tâches parent/enfant liées à un problème
- Pour naviguer dans une hiérarchie de sous-tâches

**Métadonnées fournies :**
- Nombre de messages, taille totale (KB)
- Mode de conversation, workspace
- Dernière activité (timestamp)

---

### 2. view_conversation_tree - Squelette d'une conversation

**Usage :** Obtenir une vue condensée d'une conversation pour analyse rapide.

```bash
# Mode skeleton avec smart truncation (RECOMMANDÉ)
mcp__roo-state-manager__view_conversation_tree(
  task_id: "5d775623-...",
  detail_level: "skeleton",
  smart_truncation: true,
  max_output_length: 15000
)

# Mode summary pour plus de détails
mcp__roo-state-manager__view_conversation_tree(
  task_id: "5d775623-...",
  detail_level: "summary",
  smart_truncation: true,
  max_output_length: 30000
)
```

**Modes detail_level :**
- `skeleton` : Squelette minimal (messages sans contenu détaillé)
- `summary` : Résumé des messages clés
- `full` : Contenu complet (attention au volume)

**Smart Truncation (NOUVEAU) :**
- Compression intelligente avec gradient exponentiel
- Préserve les extrêmes (début/fin), tronque le centre
- Taux de compression typique : 40-60%
- **Toujours activer** pour conversations >15K chars

**Quand utiliser :**
- Pour comprendre le déroulement d'une conversation passée
- Pour identifier les étapes clés d'une investigation
- Pour analyser les patterns d'interaction User ↔ Assistant

---

### 3. roosync_summarize - Génération de résumés

**Usage :** Générer des résumés structurés de conversations pour documentation.

```bash
# Mode trace (statistiques + structure)
mcp__roo-state-manager__roosync_summarize(
  type: "trace",
  taskId: "5d775623-...",
  outputFormat: "markdown",
  detailLevel: "Summary"
)

# Mode cluster (pour grappes de tâches)
mcp__roo-state-manager__roosync_summarize(
  type: "cluster",
  taskId: "root-task-id",
  clusterMode: "aggregated"
)
```

**Modes disponibles :**
- `trace` : Résumé simple avec statistiques (ratio compression, breakdown User/Assistant/Tools)
- `cluster` : Analyse de grappe de tâches parent-enfant
- `synthesis` : ⚠️ Synthèse LLM (bug connu, ne pas utiliser pour l'instant)

**Statistiques fournies :**
- Total sections, messages User/Assistant/Tools
- Taille totale, ratio de compression
- Breakdown en % (ex: 2.5% User, 20.5% Assistant, 77% Tools)

**Quand utiliser :**
- Pour documenter une investigation complexe
- Pour comprendre la répartition User/Assistant/Tools
- Pour identifier les conversations verboses (>1 MB)

---

## Workflow SDDD Recommandé

### Phase 1 : Identification (Grounding Sémantique)

1. Utiliser `roosync_search` (sémantique) pour trouver les conversations pertinentes
2. Lire la documentation existante (docs/, CLAUDE.md)

### Phase 2 : Exploration (Grounding Conversationnel) ✨

1. **task_browse** → Identifier la conversation cible
2. **view_conversation_tree** (skeleton + smart truncation) → Comprendre la structure
3. **roosync_summarize** (trace) → Analyser les statistiques

### Phase 3 : Validation (Grounding Technique)

1. Lire le code source (Read, Grep, Glob)
2. Vérifier les tests unitaires
3. Valider la faisabilité technique

---

## Bonnes Pratiques

### ✅ À FAIRE

- **Toujours activer smart_truncation** pour conversations >10K chars
- Commencer par `task_browse` pour avoir le contexte global
- Utiliser `skeleton` en premier, puis `summary` si besoin de détails
- Générer des résumés `trace` pour les investigations >500 messages

### ❌ À ÉVITER

- Ne PAS utiliser `detail_level: full` sans smart truncation (risque overflow)
- Ne PAS utiliser `roosync_summarize` mode `synthesis` (bug connu)
- Ne PAS ignorer les métadonnées (timestamp, workspace, mode)
- Ne PAS sauter le grounding conversationnel pour des tâches complexes

---

## Exemples Concrets

### Investigation d'un Bug

```bash
# 1. Trouver les conversations liées
roosync_search(action: "semantic", search_query: "bug authentification")

# 2. Explorer la conversation identifiée
task_browse(action: "tree", conversation_id: "abc123...")

# 3. Analyser le squelette
view_conversation_tree(
  task_id: "abc123...",
  smart_truncation: true,
  max_output_length: 15000
)

# 4. Lire le code identifié dans la conversation
Read(file_path: "src/auth/login.ts")
```

### Documentation d'une Feature

```bash
# 1. Générer le résumé de l'implémentation
roosync_summarize(type: "trace", taskId: "xyz789...")

# 2. Extraire les statistiques pour la doc
# → Copier le breakdown User/Assistant/Tools dans CHANGELOG.md

# 3. Lire le code final
Grep(pattern: "export.*Feature", path: "src/")
```

---

**Référence :** [.claude/CLAUDE_CODE_GUIDE.md](.claude/CLAUDE_CODE_GUIDE.md)
**Dernière mise à jour :** 2026-02-12
