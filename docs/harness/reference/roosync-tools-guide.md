# RooSync Coordinator Tools — Usage Guide

**Version:** 1.0.0
**Issue:** #1746-E (documentation usage scenarios)
**Scope:** Tools used by the coordinator (ai-01) and meta-analyst for fleet monitoring and dispatch

---

## Overview

The coordinator and meta-analyst use a subset of roo-state-manager tools for fleet monitoring. This guide consolidates the 4 key tools with their parameters, output shapes, and usage scenarios.

---

## Tool 1: `roosync_health_view`

**Purpose:** Single-call aggregated cluster health view. Replaces calling `roosync_inventory` + `roosync_compare_config` + env checks separately.

**Introduced:** #1746-B (PR jsboige/jsboige-mcp-servers#534)

### Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `machineId` | string | local machine | Target machine for drift check |
| `includeEnvCheck` | boolean | true | Check critical env vars (EMBEDDING_*, QDRANT_*) |
| `format` | `"json"` \| `"markdown"` | `"json"` | Output format |

### Output Shape (JSON)

```typescript
{
  status: "HEALTHY" | "WARNING" | "CRITICAL",  // HEALTHY ≥80, WARNING ≥50, CRITICAL <50
  score: number,                                 // 0-100
  timestamp: string,                             // ISO 8601
  localMachine: string,
  systemHealth: {
    machinesOnline: number,                      // Heartbeat < 2h
    machinesUnknown: number,                     // Heartbeat > 2h or unreadable
    machinesTotal: number,
    flags: string[]                              // e.g. "SYNC_STALE:myia-po-2024"
  },
  capabilities: {
    sharedPath: boolean,                         // ROOSYNC_SHARED_PATH configured
    qdrant: boolean,                             // Qdrant reachable
    embeddings: boolean                          // Embedding service configured
  },
  drift: {
    checked: boolean,                            // false if GDrive offline
    baselineSource: string,                      // e.g. "myia-po-2023 (via GDrive inventory)"
    critical: number, important: number,
    warning: number, info: number,
    items: Array<{ category, severity, path, description, action? }>
  },
  envCheck: {
    checked: boolean,
    missing: Array<{ name: string, severity: "critical" | "warning" }>,
    present: string[]
  },
  recommendations: string[]                      // Actionable suggestions
}
```

### Score Breakdown

| Category | Points | Logic |
|----------|--------|-------|
| Machine availability | 0-20 | `(1 - onlinePct) * 20` deducted |
| Capabilities | 0-30 | sharedPath=15, qdrant=10, embeddings=5 deducted per missing |
| Config drift | 0-30 | critical×10 (max 20), important×3 (max 10) deducted |
| Env vars | 0-20 | critical missing × 10 deducted |

### Usage Scenarios

**Scenario 1 — Coordinator cycle start:**
```
roosync_health_view({ format: "markdown" })
```
Returns human-readable markdown with status, score, drift summary, and recommendations. Use as first call to assess fleet state before dispatch.

**Scenario 2 — Machine-specific drift:**
```
roosync_health_view({ machineId: "myia-po-2026" })
```
Checks drift for a specific machine (useful when investigating stale machines).

**Scenario 3 — Quick capability check (no env dump):**
```
roosync_health_view({ includeEnvCheck: false })
```
Skips env var inspection when you only need machine presence + drift + capabilities.

### Guard Rails

- Requires `sharedPath` capability (GDrive mount). Returns degraded result if unavailable.
- Drift collection calls `roosyncCompareConfig` internally — may take 5-10s on full granularity.
- `format: "markdown"` returns a `text` content type in MCP response; `format: "json"` returns structured JSON.

---

## Tool 2: `roosync_inventory`

**Purpose:** Machine inventory, heartbeat status, and per-process tool usage stats.

### Key Actions

| `type` | Purpose | Cross-Machine |
|--------|---------|---------------|
| `"status"` | Compact fleet snapshot (online/offline, flags, toolUsage) | Yes (reads GDrive heartbeats) |
| `"machines"` | List machine IDs (unknown/idle status) | Yes |
| `"machine"` | Single machine details | Local only |
| `"all"` | Full inventory | Local only |
| `"heartbeat"` | Heartbeat data | Local process only |

### `type: "status"` — Coordinator Primary

```typescript
{
  machineId: string?,          // Filter by machine
  detail: "compact" | "full",  // "full" adds claims + pipeline stages
  resetCache: boolean,         // Force cache reset
  includeDetails: boolean      // Include tool usage stats
}
```

**Output highlights:**
- `flags[]` — Active alerts per machine (e.g. `MCP_DEGRADED`, `QDRANT_UNREACHABLE`)
- `toolUsage` (with `includeDetails: true`) — Per-session: totalCalls, uniqueTools, topTools/bottomTools with count+avgMs+lastCallAt, errorTools
- `schedulerMetrics` — Worker stats from GDrive

