# ADR 009: NanoClaw V2 — 4th GitHub Identity for Independent PR Review

**Date:** 2026-05-04
**Status:** Proposed
**Issue:** #1714
**Related:** #1767 (self-merge protocol), #1771 (self-merge docs)

## Context

The cluster operates 5 machine accounts on 2 repos:

| Account | Role | Permission |
|---------|------|-----------|
| jsboige | Human (admin) | admin |
| myia-ai-01 | Coordinator | write |
| myia-po-2023/24/25/26 | Workers | write |
| MyIA-Web1 | Worker | write |
| clusterManager-Myia | CI/automation | write |

### The Self-Review Problem

**roo-extensions (parent):**
- `enforce_admins: false`, `require_code_owner_reviews: false`
- 1 approval required
- CODEOWNERS: `@jsboige @myia-ai-01`
- Workers create PRs → coordinator (myia-ai-01) reviews → merges
- Effectively: same team reviews its own work

**jsboige-mcp-servers (submod):**
- `enforce_admins: true`, `require_code_owner_reviews: true`
- 1 approval required
- CODEOWNERS: `@jsboige @myia-ai-01`
- Only @jsboige or @myia-ai-01 can approve via CODEOWNERS
- Workers create PRs → coordinator must approve → but coordinator IS one of the 2 CODEOWNERS
- Result: coordinator reviews own team's PRs, or admin bypass (DELETE/POST enforce_admins) needed

**Impact:**
1. Coordinator spends time on mechanical reviews (trivial PRs, pointer bumps, docs)
2. `enforce_admins` bypass is destructive (DELETE → merge --admin → POST)
3. No genuinely independent review exists — all reviewers share the same infrastructure and incentives
4. Submod PRs pile up waiting for CODEOWNERS review from ai-01

### NanoClaw V2 — Existing Infrastructure

NanoClaw V2 runs as a Docker container on ai-01 with 4 GitHub tokens:
- GH_TOKEN_JSBOIGE (admin)
- GH_TOKEN_JSBOIGEEPITA
- GH_TOKEN_JSBOIGEECE
- GH_TOKEN_JSBOIGEEPF

The 4th token (jsboigeEPF) is NOT currently a collaborator on either repo. If added, it would be a separate GitHub identity capable of independent review.

## Decision

### Options Considered

#### Option A: jsboigeEPF Collaborator + NanoClaw Reviewer (RECOMMENDED)

Add jsboigeEPF as collaborator on both repos. Configure NanoClaw V2 to provide automated PR reviews using this identity.

**Setup:**
1. `gh api repos/jsboige/roo-extensions/collaborators/jsboigeEPF -X PUT -f permission=write`
2. `gh api repos/jsboige/jsboige-mcp-servers/collaborators/jsboigeEPF -X PUT -f permission=write`
3. Update CODEOWNERS on both repos: `* @jsboige @myia-ai-01 @jsboigeEPF`
4. Configure NanoClaw review workflow (trigger on [REVIEW-NEEDED] tag or CI green)

**Review rules (NanoClaw config):**
| Condition | Action |
|-----------|--------|
| LOC <= 50 + tests-only/docs-only | Auto-approve with `[NANOCLAW-REVIEW]` |
| LOC > 50 + CI green | Structured review per pr-review-policy.md s2 |
| CI failing | Wait, do not approve |
| Author = jsboigeEPF | Skip (self-review prevention) |

**Pros:**
- Simplest setup (3 API calls + config)
- NanoClaw already has the token, already runs on ai-01
- Satisfies CODEOWNERS requirement on submod (jsboigeEPF is a real collaborator)
- Independent identity — different from all 5 machine accounts
- Can provide fast reviews (minutes, not hours)

**Cons:**
- jsboigeEPF is still controlled by the same human (but this is true of all accounts)
- Single point of failure: NanoClaw runs on ai-01, if ai-01 is down, no reviews
- PAT token needs rotation schedule
- Review quality depends on NanoClaw's LLM quality (no Opus-level review)

**Risk: LOW** — Adding a collaborator is reversible. Review rules can be tuned.

#### Option B: GitHub App

Create a GitHub App with PR read/write permissions, install on both repos.

