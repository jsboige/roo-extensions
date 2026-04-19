# Research: Native Claude Code PR Review Tools

**Issue:** #1522
**Date:** 2026-04-19
**Author:** Claude Code (myia-po-2023)
**Status:** Phase 0 — Audit & Decision

---

## Context

Issue #1522 requests evaluation of native Claude Code tools for PR review, to reduce dependency on `sk-agent` MCP. Current state: PR reviews use a home-made `pr-reviewer` subagent backed by `sk-agent` (local LLM via z.ai GLM). Quality is inconsistent due to model limitations.

## Inventory of Available Tools

### 1. Claude Code Subagents (Agent Tool)

Claude Code has no built-in `/review` command or native PR review subagent. Subagents are **home-made** via `.claude/agents/` markdown files.

**Our current `pr-reviewer` agent** (`.claude/agents/workers/pr-reviewer.md`):
- Model: `sonnet` (Anthropic, via Claude Code session)
- Tools: `Bash, Read, Grep, Glob`
- PR data: `gh pr view/diff/checks` CLI
- Output: Structured report (CRITICAL/WARNING/INFO)
- Limitation: Cannot post inline review comments (only stdout report)

**Key observation:** The `pr-reviewer` agent already uses Anthropic models (Sonnet) when invoked from a Claude Code session. The quality gap vs sk-agent is not the agent definition — it's that `sk-agent` routes to local GLM models by default.

### 2. GitHub Official MCP Server

**Package:** `github/github-mcp-server` (GitHub-maintained)
**Source:** https://github.com/github/github-mcp-server
**Auth:** GitHub personal access token (fine-grained PAT with repo scope)
**Deployment:** Remote (GitHub-hosted SSE) or local (Docker/binary)

**Relevant toolset — `pull_requests`:**

| Tool | Method | Description |
|------|--------|-------------|
| `pull_request_read` | `get` | PR metadata (title, body, state, labels) |
| `pull_request_read` | `get_diff` | Full diff of changes |
| `pull_request_read` | `get_status` | CI check status |
| `pull_request_read` | `get_files` | Changed files list |
| `pull_request_read` | `get_review_comments` | Existing review threads |
| `pull_request_read` | `get_reviews` | Submitted reviews |
| `pull_request_read` | `get_comments` | Issue-level comments |
| `pull_request_read` | `get_check_runs` | CI check run details |
| `pull_request_review_write` | — | Submit review (APPROVE/REQUEST_CHANGES/COMMENT) |

**Additional relevant tools:**

| Tool | Description |
|------|-------------|
| `search_code` | Search code across repos (find patterns, usage) |
| `get_file_contents` | Read any file at any ref (review context) |
| `list_commits` | PR commit history |
| `request_copilot_review` | Trigger Copilot review (supplementary) |

**Advantages over `gh` CLI:**
- Structured JSON output (no parsing)
- Direct review submission (APPROVE/REQUEST_CHANGES/COMMENT with inline comments)
- Access to review threads and CI check runs in one call
- GitHub-maintained, official

**Limitations:**
- Requires PAT token (additional credential to manage)
- No semantic code understanding (still needs LLM for analysis)
- Remote SSE transport has latency; local Docker adds ops burden

### 3. Community Tools

- **`anthropics/claude-code`** CLI: No built-in review features. Subagents are the extension point.
- **GitHub Copilot Review:** Available via `request_copilot_review` in GitHub MCP. Complementary, not replacement for LLM-based deep review.

### 4. sk-agent (Current)

- **Models:** z.ai GLM-5, local vLLM, OWUI proxy
- **Quality:** Adequate for simple reviews; misses integration bugs, dual-definition patterns, silent failures
- **Incident:** #1471 — BLOCKER-3 (workspace-loss bug) passed through sk-agent review on PR #124
- **Context tracing:** Not supported natively; requires explicit prompting

## Comparison Matrix