**ADR constraint (008-heartbeat-redesign):** Only `type: "status"` is valid for cross-machine queries. `type: "heartbeat"` / `"all"` / `"machines"` reflect the local MCP process only.

**Scenario — Coordinator checking fleet health:**
```
roosync_inventory({ type: "status", detail: "full", includeDetails: true })
```

---

## Tool 3: `roosync_compare_config`

**Purpose:** Compare Roo configs between two machines. Detect configuration drift.

### Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `source` | string | local | Source machine ID |
| `target` | string | "remote" | Target machine or profile |
| `granularity` | string | — | `mcp`, `mode`, `settings`, `claude`, `modes-yaml`, `full` |
| `filter` | string | — | Path filter (e.g. `"jupyter"` for specific MCP) |
| `force_refresh` | boolean | false | Force inventory re-collection |

### Granularity Levels

| Level | Compares |
|-------|----------|
| `mcp` | MCP server configs (tools, alwaysAllow, env) |
| `mode` | Roo modes definitions |
| `settings` | Claude Code settings.json |
| `claude` | Claude-specific configs |
| `modes-yaml` | .roomodes YAML definitions |
| `full` | All of the above |

### Output

```typescript
{
  source: string,
  target: string,
  summary: { critical: number, important: number, warning: number, info: number },
  differences: Array<{
    category: string,      // e.g. "MCP", "Settings"
    severity: string,      // "CRITICAL" | "IMPORTANT" | "WARNING" | "INFO"
    path: string,          // Config path
    description: string,   // Human-readable diff
    action?: string        // Suggested fix
  }>
}
```

**Scenario — Coordinator drift check before dispatch:**
```
roosync_compare_config({ source: "myia-ai-01", granularity: "mcp" })
```

**Scenario — Full drift audit:**
```
roosync_compare_config({ source: "myia-ai-01", granularity: "full" })
```

---

## Tool 4: `roosync_dashboard`

**Purpose:** Cross-machine coordination via shared dashboards. Primary communication channel.

### Key Actions

| Action | Purpose |
|--------|---------|
| `read` | Read a dashboard (status + intercom messages) |
| `read_overview` | 3-level overview (global + machine + workspace) in 1 call |
| `append` | Post an intercom message |
| `write` | Replace dashboard status |
| `list` | List all dashboards |

### `read_overview` — Coordinator Quick Scan

```
roosync_dashboard({ action: "read_overview" })
```

Returns all 3 dashboard types (global, machine, workspace) with recent intercom messages. Use at cycle start to see fleet-wide activity in one call.

### Dashboard Types

| Type | Scope | Usage |
|------|-------|-------|
| `global` | Fleet-wide announcements | Broadcast from coordinator |
| `machine` | Per-machine status | Machine-level reports |
| `workspace` | Per-workspace coordination | Primary channel for task coordination |

### Tags (intercom messages)

Standard: `INFO`, `TASK`, `DONE`, `WARN`, `ERROR`, `ASK`, `REPLY`, `ACK`, `PROPOSAL`, `CLAIMED`, `BLOCKED`, `FRICTION`

Wake tags: `[WAKE-CLAUDE]`, `[WAKE-HERMES]`, `[WAKE-NANOCLAW]` — trigger agent spawning on target machines.

---

## Coordinator Decision Matrix

| Situation | Tool | Call |
|-----------|------|------|
| Fleet health at cycle start | `roosync_health_view` | `{ format: "markdown" }` |
| Fleet status with tool usage | `roosync_inventory` | `{ type: "status", includeDetails: true }` |
| Config drift investigation | `roosync_compare_config` | `{ granularity: "full" }` |
| Quick 3-level overview | `roosync_dashboard` | `{ action: "read_overview" }` |
| Dispatch task to machine | `roosync_dashboard` | `{ action: "append", type: "workspace", tags: ["TASK"], content: "..." }` |
| Check machine-specific drift | `roosync_health_view` | `{ machineId: "myia-po-2026" }` |
| Wake stalled machine | `roosync_dashboard` | `{ action: "append", type: "workspace", tags: ["WAKE-CLAUDE"], content: "[WAKE-CLAUDE] myia-po-2026:roo-extensions ..." }` |

---

## Anti-Patterns

1. **Calling `roosync_inventory(type: "all")` for cross-machine data** — Only `type: "status"` reads GDrive heartbeats. Other types are local-process only.
2. **Calling `roosync_compare_config` without `granularity`** — Always specify granularity to control scope and latency.
3. **Using RooSync messages for routine coordination** — Dashboard workspace is the primary channel. RooSync messages are for urgent/directed communication.
4. **Reading only `section: "status"` from dashboard** — Status is a static snapshot. Always read `section: "all"` or `section: "intercom"` for current decisions.
