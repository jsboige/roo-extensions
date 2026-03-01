# Auto-Review Pipeline - Quality Gate

**Issue:** #544 - Pipeline qualité automatique
**Status:** ✅ IMPLEMENTED (Phase 1-3 complete)

## Overview

The auto-review pipeline automatically validates every commit pushed to `main` with:

1. **Build gate** - Validates TypeScript compilation
2. **Test gate** - Runs unit tests (maxWorkers=1 for low-RAM machines)
3. **AI review** - sk-agent analyzes code changes
4. **GitHub post** - Results posted to the associated issue

## Architecture

```
Commit sur main
  ↓
Scheduler tick (3h) / Claude Worker start
  ↓
Git pull → HEAD changed?
  ↓ Yes
scripts/review/start-auto-review.ps1 -BuildCheck
  ↓
1. npm run build → FAIL → Post "Build FAILED" comment (stop)
2. npx vitest run --maxWorkers=1 → Record results
3. sk-agent review → Generate structured review
4. gh issue comment → Post to issue #NNN
```

## Integration Points

### 1. Roo Scheduler (Coordinateur - myia-ai-01)

**File:** `.roo/scheduler-workflow-coordinator.md`
**Step:** Étape 1d (line 141-160)

```markdown
Si HEAD a change depuis le dernier tick (nouveau commit) :

1. Lancer l'auto-review via sk-agent :
   execute_command(shell="powershell", command="powershell -ExecutionPolicy Bypass -File scripts/review/start-auto-review.ps1 -BuildCheck")
2. Le script detecte l'issue associee au commit (via `#NNN` dans le message)
3. Si echec : noter dans le bilan mais continuer (non bloquant)
```

### 2. Roo Scheduler (Exécutants - myia-po-*)

**File:** `.roo/scheduler-workflow-executor.md`
**Step:** Étape 2c (line 282-307)

```markdown
Apres le pull, verifier s'il y a un nouveau commit a reviewer :

execute_command(shell="gitbash", command="git log --oneline -2")
Si nouveau commit detecte, deleguer l'auto-review :
execute_command(shell="powershell", command="powershell -ExecutionPolicy Bypass -File scripts/review/start-auto-review.ps1 -BuildCheck")
```

### 3. Claude Worker (myia-ai-01)

**File:** `scripts/scheduling/start-claude-worker.ps1`
**Function:** `Invoke-GitSyncAndReview` (line 1493-1593)

The worker automatically:
1. Records HEAD before pull
2. Pulls from origin
3. If HEAD changed → triggers auto-review with `-BuildCheck`
4. Runs review in background job (120s timeout, non-blocking)

## Build Gate Details

The build gate (`-BuildCheck` flag in `auto-review.ps1`):

1. **Build validation** (`npm run build`)
   - If FAILED: Posts immediate "Build FAILED" comment to GitHub
   - Stops review (no point reviewing broken code)

2. **Test validation** (`npx vitest run --maxWorkers=1`)
   - Results included in review comment
   - Uses maxWorkers=1 for myia-web1 (2GB RAM constraint)

3. **Review execution** (only if build passes)
   - sk-agent analyzes diff
   - Generates structured review with findings table
   - Posts to GitHub issue detected from commit message

## Issue Detection

The auto-review script detects the associated GitHub issue from commit message patterns:

```regex
(?i)(?:fix|close|resolve)[\s\-]*#(\d+)   # Fixes #544
(?i)issue[\s\-]*#(\d+)                    # Issue #544
#(\d+)                                     # #544
```

**Example commit messages:**
- `feat(issue-544): Add build gate validation`
- `Fix #544: Build check not working`
- `docs: Update README #544`

## Manual Usage

```powershell
# Review HEAD vs HEAD~1 with build gate
.\scripts\review\auto-review.ps1 -BuildCheck

# Review last 3 commits
.\scripts\review\auto-review.ps1 -BuildCheck -DiffRange "HEAD~3"

# Force post to specific issue
.\scripts\review\auto-review.ps1 -BuildCheck -IssueNumber 535

# Dry run (print without posting)
.\scripts\review\auto-review.ps1 -BuildCheck -DryRun

# Use vLLM directly (skip sk-agent HTTP)
.\scripts\review\auto-review.ps1 -BuildCheck -Mode vllm
```

## Status

### Phase 1: Roo Scheduler Integration ✅
- [x] Coordinator workflow (myia-ai-01) - Étape 1d
- [x] Executor workflow (myia-po-*) - Étape 2c
- [x] Script detection of new commits
- [x] Issue association from commit message

### Phase 2: Claude Worker Integration ✅
- [x] HEAD change detection in `Invoke-GitSyncAndReview`
- [x] Auto-review trigger after git pull
- [x] Non-blocking execution (120s timeout)
- [x] Background job to not block worker

### Phase 3: Build Gate ✅
- [x] `-BuildCheck` flag in `auto-review.ps1`
- [x] Build validation before review
- [x] Test validation (maxWorkers=1)
- [x] Immediate post on build failure
- [x] Results included in review comment

## Testing

To test the pipeline:

```powershell
# Dry run to see what would be posted
.\scripts\review\auto-review.ps1 -BuildCheck -DryRun

# Test with specific issue number
.\scripts\review\auto-review.ps1 -BuildCheck -IssueNumber 535 -DryRun

# Test vLLM fallback
.\scripts\review\auto-review.ps1 -BuildCheck -Mode vllm
```

## Troubleshooting

**Auto-review not triggering:**
- Check if commit message contains `#NNN` issue reference
- Verify scheduler tick interval (3h default)
- Check INTERCOM for scheduler reports

**Build gate failing:**
- Check build output in GitHub comment
- Verify TypeScript compilation locally: `npm run build`
- Check tests: `npx vitest run --maxWorkers=1`

**sk-agent unavailable:**
- Script falls back to basic review without LLM
- Check vLLM server on port 5002
- Review posted with "Manual review recommended" notice

## References

- **Issue #535:** sk-agent auto-review pipeline
- **Issue #544:** Build gate implementation
- **Script:** `scripts/review/auto-review.ps1`
- **Scheduler workflows:** `.roo/scheduler-workflow-*.md`
- **Claude Worker:** `scripts/scheduling/start-claude-worker.ps1`
