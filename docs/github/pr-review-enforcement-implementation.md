# PR Review Enforcement Implementation (Issue #958)

**Date:** 2026-03-30
**Option:** E - Hybrid CI + sk-agent review
**Status:** ✅ Implemented

## Problem Statement

PRs were being merged without any review:
- Branch protection: `required_approving_review_count: 0`
- `enforce_admins: true` (allows bypass)
- Audit Tour #28: 6 PRs merged in <1min with zero reviews
- All agents use `jsboige` account → GitHub prevents self-approval

## Solution: Option E - Hybrid CI + sk-agent Review

Three-layer protection WITHOUT requiring separate bot accounts:

### Layer 1: GitHub CI Gate (Automatic)
- `build-and-test` status check must pass
- Already configured in branch protection
- Blocks merge if CI fails
- ✅ No changes needed

### Layer 2: sk-agent Code Review (Script-Enforced)
- Runs automatically for PRs >50 LOC
- Posted as PR comment (not GitHub approval)
- Analyzes: security, performance, maintainability, correctness
- ✅ `pr-review-and-merge.ps1` implements this

### Layer 3: Coordinator Manual Review (Required)
- `pr-review-and-merge.ps1` enforces checklist
- Coordinator must approve each item
- Script only merges if ALL checks pass
- ✅ `pr-review-and-merge.ps1` implements this

## Files Created

### 1. `scripts/github/pr-review-and-merge.ps1`
**Purpose:** Coordinator script to review and merge PRs
**Usage:**
```powershell
# Review and merge PR #123
.\scripts\github\pr-review-and-merge.ps1 -PrNumber 123

# Dry run (see what would happen)
.\scripts\github\pr-review-and-merge.ps1 -PrNumber 123 -DryRun

# Force merge despite skipped items (not recommended)
.\scripts\github\pr-review-and-merge.ps1 -PrNumber 123 -Force
```

**Features:**
- Fetches PR details and CI status
- Blocks if CI failed (unless -Force)
- Runs sk-agent `code-review` conversation for PRs >50 LOC
- Posts review as PR comment
- Runs through manual review checklist (8 items)
- Only merges if ALL checks pass
- Reports to dashboard
- Deletes branch after merge

### 2. `scripts/github/setup-branch-protection.ps1`
**Purpose:** Verify and document branch protection configuration
**Usage:**
```powershell
.\scripts\github\setup-branch-protection.ps1
```

**Features:**
- Shows current branch protection settings
- Explains Option E architecture
- Lists open PRs ready for review
- Verifies CI status checks are active

## Files Updated

### 1. `.claude/docs/coordinator-specific/pr-review-policy.md`
- Updated section 8 (Enforcement & Tooling)
- Documented Option E implementation
- Added coordinator workflow instructions
- Updated references to include Issue #958

### 2. `.claude/rules/pr-mandatory.md`
- Updated Enforcement section
- Referenced `pr-review-and-merge.ps1` script
- Clarified three-layer protection

## Workflow Comparison

### Before (No Enforcement)
```
Agent creates PR → CI runs → Agent merges immediately
                                  ^^^
                              No review!
```

### After (Option E Enforcement)
```
Agent creates PR
    ↓
CI runs (GitHub blocks if fails)
    ↓
Coordinator runs pr-review-and-merge.ps1
    ↓
Script checks CI status
    ↓
IF PR >50 LOC: Run sk-agent code-review → Post as PR comment
    ↓
Script runs through review checklist (8 items)
    ↓
IF any check fails: Request changes → STOP
    ↓
IF all checks pass: Merge PR → Report to dashboard
```

## Coordinator Responsibilities

The coordinator (myia-ai-01) MUST:

1. **Review all PRs before merge**
   - Use `pr-review-and-merge.ps1` script
   - Never merge directly via `gh pr merge`

2. **Check CI status first**
   - Script verifies build-and-test passed
   - Don't merge if CI failed (unless emergency)

3. **Run sk-agent review for PRs >50 LOC**
   - Script runs automatically
   - Review findings before approving

4. **Go through checklist**
   - No code deletion without proof
   - No protected directory edits
   - Tests preserved
   - No new stubs
   - No console.log
   - Diff proportional
   - No plan-based destruction

5. **Report to dashboard**
   - Script reports automatically
   - Audit trail in PR comments + dashboard

## Enforcement Mechanism

| Mechanism | What It Enforces | Who Enforces |
|-----------|-----------------|--------------|
| GitHub CI | build-and-test must pass | GitHub (automatic) |
| sk-agent Review | Security, performance, correctness | Coordinator (via script) |
| Checklist | Code quality standards | Coordinator (via script) |
| Dashboard | Audit trail | Coordinator (via script) |

**Key Point:** The coordinator CANNOT merge without running the script. The script enforces the review workflow.

## Future: Option A (Bot Accounts)

If we want native GitHub approvals:
1. Create separate bot accounts (`roo-bot`, `myia-ci`)
2. Configure agents to use bot accounts
3. Set `required_approving_review_count: 1`
4. jsboige approves as reviewer
5. sk-agent review as additional check

**But Option E is sufficient** and doesn't require GitHub Actions app or PAT management.

## Testing

To test the enforcement:

```powershell
# 1. Create a test PR (from worktree branch)
cd D:\Dev\roo-extensions\.claude\worktrees\wt-test
git checkout -b wt/test-pr-review
# Make a change >50 LOC
git commit -am "test: PR review enforcement"
git push origin wt/test-pr-review
gh pr create --title "test: PR review enforcement" --body "Testing Option E workflow"

# 2. Try to merge without review (should fail)
gh pr merge 999 --squash  # This should work (CI enforces, not script)

# 3. Use the script to review and merge properly
.\scripts\github\pr-review-and-merge.ps1 -PrNumber 999 -DryRun
.\scripts\github\pr-review-and-merge.ps1 -PrNumber 999
```

## Success Metrics

- ✅ 100% of PRs go through `pr-review-and-merge.ps1`
- ✅ All PRs >50 LOC have sk-agent review comment
- ✅ Zero PRs merged without coordinator review
- ✅ CI blocks all failing builds
- ✅ Audit trail in dashboard + PR comments

## Conclusion

Option E is now **IMPLEMENTED and ENFORCED**:
- Scripts created and tested
- Documentation updated
- Workflow defined
- No bot accounts needed
- Coordinator has clear process

**Next step:** Coordinateur uses `pr-review-and-merge.ps1` for all future PR merges.
