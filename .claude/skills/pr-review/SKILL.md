---
name: pr-review
description: Review open PRs autonomously when idle. Industrialises the PR review fallback pattern for executor machines. Trigger: "/pr-review", "review PRs", "idle review".
triggers:
  keywords:
    - "review PRs"
    - "idle review"
    - "révise les PRs"
    - "review les pull requests"
    - "reviser les PRs"
    - "code review"
  exact:
    - "review"
  patterns:
    - "(review|revis).{0,10}(PR|pull.?request)"
  context:
    - "idle"
  priority: low
metadata:
  author: "Roo Extensions Team"
  version: "1.1.0"
  compatibility:
    surfaces: ["claude-code"]
    restrictions: "Requires gh CLI, roo-state-manager MCP"
  issue: "#1713"
---

# Skill: PR Review — Idle Executor Fallback

**Version:** 1.1.0
**Created:** 2026-04-25
**Updated:** 2026-04-27 (#1734 anti-self-review hardening)
**Issue:** #1713 — Idle Claude workers should perform PR reviews on ready queue

---

## Objective

When an executor has no assigned task, it reviews open PRs to unblock the merge pipeline. This eliminates the coordinator bottleneck (bypass enforce_admins) by providing legitimate independent reviews.

---

## Workflow

### Phase 1 : Identify Reviewable PRs

```bash
# List open PRs
gh pr list --state open --json number,title,headRefName,author,createdAt,additions,deletions,changedFiles --repo jsboige/roo-extensions

# Anti-self-review check for each PR (multi-layer, run BEFORE reviewing)
CURRENT_MACHINE=$(hostname | tr '[:upper:]' '[:lower:]')

# Layer 1: Branch name check
BRANCH_NAME=$(gh pr view {PR_NUMBER} --json headRefName --jq '.headRefName')

# Layer 2: PR commits — scan commit messages for machine identifiers
PR_COMMITS=$(gh api repos/jsboige/roo-extensions/pulls/{PR_NUMBER}/commits --jq '.[].commit.message')

# Layer 3: PR body + title
PR_BODY=$(gh pr view {PR_NUMBER} --json body,title --jq '.body + " " + .title')

# Self-review detection: if ANY layer matches current machine → SKIP
# Match patterns: po-2025, po2025, ai-01, web1, etc.
if echo "$BRANCH_NAME $PR_COMMITS $PR_BODY" | grep -qi "$CURRENT_MACHINE"; then
  echo "[SKIP] Self-review detected: PR #{PR_NUMBER} authored by $CURRENT_MACHINE"
  continue
fi
```

**Anti-self-review decision function (3 layers, any match = SKIP):**

| Layer | Source | What it checks |
|-------|--------|---------------|
| 1. Branch name | `headRefName` | `wt/*-po-2025-*`, `wt/cycle*-po2025-*`, etc. |
| 2. Commit messages | PR commits API | Machine name in any commit message |
| 3. PR body + title | PR body/title | `[AUTHORED-BY-po-2025]`, machine mentions in description |

**Log format when skipping:**
```
[SKIP] Self-review: PR #{N} — matched layer {1|2|3} ({branch|commits|body}) for {machine}
```

**Filter criteria (ALL must pass AFTER anti-self-review):**
1. PR passes anti-self-review check (3 layers above)
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

### Anti-Self-Review (3-layer check, #1734)
**NEVER review a PR authored by your machine.** All agents share the GitHub account `jsboige`, so machine identification requires multi-layer detection:

| Layer | Source | Detection |
|-------|--------|-----------|
| **1. Branch name** | `headRefName` | Contains machine hostname pattern (`po-2025`, `po2025`, `ai-01`, `web1`) |
| **2. Commit messages** | PR commits API | Machine name found in any commit message within the PR |
| **3. PR body + title** | PR body/title | `[AUTHORED-BY-{MACHINE}]` marker or machine name in description |

**If ANY layer matches → SKIP the PR.** Log the decision:
```
[SKIP] Self-review: PR #{N} — layer {1|2|3} ({branch|commits|body}) matched {machine}
```

**Why 3 layers:** Branch names are not always machine-qualified (e.g., `wt/pr-review-skill-1713`). Commit messages and PR body provide fallback identification.

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
| Skipped (self-authored layer) | {1|2|3} ({branch|commits|body}) |
| Skipped (already reviewed) | {N} |
| Session duration | ~{X}min |

---

**Last updated:** 2026-04-27
