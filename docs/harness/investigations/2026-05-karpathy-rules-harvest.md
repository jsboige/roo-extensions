# Karpathy Skills & Agent-Rules-Books Harvest Investigation

**Date:** 2026-05-04
**Issue:** #1936
**Analyst:** myia-po-2026 (reconciling 3 prior analyses from po-2023 and po-2026)
**Sources:** [forrestchang/andrej-karpathy-skills](https://github.com/forrestchang/andrej-karpathy-skills) (MIT) + [ciembor/agent-rules-books](https://github.com/ciembor/agent-rules-books) v0.4 (MIT)

---

## Methodology

Three independent gap analyses were produced on 2026-05-03:

| # | Analyst | Scope | Key Finding |
|---|---------|-------|-------------|
| 1 | po-2023 | Karpathy 4 principles only (agent-rules-books was 404) | 5 gaps, 5 adaptations proposed |
| 2 | po-2026 | Karpathy 4P + 6 book rulesets (agent-rules-books accessible) | SKIP most, ADAPT 1 (Release It! timeouts) |
| 3 | po-2023 | Karpathy 4P + 6 book rulesets | 3 recommendations (state assumptions, characterize, prep refactoring) |

This document reconciles all three against the **original source text** (fetched 2026-05-04) and our **actual rule base** (18 files in `.claude/rules/` + global `CLAUDE.md` + Claude Code system prompt).

---

## Karpathy 4 Principles — Verified Assessment

### Principle 1: Think Before Coding

> "Don't assume. Don't hide confusion. Surface tradeoffs."

| Aspect | Covered By | Verdict |
|--------|-----------|---------|
| State assumptions explicitly | `skepticism-protocol.md` (VERIFIE/RAPPORTE/SUPPOSE) | Covered |
| **Present multiple interpretations** | **No rule requires this** | **GAP** |
| Push back when warranted | `skepticism-protocol.md` smell tests | Reinforcement |
| Name what's confusing | `friction-protocol.md` [ASK] tags | Covered |

**Divergence:** po-2023 (#1) found 2 gaps. po-2026 (#2) said SKIP. po-2023 (#3) said GAP.

**Verified:** The "present multiple interpretations" gap is real. When agents receive ambiguous dispatches (e.g., cycle 22ter pointer-bump cascade where 3 agents interpreted scope differently), no rule requires presenting interpretations before picking one. Our skepticism protocol says "verify before acting" but doesn't say "show your work on ambiguous scope."

**Harvest: ADAPT** — Add to `skepticism-protocol.md`: "When a dispatch or issue description is ambiguous (multiple valid interpretations exist), present at least 2 interpretations before acting. Tag the chosen interpretation."

---

### Principle 2: Simplicity First

> "Minimum code that solves the problem. Nothing speculative."

| Aspect | Covered By | Verdict |
|--------|-----------|---------|
| No features beyond what was asked | Claude Code system prompt: "Don't add features, refactor, or introduce abstractions beyond what the task requires" | **Covered (system-level)** |
| No abstractions for single-use | Claude Code system prompt: same | **Covered (system-level)** |
| No error handling for impossible scenarios | Claude Code system prompt: "Don't add error handling, fallbacks, or validation for scenarios that can't happen" | **Covered (system-level)** |
| If 200 lines could be 50, rewrite | Subjective; our validation counting catches bloat | Skip (impractical to enforce) |

**Divergence:** po-2023 (#1) found 4 gaps. po-2026 (#2) said SKIP. po-2023 (#3) said GAP.

**Verified:** All 4 "gaps" are covered by the **Claude Code system prompt itself** (not our rules files). po-2023's analysis missed this because it compared only against `.claude/rules/` files. The system prompt is loaded for every session and is more authoritative than any rule file.

**Harvest: SKIP** — No additions needed. Already covered at a higher level than rule files.

---

### Principle 3: Surgical Changes

> "Touch only what you must. Clean up only your own mess."

| Aspect | Covered By | Verdict |
|--------|-----------|---------|
| Don't improve adjacent code | Partial — Claude Code says "A bug fix doesn't need surrounding cleanup" but no rule for general edits | Reinforcement |
| Match existing style | Subjective | Skip |
| Report dead code, don't delete | `no-deletion-without-proof.md` | Covered |
| Remove only YOUR orphans | `validation.md` (count before/after) | Covered |
| **Every changed line traces to request** | **No explicit rule** | **GAP** |

**Divergence:** po-2023 (#1) found 2 gaps. po-2026 (#2) said SKIP. po-2023 (#3) said REINFORCED.

**Verified:** "Every changed line should trace directly to the user's request" is not stated anywhere. This is distinct from our validation counting (which counts lines changed) — it's a quality gate on WHY lines changed. Directly prevents scope creep.

**Harvest: ADAPT** — Add to `validation.md` checklist: "Every changed line in the diff traces to the task scope. Lines that don't trace = scope creep."

---

### Principle 4: Goal-Driven Execution

> "Define success criteria. Loop until verified."

| Aspect | Covered By | Verdict |
|--------|-----------|---------|
| Transform tasks into verifiable goals | Team pipeline team-plan + team-verify | Covered |
| State plan with verify checks | Team pipeline stages | Covered |
| **Strong vs weak success criteria** | **No distinction exists** | **GAP** |
| Loop independently until verified | team-verify loop | Covered |

**Divergence:** po-2023 (#1) found 1 gap. po-2026 (#2) said SKIP. po-2023 (#3) said PARTIAL GAP.

**Verified:** The strong/weak criteria distinction is genuinely useful. "Make it work" = weak. "All 74 tests pass, build clean, no regressions" = strong. Our team-verify gate implicitly uses strong criteria but doesn't make the distinction explicit, which means agents sometimes set weak criteria in their [CLAIMED] posts.

**Harvest: ADOPT** — Add to `validation.md`: one-liner distinguishing strong vs weak success criteria with example.

---

## Book Rulesets — Verified Assessment

### Refactoring (Fowler) — 49 lines mini, 31 rules

| Rule | Covered By | Verdict |
|------|-----------|---------|
| Preserve observable behavior | `validation.md` (count before/after) | Covered |
| Small reversible steps | `pr-mandatory.md` (atomic commits) | Covered |
| Safety net before risky refactor | `ci-guardrails.md` (build + test) | Covered |
| **Separate structural from behavior changes** | **No explicit requirement** | **GAP** |
| Refactor blocking smell only | Global CLAUDE.md "Don't add features beyond task" | Covered |
| Preparatory refactoring before features | Implicit in our workflow, not stated | Skip (covered by validation counting) |

**Divergence:** po-2023 (#1) said SKIP. po-2026 (#2) said SKIP. po-2023 (#3) said ADOPT 2 rules.

**Verified:** "Separate structural from behavior changes" is the one actionable gap. Mixed-intent commits (refactoring + feature in same PR) are hard to review and have caused issues. But this is already partially addressed by our PR review policy requiring clear commit messages. The gap is narrow.

**Harvest: ADAPT** — Add to `ci-guardrails.md` or `validation.md`: "Prefer separate commits for structural changes (renaming, moving, reformatting) vs behavior changes (new features, bug fixes). Mixed-intent commits should be flagged in PR description."

---

### Release It! (Nygard) — 48 lines mini, 30 rules

| Rule | Covered By | Verdict |
|------|-----------|---------|
| Explicit timeouts | `mcp-diagnosis.md` healthcheck chain | Covered (for existing code) |
| Circuit breakers | N/A — not production services | Skip |
| Bounded queues/caches | Partial (`mcp-diagnosis.md`) | Skip |
| Validate external input | `security.md` OWASP | Covered |
| Observability at boundaries | `mcp-diagnosis.md` | Covered |

**Divergence:** po-2023 (#1) said SKIP. po-2026 (#2) said ADAPT 1 (timeouts). po-2023 (#3) said SKIP.

**Verified:** Our MCP chain already has healthchecks with timeouts (`mcp-chain-healthcheck.ps1`). The Release It! patterns (circuit breakers, bulkheads) are production resilience patterns not applicable to CLI/MCP dev tools. My previous analysis (ADAPT 1) was overly cautious — the timeout concern is addressed.

**Harvest: SKIP** — Production resilience patterns not applicable to our dev harness.

---

### Working Effectively with Legacy Code (Feathers) — 50 lines mini, 32 rules

| Rule | Covered By | Verdict |
|------|-----------|---------|
| Treat untested code as legacy | `validation.md` (tests mandatory) | Covered |
| Characterize before changing | `skepticism-protocol.md` + SDDD grounding | Covered |
| Find/create seams | Not applicable — not legacy codebase | Skip |
| Sprout method/class | PR-mandatory worktree isolation | Skip |
| Leave area more testable | `validation.md` (count tests) | Covered |

**Divergence:** All 3 analyses said SKIP or near-SKIP.

**Verified:** Our codebase is actively maintained (daily commits, comprehensive tests). Legacy Code techniques solve a problem we don't have at scale.

**Harvest: SKIP**

---

### The Pragmatic Programmer (Hunt & Thomas) — 65 lines mini, 47 rules

**Strongest overlap of all sources.** Every significant rule maps to an existing harness rule:
- DRY → `validation.md` + `no-deletion-without-proof.md`
- Orthogonality → `agents-architecture.md`
- Tracer bullets → worktree → PR → integration test flow
- Automate → `ci-guardrails.md` + scripts pipeline
- Broken windows → `friction-protocol.md`
- Debug from facts → `skepticism-protocol.md`

**Harvest: SKIP** — Fully covered.

---

### Clean Code (Martin) — 47 lines mini, 29 rules

Coding style standards (naming, function size, parameter count). Not agent behavior rules. Claude Code system prompt already addresses most of these ("default to writing no comments", "keep functions focused").

**Harvest: SKIP** — Style standards, not harness material.

---

### A Philosophy of Software Design (Ousterhout) — 46 lines mini, 28 rules

Design principles (deep modules, reduce exception surface, hide complexity). Relevant to MCP tool design (#1935 consolidation) but too abstract for harness rules. Should inform tool consolidation decisions, not become rules.

**Harvest: SKIP** — Design principles, not agent behavior rules.

---

## Consolidated Harvest Decision

### 4 Adaptations (Total: ~8 lines, ~150 tokens)

| # | Rule | Source | Target File | Lines | Prevents |
|---|------|--------|------------|-------|----------|
| 1 | Present multiple interpretations for ambiguous scope | Karpathy P1 | `skepticism-protocol.md` | 2 | Agents misreading dispatch scope (cycle 22ter cascade) |
| 2 | Every changed line traces to task scope | Karpathy P3 | `validation.md` | 1 | Scope creep in diffs |
| 3 | Strong vs weak success criteria distinction | Karpathy P4 | `validation.md` | 1 | Vague [CLAIMED] success criteria |
| 4 | Separate structural from behavior changes | Refactoring (Fowler) | `validation.md` | 2 | Hard-to-review mixed-intent commits |

### Skip List (with reasons)

| Source | Reason |
|--------|--------|
| Karpathy P2 (Simplicity First) | Covered by Claude Code system prompt at higher level |
| Release It! (Nygard) | Production resilience patterns, not applicable to CLI/MCP dev tools |
| Legacy Code (Feathers) | Codebase is actively maintained, not legacy |
| Pragmatic Programmer | Strongest overlap, fully covered by existing rules |
| Clean Code (Martin) | Coding style standards, not agent behavior rules |
| Philosophy of SW Design (Ousterhout) | Design principles, should inform decisions not become rules |

### Context Budget Impact

- Current rules: ~893 lines across 18 files + ~200 lines CLAUDE.md
- Proposed additions: ~6 lines
- Token increase: ~150 tokens (0.15% of 98K effective budget)
- **Impact: negligible**

---

## Repo 2 Status: `ciembor/agent-rules-books` v0.4

**LIVE and accessible** as of 2026-05-04. Restructured since po-2023's 404: now flat directory with 3 versions per ruleset (full/mini/nano). The `unified-software-engineering` ruleset referenced in issue body no longer exists in v0.4.

---

## Key Takeaway

Our harness (18 rule files + global CLAUDE.md + Claude Code system prompt) already covers **~95%** of the externally-available structured rulesets. The 4 remaining gaps are narrow, targeted, and each addresses a documented friction incident. The main risk of broader adoption would be **context window bloat** — the 6 book rulesets alone represent ~300 lines of additional rules for marginal safety gains.

---

## Next Steps (Phase 3 — requires separate approval)

If approved, the 4 adaptations can be implemented as a single PR touching 2 files:
- `skepticism-protocol.md` — add interpretation rule
- `validation.md` — add trace, criteria, and separation rules
