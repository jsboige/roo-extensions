# Workflow Scheduler Roo - COORDINATEUR (myia-ai-01)

> Ce fichier est lu par l'orchestrateur-simple sur la machine coordinateur.
> Pour mettre a jour les instructions : modifier ce fichier puis `git push`.
> Les machines recevront les nouvelles instructions au prochain `git pull`.

## ROLE : COORDINATEUR

Tu es le coordinateur Roo sur la machine principale (myia-ai-01).
Tes responsabilites :
- Executer les taches locales demandees par Claude Code via INTERCOM
- Rapporter les resultats dans l'INTERCOM local
- Maintenir le workspace propre

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

### Etape 3 : Executer les taches locales par delegation

**REGLE ABSOLUE : NE JAMAIS faire le travail toi-meme. TOUJOURS deleguer via `new_task`.**

**CONTEXTE WORKTREE (#456 Phase B) : Inclure systematiquement le contexte worktree dans CHAQUE delegation.**

Pour chaque tache `[TASK]` trouvee dans l'INTERCOM :

| Difficulte | Action |
|-----------|--------|
| **SIMPLE** (1 action) | Deleguer a `code-simple` ou `debug-simple` via `new_task` **avec contexte worktree** |
| **MOYEN** (2-4 actions) | Deleguer chaque action separement a `code-simple` **avec contexte worktree** |
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
### Bilan planifie - Coordinateur

**Contexte Worktree (#456) :**
- Path: {WORKTREE_PATH}
- Branch: {WORKTREE_BRANCH}
- Commit: {WORKTREE_COMMIT}
- Type: {WORKTREE_TYPE}

**Execution :**
- Taches locales executees : ...
- Modes utilises : code-simple / code-complex / debug-complex
- Erreurs : ...
- Git status : propre/dirty
- Escalades effectuees : aucune / vers {mode}
- Messages RooSync detectes : N (reveille Claude : oui/non)

---
```

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

## SI RIEN DANS L'INTERCOM : VERIFIER LES MESSAGES ROOSYNC ET GITHUB

**Le coordinateur ne reste JAMAIS inactif. Il a 3 sources de travail.**

### Etape 3b : Verifier si des messages RooSync attendent Claude Code

Deleguer a `code-simple` via `new_task` **avec contexte worktree** :

```
Executer cette commande et retourner le resultat COMPLET :
ls "G:/Mon Drive/Synchronisation/RooSync/.shared-state/messages/inbox/" | Select-String "msg-" | Measure-Object | Select-Object Count

Puis lister les 5 fichiers les plus recents :
Get-ChildItem "G:/Mon Drive/Synchronisation/RooSync/.shared-state/messages/inbox/*.json" | Sort-Object LastWriteTime -Descending | Select-Object -First 5 Name,LastWriteTime
```

Si des messages non-lus existent (fichiers recents < 6h) → **REVEILLER CLAUDE CODE** (Etape 3d).

### Etape 3c : Chercher une tache sur GitHub

Deleguer a `code-simple` via `new_task` **avec contexte worktree** :

```
Executer cette commande et retourner le resultat COMPLET :
gh issue list --repo jsboige/roo-extensions --state open --limit 10 --json number,title,body --jq '.[] | select(.body | test("Roo-Schedulable|roo-schedulable|## Execution-Ready|execution-ready"; "i")) | "\(.number)\t\(.title)"'

Si la commande ne retourne rien, essayer aussi :
gh issue list --repo jsboige/roo-extensions --state open --label roo-schedulable --limit 5 --json number,title
```

Si une tache schedulable est trouvee :

**3c-bis. CLAIM LA TACHE (ANTI DOUBLE-TRAITEMENT)** - Deleguer a `code-simple` **avec contexte worktree** :

```
AVANT de commencer le travail, verifier et revendiquer la tache sur GitHub :

Etape A - Commenter l'issue pour signaler la prise en charge :
gh issue comment {NUM} --repo jsboige/roo-extensions --body "🔒 Claimed by myia-ai-01 (Roo coordinator). Working on it now. Mode: {simple/complex}."

Etape B - Mettre a jour les champs du Project #67 via GraphQL :

# Status -> In Progress
gh api graphql -f query="mutation { updateProjectV2ItemFieldValue(input: { projectId: \"PVT_kwHOADA1Xc4BLw3w\", itemId: \"{ITEM_ID}\", fieldId: \"PVTSSF_lAHOADA1Xc4BLw3wzg7PYHY\", value: { singleSelectOptionId: \"47fc9ee4\" } }) { projectV2Item { id } } }"

# Machine -> myia-ai-01
gh api graphql -f query="mutation { updateProjectV2ItemFieldValue(input: { projectId: \"PVT_kwHOADA1Xc4BLw3w\", itemId: \"{ITEM_ID}\", fieldId: \"PVTSSF_lAHOADA1Xc4BLw3wzg9nHu8\", value: { singleSelectOptionId: \"ae516a70\" } }) { projectV2Item { id } } }"

# Agent -> Roo
gh api graphql -f query="mutation { updateProjectV2ItemFieldValue(input: { projectId: \"PVT_kwHOADA1Xc4BLw3w\", itemId: \"{ITEM_ID}\", fieldId: \"PVTSSF_lAHOADA1Xc4BLw3wzg9icmA\", value: { singleSelectOptionId: \"102d5164\" } }) { projectV2Item { id } } }"

IDs des options Machine :
  myia-ai-01=ae516a70, myia-po-2023=2b4454e0, myia-po-2024=91dd0acf
  myia-po-2025=4f388455, myia-po-2026=bc8df25a, myia-web1=e3cd0cd0

Pour trouver ITEM_ID :
gh api graphql -f query="{ user(login: \"jsboige\") { projectV2(number: 67) { items(first: 100) { nodes { id content { ... on Issue { number } } } } } } }" | python -c "import sys,json; items=json.load(sys.stdin)['data']['user']['projectV2']['items']['nodes']; print(next(i['id'] for i in items if i.get('content',{}).get('number')=={NUM}))"

Si les commandes GraphQL echouent, continuer quand meme (le commentaire suffit comme claim minimal).
```

Ensuite executer :
- **Tache simple** (tag Roo ou Both) : Deleguer a `code-simple` ou `code-complex`
- **Tache Claude Code only** : Signaler dans INTERCOM + reveiller Claude (Etape 3d)

### Etape 3d : REVEILLER CLAUDE CODE (Oracle)

**QUAND :** Des messages RooSync non-lus ou des taches Claude Code sont detectes.

Deleguer a `code-simple` via `new_task` **avec contexte worktree** :

```
Executer cette commande pour invoquer Claude Code en mode coordinateur :
claude -p "Tu es reveille par le scheduler Roo sur myia-ai-01. Il y a des messages RooSync non-lus ou des taches en attente. Lance /coordinate pour faire un tour de sync rapide : lis les messages, reponds aux agents, et mets a jour GitHub. Sois concis et autonome." --dangerously-skip-permissions --model opus

Si la commande echoue, signaler dans l'INTERCOM :
## [{DATE}] roo -> claude-code [WARN]
### Echec invocation Claude Code
- Commande : claude -p "..."
- Erreur : {message d'erreur}
- Action requise : Lancer /coordinate manuellement
```

**ATTENTION :** `claude -p` lance Claude en mode non-interactif. Il va :
1. Lire les messages RooSync
2. Repondre aux agents
3. Mettre a jour GitHub si necessaire
4. Sortir automatiquement

### SI VRAIMENT RIEN A FAIRE

Si ni INTERCOM, ni RooSync, ni GitHub ne contiennent de tache :

Deleguer a `code-simple` **avec contexte worktree** les taches de maintenance :
1. `git pull --no-rebase origin main` (mettre a jour le code)
2. `npm run build` dans `mcps/internal/servers/roo-state-manager` (verifier que le build passe)
3. `npx vitest run` (verifier que les tests passent)
4. Rapporter le resultat dans l'INTERCOM

```markdown
## [{DATE}] roo -> claude-code [MAINTENANCE]
Aucune tache assignee. Maintenance executee :
- Git pull : OK/erreur
- Build : OK/FAIL
- Tests : X/Y pass
- Workspace : propre/dirty
- Messages RooSync detectes : 0

---
```
