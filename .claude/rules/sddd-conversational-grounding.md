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

**Actions de base :**

```
roosync_search(action: "semantic", search_query: "sujet conceptuel")  # Par concept (Qdrant)
roosync_search(action: "text", search_query: "mot exact")             # Par texte (cache)
roosync_search(action: "diagnose")                                     # Diagnostic de l'index
```

La recherche semantique utilise Qdrant (index des conversations Roo). La recherche textuelle scanne le cache directement.

**Filtres avances (#636) — disponibles avec `action: "semantic"` :**

```
# Frictions recentes : messages utilisateurs avec erreurs (ideal meta-analyse)
roosync_search(
  action: "semantic",
  search_query: "probleme erreur echec impossible bloque",
  has_errors: true,
  start_date: "YYYY-MM-DD",
  max_results: 10
)

# Historique d'un outil specifique
roosync_search(
  action: "semantic",
  search_query: "write_to_file resultat",
  tool_name: "write_to_file",
  max_results: 5
)

# Messages utilisateur uniquement (sans resultats d'outils, plus compact)
roosync_search(
  action: "semantic",
  search_query: "...",
  role: "user",
  exclude_tool_results: true
)

# Filtrer par source (Roo ou Claude Code)
roosync_search(action: "semantic", search_query: "escalade", source: "roo")
roosync_search(action: "semantic", search_query: "escalade", source: "claude-code")

# Filtrer par modele et periode temporelle
roosync_search(
  action: "semantic",
  search_query: "...",
  model: "opus",
  start_date: "2026-03-01",
  end_date: "2026-03-17"
)

# Deep dive dans une conversation specifique
roosync_search(action: "semantic", search_query: "...", conversation_id: "{TASK_ID}")
```

**Patterns de requete courants (#637) :**

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
| **`list`** | **POINT D'ENTREE OBLIGATOIRE** - Lister les taches recentes pour obtenir les IDs | `workspace`, `limit`, `contentPattern` |
| `tree` | Arbre des taches Roo | `conversation_id`, `output_format: "ascii-tree"` |
| `current` | Tache active | `workspace: "d:\\roo-extensions"` |
| `view` | Squelette conversation | `task_id`, `smart_truncation: true`, `max_output_length: 15000` |
| `summarize` | Resume/stats | `type: "trace"`, `taskId` |

### REGLE CRITIQUE : `list` comme point d'entree (OBLIGATOIRE)

**Sans IDs, tu es aveugle.** Les taches Roo ont des identifiants uniques. Les actions `tree`, `view`, et `summarize` EXIGENT un `task_id` ou `conversation_id`. Sans appel prealable a `list`, tu n'as aucun moyen fiable d'obtenir ces IDs.

**TOUJOURS commencer par :**
```
conversation_browser(action: "list", workspace: "d:\\roo-extensions", limit: 20)
```

**Pour chercher des taches specifiques :**
```
conversation_browser(action: "list", contentPattern: "write_to_file", limit: 30)
```

**Anti-pattern a ne JAMAIS reproduire :**
- Deviner les IDs de taches
- Utiliser `current` comme seul point d'entree (retourne la plus ancienne tache ouverte, pas la plus recente)
- Aller directement a `view` ou `tree` sans avoir liste au prealable

**TOUJOURS activer `smart_truncation: true`** pour conversations >10K chars.

**Modes `view` detail_level :**
- `skeleton` : Minimal (par defaut, recommande)
- `summary` : Messages cles
- `full` : Complet (risque overflow sans smart truncation)

**Modes `summarize` :**
- `trace` : Stats (compression, breakdown User/Assistant/Tools)
- `cluster` : Grappes parent-enfant
- `synthesis` : **BUG CONNU** - ne pas utiliser

## Recommandations conversation_browser(summarize) - CRITIQUE

**⚠️ PROBLÈME CONNU :** L'action `summarize` avec `detailLevel: "NoTools"` génère **explosion de contenu** (309 KB+ pour 23 messages).

### Cause racine

1. **`NoTools` est mal nommé** : Il masque SEULEMENT les paramètres d'appels d'outils, mais **garde TOUS les résultats d'outils complets**.
2. **`truncationChars` défaut = 0** : Pas de limite de caractères par défaut.

### Résultat réel

| Paramètres | Contenu | Taille |
|------------|---------|--------|
| `NoTools` sans truncation | ❌ EXPLOSION | ~300 KB (309 569 chars pour 23 messages) |
| `Summary` + `truncationChars: 10000` | ✅ COMPACT | ~3 KB (utilisable) |

### Recommandation STRICTE - Pour résumés compacts

**Toujours utiliser cette combinaison :**

```typescript
conversation_browser(
  action: "summarize",
  summarize_type: "trace",      // "trace" pour statistiques
  detailLevel: "Summary",         // PAS "NoTools" (trompeur)
  truncationChars: 10000,         // OBLIGATOIRE - limite chars
  taskId: "..."                   // ou taskIds pour clusters
)
```

### Niveaux `detailLevel` réels

| Niveau | Contenu | Cas d'usage |
|--------|---------|------------|
| **`Full`** | Tout inclus | ❌ JAMAIS (explosion, massif) |
| **`NoTools`** | ❌ Trompeur (masque params, garde résultats) | ❌ À ÉVITER absolument |
| **`NoResults`** | Messages + params (sans résultats) | ✅ Compact, à tester |
| **`Messages`** | Messages seulement | ✅ Très compact |
| **`Summary`** | Vue condensée | ✅ Recommandé |
| **`UserOnly`** | Messages utilisateur seulement | ✅ Plus compact encore |

### Règle d'or

**TOUJOURS définir `truncationChars`** quand `summarize_type != "trace"`.

```typescript
// BON - Limité à 10000 chars
conversation_browser(action: "summarize", detailLevel: "Summary", truncationChars: 10000)

// MAUVAIS - Pas de limite, risque explosion
conversation_browser(action: "summarize", detailLevel: "Summary")

// MAUVAIS - Trompeur, masque seulement params
conversation_browser(action: "summarize", detailLevel: "NoTools")
```

### Quand utiliser `trace`

**`summarize_type: "trace"` génère automatiquement des stats lisibles :**
- Nombre de messages par type (User/Assistant/Tool)
- Taille compression avant/après
- Breakdown par catégorie

⇒ Utiliser `trace` pour les rapports métriques, pas pour le contenu détaillé.

---

## Workflow SDDD Complet

```
1. BOOKEND DEBUT : codebase_search multi-pass (Pass 1 large → Pass 2 zoom) + roosync_search(semantic)
2. CONVERSATIONNEL : conversation_browser(list) → identifier IDs → conversation_browser(view, skeleton)
3. TECHNIQUE : Read/Grep le code source (Pass 3 confirmation), tests unitaires
4. TRAVAIL : Implementer/corriger/documenter
5. BOOKEND FIN : codebase_search(query: "validation tache") → confirmer indexation
```

**IMPORTANT (etape 2) :** `list` est le PREMIER appel obligatoire du grounding conversationnel. Sans lui, les IDs de taches sont inconnus et les appels `view`/`tree`/`summarize` sont impossibles. `current` seul est insuffisant (retourne la plus ancienne tache ouverte, pas forcement la plus pertinente).

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

- **Commencer par `list`** pour obtenir les IDs des taches recentes (OBLIGATOIRE)
- Utiliser `tree` pour le contexte global une fois les IDs connus
- Utiliser `skeleton` en premier, `summary` si besoin
- Generer des `trace` pour investigations >500 messages
- Ne PAS utiliser `full` sans smart truncation
- Ne PAS ignorer les metadonnees (timestamp, workspace, mode)
- Le bookend FIN est aussi important que le bookend DEBUT

---

## Recommandations conversation_browser (CRITIQUE #608)

### Niveaux de detailLevel

| Niveau | Comportement | Quand l'utiliser |
|--------|-------------|------------------|
| `Full` | Tout inclus (massif) | ❌ Jamais - explosion de contenu |
| `NoTools` | Trompeur! Masque SEULEMENT les paramètres, garde tous les résultats | ❌ À PROSCRIRE |
| `NoResults` | Masque les résultats d'outils | Pour vérifier le flow |
| `Messages` | Messages seuls | Pour analyse structurelle |
| `Summary` | Compact et utilisable | ✅ RECOMMANDÉ |
| `UserOnly` | Plus compact encore | Pour audit rapide |

### ⚠️ Attention: `NoTools` est mal nommé

Le niveau devrait s'appeler `NoToolParams` car il **masque SEULEMENT les paramètres** d'appels d'outils mais **garde TOUS les résultats d'outils complets**.

**Exemple réel (issue #608) :**
- `NoTools` sans troncature → **309 569 caractères** pour 23 messages
- `Summary` + `truncationChars: 10000` → **~2 900 caractères**

### Recommandation pour les résumés compacts

```typescript
action: "summarize"
summarize_type: "trace"  // ou "cluster"
detailLevel: "Summary"   // PAS "NoTools" (trompeur)
truncationChars: 10000   // TOUJOURS définir une limite
smart_truncation: true   // Activer pour les conversations >10K chars
```

### À éviter absolument

- `detailLevel: "NoTools"` sans comprendre ce qu'il fait réellement
- Omettre `truncationChars` pour les conversations >50 messages
- Utiliser `Full` sans une raison très spécifique

---

## Référence Croisée - SDDD RooSync

**Ce document** (`.claude/rules/sddd-conversational-grounding.md`) est le **protocole opérationnel Claude Code** pour le triple grounding SDDD. Il couvre les outils spécifiques à Claude Code :
- `conversation_browser` (outil unifié)
- `bookend pattern` (début et fin de tâche)
- `protocole multi-pass` pour `codebase_search`

**Pour la méthodologie SDDD au niveau RooSync** (gh CLI, orchestrator obligations, project workflow), voir :
- [docs/roosync/PROTOCOLE_SDDD.md](../../docs/roosync/PROTOCOLE_SDDD.md) (v2.7.0)

**Les deux documents sont complémentaires** :
- **PROTOCOLE_SDDD.md** : Méthodologie système RooSync (tous agents, gh CLI, workflow projet)
- **Ce fichier** : Protocole opérationnel Claude Code (`conversation_browser`, `bookend`, multi-pass)

---

**Reference :** [.claude/CLAUDE_CODE_GUIDE.md](.claude/CLAUDE_CODE_GUIDE.md)
