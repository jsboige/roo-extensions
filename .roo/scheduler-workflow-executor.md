# Executor Workflow - Orchestrator Roo

> Lu par orchestrateur-simple sur les machines executrices. MAJ : modifier + `git push`.
> **PRÉAMBULE** : Lire `.roo/scheduler-workflow-shared.md` pour les règles communes (autonomie, circuit breaker, output, win-cli, rapport dashboard).

---

## Workflow Executor

**Machine:** {MACHINE} (myia-po-* ou myia-web1)
**Fréquence:** 6 heures
**Mode:** orchestrator-simple (délègue tout via new_task)

---

## ⛔ RÈGLE SSH - JAMAIS SSH VERS LA MACHINE LOCALE (Issue #903)

**Tu tournes DÉJÀ sur {MACHINE}. Toutes les commandes s'exécutent LOCALEMENT.**

- **JAMAIS** `ssh_execute` ou `create_ssh_connection` pour {MACHINE}
- **TOUJOURS** `execute_command(shell="powershell", ...)` ou `execute_command(shell="gitbash", ...)`

---

## Git Author (OBLIGATOIRE avant tout commit)

**Tous les commits doivent utiliser le nom `jsboige`.** Avant tout `git commit` :
```
execute_command(shell="gitbash", command="git config user.name 'jsboige' && git config user.email 'jsboige@hotmail.com'")
```

---

## ⚠️ Guardrails Phantom PRs (#1295) - OBLIGATOIRE

**Contexte :** Les phantom PRs sont causées par des pointeurs submodule qui pointent vers des commits non-poussés sur le remote.

**Règles pour TOUTES les opérations Git impliquant des submodules :**

1. **Vérification AVANT push** : TOUJOURS vérifier que les commits submodule sont sur `origin/main` avant de pousser le repo parent
2. **Ordre des pushs** : Submodule EN PREMIER, repo parent ENSUITE
3. **En cas de doute** : `git -C mcps/internal log origin/main..HEAD` pour voir les commits non-poussés
4. **Échec de push submodule** : NE PAS créer la PR parent, signaler l'erreur dans le dashboard

**Commandes de validation (à utiliser avant tout `git push` du parent) :**
```
# Vérifier les commits non-poussés du submodule
execute_command(shell="gitbash", command="cd mcps/internal/servers/roo-state-manager && git log origin/main..HEAD --oneline")

# Si non-vide → pousser le submodule AVANT le parent
execute_command(shell="gitbash", command="cd mcps/internal/servers/roo-state-manager && git push origin HEAD")
```

**Si le mode -complex doit modifier le submodule :**
1. Pousser le submodule : `cd mcps/internal && git push origin HEAD`
2. SEULEMENT ENSUITE pousser le parent et créer la PR

---

## Rappels Critiques

1. **TOUJOURS déléguer via `new_task`** - NE JAMAIS exécuter soi-même
2. **NE JAMAIS demander à l'utilisateur** - C'est RÈGLE #1 (voir preamble partagé)
3. **TOUJOURS vérifier les MCP** - Pre-flight check OBLIGATOIRE
4. **win-cli OBLIGATOIRE pour shell** - Les modes `-simple` n'ont PAS le terminal natif
5. **Identifiants de modes OBLIGATOIRES** : `code-simple`, `ask-simple`, `debug-simple`, `code-complex`, `ask-complex`, `debug-complex`, `orchestrator-simple`, `orchestrator-complex`
6. **Escalade agressive** : 1 échec en `-simple` → immédiatement vers `-complex`
7. **JAMAIS `write_to_file` pour fichiers >200 lignes** : Utiliser `apply_diff` ou `replace_in_file`
8. **JAMAIS `ssh_execute` pour la machine locale** — Tu es DÉJÀ sur {MACHINE}

---

## Étape 0 : Pre-flight Check + Heartbeat (OBLIGATOIRE)

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

