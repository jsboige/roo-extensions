# Executor Workflow - Orchestrator Roo

> Lu par orchestrateur-simple sur les machines executrices. MAJ : modifier + `git push`.
> **PRÉAMBULE** : Lire `.roo/scheduler-workflow-shared.md` pour les règles communes (autonomie, circuit breaker, output, win-cli, rapport dashboard).

---

## Workflow Executor

**Machine:** {MACHINE} (myia-po-* ou myia-web1)
**Fréquence:** 6 heures
**Mode:** orchestrator-simple (délègue tout via new_task)

> **BUDGET DÉLÉGATION (#2068) :** Max 3 delegations par cycle. La premiere (ask-simple pour lire ce fichier) est hors de notre controle (config schedule). Les etapes ci-dessous utilisent donc MAXIMUM 2 delegations : Setup (Etape 0) + Tache+Rapport (Etape 1).

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

## Étape 0 : Setup combiné — Pre-flight + Git + Dashboard (OBLIGATOIRE)

> **Budget délégation (#2068) :** Cette étape combine l'ancien pre-flight ET git+dashboard en UNE SEULE délégation.

**DÉLEGUER à `code-simple` via `new_task` :**

```
REGLE ABSOLUE: JAMAIS demander a l'utilisateur, JAMAIS poser de question, JAMAIS demander confirmation. Agis directement.

SETUP COMBINÉ — Exécuter dans l'ordre et rapporter le résultat :

A. Pre-flight (tester MCP win-cli) :
1. execute_command(shell="powershell", command="echo PRE-FLIGHT-OK")

B. Git pull + status :
2. execute_command(shell="gitbash", command="git pull --no-rebase origin main")
3. execute_command(shell="gitbash", command="git status")

C. Worktree cleanup check (issue #856) :
4. execute_command(shell="powershell", command="git worktree list --porcelain | Select-String '^worktree ' | Measure-Object | Select-Object -ExpandProperty Count")
   Si > 2 worktrees : execute_command(shell="powershell", command="powershell -ExecutionPolicy Bypass -File scripts/claude/worktree-cleanup.ps1 -WhatIf")
   Si des orphelins détectés : execute_command(shell="powershell", command="powershell -ExecutionPolicy Bypass -File scripts/claude/worktree-cleanup.ps1 -Force")

D. Dashboard workspace :
5. roosync_dashboard(action: "read", type: "workspace", section: "all")

Chercher les messages avec tags [WAKE-ROO], [TASK], [SCHEDULED], [URGENT], [PROPOSAL].
Rapporter : pre-flight OK/FAIL + état git + worktrees count + contenu dashboard workspace + liste des tâches/propositions trouvées + presence de [WAKE-ROO].

Heartbeat automatique (#1609) : envoyé à chaque appel d'outil MCP, pas d'action requise.
IMPORTANT : utilise win-cli MCP (pas le terminal natif).
```

**Si STOP (échec win-cli au pre-flight) :**
- Écrire dans dashboard workspace : `roosync_dashboard(type: "workspace", action: "append", tags: ["CRITICAL", "roo-scheduler"], content: "win-cli MCP non disponible")`
- Terminer la tâche sans déléguer d'autres sous-tâches

**Décision (d'après le rapport) :**
- Si git pull ÉCHOUÉ → **Étape 2** avec rapport d'erreur
- Si `[WAKE-ROO]` (#1955, IMMÉDIAT) → traiter le contenu IMMEDIATEMENT, repondre par `[ACK]` sur le dashboard, escalader vers `-complex` si la demande l'exige
- Si `[URGENT]` → escalader vers `orchestrator-complex`
- Si `[TASK]`/`[PROPOSAL]` avec `[COMPLEX]` ET date < 24h → **escaler vers orchestrator-complex**
- Si `[TASK]`/`[PROPOSAL]` ET date < 24h → **Étape 1a**
- Si `[TASK]` MAIS date > 24h → IGNORER
- Si rien → **Étape 1b**

---

## Étape 1a : Exécuter les tâches du Dashboard Workspace

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

Après exécution → **Étape 2**

---

## Étape 1b : Tâches par défaut (si pas de [TASK])

> ⚠️ **OBLIGATION CRITIQUE (Bug #702)** : L'Étape 1b comprend TOUJOURS 4 sous-étapes séquentielles.

**CHECKLIST SOUS-ÉTAPES OBLIGATOIRES :**

```
☐ 1b-1 : Build + Tests (validation santé workspace)
☐ 1b-2 : GitHub issues (chercher une tâche dispatchée ou disponible)
☐ 1b-review : PR Review (reviewer les PRs ouvertes)
☐ 1c-idle : Veille Active ou Consolidation (toujours, même si rien à faire)
→ SEULEMENT ENSUITE : Étape 2
```

### 1b-1 : Build + Tests

```
Executer dans mcps/internal/servers/roo-state-manager avec win-cli :
1. execute_command(shell="powershell", command="cd mcps/internal/servers/roo-state-manager; npm run build")
2. execute_command(shell="powershell", command="cd mcps/internal/servers/roo-state-manager; npx vitest run 2>&1 | Select-Object -Last 30")
Rapporter : build OK/FAIL + nombre tests pass/fail.
INTERDIT : --coverage ou vitest sans '2>&1 | Select-Object -Last 30'.
```

> **Note MyIA-Web1** : Toujours utiliser `npx vitest run --maxWorkers=1 2>&1 | Select-Object -Last 30`

### 1b-2 : GitHub Issues (dispatch-aware)

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

### 1b-review : Reviewer les PRs ouvertes

```
execute_command(shell="powershell", command="gh pr list --repo jsboige/roo-extensions --state open --json number,title,author,createdAt")
```

**OBLIGATOIRE avant chaque review — Déduplication SHA (#2140) :**

Pour chaque PR à reviewer, vérifier qu'aucune review n'existe déjà sur le commit HEAD actuel :

```bash
# Obtenir le HEAD SHA
HEAD_SHA=$(gh pr view {N} --json headRefOid --jq '.headRefOid')
# Vérifier les reviews existantes sur ce SHA
REVIEWS_COUNT=$(gh api repos/jsboige/roo-extensions/pulls/{N}/reviews --jq "[.[] | select(.commit_id == \"$HEAD_SHA\")] | length")
# Si >0 → SKIP (ne PAS appeler gh pr review)
```

Adapter le repo dans l'URL API selon le repo de la PR (jsboige-mcp-servers, etc.).

Si PR trouvée ET dédup OK → déléguer la review à `code-complex` (JAMAIS code-simple).

### 1b-patrol : Veille Active Proactive — Patrouille avec Auto-Réparation (MANDATORY si >1h depuis dernière)

> **Mandate #1886** : Patrouille proactive avec auto-réparation AVANT toute action de consolidation. Contraintes dans `.roo/scheduler-workflow-shared.md` section "VEILLE ACTIVE".

**DÉLÉGUER** a `code-simple` via `new_task` :

```
REGLE ABSOLUE: JAMAIS demander a l'utilisateur, JAMAIS poser de question, JAMAIS demander confirmation. Agis directement.

VEILLE ACTIVE PROACTIVE — Détection et auto-réparation automatique.

1. roosync_dashboard(action: "read", type: "workspace") — chercher dernier [PATROL] ou [FRICTION-FOUND]
   Si dernier patrol < 1h → RAPPORTER "SKIP: patrol < 1h" et TERMINER cette sous-tâche

2. Si patrol nécessaire, exécuter les vérifications automatiques (dans l'ordre) :

   **A. Santé Tests (Build + Vitest) :**
   - execute_command(shell="powershell", command="cd mcps/internal/servers/roo-state-manager; npm run build")
   - execute_command(shell="powershell", command="cd mcps/internal/servers/roo-state-manager; npx vitest run 2>&1 | Select-Object -Last 50")
   - SI échec build ou tests :
     * Créer issue GitHub : gh issue create --title "[PATROL] Build/Tests failed on {MACHINE}" --body "Auto-detected by Roo scheduler patrol. Details: {OUTPUT}" --label needs-approval --label patrol
     * Poster [FRICTION-FOUND] sur dashboard avec détails
     * TERMINER patrol (pas de auto-fix pour tests)

   **B. Fichiers non-commités (>7 jours) :**
   - execute_command(shell="gitbash", command="git status --porcelain")
   - execute_command(shell="powershell", command="git status --porcelain | ForEach-Object { git log -1 --format=%ct -- $_.Split(' ')[-1] } | Where-Object { $_ -lt (Get-Date).AddDays(-7).Ticks } | Measure-Object")
   - SI fichiers >7 jours non-commités :
     * Poster [FRICTION-FOUND] sur dashboard avec liste des fichiers
     * NE PAS créer issue (info seulement)

   **C. Imports morts (exports jamais importés) :**
   - execute_command(shell="powershell", command="Get-ChildItem -Path mcps/internal/servers/roo-state-manager/src -Recurse -Filter '*.ts' | Select-String -Pattern '^export ' | ForEach-Object { $_.Line } | Get-Unique | Measure-Object")
   - execute_command(shell="powershell", command="Get-ChildItem -Path mcps/internal/servers/roo-state-manager -Recurse -Filter '*.ts' | Select-String -Pattern '^import.*from.*src/' | ForEach-Object { $_.Line } | Get-Unique | Measure-Object")
   - SI exports sans imports correspondants :
     * Poster [FRICTION-FOUND] sur dashboard avec ratio exports/imports
     * NE PAS auto-fix (risque de faux positifs)

   **D. Synchronisation schedules.json :**
   - execute_command(shell="powershell", command="if (-not (Test-Path .roo/schedules.json)) { echo 'MISSING' } else { git log -1 --format=%ct -- .roo/schedules.json }")
   - execute_command(shell="powershell", command="git log -1 --format=%ct -- roo-config/modes/modes-config.json")
   - SI schedules.json manquant ou plus vieux que modes-config.json (>1 jour) :
     * Exécuter : execute_command(shell="powershell", command="node roo-config/modes/generate-modes.js")
     * SI succès : poster [PATROL] "schedules.json régénéré"
     * SI échec : poster [FRICTION-FOUND] "Impossible de régénérer schedules.json"

3. Rapport final : domaines vérifiés + résultats + tag [PATROL] si OK ou [FRICTION-FOUND] si problème(s)

IMPORTANT : utilise win-cli MCP (pas le terminal natif).
LIMITES : Auto-fix UNIQUEMENT pour schedules.json (règle claire). Tout autre problème = rapport seulement.
```

**Si problème détecté :** Poster `[FRICTION-FOUND]` sur dashboard workspace avec détails. Pour tests échoués, créer issue GitHub automatiquement.

→ **Ensuite : 1c-idle** (consolidation ou veille complementaire)

### 1c-idle : Consolidation ou Veille Active complementaire

> **Priorité** : Parasite cleanup si détecté, puis Consolidation si disponible, sinon Veille Active complementaire.
> **Note :** La patrouille lecture seule principale est a l'Etape 2b-patrol. Cette etape est un complement.

#### 1c-idle-0 : [PROPOSAL] obligatoire si IDLE (#2215)

**Si aucune tâche n'a été exécutée dans ce cycle (pas de 1a, pas de 1b-2 issue claimée) :**

Poster **exactement 1** `[PROPOSAL]` sur le dashboard workspace avant toute autre action idle :

```
roosync_dashboard(action: "append", type: "workspace", tags: ["PROPOSAL", "roo-scheduler"], content: "[PROPOSAL] {MACHINE} IDLE — Suggestion: {contenu de la proposition}")
```

**Contenu de la proposition** (choisir parmi) :
1. Un domaine d'exploration pertinent (voir Option 2 ci-dessous)
2. Une observation faite pendant le setup/1b-1 (build anomalies, config drift, etc.)
3. Une suggestion d'amélioration harnais basée sur une friction observée ce cycle

**Max 1 PROPOSAL par cycle.** Si un PROPOSAL a déjà été posté ce cycle, ne pas repost.

#### Option 0 : Détection Parasite (#1526, PRIORITAIRE)

**Avant toute autre action idle**, scanner le working dir pour fichiers parasites :

```
execute_command(shell="powershell", command="git status --porcelain | Select-String -Pattern '^\?\? (C|D)$|shared-state-test-|git-archaeology-|debug_' | ForEach-Object { $_.Line }")
```

**Si parasites détectés :**

1. Créer une tâche prioritaire de nettoyage :

   ```text
   Déléguer à code-simple : Supprimer les fichiers parasites détectés :
   - Fichiers <5 bytes à la racine (C, D, etc.)
   - Répertoires .shared-state-test-*/ orphelins
   - Fichiers git-archaeology-*.md mal placés à la racine
   - Fichiers debug_*.{js,ps1} à la racine
   Puis : git status --porcelain pour confirmer le nettoyage.
   ```

2. Poster sur dashboard workspace : `[CLEANUP] {MACHINE} : {N} fichiers parasites nettoyés`

3. Continuer vers Option 1 (Consolidation)

**Si aucun parasite :** Passer à Option 1.

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

#### Option 2 : Veille Active complementaire (si pas de consolidation)

**RÈGLES STRICTES :** LECTURE SEULE. 1 seule exploration par session. Pas de commit/push. Auto-fix INTERDIT (Mandate #1886).

**Sélection pseudo-random déterministe (#2216) :** Au lieu de parcourir les domaines séquentiellement, utiliser un hash du timestamp pour sélectionner un domaine aléatoirement mais de façon reproductible :

```
DOMAIN_INDEX=$(( $(date +%s) % 9 + 1 ))
```

Ou en PowerShell :

```
$domainIndex = ([int](Get-Date -UFormat %s) % 9) + 1
```

Le domaine sélectionné par ce calcul est celui à explorer ce cycle. Ne pas le contourner.

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

Après exploration → **Étape 2**

---

## Étape 2 : Rapport Substantiel + Terminer (OBLIGATOIRE)

> **Budget délégation (#2068) :** Cette étape ne crée PAS de nouvelle délégation. Le rapport est posté par la délégation de l'Étape 1 (tâche), OU par l'orchestrateur via attempt_completion.
>
> **CRITIQUE** : Le rapport est la seule trace du passage du scheduler. Il DOIT être substantiel (#2217).

**Si une tâche a été exécutée à l'Étape 1 (1a ou 1b) :** Le rapport doit avoir été inclus dans la délégation de tâche. Ajouter à TOUTE délégation de tâche l'instruction :

```
APRES avoir terminé la tâche, poster le bilan SUBSTANTIEL sur le dashboard WORKSPACE :

Le rapport DOIT contenir les 4 sections OBLIGATOIRES (#2217) :
1. **Build/Tests** : build OK/FAIL + nombre tests pass/fail (même si non exécuté ce cycle → "non run")
2. **Issues/PRs examinées** : nombre d'issues lues + nombre de PRs reviewées
3. **Veille active** : résultat patrol (OK/détails problème) OU "non requise (<1h)"
4. **Observation** : 1 constat technique, suggestion, ou friction détectée (JAMAIS vide)

Template :
roosync_dashboard(action: "append", type: "workspace", tags: ["{DONE|IDLE|PARTIEL}", "roo-scheduler"], content: "### [{MACHINE}] Bilan Cycle {N}\n\n**Build/Tests :** {OK/Xp/Yf | FAIL: détails | non run}\n**Issues/PRs :** {N} issues examinées, {M} PRs reviewées\n**Veille :** {patrol OK | patrol détails | non requise (<1h)}\n**Observation :** {1 constat ou suggestion}\n\nTâches : {N} ({source}) | Erreurs : {aucune ou description}")
```

**Si STOP (pre-flight échec ou aucune tâche exécutée) :** Poster le rapport directement via attempt_completion :

```
attempt_completion(result: "[{MACHINE}] Cycle executor terminé.\n\nBuild/Tests: {non run — pre-flight FAIL}\nIssues/PRs: 0\nVeille: non requise (STOP)\nObservation: {cause du STOP}\n\nDashboard: {OK/non posté}")
```

### Étape 3 : TERMINER le cycle (OBLIGATOIRE)

```
attempt_completion(result: "Cycle executor terminé. Bilan posté dans dashboard workspace.")
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
