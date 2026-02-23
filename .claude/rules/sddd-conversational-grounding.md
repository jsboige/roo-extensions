# Regles SDDD - Protocole de Triple Grounding

**Version:** 2.1.0 (2026-02-23)

## Principe

**SDDD (Semantic Documentation Driven Development)** : Tout travail significatif doit croiser 3 types de grounding pour fiabiliser les taches et empecher la doc de s'eparpiller ou devenir obsolete.

1. **Semantique** - `codebase_search` + `roosync_search(action: "semantic")` → Trouver par concept
2. **Conversationnel** - `conversation_browser` + traces Roo → Historique de travail
3. **Technique** - Read, Grep, Glob, Bash, Git → Code source = verite

**Regle absolue :** Ne jamais se contenter d'une seule source.

---

## Pattern Bookend (OBLIGATOIRE)

**`codebase_search` doit etre utilise en DEBUT et en FIN de chaque tache significative.**

### En debut de tache (Contexte)

Avant de commencer, chercher ce qui existe deja :

```
codebase_search(query: "description conceptuelle de la tache", workspace: "d:\\roo-extensions")
roosync_search(action: "semantic", search_query: "sujet de la tache")
```

**But :** Eviter de refaire un travail deja fait, comprendre le contexte existant, trouver les fichiers pertinents.

### En fin de tache (Validation)

Apres avoir termine, verifier que le travail est visible :

```
codebase_search(query: "concept implemente/corrige", workspace: "d:\\roo-extensions")
```

**But :** Confirmer que le code/la doc est indexe et retrouvable. Si le resultat ne remonte pas, c'est que l'indexation n'a pas eu lieu ou que la documentation est insuffisante.

### Quand appliquer le bookend

| Type de tache | Bookend obligatoire | Raison |
|---------------|-------------------|--------|
| Feature/fix dans le code | OUI | Contexte + validation |
| Investigation de bug | OUI (debut seulement) | Peut trouver des traces passees |
| Mise a jour de doc | OUI | Eviter doublons, verifier couverture |
| Simple commit/push | NON | Tache mecanique |
| Reponse a question | NON | Pas de modification |

---

## Outils Semantiques

### codebase_search (recherche dans le code)

Recherche par **concept** dans le workspace indexe par Qdrant (pas par texte exact).

```
codebase_search(query: "rate limiting for embeddings", workspace: "d:\\roo-extensions")
```

**TOUJOURS passer `workspace` explicitement.** L'auto-detection pointe vers le repertoire du serveur MCP.

**Prerequis :** Variables `.env` configurees (EMBEDDING_MODEL, EMBEDDING_API_BASE_URL, etc.)

### roosync_search (recherche dans les taches Roo)

```
roosync_search(action: "semantic", search_query: "sujet conceptuel")  # Par concept (Qdrant)
roosync_search(action: "text", search_query: "mot exact")             # Par texte (cache)
```

La recherche semantique utilise Qdrant (index des conversations Roo). La recherche textuelle scanne le cache directement.

---

## Protocole Multi-Pass pour codebase_search (RECOMMANDE)

`codebase_search` utilise des embeddings vectoriels sur des chunks de ~1000 caracteres (tree-sitter AST).
Une seule requete large ne suffit souvent pas a localiser un fichier precis.

**Limitations connues :**
- Les fichiers sont decoupes en chunks de ~1000 chars (MAX_BLOCK_CHARS, non configurable)
- Pas de chevauchement entre chunks → les concepts qui traversent plusieurs fonctions sont fragmentes
- Les requetes en francais performent mal (le code et les embeddings sont en anglais)
- Scores typiques : 0.60-0.80 pour des resultats pertinents

### Protocole en 4 passes

**Pass 1 - Requete conceptuelle large** (sans directory_prefix)

But : identifier le repertoire/module pertinent. Utiliser des termes generiques en anglais.

```
codebase_search(query: "message sending inter-machine communication", workspace: "d:\\roo-extensions")
```

Analyser les `file_path` des resultats pour identifier les prefixes de repertoire communs.

**Pass 2 - Zoom avec directory_prefix** (vocabulaire du code)

But : cibler le module identifie en Pass 1 avec du vocabulaire specifique au code (noms de fonctions, variables, types).

