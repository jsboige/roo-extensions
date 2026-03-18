# Executor Workflow - Orchestrator Roo

> Lu par orchestrateur-simple sur les machines executrices. MAJ : modifier + `git push`.

---

## ⚠️ RÈGLE #1 - INTERDICTION ABSOLUE DE DEMANDER À L'UTILISATEUR

**QUAND tu as besoin de lire ou écrire un fichier : DELEGUE immédiatement via `new_task` à un mode qui a l'accès (ask-simple, code-simple, debug-simple).**

### ❌ JAMAIS FAIRE (bloque le scheduler)

```
# NE JAMAIS écrire ça :
"Pourriez-vous copier le contenu du fichier .roo/scheduler-workflow-executor.md ?"
"Merci de coller le contenu de .claude/local/INTERCOM-myia-po-2024.md ici."
"Pouvez-vous me transmettre le contenu de ce fichier ?"
```

**Pourquoi c'est interdit ?** Cela bloque le scheduler en attendant une intervention humaine. L'orchestrateur DOIT être autonome.

### ✅ TOUJOURS FAIRE (délégation immédiate)

```javascript
// QUAND tu as besoin de lire un fichier, délégue immédiatement :
await new_task({
  title: "Lire le fichier de workflow",
  instructions: `
Lire le fichier .roo/scheduler-workflow-executor.md avec read_file.
Retourner un résumé des instructions.
  `
});

// QUAND tu as besoin de lire l'INTERCOM, délégue immédiatement :
await new_task({
  title: "Lire INTERCOM local",
  instructions: `
Lire .claude/local/INTERCOM-myia-po-2024.md avec read_file.
Retourner les 5 derniers messages avec tags [DONE], [TASK], [WARN].
  `
});
```

**Même si un outil échoue** : NE DEMANDE JAMAIS à l'utilisateur. Délégue à un autre mode qui a l'outil.

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

## Workflow Executor

**Machine:** {MACHINE} (myia-po-* ou myia-web1)
**Fréquence:** 3 heures
**Mode:** orchestrator-simple (délègue tout via new_task)

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
4. **TOUJOURS rapporter dans INTERCOM** - Même si 0 tâches
5. **win-cli OBLIGATOIRE pour shell** - Les modes `-simple` n'ont PAS le terminal natif
6. **Identifiants de modes OBLIGATOIRES** : `code-simple`, `ask-simple`, `debug-simple`, `code-complex`, `ask-complex`, `debug-complex`, `orchestrator-simple`, `orchestrator-complex`
7. **Escalade agressive** : 1 échec en `-simple` → immédiatement vers `-complex`
8. **JAMAIS `write_to_file` pour fichiers >200 lignes** : Utiliser `apply_diff` ou `replace_in_file`

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
- Écrire dans INTERCOM avec `[CRITICAL]` : win-cli MCP non disponible
- Terminer la tâche sans déléguer d'autres sous-tâches

---

## Étape 1 : Git Pull + Lecture INTERCOM

**DÉLEGUER à `code-simple` via `new_task` :**

```
Executer ces commandes avec win-cli MCP et rapporter le résultat :
1. execute_command(shell="gitbash", command="git pull --no-rebase origin main")
2. execute_command(shell="gitbash", command="git status")
Puis lire les 5 derniers messages de .claude/local/INTERCOM-{MACHINE}.md
Chercher les messages [TASK], [SCHEDULED], [URGENT], [PROPOSAL].
Rapporter : état git + liste des tâches/propositions trouvées.
```

**Décision :**
- Si git pull a ÉCHOUÉ → aller à **Étape 3** avec rapport d'erreur
- Si `[URGENT]` → escalader vers `orchestrator-complex`
- Si `[TASK]` ou `[PROPOSAL]` trouvé avec tag `[COMPLEX]` ET date < 24h → **escalader vers orchestrator-complex**
- Si `[TASK]` ou `[PROPOSAL]` trouvé ET date < 24h → aller à **Étape 2a** (traiter `[PROPOSAL]` comme `[TASK]`)
- Si `[TASK]` trouvé MAIS date > 24h → IGNORER
- Si rien → aller à **Étape 2b**

