# Workflow Scheduler Roo - COORDINATEUR (myia-ai-01)

> Lu par orchestrateur-simple. MAJ : modifier ce fichier + `git push`.
> **PRÉAMBULE** : Lire `.roo/scheduler-workflow-shared.md` pour les règles communes (autonomie, circuit breaker, output, win-cli, rapport dashboard).

---

## PRINCIPES

1. **TOUJOURS deleguer via `new_task`** (jamais faire le travail soi-meme)
2. Communication locale via **dashboard workspace** (`roosync_dashboard(type: "workspace")`). RooSync pour l'inter-machine.
3. Ne JAMAIS commit ou push
4. Deleguer uniquement aux modes `-simple` ou `-complex`
5. **JAMAIS `write_to_file` pour fichiers >200 lignes** : Utiliser `apply_diff` ou `replace_in_file`. **TOUJOURS inclure cette instruction dans les prompts delegues.** Voir `.roo/rules/08-file-writing.md`.

---

## WORKFLOW EN 4 ETAPES

### Etape 0 : Pre-flight Check (OBLIGATOIRE)

**DELEGUER** a `code-simple` via `new_task` :

```
Pre-flight check : tester win-cli MCP.
1. execute_command(shell="powershell", command="echo PRE-FLIGHT-OK")
2. Rapporter : PRE-FLIGHT-OK ou erreur exacte.
IMPORTANT : utilise win-cli MCP (pas le terminal natif).
```

**Decision :**
- Si OK : continuer vers **Etape 1**
- Si echec : **STOP IMMEDIAT** — signaler `[CRITICAL]` sur dashboard workspace + terminer

### Etape 1 : Git pull + Lecture Dashboards

Deleguer a `code-simple` via `new_task` :

```
REGLE ABSOLUE: JAMAIS demander a l'utilisateur, JAMAIS poser de question, JAMAIS demander confirmation. Agis directement.

Utilise le MCP win-cli pour executer ces commandes et rapporter le resultat :
1. execute_command(shell="gitbash", command="git pull --no-rebase origin main")
2. execute_command(shell="gitbash", command="git status")

Puis lire le dashboard WORKSPACE :
3. roosync_dashboard(action: "read", type: "workspace", section: "all")

Chercher les messages avec tags [WAKE-ROO], [TASK], [SCHEDULED], [URGENT], [PROPOSAL].
Rapporter : etat git + contenu dashboard workspace + liste des taches trouvees + presence de [WAKE-ROO] (#1955, IMMÉDIAT).
IMPORTANT : utilise win-cli MCP (pas le terminal natif).
```