```
codebase_search(
  query: "format result success message sent priority timestamp",
  workspace: "d:\\roo-extensions",
  directory_prefix: "src/tools/roosync"
)
```

**Pass 3 - Grep de confirmation** (verite technique)

But : confirmer et completer avec une recherche exacte.

```
Grep(pattern: "function handleSendMessage", path: "mcps/internal/servers/roo-state-manager/src")
```

**Pass 4 - Variante vocabulaire** (si Pass 2 insuffisante)

Reformuler avec des synonymes ou des noms de fonctions/classes decouverts en Pass 1-3.

```
codebase_search(
  query: "sendMessage reply amend message manager",
  workspace: "d:\\roo-extensions",
  directory_prefix: "src/tools/roosync"
)
```

### Quand utiliser chaque combinaison

| Situation | Approche recommandee |
|-----------|---------------------|
| Fichier/fonction connus | Grep direct (pas besoin de semantique) |
| Concept connu, localisation inconnue | Pass 1 → Pass 2 |
| Exploration d'un domaine | Pass 1 seule (analyser les resultats) |
| Fichier introuvable apres Pass 2 | Pass 3 (Grep) puis Pass 4 (variante) |
| Validation post-implementation | Pass 1 avec le concept implemente |

### Conseils pour les requetes

- **Toujours en anglais** : les embeddings sont entraines sur du code anglophone
- **Vocabulaire du code > langage naturel** : `"heartbeat machine registration alive"` > `"how to register a machine heartbeat"`
- **Noms concrets** : inclure noms de fonctions, types, variables quand connus
- **Pas trop long** : 5-10 mots cles, pas des phrases completes
- **`directory_prefix` divise par ~10 l'espace de recherche** : toujours l'utiliser en Pass 2

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

## Workflow SDDD Complet

```
1. BOOKEND DEBUT : codebase_search multi-pass (Pass 1 large → Pass 2 zoom) + roosync_search(semantic)
2. CONVERSATIONNEL : conversation_browser(current) → conversation_browser(view, skeleton)
3. TECHNIQUE : Read/Grep le code source (Pass 3 confirmation), tests unitaires
4. TRAVAIL : Implementer/corriger/documenter
5. BOOKEND FIN : codebase_search(query: "validation tache") → confirmer indexation
```

**Combinaison semantique + technique :** Les Passes 1-2 (codebase_search) identifient les zones pertinentes par concept. La Pass 3 (Grep) confirme et complete avec precision. Ne jamais se fier uniquement a l'un ou l'autre.

---

## Protocole de Friction (OBLIGATOIRE)

**Tout agent rencontrant une friction ou un probleme avec les outils SDDD doit le signaler au collectif.**

### Quand signaler

- Un outil SDDD ne fonctionne pas (codebase_search timeout, roosync_search vide, etc.)
- Le bookend debut ne retourne rien d'utile (index pas a jour, embeddings down)
- Un skill/workflow ne suit pas le protocole SDDD
- Une doc est introuvable malgre le triple grounding

### Comment signaler

```
roosync_send(
  action: "send",
  to: "all",
  subject: "[FRICTION] Description courte du probleme",
  body: "## Probleme\n[Description]\n\n## Contexte\n[Quelle tache, quel outil, quel resultat]\n\n## Impact\n[Ce qui est bloque ou degrade]\n\n## Suggestion\n[Amelioration proposee si applicable]",
  tags: ["friction", "sddd"]
)
```

### Traitement des frictions

1. Le collectif (toutes les machines) recoit le message
2. Les agents qui ont une experience similaire repondent
3. Le coordinateur (myia-ai-01) synthetise et decide l'amelioration
4. Si approuvee : modifier le skill/rule/tool concerne (incremental)

**Principe :** Les skills evoluent par friction reelle, pas par anticipation theorique.

---

## Bonnes Pratiques

- Commencer par `tree` pour le contexte global conversationnel
- Utiliser `skeleton` en premier, `summary` si besoin
- Generer des `trace` pour investigations >500 messages
- Ne PAS utiliser `full` sans smart truncation
- Ne PAS ignorer les metadonnees (timestamp, workspace, mode)
- Le bookend FIN est aussi important que le bookend DEBUT

---

**Reference :** [.claude/CLAUDE_CODE_GUIDE.md](.claude/CLAUDE_CODE_GUIDE.md)
