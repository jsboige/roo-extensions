# ADR 008: Heartbeat Redesign — Passive Activity Derivation

**Date:** 2026-05-03 (v3 updated 2026-05-08 by po-2026; v4 Phase 4 Sunset added 2026-05-23 by ai-01)
**Status:** Phase 1+2 COMPLETE — Phase 3 validation NEVER REACHED — **Phase 4 SUNSET (cross-machine presence role removed, see below)**
**Issue:** #1953 (sunset tracked under #2121)
**Supersedes:** #1495, #1674, #1791, #1938 (4 failed fixes in 6 weeks)
**Related:** #1609 (auto-heartbeat), #293 (dashboard cross-check), #311 (double-callback fix), #377 (Phase 2 implementation)
**Approvers:** myia-po-2024 (ADR v2 ratification)

## Context

The heartbeat system marks machines OFFLINE that are demonstrably active. Four attempted fixes (#1495, #1674, #1791, #1938) each held for days then regressed. The symptom is always the same: `roosync_get_status` and `roosync_inventory` report machines as OFFLINE while those same machines are posting dashboard messages, creating PRs, and running scheduled tasks.

### Root Cause Analysis

The system has **three independent heartbeat mechanisms** that diverge:

| Mechanism | Identity Source | Trigger | Write Target |
|-----------|----------------|---------|-------------|
| `auto-heartbeat.ts` (#1609) | `ROOSYNC_MACHINE_ID` (.env) | Any MCP tool call | In-memory → disk (throttled) |
| `heartbeat-activity.ts` (#1791) | `os.hostname()` | Dashboard write/append | In-memory → disk (throttled) |
| `HeartbeatService` background | `ROOSYNC_MACHINE_ID` (.env) | Interval (60s) | In-memory → disk |

**Identity mismatch is the primary bug.** `heartbeat-activity.ts` uses `os.hostname()` (correct, e.g., `myia-po-2023`), while `auto-heartbeat.ts` uses `this.config.machineId` from `.env` (which may be stale or wrong — fix #501 documents that `.env` hardcoded `myia-ai-01` for all machines). When `auto-heartbeat` registers under the wrong ID and `heartbeat-activity` registers under the correct hostname, the system has split identity for one physical machine.

**Secondary issues:**
- Background heartbeat disabled by default (#607 GDrive sync storm) → no fallback
- Dirty-flag write optimization (#607) throttles disk writes to every 5min → reader may see stale data
- Per-machine files on GDrive have inherent sync latency (~5s minimum, often 30-60s under load)

### Impact

- **Alert fatigue**: operators ignore OFFLINE flags → real outages missed
- **Bad coordination**: Hermes instructed workers to stop claiming tasks based on false OFFLINE data
- **Wasted time**: ~2h/week of interactive coordinator time verifying false positives
- **Issue churn**: 4 identical issues opened/closed in 6 weeks

## Decision

**Option A: Passive activity derivation** — remove dedicated heartbeat mechanism entirely.

Every MCP tool invocation IS the heartbeat. No separate write, no interval, no background service.

### Architecture

```
BEFORE (3 mechanisms, 2 identity sources):
  tool call → auto-heartbeat (15min throttle, .env identity) → in-memory → disk (throttled)
  dashboard write → heartbeat-activity (hostname identity) → in-memory → disk (throttled)
  background interval (disabled) → in-memory → disk (throttled)

AFTER (1 mechanism, 1 identity source):
  tool call → audit log entry (hostname identity) → in-memory only
  roosync_get_status / roosync_inventory → reads audit timestamps → derives status
```

### Identity Source: Unify to `os.hostname()`

All heartbeat-like activity uses `os.hostname().toLowerCase()` as the machine identifier. The `.env` `ROOSYNC_MACHINE_ID` is no longer used for heartbeat purposes (it remains for message routing and other features).

### Status Derivation (no files on disk)

`roosync_get_status` and `roosync_inventory` derive machine status from:

| Status | Condition | Semantic |
|--------|-----------|----------|
| **ONLINE** | Last MCP tool call < 30 min ago | Machine is actively using RooSync |
| **IDLE** | Last MCP tool call 30-120 min ago | Machine is on but not actively working |
| **UNKNOWN** | No MCP tool call recorded | Machine has never connected or data expired |

**No "OFFLINE" status.** A machine can only be ONLINE, IDLE, or UNKNOWN. True machine failure is detected by external tools (watchdog scripts, LAN ping), not by heartbeat absence.

### Storage: In-Memory Activity Log

Replace per-machine heartbeat files (`heartbeats/{machineId}.json` on GDrive) with an in-memory `Map<machineId, lastActivityTimestamp>` inside the MCP server process.

- No GDrive writes for heartbeat data → eliminates sync storms
- No disk I/O → eliminates 0-byte corruption (#1674)
- Server restart → all machines start as UNKNOWN → first tool call → ONLINE (acceptable)
- `roosync_get_status` reads from memory → always consistent with actual activity

### Activity Sources

All MCP tool calls update the activity map (via existing `autoHeartbeat` hook in `registry.ts` line 711-712, with identity fix):

```typescript
// In registry.ts tool handler (existing pattern, fix identity):
const { autoHeartbeat } = await getAutoHeartbeat();
await autoHeartbeat(name);  // Already called on every tool invocation

// In auto-heartbeat.ts (change identity source):
const realMachineId = os.hostname().toLowerCase().replace(/[^a-z0-9-]/g, '-');
this.state.heartbeats.set(realMachineId, { lastActivity: Date.now() });
```

Dashboard writes/reads also count (already hooked via `heartbeat-activity.ts`, keep but unify identity).

### External Monitoring (for true machine failure)

True machine failure (power off, OS crash, network down) is NOT the responsibility of RooSync heartbeat. Existing external tools handle this:

| Tool | Scope | Detection |
|------|-------|-----------|
| `mcp-chain-watchdog.ps1` | MCP chain health | Scheduled task every 5 min on ai-01 |
| `watchdog-LAN-differential` (#1942) | LAN connectivity | Network-level ping |
| Windows Task Scheduler | Process health | Scheduled task monitoring |

## Migration Plan

### Phase 1: Identity Fix + In-Memory — DONE

1. Fix `auto-heartbeat.ts` to use `os.hostname()` instead of `this.config.machineId` — DONE via `getLocalMachineId()` unified function
2. Remove GDrive heartbeat file writes from `HeartbeatService.registerHeartbeat` — DONE (in-memory only)
3. Keep `HeartbeatService` class but simplify to in-memory map — DONE
4. Update `roosync_get_status` / `roosync_inventory` to use new status model (ONLINE/IDLE/UNKNOWN) — DONE

### Phase 2: Remove Dead Code — DONE

1. Remove `heartbeats/` directory on GDrive — PENDING (low priority, files orphaned but harmless)
2. Remove `heartbeat-service.ts` tool (no longer needed) — DONE (#1609)
3. Remove `register-heartbeat.ts` tool (no longer needed) — DONE
4. Clean up `background-services.ts` heartbeat auto-start code — DONE (PR #377)
5. Update documentation references — DONE (PR #377: removed offline/warning terminology)

### Phase 3: Validation — PENDING

1. 6 machines active → all show ONLINE simultaneously
2. Machine idle for 30 min → shows IDLE (not OFFLINE)
3. Machine truly down → shows UNKNOWN (not OFFLINE) → external watchdog detects
4. 48h continuous operation without manual intervention

## Alternatives Considered

### Option B: Fix existing heartbeat (dashboard-derived)

Fix the identity mismatch in `heartbeat-activity.ts` + `auto-heartbeat.ts`, keep the file-based system.

**Rejected because:** The file-on-GDrive approach has fundamental problems:
- GDrive sync latency (30-60s under load) makes heartbeat timestamps unreliable
- Per-machine files still require disk I/O and are subject to 0-byte corruption (#1674)
- Dirty-flag throttling (#607) means writes happen at most every 5min → reader sees stale data
- 4 previous attempts to fix this approach all regressed

### Option C: Remove heartbeat entirely + external monitoring only

Remove all heartbeat tracking from RooSync. Rely entirely on watchdog scripts and LAN monitoring.

**Rejected because:** External tools detect infrastructure failure (ping, process health), not RooSync activity. A machine that pings OK but has a broken MCP server should show as IDLE/UNKNOWN in RooSync, not ONLINE. The MCP-tool-call signal is valuable for coordination — it just shouldn't be a separate mechanism.

## Risks

| Risk | Mitigation |
|------|------------|
| Server restart loses activity history | Acceptable: all machines start UNKNOWN, first tool call → ONLINE within minutes |
| Identity still wrong if hostname ≠ expected machine ID | Validate hostnames match `myia-*` pattern, log warnings on mismatch |
| GDrive `heartbeats/` files become orphaned | Phase 2 cleanup after validation |
| Statusline ADR (#1855) references heartbeat.json | Update to read from in-memory source or remove heartbeat section |
| `roosync_heartbeat_service` tool removal breaks callers | Keep redirect handler in registry.ts for backward compat |

## Post-#311 Update (2026-05-04, po-2024)

### What PR #311 Fixed (interim, pre-ADR implementation)

PR #311 (po-2026, merged 2026-05-04) addressed the **immediate symptom** — double-callback in `startHeartbeatChecker()` that caused every status change to fire callbacks twice, amplifying the identity split bug into constant OFFLINE/ONLINE flapping.

Changes:
- Removed duplicate callback invocation in `startHeartbeatChecker()` (callbacks already fired inside `checkHeartbeats()`)
- Removed dead `performAutoSync()` + `startAutoSync()` methods (only logged, never synced)
- Kept `autoSyncEnabled`/`autoSyncInterval` as `@deprecated` optional fields for backward compat

### What PR #293 Added (cross-check bridge)

PR #293 (po-2024, merged cycle 29 W7) added a **dashboard-derived status cross-check** in `roosync_get_status`. When heartbeat data reports OFFLINE but dashboard shows recent activity, the status is overridden. This is a **palliative**, not a fix — it masks the heartbeat inaccuracy rather than fixing the source.

### ADR 008 Remains Necessary

Both #311 and #293 are **stopgaps**. The fundamental problems persist:
1. **3 mechanisms, 2 identity sources** — #311 fixed the double-fire but identity split remains
2. **GDrive file latency** — #293 cross-check works around it but adds complexity
3. **OFFLINE false positives** — still occur, just hidden by the cross-check

The ADR 008 Option A (passive activity derivation) is the correct long-term fix. #311 and #293 should be reverted as part of Phase 2 implementation (their logic is superseded by the in-memory model).

### Updated Migration Roadmap

| Phase | Description | Status | Dependencies |
|-------|-------------|--------|-------------|
| 0 (stopgap) | Double-callback fix (#311) + cross-check (#293) | DONE | None |
| 1 | Identity fix + in-memory model (this ADR) | DONE (PR #377) | ADR approval |
| 2 | Remove dead code (heartbeat files, tools, GDrive writes) | DONE (PR #377) | Phase 1 live |
| 3 | 48h continuous validation across 6 machines | PENDING | Phase 2 complete |

### Approval Notes (po-2024 review)

The ADR is technically sound. Specific validations:

- **Identity source:** `os.hostname()` is correct — verified against `heartbeat-activity.ts` which already uses it successfully
- **In-memory only:** Correct approach — GDrive file latency is the root cause of all 4 regressions
- **No OFFLINE status:** Correct — absence of signal should not imply failure (external tools handle this)
- **Backward compat:** Keep redirect handlers for removed tools — consistent with project patterns

**One concern:** Phase 1 should also remove the `heartbeat-activity.ts` GDrive file writes (not just HeartbeatService writes), since both write to the same unreliable medium. Recommend including this in Phase 1 scope.

**Recommendation: APPROVED pending coordinator sign-off.**

## Phase 1+2 Implementation Record (2026-05-08, po-2026)

### What was implemented

PR #377 (submod, po-2026) implemented the ADR 008 changes:

1. **Identity unification**: `getLocalMachineId()` in `message-helpers.ts` now uses `ROOSYNC_MACHINE_ID` env var (set to correct hostname in `.env`) with `os.hostname()` fallback. All heartbeat activity uses this single function.
2. **In-memory model**: `HeartbeatService` stores activity timestamps in-memory only. No GDrive writes, no disk I/O. Server restart = all machines start UNKNOWN.
3. **Status model**: ONLINE (<30 min), IDLE (30-120 min), UNKNOWN (>120 min or never connected). No OFFLINE status.
4. **Dead code removal**: Removed `getOfflineMachines()`, `getWarningMachines()`, `cleanupOldOfflineMachines()`. Background auto-start disabled. Configuration emptied.
5. **Terminology**: All references to `offline`/`warning` replaced with `unknown`/`idle` across codebase (11 test files updated).

### Verified behavior (po-2026, 2026-05-08)

- `roosync_inventory(type: "status")` correctly shows only actively-calling machines as ONLINE
- `dashboardOverrides` correctly detects machines active on dashboard but not yet in heartbeat map
- Build clean, 9185 CI tests pass

### Remaining (GDrive cleanup)

The `heartbeats/` directory on GDrive contains orphaned `.tmp` files from the old file-based system. These are harmless (no code reads them) and should be cleaned up during routine maintenance.

## Phase 4: Sunset — Cross-Machine Presence Role Removed (2026-05-23, ai-01)

**Verdict (user mandate 2026-05-23):** *"Si le heartbeat est devenu local only (on croit rêver), alors il faut le sunsetter, c'est que vous n'êtes pas arrivés à le faire marcher (ou bien répare-le, mais franchement je n'y crois plus là, je tombe de ma chaise)."*

### The fatal flaw of Option A: it is structurally cross-machine BLIND

Phase 1+2 moved heartbeat state to an **in-memory `Map` inside each MCP server process** (Decision, "Storage: In-Memory Activity Log"). This eliminated GDrive sync storms and file corruption — but it also eliminated the only thing that made heartbeat a *cross-machine* signal.

Each machine's MCP server records **only its own tool calls**. There is no transport carrying one machine's activity to another machine's process. Therefore:

- On ai-01, `roosync_inventory(type: "heartbeat" | "all" | "machines")` reports **ai-01 = ONLINE** and **every other machine = UNKNOWN**, regardless of what those machines are actually doing.
- The same is true symmetrically on every machine: each one sees itself online and everyone else unknown.

This is not a bug to be fixed — it is the **direct, intended consequence** of "in-memory only, no GDrive writes." The Phase 3 validation criterion *"6 machines active → all show ONLINE simultaneously"* was **never reachable** under the in-memory model and Phase 3 was never reached.

### Why "fiabiliser" (repair) is rejected

Making the in-memory heartbeat report *other* machines' presence requires a shared transport — i.e. re-introducing per-machine writes to a shared medium (GDrive). That is precisely **Option B**, already rejected in this ADR for GDrive latency + corruption + 4 prior regressions (#1495, #1674, #1791, #1938). Repairing the heartbeat means resurrecting the exact failure mode ADR 008 was written to kill. The user has explicitly withdrawn confidence in further repair attempts.

**Decision: SUNSET the heartbeat's cross-machine presence role.** Do not repair it. Do not add a new mechanism to replace it (No Pendulum). The dashboard already carries cross-machine presence reliably — judgment moves there.

### Single source of cross-machine presence truth: the dashboard

A reliable cross-machine presence signal **already exists and is already wired** — it does not need to be built:

| Signal | How | Why reliable |
|--------|-----|--------------|
| **`roosync_inventory(type: "status")`** | delegates to `get-status.ts` → `crossCheckWithDashboard()` (`utils/dashboard-activity.ts`) | Aggregates ALL machines' dashboard files; reads timestamps **embedded in message content** (`### [ISO8601] machine \| ...`), immune to GDrive mtime latency. #1953 Phase 4 discovers machines purely from the dashboard, independent of any heartbeat map. |
| **Dashboard intercom recency** | `roosync_dashboard(action: "read", type: "workspace", section: "intercom")` | A machine that posted in the last hours is provably alive; recency of its newest message is the activity proof. |
| **`.claude/locks/watcher-<ws>.lastack` mtime** | dashboard-listener ack file | Most reliable liveness signal for the watcher loop; a fresh mtime proves the machine's listener is running. |
| **git / PR activity** | `git log`, `gh pr list --author` | Commits and PRs are timestamped proof of work, not presence inference. |

### What changes (mœurs — agent practice)

**STOP** using `roosync_inventory(type: "heartbeat" | "all" | "machines")` to judge **other** machines' activity. Those read paths only ever reflect the *local* process and will mislead.

**DO** judge other machines' presence/activity from the dashboard signals above. To declare a machine "silent/down," the test is **"no dashboard message and no PR/commit in N hours,"** never "heartbeat says UNKNOWN."

The three coordinator/worker playbooks have been corrected accordingly: `.claude/skills/sync-tour/SKILL.md` (Phase 4bis), `.claude/commands/coordinate.md` (Surveillance Santé), `.claude/agents/workers/sync-checker.md` (heartbeat row — clarified as local-self only).

### What is kept

- **The local self-activity map** stays (cheap, harmless, accurate for the *one* machine it observes). `roosync_inventory(type: "status")` continues to use it as a seed, then the dashboard cross-check is authoritative.
- **`HeartbeatService.recordSchedulerRun` / scheduler metrics (#1442)** stay — they are a separate, legitimately-local concern (this process's scheduler outcomes).
- **The write hook** (`recordRooSyncActivity`, registered on local tool calls) is harmless and stays.

### Code follow-through (separate submod PR, tracked under #2121)

The doc/mœurs change (this addendum + the 3 playbooks) lands first. The code change — demoting/redirecting the blind read paths (`type: "heartbeat" | "all" | "machines"`) so they cannot be mistaken for cross-machine truth, and making `get-status.ts` presence purely dashboard+lastack derived — is specified as a claimed issue under epic **#2121** (presence/config/sharedState consolidation, po-2026 owner). That epic's "Phase 2 = dashboard-derived presence" is exactly this sunset; the code work is its natural completion.
