---
name: pr-review
description: Review open PRs autonomously when idle. Industrialises the PR review fallback pattern for executor machines. Trigger: "/pr-review", "review PRs", "idle review".
metadata:
  author: "Roo Extensions Team"
  version: "1.0.0"
  compatibility:
    surfaces: ["claude-code"]
    restrictions: "Requires gh CLI, roo-state-manager MCP"
  issue: "#1713"
---

# Skill: PR Review — Idle Executor Fallback

**Version:** 1.0.0
**Created:** 2026-04-25
**Issue:** #1713 — Idle Claude workers should perform PR reviews on ready queue

---

## Objective

When an executor has no assigned task, it reviews open PRs to unblock the merge pipeline. This eliminates the coordinator bottleneck (bypass enforce_admins) by providing legitimate independent reviews.

---

## Workflow

### Phase 1 : Identify Reviewable PRs

```bash
# List open PRs, exclude own machine's PRs (anti-self-review)
MACHINE=$(hostname | tr '[:upper:]' '[:lower:]' | sed 's/myia-//')
gh pr list --state open --json number,title,headRefName,author,createdAt,additions,deletions,changedFiles --repo jsboige/roo-extensions
```

**Filter criteria (ALL must pass):**
1. PR is NOT authored by the current machine (check `headRefName` does NOT contain machine name)
2. PR is older than 24 hours (`createdAt` check) — anti-fresh-PR
3. PR is not already reviewed by this machine (check existing comments)
4. CI status is `SUCCESS` or `MERGEABLE`
5. PR is not in `DRAFT` state

**Hard cap: maximum 3 reviews per session.**

### Phase 2 : Structured Review

For each selected PR, execute:

#### A. Gather context

```bash
# Full diff
gh pr diff {PR_NUMBER} --repo jsboige/roo-extensions

# Files touched
gh pr diff {PR_NUMBER} --name-only --repo jsboige/roo-extensions

# CI status
gh pr checks {PR_NUMBER} --repo jsboige/roo-extensions

# Existing comments (avoid duplicate review)
gh api repos/jsboige/roo-extensions/pulls/{PR_NUMBER}/comments --jq '.[].body[:100]'
```

#### B. Review template by size

**For PRs <= 50 LOC (concise review):**

```
## Review [{MACHINE}] — PR #{NUMBER}

**Scope:** {1-line summary}
**LOC:** +{additions}/-{deletions}
**CI:** {status}

### Assessment
{Concise evaluation: correct approach, tests present, no regressions}

### Verdict
{LGTM | CHANGES_REQUESTED} — {reason in 1 sentence}

## Evidence
- **CI:** {check results}
- **Files reviewed:** {count} files
- **Tests:** {present/absent}, {count} relevant
```

**For PRs > 50 LOC (Rule 16 integration tracing):**

Apply the full integration tracing template from `docs/harness/coordinator-specific/pr-review-policy.md` section 2:

```
## Review [{MACHINE}] — PR #{NUMBER}

**Scope:** {1-line summary}
**LOC:** +{additions}/-{deletions}
**CI:** {status}

### Context Tracing

For each modified API, schema, or behavioral change:

| Change | Entry Point | Validation | Consumers | Side Effects | Context Preserved? |
|--------|-------------|------------|-----------|--------------|--------------------|
| {field/func} | {where input enters} | {schema/checks} | {downstream code} | {network/DB/dispatch} | {yes/no + why} |

### Critical Patterns Hunt

- [ ] Silent failures: `.catch(() => {})`, fire-and-forget without logging
- [ ] Context loss: passing `machineId` alone where `{machineId, workspace}` needed
- [ ] Defaults masking bugs: `|| undefined`, `?? ''` when missing input should error
- [ ] E2E test gap: does any test exercise full flow?
- [ ] Dual-definition: same schema/type duplicated in tool-definitions vs handler

### Test Assessment
{Coverage of new/modified code, edge cases}

### Verdict
{LGTM | CHANGES_REQUESTED} — {reason}

## Evidence
- **CI:** {check results}
- **Files reviewed:** {count} files
- **Integration tracing:** {complete/partial/N/A}
- **Tests:** {present/absent}, {count} relevant, {gaps identified}
```

### Phase 3 : Post Review

```bash
# Approve
gh pr comment {PR_NUMBER} --repo jsboige/roo-extensions --body "$(cat <<'EOF'
{REVIEW_CONTENT}

[REVIEW-{MACHINE}-INDEP] — Posted by {MACHINE} executor (idle fallback, #1713)
EOF
)"

# Or request changes
gh pr review {PR_NUMBER} --repo jsboige/roo-extensions --request-changes --body "$(cat <<'EOF'
{REVIEW_CONTENT}

[REVIEW-{MACHINE}-INDEP] — Posted by {MACHINE} executor (idle fallback, #1713)
EOF
)"
```

### Phase 4 : Report

Post session summary on dashboard workspace:

```javascript
roosync_dashboard(action: "append", type: "workspace",
  tags: ["DONE", "claude-interactive"],
  content: "### [po-2025] PR Review Session\n- Reviewed: {N} PRs ({LGTM count} LGTM, {CHANGES count} CHANGES_REQUESTED)\n- PRs: #{list}\n- Skipped: {reasons}\n- Time: ~{X}min"
)
```

---

## Rules

### Anti-Self-Review
**NEVER review a PR whose `headRefName` contains your machine name.** All agents share the GitHub account `jsboige`, so machine identification is via branch name patterns (`wt/*-po-2025-*`, `wt/*-web1-*`, etc.).

### Hard Cap
Maximum **3 reviews per session**. Prevents context explosion (workers have limited context windows).

### Fresh PR Filter
PRs created <24h ago are skipped. The author may still be iterating. Exception: PRs explicitly requesting review via `[REVIEW-NEEDED]` tag on dashboard.

### Quality Standards
- Every review MUST include an `## Evidence` block
- Every review MUST end with a clear verdict (LGTM or CHANGES_REQUESTED)
- CHANGES_REQUESTED MUST list specific issues with file:line references
- Integration tracing is MANDATORY for PRs >50 LOC

### Duplicate Prevention
Before reviewing, check existing PR comments for `[REVIEW-*-INDEP]` markers. If the PR already has 2+ independent reviews, skip it.

---

## Invocation

```bash
# Manual invocation
/pr-review

# Integrated in executor workflow (Phase 2, priority 7 — fallback)
# Triggered automatically when no task is assigned
```

---

## Telemetry

At the end of each review session, report metrics:

| Metric | Value |
|--------|-------|
| PRs scanned | {N} |
| PRs reviewed | {N} |
| LGTM | {N} |
| CHANGES_REQUESTED | {N} |
| Skipped (fresh) | {N} |
| Skipped (self-authored) | {N} |
| Skipped (already reviewed) | {N} |
| Session duration | ~{X}min |

---

**Last updated:** 2026-04-25
