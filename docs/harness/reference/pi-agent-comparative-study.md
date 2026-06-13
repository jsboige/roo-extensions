# Comparative Study — Pi Agent / pi-subagents / devstack vs RooSync + Claude Code

**Issue :** [#2416](https://github.com/jsboige/roo-extensions/issues/2416)
**Auteur :** myia-po-2026 (GLM-5.1, Claude Code)
**Date :** 2026-06-13
**Statut :** Draft v1 — first research pass (issue dispatched to po-2026 by ai-01 on 2026-05-28, no prior deliverable)

---

## 1. Scope

Comparative analysis of three alternative / open-source agent harness ecosystems against our current stack:

- **Our stack :** RooSync v2.3 + Claude Code + Roo Code + roo-state-manager MCP (15 tools) + 6-machine fleet
- **Subjects :** [Pi Agent](https://github.com/earendil-works/pi) (56.8k★, MIT, v0.76.0), [pi-subagents](https://github.com/nicobailon/pi-subagents) (1.6k★), [devstack](https://github.com/lhl/devstack) (21★)

Goal: identify migration opportunities, adaptation patterns, and architectural inspiration. The study is **documentary and architectural** — no code migration is proposed without a follow-up issue.

> **Note on tool count:** The dispatch body cites "34 MCP tools" — that count is stale (pre-CONS consolidation). Current roo-state-manager exposes **15 tools** (`CLAUDE.md:42`, verified by `tool-definitions.ts` + independent MCP audits po-2026/ai-01 2026-06-13). The architectural comparison holds regardless.

---

## 2. Subjects Overview

### 2.1 Pi Agent (`earendil-works/pi`)

TypeScript monorepo coding-agent toolkit. Key packages:

| Package | Role |
|---------|------|
| `pi-ai` | Unified multi-provider LLM API (Claude, GPT, Gemini, Bedrock, Vertex, OpenRouter, local) |
| `pi-agent-core` | Agent runtime, tool calling, state management |
| `pi-coding-agent` | CLI coding harness (TUI) |
| `pi-tui` | Terminal UI |

**Notable features:** non-blocking UI (model/effort/status switching while running), advanced session history (`/tree`, `/fork`, `/clone` for branching/time-travel), hot-reload extensions (`/reload` without restart), extreme customizability ("tell pi to change itself").

### 2.2 pi-subagents (`nicobailon/pi-subagents`)

Async subagent delegation extension for Pi. **Note:** this is a third-party extension by the same author — Pi core ships *without* sub-agents (per pi.dev), so everything below is extension-provided, not built-in. **Strongest parallel to our architecture:**

- 8 built-in agents: scout, researcher, planner, worker, reviewer, context-builder, oracle, delegate (plus a user-defined `custom` mode)
- Execution modes: **parallel, chain, background** — direct analog of our executor/meta patterns
- **Worktree isolation** per subagent (we do this via `.claude/worktrees/`)
- **Intercom bridge** for cross-agent communication (analog of our dashboard workspace)
- Recursion guards + skill injection

### 2.3 devstack (`lhl/devstack`)

"Agentic practices knowledge base + supporting software toolkit" — opinionated guide. Key insights:

- **Karpathy LLM Wiki pattern:** structured KB with `inbox/` → `sources/` → `wiki/` pipeline (we approximate via MEMORY.md + `codebase_search`)
- **Extension ecosystem curation:** `pi-packages.json` manifest for fleet-wide consistent setups
- **Context-management tools:** `pi-context-prune` (recoverable summarization), `pi-vcc` (zero-LLM algorithmic compaction), `pi-continue-after-compaction`
- **`pi-multiloop`:** battle-tested autoloop for long-running sessions (analog of our executor cycles)
- **`pi-multicodex`:** automatic account rotation for quota/rate limits

---

## 3. Axis A — Architecture Comparison

| Aspect | Our Stack | Pi + Extensions |
|--------|-----------|-----------------|
| Agent runtime | Claude Code (Anthropic) + Roo Code (extension) | `pi-agent-core` (customizable TS) |
| LLM providers | Claude API + GLM/z.ai + vLLM (self-hosted) | Unified `pi-ai` (Claude, GPT, Gemini, Vertex, Bedrock, OpenRouter, local) |
| Multi-machine | **6 machines**, RooSync GDrive sync, dashboard workspace | Single-machine focus (subagents are local) |
| Coordination | Dashboard workspace + RooSync messages + `ROO_FLEET_ROSTER` partitioning | Intercom bridge (local subagents only) |
| State persistence | SQLite + Qdrant + GDrive | Session history with fork/clone |
| Context management | Auto-compaction (200k/90% universal) | `pi-vcc` (algorithmic, zero-LLM), `pi-context-prune` (recoverable) |
| Scheduler | schtasks + `start-claude-worker.ps1` + cron 2h | `pi-multiloop` (manual loop) |

**Architectural verdict:** Our stack and Pi optimize for **different scales**. Pi is a polished single-machine coding harness; our value proposition is fleet coordination across 6 physical machines. They are not substitutes at the architecture level.

---

## 4. Axis B — What They Do Better

1. **LLM provider abstraction** — `pi-ai` unified API vs our ad-hoc per-provider config (`ANTHROPIC_BASE_URL` switches, `sk-agent` for vision)
2. **Non-blocking UI** — Pi allows model/status operations mid-run
3. **Session branching** — `/fork`, `/clone`, `/tree`; we have no equivalent
4. **Zero-LLM compaction** — `pi-vcc` uses deterministic extraction (no summarizer model → avoids 400 errors / fallback-truncation on long sessions)
5. **Recoverable pruning** — `pi-context-prune` keeps originals retrievable on demand (our auto-compaction is destructive)
6. **Extension hot-reload** — `/reload` without restart vs our VS Code restart requirement (#2532 driver)
7. **Account rotation** — `pi-multicodex` handles multi-account quota automatically
8. **Auto-continue post-compaction** — watches and sends continue; prevents stalls

---

## 5. Axis C — What We Do Better

1. **Multi-machine fleet coordination** — 6 machines, RooSync GDrive sync, heartbeat, dashboard workspace. Pi is single-machine.
2. **Cross-machine task dispatching** — hash-based partitioning (`ROO_FLEET_ROSTER`, `task-partition.ts`), claim discipline, anti-double-claim
3. **MCP ecosystem** — `roo-state-manager` (15 tools) for coordination, semantic search, conversation indexing across the fleet
4. **Scheduler integration** — schtasks + worker scripts + cron 2h for autonomous cycles (vs `pi-multiloop` manual loop)
5. **Agent claim discipline** — verified claims, `git cat-file -e`, SHA verification, pre-claim anti-overlap (`agent-claim-discipline.md`)
6. **CI/CD pipeline** — `check-submodule-pointer`, `validate-before-push.ps1`, PR mandatory rules, tier-gate
7. **Durability** — dashboard-listener self-healing wrapper + in-loop heartbeat (#2431); the 2026-06-13 2h cluster crash (po-2023 disk full → wsl/docker/claudish down) left all 5 listeners alive, proving the design

---

## 6. Axis D — Migration / Adaptation Opportunities (Decision Matrix)

For each opportunity: **Decision = Adopt / Adapt / Defer**, with effort and impact.

| # | Opportunity | Source | Effort | Impact | Decision | Rationale |
|---|-------------|--------|--------|--------|----------|-----------|
| 1 | Unified LLM provider layer | `pi-ai` | Medium | Medium | **Defer** | We already route via `ANTHROPIC_BASE_URL` + z.ai router + `sk-agent`. A full `pi-ai`-style abstraction is valuable only if we adopt Pi as a runtime. Keep on backlog; revisit if fleet standardizes on Pi. |
| 2 | Zero-LLM compaction | `pi-vcc` | Medium | **High** | **Adapt (prototype)** | Our summarizer-based compaction hits 400 errors / fallback-truncation on long sessions (circuit-breaker documented). A deterministic extraction pass before LLM summarization could reduce model calls. **Top candidate for a follow-up issue.** |
| 3 | Recoverable context pruning | `pi-context-prune` | Medium | Medium | **Adapt** | Pairs with #2. Our auto-compaction is destructive; keeping pruned content retrievable (Qdrant-backed) would make compaction lossless-on-demand. Follow-up issue bundles with #2. |
| 4 | Session branching/forking | Pi `/fork`/`/clone` | High | Medium | **Defer** | Requires deep harness changes (Claude Code session model). Not worth the cost given we already have worktrees + git branching for parallel work. |
| 5 | Extension hot-reload | Pi `/reload` | Low (if Pi adopted) | Medium | **Defer** | Harness-level feature; only relevant if we migrate to Pi. Our workaround is session restart (#2532). |
| 6 | Auto-continue post-compaction | `pi-continue-after-compaction` | Low | Medium | **Adapt** | Low-hanging fruit: a small watcher that sends `continue` after auto-compact prevents stalls. Could be a scheduler schtask. Candidate follow-up issue. |
| 7 | Account/key rotation | `pi-multicodex` | Low | Medium | **Adapt** | We already rotate keys (env rotation #864, `.env` post-rotation). A generalized multi-key round-robin for API quotas would help on high-throughput cycles. Candidate follow-up. |
| 8 | Worktree per-subagent | `pi-subagents` | Medium | Low | **Already have** | We already isolate via `.claude/worktrees/` (`pr-mandatory.md`). No change needed. |
| 9 | Fleet extension manifest | devstack `pi-packages.json` | Low | Medium | **Adapt** | A declarative manifest listing the canonical MCP/skill/rule set for each machine would reduce config drift (idle task I4). **Candidate follow-up issue** — aligns with `roosync_compare_config`. |
| 10 | Karpathy wiki pattern | devstack `inbox→sources→wiki` | Low | Low | **Already approximate** | We have MEMORY.md + `codebase_search` + `conversation_browser`. The `inbox→sources→wiki` pipeline is more structured but our SDDD bookend pattern covers the need. Defer unless knowledge-management gaps emerge. |

---

## 7. Top 3 Adaptation Opportunities (Acceptance Criterion #2)

Ranked by impact/effort ratio:

### 🥇 #2 + #3 — Deterministic + recoverable compaction (bundle)
- **Why:** Long sessions hit summarizer 400 errors → fallback truncation (circuit-breaker). Deterministic pre-extraction reduces model load; Qdrant-backed pruned content makes compaction lossless-on-demand.
- **Concrete plan:** Prototype a `deterministic-prune.ts` in roo-state-manager that (a) extracts tool-result blocks + verbatim code into a side-store keyed by message index, (b) replaces them with a recoverable pointer, (c) runs *before* LLM summarization. Gate behind a flag. Measure summarizer-call reduction over 5 sessions.
- **Follow-up issue:** yes.

### 🥈 #9 — Fleet extension manifest
- **Why:** Config drift across 6 machines is a recurring idle-task finding (I4). A declarative manifest (`fleet-manifest.json`: MCP servers, skills, rules per machine role) + a `verify-manifest` script would make drift a CI-checkable invariant.
- **Concrete plan:** Define schema (machine role → expected MCP list + skill list). Script `scripts/scheduling/verify-fleet-manifest.ps1` compares `~/.claude.json` + `.mcp.json` against manifest, exits non-zero on drift. Wire into coordinator cycle.
- **Follow-up issue:** yes.

### 🥉 #6 — Auto-continue post-compaction
- **Why:** Lowest effort. A schtask watcher that detects post-compact state and injects `continue` prevents dead cycles after auto-compaction.
- **Concrete plan:** Tiny `pi-continue`-equivalent: schtask every 2 min checks a sentinel (session idle + just-compacted marker) → sends continue. 50-line script.
- **Follow-up issue:** yes.

---

## 8. Decision Summary (Acceptance Criterion #3)

| Decision | Count | Items |
|----------|-------|-------|
| **Adapt** (prototype in our stack) | 4 † | #2, #3 (bundle), #6, #7, #9 |
| **Defer** (revisit if Pi adopted / backlog) | 4 | #1, #4, #5 |
| **Already have / approximate** | 2 | #8, #10 |

† Count is post-bundle: #2 and #3 are tracked as a single follow-up (deterministic + recoverable compaction), so 5 line-items collapse to 4 distinct adaptations.

**Net recommendation:** Do **not** migrate to Pi as a runtime (our fleet-coordination value is orthogonal and stronger at our scale). **Do** adapt the three compaction/manifest/continue patterns — they are harness-agnostic and improve our existing stack without a migration bet.

---

## 9. Acceptance Criteria Status

- [x] Comparative analysis document created in `docs/harness/reference/` — **this file**
- [x] Top 3 adaptation opportunities identified with concrete implementation plans — §7
- [x] Decision documented: adopt / adapt / defer for each opportunity — §6, §8
- [ ] If adopting: issues created for implementation tasks — **deferred to follow-up** (3 issues to create: compaction bundle, fleet manifest, auto-continue). Will be created in a follow-up cycle or by the coordinator.

---

## 10. Context

- Current stack: RooSync v2.3 + Claude Code + Roo Code + roo-state-manager (15 MCP tools) + 6-machine fleet
- Executor cycles: 2h cadence (`CronCreate`), auto-stop after 3 IDLE (#2185), wake routing via `[WAKE-CLAUDE]`
- Compaction: 200k/90% universal threshold (`context-window.md`), auto-condensation at 92% dashboard
- Post-crash note (2026-06-13): the 2h cluster crash (po-2023 disk full) left all 5 dashboard-listeners alive — corroborates §5.7 (our durability design works)

---

**References:**
- [Pi Agent](https://github.com/earendil-works/pi) · [pi-subagents](https://github.com/nicobailon/pi-subagents) · [devstack](https://github.com/lhl/devstack)
- Issue [#2416](https://github.com/jsboige/roo-extensions/issues/2416)
- Internal: [`condensation-thresholds.md`](condensation-thresholds.md), [`pr-mandatory.md`](../../../.claude/rules/pr-mandatory.md), [`tool-availability.md`](../../../.claude/rules/tool-availability.md)
