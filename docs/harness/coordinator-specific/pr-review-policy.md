# PR Review Policy - Multi-Agent Commits (#461 Phase 3)

**Version:** 1.0.0
**Created:** 2026-03-05
**Issue:** #461 - Worktree Integration & Branch Protection

---

## Overview

All agent-generated code commits must pass through a PR review workflow before merging to `main`. This policy prevents regressions (CLEANUP-3) and ensures quality gates are met.

**Key Principle:** No direct pushes to `main` by agents. All changes → Worktree → PR → Review → Merge.

---

## 1. PR Creation Rules

### Who Creates PRs?

| Agent Type | Creates PR? | Exception |
|-----------|-------------|-----------|
| **Scheduler (Roo)** | ✅ YES (all tasks with code changes) | No exception — PR mandatory per `.claude/rules/pr-mandatory.md` |
| **Scheduler (Claude)** | ✅ YES (for all tasks) | Research tasks (no code changes) |
| **Coordinator (ai-01)** | ❌ NO | Coordinator merges PRs, doesn't create them |
| **Interactive (/executor)** | ✅ YES | User approval required before creating PR |
| **Interactive (/coordinate)** | ✅ YES | Coordinator approval required before creating PR |

### PR Creation Checklist

**Before `gh pr create`:**

- [ ] Code changes committed and pushed to worktree branch
- [ ] Branch naming convention: `wt/{feature}-{agent}-{timestamp}`
  - Example: `wt/fix-487-scheduler-claude-20260305-071539`
- [ ] All tests pass (`npm test`, `npx vitest run`)
- [ ] Worktree is clean: `git status` = nothing to commit
- [ ] Commit messages follow conventional commits (`fix:`, `feat:`, `docs:`, etc.)
- [ ] No secrets in commits (verify with `git log -p`)

### PR Body Template

```markdown
## Summary
Brief description of changes (1-3 sentences).

## Type
- [ ] Bug fix
- [ ] Feature
- [ ] Documentation
- [ ] Refactoring
- [ ] Build/Test

## Checklist
- [ ] Tests pass locally
- [ ] No breaking changes
- [ ] Documentation updated
- [ ] Related issues linked

## Related Issues
Fixes #XXX, Relates to #YYY

## Machine & Agent
**Machine:** myia-po-2025
**Agent:** Claude Code
**Branch:** wt/feature-name-timestamp
```

---

## 2. Auto-Review Criteria

**Timing:** Runs automatically when PR created (via CI/GitHub Actions)

### Critical Checks (BLOCKING)

| Check | Tool | Pass Criteria | If Fail |
|-------|------|---------------|---------|
| Build | `npm run build` | Exit code 0 | PR blocked, agent fixes and re-pushes |
| Tests | `npx vitest run` | 100% pass (or skip justified) | PR blocked, agent fixes |
| Secrets Scan | `detect-secrets` | No secrets detected | PR blocked, secrets removed |
| Type Checks | `tsc --noEmit` | No type errors | PR blocked, agent fixes |

### sk-agent Code Review (MANDATORY for PRs >50 LOC)

**REQUIRED** before merging any PR with >50 lines of code changes. The coordinator MUST run a structured code review via sk-agent and post the results as a PR comment.