| Criterion | pr-reviewer (subagent) | GitHub MCP Server | sk-agent |
|-----------|----------------------|-------------------|----------|
| **Model** | Anthropic Sonnet/Opus | N/A (tool only) | GLM-5, vLLM |
| **PR data access** | `gh` CLI (parse output) | Structured API (JSON) | `gh` CLI |
| **Inline comments** | No (stdout only) | Yes (`pull_request_review_write`) | No |
| **Review submission** | Manual (comment via `gh`) | Direct (APPROVE/REQUEST_CHANGES) | Manual |
| **CI status** | `gh pr checks` | `get_status`, `get_check_runs` | `gh pr checks` |
| **Code search** | Grep/Glob (local) | `search_code` (GitHub-wide) | N/A |
| **File context** | Read (local checkout) | `get_file_contents` (any ref) | Read |
| **Review threads** | Not accessible | `get_review_comments` | Not accessible |
| **Custom prompts** | Full (markdown agent def) | N/A | Full (system prompt) |
| **Setup cost** | Zero (built-in) | PAT + MCP config | Already deployed |
| **Ops burden** | None | Token rotation, MCP uptime | Model availability |
| **Context tracing** | Via CLAUDE.md rules | Manual prompting | Manual prompting |
| **Integration tracing** (#1471) | Agent prompt defines it | N/A | Weak |

## Decision: HYBRID Approach

### Recommendation

**Keep `pr-reviewer` subagent as primary, upgrade model quality, optionally add GitHub MCP Server.**

**Phase 1 — Immediate (no infra change):**
1. Upgrade `pr-reviewer.md` to use `model: opus` for PRs >50 LOC (per #1471 policy)
2. Strengthen the agent prompt with the integration tracing template from `docs/harness/coordinator-specific/pr-review-policy.md`
3. Add anti-pattern detection (`.catch(() => {})`, fire-and-forget, dual-definition)

**Phase 2 — Optional enhancement:**
1. Add GitHub MCP Server to Claude Code config for richer PR context
2. Enable inline review comments via `pull_request_review_write`
3. Use `search_code` for cross-repo pattern detection

**Phase 3 — NOT recommended:**
- Replacing `pr-reviewer` with sk-agent for complex reviews
- sk-agent remains useful for batch/multi-model reviews of simple PRs only

### Rationale

1. **Model quality > tool access.** The `pr-reviewer` subagent already runs on Anthropic models when invoked from Claude Code. The gap is using Opus for complex PRs, not getting more tools.
2. **`gh` CLI is sufficient.** Our agent already reads PR diffs, checks CI, and reads files. GitHub MCP adds incremental value (inline comments, review threads) but isn't critical.
3. **sk-agent is the weak link.** GLM models miss integration bugs. Per #1471, reviews must use integration tracing — this requires strong reasoning, not just data access.
4. **Low setup cost.** Upgrading the agent prompt and model is zero-infra. GitHub MCP Server requires PAT management and MCP config across 6 machines.

### What NOT to do

- Don't replace `pr-reviewer` with a GitHub Copilot-only flow (no custom prompts)
- Don't use sk-agent for PRs >50 LOC (proven insufficient, #1471)
- Don't add GitHub MCP Server to all 6 machines upfront (start with ai-01 coordinator)

## Acceptance Criteria Mapping

| Criterion | Status | Evidence |
|-----------|--------|----------|
| Audit document committed | Done | This file |
| Custom vs native decision | Done | HYBRID (keep custom, upgrade model) |
| Recommendation with justification | Done | Section above |
| Comparison matrix | Done | Table above |

---

## Next Steps for #1522

- [ ] Phase 1: Update `pr-reviewer.md` prompt with integration tracing template
- [ ] Phase 1: Set `model: opus` for complex PR reviews
- [ ] Phase 2 (optional): Evaluate GitHub MCP Server on ai-01
- [ ] Close #1522 after Phase 1 implementation

---

**Sources:**
- `.claude/agents/workers/pr-reviewer.md` — Existing agent definition
- GitHub MCP Server README — https://github.com/github/github-mcp-server
- Claude Code documentation — https://docs.anthropic.com/en/docs/claude-code
- Issue #1471 — Integration tracing policy
- Issue #1522 — Original request
