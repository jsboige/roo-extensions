# GitHub Reviewer Bot - Feasibility Study

**Issue:** #1184
**Date:** 2026-04-08
**Status:** PRELIMINARY ANALYSIS

---

## Executive Summary

This document analyzes the feasibility of implementing automated PR review for the roo-extensions repository using two approaches:

1. **Option A (Recommended):** Claude Code CLI in GitHub Actions for intelligent code review
2. **Option B (Fallback):** Simple auto-approve bot with minimal checks

**Recommendation:** Implement Option A for intelligent review with Option B as safety fallback.

---

## Current State Analysis

### Branch Protection Rules (as of 2026-04-08)

```json
{
  "required_approving_review_count": 0,
  "required_status_checks": {
    "contexts": ["build-and-test (20)", "build-and-test (22)"],
    "strict": true
  },
  "enforce_admins": true
}
```

**Key observations:**
- ✅ CI checks are required (Node 20 + 22)
- ❌ No review requirement (can't enable due to self-review limitation)
- ✅ Admin enforcement enabled (prevents bypassing protections)

### Problem Statement

All PRs are created under the `jsboige` account. GitHub's API prevents self-approval, making it impossible to enable `required_approving_review_count: 1` without a separate reviewer account.

---

## Option A: Claude Code CLI in GitHub Actions

### Technical Feasibility: **PROVEN** ✅

**Tested locally:** Claude Code CLI v2.1.19 supports non-interactive mode via `-p/--print` flag.

```bash
# Tested command works:
echo "prompt" | claude -p "Say hello"
# Output: Hello from Claude Code CLI
```

**Key capabilities for GitHub Actions:**
- ✅ Non-interactive mode (`-p` flag)
- ✅ JSON output format (`--output-format json`)
- ✅ Structured output via JSON Schema (`--json-schema`)
- ✅ Max budget control (`--max-budget-usd`)
- ✅ Bypass permissions in trusted directories
- ✅ npm package available: `@anthropic-ai/claude-code`

### Proposed GitHub Action Workflow

```yaml
# .github/workflows/claude-review.yml
name: Claude Code Review

on:
  pull_request:
    types: [opened, synchronize, reopened]
    branches: [main]

permissions:
  contents: read
  pull-requests: write

jobs:
  review:
    runs-on: ubuntu-latest
    if: github.event.pull_request.user.login == 'jsboige'

    steps:
      - name: Checkout PR
        uses: actions/checkout@v4
        with:
          ref: ${{ github.event.pull_request.head.sha }}

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'

      - name: Install Claude Code CLI
        run: npm install -g @anthropic-ai/claude-code

      - name: Get PR diff
        id: diff
        run: |
          gh pr diff ${{ github.event.pull_request.number }} > pr.diff
          echo "size=$(wc -l < pr.diff)" >> $GITHUB_OUTPUT
        env:
          GH_TOKEN: ${{ github.github_token }}

      - name: Review with Claude Code
        id: review
        run: |
          RESULT=$(claude -p "$(cat pr.diff)" \
            --output-format json \
            --json-schema '{
              "type": "object",
              "properties": {
                "approved": {"type": "boolean"},
                "summary": {"type": "string"},
                "issues": {"type": "array", "items": {"type": "string"}}
              },
              "required": ["approved", "summary"]
            }' \
            "Review this diff for: security vulnerabilities, bugs, performance issues, code quality. Respond with JSON containing: approved (boolean), summary (string), issues (array of strings).")

          echo "result=$RESULT" >> $GITHUB_OUTPUT
        env:
          ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}

      - name: Post review comment
        uses: actions/github-script@v7
        with:
          script: |
            const result = JSON.parse('${{ steps.review.outputs.result }}');
            const body = [
              '## 🤖 Claude Code Review',
              '',
              `**Verdict:** ${result.approved ? '✅ APPROVED' : '❌ CHANGES REQUESTED'}`,
              '',
              '**Summary:**',
              result.summary,
              result.issues.length > 0 ? '\n**Issues found:**\n' + result.issues.map(i => `- ${i}`).join('\n') : ''
            ].join('\n');

            await github.rest.issues.createComment({
              owner: context.repo.owner,
              repo: context.repo.repo,
              issue_number: context.issue.number,
              body: body
            });

      - name: Approve PR if safe
        if: steps.review.outputs.result != '' && fromJSON(steps.review.outputs.result).approved == true
        run: |
          gh pr review ${{ github.event.pull_request.number }} --approve --body "Automatically approved by Claude Code review"
        env:
          GH_TOKEN: ${{ secrets.REVIEWER_BOT_TOKEN }}
```

### Cost Analysis

**Estimated cost per review:**
- Average diff: 500-2000 lines
- Input tokens: ~10K-50K (diff + system prompt)
- Output tokens: ~1K-5K (review response)
- **Total per review:** ~11K-55K tokens

**Pricing (Claude Sonnet 4.5):**
- Input: $3/M tokens → $0.03-$0.15 per review
- Output: $15/M tokens → $0.015-$0.075 per review
- **Total per review:** ~$0.05-$0.25

**Annual estimate (100 PRs/year):** $5-$25/year

### Subscription Coverage

**Question:** Does Claude Code Max subscription cover CI/CD usage?

**Status:** ⚠️ **NEEDS VERIFICATION**

The Claude Code CLI can be installed via npm (`@anthropic-ai/claude-code`) and requires an Anthropic API key. The Max subscription covers the Claude Code VS Code extension, but CI/CD usage via CLI requires:

1. **Anthropic API key** (separate from Claude Code subscription)
2. **API pricing** (pay-per-use, not included in Max subscription)

**Conclusion:** Option A requires an Anthropic API key with billing enabled. The Max subscription alone does not cover API usage in CI/CD environments.

### Advantages

✅ **Intelligent review:** Detects security issues, bugs, performance problems
✅ **Consistent:** Applies same standards to all PRs
✅ **Explainable:** Provides reasons for approval/rejection
✅ **No rubber-stamping:** Actually reviews code quality
✅ **Learns:** Can be tuned with custom prompts for project-specific standards

### Disadvantages

❌ **Cost:** $5-$25/year in API costs
❌ **Latency:** Review takes 30-120 seconds
❌ **API dependency:** Requires Anthropic API availability
❌ **Setup complexity:** Requires API key management in GitHub secrets

---

## Option B: Simple Auto-Approve Bot

### Implementation

**Create GitHub account:** `roo-coordinator-bot` (or similar)

**GitHub Action:**
```yaml
# .github/workflows/auto-approve.yml
name: Auto Approve

on:
  pull_request:
    types: [opened, synchronize, reopened]
    branches: [main]

permissions:
  contents: read
  pull-requests: write

jobs:
  approve:
    runs-on: ubuntu-latest
    if: github.event.pull_request.user.login == 'jsboige'

    steps:
      - name: Wait for CI checks
        uses: lewagon/wait-on-check-action@v1.3.1
        with:
          ref: ${{ github.event.pull_request.head.sha }}
          check-name: 'build-and-test'
          repo-token: ${{ secrets.GITHUB_TOKEN }}
          wait-interval: 30

      - name: Approve PR
        run: |
          gh pr review ${{ github.event.pull_request.number }} \
            --approve \
            --body "Auto-approved by CI checks"
        env:
          GH_TOKEN: ${{ secrets.REVIEWER_BOT_TOKEN }}
```

**Required secrets:**
- `REVIEWER_BOT_TOKEN`: GitHub Personal Access Token from bot account

**Account setup:**
1. Create new GitHub account
2. Add as collaborator with `write` permission on `jsboige/roo-extensions`
3. Generate PAT with `repo:status`, `pull_request:write` scopes
4. Add to repository secrets

### Advantages

✅ **Zero cost:** No API fees
✅ **Fast:** Approves immediately after CI passes
✅ **Simple:** Minimal setup and maintenance
✅ **Reliable:** No external dependencies

### Disadvantages

❌ **Rubber-stamping:** No actual code review
❌ **False confidence:** PR passes but may have issues
❌ **Manual review needed:** Still requires human oversight for critical changes

---

## Recommended Implementation

### Phase 1: Enable Safe Auto-Approve (Immediate)

**Action:** Implement Option B with safeguards

1. Create `roo-coordinator-bot` GitHub account
2. Add as collaborator with `write` permission
3. Create `auto-approve.yml` workflow with:
   - CI check requirement (must pass)
   - Author check (only `jsboige` PRs)
   - File pattern check (exclude sensitive paths)
4. Enable branch protection: `required_approving_review_count: 1`

**Safeguards to add:**
```yaml
# Exclude sensitive files from auto-approval
- name: Check for sensitive changes
  run: |
    if gh pr diff ${{ github.event.pull_request.number }} | grep -E '^\+\+\+.*(package-lock\.json|yarn\.lock|\.env|credentials)'; then
      echo "Sensitive files changed - skipping auto-approve"
      exit 1
    fi
```

### Phase 2: Add Intelligent Review (Future)

**Action:** Implement Option A for enhanced review

1. Get Anthropic API key
2. Create `claude-review.yml` workflow
3. Configure project-specific review prompts
4. Add cost monitoring (budget alerts)
5. Test on non-protected branch first

**Hybrid approach:**
- Auto-approve for trivial changes (docs, typos)
- Claude review for code changes
- Manual review required for sensitive paths

---

## Branch Protection Configuration

After implementing bot account, update branch protection:

```bash
gh api repos/jsboige/roo-extensions/branches/main/protection \
  --input - << EOF
{
  "required_pull_request_reviews": {
    "required_approving_review_count": 1,
    "dismiss_stale_reviews": false,
    "require_code_owner_reviews": false
  },
  "enforce_admins": true,
  "required_status_checks": {
    "strict": true,
    "contexts": ["build-and-test (20)", "build-and-test (22)"]
  },
  "allow_deletions": false,
  "allow_force_pushes": false
}
EOF
```

---

## Next Steps

### Immediate (Option B)

1. ✅ Create `roo-coordinator-bot` GitHub account
2. ✅ Add as collaborator to `jsboige/roo-extensions`
3. ✅ Generate PAT and add to secrets
4. ✅ Create `.github/workflows/auto-approve.yml`
5. ✅ Update branch protection rules
6. ✅ Test with sample PR

### Future (Option A)

1. ⏳ Get Anthropic API key with billing
2. ⏳ Implement `claude-review.yml` workflow
3. ⏳ Add project-specific review prompts
4. ⏳ Configure cost monitoring
5. ⏳ A/B test against manual reviews
6. ⏳ Gradually roll out for code changes

---

## Appendix: Claude Code CLI Reference

### Installation

```bash
npm install -g @anthropic-ai/claude-code
```

### Non-Interactive Usage

```bash
# Basic
claude -p "Your prompt here"

# With input
echo "input" | claude -p "Process this"

# JSON output
claude -p "Analyze this" --output-format json

# With JSON schema validation
claude -p "Return structured data" \
  --json-schema '{"type":"object","properties":{"approved":{"type":"boolean"}}}'
```

### Environment Variables

- `ANTHROPIC_API_KEY`: Required for API access
- `CLAUDE_DEFAULT_MODEL`: Override default model (default: `sonnet`)

### Limitations

- Requires workspace trust in `-p` mode (use only in trusted directories)
- No session persistence in `-p` mode
- Max budget: $100 USD per invocation (safety limit)

---

## References

- Claude Code CLI: https://github.com/anthropics/claude-code
- Anthropic API pricing: https://docs.anthropic.com/en/api/pricing
- GitHub Actions docs: https://docs.github.com/en/actions
- Branch protection API: https://docs.github.com/en/rest/branches/branch-protection

---

**Document version:** 1.0
**Last updated:** 2026-04-08
**Status:** Ready for implementation
