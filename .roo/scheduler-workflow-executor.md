# Executor Workflow - Orchestrator Roo

> Lu par orchestrateur-simple sur les machines executrices. MAJ : modifier + `git push`.

---

## ⚠️ RÈGLE #1 - AUTONOMIE ABSOLUE (ZÉRO QUESTION)

**Tu es 100% AUTONOME. Tu n'as AUCUN droit de poser une question à l'utilisateur.**

### ❌ INTERDIT (bloque le scheduler IMMEDIATEMENT)

```
# TOUTE question = ECHEC. Exemples de ce qui est INTERDIT :
"Pourriez-vous copier le contenu du fichier ?"       # Demande de contenu
"Veux-tu que je continue ?"                           # Demande de confirmation
"Dois-je procéder à l'exécution ?"                    # Demande de permission
"Voulez-vous que je fasse X ?"                        # Demande de validation
"Confirmez-vous que..."                               # Demande de confirmation
"Souhaitez-vous..."                                   # Demande de préférence
"Que préférez-vous ?"                                 # Demande de choix
```

**Pourquoi ?** Le scheduler tourne SANS utilisateur. Toute question bloque indéfiniment.

### ✅ TOUJOURS FAIRE (agir directement)

- Besoin de lire un fichier → **déléguer via `new_task`** à ask-simple ou code-simple
- Besoin de décider → **décider soi-même** selon le workflow
- Besoin de confirmer → **agir directement** sans demander
- Outil échoue → **déléguer à un autre mode** qui a l'outil, JAMAIS demander à l'utilisateur

### RÈGLE #2 : Propagation aux sous-tâches

**TOUTES les sous-tâches créées via `new_task` doivent commencer par :**
```
REGLE ABSOLUE: JAMAIS demander a l'utilisateur, JAMAIS poser de question,
JAMAIS demander confirmation. Agis directement.
```

**Il n'y a AUCUNE exception à cette règle.**

---

## 🚨 RÈGLE OBLIGATOIRE - LIMITATION D'OUTPUT (Issue #707)

**TOUJOURS limiter l'output des commandes shell** pour éviter l'explosion du contexte (GLM : 131k tokens réels).

```bash
# GIT LOG — TOUJOURS avec head -30 ou équivalent
execute_command(shell="gitbash", command="git log --oneline -30")
execute_command(shell="gitbash", command="git log --oneline HEAD@{1}..HEAD | head -30")
execute_command(shell="gitbash", command="git log --oneline --since='7 days ago' | head -30")

# GIT STATUS — OK sans limite (output court par nature)
execute_command(shell="gitbash", command="git status --short")

# GIT DIFF — TOUJOURS limiter
execute_command(shell="gitbash", command="git diff --stat | head -30")
execute_command(shell="gitbash", command="git diff HEAD --name-only | head -30")

# AUTRES COMMANDES À OUTPUT LONG — TOUJOURS limiter
execute_command(shell="powershell", command="... | Select-Object -Last 30")
execute_command(shell="gitbash", command="... | tail -30")
```

**⛔ INTERDIT :**

- `git log` sans `-N` ou `| head -N` ou `--since`
- `git diff` complet sans filtre (utiliser `--stat` ou `--name-only`)
- `--coverage` dans les tests (bloque + explose le contexte)

---

## 🛑 CIRCUIT BREAKER - Anti-Boucle d'Échecs (Issue #737)

**Si un outil échoue 2 fois de suite avec la même erreur → ABANDONNER cette action.**

### Règle

| Échecs consécutifs | Action |
|--------------------|--------|
| 1 | Réessayer UNE FOIS avec syntaxe simplifiée |
| 2 | **STOP** — Abandonner cette sous-tâche, passer à la suivante |
| 3+ | **INTERDIT** — Ne JAMAIS réessayer plus de 2 fois |

### Cas spécifiques

**`gh api graphql` en mode `-simple` via win-cli :**
- Les guillemets JSON dans les commandes `gh api graphql` cassent souvent via win-cli
- **PRÉFÉRER** : `gh issue list`, `gh issue view`, `gh pr list` (commandes simples)
- **ÉVITER** : `gh api graphql -f query='...'` en `-simple` (quoting instable)
- Si GraphQL nécessaire → **escalader vers `-complex`** qui a le terminal natif

