# Pipeline Qualité Automatique - Documentation Technique

**Issue :** #544
**Créé :** 2026-03-01
**Status :** COMPLETE ✅

---

## Vue d'ensemble

Système automatique de validation qui s'exécute à **chaque commit significatif sur main** :
1. Build + tests (validation technique)
2. Review IA via sk-agent (analyse de qualité)
3. Commentaire GitHub sur l'issue associée

---

## Architecture

```
Commit sur main (jsboige push)
  ↓
Déclenchement automatique (3 sources possibles)
  ↓ (1) Roo Scheduler Coordinateur (myia-ai-01, tick 3h)
  ↓ (2) Roo Scheduler Executeur (5 machines, tick 3h)
  ↓ (3) Claude Worker (myia-ai-01, tick 3h)
  ↓
Git pull origin main
  ↓
Détection HEAD changed (git rev-parse HEAD)
  ↓
start-auto-review.ps1 -BuildCheck
  ↓
auto-review.ps1 : diff → build → tests → sk-agent critic
  ↓
GitHub comment sur issue #NNN
```

---

## Implémentation par Phase

### Phase 1 : Scheduler Roo (6 machines) ✅

**Coordinateur** (myia-ai-01)
- Fichier : `.roo/scheduler-workflow-coordinator.md`
- Section : Étape 1d (lignes 141-160)
- Déclenchement : Après `git pull` (Étape 1)

**Executeurs** (myia-po-2023, 2024, 2025, 2026, myia-web1)
- Fichier : `.roo/scheduler-workflow-executor.md`
- Section : Étape 2c (lignes 282-307)
- Déclenchement : Après `git pull` (Étape 1)

**Code :**
```bash
execute_command(shell="gitbash", command="git log --oneline -2")
# Si nouveau commit détecté :
execute_command(shell="powershell", command="powershell -ExecutionPolicy Bypass -File scripts/review/start-auto-review.ps1 -BuildCheck")
```

### Phase 2 : Claude Worker (myia-ai-01) ✅

**Fichier :** `scripts/scheduling/start-claude-worker.ps1`

**Phase 0.5 : Git Sync + Auto-Review** (lignes 1636-1648)
- Exécutée AVANT la récupération des tâches
- Non-bloquante (timeout 120s)
- Fallback gracieux si échec

**Fonction :** `Invoke-GitSyncAndReview` (lignes 1493-1593)

**Code :**
```powershell
# Record HEAD before pull
$oldHead = (git -C $RepoRoot rev-parse HEAD 2>&1).Trim()

# Pull
git -C $RepoRoot pull --no-rebase origin main 2>&1

# Check if HEAD changed
$newHead = (git -C $RepoRoot rev-parse HEAD 2>&1).Trim()

if ($newHead -ne $oldHead) {
    # Trigger auto-review with build gate
    $reviewArgs = @("-BuildCheck")
    if ($DryRun) { $reviewArgs += "-DryRun" }

    # Calculate diff range based on commit count
    $commitCount = (git -C $RepoRoot rev-list "$oldHead..$newHead" --count).Trim()
    if ([int]$commitCount -gt 1) {
        $reviewArgs += "-DiffRange", "HEAD~$commitCount"
    }

    # Execute with timeout
    $reviewJob = Start-Job { & powershell -File $script @args }
    Wait-Job $reviewJob -Timeout 120
}
```

### Phase 3 : Build Gate ✅

**Fichier :** `scripts/review/auto-review.ps1`

**Section :** Lignes 104-147 (Step 3b)

**Paramètre :** `-BuildCheck`

**Workflow :**
1. Résoudre `mcps/internal/servers/roo-state-manager`
2. Build : `npm run build --prefix $buildDir`
3. Tests : `npx vitest run --maxWorkers=1 --prefix $buildDir`
4. Si build FAIL → post immédiat GitHub (avant LLM review)
5. Section Build Gate dans la review finale

