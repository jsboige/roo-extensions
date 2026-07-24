# GDriveFS Watchdog

**Issues:** #2875 (silent-exit), #2933 (hung-process C1 + cooldown/escalation C2)
**Date:** 2026-07-24
**Owner:** myia-web1

---

## Overview

A watchdog that relaunch `GoogleDriveFS.exe` (Google Drive File Stream) when it
dies silently **or** is hung (process alive but unresponsive). Cuts the
recurrence of the #2875 comm blackouts from hours/days down to ~15 min, and
self-cools when persistent relaunch failures (e.g. dropped account token)
indicate a need for human intervention.

## Problem

`GoogleDriveFS.exe` dies silently with **no auto-restart**: the HKCU `Run` entry
fires only at interactive logon, not after a crash. While it is dead:

- The host loses 2-way comm with the RooSync fleet (the GDrive `.shared-state`
  mount stops syncing).
- `roosync_dashboard` returns `"success"` while writing to **local disk only** —
  nothing syncs up or down (the MCP cannot tell).
- The fleet reports the host "dead/non-responsive" for hours/days until someone
  notices and relaunches the process by hand.

A second failure mode (#2933 C1): the process can be **alive but hung**
(`core_controller` wedged, slot allocated, no I/O). The base watchdog
(`Test-GDriveFSAlive == true`) does not catch this and silent-fail continues.

A third failure mode (#2933 C2): when the **account token was dropped** (not
just the process), a clean relaunch requires a one-time interactive WebView2
re-auth. The base watchdog would re-attempt `Start-Process` every 15 min
forever — log noise with no progress.

Incident 2026-07-24: web1 was silent ~26h because of exactly this.

## Solution

A short-lived scheduled task runs `gdrivefs-watchdog.ps1` every 15 min and
applies three checks in order:

1. **C0 (silent-exit)** — Is `GoogleDriveFS.exe` running? → exit 0 (no action).
2. **C1 (hung-process)** — Is every GDriveFS process below a CPU% threshold
   (default `0.5%`) over a sample window (default `30s`)? → hung.
3. **C2 (cooldown)** — If a relaunch is needed and we're in cooldown, skip and
   emit an alert. Otherwise relaunch in the **user context** (same command as
   the HKCU `Run` entry: `GoogleDriveFS.exe --startup_mode`), wait 20s, re-check,
   log it.

### C1 — Hung-process detection (CPU sampling)

`Test-GDriveFSHung` records `[Process].CPU` (cumulative seconds) at T0 for
every GoogleDriveFS.exe, sleeps `HungSampleSeconds` (default 30), re-reads
CPU, and computes the per-process delta. If **all** processes are below
`HungCpuPctLow` (default `0.5%` of one core), the process is alive but
unresponsive → relaunch.

Notes:
- `HungSampleSeconds=0` disables C1 entirely (process-existence-only mode).
- The body is bounded by the scheduled task's `ExecutionTimeLimit` (5 min); the
  default 30s sample leaves ample headroom on top of the 20s post-relaunch wait.
- Per-process PID matching: if a process is recycled mid-sample, the new PID
  re-baselines at 0 (no false positives from inherited cumulative CPU).

### C2 — Cooldown + escalation

State file `<LogDir>/watchdog-state.json` tracks:

```json
{
  "consecutive_relaunch_failures": 0,
  "last_relaunch_attempt": "2026-07-24T...",
  "last_alert_at": "2026-07-24T...",
  "cooldown_until": "2026-07-25T..."
}
```

Logic:
- After each successful poll (alive + healthy) → reset `consecutive_relaunch_failures=0`.
- After each failed relaunch (process still absent 20s post-Start-Process) →
  increment counter.
- When counter reaches `MaxConsecutiveFailures` (default `3`) → mark
  `cooldown_until = now + CooldownHours` (default `24h`), emit EventLog
  **Error** event 2001 ("GDriveFS watchdog ESCALATION..."), and stop attempting
  relaunches until cooldown expires.
- `dry-run` mode never mutates the state file (safe to test).
- Re-arms automatically: when the next successful detection (alive + healthy)
  reports, the counter and cooldown are reset in the same poll.

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
comm automatically. The C2 cooldown limits log noise to once per 24h while the
user re-auths manually — the next successful `Test-GDriveFSAlive` (after the
user re-auths) clears the cooldown and the watchdog resumes normal operation.

## Files

| File | Role |
|------|------|
| `gdrivefs-watchdog.ps1` | Body — one-shot poll: detect (C0) + health-check (C1) + cooldown (C2) + relaunch + log. |
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
| `Mode` (body) | `poll` | `poll` = relaunch if dead/hung; `dry-run` = probe only (never relaunch, never touch state) |
| `HungSampleSeconds` (body) | `30` | C1 — sample window for CPU-delta hung detection. `0` disables C1. |
| `HungCpuPctLow` (body) | `0.5` | C1 — below this CPU% of one core over the window → hung. |
| `MaxConsecutiveFailures` (body) | `3` | C2 — after this many failed relaunches, enter cooldown. |
| `CooldownHours` (body) | `24` | C2 — hours to suppress further relaunches after threshold reached. |
| `LogRetentionDays` (body) | `14` | Auto-prune logs older than N days. |
| `RepeatMinutes` (installer) | `15` | Poll cadence. |
| `StartupDelayMinutes` (installer) | `2` | Delay after boot (let GDrive settle). |

Artifacts (gitignored):
- **Logs**: `<LogDir>/watchdog-YYYYMMDD.log`
- **State file**: `<LogDir>/watchdog-state.json` (C2) — survives across polls to track consecutive failures and cooldown.

Tuning `HungSampleSeconds`/`HungCpuPctLow`: the default 30s @ 0.5% detects a
fully unresponsive process while tolerating normal idling. Tighten
(`HungSampleSeconds=15`, `HungCpuPctLow=0.2`) for stricter detection on a
host with frequent sync; loosen (`HungSampleSeconds=60`) on a slow host that
runs heavy sync periodically. Cooldown should stay ≥ 24h to avoid masking
persistent auth loss with noise.
