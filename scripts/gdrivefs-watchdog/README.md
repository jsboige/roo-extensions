# GDriveFS Watchdog

**Issues:** #2875 (silent-exit), #2933 (C1 mechanism + C2), #2938 (positive C1 liveness probe)
**Date:** 2026-07-25
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

1. **C0 (silent-exit)** — Is `GoogleDriveFS.exe` running? If not, relaunch.
2. **C1 (hung-process)** — Can the configured DriveFS mount serve a metadata
   request within 5 seconds? A healthy idle mount succeeds; timeout/error means
   `core_controller` is not serving filesystem I/O, so relaunch.
3. **C2 (cooldown)** — If a relaunch is needed and we're in cooldown, skip and
   emit an alert. Otherwise relaunch in the **user context** (same command as
   the HKCU `Run` entry: `GoogleDriveFS.exe --startup_mode`), then re-check
   process existence and mount liveness, and log the result.

### C1 — Positive mount liveness probe

`Test-GDriveFSMountLive` runs `Get-Item -LiteralPath <MountPath>` in a background
PowerShell job and waits at most `MountProbeTimeoutSeconds` (default `5`). The
bounded metadata operation provides a positive signal from DriveFS itself:

- Healthy and idle: mount stat completes → healthy.
- Process alive but `core_controller` wedged: stat hangs until timeout → hung.
- Mount absent or serving errors: stat fails → unhealthy.

C1 is enabled by default for `G:\`. Set `MountPath` for hosts that use a different
DriveFS mount. `MountProbeTimeoutSeconds=0` disables C1 as an explicit recovery
option; normal installs should retain the default probe. The previous CPU-delta
heuristic was removed because an idle-but-healthy DriveFS legitimately uses 0%
CPU and therefore produced false positives.

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

### Startup grace guard (A0.1/A0.2, #3466)

GoogleDriveFS mount init takes **~11-20 min** on slow hosts (measured on ai-01,
2026-09-05). The poll cadence (15 min) is shorter than that init, so the watchdog
would otherwise **kill an instance its previous tick had just launched** — and
declare its own relaunch failed on a 90 s constant that couldn't see the init
complete (proof n1: `15:42 FAIL → 16:03 mount-stat-ok`, same pids; proof n2:
the recovery came from a manual restart, not the watchdog).

Two guards, both anchored on `StartupGraceSeconds` (default 1200 = 20 min,
derived from the measured init):

- **A0.1 — no kill during init.** A C1-hung instance whose youngest process is
  still inside the grace window is a relaunch mid-init, not a genuine hang. The
  watchdog leaves it alone: no kill, no relaunch, no failed-cycle count. Grace
  reads the process `StartTime` (host-native / manually-started instances) **and**
  the `last_relaunch_attempt` field already written by C2 (instances the watchdog
  itself launched).
- **A0.2 — verdict measured, not a 90 s constant.** After a relaunch, the
  watchdog does **not** declare failure on a fixed 90 s window. It issues the
  relaunch, does one bounded probe for fast-success feedback, and defers the
  verdict to the grace window: a relaunch still inside grace is not a failure, and
  the next poll that sees it still hung **after** grace elapses counts that cycle
  as a genuine failure (and re-launches). The C2 cooldown still engages on repeated
  post-grace failures, so a truly broken relaunch (e.g. dropped account token) is
  still escalated.

**A0.3 positive control** is a regression test: replay the in-init sequence from
proof n2 (relaunch at 17:37:47 → observations at 17:39:25 and 17:48:30, 11 min
old, still in init). The old code (no grace) kills the in-init instance **(2
kills)**; the grace guard kills it **zero** times, while still killing a
genuinely-hung instance past the init window.

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
| `test-gdrivefs-watchdog.ps1` | Regression tests for successful idle mount stat, error, disable, and bounded return behavior. |
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

# Run regression tests for the positive mount probe:
pwsh -File scripts\gdrivefs-watchdog\test-gdrivefs-watchdog.ps1

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
| `MountPath` (body) | `G:\` | C1 — DriveFS mount whose metadata is probed. Override on hosts using another mount. |
| `MountProbeTimeoutSeconds` (body) | `5` | C1 — bounded mount-stat timeout. `0` explicitly disables C1. |
| `MaxConsecutiveFailures` (body) | `3` | C2 — after this many failed relaunches, enter cooldown. |
| `CooldownHours` (body) | `24` | C2 — hours to suppress further relaunches after threshold reached. |
| `StartupGraceSeconds` (body) | `1200` | Guard (#3466) — never kill an instance younger than this. Derived from the measured init time (~11-20 min). The post-relaunch verdict window is this factor, not a fixed 90 s. |
| `LogRetentionDays` (body) | `14` | Auto-prune logs older than N days. |
| `RepeatMinutes` (installer) | `15` | Poll cadence. |
| `StartupDelayMinutes` (installer) | `2` | Delay after boot (let GDrive settle). |

Artifacts (gitignored):
- **Logs**: `<LogDir>/watchdog-YYYYMMDD.log`
- **State file**: `<LogDir>/watchdog-state.json` (C2) — survives across polls to track consecutive failures and cooldown.
