# ADR 011 — MCP Split + VibeSync Rebrand (EPIC #2190 Phase 1)

**Status:** Amended — re-scoped to 2 MCPs + workspace trunk (user arbitrage 2026-06-11). Original 8-MCP proposal kept below for history.
**Date:** 2026-05-15
**Author:** myia-ai-01 (claude-interactive, R41 wake)
**Supersedes:** N/A (new architecture)
**Related:** #1935 (origin user mandate), #1841 (consolidation audit), EPIC #2190 (this work), #2197 / ADR 010 (conversation_browser GDrive storage, complementary)
**Data source:** [po-2025 Phase 1 data mapping](https://github.com/jsboige/roo-extensions/issues/2190#issuecomment-4459593168) (94,767 LOC, 26 tools, 8 candidate MCPs mapped 2026-05-15T12:06Z)

---

## Amendment 2026-06-11 — Re-scope: 2 MCPs + workspace trunk (user arbitrage)

**User verdict (2026-06-11):** the 8-MCP plan is **overkill**. The granularity that matters operationally is two families — multi-machine coordination ("Config-sync") vs conversational state — and detail questions only come after the coarse cut is settled. The user validated the following 2-MCP cut the same day.

### Amended decision

| MCP | Role | Tools (of the current 15) |
|---|---|---|
| **`vibesync`** | Multi-machine coordination (Config-sync) | `roosync_dashboard`, `roosync_messages`, `roosync_config`, `roosync_compare_config`, `roosync_baseline`, `roosync_inventory`, `roosync_mcp_management` (7) — plus future #2406 Phase 2 tools (`roosync_schtasks`, `roosync_services`, `roosync_secrets`, see ADR 013) |
| **`vibe-conversations`** | Conversational state, search & indexing | `conversation_browser`, `codebase_search`, `roosync_search`, `roosync_indexing`, `export_data`, `roosync_storage_management`, `roosync_diagnose`, `read_vscode_logs` (8) |

- **Cut rationale:** the two install populations are disjoint. `vibesync` is what ANY fleet participant needs to coordinate (Zoo machines, infra workspaces like postgres/vllm/qdrant, bots). `vibe-conversations` only makes sense where Roo/Claude conversation histories exist to browse and index. Two processes ↔ two real deployment audiences — not eight.
- **Trunk:** `@vibesync/core` becomes an **npm workspaces package inside the monorepo** (`mcps/internal`), imported locally by both MCPs. No npm registry, no publish flow → **closes open question 2** (neither registry nor vendor copy).
- **Monorepo retained** (**closes open question 7**): workspaces packaging requires it, and it avoids multiplying submodule pointer-bump pain (#1799).
- **Search bundling (open question 3) resolved by the cut:** `search/` + `indexing/` both land in `vibe-conversations`; the vector cluster (openai/qdrant/task-indexer) never crosses an MCP boundary.
- **Migration = single breaking-change window** (replaces Waves 1-3): one extraction (`vibe-conversations`) + one rename (remainder → `vibesync`). Rebrand happens in that same window (**closes open question 6**, "coupled" direction).
- **Tool-count cap relaxed** (user, same arbitrage): *"passer de 15 à 16 outils n'est pas du tout un pb pour moi si c'est justifié, on en avait plus de 50 quand on a entamé la réduction."* The anti-proliferation principle stays, but a justified top-level tool is acceptable — directly relevant to ADR 013.

### Remaining detail questions (settle at implementation time)

1. Final names — `vibe-conversations` vs `vibesync-conversations` (residue of Q1, single vs dual prefix).
2. Migration window timing (residue of Q4) — sequenced **after** the unified store Postgres lands (#2191/#2553), per the 2026-06-11 archaeology on #2190.
3. Shim duration (residue of Q5) — simplified to a single window covering both the extraction and the rename.

The Waves 1-3 plan, the 8-MCP table and open questions 1-7 below are kept for history and **superseded by this amendment**.

---

## Context

The `roo-state-manager` MCP has grown protéiforme: **26 tools, 94,767 LOC, 36K services, 14K utils, 8 distinct functional domains**. Cycle 32 W8 consolidation reduced tool count 34→30 but the audit revealed irreducible coupling within the monolith:

- A single MCP serves agents in 8 disjoint usage contexts (dashboard, intercom, conversation browser, config, infra, indexing, export, diagnose).
- Hot path (dashboard + messages) shares process with cold path (export, diagnose) → restart for hot fixes blocks cold path; cold path bugs can crash hot path.
- Naming: `roo-state-manager` ties identity to "Roo" while the MCP serves Claude Code, Hermes, NanoClaw, future Zoo. Coordination friction.
- Rebrand cost ≈ migration cost for split. Doing both together = single breaking-change window.

**User mandate (#1935, 2026-05-15 ~11:05Z)** mandated:
1. **Split** the MCP into multiple disjoint MCPs (with or without shared trunk depending on analysis)
2. **Rebrand** away from `roo-*` naming (e.g., `vibesync-*`, `vibe-*`)
3. **Investigation** of split candidates (dashboard / messages / conversation / config / search) **before** code
4. **Migration period** required (breaking change for Roo, Hermes, NanoClaw, scripts)
5. **EPIC #2190** absorbs #1935 (don't close prematurely)

This ADR proposes the **architecture** and **migration plan**. Phase 2+ ADRs will cover implementation details per Wave.

---

## Decision

**8 MCPs grouped in 3 Waves, with a shared `@vibesync/core` SDK trunk (~7-8K LOC).**

| Family | MCPs | Wave | Risk | Estimated LOC (tools + dedicated services) |
|---|---|---|---|---|
| **vibe-\*** (single-purpose tools) | `vibe-export`, `vibe-diagnose`, `vibe-indexing`, `vibe-conversation-browser` | 1 (export, diagnose, indexing), 3 (conv-browser) | Low to High | export: 3K · diagnose: 2K · indexing: 4.6K (with search bundle) · conv-browser: ~12K |
| **vibesync-\*** (multi-machine coordination) | `vibesync-intercom` (bundle dashboard+messages), `vibesync-config`, `vibesync-infra` | 2 (intercom, config), 3 (infra) | Moderate to High | intercom: ~14K · config: ~4K · infra: ~7K |
| **Shared trunk** | `@vibesync/core` (npm SDK, semver-versioned) | — | Required from Wave 1 | ~7-8K |

### Naming convention

- **`vibe-*`** = single-domain MCP serving one workflow (export a conversation, diagnose env, etc.). Stateless or near-stateless.
- **`vibesync-*`** = multi-machine state coordination MCP (intercom, config sharing, infra metrics). Holds shared state via GDrive `.shared-state/`.
- **`@vibesync/core`** = npm package shared library (FileLockManager, PresenceManager, state-manager.service, openai+qdrant clients, unified-task types, markdown-formatter, logger).

### Wave 1 (this ADR) — Low-risk extractions, validate architecture

**Goals:** Validate trunk SDK pattern + per-MCP packaging + agent integration before touching hot path.

1. **`vibe-export`** (~3K LOC tools + dedicated services TraceSummaryService, ExportConfigManager, XmlExporterService)
   - Dependencies on trunk: `task/` types only (light) → embed types or use SDK
   - **Hot path:** NO (on-demand only)
   - **Verdict:** Extract first. Lowest risk.

2. **`vibe-diagnose`** (~2K LOC tools: diagnostic + repair + best-practices + vscode logs)
   - Dependencies on trunk: minimal (uses `state-manager.service` interface, logger)
   - **Hot path:** NO (debug-only)
   - **Verdict:** Extract second. Lowest coupling.

3. **`vibe-indexing`** — **bundled with `search/`** (~4.6K LOC tools + 2.4K services: task-indexer, openai, qdrant)
   - Tightly coupled to `search/` via `openai.ts` + `qdrant.ts` + `task-indexer.ts`
   - **Decision (open question 3 below):** bundle indexing+search into one MCP `vibe-indexing` (covers both write path and read path of vector ops), avoiding cross-MCP coupling.
   - **Hot path:** YES but background-async (does not block tool responses)
   - **Verdict:** Extract third. Higher coupling but isolated cluster.

### Wave 2 — Moderate-risk extractions

4. **`vibesync-intercom`** (~14K LOC: bundle `dashboard/` 3.6K + `messages/` 3.3K + their services ~7K)
   - **Rationale for bundling:** dashboard append/read and messages send/read both consume `MessageManager`, `FileLockManager`, `PresenceManager`, `state-manager.service`. Splitting them creates 4-way file locking nightmare on GDrive.
   - **Hot path:** YES (every agent every tour)
   - **Migration risk:** HIGH (every machine must restart simultaneously)
   - **Verdict:** Bundle. Single hot-path MCP for all multi-machine coord.

5. **`vibesync-config`** (~4K LOC: config tools + ConfigSharingService, DiffDetector, RooSettingsService, PowerShellExecutor)
   - Dependencies: low cross-domain coupling, several dedicated services
   - **Hot path:** Moderate (used by `/sync-tour` and on-demand)
   - **Verdict:** Extract. Self-contained cluster.

### Wave 3 — High-risk, large surface

6. **`vibe-conversation-browser`** (~12K LOC: conversation + task + search¹ + summary + cache)
   - **¹** If indexing+search bundled in Wave 1 `vibe-indexing`, then conv-browser becomes ~10K LOC without search (uses `vibe-indexing` via SDK).
   - Shares `skeleton-cache.service` with intercom (read path), `RooSyncService` with infra, `openai`+`qdrant`+`task-indexer` with indexing
   - **Hot path:** YES (every coordination read)
   - **Migration risk:** HIGHEST (broad agent surface, ADR 010 #2191 already in flight for storage backend)
   - **Verdict:** Last. Wait for ADR 010 storage decision + Wave 1/2 stable.

7. **`vibesync-infra`** (~7K LOC: inventory + storage-management + baseline + heartbeat + machines + sync-event + claims)
   - Dependencies: `MessageManager`, `state-manager.service`, hot-path FileLockManager/PresenceManager
   - **Hot path:** YES (heartbeat every MCP call)
   - **Migration risk:** HIGH (heartbeat outage affects entire fleet awareness)
   - **Verdict:** Last alongside conv-browser. Heartbeat needs careful migration choreography.

### Shared trunk: `@vibesync/core` (npm SDK)

| Module | LOC | Role |
|---|---:|---|
| `state-manager.service` | 143 | Interface registry, used by 6 domains |
| `FileLockManager.simple` | (part of roosync 5.2K) | Concurrency primitive |
| `PresenceManager` | idem | Heartbeat primitive |
| `openai.ts` | 103 | LLM client |
| `qdrant.ts` | 84 | Vector DB client |
| `types/unified-task` + companion types | ~5K | Schemas (must be trunk to share envelope) |
| `services/extraction/unified-task-extractor` | 412 | Parse types unifiés |
| `services/markdown-formatter/` | 1.8K | Cross-MCP formatting |
| `utils/logger` + helpers | (part of 14K utils) | Logging |

**Versioning:** semver, publish to **internal npm registry** (`@vibesync/core@x.y.z`). Each MCP pins exact version. Breaking change in trunk = coordinated MCP rebuild + republish.

**Alternative (rejected):** vendor copy with sync script. Versioning becomes implicit, drift inevitable, audit harder.

---

## Migration Strategy

### Window choice

**Cycle 33-34 window** (after Wave 1 spike validates SDK pattern). Migration of one MCP family at a time, with **30-day backward-compat shim** in `roo-state-manager` (deprecated MCP) republishing forwarded tool calls to new MCPs.

### Backward-compat shim approach

For each tool moved:
1. New MCP exposes the tool under new name (or same name namespaced).
2. Old `roo-state-manager` tool forwards to new MCP via internal RPC and emits a `[DEPRECATED]` warning header.
3. After 30 days fleet-wide observation (zero clients using old tool), remove from `roo-state-manager`.
4. After 60 days, deprecate `roo-state-manager` entirely.

### Client migration paths

| Client | Path | Estimated effort |
|---|---|---|
| **Claude Code** (this fleet) | Update `~/.claude.json` MCP entries per machine + `gh` deploy via `roosync_mcp_management(action: "manage", subAction: "write")` | 1h per machine (or single fleet broadcast) |
| **Roo Code** | Update `%APPDATA%/.../mcp_settings.json` via roo-state-manager `manage_mcp_settings` tool (irony) | 30min per machine |
| **Hermes (myia-ai-01 review bot)** | Update bot env vars + workflow files | 2h |
| **NanoClaw (myia-po-2026 review bot)** | Update bot config | 2h |
| **scripts/** repo automation | grep for `roo-state-manager` references, update to new MCP names per call | 4h (one-shot) |

### Rollback criterion

If Wave 1 spike fails (compile error, agent context window regression > 5%, integration test failure), **rollback by reverting the PR** (no half-state, MCPs are additive until cutover). Backward-compat shim ensures fleet keeps working with old `roo-state-manager` if new MCPs are absent.

---

## Open Questions (User Arbitrage Required)

1. **Naming finalization:** `vibe-*` (single-purpose) vs `vibesync-*` (multi-machine coord) split is logical — but is the user OK with the dual prefix? Alternative: single prefix `vibe-*` for all, with `vibe-sync-*` or `vibesync-*` reserved for coordination.

2. **Trunk packaging:** SDK npm `@vibesync/core` (recommended, semver, audit) vs vendor copy (no registry dependency, but drift risk). Trade-off: NPM registry availability vs versioning rigor.

3. **Wave 1 search bundling:** `vibe-indexing` includes `search/` (recommended, isolates vector cluster) **OR** `search/` stays with conv-browser (preserves browser as primary read entry). Coupling data favors bundling (3 shared trunk modules: openai+qdrant+task-indexer).

4. **Migration window:** Cycle 33-34 (2 weeks, low fleet activity expected after #2190 stabilization) **OR** wait for post-#1393 ADR 010 implementation (#2197, storage backend decided). Sequencing affects conv-browser Wave 3 timing.

5. **Backward-compat shim duration:** 30/60 days proposed. Shorter (15/30) reduces double-publish cost but increases agent breakage risk if a client lags. Longer (60/120) is safer but extends maintenance overhead.

6. **Rebrand timing:** Rebrand happens at **first Wave 1 publish** (`vibe-export` ships with `@vibesync/core`) — locking the new naming early. Alternative: split first as `roo-state-*` MCPs, rebrand later. Coupled = single breaking-change window. Uncoupled = two consecutive breakages.

7. **Single repo vs polyrepo:** Continue monorepo (`mcps/internal/servers/{name}`) with all MCPs side-by-side, **OR** split each MCP into its own repo under `jsboige/jsboige-mcp-servers` (one repo per MCP). Coupled with submod pointer-bump complexity (already a pain point: #1799).

---

## Acceptance Criteria

| Criterion | Mechanism | Target |
|---|---|---|
| Compile time per MCP | `tsc --build` | < 30s per MCP (down from current 90s monolith) |
| Test surface per MCP | Vitest per project | < 200 tests per MCP (down from 9500 monolith) |
| Agent context window | Tools loaded per agent | < 20 tools per agent (down from 26-30 in monolith) |
| Migration zero-downtime | Backward-compat shim window | 30 days no-break, fleet observation |
| Trunk drift | SDK pinning + CI check | 0 unsynced versions detected per quarter |

---

## Out of Scope (Phase 2+)

- **Implementation of Wave 1 spike:** Separate ADR per MCP, separate PR per Wave. This ADR is **architecture only**.
- **`@vibesync/core` SDK boundary refinement:** What exactly goes in trunk vs duplicated will be decided per-Wave when extracting the first MCP.
- **Test re-partitioning:** ~10K tests must be split across MCPs. Plan TBD in Phase 2 ADR.
- **CI/CD pipeline changes:** Per-MCP build matrix, npm publish flow. Phase 2 ADR.
- **Observability:** Per-MCP metrics, distributed tracing. Phase 3 ADR.

---

## Decision Log

| Date | Decision | Author | Rationale |
|---|---|---|---|
| 2026-05-15 | Proposed 8-MCP split (4 vibe-* + 3 vibesync-* + 1 trunk SDK) | myia-ai-01 (R41) | Based on po-2025 Phase 1 data: 4 clear hot/cold clusters, 4 cross-imports → 4 single-purpose + 3 coord + trunk |
| 2026-05-15 | Wave 1 = export + diagnose + indexing | myia-ai-01 (R41) | Low risk, validates SDK pattern, no hot-path interference |
| 2026-05-15 | Bundle dashboard+messages = `vibesync-intercom` | myia-ai-01 (R41) | 4 services shared, splitting creates GDrive lock storm |
| 2026-06-11 | 8-MCP plan rejected as **overkill**; coarse 2-family cut (Config-sync vs conversational) mandated before any detail | user | "8 MCPs??? […] il faudrait déjà faire le point là-dessus avant d'aborder le détail" |
| 2026-06-11 | Re-scope to 2 MCPs (`vibesync` + `vibe-conversations`) + `@vibesync/core` npm workspaces trunk; Q2/Q3/Q6/Q7 closed, Q1/Q4/Q5 demoted to implementation detail | user (granularity GO) + myia-ai-01 | See Amendment section at top |

---

## Links

- **Origin mandate:** #1935 (user 2026-05-15 ~11:05Z)
- **Consolidation audit:** #1841 (closed 2026-05-08, basis of this EPIC)
- **EPIC:** #2190
- **Phase 1 data:** [po-2025 comment on #2190](https://github.com/jsboige/roo-extensions/issues/2190#issuecomment-4459593168)
- **Complementary ADR (storage):** #2197 / ADR 010 (`conversation_browser` GDrive)
- **Anti-pattern reminder:** #1799 (pointer-bump premature)
- **Submodule safety:** [.claude/rules/submod-pointer-safety.md](../../../.claude/rules/submod-pointer-safety.md)
