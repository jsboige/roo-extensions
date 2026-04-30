# ADR 006: RooSync HUD Statusline

**Date:** 2026-04-30
**Status:** Proposed
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

- **Phase 1** (this PR): ADR + PowerShell script + minimal/normal/verbose presets
- **Phase 2** (future): MCP metrics endpoint for real-time data
- **Phase 3** (future): Active claims section, team-stage display
