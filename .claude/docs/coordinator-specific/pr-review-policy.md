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

```bash
# 1. Get the PR diff
gh pr diff {PR_NUMBER} --repo jsboige/roo-extensions

# 2. Run sk-agent code review
run_conversation(conversation: "code-review", prompt: "Review this PR diff for security, performance, maintainability, and correctness:\n\n[git diff output]")

# 3. Post review as PR comment
gh pr comment {PR_NUMBER} --body "## sk-agent Review\n\n{review summary}"
```

This provides multi-perspective analysis (security, perf, maintainability) before merge. The review summary MUST be posted as a PR comment under a `## sk-agent Review` section.

**When to use:** All PRs with >50 lines of code changes.
**Skip for:** Doc-only, config-only, or harness-only PRs (<50 LOC).
**Blocking:** If sk-agent identifies critical issues (security, data loss), the PR MUST NOT be merged until resolved.

**Note:** Since all agents use the same GitHub account (`jsboige`), GitHub cannot enforce approval via PR reviews. sk-agent review as PR comment is the enforcement mechanism (Option E, approved 2026-03-28). Future: Option A (separate bot accounts) will enable native GitHub PR reviews.

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

All PRs with checklists in body MUST follow [`.claude/docs/github-checklists.md`](../github-checklists.md):

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

## 8. Enforcement & Tooling

### Branch Protection (Phase 3)

**On `main` branch:**

```
- Require pull requests before merging: YES
- Require 1 approval: YES (Coordinator)
- Require status checks pass: YES (Build + Tests)
- Dismiss stale PR approvals: YES
- Restrict who can push: Only Coordinator (for merges via PR)
- Allow force pushes: NO
```

### CLI Validation

Before pushing to PR, agent runs:

```bash
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

- **Pre-PR hook:** Block `git push origin main` from non-coordinators
- **PR review bot:** Auto-apply labels (needs-review, reviewed, approved)
- **Auto-close:** Stale PRs (no activity >7d) auto-comment with reminder

---

## 9. Training & Documentation

### For New Agents

1. Read [`.claude/docs/github-checklists.md`](../github-checklists.md) (checklist discipline)
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

## References

- Issue #461: Worktree integration
- Issue #535: Auto-review pipeline
- Issue #549: CLEANUP-3 regression (motivating incident)
- Rules: [`.claude/docs/github-checklists.md`](../github-checklists.md)
- Scripts: `scripts/review/`, `roo-config/worktree/scripts/`

---

**Last updated:** 2026-03-28
**Maintainer:** Coordinateur RooSync (myia-ai-01)