**Code :**
```powershell
if ($BuildCheck) {
    $buildDir = Join-Path $ScriptDir "..\..\mcps\internal\servers\roo-state-manager"

    # Build
    $buildOutput = & npm run build --prefix $buildDir 2>&1 | Select-Object -Last 10
    $buildOk = ($LASTEXITCODE -eq 0)

    # Tests (maxWorkers=1 for low-RAM machines)
    $testOutput = & npx vitest run --maxWorkers=1 --prefix $buildDir 2>&1 | Select-Object -Last 20
    $testOk = ($LASTEXITCODE -eq 0)

    if (-not $buildOk) {
        # Post build failure immediately
        $buildFailComment = "⚠️ **Build FAILED** on commit ``$shortHash``..."
        gh issue comment $IssueNumber --body $buildFailComment
    }
}
```

**Output :**
```markdown
### Build Gate ✅
| Check | Status |
|-------|--------|
| Build | PASS |
| Tests | PASS (3308 tests) |
```

---

## Scripts

### `start-auto-review.ps1`

**Rôle :** Wrapper appelé par les schedulers

**Localisation :** `scripts/review/start-auto-review.ps1`

**Usage :**
```powershell
powershell -ExecutionPolicy Bypass -File scripts/review/start-auto-review.ps1
```

**Code :**
```powershell
$autoReviewScript = Join-Path $PSScriptRoot "auto-review.ps1"
& $autoReviewScript
exit $LASTEXITCODE
```

### `auto-review.ps1`

**Rôle :** Pipeline complet (diff → build → tests → review → GitHub)

**Localisation :** `scripts/review/auto-review.ps1`

**Paramètres :**
- `-DiffRange "HEAD~3"` : Range de commits à reviewer
- `-IssueNumber 535` : Issue cible (sinon auto-détecté via commit message)
- `-Mode vllm` : Forcer vLLM direct (skip sk-agent HTTP)
- `-BuildCheck` : Activer build gate
- `-DryRun` : Afficher la review sans poster

**Usage :**
```powershell
# Review HEAD vs HEAD~1 avec build gate
powershell -ExecutionPolicy Bypass -File scripts/review/auto-review.ps1 -BuildCheck

# Review 3 derniers commits sans build
powershell -ExecutionPolicy Bypass -File scripts/review/auto-review.ps1 -DiffRange "HEAD~3"

# Test en dry-run
powershell -ExecutionPolicy Bypass -File scripts/review/auto-review.ps1 -DryRun -IssueNumber 544
```