**IMPORTANT:** Use the INTEGRATION TRACING template below, not just generic diff validation. This catches bugs like BLOCKER-3 (issue #1471) where schema changes work but downstream dispatch fails.

```bash
# 1. Get the PR diff
gh pr diff {PR_NUMBER} --repo jsboige/roo-extensions

# 2. Get files touched
gh pr diff {PR_NUMBER} --name-only --repo jsboige/roo-extensions

# 3. Run sk-agent code review with INTEGRATION TRACING
run_conversation(conversation: "code-review", prompt: "[INTEGRATION TRACING TEMPLATE - see below]")

# 4. Post review as PR comment
gh pr comment {PR_NUMBER} --body "## sk-agent Review\n\n{review summary}"
```

**INTEGRATION TRACING TEMPLATE (use this for sk-agent reviews):**

```
Review this PR with a focus on INTEGRATION, not just diff correctness.

DIFF:
[git diff output]

FILES TOUCHED:
[gh pr diff --name-only output]

CONTEXT TRACING (required):
For each new field, API, or modified behavior in this PR:
1. Where does a value enter the system? (tool input, request body, env var)
2. Where is it validated? (schema, Zod, manual checks)
3. What code CONSUMES it downstream?
4. Where does it have side effects? (network call, DB write, message dispatch)
5. At each step: is required context (workspace, machineId, auth, traceId) preserved?

Use the codebase to trace these. If the PR adds/modifies a schema field,
grep for consumers. If it changes a function signature, find callers.

CRITICAL PATTERNS TO HUNT:
- Silent failures: `.catch(() => {})`, fire-and-forget without logging
- Context loss: passing `machineId` alone where `{machineId, workspace}` is needed
- Defaults papering over bugs: `|| undefined`, `?? ''`, `|| []` when missing input should error
- E2E test gap: does any test exercise the full flow from input to effect?
- Dual-definition: check if the same schema/type is duplicated elsewhere (tool-definitions vs handler source)

VERDICT: APPROVE / REQUEST_CHANGES / COMMENT.
Be specific about bugs NOT in the diff but exposed/obscured by it.
```

**When to use:** All PRs with >50 lines of code changes.
**Skip for:** Doc-only, config-only, or harness-only PRs (<50 LOC).
**Blocking:** If sk-agent identifies critical issues (security, data loss, integration bugs), the PR MUST NOT be merged until resolved.

**Note:** Since all agents use the same GitHub account (`jsboige`), GitHub cannot enforce approval via PR reviews. sk-agent review as PR comment is the enforcement mechanism (Option E, approved 2026-03-30, Issue #958). The coordinator MUST run `pr-review-and-merge.ps1` before merging any PR. This script enforces the review workflow. Future: Option A (separate bot accounts) will enable native GitHub PR reviews.

### Warning Checks (NON-BLOCKING)

| Check | Tool | Threshold | Action |
|-------|------|-----------|--------|
| Code Coverage | Jest/Vitest | < 80% coverage | Auto-comment with report, manual review |
| File Size | Custom | > 500 lines per file | Auto-comment suggesting split |
| Dependencies | npm audit | Medium+ vulnerabilities | Auto-comment with remediation |
| Linting | ESLint | > 10 warnings | Auto-comment, agent can dismiss |

---

## 3. Manual Review (Coordinator)

**Who:** Coordinator (myia-ai-01) exclusively
**When:** After auto-review passes
**Deadline:** Within 24h of PR creation

### Review Checklist

- [ ] **Architecture**: Changes align with system design
- [ ] **Code Quality**: Follows existing patterns, readable, no duplication
- [ ] **Documentation**: README/CLAUDE.md updated if needed
- [ ] **Scope**: Changes are minimal and focused (single concern)
- [ ] **Testing**: New code has tests, edge cases covered
- [ ] **Git Hygiene**: Commits are atomic, messages clear
- [ ] **Agent Capability**: Task appropriate for agent's skill level

### Coordinator Actions

| Scenario | Action |
|----------|--------|
| All checks pass + review OK | ✅ Approve & Merge |
| Minor issues (doc, comments) | 💬 Request changes, agent re-pushes |
| Architecture concerns | ❌ Request major changes or close PR |
| Blocked by auto-review | ⏸️ Wait for fixes, then review |

### Merge Rules

- [ ] **Single approval:** Coordinator approval sufficient (no second reviewer)
- [ ] **Branch protection:** After Phase 3, main requires 1 PR
- [ ] **Merge strategy:** Squash + rebase (one commit per PR) unless multi-commit intentional
- [ ] **Post-merge:** Delete worktree branch, leave PR open for audit trail

---

## 4. Exception Workflows

### Exception 1: Emergency Fixes (Security/Production Down)

**When:** Security patch, production outage
**Authority:** Coordinator (ai-01) decides if emergency
**Process:**
1. Create PR normally
2. Coordinator BYPASSES review (documents reason in PR comment)
3. Merge directly, document in commit: `Emergency fix: [reason]`
4. Post-merge review (within 1h)

### Exception 2: Agent-to-Agent Handoff

**When:** Agent A creates PR for Agent B to continue work
**Process:**
1. PR draft mode (leave description explaining the halt point)
2. Coordinator assigns to next agent
3. Agent B pushes to same worktree branch
4. PR review follows normal checklist
5. Updated PR description before merge

### Exception 3: Large Features (Multi-Commit)

**When:** Feature requires >500 lines, >5 files, >3 commits
**Process:**
1. Create PR as draft
2. Agent pushes multiple commits with clear commit messages
3. Coordinator reviews each commit individually (can add review comments per-commit)
4. Convert from draft → ready when complete
5. Merge WITH full commit history (no squash)

---

## 5. Machine-Specific Rules

### Coordinator (myia-ai-01)

- Merges PRs (no PRs created by this agent)
- Can bypass reviews for emergency fixes
- Should review PRs within 4h during business hours
- Delegates review to other machines if needed (hand-off documented)

### Executors (po-2023, po-2024, po-2025, po-2026, web1)

- Create PRs for all code changes
- Cannot merge PRs (review by coordinator required)
- Can self-review research/analysis tasks (no code)
- Scheduler agents: `-simple` can push to main, `-complex` requires PR

### web1 (RAM constraints)

- Keep PRs focused (<50 files to avoid timeout)
- Build tests with `--maxWorkers=1` flag
- Auto-review may take longer due to resource constraints

---

## 6. Checklist Integration with #516

All PRs with checklists in body MUST follow [`docs/harness/reference/github-checklists.md`](../reference/github-checklists.md):

- [ ] Checklist in PR body reflects actual work items
- [ ] Coordinator updates checklist as PR progresses (not just at end)
- [ ] PR cannot be merged if checklist has unchecked items (unless explicitly approved)
- [ ] Checklist provides audit trail for multi-agent PRs

---

## 7. PR Monitoring & Metrics

### Dashboard (Updated in sync-tour, Phase 7)

```markdown
## PR Status (Last 7 Days)

| Machine | Created | Approved | Merged | Blocked | Avg Review Time |
|---------|---------|----------|--------|---------|-----------------|
| po-2025 | 2 | 2 | 2 | 0 | 3.5h |
| po-2023 | 1 | 1 | 1 | 0 | 2h |
| web1 | 0 | 0 | 0 | 0 | - |

**Total:** 3 PRs merged, 0 blocked, avg review 2.8h
```

### Success Metrics

- **Target:** 100% of agent commits go through PR
- **Review time:** < 8h median
- **Merge rate:** ≥ 90% PRs merged (rest closed)
- **Regression rate:** 0 (zero regressions post-merge like CLEANUP-3)

---

## 8. Enforcement & Tooling (Option E - Issue #958)

### Branch Protection (Current Configuration)

**On `main` branch (as of 2026-03-30):**

```
- Require pull requests before merging: YES (enforced)
- Require approving reviews: NO (0 required - see note below)
- Require status checks pass: YES (build-and-test)
- Enforce admins: YES
- Allow force pushes: NO
- Allow deletions: NO
```

**Why 0 required reviews?** All agents use the same GitHub account (`jsboige`). GitHub prevents self-approval, so requiring reviews would create a deadlock. Instead, we use **Option E: Hybrid CI + sk-agent review**.

### Enforcement Mechanism (Option E)

**Three-layer protection:**

1. **GitHub CI Gate (Automatic)**
   - `build-and-test` status check must pass
   - Blocks merge if CI fails
   - Configured in branch protection

2. **sk-agent Code Review (Coordinator-triggered)**
   - Run automatically by `pr-review-and-merge.ps1` for PRs >50 LOC
   - Posted as PR comment (not GitHub approval)
   - Analyzes: security, performance, maintainability, correctness
   - Coordinator MUST review findings before merge

3. **Coordinator Manual Review (Required)**
   - `pr-review-and-merge.ps1` enforces checklist review
   - Coordinator must approve each item before merge
   - Script only merges if all checks pass
   - Audit trail in dashboard and PR comments

### Coordinator Workflow

**To review and merge a PR:**

```powershell
# Basic review (PR ≤50 LOC, no sk-agent review)
.\scripts\github\pr-review-and-merge.ps1 -PrNumber 123

# Full review with sk-agent analysis (PR >50 LOC)
.\scripts\github\pr-review-and-merge.ps1 -PrNumber 456

# Dry run (see what would happen)
.\scripts\github\pr-review-and-merge.ps1 -PrNumber 789 -DryRun

# Force merge despite skipped checklist items (not recommended)
.\scripts\github\pr-review-and-merge.ps1 -PrNumber 789 -Force
```

**The script:**
1. Fetches PR details and CI status
2. Blocks if CI failed (unless -Force)
3. Runs sk-agent code-review for PRs >50 LOC
4. Posts review as PR comment
5. Runs through manual review checklist
6. Only merges if ALL checks pass
7. Reports to dashboard

### CLI Validation

Before pushing to PR, agent runs:

```powershell
# Test PR will be mergeable
gh pr create --title "..." --body "..." --draft

# Check build
npm run build

# Check tests
npx vitest run

# Verify no secrets
detect-secrets scan --all-files --only-whitelist
```

### Automated Enforcement

- **CI Gate:** GitHub Actions block merge if build-and-test fail
- **Review Script:** Coordinator MUST use `pr-review-and-merge.ps1`
- **Dashboard Reporting:** All merges logged to workspace dashboard
- **Audit Trail:** PR comments + dashboard + git log provide traceability

### Future: Option A (Bot Accounts)

If we implement separate bot accounts (`roo-bot`, `myia-ci`), we can enable native GitHub approvals:
- Set `required_approving_review_count: 1`
- Bot accounts create PRs
- jsboige approves as reviewer
- sk-agent review as additional check

This requires GitHub Actions app or PAT management. Option E is sufficient for current needs.

---

## 9. Training & Documentation

### For New Agents

1. Read [`docs/harness/reference/github-checklists.md`](../reference/github-checklists.md) (checklist discipline)
2. Read this file (PR review policy)
3. Review 1 example PR (coordinator shows PR structure)
4. Create first PR as draft, get feedback before converting to ready

### For Coordinators

- Maintain review SLA: < 8h response time
- Document review decisions in PR comments (for learning)
- Monthly review of PR metrics to identify process bottlenecks

---

## 10. Transition Timeline

| Date | Phase | Action |
|------|-------|--------|
| 2026-03-05 | Phase 1 | Schedulers start using worktrees for `-complex` |
| 2026-03-10 | Phase 2 | All agent PRs enabled (not yet required) |
| 2026-03-15 | Phase 2.5 | Agents warned: direct main pushes will be blocked |
| 2026-03-20 | Phase 3 | Branch protection ACTIVE on main |
| 2026-03-25 | Full Enforcement | No exceptions (emergency only) |

---

## 11. Pipeline Multi-Canal Cycle 21 — sk-agent + Workers + Interactif (#1754)

**Version:** 1.0.0
**Created:** 2026-04-27
**Issue:** #1754 — META-HARNESS sk-agent PR review pipeline
**Context:** sk-agent audit completed (#1748). This section documents the production pipeline using sk-agent agents and multi-agent conversations for automated PR review.

### Overview

The pipeline processes PRs through 5 stages, escalating from automated lightweight review to human verification. Each stage has clear inputs, outputs, and pass/fail criteria.

```
PR Created → Step 1 (Quick Scan) → Step 2 (Impact) → Step 3 (Tests) → Step 4 (Opus Verify) → Step 5 (Merge)
              sk-agent              sk-agent           Worker          Claude interactif     Coordinator
              commit-reviewer       commit-review      CI              ai-01 Opus            jsboige/NanoClaw
              ~30s                  ~2min              ~2min           ~5min                 ~1min
```

### Stage 1: Quick Diff Scan (sk-agent `commit-reviewer`)

**Goal:** Fast structured findings table from the raw diff.

**Trigger:** Any PR created or updated with code changes (>10 LOC).

```javascript
// Claude Code / Coordinator triggers:
const diff = await getPrDiff(prNumber);  // gh pr diff {N}
const files = await getPrFiles(prNumber); // gh pr diff {N} --name-only

const result = await call_agent({
  agent: "commit-reviewer",
  prompt: `Review this PR diff. Output a structured findings table.

FILES CHANGED:
${files}

DIFF:
${diff}

For each finding, provide:
- SEVERITY: CRITICAL / HIGH / MEDIUM / LOW / INFO
- CATEGORY: security | performance | correctness | maintainability | style
- FILE: affected file
- LINE: approximate line number
- DESCRIPTION: what the issue is
- SUGGESTION: how to fix it

End with VERDICT: APPROVE / REQUEST_CHANGES / COMMENT
and a brief summary.`
});
```

**Output:** Structured findings table posted as PR comment.
**Timeout:** 30 seconds.
**Pass criteria:** No CRITICAL or HIGH severity findings → proceed to Stage 2.
**If fail:** Post findings, flag PR as needs-changes. Author addresses issues.

### Stage 2: Impact Analysis (sk-agent `commit-review` conversation)

**Goal:** Multi-perspective analysis — security, edge cases, integration risks.

**Trigger:** Stage 1 passed OR PR >100 LOC (always run for large PRs).

```javascript
const diff = await getPrDiff(prNumber);
const context = await getPrContext(prNumber); // Issue description, related issues

const result = await run_conversation({
  conversation: "commit-review",
  prompt: `Multi-perspective code review of PR #${prNumber}.

CONTEXT: ${context}

DIFF:
${diff}

Agents should analyze:
1. **commit-reviewer**: Structured findings — correctness, edge cases, type safety
2. **devils-advocate**: What could go wrong? Attack surface, failure modes, worst-case scenarios
3. **synthesizer**: Overall assessment, risk summary, recommendation

Focus on INTEGRATION TRACING:
- Where does each new value enter the system?
- Where is it validated?
- What consumes it downstream?
- Are required context fields (machineId, workspace, auth) preserved?

VERDICT: APPROVE / REQUEST_CHANGES / COMMENT with confidence level.`
});
```

**Output:** Multi-agent review synthesis posted as PR comment.
**Timeout:** 2 minutes.
**Pass criteria:** No unresolved CRITICAL findings → proceed to Stage 3.
**If fail:** Post synthesis, add `needs-changes` label.

**Alternative for security-sensitive PRs:**

```javascript
// Use code-review conversation for security-critical changes
const result = await run_conversation({
  conversation: "code-review",
  prompt: `Security-focused review of PR #${prNumber}...\n\nDIFF:\n${diff}`
});
```

### Stage 3: Build + Tests (Worker)

**Goal:** Verify code compiles and all tests pass.

**Trigger:** Stage 2 passed.

```bash
# Worker (any executor machine) runs:
cd mcps/internal/servers/roo-state-manager  # if submodule changed
npm run build
npx vitest run --config vitest.config.ci.ts

# OR for parent repo changes:
cd /c/dev/roo-extensions
# (parent has no build, just submodule validation)
cd mcps/internal/servers/roo-state-manager
npm run build && npx vitest run --config vitest.config.ci.ts
```

**Output:** Build status + test results posted to CI (GitHub Actions) and dashboard.
**Timeout:** 3 minutes.
**Pass criteria:** Build succeeds, 0 test failures (skips OK).
**If fail:** PR blocked until author fixes.

### Stage 4: Verification Finale (Claude Interactif — Opus)

**Goal:** Human-quality review with full context window and tool access.

**Trigger:** Stages 1-3 all passed. Coordinator (ai-01 Opus) reviews.

**Process:**
1. Coordinator reads accumulated findings from Stages 1-2 (PR comments)
2. Reads CI results from Stage 3
3. Uses Claude Code tools (Read, Grep, Glob) to verify specific concerns
4. Cross-references with MEMORY.md, CLAUDE.md rules
5. Posts final review with APPROVE / REQUEST_CHANGES

**Focus areas for Opus review:**
- Integration correctness (Stages 1-2 may miss cross-file impacts)
- Protected directories (`src/services/synthesis/`, `src/services/narrative/`)
- Agent claim discipline (SHAs verified, PRs reachable)
- No deletion without proof (Rule #4)

**Timeout:** 5 minutes.
**Pass criteria:** Coordinator explicit APPROVE.

### Stage 5: Merge (Coordinator or jsboige via NanoClaw)

**Goal:** Complete the merge with proper audit trail.

**Who merges:**
- **Coordinator (myia-ai-01)** for PRs authored by `jsboige` or other agents
- **jsboige (via NanoClaw)** for PRs authored by `myia-ai-01` (CODEOWNERS self-approval constraint)

```bash
# Merge workflow:
gh pr review {N} --approve --body "Pipeline Stages 1-4 passed. Verified by [agent]."
gh pr merge {N} --squash --delete-branch
```

**Post-merge:**
1. Clean up worktree: `git worktree remove .claude/worktrees/wt-{desc}`
2. Delete branch: `git branch -D wt/{desc}`
3. Report to dashboard: `[DONE] PR #{N} merged — {summary}`

### Pipeline Decision Matrix

| PR Size | Stage 1 | Stage 2 | Stage 3 | Stage 4 | Stage 5 |
|---------|---------|---------|---------|---------|---------|
| <10 LOC (doc/config) | SKIP | SKIP | SKIP | SKIP | Direct merge |
| 10-50 LOC | REQUIRED | SKIP | REQUIRED | SKIP | Coordinator |
| 50-100 LOC | REQUIRED | REQUIRED | REQUIRED | OPTIONAL | Coordinator |
| >100 LOC | REQUIRED | REQUIRED | REQUIRED | REQUIRED | Coordinator |
| Security-critical | REQUIRED | `code-review` | REQUIRED | REQUIRED | jsboige |

### Error Handling

| Stage Fails | Action |
|-------------|--------|
| Stage 1 (CRITICAL/HIGH) | Block PR, author fixes, re-run from Stage 1 |
| Stage 2 (unresolved) | Block PR, add `needs-changes` label |
| Stage 3 (build/test) | Block PR, author fixes, re-run from Stage 3 |
| Stage 4 (Opus rejects) | Block PR, detailed feedback, author addresses |
| sk-agent unavailable | Fall back to Opus-only review (Stage 4 directly) |
| CI timeout | Retry once, then fall back to local validation |

### sk-agent Agent Reference

| Agent/Conversation | Use Case | Model |
|-------------------|----------|-------|
| `commit-reviewer` | Quick structured diff review | GLM-5.1 |
| `critic` | Stress-test findings for gaps | GLM-5.1 |
| `commit-review` conversation | Multi-perspective (3 rounds) | commit-reviewer → devils-advocate → synthesizer |
| `code-review` conversation | Security+perf+maintainability (6 rounds) | security/perf/maintainability reviewers |
| `deep-think` conversation | Complex architectural decisions | optimist → devils-advocate → pragmatist → mediator |

---

## References

- Issue #461: Worktree integration
- Issue #535: Auto-review pipeline
- Issue #549: CLEANUP-3 regression (motivating incident)
- Issue #958: PR review enforcement (Option E implementation)
- Issue #1748: sk-agent calibration uplift (audit)
- Issue #1754: META-HARNESS pipeline design (this section)
- Rules: [`docs/harness/reference/github-checklists.md`](../reference/github-checklists.md)
- Scripts: `scripts/github/pr-review-and-merge.ps1`, `scripts/github/setup-branch-protection.ps1`

---

**Last updated:** 2026-04-27 (Pipeline multi-canal cycle 21 — Issue #1754)
**Maintainer:** Coordinateur RooSync (myia-ai-01)
