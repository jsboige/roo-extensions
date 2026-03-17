# Worktree Best Practices - RooSync Multi-Agent

**Version:** 1.0.0
**Created:** 2026-03-10
**Issue:** #627 - Research worktrees + PR review best practices

---

## Executive Summary

This document synthesizes existing worktree infrastructure, closed RFCs, and PR review policies to provide **actionable best practices** for the RooSync multi-agent system.

**Key Finding:** The infrastructure exists but adoption is partial. Worktrees are used sporadically (Claude Worker, #456 phases A+B+C) while most commits still go directly to `main`.

**Recommendation:** Progressive adoption based on task complexity (see Decision Tree below).

---

## 1. Existing Infrastructure

### 1.1 Scripts Available

| Script | Location | Purpose | Status |
|--------|----------|---------|--------|
| `create-worktree.ps1` | `scripts/worktrees/` | Create isolated worktree per issue | ✅ Working |
| `cleanup-worktree.ps1` | `scripts/worktrees/` | Remove worktree after merge | ✅ Working |
| `EnterWorktree` | Claude Code tool | Native VS Code worktree support | ✅ Built-in |

### 1.2 Worktree Locations

Two patterns coexist:

| Pattern | Path | Usage |
|---------|------|-------|
| **Manual scripts** | `../roo-extensions-wt/feature/ISSUE-NNN-` | User-initiated worktrees |
| **Claude Code native** | `.claude/worktrees/wt-{name}-{timestamp}/` | VS Code managed worktrees |

**Note:** Claude Code worktrees are stored INSIDE the project (`.gitignore`d) while manual scripts use a sibling directory.

### 1.3 Branch Naming Convention

**Standard pattern from `create-worktree.ps1`:**
```
feature/ISSUE-NNN-{clean-title}
```

Examples:
- `feature/417-scheduler-workflow`
- `feature/627-worktree-best-practices`

---

## 2. Historical Context (Closed RFCs)

### 2.1 RFC #448 - Worktrees + PRs + Reviews (CLOSED)

**Proposed:** Comprehensive workflow with PR reviews for all significant changes.

**Decision:** CLOSED as "theoretical RFC without concrete deadline."

**Key insights preserved:**
- ✅ Threshold-based approach (small fixes vs. features)
- ✅ Hybrid reviews (auto-merge for <50 lines, agent review for larger)
- ✅ Cross-machine peer review (myia-ai-01 ↔ myia-po-2023/2024)

**Rejection reason:** Current single-branch workflow works; PR overhead not justified yet.

### 2.2 Issue #456 - Scheduler Feedback + Worktrees (CLOSED)

**Implemented:** Phases A+B+C (partial worktree support)

**What was done:**
- ✅ Worktree detection in scheduler workflows (Étape 1.5)
- ✅ Feedback loop with `[FEEDBACK]` messages in INTERCOM
- ✅ Structured metrics in DONE reports

**What remains:**
- ❌ Phase 1-2: Full worktree integration in scheduler
- ❌ Phase 5: Structured ANALYSIS/LESSONS sections in INTERCOM
- ❌ Phase 6: Skills integration

**Legacy:** Scheduler workflows now mention worktrees but don't enforce them.

---

## 3. Current PR Review Policy (pr-review-policy.md)

### 3.1 Policy Overview

**Document:** `.claude/rules/pr-review-policy.md` (317 lines)

**Scope:** Multi-agent commits must pass PR review before merging to `main`.

**Key Principle:** "No direct pushes to main by agents. All changes → Worktree → PR → Review → Merge."

### 3.2 PR Creation Rules

| Agent Type | Creates PR? | Exception |
|-----------|-------------|-----------|
| Scheduler (Roo) | ✅ YES (for `-complex` tasks) | `-simple` tasks can push to main |
| Scheduler (Claude) | ✅ YES (for all tasks) | Research tasks (no code) |
| Coordinator (ai-01) | ❌ NO | Coordinator merges PRs |
| Interactive (/executor) | ✅ YES | User approval required |

### 3.3 Review Criteria

**Critical Checks (BLOCKING):**
- Build (`npm run build`)
- Tests (`npx vitest run`)
- Secrets scan (`detect-secrets`)
- Type checks (`tsc --noEmit`)

**Warning Checks (NON-BLOCKING):**
- Code coverage < 80%
- File size > 500 lines
- Dependencies audit

### 3.4 Branch Protection (Phase 3)

Planned protections on `main`:
- Require pull requests before merging: YES
- Require 1 approval: YES (Coordinator)
- Require status checks pass: YES (Build + Tests)
- Dismiss stale PR approvals: YES
- Restrict who can push: Only Coordinator (for merges via PR)

---

## 4. Decision Tree: When to Use Worktrees + PRs

**This is the NEW recommended practice** synthesizing from #448, #456, and pr-review-policy.md.

```
┌─────────────────────────────────────────────────────────────────┐
│                    Task Classification                           │
└────────────────────────────────┬────────────────────────────────┘
                                 │
                    ┌────────────┴────────────┐
                    │                         │
              ┌─────▼─────┐             ┌─────▼─────┐
              │ Research  │             │ Code      │
              │ (no code) │             │ Change?   │
              └─────┬─────┘             └─────┬─────┘
                    │                         │
                    │                    ┌────▼────┐
                    │                    │ Complex? │
                    │                    └────┬────┘
                    │                         │
                    │              ┌──────────┼──────────┐
                    │              │          │          │
                    │         ┌────▼───┐ ┌───▼───┐ ┌──▼─────┐
                    │         │ Simple │ │Medium│ │ Complex│
                    │         │ Fix   │ │      │ │        │
                    │         └────┬───┘ └───┬───┘ └──┬─────┘
                    │              │         │          │
                    │              ▼         ▼          ▼
                    │         [Direct   [Worktree  [Worktree
                    │          to main]  optional]  REQUIRED]
                    │              │         │          │
                    └──────────────┴─────────┴──────────┘
                                   │         │          │
                                   ▼         ▼          ▼
                             [Direct   [Optional [Full PR
                              commit]    PR]      Review]
```

### 4.1 Classification Criteria

**Simple Fix (Direct to main):**
- < 20 lines changed
- 1 file only
- Trivial bug fix or typo
- Tests pass

**Medium Task (Optional Worktree):**
- 20-100 lines changed
- 2-3 files
- Small feature or refactor
- Tests pass

**Complex Task (Worktree + PR REQUIRED):**
- > 100 lines changed OR > 3 files
- New feature or architectural change
- Breaking changes
- Requires cross-machine validation

### 4.2 PR Review Threshold

**From #448 (preserved recommendation):**

| PR Size | Review Type | Auto-Merge |
|---------|-------------|------------|
| Small (< 50 lines) | Automated checks only | ✅ YES (if tests pass) |
| Medium (50-500 lines) | Coordinator review | ❌ NO |
| Large (> 500 lines) | Coordinator + detailed review | ❌ NO |

---

## 5. Workflow: End-to-End

### 5.1 Simple Fix (Direct to Main)

```bash
# 1. Edit files
# 2. Test
npx vitest run
# 3. Commit + push
git add .
git commit -m "fix: typo in CLAUDE.md"
git push origin main
```

**No PR needed.** Used for trivial changes only.

### 5.2 Medium Task (Optional Worktree)

```bash
# 1. Create worktree (optional but recommended)
.\scripts\worktrees\create-worktree.ps1 -IssueNumber 627

# 2. Work in isolation
cd ../roo-extensions-wt/627-worktree-best-practices
# ... make changes ...

# 3. Test
cd mcps/internal/servers/roo-state-manager
npx vitest run

# 4. Commit + push branch
git add .
git commit -m "feat: add worktree documentation"
git push origin feature/627-worktree-best-practices

# 5. Optional: Create PR
gh pr create --title "Worktree best practices" --body "## Summary..."
```

**PR optional but recommended for traceability.**

### 5.3 Complex Task (Worktree + PR REQUIRED)

```bash
# 1. Create worktree
.\scripts\worktrees\create-worktree.ps1 -IssueNumber 461

# 2. Work in isolation
cd ../roo-extensions-wt/461-worktree-integration
# ... make changes ...

# 3. Validate (CRITICAL)
npm run build
npx vitest run
tsc --noEmit
detect-secrets scan --all-files

# 4. Commit + push
git add .
git commit -m "feat: worktree integration for scheduler"
git push origin feature/461-worktree-integration

# 5. Create PR (REQUIRED)
gh pr create --title "Worktree Integration" --body "## Summary...
## Type
- [ ] Bug fix
- [x] Feature
## Checklist
- [x] Tests pass locally
- [x] No breaking changes
- [x] Documentation updated
## Related Issues
Fixes #461"

# 6. Wait for coordinator review
# 7. After merge, cleanup
.\scripts\worktrees\cleanup-worktree.ps1 -IssueNumber 461
```

**PR + Review MANDATORY before merge.**

---

## 6. Multi-Machine Coordination

### 6.1 Worktree Prefix Convention (From #448)

**REJECTED but worth noting:**
```
myia-ai-01 → ai01/feature/
myia-po-2023 → po23/feature/
myia-po-2024 → po24/feature/
...
```

**Why rejected:** Adds complexity without clear benefit.

**Current practice:** No prefix, all branches use `feature/ISSUE-NNN-` pattern.

### 6.2 Avoiding Conflicts

**Current problem:** Multiple machines working on same files → merge conflicts on `main`.

**Worktree solution:**
1. Each machine creates worktree for its assigned issue
2. Work proceeds in isolation
3. Coordinator reviews and merges PRs sequentially
4. No conflicts until merge time

**Best practice:** Claim GitHub issue BEFORE creating worktree (see `.claude/rules/github-checklists.md`).

---

## 7. Integration Points

### 7.1 Scheduler Integration

**Current state (from #456 Phase A+B):**
- Worktree detection in scheduler workflows (Étape 1.5)
- Mention of worktrees in instructions but NOT enforced

**Gap:** Scheduler doesn't auto-create worktrees for scheduled tasks.

**Recommendation:** For Phase 2 of #461, modify `start-claude-worker.ps1` to create worktree automatically for assigned tasks.

### 7.2 PR Review Automation

**Current state:** Policy defined (pr-review-policy.md) but NOT enforced.

**Gap:** No GitHub Actions CI/CD pipeline implementing auto-review.

**Recommendation:** Create `.github/workflows/pr-review.yml` with:
- Build step
- Test step
- Secrets scan
- Type check
- Coverage report

### 7.3 Branch Protection

**Current state:** Documented but NOT active.

**Gap:** `main` branch still accepts direct pushes.

**Recommendation:** Enable branch protection on `main` (Phase 3 of #461).

---

## 8. Lessons Learned

### 8.1 What Worked

| Practice | Source | Evidence |
|----------|--------|----------|
| Worktree detection | #456 Phase A | Implemented in scheduler workflows |
| Feedback loop | #456 Phase C | `[FEEDBACK]` messages working |
| Threshold-based PR | #448 | Preserved in pr-review-policy.md |

### 8.2 What Didn't Work

| Attempt | Source | Why it failed |
|---------|--------|---------------|
| Full PR adoption | #448 | Too much overhead, rejected |
| Prefix convention | #448 | Unnecessary complexity |
| Immediate enforcement | #456 | No tooling to enforce |

### 8.3 Anti-Patterns

**Avoid:**
- ❌ Creating worktrees for trivial fixes (< 20 lines)
- ❌ Using worktrees without PR (defeats purpose)
- ❌ Merging PRs without review (except small < 50 lines)
- ❌ Abandoned worktrees (cleanup after merge)

### 8.4 Critical Pitfall: Scheduler Task Path Hardcoding (Issue #731)

**Incident (2026-03-17):** Claude Worker and MetaAudit tasks were silently failing for 76h after worktree cleanup.

**Root Cause:** `scripts/scheduling/setup-scheduler.ps1` uses `$scriptDir` (the directory containing the script at install time). When run from inside a worktree, the Windows Task Scheduler task is created with the worktree path hardcoded.

**Symptom:** After the worktree is deleted, schtasks continues "running" every 6h but immediately fails (script not found). **No error is logged** because the failure occurs before the script starts.

**⚠️ RULE:** ALWAYS run `setup-scheduler.ps1` from the **main repository** (`D:\dev\roo-extensions\scripts\scheduling\`), NEVER from a worktree copy.

**Prevention:** setup-scheduler.ps1 now detects worktree installation and aborts with an error (commit `7f66ea3e`).

**Verification after worktree cleanup:**

```powershell
schtasks /Query /TN "Claude-Worker" /FO LIST | findstr "Task To Run"
# If path contains ".claude/worktrees/" → reinstall from main repo
.\scripts\scheduling\setup-scheduler.ps1 -Action install -TaskType worker
```

This applies to ANY script or configuration that uses its own path for registration. **Document the install path explicitly** to catch this class of bugs early.

---

## 9. Action Plan for #461

### 9.1 Immediate (Phase 1 - READY)

- [x] Document existing infrastructure (this file)
- [ ] Update #461 with refined action plan
- [ ] Create GitHub Actions workflow for PR review automation

### 9.2 Short-term (Phase 2 - PLANNED)

- [ ] Modify `start-claude-worker.ps1` to auto-create worktrees
- [ ] Add worktree creation to `/executor` skill
- [ ] Test on pilot machine (myia-po-2025)

### 9.3 Medium-term (Phase 3 - PLANNED)

- [ ] Enable branch protection on `main`
- [ ] Deploy PR review automation
- [ ] Train all agents on new workflow

### 9.4 Long-term (Phase 4 - FUTURE)

- [ ] Full worktree adoption (all tasks > 3 files)
- [ ] Structured INTERCOM (ANALYSIS/LESSONS sections)
- [ ] Dashboard showing active worktrees per machine

---

## 10. References

- **RFC #448:** Worktrees + PRs + Reviews (closed)
- **Issue #456:** Scheduler feedback + worktrees (closed, partial implementation)
- **Issue #461:** Worktree Integration & Branch Protection (active)
- **Policy:** `.claude/rules/pr-review-policy.md`
- **Scripts:** `scripts/worktrees/create-worktree.ps1`, `cleanup-worktree.ps1`
- **Rules:** `.claude/rules/github-checklists.md`, `sddd-conversational-grounding.md`

---

**Document Status:** ✅ Complete
**Next Step:** Update #461 with refined action plan based on this research.
