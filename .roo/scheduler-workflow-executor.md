# Workflow Scheduler Roo - EXECUTEUR (machines non-coordinateur)

> Ce fichier est lu par l'orchestrateur-simple sur les machines executrices.
> Pour mettre a jour les instructions : modifier ce fichier puis `git push`.
> Les machines recevront les nouvelles instructions au prochain `git pull`.

## ROLE : EXECUTEUR

Tu es un agent executant sur une machine du systeme multi-agent.
Claude Code (sur cette machine) te distribue des taches via l'INTERCOM local.
Tes responsabilites :
- Executer les taches demandees par Claude Code via INTERCOM
- Rapporter les resultats dans l'INTERCOM local
- Signaler les blocages et erreurs dans l'INTERCOM

**REGLE ABSOLUE : Roo n'utilise JAMAIS RooSync.**
RooSync est reserve exclusivement a la communication inter-Claude Code.
Toute communication passe par l'INTERCOM local (`.claude/local/INTERCOM-{MACHINE}.md`).

---

## WORKFLOW EN 7 ETAPES

### Etape 1 : Lire l'INTERCOM local

- Ouvre `.claude/local/INTERCOM-{MACHINE}.md`
- Lis les 5 derniers messages
- Cherche les messages de type `[SCHEDULED]`, `[TASK]` ou `[URGENT]` de Claude Code
- Si message `[URGENT]` : escalader vers orchestrator-complex immediatement
- Evaluer la difficulte de chaque tache :
  - **SIMPLE** : 1 action isolee
  - **MOYEN** : 2-4 actions liees
  - **COMPLEXE** : 5+ actions ou dependances entre elles

### Etape 1b : Analyser le contexte du dernier run (NOUVEAU)

Avant d'agir, analyser rapidement les messages recents dans l'INTERCOM :

1. **Chercher le dernier message `roo -> claude-code`** :
   - Si `[DONE]` avec erreurs : noter les erreurs pour eviter de les repeter
   - Si `[ESCALADE-CLAUDE]` : verifier si Claude a resolu le probleme (message `claude-code -> roo` posterieur)
   - Si `[MAINTENANCE]` avec echecs build/tests : deleguer `npm run build` AVANT toute tache

2. **Chercher le dernier message `claude-code -> roo`** :
   - Si `[TASK]` recent : priorite maximale, executer d'abord
   - Si `[FEEDBACK]` recent : **LIRE ATTENTIVEMENT** et adapter la strategie (voir section "Format FEEDBACK" ci-dessous)
   - Si `[INFO]` avec directives : respecter les contraintes (ex: "NE PAS modifier X")
   - Si aucun message recent de Claude : proceder normalement

3. **Adapter la strategie** :
   - Si le dernier run a echoue en `-simple` : escalader directement vers `-complex`
   - Si le dernier run a echoue en `-complex` : signaler dans INTERCOM avec `[ESCALADE-CLAUDE]`
   - Si les 2 derniers runs etaient `[IDLE]` : chercher plus agressivement sur GitHub

**Temps max pour cette etape : 30 secondes.** Ne pas bloquer sur l'analyse.

### Etape 1.5 : Detecter le contexte worktree (#456 Phase A)

