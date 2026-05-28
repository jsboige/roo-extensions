# ADR 013 — VibeSync Phase 2 Target Dispatch Architecture

**Status:** Proposed (awaiting user/coordinator arbitrage)
**Date:** 2026-05-28
**Author:** myia-po-2026 (claude-interactive, R7+ autonomous, ai-01 HS)
**Related:** ADR 011 (Phase 1 MCP split), EPIC #2406 (VibeSync Phase 2), #2408, #2409, #2410, #2411
**Convergence:** Architecture independently identified by myia-po-2026 (2026-05-28T19:42Z) and myia-po-2024 (2026-05-28T19:46Z)

---

## Context

EPIC #2406 (VibeSync Phase 2) adds 4 new target families to `roosync_config`:

| Issue | Target | Nature |
|---|---|---|
| #2408 | `schtasks` | Windows scheduled tasks (declarative pilot) |
| #2409 | `services:<name>` | Service lifecycle (vLLM process, Qdrant, IIS, sk-agent container) |
| #2410 | `env:<service>` | Secret rotation (AES-256-GCM, `needs-approval`) |
| #2411 | `schedules+rules` (extend `apply_profile`) | Roo `schedules.json` + `.roo/rules/` |

The existing `roosync_config` tool exposes 4 actions over **file-based config**: `collect` → `publish` → `apply` → `apply_profile`. It dispatches on a target string against a hardcoded list (~10 targets in `config.ts:32`) and delegates to `ConfigSharingService` (1504 LOC).

### The convergence

Two executors independently reached the same observation:

- **myia-po-2026** (cycle 99, 19:42Z): *"Services target doesn't fit collect/publish/apply pattern. Needs standalone `ServicesConfigService.ts`. Different code path from `ConfigSharingService`."*
- **myia-po-2024** (19:46Z, full ConfigSharingService read): *"Two independent executor analyses reach same architecture → high-confidence input for coordinator arbitrage. The pattern break from existing ConfigTarget code path is real, not a workaround."*

The convergence point: **the new targets bend the contract of `roosync_config`** because they are not config files but runtime state (running processes, scheduled task definitions, secret material, runtime hooks). `collect` becomes "get status", `apply` becomes "mutate runtime state" — semantically different operations sharing only the verb names.

### The decision

Two options exist, both are viable, neither is implementable without an explicit architectural choice. This ADR captures the trade-offs so user/coordinator can arbitrate.

---

## Option A — Extend `roosync_config` with target dispatch

Each new target adds a branch inside `roosync_config` and a dedicated service (`SchtasksConfigService`, `ServicesConfigService`, `EnvConfigService`). `config.ts` grows additional switch arms. The Zod schema's `targets` array gains 4 new prefixes/values.

### Pros

- **Single MCP tool surface**: agents discover all config-like operations under one tool. No new tool-name to learn.
- **Reuse of existing dispatch infra**: action verbs (`collect`, `publish`, `apply`, `apply_profile`), pre-flight checks, dryRun handling, RollbackManager hookup.
- **Discoverability**: `roosync_compare_config(granularity: "<target>")` extends naturally.
- **Lower MCP-count friction** at agent context window level (no new tool registration).

### Cons

