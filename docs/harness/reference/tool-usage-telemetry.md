# Tool Usage Telemetry

**Version:** 1.0.0
**Date:** 2026-05-01
**Issue:** #1863 Phase D

## Overview

Per-tool usage tracking for the roo-state-manager MCP server. Every MCP tool call is counted and timed, providing real-world usage data to guide consolidation and deprecation decisions.

## Architecture

### Collection Point

All tool calls pass through a single wrapper in `src/index.ts` (the outermost `tools/call` handler). After each call completes:

1. `toolName` and `durationMs` are extracted
2. `recordToolCall(toolName, durationMs, hadError)` is called
3. The in-memory `Map<string, ToolStats>` is updated

### Data Structure

Each tool tracks:
- `count` — Total calls this session
- `totalMs` — Cumulative duration
- `lastCallAt` — ISO timestamp of most recent call
- `errorCount` — Number of calls that threw errors

### Access

Stats are exposed via `roosync_get_status(includeDetails: true)`:

```
roosync_get_status(args: { includeDetails: true })
```

Response includes a `toolUsage` section:
```json
{
  "toolUsage": {
    "sessionStartAt": "2026-05-01T11:00:00Z",
    "totalCalls": 342,
    "uniqueTools": 28,
    "topTools": [
      { "name": "roosync_dashboard", "count": 87, "avgMs": 312, "lastCallAt": "..." },
      { "name": "roosync_read", "count": 45, "avgMs": 280, "lastCallAt": "..." }
    ],
    "bottomTools": [
      { "name": "export_data", "count": 1, "avgMs": 50, "lastCallAt": "..." }
    ],
    "errorTools": [
      { "name": "roosync_send", "errorCount": 2 }
    ]
  }
}
```

## Reading the Stats

### Top 5 / Bottom 5

- **Top 5**: Most frequently called tools — candidates for optimization (caching, batching)
- **Bottom 5**: Least used tools — candidates for deprecation or consolidation

### Error Tools

Tools with errors indicate reliability issues. Cross-reference with `errorCount` to prioritize fixes.

### Session Scope

Metrics are **in-memory only** — they reset when the MCP server restarts. This is intentional: we want current-session data, not cumulative historical counts that would grow unbounded.

## Limitations

- Per-session only (no persistence across restarts)
- Counts all calls including those from automated schedulers
- Does not distinguish caller (interactive vs scheduled)

## Files

| File | Description |
|------|-------------|
| `src/utils/tool-call-metrics.ts` | Core metrics module (record, snapshot, reset) |
| `src/index.ts` | Integration point (after each tool call) |
| `src/tools/roosync/get-status.ts` | Exposed via `includeDetails` parameter |
