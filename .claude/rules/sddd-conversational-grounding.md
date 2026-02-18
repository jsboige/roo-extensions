# Regles SDDD - Grounding Conversationnel (Claude Code)

## Triple Grounding

**SDDD (Semantic Documentation Driven Development)** : 3 types de grounding a croiser systematiquement.

1. **Semantique** - `roosync_search(action: "semantic")` + Grep/Glob
2. **Conversationnel** - `conversation_browser` + traces Roo (CES REGLES)
3. **Technique** - Read, Grep, Bash, Git (code source = verite)

---

## Outils Conversationnels

### conversation_browser (outil unifie)

| Action | Usage | Parametres cles |
|--------|-------|----------------|
| `tree` | Arbre des taches Roo | `conversation_id`, `output_format: "ascii-tree"` |
| `current` | Tache active | `workspace: "d:\\roo-extensions"` |
| `view` | Squelette conversation | `task_id`, `smart_truncation: true`, `max_output_length: 15000` |
| `summarize` | Resume/stats | `type: "trace"`, `taskId` |

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
2. **Conversationnel** : `conversation_browser(tree)` → `conversation_browser(view, skeleton)` → `conversation_browser(summarize, trace)`
3. **Technique** : Read/Grep le code source, tests unitaires

**Regle :** Ne jamais se contenter d'une seule source.

---

## Bonnes Pratiques

- Commencer par `tree` pour le contexte global
- Utiliser `skeleton` en premier, `summary` si besoin
- Generer des `trace` pour investigations >500 messages
- Ne PAS utiliser `full` sans smart truncation
- Ne PAS ignorer les metadonnees (timestamp, workspace, mode)

---

**Reference :** [.claude/CLAUDE_CODE_GUIDE.md](.claude/CLAUDE_CODE_GUIDE.md)
