# GDriveFS Watchdog

**Issues:** #2875 (silent-exit), #2933 (C1 mechanism + C2), #2938 (positive C1 liveness probe), #3678 (survivor alert channel + fast-poll)
**Date:** 2026-07-25 (updated 2026-09-16, #3678)
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
2. **C1 (hung-process)** — Can the configured DriveFS mount serve a bounded
   metadata request AND a bounded content enumeration (5 s per stage)? A healthy
   idle mount succeeds; timeout/error means `core_controller` is not serving
   filesystem I/O, so relaunch.
3. **C2 (cooldown)** — If a relaunch is needed and we're in cooldown, skip and
   emit an alert. Otherwise relaunch in the **user context** (same command as
   the HKCU `Run` entry: `GoogleDriveFS.exe --startup_mode`), then re-check
   process existence and mount liveness, and log the result.

### C1 — Positive mount liveness probe

`Test-GDriveFSMountLive` runs two bounded stages, each in a background PowerShell
job with at most `MountProbeTimeoutSeconds` (default `5`):

1. **Stat** — `Get-Item -LiteralPath <MountPath>` (metadata only, fast).
2. **Enumeration** — `Get-ChildItem <MountPath> | Select-Object -First 1`
   (bounded content read; exercising one entry is enough, and a mount that
   completes with zero entries still passes — the call completed).

The bounded operations provide a positive signal from DriveFS itself:

- Healthy and idle: stat + enumeration complete → healthy (`mount-stat+enum-ok`).
- Process alive but `core_controller` wedged: stat or enumeration hangs until
  timeout → hung (`mount-probe-timeout-Ns` / `mount-enum-timeout-Ns`).
- Mount absent or serving errors: stat fails → unhealthy (`mount-probe-error`).

The enumeration stage exists because of the 2026-09-05 incident (po-204): a
wedged DriveFS instance served stat normally while **every content read hung**
(the whole fleet saw the machine go silent). A stat-only probe logged
"healthy" through the entire outage. Stat answers "is the mount there?",
enumeration answers "does it serve content?" — both are needed.

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
  "cooldown_until": "2026-07-25T...",
  "last_github_alert_at": "2026-09-16T...",
  "consecutive_cooldown_skips": 0,
  "fast_poll_until": "2026-09-16T..."
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

### Survivor alert channel (#3678)

During a GDrive outage, every fleet coordination channel (dashboard, RooSync
inbox, `[WAKE-CLAUDE]`) runs through the dead `G:` mount — the incident of
2026-08-16 left the fleet deaf and mute for ~15 min with **no one off-host
aware**. The watchdog's local sinks (log file, Event Log 2001) worked, but they
speak into the void. The defense is two layers:

| Layer | Channel | Survives the GDrive outage? | Cost |
|-------|---------|------------------------------|------|
| 1 — local (already in place) | `watchdog-YYYYMMDD.log` + Event Log EventIds 2000/2001 | Yes (local disk) | zero |
| 2 — remote (#3678) | **GitHub issue** (label `gdrivefs-watchdog-alert`) via `gh` CLI | **Yes — gh talks to api.github.com, not G:** | ~4 issues / 24 h max |

Layer 2 triggers:

- **At C2 escalation** (cooldown engaged) — first alert.
- **On repeated cooldown-skips** (`CooldownSkipAlertThreshold`, default 2) —
  the outage persists; a re-alert is attempted on each skip.
- **Dedupe guard**: `last_github_alert_at` in the state file; a new issue only
  goes out after `AlertMinIntervalHours` (default 6 h) — ceiling ≈ 4 issues /
  24 h / machine under a continuous outage (~0.003 % of the 5 000/h GitHub quota).

Failure behavior: `gh` missing, unauthenticated, or the label absent ⇒ the
alert is skipped with a `WARN` in the local log. **A dead alert channel never
breaks the watchdog's local duties** (relaunch, cooldown, Event Log).

Prerequisites (once per repo): the label must exist —

```powershell
gh label create gdrivefs-watchdog-alert --repo jsboige/roo-extensions --color D93F0B
```

Pass `-AlertGitHubRepo ''` to disable remote alerting on a host (local sinks
remain).

This is a **persistence/observability** channel, not push notification: the
human still has to look at GitHub. A cross-machine absence-detection heartbeat
(design proposal §3 layer 3) is explicitly post-MVP.

### Fast-poll window (#3678)

The regular cadence is 15 min; after a C2 escalation that leaves up to 15 more
minutes of blind time. The installer registers a **companion task**
`GDriveFS-Watchdog-FastPoll` repeating every 1 min — **disabled** at rest. On
escalation the body arms it (`Enable-ScheduledTask`) for
`FastPollWindowMinutes` (default 10), records `fast_poll_until` in state, and
disarms it at window expiry or on recovery.

The companion invokes the same body with `-FastPoll`: outside the window, that
invocation **disarms the task and exits before any probe**. Even if a disarm
ever fails, the cost is one cheap no-op invocation per minute, not a full poll —
nominal cost stays zero (this is proposal option (b): dynamic arm/disarm, not
two permanent triggers).

### Status of the #2875 workaround — permanent (production control)

Original framing called this watchdog an interim fix pending a root-cause
repair of the GoogleDriveFS silent-exit. The investigation (#2875) closed
**inconclusive** — no crash log, no reproducible trigger; candidate causes
(OOM kill, indexation conflict, DriveFS v127 flakiness) remain undiscriminated.
**Decision (2026-09-16, #3678 deliverable 3): the workaround is permanent.**
This watchdog is a *production control*, not a temporary bandage; no further
root-cause investigation is planned unless a discriminating signal surfaces
(a logged crash, a reproducible behavior).

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
| `gdrivefs-watchdog.ps1` | Body — one-shot poll: detect (C0) + health-check (C1) + cooldown (C2) + relaunch + log + survivor alert (#3678) + fast-poll window (#3678). |
| `test-gdrivefs-watchdog.ps1` | Regression tests: mount probe (stat/enum/error/disable/bounded), startup-grace replay, survivor-channel alert (dedupe/mock gh), fast-poll window. |
| `install-gdrivefs-watchdog-schtask.ps1` | Installer — registers `GDriveFS-Watchdog` + the companion `GDriveFS-Watchdog-FastPoll` task (disabled until armed). |

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

…plus the companion task `GDriveFS-Watchdog-FastPoll` (1-min repeat,
**registered disabled** — the body arms/disarms it, see *Fast-poll window*).

**Upgrading from a pre-#3678 install:** re-run the installer (it replaces both
tasks idempotently) and make sure the `gdrivefs-watchdog-alert` label exists
(see *Survivor alert channel*).

Neither a cron worker nor a `[WAKE-CLAUDE]` can install it (chicken-and-egg: you
cannot WAKE to repair the WAKE; elevation is not available from a non-elevated
session).

## Usage

```powershell
# Dry-run (probe only, never relaunch) — safe, no system change:
pwsh -File scripts\gdrivefs-watchdog\gdrivefs-watchdog.ps1 -Mode dry-run

# Dry-run as the fast-poll companion would (exercises the early-exit guard):
pwsh -File scripts\gdrivefs-watchdog\gdrivefs-watchdog.ps1 -Mode dry-run -FastPoll

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
| `AlertGitHubRepo` (body) | `jsboige/roo-extensions` | #3678 — repo for survivor-channel alert issues. Empty string disables remote alerting. |
| `AlertMinIntervalHours` (body) | `6` | #3678 — minimum hours between two alert issues (ceiling ≈ 4 / 24 h). |
| `CooldownSkipAlertThreshold` (body) | `2` | #3678 — consecutive cooldown-skips before re-alerting (outage persists). |
| `FastPollWindowMinutes` (body) | `10` | #3678 — minutes of 1-min fast polling after a C2 escalation. |
| `FastPollTaskName` (body) | `GDriveFS-Watchdog-FastPoll` | #3678 — companion task name (must match the installer's). |
| `FastPoll` (body) | — | #3678 — switch set by the companion task invocation; enables the early-exit guard outside the window. |
| `RepeatMinutes` (installer) | `15` | Poll cadence. |
| `StartupDelayMinutes` (installer) | `2` | Delay after boot (let GDrive settle). |
| `FastPollRepeatMinutes` (installer) | `1` | #3678 — companion task repeat interval. |

Artifacts (gitignored):
- **Logs**: `<LogDir>/watchdog-YYYYMMDD.log`
- **State file**: `<LogDir>/watchdog-state.json` (C2) — survives across polls to track consecutive failures and cooldown.