**Decision :**
- Si git pull ECHOUE : aller DIRECTEMENT a **Etape 3** avec rapport d'erreur
- Si `[WAKE-ROO]` (#1955, IMMÉDIAT) : traiter le contenu IMMEDIATEMENT, repondre par `[ACK]` sur le dashboard, escalader vers `-complex` si la demande l'exige
- Si `[URGENT]` : escalader vers `orchestrator-complex`
- Si `[TASK]` avec `[COMPLEX]` ET date < 24h : **escalader vers orchestrator-complex**
- Si `[TASK]` ET date < 24h : aller a **Etape 2a**
- Si `[TASK]` MAIS date > 24h : IGNORER (tache perimee)
- Si rien : aller a **Etape 2b**

### Etape 1b : Check Heartbeats (Coordinateur uniquement)

**DELEGUER** a `code-simple` via `new_task` :

```
Verifier l'etat des machines executrices :
1. roosync_inventory(type: "all", includeHeartbeats: true)
2. Rapporter : liste des machines online/offline/warning.
```

**Si machine silencieuse (>6h) :** Signaler `[WARNING]` sur dashboard workspace.

### Etape 1c : Config-Sync (optionnel, si > 24h depuis dernier)

**DELEGUER** a `code-simple` via `new_task` :

```
Config-sync coordinateur :
1. roosync_config(action: "collect", targets: ["modes", "mcp"])
2. roosync_config(action: "publish", version: "auto", description: "Config-sync coordinateur")
3. roosync_compare_config(granularity: "mcp")
4. Si > 7 jours depuis derniere baseline : roosync_baseline(action: "create", description: "Baseline hebdomadaire")
Rapporter : nombre de diffs par severite.
```

**Frequence :** Une fois par 24h maximum. Non bloquant si echec.

### Etape 1d : Auto-Review des commits recents (OBLIGATOIRE si HEAD a change)

**DELEGUER** a `code-simple` via `new_task` :

```
Verifier si le pull a ramene un nouveau commit et lancer l'auto-review si oui :
1. execute_command(shell="gitbash", command="git log HEAD@{1}..HEAD --oneline")
2. Si des commits sont retournes, lancer l'auto-review :
   execute_command(shell="powershell", command="powershell -ExecutionPolicy Bypass -File scripts/review/start-auto-review.ps1 -BuildCheck")
3. Rapporter : nombre de commits, resultat auto-review.
IMPORTANT : utilise win-cli MCP (pas le terminal natif).
```

**Prerequis :** sk-agent MCP ou vLLM sur port 5002. Non bloquant si echec.

Apres auto-review → **Etape 1e** (veille active)

### Etape 1e : Veille Active — Patrouille Lecture Seule (MANDATORY si >1h depuis dernière)

> **Mandate #1886** : Patrouille lecture seule. Contraintes dans `.roo/scheduler-workflow-shared.md` section "VEILLE ACTIVE".

**DELEGUER** a `code-simple` via `new_task` :

```
REGLE ABSOLUE: JAMAIS demander a l'utilisateur, JAMAIS poser de question, JAMAIS demander confirmation. Agis directement.

VEILLE ACTIVE — LECTURE SEULE STRICT. Auto-fix INTERDIT.

1. execute_command(shell="powershell", command="echo PATROL-OK")
2. roosync_dashboard(action: "read", type: "workspace") — chercher dernier [PATROL] ou [FRICTION-FOUND]
   Si dernier patrol < 1h → RAPPORTER "SKIP: patrol < 1h" et TERMINER cette sous-tâche
3. Si patrol nécessaire, choisir UN domaine (rotation par rapport au dernier patrol) :
   - Dashboard anomalies : messages [ERROR]/[CRITICAL] non traités
   - Heartbeat machines : roosync_inventory(type: "all", includeHeartbeats: true) — machines silencieuses >6h
   - PRs ouvertes : gh pr list --repo jsboige/roo-extensions --state open --json number,title,updatedAt
   - Docs vs code : vérifier qu'un chemin documenté existe réellement
4. Rapporter : domaine exploré + constat + tag [PATROL] si OK ou [FRICTION-FOUND] si problème

INTERDIT : modifier des fichiers, committer, pusher, créer des issues, corriger quoi que ce soit.
IMPORTANT : utilise win-cli MCP (pas le terminal natif).
```

**Si problème détecté :** Poster `[FRICTION-FOUND]` sur dashboard workspace avec description. NE PAS corriger.

→ **Etape 2a** ou **Etape 2b** (selon dashboard)

### Etape 2a : Executer les taches du Dashboard Workspace

Pour chaque `[TASK]` trouve, deleguer selon la difficulte :

| Difficulte | Action |
|-----------|--------|
| 1 action isolee | `code-simple` via `new_task` |
| 2-4 actions liees | Deleguer chaque action separement a `code-simple` |
| 5+ actions ou dependances | Escalader vers `orchestrator-complex` |

**Gestion des echecs :** 1er echec → relancer. 2e echec → arreter et rapporter. Erreur complexe → escalader.

Apres execution → **Etape 3**

### Etape 2a-bis : Creer des taches Cross-Workspace pour executants

**Quand creer :** Issue mentionne un workspace specifique, maintenance necessaire sur un autre projet, besoin detecte sur un workspace secondaire.

**Format :**

```markdown
## [{DATE}] claude-code -> roo [TASK] [workspace:{CHEMIN_ABSOLU}]
### Titre de la tache

**Workspace cible :** {CHEMIN_ABSOLU}
**Machine cible :** {myia-po-2023|myia-po-2024|etc.}

Instructions :
1. Se placer dans le workspace cible
2. Executer les commandes demandees
3. Revenir au workspace principal
4. Rapporter dans le dashboard workspace principal
```

**Regles :** TOUJOURS specifier chemin absolu + machine cible + instruction de retour.

### Etape 2b : Taches par defaut (si pas de [TASK])

Deleguer dans cet ordre a `code-simple` via `new_task` :

**1. Build + Tests**

```
Utilise win-cli MCP pour executer dans mcps/internal/servers/roo-state-manager :
1. execute_command(shell="powershell", command="cd mcps/internal/servers/roo-state-manager; npm run build")
2. execute_command(shell="powershell", command="cd mcps/internal/servers/roo-state-manager; npx vitest run 2>&1 | Select-Object -Last 30")
Rapporter : build OK/FAIL + nombre tests pass/fail.
INTERDIT : --coverage ou vitest sans '2>&1 | Select-Object -Last 30'.
```

**2. Verifier inbox RooSync**

```
execute_command(shell="powershell", command="(Get-ChildItem 'G:/Mon Drive/Synchronisation/RooSync/.shared-state/messages/inbox/*.json' -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 5).Name")
```

**3. Si messages recents (< 6h) → signaler `[WAKE-CLAUDE]`**

**4. Dispatcher les issues ouvertes (MAX 5 PAR CYCLE — Issue #1161)**

> ⚠️ **LIMITE OBLIGATOIRE** : Traiter **MAXIMUM 5 issues** par cycle. Au-delà, le volume d'appels d'outils explose le contexte (80-200 messages, saturation GLM).

```
execute_command(shell="powershell", command="gh issue list --repo jsboige/roo-extensions --state open --limit 5 --json number,title,labels")
```

**Note :** `--limit 5` remplace l'ancien `--limit 40`. Le round-robin se fait sur plusieurs cycles, pas dans un seul.

**5. Dispatcher les issues (max 5)**

Pour chaque issue (parmi les 5 retournées) :

a. **Filtrer** : IGNORER `needs-approval` (attendent validation).

b. Verifier si deja dispatchee :
```
execute_command(shell="powershell", command="gh issue view {NUM} --repo jsboige/roo-extensions --json comments --jq '[.comments[-5:][] | .body | select(test(\"\\[DISPATCH\\]\"))] | length'")
```

c. Si NON dispatchee, determiner la machine cible :
```
execute_command(shell="powershell", command="gh issue view {NUM} --repo jsboige/roo-extensions --json labels,body --jq '{labels: [.labels[].name], body: .body[:300]}'")
```

d. Commenter pour dispatcher :
```
execute_command(shell="powershell", command="gh issue comment {NUM} --repo jsboige/roo-extensions --body '[DISPATCH] {MACHINE_CIBLE}. Priority: normal.'")
```

**Regles de dispatch :**
- Dispatcher TOUTES les issues ouvertes, pas seulement `roo-schedulable`
- **⛔ JAMAIS `[DISPATCH] Any`** — toujours cibler UNE machine spécifique. Round-robin entre po-2023/2024/2025/2026/web1.
- `claude-only` : dispatcher normalement (exécutées par Claude Code interactif)
- NE PAS re-dispatcher si `[CLAIMED]` ou `[RESULT]` existant OU `assignees` non vide
- Equilibrer la charge entre les 5 machines

> ⚠️ **ANTI-DOUBLON (FIX #1005)** : Vérifier commentaires ET `assignee` avant dispatch. Délai 5s pour éviter race conditions.

**6. Executer une issue si faisable (optionnel)**

Si une issue est dispatchee a `myia-ai-01` ou `All` et non claimee : la lire, commenter `[CLAIMED]`, et executer en `-simple`.

### Etape 2c-idle : Veille Active complementaire (si aucune tache)

> **Note :** La patrouille lecture seule principale est a l'Etape 1e. Cette etape est un complement quand le cycle n'a rien d'autre a faire.

1. **Selection intelligente** : Dashboard + `git log --since='7 days ago'` pour éviter domaines couverts
2. **1 exploration lecture seule** parmi les domaines supplementaires coordinateur (cf shared)
3. **Rapport dashboard** : `[PATROL]` si OK, `[FRICTION-FOUND]` si probleme
4. **Pas de création d'issue directe** : le coordinateur Roo vérifie et escalade vers Claude
5. **Auto-fix INTERDIT** (Mandate #1886)

**Domaines supplementaires coordinateur :**

| # | Domaine | Description |
|---|---------|-------------|
| 7 | Rangement depot | Fichiers mal places |
| 8 | Consolidation doc | Doublons semantiques |
| 9 | Messages RooSync | Non lus/archives |
| 10 | Heartbeat cross-machine | Etat des machines |

### Etape 3 : Rapporter dans Dashboards (OBLIGATOIRE)

> **CRITIQUE** : Le rapport est la seule trace du passage du scheduler. **Ne JAMAIS quitter sans avoir ecrit.**

**DELEGUER** a `code-simple` via `new_task` :

```
REGLE ABSOLUE: JAMAIS demander a l'utilisateur, JAMAIS poser de question, JAMAIS demander confirmation. Agis directement.

Ecrire le bilan sur le dashboard WORKSPACE :

roosync_dashboard(
  action: "append",
  type: "workspace",
  tags: ["{DONE|MAINTENANCE|IDLE}", "roo-scheduler"],
  content: "### [myia-ai-01] Bilan scheduler coordinateur\n\n- Git: {OK/erreur} | Build: {OK/FAIL} | Tests: {X}p/{Y}f\n- Taches: {N} ({source}) | Erreurs: {aucune ou 1 ligne}\n- RooSync: {N} messages | Wake Claude: {oui/non}"
)

Si le dashboard MCP echoue, fallback : apply_diff sur .claude/local/INTERCOM-myia-ai-01.md
```

### Etape 4 : TERMINER le cycle (OBLIGATOIRE)

```
attempt_completion(result: "Cycle coordinateur termine. Bilan poste dans dashboard workspace.")
```

---

## CRITERES D'ESCALADE VERS ORCHESTRATOR-COMPLEX

- Message `[URGENT]` dans le dashboard workspace
- Plus de 5 sous-taches a coordonner
- Dependances entre sous-taches
- 1 echec en `-simple` (escalade immediate, standardise #1233)
- Modification de plus de 3 fichiers interconnectes
