# ADR 007: RooSync HUD Statusline

**Date:** 2026-04-30
**Status:** Phase 3 Complete
**Issue:** #1855
**Source:** oh-my-claudecode evaluation (#1802, pattern #3)

## Context

Our multi-agent system (6 machines, Roo + Claude Code) has no real-time visibility during sessions. Agents report post-task via dashboard, but there's no indication of cluster health, active agents, or inbox state while working.

## Decision

Implement a Claude Code statusline script that reads RooSync shared state directly from GDrive and displays a compact HUD in the terminal.

### Architecture: Direct File Read (No MCP endpoint)

**Option A (chosen):** PowerShell script reads GDrive shared state files directly.

```
Claude Code → stdin JSON → roosync-statusline.ps1 → reads GDrive files → stdout text
```

**Option B (deferred):** Add HTTP metrics endpoint to roo-state-manager, script polls it.

Why Option A:
- Zero code changes in roo-state-manager
- No new MCP tool needed
- Instant deployment (just configure settings.json)
- GDrive sync latency (~5s) is acceptable for a status bar
- Can migrate to Option B later if needed

### Statusline Output Format

Three presets:

| Preset | Format | Example |
|--------|--------|---------|
| **minimal** | Status emoji + machines | `OK 5/6` |
| **normal** (default) | Status + machines + inbox + task | `OK 5/6 | 2 unread | wt/1855-statusline` |
| **verbose** | Full metrics | `OK 5/6 machines | 2 unread (0 urgent) | 3 dashboards | wt/1855-statusline | po-2026` |

Status indicators:
- `OK` (green) = HEALTHY
- `WARN` (yellow) = WARNING
- `CRIT` (red) = CRITICAL

### Data Sources

| Source | File | Data |
|--------|------|------|
| Machine status | `heartbeat.json` | online/offline/warning counts |
| Dashboard activity | `dashboards/*.md` mtime | active dashboards |
| Current branch | git (from stdin context) | branch name |
| Session model | stdin JSON | model name |

### Script Location

`scripts/claude/roosync-statusline.ps1`

### Configuration

In `~/.claude/settings.json`:

```json
{
  "statusLine": {
    "type": "command",
    "command": "powershell -ExecutionPolicy Bypass -File scripts/claude/roosync-statusline.ps1 -Preset normal"
  }
}
```

Portable path resolution: script uses `$env:ROOSYNC_SHARED_PATH` or defaults to `G:/Mon Drive/Synchronisation/RooSync/.shared-state/`.

## Alternatives Considered

1. **MCP metrics endpoint** — Clean but requires submodule changes, build, deploy. Deferred to Phase 2.
2. **VS Code extension** — Heavy, maintenance burden. Out of scope.
3. **Terminal tmux status** — Not all machines use tmux. Not portable.

## Risks

| Risk | Mitigation |
|------|------------|
| GDrive sync latency (~5s) | Acceptable for status bar (not real-time control) |
| GDrive offline | Script returns "OFFLINE" instead of crashing |
| Script performance | File reads are <100ms, no network calls |
| heartbeat.json stale | Show last update time in verbose mode |

## Implementation Phases

- **Phase 1** (PR #1872, MERGED): ADR + PowerShell script + minimal/normal/verbose presets
- **Phase 2** (PR #1891, MERGED): MCP metrics endpoint (get-status detail="full") + HUD data structures
- **Phase 3** (deployed web1, template ready): Active claims, team-stage display, deployment template

### Deployment Template

Each machine needs `statusLine` in `~/.claude/settings.json`:

```json
{
  "statusLine": {
    "type": "command",
    "command": "pwsh -ExecutionPolicy Bypass -Command \"$env:ROOSYNC_SHARED_PATH='<SHARED_PATH>'; & '<REPO>/scripts/claude/roosync-statusline.ps1' -Preset normal\""
  }
}
```

Per-machine `ROOSYNC_SHARED_PATH` values are in `.env` files. Script also falls back to `G:\Mon Drive\...` or `D:\Mon Drive\...`.

**Known limitation:** Presence/heartbeat data is stale on all machines (#1953 — heartbeat tracker redesign). Statusline correctly reads available data but machine counts may show 0/6 until #1953 is resolved.