**Setup:**
1. Create GitHub App at developer.github.com
2. Set permissions: `pull_requests: write`, `contents: read`, `checks: read`
3. Install on both repos
4. Implement webhook handler or polling mechanism for review triggers
5. Generate installation token for API calls

**Pros:**
- Official GitHub mechanism, no ToS concerns
- Fine-grained permissions (only PR review, no repo admin)
- Token auto-rotation via installation tokens (1hr expiry)
- Can appear as "bot" in PR reviews (clear provenance)

**Cons:**
- Significantly more complex setup (webhook server, JWT generation)
- For personal repos (not org), the App approval flow is manual
- GitHub App cannot be a CODEOWNER (only users/teams)
- Overkill for a single-developer project
- Webhook handler requires a public endpoint or polling infrastructure

**Risk: MEDIUM** — GitHub App setup has many moving parts. CODEOWNERS limitation means this doesn't solve the submod branch protection issue without also adding a user account.

#### Option C: Structural — Relax Submod Protection + Self-Merge Protocol

Remove `require_code_owner_reviews` on submod, rely on self-merge protocol (#1767) documented conventions.

**Setup:**
1. `gh api repos/jsboige/jsboige-mcp-servers/branches/main/protection/required_pull_request_reviews -X PATCH -f require_code_owner_reviews=false`
2. Document self-merge rules in coordinator guide
3. Add CI checks for quality gates (lint, test coverage thresholds)

**Pros:**
- Zero new infrastructure
- Immediate resolution of PR pileup
- CI provides objective quality gates

**Cons:**
- Removes the last structural barrier to unchecked merges
- Relies entirely on convention (which already failed — cycle 17 audit)
- Does not provide independent review
- Goes against the original intent of adding protection, not removing it

**Risk: HIGH** — History shows convention-only approaches fail in this project (cycle 17 incident, #1767 audit).

### Recommendation

**Option A (jsboigeEPF + NanoClaw)** for Phase 1, with a path to Option B (GitHub App) for Phase 2 if the pilot succeeds.

**Rationale:**
1. **Speed to value:** 3 API calls + NanoClaw config vs. webhook server + JWT flow
2. **CODEOWNERS compatibility:** Only user accounts can be CODEOWNERS. jsboigeEPF works, GitHub App doesn't.
3. **Existing infrastructure:** NanoClaw already runs, already has the token, already understands the repo structure
4. **Reversible:** If it doesn't work, remove collaborator and CODEOWNERS entry

## Implementation Plan

### Phase 1: Pilot (this ADR, ~2 weeks)

| Step | Action | Owner |
|------|--------|-------|
| 1 | Add jsboigeEPF collaborator on both repos | ai-01 (admin) |
| 2 | Update CODEOWNERS on both repos | ai-01 |
| 3 | Configure NanoClaw review trigger ([REVIEW-NEEDED] tag on dashboard) | ai-01 |
| 4 | Implement review rules (trivial auto-approve, structured for >50 LOC) | NanoClaw config |
| 5 | Pilot 2 weeks — track metrics | all machines |

**Metrics to track:**
- Time from PR creation to first review (before vs. after)
- Number of enforce_admins bypasses (before vs. after)
- Review quality (false positives, missed issues)
- NanoClaw uptime during pilot

### Phase 2: Production (conditional on Phase 1 success)

- Evaluate GitHub App migration if PAT management becomes burden
- Add review quality checks (require CI green before NanoClaw approves)
- Integrate with team pipeline stages (#1853)
- Consider adding jsboigeEPF to PR creation workflow for trivial PRs

## API Rate Limits Consideration

GitHub personal access tokens have a rate limit of 5,000 requests/hour. With 6 machines creating ~50 PRs/week:
- Review API calls: ~2 per PR (review + comment) = ~100/week
- Well within rate limits, even with NanoClaw polling for review triggers

## Consequences

- **Branch protection satisfied:** jsboigeEPF approval counts toward CODEOWNERS requirement
- **Self-merge cycle broken:** jsboigeEPF is independent from all 5 machine accounts
- **Coordinator workload reduced:** Mechanical reviews delegated to NanoClaw
- **Single point of failure:** NanoClaw on ai-01. Mitigation: fallback to manual review if NanoClaw is down.
- **Token security:** jsboigeEPF PAT stored in NanoClaw container env. Rotation schedule recommended (90 days).