Puis lire le dashboard WORKSPACE :
4. roosync_dashboard(action: "read", type: "workspace", section: "all")

Chercher les messages avec tags [TASK], [SCHEDULED], [URGENT], [PROPOSAL].
Rapporter : état git + worktrees count + contenu dashboard workspace + liste des tâches/propositions trouvées.
```

**Décision :**
- Si git pull ÉCHOUÉ → **Étape 3** avec rapport d'erreur
- Si `[URGENT]` → escalader vers `orchestrator-complex`
- Si `[TASK]`/`[PROPOSAL]` avec `[COMPLEX]` ET date < 24h → **escalader vers orchestrator-complex**
- Si `[TASK]`/`[PROPOSAL]` ET date < 24h → **Étape 2a**
- Si `[TASK]` MAIS date > 24h → IGNORER
- Si rien → **Étape 2b**

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
- Écrire `[INCIDENT-SIMPLE]` dans dashboard workspace pour CHAQUE escalade
- Ne PAS relancer en -simple

Après exécution → **Étape 3**

---

## Étape 2b : Tâches par défaut (si pas de [TASK])

> ⚠️ **OBLIGATION CRITIQUE (Bug #702)** : L'Étape 2b comprend TOUJOURS 4 sous-étapes séquentielles.

**CHECKLIST SOUS-ÉTAPES OBLIGATOIRES :**

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
INTERDIT : --coverage ou vitest sans '2>&1 | Select-Object -Last 30'.
```

> **Note MyIA-Web1** : Toujours utiliser `npx vitest run --maxWorkers=1 2>&1 | Select-Object -Last 30`

### 2b-2 : GitHub Issues (dispatch-aware)

**Etape A — Lister les issues ouvertes :**

```
execute_command(shell="powershell", command="gh issue list --repo jsboige/roo-extensions --state open --limit 40 --json number,title,labels")
```

**Etape B — Selectionner une issue (priorité) :**

1. **Issue dispatchee a cette machine** : `[DISPATCH] {MACHINE}` → priorité
2. **Issue dispatchee a `All`** : disponible (vérifier claim)
3. **Issue non dispatchee et non claimee** → claimer et executer
4. **PASSER si :** `assignee` défini, `[CLAIMED]`, `[RESULT]`, ou dispatchée à une autre machine

