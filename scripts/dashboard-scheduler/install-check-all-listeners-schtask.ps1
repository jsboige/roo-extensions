<#
.SYNOPSIS
    Install or uninstall the Claude-CheckAllListeners scheduled task (#2928 systemic gap).

.DESCRIPTION
    Creates a Windows scheduled task that runs check-all-listeners.ps1 every 2h, reading
    shared heartbeats from <ROOSYNC_SHARED_PATH>/listener-heartbeats/*.heartbeat and
    posting a [FLEET-ALERT] [WARN] to the local workspace dashboard when any machine's
    wake-listener heartbeat is STALE >2h.

    Why: #2928 incident (ai-01 listener dead 8h, coordinator non-WAKE-able). The checker
    script existed in the repo but was not registered as a schtask on ANY machine. Without
    this monitoring, a dead listener passes unnoticed for 8h+ instead of 2h max.

    Design (mirrors install-tool-usage-snapshot-schtask.ps1):
      - Per-machine, idempotent: identical schtask installed on each fleet machine.
        Any machine can detect any other machine's dead listener via shared GDrive
        heartbeats -> redundant detection (no single-point-of-failure).
      - Short one-shot run (~1-5s, reads local files + maybe writes dashboard file).
        Not a long-running service -> no self-healing repeat trigger (unlike
        Claude-DashboardListener), no ExecutionTimeLimit PT0S.
      - Best-effort: try/catch in the checker script itself; a failed run retries next
        cycle (2h later).
      - -StartWhenAvailable: a missed fire (machine off) runs on wake.

    Rollout options (NOT decided here -- coordinator/user lane per #2928):
      - Option 1 (ai-01 self + fleet): install only on ai-01. Centralized detection.
      - Option 2 (fleet-wide distributed): install on every machine. Redundant detection.
      - Option 3 (ad-hoc): keep manual I3 patrols (status quo ante).

    NOTE: This script is reviewed-but-NOT-installed by default. Fleet-wide install requires
    UAC elevation (Register-ScheduledTask) and is an [INTERACTIVE-ONLY] + user-arbitration
    step per CLAUDE.md. The -DryRun flag previews the schtask config without registering.

.PARAMETER Uninstall
    Remove the scheduled task instead of creating it.

.PARAMETER DryRun
    Print the exact schtask configuration that would be registered, without registering
    (no elevation required). Use to validate before fleet rollout.

.PARAMETER IntervalMinutes
    Repetition interval in minutes (default 120 = 2h, matches the script's 7200s STALE
    threshold and the documented "every 2h" cron cadence).

.EXAMPLE
    .\install-check-all-listeners-schtask.ps1 -DryRun
    # Preview the schtask config without registering.

.EXAMPLE
    .\install-check-all-listeners-schtask.ps1
    # Register the 2h task (requires elevation).

.EXAMPLE
    .\install-check-all-listeners-schtask.ps1 -Uninstall

.NOTES
    Requires admin elevation (RunLevel Highest) for schtasks registration.
    Run from an elevated PowerShell:
    pwsh -ExecutionPolicy Bypass -File .\install-check-all-listeners-schtask.ps1

    Related: issue #2928 (ai-01 listener dead 8h -- systemic detection gap),
    #2576 (web1 listener recurring STALE), #2431 (durability fix).
#>

param(
    [switch]$Uninstall,

    [switch]$DryRun,

    [int]$IntervalMinutes = 120
)

$ErrorActionPreference = 'Stop'
$scriptDir = Split-Path $MyInvocation.MyCommand.Path -Parent
$checkerScript = Join-Path $scriptDir "check-all-listeners.ps1"
$taskName = "Claude-CheckAllListeners"

# ========================================
# UNINSTALL PATH
# ========================================
if ($Uninstall) {
    if ($DryRun) {
        Write-Host "[DryRun] Would unregister task: $taskName" -ForegroundColor Cyan
        exit 0
    }
    $existing = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
    if ($existing) {
        Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
        Write-Host "Removed scheduled task: $taskName" -ForegroundColor Green
    } else {
        Write-Host "Task not found: $taskName" -ForegroundColor Yellow
    }
    exit 0
}

# ========================================
# PRE-FLIGHT CHECKS
# ========================================
if (-not (Test-Path $checkerScript)) {
    Write-Host "ERROR: checker script not found: $checkerScript" -ForegroundColor Red
    exit 1
}

if ($IntervalMinutes -lt 15) {
    Write-Host "ERROR: -IntervalMinutes must be >= 15 (GDrive heartbeat write cadence is 5 min," -ForegroundColor Red
    Write-Host "       anything tighter than 15 min would alert before a healthy listener even pings)."
    exit 1
}

$pwshPath = (Get-Command pwsh -ErrorAction SilentlyContinue).Source
if (-not $pwshPath) {
    Write-Host "ERROR: pwsh not found in PATH." -ForegroundColor Red
    exit 1
}

# ROOSYNC_SHARED_PATH is required by check-all-listeners.ps1 to locate heartbeats.
# Warn (don't fail) -- the task can still be registered; it will surface the error
# in its own output at run time, which is more debuggable than blocking install.
$sharedPath = $env:ROOSYNC_SHARED_PATH
if (-not $sharedPath) {
    # Try User-level env var (set by install-dashboard-listener-schtask.ps1)
    $sharedPath = [System.Environment]::GetEnvironmentVariable('ROOSYNC_SHARED_PATH', 'User')
}
$roosyncWarning = if (-not $sharedPath) {
    "WARNING: ROOSYNC_SHARED_PATH not set. The checker will exit with UNKNOWN for every machine. Set it via install-dashboard-listener-schtask.ps1 or manually."
} else {
    "ROOSYNC_SHARED_PATH detected: $sharedPath"
}

# ========================================
# BUILD SCHTASK COMPONENTS
# ========================================
# Action: run check-all-listeners.ps1 with default params (check full fleet, alert on dead).
$action = New-ScheduledTaskAction -Execute $pwshPath `
    -Argument "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$checkerScript`""

# Repeat every N minutes starting in 1 min. A short one-shot (~1-5s) -- not a service,
# no AtLogOn/AtStartup trigger needed (the repeat covers it; -StartWhenAvailable covers
# machine-off misses).
$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1) `
    -RepetitionInterval (New-TimeSpan -Minutes $IntervalMinutes)

# Run as the interactive user (matches Claude-DashboardListener pattern -- needs
# ROOSYNC_SHARED_PATH User env var + write access to .claude/workspaces/ dashboard file).
$principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -RunLevel Highest -LogonType Interactive

# Bounded execution (5 min cap if GDrive hangs) + best-effort retry.
$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
    -StartWhenAvailable -RestartCount 2 -RestartInterval (New-TimeSpan -Minutes 5) `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 5) `
    -MultipleInstances IgnoreNew

$description = "Fleet wake-listener health check (#2928 systemic gap) -- runs check-all-listeners.ps1 every $IntervalMinutes min. Reads shared heartbeats, posts [FLEET-ALERT] [WARN] on STALE >2h. Self-installed per-machine; any machine can detect any other's dead listener via shared GDrive heartbeats."

# ========================================
# DRY RUN (validate without elevation)
# ========================================
if ($DryRun) {
    Write-Host "========== DRY RUN -- schtask preview (not registered) ==========" -ForegroundColor Cyan
    Write-Host "TaskName      : $taskName"
    Write-Host "Action        : $($action.Execute) $($action.Arguments)"
    Write-Host "Trigger       : Every $IntervalMinutes min (-Once + RepetitionInterval)"
    Write-Host "Principal     : $($principal.UserId) (RunLevel: $($principal.RunLevel), LogonType: $($principal.LogonType))"
    Write-Host "ExecLimit     : 5 min | MultipleInstances: IgnoreNew | Restart: 2x /5min"
    Write-Host "Description   : $description"
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Checker script exists: $((Test-Path $checkerScript)) | pwsh: $pwshPath"
    Write-Host $roosyncWarning
    Write-Host ""
    Write-Host "To register (elevated): re-run without -DryRun"
    Write-Host "To test checker now    : pwsh -File `"$checkerScript`""
    exit 0
}

# ========================================
# REGISTER (elevated)
# ========================================
# Idempotent re-install: remove an existing task first.
$existing = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
if ($existing) {
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
    Write-Host "Removed existing task: $taskName" -ForegroundColor Gray
}

Register-ScheduledTask -TaskName $taskName `
    -Action $action -Trigger $trigger -Principal $principal `
    -Settings $settings -Description $description | Out-Null

Write-Host "Installed scheduled task: $taskName" -ForegroundColor Green
Write-Host "  Trigger      : Every $IntervalMinutes min | Principal: $env:USERNAME (Highest)"
Write-Host "  Checker      : $checkerScript"
Write-Host "  Alert sink   : local .claude/workspaces/workspace-<machine>.md ([FLEET-ALERT] [WARN])"
Write-Host ""
Write-Host $roosyncWarning -ForegroundColor $(if ($sharedPath) { 'Gray' } else { 'Yellow' })
Write-Host ""
Write-Host "To run immediately: schtasks /run /tn `"$taskName`""
Write-Host "To verify        : (Get-ScheduledTask $taskName).Triggers"