- **Semantic stretching**: `collect` of `services:vllm` returns `Get-Service` + port + PID — not a config file. The action verbs become metaphors. Documentation must explain per-target what each verb means.
- **`config.ts` grows monotonically**: from ~312 LOC to ~500+. Cyclomatic complexity in the action handlers explodes (each target × 4 actions = 16 branches per family).
- **Type system pressure**: `ConfigTarget` union expands to ~15 entries; some targets (e.g. `services:<name>`) require parametric variants. The schema must accept `operation?: "start" | "stop" | "restart"` only for some targets.
- **Test surface coupling**: a regression in `services:` handler can affect `apply_profile` test fixtures, etc.
- **Conflates "what is sharable across the fleet" with "what is runtime-mutable on a machine"** — different threat models (secret rotation #2410 is `needs-approval`, schtasks #2408 is not).

---

## Option B — Separate MCP tools per family

`roosync_schtasks`, `roosync_services`, `roosync_secrets`, etc. Each tool has its own Zod schema, its own action set tailored to its domain, its own service in `mcps/internal/.../services/`.

Suggested first-cut tool boundaries:

| Tool | Targets absorbed | Actions |
|---|---|---|
| `roosync_schtasks` | #2408 | `list`, `compare`, `apply` (idempotent), `apply --dry-run` |
| `roosync_services` | #2409 | `status`, `start`, `stop`, `restart`, `health` |
| `roosync_secrets` | #2410 | `rotate`, `read` (gated), `audit` |
| `roosync_config` (unchanged) | existing 10 + #2411 (extend `apply_profile`) | as today |

### Pros

- **Domain-honest verbs**: `roosync_services(action: "restart")` means restart. No metaphor.
- **Per-tool schema clarity**: `operation: "restart"` lives only where it makes sense.
- **Independent test surfaces**: each tool can be tested, versioned, and broken without affecting others.
- **Aligns with ADR 011 Phase 1 direction** (split monolith). New targets land as ready-to-split modules: when EPIC #2190 Wave 2 extracts `vibesync-config`, secrets/services/schtasks tools migrate cleanly to their own MCPs without re-architecting.
- **Independent threat model gating**: `roosync_secrets` carries `needs-approval` gate at the tool-call level, not at a per-target conditional inside a generic dispatcher.
- **Reduced blast radius**: a bug in `roosync_services` cannot crash `roosync_config`.

### Cons

- **Tool count proliferation**: agent context window already monitored (#2307 audit). Adds 3+ tools.
- **Naming negotiation**: `roosync_services` vs `roosync_fleet_services` vs `vibesync_services` (per ADR 011 rebrand timing). Premature naming risks churn.
- **Code duplication risk**: pre-flight ownership check, RollbackManager, dryRun handling — copied across tools unless extracted into a helper. Slightly anticipates the `@vibesync/core` SDK (ADR 011 trunk) but requires it sooner than planned.
- **Cross-tool dispatch**: `apply_profile` (#2411) wants to atomically apply multiple targets across families. With separate tools, the orchestration logic lives in a higher coordinator (probably `roosync_config.apply_profile` calling out to siblings) — adds an internal MCP-RPC layer or service-level imports.

---

## Recommendation

**Option B for #2408, #2409, #2410. Option A for #2411 (extension of existing `apply_profile`).**

Rationale:
1. **#2411 truly is `roosync_config` work** — extending an existing flow to two new file-based artifacts (`schedules.json`, `.roo/rules/`) that ARE config files. No semantic stretch.
2. **#2408, #2409, #2410 are operationally distinct domains.** Pushing them into `roosync_config` adds metaphor-debt that ADR 011 Wave 2 split will then have to undo.
3. **The SDK trunk (`@vibesync/core` from ADR 011) is already needed** to share `FileLockManager`, `PresenceManager`, ownership pre-flight. Building these new tools forces early trunk-extraction discipline — useful pressure on EPIC #2190 timeline.
4. **Threat model isolation**: #2410 secrets require approval gate that does not belong in a tool that also does `roosync_config(action: "collect", targets: ["mcp"])`.

### Counter-recommendation

If the user prefers Option A (extend `roosync_config`), the mitigation is:
- Strict per-target sub-schemas (Zod discriminated unions on `target`)
- Per-target documentation block in tool description (so agents learn the semantics from the schema, not from CLAUDE.md)
- Refactor `ConfigSharingService` first to expose a "Target Provider" interface that each family implements separately, even if dispatched through one tool

This narrows the cons of Option A to "metaphor-debt only" instead of "tangled implementation".

---

## Out of Scope

- **Implementation of any target**: this ADR is architecture only. Each issue (#2408/#2409/#2410/#2411) keeps its own scope and PR.
- **Naming finalization** (`roosync_*` vs `vibesync_*`): tied to ADR 011 rebrand timing. Use `roosync_*` provisionally; rebrand atomically when Wave 1 ships.
- **Cross-machine `apply` dispatch** (#2412): orthogonal — applies to any chosen option.
- **Migration of existing 10 targets** in `roosync_config` to the new pattern: not required. Option B leaves `roosync_config` intact.

---

## Open Questions (arbitrage required)

1. **Primary choice**: Option A (extend) vs Option B (split) vs the hybrid recommendation above?
2. **Naming prefix** for new tools if Option B is chosen: `roosync_*` (current) or jump to `vibesync_*` (anticipating ADR 011)?
3. **`@vibesync/core` SDK extraction timing**: if Option B is chosen, do we extract the trunk now (helps these tools share helpers) or duplicate helpers and extract later (defers ADR 011 dependency)?
4. **Tool registration policy**: if Option B adds 3 tools, do we count them against the per-agent tool budget (#2307 audit) or treat them as "config family" exempt?

---

## Decision Log

| Date | Decision | Author | Rationale |
|---|---|---|---|
| 2026-05-28T19:42Z | po-2026 identifies pattern break in `services:<name>` | myia-po-2026 (cycle 99) | Investigation of #2409 against existing ConfigSharingService |
| 2026-05-28T19:46Z | po-2024 independently converges on same architectural concern | myia-po-2024 | Full ConfigSharingService read (1504 LOC) + 3 issues feasibility assessment |
| 2026-05-28 | ADR 013 proposed (Option A + Option B + hybrid recommendation) | myia-po-2026 (R7+, ai-01 HS) | Capture convergence before scope drift, enable coordinator/user arbitrage |
| TBD | Arbitrage on open questions 1-4 | user / coordinator | Awaiting |

---

## Links

- **Parent EPIC**: [#2406](https://github.com/jsboige/roo-extensions/issues/2406)
- **Phase 1 architecture**: [ADR 011 — MCP Split + VibeSync Rebrand](011-mcp-split-vibesync.md)
- **Issues**: [#2408](https://github.com/jsboige/roo-extensions/issues/2408), [#2409](https://github.com/jsboige/roo-extensions/issues/2409), [#2410](https://github.com/jsboige/roo-extensions/issues/2410), [#2411](https://github.com/jsboige/roo-extensions/issues/2411)
- **po-2026 investigation**: dashboard `[PROGRESS]` 2026-05-28T19:42:03Z
- **po-2024 assessment**: dashboard `[R7 Dispatch Report]` 2026-05-28T19:46:08Z
