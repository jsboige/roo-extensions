# ADR 008: Heartbeat Redesign — Passive Activity Derivation

**Date:** 2026-05-03
**Status:** Proposed
**Issue:** #1953
**Supersedes:** #1495, #1674, #1791, #1938 (4 failed fixes in 6 weeks)
**Related:** #1609 (auto-heartbeat on tool calls)

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

### Phase 1: Identity Fix + In-Memory (low risk, immediate)

1. Fix `auto-heartbeat.ts` to use `os.hostname()` instead of `this.config.machineId`
2. Remove GDrive heartbeat file writes from `HeartbeatService.registerHeartbeat`
3. Keep `HeartbeatService` class but simplify to in-memory map
4. Update `roosync_get_status` / `roosync_inventory` to use new status model (ONLINE/IDLE/UNKNOWN)

### Phase 2: Remove Dead Code (after 48h validation)

1. Remove `heartbeats/` directory on GDrive
2. Remove `heartbeat-service.ts` tool (no longer needed)
3. Remove `register-heartbeat.ts` tool (no longer needed)
4. Clean up `background-services.ts` heartbeat auto-start code
5. Update documentation references

### Phase 3: Validation

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