**Condensation qui échoue :**
- Si la condensation retourne une erreur (token limit, API error) → **NE PAS réessayer**
- Terminer la tâche avec `attempt_completion` immédiatement
- Écrire `[WARN] Condensation failed` dans le rapport dashboard

### Pourquoi c'est critique

Sans circuit breaker, un outil qui échoue en boucle ajoute ~1KB d'erreur par tentative.
Après 60 tentatives = 60KB de contexte gaspillé → déclenche une boucle de condensation →
la condensation elle-même échoue (>262K tokens) → boucle infinie (#737 RC2+RC3).

---

## Workflow Executor

**Machine:** {MACHINE} (myia-po-* ou myia-web1)
**Fréquence:** 6 heures
**Mode:** orchestrator-simple (délègue tout via new_task)

---

## ⛔ RÈGLE SSH - JAMAIS SSH VERS LA MACHINE LOCALE (Issue #903)

**Tu tournes DÉJÀ sur {MACHINE}. Toutes les commandes s'exécutent LOCALEMENT.**

- **JAMAIS** utiliser `ssh_execute` ou `create_ssh_connection` pour {MACHINE}
- **JAMAIS** interpréter "Machine: {MACHINE}" comme "se connecter en SSH à {MACHINE}"
- **TOUJOURS** utiliser `execute_command(shell="powershell", command="...")` ou `execute_command(shell="gitbash", command="...")` pour les commandes locales

**Pourquoi ?** Roo tourne sur la machine locale. SSH vers soi-même échoue systématiquement avec `Unknown SSH connection ID` et bloque le scheduler.

---

## Git Author (OBLIGATOIRE avant tout commit)

**Tous les commits doivent utiliser le nom `jsboige`.** Avant tout `git commit`, executer :
```
execute_command(shell="gitbash", command="git config user.name 'jsboige' && git config user.email 'jsboige@hotmail.com'")
```
Ceci corrige le probleme des commits sous "Roo Extensions Dev" qui polluent l'historique git.

---

## Rappels Critiques

1. **TOUJOURS déléguer via `new_task`** - NE JAMAIS exécuter soi-même
2. **NE JAMAIS demander à l'utilisateur** - C'est RÈGLE #1
3. **TOUJOURS vérifier les MCP** - Pre-flight check OBLIGATOIRE
4. **TOUJOURS rapporter dans le dashboard workspace** - Via `roosync_dashboard(type: "workspace", action: "append")`. Fallback fichier `.claude/local/INTERCOM-{MACHINE}.md` si MCP échoue.
5. **win-cli OBLIGATOIRE pour shell** - Les modes `-simple` n'ont PAS le terminal natif
6. **Identifiants de modes OBLIGATOIRES** : `code-simple`, `ask-simple`, `debug-simple`, `code-complex`, `ask-complex`, `debug-complex`, `orchestrator-simple`, `orchestrator-complex`
7. **Escalade agressive** : 1 échec en `-simple` → immédiatement vers `-complex`
8. **JAMAIS `write_to_file` pour fichiers >200 lignes** : Utiliser `apply_diff` ou `replace_in_file`
9. **JAMAIS `ssh_execute` pour la machine locale** — Tu es DÉJÀ sur {MACHINE}. Utilise `execute_command` directement.

---

## Étape 0 : Pre-flight Check + Heartbeat (OBLIGATOIRE)

**AVANT TOUT**, vérifier que les MCP critiques sont disponibles.

**DÉLEGUER à `code-simple` via `new_task` :**

```
Pre-flight check : tester le MCP win-cli.

1. Executer : execute_command(shell="powershell", command="echo PRE-FLIGHT-OK")
2. Rapporter : PRE-FLIGHT-OK si la commande réussit, ou le message d'erreur exact si échec.

Puis envoyer heartbeat au coordinateur :
roosync_heartbeat(action: "register", machineId: "{MACHINE_ID}")
```

**Si STOP (échec win-cli) :**
- Écrire dans dashboard workspace : `roosync_dashboard(type: "workspace", action: "append", tags: ["CRITICAL", "roo-scheduler"], content: "win-cli MCP non disponible")`
- Fallback fichier : `.claude/local/INTERCOM-{MACHINE}.md` si dashboard échoue
- Terminer la tâche sans déléguer d'autres sous-tâches

---

## Étape 1 : Git Pull + Worktree Check + Lecture Dashboards

**DÉLEGUER à `code-simple` via `new_task` :**

```
REGLE ABSOLUE: JAMAIS demander a l'utilisateur, JAMAIS poser de question, JAMAIS demander confirmation. Agis directement.

Executer ces commandes avec win-cli MCP et rapporter le résultat :
1. execute_command(shell="gitbash", command="git pull --no-rebase origin main")
2. execute_command(shell="gitbash", command="git status")

Worktree cleanup check (issue #856) :
3. execute_command(shell="powershell", command="git worktree list --porcelain | Select-String '^worktree ' | Measure-Object | Select-Object -ExpandProperty Count")
   Si > 2 worktrees : execute_command(shell="powershell", command="powershell -ExecutionPolicy Bypass -File scripts/claude/worktree-cleanup.ps1 -WhatIf")
   Si des orphelins détectés : execute_command(shell="powershell", command="powershell -ExecutionPolicy Bypass -File scripts/claude/worktree-cleanup.ps1 -Force")

Puis lire le dashboard WORKSPACE (coordination cross-machine) :
4. roosync_dashboard(action: "read", type: "workspace", section: "all")

Si le dashboard échoue, FALLBACK fichier local :
4b. Lire le dashboard workspace+machine (DEPRECATED) ou le fichier INTERCOM local (DEPRECATED) comme fallback

Chercher les messages avec tags [TASK], [SCHEDULED], [URGENT], [PROPOSAL].
Rapporter : état git + worktrees count + contenu dashboard workspace + liste des tâches/propositions trouvées.
```

**Décision :**
- Si git pull a ÉCHOUÉ → aller à **Étape 3** avec rapport d'erreur
- Si `[URGENT]` → escalader vers `orchestrator-complex`
- Si `[TASK]` ou `[PROPOSAL]` trouvé avec tag `[COMPLEX]` ET date < 24h → **escalader vers orchestrator-complex**
- Si `[TASK]` ou `[PROPOSAL]` trouvé ET date < 24h → aller à **Étape 2a** (traiter `[PROPOSAL]` comme `[TASK]`)
- Si `[TASK]` trouvé MAIS date > 24h → IGNORER
- Si rien → aller à **Étape 2b**

---

## Étape 2a : Exécuter les tâches du Dashboard Workspace

Pour chaque `[TASK]` trouvé, déléguer selon la difficulté :

| Difficulté | Action |
|-----------|--------|
| Tâche avec label `enhancement` ou `feature` | **Escalader vers `code-complex`** |
| Schéma Zod complexe (`refine()`, validation conditionnelle) | **Escalader vers `code-complex`** |
| Modification de >2 fichiers interconnectés | **Escalader vers `code-complex`** |
| 1 action isolée | `code-simple` via `new_task` |
| 2-4 actions liées | Deleguer chaque action séparément à `code-simple` |
| 5+ actions ou dépendances | Escalader vers `orchestrator-complex` |

**Gestion des échecs (ESCALADE AGRESSIVE) :**
- 1er résultat insatisfaisant → **escalader IMMEDIATEMENT vers `-complex`**
- Écrire `[INCIDENT-SIMPLE]` dans dashboard workspace (`roosync_dashboard(type: "workspace", action: "append", tags: ["INCIDENT-SIMPLE", "roo-scheduler"])`) pour CHAQUE escalade
- Ne PAS relancer en -simple

Après exécution → **Étape 3**

---

## Étape 2b : Tâches par défaut (si pas de [TASK])

> ⚠️ **OBLIGATION CRITIQUE (Bug #702)** : L'Étape 2b comprend TOUJOURS 4 sous-étapes séquentielles.

**CHECKLIST SOUS-ÉTAPES OBLIGATOIRES (toutes à exécuter) :**

```
☐ 2b-1 : Build + Tests (validation santé workspace)
☐ 2b-2 : GitHub issues (chercher une tâche dispatchée ou disponible)
☐ 2b-review : PR Review (reviewer les PRs ouvertes)
☐ 2c-idle : Veille Active ou Consolidation (toujours, même si rien à faire)
→ SEULEMENT ENSUITE : Étape 3
```

### 2b-1 : Build + Tests

```
Executer dans mcps/internal/servers/roo-state-manager avec win-cli :
1. execute_command(shell="powershell", command="cd mcps/internal/servers/roo-state-manager; npm run build")
2. execute_command(shell="powershell", command="cd mcps/internal/servers/roo-state-manager; npx vitest run 2>&1 | Select-Object -Last 30")
Rapporter : build OK/FAIL + nombre tests pass/fail.
IMPORTANT : utilise win-cli MCP (pas le terminal natif).
INTERDIT : NE JAMAIS utiliser --coverage ou le reporter par defaut (output 600KB = sature le contexte LLM #827).
INTERDIT : NE JAMAIS lancer vitest sans '2>&1 | Select-Object -Last 30' (output brut = 500K+ chars = saturation contexte).
```

> **Note MyIA-Web1** : Toujours utiliser `npx vitest run --maxWorkers=1 2>&1 | Select-Object -Last 30`

### 2b-2 : GitHub Issues (dispatch-aware)

**Etape A — Lister TOUTES les issues ouvertes (pas seulement roo-schedulable) :**

```
execute_command(shell="powershell", command="gh issue list --repo jsboige/roo-extensions --state open --limit 40 --json number,title,labels")
```

Note : On liste toutes les issues. Le filtrage se fait en Etape B (labels, dispatch status, claim status).
IGNORER les issues avec label `needs-approval` (attendent validation utilisateur).

**Etape B — Selectionner une issue (ordre de priorite) :**

Pour les 5 premieres issues de la liste, verifier les derniers commentaires :
```
execute_command(shell="powershell", command="gh issue view {NUM} --repo jsboige/roo-extensions --json comments --jq '[.comments[-5:][] | .body] | join(\"\\n---\\n\")'")
```

**Priorite de selection :**
1. **Issue dispatchee a cette machine** : commentaire contenant `[DISPATCH] {MACHINE}` → executer en priorite
2. **Issue dispatchee a `All`** : commentaire `[DISPATCH] All` → disponible (attention: verifier claim)
3. **Issue non dispatchee et non claimee** : aucun commentaire `[DISPATCH]` ni `[CLAIMED]` → claimer et executer
4. **PASSER si :**
   - Assignee defini (quelqu'un a déjà locké l'issue avec assignee)
   - Commentaire `[CLAIMED]` par n'importe quel agent (pas seulement autre machine)
   - Commentaire `[RESULT]` existant (travail deja fait, meme si non ferme)
   - Issue dispatchee a une machine specifique AUTRE que la tienne

> ⚠️ **ANTI-DOUBLON (CRITIQUE - FIX #1005)** : Le mécanisme de claim utilise maintenant le champ `assignee` comme verrou atomique.
> 1. **Phase 1** : `gh issue edit --add-assignee jsboige` (opération atomique GitHub API)
> 2. **Phase 2** : Attendre 5 secondes, puis vérifier que l'assignee est toujours présent
> 3. **Phase 3** : Si vérification OK, poster commentaire `[CLAIMED]` pour traçabilité
> 4. **Rollback** : Si l'assignee a été retiré pendant le délai, abandonner l'issue
>
> TOUJOURS verifier les 10 derniers commentaires pour `[CLAIMED]` ET `[RESULT]` AVANT de claimer. Si l'un ou l'autre existe → PASSER cette issue. Ne JAMAIS claimer une issue qui a deja un `[RESULT]`.

Si une issue est trouvee :
1. Lire le body complet avec labels : execute_command(shell="powershell", command="gh issue view {NUM} --repo jsboige/roo-extensions --json title,body,labels,assignees")
2. **VERIFIER LES LABELS** avant de choisir le mode d'execution :
   - Si labels contiennent `roo-schedulable` : utiliser `code-simple` (taches calibrees pour ca)
   - **Si PAS de label `roo-schedulable`** : **DELEGUER A `code-complex`** (tache non calibree pour -simple)
   - Si labels contiennent `enhancement` ou `feature` : **TOUJOURS `code-complex`** meme si roo-schedulable
   - Si labels contiennent `bug` avec complexite inconnue : commencer avec `code-complex`
3. **Claimer avec assignee comme verrou** (fonction `Claim-GitHubIssue` dans start-claude-worker.ps1) :
   - Ajoute `jsboige` comme assignee (opération atomique)
   - Attend 5 secondes et vérifie que l'assignee est toujours présent
   - Poste commentaire `[CLAIMED]` pour traçabilité
   - Retourne `$false` si le claim a échoué (un autre agent a pris l'issue)
4. **Creer une branche et travailler dessus** (JAMAIS push direct sur main) :
   ```
   execute_command(shell="gitbash", command="git checkout -b wt/{MACHINE}-issue-{NUM}")
   ```
5. Executer selon difficulte (simple → `code-simple`, complexe → `code-complex`)
6. **Commiter, pusher la branche, et creer une PR** :
   ```
   execute_command(shell="gitbash", command="git push -u origin wt/{MACHINE}-issue-{NUM}")
   execute_command(shell="powershell", command="gh pr create --repo jsboige/roo-extensions --title 'fix(#{NUM}): {TITRE_COURT}' --body '[RESULT] {MACHINE}: PASS. Mode: {simple/complex}.\n\nCloses #{NUM}'")
   ```
7. Commenter l'issue avec le lien PR : execute_command(shell="powershell", command="gh issue comment {NUM} --body \"[RESULT] {MACHINE}: PR created. Mode: {simple/complex}. Awaiting review.\"")
8. **Revenir sur main** : execute_command(shell="gitbash", command="git checkout main")

**IMPORTANT :** NE JAMAIS executer une issue avec label `enhancement` ou `feature` en mode `code-simple`. Ces taches necessitent des modeles plus capables (voir Issue #605).

> ⚠️ **TOUJOURS CONTINUER** vers **Étape 2b-review** puis **Étape 2c-idle**

### 2b-review : Reviewer les PRs ouvertes

```
execute_command(shell="powershell", command="gh pr list --repo jsboige/roo-extensions --state open --json number,title,author,createdAt")
```

Si PR trouvée → déléguer la review à `code-complex` (JAMAIS code-simple).

### 2c-idle : Veille Active ou Consolidation

> **Priorité** : Si des tâches de consolidation sont en attente (label `idle-task`), les exécuter. Sinon, faire une exploration Veille Active.

#### Option 1 : Consolidation (prioritaire si disponible)

Tâches de consolidation disponibles (voir Issue #656) :

| # | Task | Status |
|---|------|--------|
| 1 | Scripts datés | DONE |
| 2 | QuickFiles deprecated | DONE |
| 3 | RooSync Phase 3 | DONE |
| 4 | Scripts dupliqués (6 consolidations) | TODO |
| 5 | Docs obsolètes (9 dossiers) | TODO |
| 6 | Outputs temporaires | DONE |
| 7 | Couverture tests (9 outils sans tests) | TODO |
| 8 | Synthèse rapports git-history | TODO |
| 9 | Index docs | TODO (existe déjà) |

Déléguer UNE consolidation à `code-simple` via `new_task`.

#### Option 2 : Veille Active (si pas de consolidation)

**RÈGLES STRICTES :**
- **LECTURE SEULE** : ne JAMAIS modifier un fichier
- **1 seule exploration par session**
- **Pas de commit/push**

**Domaines d'exploration :**

| # | Domaine | Description |
|---|---------|-------------|
| 1 | Outil MCP peu utilisé | Tester un outil MCP rarement appelé |
| 2 | Doc vs réalité | Vérifier que chemins/outils/commandes existent |
| 3 | Couverture de tests | Lister fichiers sans tests correspondants |
| 4 | Cohérence config | Comparer config déployée avec source |
| 5 | Santé infrastructure | Tester un endpoint d'infrastructure |
| 6 | Inventaire GitHub | Issues perimées (> 14j sans commentaire) |
| 7 | Rangement dépôt | Vérifier fichiers bien placés |
| 8 | Consolidation doc | Chercher doublons sémantiques |
| 9 | Veille harnais agentique | Observer nouveaux outils vibe coding |

Après exploration → **Étape 3**

---

## Étape 3 : Rapporter dans Dashboards (OBLIGATOIRE)

> **CRITIQUE** : Le rapport est la seule trace du passage du scheduler.
> **REGLE #836** : Rapporter sur le dashboard WORKSPACE (cross-machine) ET sur workspace (local).

**MÉTHODE PRÉFÉRÉE — Dashboard MCP (pas d'approbation fichier) :**

**DÉLEGUER à `code-simple` via `new_task` :**

```
REGLE ABSOLUE: JAMAIS demander a l'utilisateur, JAMAIS poser de question, JAMAIS demander confirmation. Agis directement.

Écrire le bilan sur le dashboard WORKSPACE (cross-machine, visible par TOUTES les machines) :

roosync_dashboard(
  action: "append",
  type: "workspace",
  tags: ["{DONE|IDLE|PARTIEL}", "roo-scheduler"],
  content: "### [{MACHINE}] Bilan scheduler executor\n\nGit: {OK/erreur} | Build: {OK/FAIL} | Tests: {X}p/{Y}f\nTâches: {N} ({source}) | Erreurs: {aucune ou description 1 ligne}"
)

Si le dashboard MCP échoue (erreur), rapporter l'échec via attempt_completion (les fichiers INTERCOM locaux sont DEPRECATED).
```

**TAGS OBLIGATOIRES pour identifier l'auteur :**
- `roo-scheduler` = Roo orchestrateur executor (6h)
- `roo-meta` = Roo meta-analyste (72h)
- `claude-scheduled` = Claude Worker (schtask)
- `claude-interactive` = Claude Code interactif (humain)

**⚠️ REGLE ANTI-FAUX-POSITIF** : Le bilan DOIT refléter la réalité. Ne JAMAIS dire "Tout OK" si un échec est survenu.

### Étape 4 : TERMINER le cycle (OBLIGATOIRE)

> **CRITIQUE :** Apres l'Etape 3, l'orchestrateur DOIT appeler `attempt_completion` pour marquer la tache comme terminee. Sans cela, le scheduler considere la tache comme "en cours" et SAUTE les prochains ticks (`taskInteraction: "skip"`).

```
attempt_completion(result: "Cycle executor termine. Bilan poste dans dashboard workspace.")
```

**Si tu oublies cette etape**, la frequence du scheduler passe de 6h a ~24h+ car chaque tick suivant est saute.

---

## Chaîne d'escalade

`code-simple` → `code-complex` → **Claude Code CLI** (via `[ESCALADE-CLAUDE]`)

**Escalade OBLIGATOIRE vers `code-complex` pour :**
- Issue GitHub avec label `enhancement` ou `feature`
- Message `[URGENT]` dans le dashboard
- Modification de >2 fichiers interconnectés
- Schéma Zod complexe (`refine()`, validation conditionnelle)
- >5 sous-tâches ou dépendances

**Escalade après échec (RÈGLE AGRESSIVE) :**
- **1 seul échec en `-simple`** → escalade IMMEDIATE vers `-complex`
- Ne PAS retenter en `-simple`
- Écrire `[INCIDENT-SIMPLE]` dans le dashboard workspace
- **1 seul échec en `-complex`** → escalade IMMEDIATE vers Claude Code CLI
- Ne PAS retenter en `-complex`
- Écrire `[INCIDENT-COMPLEX]` dans le dashboard workspace

### Escalade vers Claude Code CLI (nouveau)

Quand un mode `-complex` échoue sur une tâche, le scheduler peut demander l'aide de Claude Code via la CLI `claude`. C'est un modèle plus puissant (Opus/Sonnet) capable de résoudre des problèmes architecturaux complexes.

**Déclencheur :** 1 échec en mode `-complex` (quel que soit le type : code-complex, debug-complex)

**Procédure :**
1. Écrire dans le dashboard workspace : `[ESCALADE-CLAUDE] Tâche {description}. Échec en {mode}. Erreur: {résumé}.`
2. Déléguer à `code-complex` pour exécuter la commande CLI :
```
execute_command(shell="powershell", command="claude -p 'Résoudre cette tâche: {DESCRIPTION}. Contexte: {ERREUR}. Fichiers concernés: {FICHIERS}. Exécuter le fix et rapporter le résultat.' --max-turns 10 --model sonnet")
```
3. Si Claude CLI résout → pusher la branche et créer une PR, puis commenter l'issue GitHub avec `[RESULT] {MACHINE}: PR created (escalade Claude CLI). Awaiting review.`
4. Si Claude CLI échoue aussi → commenter `[RESULT] {MACHINE}: FAIL (escalade Claude CLI). Nécessite intervention manuelle.` et écrire `[ERROR]` dans le dashboard workspace.

**Garde-fous :**
- Maximum **2 escalades Claude CLI par session** scheduler (éviter les coûts excessifs)
- Préférer `--model sonnet` (économique). Utiliser `--model opus` uniquement si sonnet échoue
- Timeout : `--max-turns 10` pour limiter la durée
- Documenter CHAQUE escalade dans le dashboard workspace avec le résultat