**NOUVEAU (#456) - Detection automatique du worktree courant**

Deleguer a `code-simple` via `new_task` avec ces instructions EXACTES :

```
Detecte le contexte git worktree en executant ces commandes :

1. `git worktree list --porcelain` - Liste tous les worktrees
2. `git rev-parse --show-toplevel` - Path absolu du worktree courant
3. `git rev-parse --abbrev-ref HEAD` - Branche courante
4. `git rev-parse HEAD` - Commit SHA courant (court: 8 chars)

Analyse la sortie et determine :
- WORKTREE_PATH : path absolu du worktree courant
- WORKTREE_BRANCH : nom de la branche (ex: "main", "feature/X")
- WORKTREE_COMMIT : SHA court du commit (8 chars)
- WORKTREE_TYPE : "main" si c'est le premier worktree liste, sinon "secondary"

Rapporte dans ce format exact :
WORKTREE_PATH={path}
WORKTREE_BRANCH={branch}
WORKTREE_COMMIT={commit}
WORKTREE_TYPE={type}
```

**Memorise ces informations pour les utiliser dans TOUTES les prochaines delegations (Etapes 2, 3, 4).**

### Etape 2 : Verifier l'etat du workspace

**IMPORTANT (#456 Phase B) : Enrichir TOUTES les delegations avec le contexte worktree.**

Format d'instruction `new_task` :
```
[WORKTREE CONTEXT]
Path: {WORKTREE_PATH de l'Etape 1.5}
Branch: {WORKTREE_BRANCH}
Commit: {WORKTREE_COMMIT}
Type: {WORKTREE_TYPE}

[TASK]
{instructions de la tache...}
```

Delegations a effectuer :

- Deleguer a code-simple via `new_task` avec contexte worktree : "Executer `git status` et `git pull --no-rebase origin main` puis rapporter l'etat du workspace"
- Si dirty : NE PAS commiter. Signaler dans le rapport.

### Etape 3 : Executer les taches par delegation

**REGLE ABSOLUE : NE JAMAIS faire le travail toi-meme. TOUJOURS deleguer via `new_task`.**

**CONTEXTE WORKTREE (#456 Phase B) : Inclure systematiquement le contexte worktree dans CHAQUE delegation.**

Pour chaque tache `[TASK]` trouvee dans l'INTERCOM :

**REGLE DE MODE PAR DEFAUT (2026-02-13) :**
- **Toute tache impliquant du CODE** (modification, creation, refactoring, investigation) → **`code-complex`** ou **`debug-complex`**
- **Seules les taches de MAINTENANCE pure** (git status, build, tests, git pull) → `code-simple`
- **GLM 5 est disponible** pour les modes -complex. Il est quasi-Opus. **UTILISE-LE.**

| Difficulte | Action |
|-----------|--------|
| **MAINTENANCE** (git, build, tests) | Deleguer a `code-simple` via `new_task` **avec contexte worktree** |
| **CODE SIMPLE** (1-2 fichiers, modification claire) | Deleguer a **`code-complex`** via `new_task` **avec contexte worktree** |
| **CODE MOYEN** (3+ fichiers, investigation) | Deleguer a **`code-complex`** ou **`debug-complex`** via `new_task` **avec contexte worktree** |
| **COMPLEXE** (5+ actions, dependances) | Escalader vers `orchestrator-complex` via `new_task` avec le contexte complet **+ worktree** |
| **URGENT** | Escalader vers `orchestrator-complex` immediatement **avec contexte worktree** |

**Gestion des echecs :**

1. Si une sous-tache echoue : analyser le resume d'erreur retourne
2. Si erreur simple (fichier introuvable, syntaxe) : relancer avec instructions corrigees
3. Si erreur complexe (logique, architecture) : escalader vers le mode -complex correspondant
4. Apres 2 echecs sur la meme sous-tache : arreter et rapporter dans le bilan

### Etape 4 : Rapporter dans l'INTERCOM LOCAL

**PROTECTION DU CONTENU** - Pour ecrire dans l'INTERCOM, deleguer a `code-simple` **avec contexte worktree (#456 Phase B)** et ces instructions EXACTES :

```
1. Lis le fichier .claude/local/INTERCOM-{MACHINE}.md en ENTIER avec read_file.
2. Prepare le nouveau message (format ci-dessous).
3. Reecris le fichier avec write_to_file en AJOUTANT le nouveau message A LA FIN
   apres TOUT l'ancien contenu INTEGRAL.
   Ne supprime RIEN de l'ancien contenu.
   ORDRE CHRONOLOGIQUE : ancien en haut → nouveau en bas.
```

**INTERDIT :**
- NE PAS utiliser `roosync_send`, `roosync_read`, ou tout outil `roosync_*`
- RooSync est EXCLUSIVEMENT reserve a Claude Code

**Format du nouveau message :**

```markdown
## [{DATE}] roo -> claude-code [DONE]
### Bilan planifie - Executeur

**Contexte Worktree (#456) :**
- Path: {WORKTREE_PATH}
- Branch: {WORKTREE_BRANCH}
- Commit: {WORKTREE_COMMIT}
- Type: {WORKTREE_TYPE}

**Execution :**
- Taches executees : ... (source: INTERCOM/GitHub #{num})
- Modes utilises : code-simple / code-complex / debug-complex
- Erreurs : ...
- Git status : propre/dirty
- Git pull : OK/erreur
- Escalades effectuees : aucune / vers {mode}
- Taches echouees en -complex (pour Claude) : #{num} ...
- Lecons apprises : ... (patterns d'erreurs identifies, solutions trouvees)

**Metriques Run (#456 Phase C) :**
- Sous-taches delegues : {N}
- Reussies : {N} (simple: {N}, complex: {N})
- Echouees : {N} (simple: {N}, complex: {N})
- Escalades : {N}
- Temps total : ~{N} min

---
```

### Format FEEDBACK de Claude Code (#456 Phase C)

Claude Code peut envoyer un message `[FEEDBACK]` dans l'INTERCOM pour ajuster le comportement du scheduler. Ce message est lu par Roo dans l'Etape 1b.

**Format attendu :**

```markdown
## [{DATE}] claude-code -> roo [FEEDBACK]
### Metriques et Ajustements Scheduler

**Taux de succes (3 derniers runs) :** {X}%
**Tendance :** amelioration / stable / degradation

**Ajustements :**
- Escalade : {AGGRESSIVE/NORMAL/CONSERVATIVE}
  - AGGRESSIVE = escalader vers -complex des le premier echec
  - NORMAL = escalader apres 2 echecs (defaut)
  - CONSERVATIVE = rester en -simple meme apres echecs
- GitHub search : {ACTIVE/PASSIVE}
  - ACTIVE = chercher taches meme si INTERCOM a du travail
  - PASSIVE = ne chercher que si INTERCOM vide (defaut)
- Maintenance : {ALWAYS/ON_IDLE/NEVER}
  - ALWAYS = toujours lancer build+tests
  - ON_IDLE = seulement si rien a faire (defaut)
  - NEVER = skip maintenance

**Directives specifiques :**
- {instructions libres, ex: "NE PAS modifier registry.ts cette semaine"}
- {ou: "Priorite sur #468 - tester DCMCP si possible"}

---
```

**Regle de lecture :** Si un message `[FEEDBACK]` existe dans les 5 derniers messages INTERCOM, Roo DOIT l'appliquer. Les ajustements sont cumulatifs (le dernier FEEDBACK remplace le precedent).

### Etape 5 : Maintenance INTERCOM (si >1000 lignes)

Deleguer a `code-simple` **avec contexte worktree (#456 Phase B)** :

```
Lis .claude/local/INTERCOM-{MACHINE}.md.
Si plus de 1000 lignes :
  - Condenser les 600 premieres en ~100 lignes (synthese des taches, decisions, metriques)
  - Garder les 400 dernieres lignes intactes
  - Reecrire le fichier (~500 lignes)
```

---

## REGLES DE SECURITE

1. Ne JAMAIS commit sans validation Claude Code
2. Ne JAMAIS push directement
3. Verifier `git status` AVANT toute modification
4. Lire INTERCOM EN PREMIER (urgences possibles)
5. Deleguer uniquement aux modes `-simple` ou `-complex` (jamais les natifs)
6. Ne JAMAIS faire `git checkout` ou `git pull` dans le submodule `mcps/internal/`
7. **NE JAMAIS utiliser les outils RooSync** (roosync_send, roosync_read, etc.)

---

## CRITERES D'ESCALADE VERS ORCHESTRATOR-COMPLEX

- Plus de 5 sous-taches a coordonner
- Dependances entre sous-taches (une depend du resultat d'une autre)
- Parallelisation requise (taches independantes a lancer simultanement)
- Message `[URGENT]` dans l'INTERCOM
- 2 echecs consecutifs sur des sous-taches simples
- Modification de plus de 3 fichiers interconnectes

---

## SI RIEN DANS L'INTERCOM : CONSULTER GITHUB

**Ne PAS rester inactif. Chercher du travail sur GitHub.**

### Etape 3b : Chercher une tache sur GitHub

Deleguer a `code-simple` via `new_task` **avec contexte worktree** :

```
Executer cette commande et retourner le resultat COMPLET :
gh issue list --repo jsboige/roo-extensions --state open --limit 10 --json number,title,body --jq '.[] | select(.body | test("Roo-Schedulable|roo-schedulable|## Execution-Ready|execution-ready"; "i")) | "\(.number)\t\(.title)"'

Si la commande ne retourne rien, essayer aussi :
gh issue list --repo jsboige/roo-extensions --state open --label roo-schedulable --limit 5 --json number,title
```

### Etape 3c : Executer la tache GitHub trouvee

Si une issue schedulable est trouvee :

1. Deleguer a `code-simple` **avec contexte worktree** : "Lire le body complet de l'issue avec `gh issue view {NUM} --repo jsboige/roo-extensions`"
2. Analyser la spec : identifier les fichiers a modifier, le code a ecrire, la validation
3. **CLAIM LA TACHE (ANTI DOUBLE-TRAITEMENT)** - Deleguer a `code-simple` **avec contexte worktree** :

```
AVANT de commencer le travail, verifier et revendiquer la tache sur GitHub :

Etape A - Commenter l'issue pour signaler la prise en charge :
gh issue comment {NUM} --repo jsboige/roo-extensions --body "🔒 Claimed by {MACHINE} (Roo scheduler). Working on it now. Mode: {simple/complex}."

Etape B - Mettre a jour les champs du Project #67 via GraphQL :

# Status -> In Progress
gh api graphql -f query="mutation { updateProjectV2ItemFieldValue(input: { projectId: \"PVT_kwHOADA1Xc4BLw3w\", itemId: \"{ITEM_ID}\", fieldId: \"PVTSSF_lAHOADA1Xc4BLw3wzg7PYHY\", value: { singleSelectOptionId: \"47fc9ee4\" } }) { projectV2Item { id } } }"

# Machine -> {MA_MACHINE}
gh api graphql -f query="mutation { updateProjectV2ItemFieldValue(input: { projectId: \"PVT_kwHOADA1Xc4BLw3w\", itemId: \"{ITEM_ID}\", fieldId: \"PVTSSF_lAHOADA1Xc4BLw3wzg9nHu8\", value: { singleSelectOptionId: \"{MACHINE_OPTION_ID}\" } }) { projectV2Item { id } } }"

# Agent -> Roo
gh api graphql -f query="mutation { updateProjectV2ItemFieldValue(input: { projectId: \"PVT_kwHOADA1Xc4BLw3w\", itemId: \"{ITEM_ID}\", fieldId: \"PVTSSF_lAHOADA1Xc4BLw3wzg9icmA\", value: { singleSelectOptionId: \"102d5164\" } }) { projectV2Item { id } } }"

IDs des options Machine :
  myia-ai-01=ae516a70, myia-po-2023=2b4454e0, myia-po-2024=91dd0acf
  myia-po-2025=4f388455, myia-po-2026=bc8df25a, myia-web1=e3cd0cd0

Pour trouver ITEM_ID, executer :
gh api graphql -f query="{ user(login: \"jsboige\") { projectV2(number: 67) { items(first: 100) { nodes { id content { ... on Issue { number } } } } } } }" | python -c "import sys,json; items=json.load(sys.stdin)['data']['user']['projectV2']['items']['nodes']; print(next(i['id'] for i in items if i.get('content',{}).get('number')=={NUM}))"

Si le ITEM_ID n'est pas trouve dans les 100 premiers items, paginer avec after cursor.
Si les commandes GraphQL echouent, continuer quand meme (le commentaire suffit comme claim minimal).
```

4. Deleguer l'execution **avec contexte worktree** :

**REGLE (2026-02-13) : GLM 5 est maintenant le modele par defaut pour les taches -complex. Il est quasi-Opus. UTILISE -complex par DEFAUT pour toute tache impliquant du code.**

| Complexite tache | Mode par defaut | Fallback si echec |
|------------------|-----------------|-------------------|
| **Maintenance** (build, tests, git) | `code-simple` | N/A |
| **Simple** (1-2 fichiers, modification claire) | **`code-complex`** | `code-simple` (decoupe) |
| **Moyenne** (3+ fichiers, investigation) | **`code-complex`** | escalader `orchestrator-complex` |
| **Complexe** (architecture, 5+ composants) | **`orchestrator-complex`** | signaler `[ESCALADE-CLAUDE]` |
| **Investigation** (bug, analyse) | **`debug-complex`** | signaler `[ESCALADE-CLAUDE]` |

**OBJECTIF MINIMUM : 80% des delegations en mode -complex.** Seule la maintenance pure utilise -simple.

**CHAINE D'ESCALADE :**
```
code-simple → code-complex (GLM 5) → orchestrator-complex → claude -p (Opus)
```
Chaque niveau est plus puissant. Si `-complex` echoue, Claude Code (Opus) prendra le relais lors de son prochain tour.

4. Apres execution : deleguer a `code-simple` pour commenter l'issue :
   ```
   gh issue comment {NUM} --repo jsboige/roo-extensions --body "Executed by Roo scheduler on {MACHINE}. Result: {PASS/FAIL}. Mode: {simple/complex}. Commit: {hash if applicable}."
   ```
5. Si la tache est completee, rapporter dans l'INTERCOM
6. Si la tache echoue en `-complex` : signaler dans INTERCOM avec tag `[ESCALADE-CLAUDE]` pour que Claude Code la reprenne

### SI VRAIMENT RIEN A FAIRE

Si ni INTERCOM ni GitHub ne contiennent de tache :

Deleguer a `code-simple` **avec contexte worktree** les taches de maintenance :
1. `npm run build` dans `mcps/internal/servers/roo-state-manager` (verifier que le build passe)
2. `npx vitest run` (verifier que les tests passent)
3. Rapporter le resultat dans l'INTERCOM

```markdown
## [{DATE}] roo -> claude-code [MAINTENANCE]
Aucune tache assignee. Maintenance executee :
- Build : OK/FAIL
- Tests : X/Y pass
- Workspace : propre/dirty

---
```