> ⚠️ **ANTI-DOUBLON (FIX #1005)** : Claim via `assignee` atomique. Vérifier commentaires ET assignee avant claim. Délai 5s anti-race condition.

Si une issue est trouvée :
1. Lire le body complet : `gh issue view {NUM} --json title,body,labels,assignees`
2. **Vérifier labels** : `roo-schedulable` → `code-simple`. Sinon → `code-complex`. `enhancement`/`feature` → TOUJOURS `code-complex`.
3. **Claimer (protocole atomique FIX #1005)** :
   - Phase 1 : `gh issue edit {NUM} --add-assignee jsboige` (verrou atomique)
   - Phase 2 : Attendre 5 secondes (anti-race condition)
   - Phase 3 : Re-vérifier `gh issue view {NUM} --json assignees` — si assignee retiré → abandonner
   - Phase 4 : Poster commentaire `[CLAIMED] {MACHINE}` pour traçabilité
   - **Rollback** : Si assignee absent après Phase 2 → quelqu'un d'autre a claimé, passer à l'issue suivante
4. Créer branche : `git checkout -b wt/{MACHINE}-issue-{NUM}`
5. Exécuter selon difficulté

> ⚠️ **GUARDRAIL #1295 - Phantom PRs** : AVANT le push + PR, vérifier et pousser les submodules

6. **Vérifier les commits submodule non-poussés** :
   ```
   execute_command(shell="gitbash", command="cd mcps/internal/servers/roo-state-manager && git log origin/main..HEAD --oneline")
   ```
   - Si output VIDE → PAS de changements submodule, continuer à l'étape 7
   - Si output NON-VIDE → Pousser le submodule AVANT le parent :
     ```
     execute_command(shell="gitbash", command="cd mcps/internal/servers/roo-state-manager && git push origin HEAD")
     ```

7. Commit + push + PR : `gh pr create --repo jsboige/roo-extensions --title 'fix(#{NUM}): {TITRE}' --body '[RESULT] {MACHINE}: PASS.'`
8. Commenter l'issue : `gh issue comment {NUM} --body "[RESULT] {MACHINE}: PR created."`
9. Revenir sur main : `git checkout main`

### 2b-review : Reviewer les PRs ouvertes

```
execute_command(shell="powershell", command="gh pr list --repo jsboige/roo-extensions --state open --json number,title,author,createdAt")
```

Si PR trouvée → déléguer la review à `code-complex` (JAMAIS code-simple).

### 2c-idle : Veille Active ou Consolidation

> **Priorité** : Consolidation si disponible, sinon Veille Active.

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

**RÈGLES STRICTES :** LECTURE SEULE. 1 seule exploration par session. Pas de commit/push.

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

**DÉLEGUER à `code-simple` via `new_task` :**

```
REGLE ABSOLUE: JAMAIS demander a l'utilisateur, JAMAIS poser de question, JAMAIS demander confirmation. Agis directement.

Écrire le bilan sur le dashboard WORKSPACE :

roosync_dashboard(
  action: "append",
  type: "workspace",
  tags: ["{DONE|IDLE|PARTIEL}", "roo-scheduler"],
  content: "### [{MACHINE}] Bilan scheduler executor\n\nGit: {OK/erreur} | Build: {OK/FAIL} | Tests: {X}p/{Y}f\nTâches: {N} ({source}) | Erreurs: {aucune ou description 1 ligne}"
)

Si le dashboard MCP échoue, fallback : apply_diff sur .claude/local/INTERCOM-{MACHINE}.md
```

### Étape 4 : TERMINER le cycle (OBLIGATOIRE)

```
attempt_completion(result: "Cycle executor termine. Bilan poste dans dashboard workspace.")
```

---

## Chaîne d'escalade

`code-simple` → `code-complex` → **Claude Code CLI** (via `[ESCALADE-CLAUDE]`)

**Escalade OBLIGATOIRE vers `code-complex` pour :**
- Issue GitHub avec label `enhancement` ou `feature`
- Message `[URGENT]` dans le dashboard
- Modification de >2 fichiers interconnectés
- Schéma Zod complexe (`refine()`, validation conditionnelle)
- >5 sous-tâches ou dépendances

**Escalade après échec (AGRESSIVE) :**
- **1 échec en `-simple`** → escalade IMMEDIATE vers `-complex`
- **1 échec en `-complex`** → escalade IMMEDIATE vers Claude Code CLI

### Escalade vers Claude Code CLI

**Procédure :**
1. Écrire `[ESCALADE-CLAUDE]` dans le dashboard workspace
2. Déléguer à `code-complex` pour exécuter :
```
execute_command(shell="powershell", command="claude -p 'Résoudre: {DESCRIPTION}. Contexte: {ERREUR}. Fichiers: {FICHIERS}.' --max-turns 10 --model sonnet")
```
3. Si succès → push + PR + commenter issue `[RESULT]`

> ⚠️ **IMPORTANT (#1295)** : Si la tâche a modifié le submodule, le mode -complex DOIT pousser le submodule AVANT le parent :
> ```
> cd mcps/internal && git push origin HEAD
> cd ../.. && git push origin wt/{BRANCH}
> ```

4. Si échec → commenter `[RESULT] {MACHINE}: FAIL (escalade CLI).` + `[ERROR]` dashboard

**Garde-fous :** Max 2 escalades CLI/session. Préférer `sonnet` (économique). Timeout `--max-turns 10`.