---

## Étape 2a : Exécuter les tâches INTERCOM

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
- Écrire `[INCIDENT-SIMPLE]` dans INTERCOM pour CHAQUE escalade
- Ne PAS relancer en -simple

Après exécution → **Étape 3**

---

## Étape 2b : Tâches par défaut (si pas de [TASK])

> ⚠️ **OBLIGATION CRITIQUE (Bug #702)** : L'Étape 2b comprend TOUJOURS 4 sous-étapes séquentielles.

**CHECKLIST SOUS-ÉTAPES OBLIGATOIRES (toutes à exécuter) :**

```
☐ 2b-1 : Build + Tests (validation santé workspace)
☐ 2b-2 : GitHub issues (chercher une tâche roo-schedulable)
☐ 2b-review : PR Review (reviewer les PRs ouvertes)
☐ 2c-idle : Veille Active ou Consolidation (toujours, même si rien à faire)
→ SEULEMENT ENSUITE : Étape 3
```

### 2b-1 : Build + Tests

```
Executer dans mcps/internal/servers/roo-state-manager avec win-cli :
1. execute_command(shell="powershell", command="npm run build")
2. execute_command(shell="powershell", command="npx vitest run")
Rapporter : build OK/FAIL + nombre tests pass/fail.
```

> **Note MyIA-Web1** : Toujours utiliser `npx vitest run --maxWorkers=1`

### 2b-2 : GitHub Issues (dispatch-aware)

**Etape A — Lister les issues roo-schedulable :**

```
execute_command(shell="powershell", command="gh issue list --repo jsboige/roo-extensions --state open --limit 30 --label roo-schedulable --json number,title,labels")
```

**Etape B — Selectionner une issue (ordre de priorite) :**

Pour les 5 premieres issues de la liste, verifier les derniers commentaires :
```
execute_command(shell="powershell", command="gh issue view {NUM} --repo jsboige/roo-extensions --json comments --jq '[.comments[-5:][] | .body] | join(\"\\n---\\n\")'")
```

**Priorite de selection :**
1. **Issue dispatchee a cette machine** : commentaire contenant `[DISPATCH] {MACHINE}` → executer en priorite
2. **Issue dispatchee a `All` ou `Any`** : commentaire `[DISPATCH] All` ou `[DISPATCH] Any` → disponible
3. **Issue non dispatchee et non claimee** : aucun commentaire `[DISPATCH]` ni `[CLAIMED]` → claimer et executer
4. **Issue claimee par une autre machine** : commentaire `[CLAIMED] by {AUTRE_MACHINE}` → PASSER, ne pas executer

Si une issue est trouvee :
1. Lire le body complet avec labels : execute_command(shell="powershell", command="gh issue view {NUM} --repo jsboige/roo-extensions --json title,body,labels")
2. **VERIFIER LES LABELS** avant de choisir le mode d'execution :
   - Si labels contiennent `enhancement` ou `feature` : **DELEGUER A `code-complex`** (pas code-simple)
   - Si labels contiennent `bug` avec complexite inconnue : commencer avec `code-complex`
   - Sinon : utiliser `code-simple` pour taches simples (doc, tests, validation)
3. Commenter pour claim : execute_command(shell="powershell", command="gh issue comment {NUM} --body \"[CLAIMED] by {MACHINE} (Roo scheduler). Mode: {simple/complex}.\"")
4. Executer selon difficulte (simple → `code-simple`, complexe → `code-complex`)
5. Commenter le resultat : execute_command(shell="powershell", command="gh issue comment {NUM} --body \"[RESULT] {MACHINE}: {PASS/FAIL}. Mode: {simple/complex}. Commit: {hash-si-applicable}.\"")

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

## Étape 3 : Rapporter dans INTERCOM (OBLIGATOIRE)

> **CRITIQUE** : L'écriture INTERCOM est la seule trace du passage du scheduler.

**DÉLEGUER à `code-simple` via `new_task` :**

```
Ajouter le bilan scheduler à la fin de .claude/local/INTERCOM-{MACHINE}.md :
1. Lis les 20 DERNIERES lignes du fichier avec read_file
2. Utilise apply_diff pour ajouter le message APRES le dernier séparateur ---
3. Si apply_diff échoue : utilise win-cli Add-Content
4. NE PAS utiliser write_to_file (boucle infinie sur gros fichiers)

Message à ajouter :
[INSERER LE BILAN CI-DESSOUS]
```

**FORMAT MESSAGE (max 8 lignes) :**

```markdown
## [{DATE}] roo -> claude-code [{DONE|IDLE|PARTIEL}]
- Git: {OK/erreur} | Build: {OK/FAIL} | Tests: {X}p/{Y}f
- Heartbeat: {OK/ECHEC} | Tâches: {N} ({source})
- Erreurs: {aucune ou description 1 ligne}
---
```

**⚠️ REGLE ANTI-FAUX-POSITIF** : Le bilan DOIT refléter la réalité. Ne JAMAIS dire "Tout OK" si un échec est survenu.

---

## Chaîne d'escalade

`code-simple` → `code-complex` → **Claude Code CLI** (via `[ESCALADE-CLAUDE]`)

**Escalade OBLIGATOIRE vers `code-complex` pour :**
- Issue GitHub avec label `enhancement` ou `feature`
- Message `[URGENT]` dans l'INTERCOM
- Modification de >2 fichiers interconnectés
- Schéma Zod complexe (`refine()`, validation conditionnelle)
- >5 sous-tâches ou dépendances

**Escalade après échec (RÈGLE AGRESSIVE) :**
- **1 seul échec en `-simple`** → escalade IMMEDIATE vers `-complex`
- Ne PAS retenter en `-simple`
- Écrire `[INCIDENT-SIMPLE]` dans INTERCOM
- **1 seul échec en `-complex`** → escalade IMMEDIATE vers Claude Code CLI
- Ne PAS retenter en `-complex`
- Écrire `[INCIDENT-COMPLEX]` dans INTERCOM

### Escalade vers Claude Code CLI (nouveau)

Quand un mode `-complex` échoue sur une tâche, le scheduler peut demander l'aide de Claude Code via la CLI `claude`. C'est un modèle plus puissant (Opus/Sonnet) capable de résoudre des problèmes architecturaux complexes.

**Déclencheur :** 1 échec en mode `-complex` (quel que soit le type : code-complex, debug-complex)

**Procédure :**
1. Écrire dans INTERCOM : `[ESCALADE-CLAUDE] Tâche {description}. Échec en {mode}. Erreur: {résumé}.`
2. Déléguer à `code-complex` pour exécuter la commande CLI :
```
execute_command(shell="powershell", command="claude -p 'Résoudre cette tâche: {DESCRIPTION}. Contexte: {ERREUR}. Fichiers concernés: {FICHIERS}. Exécuter le fix et rapporter le résultat.' --max-turns 10 --model sonnet")
```
3. Si Claude CLI résout → commenter l'issue GitHub avec `[RESULT] {MACHINE}: PASS (escalade Claude CLI). Commit: {hash}.`
4. Si Claude CLI échoue aussi → commenter `[RESULT] {MACHINE}: FAIL (escalade Claude CLI). Nécessite intervention manuelle.` et écrire `[ERROR]` dans INTERCOM.

**Garde-fous :**
- Maximum **2 escalades Claude CLI par session** scheduler (éviter les coûts excessifs)
- Préférer `--model sonnet` (économique). Utiliser `--model opus` uniquement si sonnet échoue
- Timeout : `--max-turns 10` pour limiter la durée
- Documenter CHAQUE escalade dans INTERCOM avec le résultat
