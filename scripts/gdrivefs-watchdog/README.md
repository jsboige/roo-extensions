# GDriveFS Watchdog

**Issue:** #2875
**Date:** 2026-07-24
**Owner:** myia-web1

---

## Overview

A watchdog that relaunch `GoogleDriveFS.exe` (Google Drive File Stream) when it
dies silently. Cuts the recurrence of the #2875 comm blackouts from hours/days
down to ~15 min.

## Problem

`GoogleDriveFS.exe` dies silently with **no auto-restart**: the HKCU `Run` entry
fires only at interactive logon, not after a crash. While it is dead:

- The host loses 2-way comm with the RooSync fleet (the GDrive `.shared-state`
  mount stops syncing).
- `roosync_dashboard` returns `"success"` while writing to **local disk only** —
  nothing syncs up or down (the MCP cannot tell).
- The fleet reports the host "dead/non-responsive" for hours/days until someone
  notices and relaunches the process by hand.

Incident 2026-07-24: web1 was silent ~26h because of exactly this.

## Solution

A short-lived scheduled task runs `gdrivefs-watchdog.ps1` every 15 min:

1. Is `GoogleDriveFS.exe` running? → exit 0 (no action).
2. Not running → relaunch it in the **user context** (same command as the HKCU
   `Run` entry: `GoogleDriveFS.exe --startup_mode`), wait 20s, re-check, log it.

### Why user context (NOT SYSTEM)

GDriveFS binds its `core_controller` to the **user account token**. A
`SYSTEM`-context relaunch cannot restore the account association. The task
therefore runs as the user (`RunLevel Highest`, `LogonType Interactive`) — the
same shape as `install-dashboard-listener-schtask.ps1` (#2431), not as the
`SYSTEM`-based `mcp-watchdog`.

### Limitation

If the **account token was dropped** (not just the process), a clean relaunch may
require a one-time interactive re-auth (WebView2 prompt). The watchdog restores
the process; the **common case** (process dead, token still cached) restores
comm automatically. Persistent auth loss still needs the user.

## Files

| File | Role |
|------|------|
| `gdrivefs-watchdog.ps1` | Body — one-shot poll: detect + relaunch + log. |
| `install-gdrivefs-watchdog-schtask.ps1` | Installer — registers the `GDriveFS-Watchdog` scheduled task. |

## Installation — [INTERACTIVE-ONLY]

Registering the task (`RunLevel Highest`) **requires elevation**. Run from an
elevated PowerShell (VS Code launched as Administrator, or a `Run as
administrator` terminal):

```powershell
pwsh -ExecutionPolicy Bypass -File scripts\gdrivefs-watchdog\install-gdrivefs-watchdog-schtask.ps1
```

This installs a task `GDriveFS-Watchdog` that:
- Runs as the user, `Highest`, `Interactive`
- Triggers: `AtLogOn` + `AtStartup`(+2m) + repeat every 15 min
- `ExecutionTimeLimit` 5 min, `MultipleInstances IgnoreNew`
- Restarts on failure (3× / 1 min)

Neither a cron worker nor a `[WAKE-CLAUDE]` can install it (chicken-and-egg: you
cannot WAKE to repair the WAKE; elevation is not available from a non-elevated
session).

## Usage

```powershell
# Dry-run (probe only, never relaunch) — safe, no system change:
pwsh -File scripts\gdrivefs-watchdog\gdrivefs-watchdog.ps1 -Mode dry-run

# Run the poll manually:
pwsh -File scripts\gdrivefs-watchdog\gdrivefs-watchdog.ps1

# Uninstall the task:
pwsh -File scripts\gdrivefs-watchdog\install-gdrivefs-watchdog-schtask.ps1 -Uninstall

# Today's logs:
Get-Content outputs\gdrivefs-watchdog\watchdog-$(Get-Date -Format yyyyMMdd).log -Tail 20
```

## Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `Mode` (body) | `poll` | `poll` = relaunch if dead; `dry-run` = probe only |
| `RepeatMinutes` (installer) | `15` | Poll cadence |
| `StartupDelayMinutes` (installer) | `2` | Delay after boot (let GDrive settle) |
| `LogRetentionDays` (body) | `14` | Auto-prune logs older than N days |

Logs: `<repo-root>/outputs/gdrivefs-watchdog/watchdog-YYYYMMDD.log` (gitignored).
