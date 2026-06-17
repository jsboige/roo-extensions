<#
.SYNOPSIS
    Install or uninstall the weekly tool-usage snapshot scheduled task (#2336 D4).

.DESCRIPTION
    Creates a Windows scheduled task that runs save-tool-usage-snapshot.ps1 once a week
    (default Monday 03:17, off-peak) to persist a tool_usage_stats snapshot to
    <shared>/tool-usage-snapshots/{machine}-{date}.json via the RSM save_snapshot action.

    Why: the user mandate (#2336, 2026-05-24) asks to "voir usage↑/utilité↑ vs cycle
    précédent". The infra exists (roosync_indexing save_snapshot + trend_report), but
    without a recurring snapshot there is nothing for trend_report to compare -- the
    mandate cannot be realized. Observed before this task: only 1 snapshot existed
    fleet-wide (po-2026 2026-06-04), 13 days stale.

    Design (mirrors install-inventory-schtask.ps1):
      - Per-machine: each machine writes {machine}-{date}.json under the shared
        tool-usage-snapshots/ dir (distinct files -> 0 GDrive contention). Rollout =
        identical schtask on each machine.
      - One-shot weekly: a ~30s save_snapshot call, not a continuous service. No
        self-healing repeat trigger (unlike Claude-DashboardListener).
      - Best-effort: save-tool-usage-snapshot.ps1 wraps the claude -p call in try/catch
        and exits 1 on failure; a weekly task that fails this week retries next week.
      - Staleness: save_snapshot overwrites {machine}-{date}.json for today; prior days
        are preserved as distinct files so trend_report can diff any two.

    NOTE: This script is reviewed-but-NOT-installed. Fleet-wide install requires UAC
    elevation (Register-ScheduledTask) and is an [INTERACTIVE-ONLY] + user-arbitration
    step. trend_report itself still requires the #2623 fix (schema-drift robustness) to
    be deployed via MCP host restart to be fully usable.

.PARAMETER Uninstall
    Remove the scheduled task instead of creating it.

.PARAMETER DryRun
    Print the exact schtask configuration that would be registered, without registering
    (no elevation required). Use to validate before fleet rollout.

.PARAMETER TaskDay
    Day of week for the weekly run (default "Monday"). Off-peak, before the 2h executor
    cron ramp.

.PARAMETER TaskTime
    Run time as "HH:mm" (default "03:17", off-:00 / off-peak).

.EXAMPLE
    .\install-tool-usage-snapshot-schtask.ps1 -DryRun
    # Preview the schtask config without registering.

.EXAMPLE
    .\install-tool-usage-snapshot-schtask.ps1
    # Register the weekly Monday 03:17 task (requires elevation).

.EXAMPLE
    .\install-tool-usage-snapshot-schtask.ps1 -Uninstall

.NOTES
    Requires admin elevation (RunLevel Highest) for schtasks registration.
    Run from an elevated PowerShell:
    pwsh -ExecutionPolicy Bypass -File .\install-tool-usage-snapshot-schtask.ps1
#>

param(
    [switch]$Uninstall,

    [switch]$DryRun,

    [string]$TaskDay = "Monday",

    [string]$TaskTime = "03:17"
)

$ErrorActionPreference = 'Stop'
$scriptDir = Split-Path $MyInvocation.MyCommand.Path -Parent
$snapshotScript = Join-Path $scriptDir "save-tool-usage-snapshot.ps1"
$taskName = "roo-save-tool-usage-snapshot"

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
if (-not (Test-Path $snapshotScript)) {
    Write-Host "ERROR: snapshot script not found: $snapshotScript" -ForegroundColor Red
    exit 1
}

# Validate TaskTime format (HH:mm)
if ($TaskTime -notmatch '^\d{2}:\d{2}$') {
    Write-Host "ERROR: -TaskTime must be HH:mm (e.g. '03:17'). Got: $TaskTime" -ForegroundColor Red
    exit 1
}
$hour, $minute = $TaskTime -split ':'
if ([int]$hour -gt 23 -or [int]$minute -gt 59) {
    Write-Host "ERROR: -TaskTime out of range: $TaskTime" -ForegroundColor Red
    exit 1
}

# Validate TaskDay (day-of-week name)
$validDays = @('Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday')
if ($TaskDay -notin $validDays) {
    Write-Host "ERROR: -TaskDay must be one of: $($validDays -join ', '). Got: $TaskDay" -ForegroundColor Red
    exit 1
}

$pwshPath = (Get-Command pwsh -ErrorAction SilentlyContinue).Source
if (-not $pwshPath) {
    Write-Host "ERROR: pwsh not found in PATH." -ForegroundColor Red
    exit 1
}

# ========================================
# BUILD SCHTASK COMPONENTS
# ========================================
# Action: run save-tool-usage-snapshot.ps1 (which pipes a save_snapshot prompt to claude -p).
$action = New-ScheduledTaskAction -Execute $pwshPath `
    -Argument "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$snapshotScript`""

# Single weekly trigger. A ~30s save_snapshot one-shot, not a continuous service --
# no self-healing repeat trigger (unlike Claude-DashboardListener).
$trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek $TaskDay -At $TaskTime

# Run as the interactive user (claude -p needs the USER's ~/.claude.json MCP config).
# RunLevel Highest keeps parity with the inventory collector; registration requires
# elevation (script is [INTERACTIVE-ONLY]).
$principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -RunLevel Highest -LogonType Interactive

# Best-effort: -StartWhenAvailable runs a missed fire (machine off) on wake.
$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
    -StartWhenAvailable -RestartCount 2 -RestartInterval (New-TimeSpan -Minutes 5)

$description = "Weekly tool-usage snapshot (#2336 D4) -- persists tool_usage_stats to <shared>/tool-usage-snapshots/{machine}-{date}.json via save-tool-usage-snapshot.ps1 (RSM save_snapshot). Feeds trend_report."

# ========================================
# DRY RUN (validate without elevation)
# ========================================
if ($DryRun) {
    Write-Host "========== DRY RUN -- schtask preview (not registered) ==========" -ForegroundColor Cyan
    Write-Host "TaskName    : $taskName"
    Write-Host "Action      : $($action.Execute) $($action.Arguments)"
    Write-Host "Trigger     : Weekly on $TaskDay at $TaskTime"
    Write-Host "Principal   : $($principal.UserId) (RunLevel: $($principal.RunLevel), LogonType: $($principal.LogonType))"
    Write-Host "Description : $description"
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Snapshot script exists: $((Test-Path $snapshotScript)) | pwsh: $pwshPath"
    Write-Host "To register (elevated): re-run without -DryRun"
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
Write-Host "  Trigger      : Weekly on $TaskDay at $TaskTime | Principal: $env:USERNAME (Highest)"
Write-Host "  Snapshot run : $snapshotScript"
Write-Host "  Output       : <shared>/tool-usage-snapshots/$($env:COMPUTERNAME.ToLower())-{date}.json"
Write-Host ""
Write-Host "To run immediately: schtasks /run /tn `"$taskName`""