**Workflow :**
1. Git commit info (`git rev-parse HEAD`, `git log --format="%s"`)
2. Git diff (`git diff $DiffRange HEAD`)
3. Détection issue (#NNN pattern dans commit message)
4. Build gate (si `-BuildCheck`)
5. sk-agent critic (fallback vLLM si HTTP échec)
6. Format review (markdown avec findings table)
7. Post GitHub (`gh issue comment $IssueNumber --body-file -`)

---

## Détection d'issue

**Patterns supportés :**
```regex
(?i)(?:fix|close|resolve)[\s\-]*#(\d+)  # fix #123
(?i)issue[\s\-]*#(\d+)                   # issue #123
#(\d+)                                   # #123
```

**Exemples de commits détectés :**
```
docs(issue-543): Phase 1 complete        → Issue #543
fix #496: Auto-approval config bug       → Issue #496
Close issue #485 - sk-agent exploit      → Issue #485
```

---

## sk-agent Integration

**Mode HTTP :**
- Endpoint : `http://localhost:5000` (sk-agent MCP)
- Agent : `critic`
- Fallback automatique vers vLLM si échec

**Mode vLLM (fallback) :**
- Endpoint : `http://localhost:5002/v1` (Qwen3.5-35B-AWQ)
- API OpenAI-compatible
- Pas de dépendance sk-agent

**Code :**
```powershell
$reviewResult = & "$ScriptDir\call-sk-agent.ps1" `
    -Prompt $reviewPrompt `
    -Agent "critic" `
    -Mode $Mode
```

**Output format :**
```markdown
## Auto-Review

1. Summary
[Concise 2-3 sentences summary]

2. Findings table
| Severity | Category | Description |
|----------|----------|-------------|
| Critical | Security | SQL injection vulnerability... |

3. Final verdict: APPROVE / APPROVE WITH FIXES / REJECT
```

---

## Machines & Configuration

| Machine | Scheduler | Worker | Build Gate | Contraintes |
|---------|-----------|--------|------------|-------------|
| **myia-ai-01** | ✅ Coord | ✅ Phase 0.5 | ✅ -BuildCheck | sk-agent HTTP + vLLM |
| **myia-po-2023** | ✅ Exec | N/A | ✅ -BuildCheck | vLLM fallback |
| **myia-po-2024** | ✅ Exec | N/A | ✅ -BuildCheck | vLLM fallback |
| **myia-po-2025** | ✅ Exec | N/A | ✅ -BuildCheck | vLLM fallback |
| **myia-po-2026** | ✅ Exec | N/A | ✅ -BuildCheck | vLLM fallback |
| **myia-web1** | ✅ Exec | N/A | ⚠️ --maxWorkers=1 | RAM 2GB |

**Note myia-web1 :**
- Contrainte RAM 2GB → Build gate avec `--maxWorkers=1`
- Déjà géré dans auto-review.ps1 ligne 118
- Taux de succès attendu : 99.6% (3294/3308)

---

## Monitoring

### Vérifier les auto-reviews

```powershell
# Logs Roo scheduler
Get-ChildItem "$env:APPDATA\Code\User\globalStorage\rooveterinaryinc.roo-cline\tasks" |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 5

# Logs Claude worker
Get-ChildItem ".claude\logs\worker-*.log" |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 5
```

### Métriques GitHub

```bash
# Lister les auto-reviews postées
gh issue list --repo jsboige/roo-extensions --search "Auto-review by sk-agent"

# Statistiques d'une issue spécifique
gh issue view 544 --repo jsboige/roo-extensions --json comments
```

---

## Tests & Validation

### Test complet (dry-run)

```powershell
powershell -ExecutionPolicy Bypass -File scripts/review/auto-review.ps1 `
    -DiffRange a3228bb5~1 `
    -IssueNumber 543 `
    -BuildCheck `
    -DryRun
```

**Output attendu :**
```
[AUTO-REVIEW] Starting review (range: a3228bb5~1, mode: http)
[AUTO-REVIEW] Commit: 3ed57a9 - docs(issue-543): Session completion...
[AUTO-REVIEW] Diff: 2243 chars
[AUTO-REVIEW] Build gate PASSED (3308 tests)
[AUTO-REVIEW] Review received (1171 chars)
[AUTO-REVIEW] DRY RUN - Would post to #543
```

### Test build gate uniquement

```powershell
cd mcps/internal/servers/roo-state-manager
npm run build
npx vitest run --maxWorkers=1
```

### Test sk-agent

```powershell
# Via HTTP (sk-agent MCP)
scripts/review/call-sk-agent.ps1 -Prompt "Test review" -Agent "critic" -Mode http

# Via vLLM direct
scripts/review/call-sk-agent.ps1 -Prompt "Test review" -Agent "critic" -Mode vllm
```

---

## Troubleshooting

### Build gate échoue

**Symptôme :** Build ou tests échouent, aucun commit GitHub posté

**Diagnostic :**
1. Vérifier build local : `npm run build`
2. Vérifier tests local : `npx vitest run`
3. Consulter logs scheduler : `%APPDATA%\Code\User\globalStorage\rooveterinaryinc.roo-cline\tasks`

**Solution :**
- Corriger le build/tests avant de commit
- Ou désactiver `-BuildCheck` temporairement

### sk-agent timeout

**Symptôme :** Review partielle ou vide

**Diagnostic :**
1. Vérifier sk-agent MCP : `Get-Process | Where-Object { $_.Name -like "*node*" }`
2. Tester vLLM direct : `curl http://localhost:5002/v1/models`

**Solution :**
- Redémarrer sk-agent MCP
- Utiliser mode vLLM : `-Mode vllm`

### Aucune review postée

**Symptôme :** Pipeline s'exécute mais pas de commentaire GitHub

**Diagnostic :**
1. Vérifier détection issue : commit message contient `#NNN` ?
2. Vérifier gh CLI : `gh auth status`

**Solution :**
- Forcer issue : `-IssueNumber 544`
- Re-auth gh : `gh auth refresh --hostname github.com -s project`

---

## Références

- **Issue #544 :** Pipeline qualité automatique
- **Issue #535 :** sk-agent auto-review pipeline (précédent)
- **Documentation sk-agent :** `mcps/internal/servers/sk-agent/README.md`
- **Workflows scheduler :** `.roo/scheduler-workflow-*.md`

---

**Dernière mise à jour :** 2026-03-01
**Mainteneur :** Coordinateur RooSync (myia-ai-01)
