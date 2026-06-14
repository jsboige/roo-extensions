<#
.SYNOPSIS
    Install or uninstall the daily inventory-collection scheduled task (inventory-automation).

.DESCRIPTION
    Creates a Windows scheduled task that runs Bootstrap-AllInventories.ps1 once a day
    (default 04:17, off-peak) to keep the per-machine inventory JSON fresh.

    Why: without automation, inventories drift to 2-15 days stale (observed fleet-wide),
    so compare_config diffs compare a stale snapshot and produce misleading results.
    Daily refresh keeps the picture current.

    Design (dispatch ai-01 -> po-2024 2026-06-14, user-approved direction F):
      - Per-machine: each machine writes its own inventories/{machineId}.json (0 GDrive
        contention -- distinct files). Rollout = identical schtask on each machine.
      - Staleness idempotency: delegated to Bootstrap-AllInventories.ps1 -MaxAge (default 12h).
        Bootstrap already skips generation when the existing inventory is fresh and valid;
        re-runs within the threshold are a no-op -> safe double-fire.
      - Lockfile guard: Bootstrap holds a PID lockfile during the ~32s collection to prevent
        two concurrent writes corrupting the same inventory file (manual + schtask collision
        during debugging).
      - Best-effort: Bootstrap wraps generation in try/catch and exits 1 on failure; a daily
        task that fails today retries tomorrow -- it never breaks the host.
      - NOT a continuous service: a single 32s one-shot per day. No self-healing repeat
        trigger (unlike Claude-DashboardListener which is a long-running wrapper).

    Per the dispatch, this script is reviewed-but-NOT-installed. Fleet-wide install requires
    UAC elevation (Register-ScheduledTask) and is an [INTERACTIVE-ONLY] + user-arbitration step.

.PARAMETER Uninstall
    Remove the scheduled task instead of creating it.

.PARAMETER DryRun
    Print the exact schtask configuration that would be registered, without registering
    (no elevation required). Use to validate the script before fleet rollout.

.PARAMETER TaskTime
    Daily run time as "HH:mm" (default "04:17", off-:00 / off-peak, before the 2h executor
    cron ramp).

.PARAMETER MaxAgeHours
    Staleness threshold (hours) forwarded to Bootstrap-AllInventories.ps1 -MaxAge (default 12).
    Bootstrap skips regeneration when the existing inventory is younger than this.

.EXAMPLE
    .\install-inventory-schtask.ps1 -DryRun
    # Preview the schtask config without registering.

.EXAMPLE
    .\install-inventory-schtask.ps1
    # Register the daily 04:17 task (requires elevation).

.EXAMPLE
    .\install-inventory-schtask.ps1 -Uninstall

.NOTES
    Requires admin elevation (RunLevel Highest) for schtasks registration.
    Run from an elevated PowerShell:
    pwsh -ExecutionPolicy Bypass -File .\install-inventory-schtask.ps1
#>

param(
    [switch]$Uninstall,

    [switch]$DryRun,

    [string]$TaskTime = "04:17",

    [int]$MaxAgeHours = 12
)

$ErrorActionPreference = 'Stop'
$scriptDir = Split-Path $MyInvocation.MyCommand.Path -Parent
$bootstrapScript = Join-Path $scriptDir "Bootstrap-AllInventories.ps1"
$taskName = "Claude-InventoryCollector"

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
if (-not (Test-Path $bootstrapScript)) {
    Write-Host "ERROR: Bootstrap script not found: $bootstrapScript" -ForegroundColor Red
    exit 1
}

# Validate TaskTime format (HH:mm)
if ($TaskTime -notmatch '^\d{2}:\d{2}$') {
    Write-Host "ERROR: -TaskTime must be HH:mm (e.g. '04:17'). Got: $TaskTime" -ForegroundColor Red
    exit 1
}
$hour, $minute = $TaskTime -split ':'
if ([int]$hour -gt 23 -or [int]$minute -gt 59) {
    Write-Host "ERROR: -TaskTime out of range: $TaskTime" -ForegroundColor Red
    exit 1
}

# Resolve ROOSYNC_SHARED_PATH (User env, with GDrive auto-detect -- mirrors
# install-dashboard-listener-schtask.ps1).
$sharedPath = [System.Environment]::GetEnvironmentVariable('ROOSYNC_SHARED_PATH', 'User')
if (-not $sharedPath) {
    $candidates = @(
        "$env:USERPROFILE\Google Drive\Mon Drive\Synchronisation\RooSync\.shared-state",
        "G:\Mon Drive\Synchronisation\RooSync\.shared-state",
        "D:\Google Drive\Mon Drive\Synchronisation\RooSync\.shared-state"
    )
    $detected = $candidates | Where-Object { Test-Path $_ } | Select-Object -First 1
    if ($detected) {
        $sharedPath = $detected
        Write-Host "ROOSYNC_SHARED_PATH auto-detected: $sharedPath" -ForegroundColor Gray
    } else {
        Write-Host "ERROR: ROOSYNC_SHARED_PATH not set and no GDrive .shared-state found." -ForegroundColor Red
        Write-Host "  Bootstrap needs it to locate inventories/. Set it manually:" -ForegroundColor Yellow
        Write-Host '  [System.Environment]::SetEnvironmentVariable("ROOSYNC_SHARED_PATH", "<path>", "User")' -ForegroundColor Yellow
        exit 1
    }
} else {
    Write-Host "ROOSYNC_SHARED_PATH (User): $sharedPath" -ForegroundColor Gray
}

$pwshPath = (Get-Command pwsh -ErrorAction SilentlyContinue).Source
if (-not $pwshPath) {
    Write-Host "ERROR: pwsh not found in PATH." -ForegroundColor Red
    exit 1
}

# ========================================
# BUILD SCHTASK COMPONENTS
# ========================================
# Action: run Bootstrap with -MaxAge (staleness idempotency) AND an explicit
# -SharedStatePath so the scheduled run does not depend on the User env var being
# inherited by the task host.
$action = New-ScheduledTaskAction -Execute $pwshPath `
    -Argument "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$bootstrapScript`" -MaxAge $MaxAgeHours -SharedStatePath `"$sharedPath`""

# Single daily trigger. Inventory collection is a 32s one-shot, not a continuous
# service -- no self-healing repeat trigger (unlike Claude-DashboardListener).
$trigger = New-ScheduledTaskTrigger -Daily -At $TaskTime

# Run as the interactive user (must read ~/.claude.json, VS Code settings, Roo config
# for the USER -- not SYSTEM). RunLevel Highest = complete inventory (all listening
# ports, all services). Registration requires elevation (script is [INTERACTIVE-ONLY]).
$principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -RunLevel Highest -LogonType Interactive

# Best-effort: -StartWhenAvailable runs a missed fire (machine off at 04:17) on wake.
# -RestartCount handles transient failures; the 32s runtime is far under any limit.
$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
    -StartWhenAvailable -RestartCount 2 -RestartInterval (New-TimeSpan -Minutes 5)

$description = "Daily inventory collector (inventory-automation) -- refreshes inventories/{machineId}.json via Bootstrap-AllInventories.ps1 -MaxAge $MaxAgeHours. Staleness-idempotent + lockfile-guarded."

# ========================================
# DRY RUN (validate without elevation)
# ========================================
if ($DryRun) {
    Write-Host "========== DRY RUN -- schtask preview (not registered) ==========" -ForegroundColor Cyan
    Write-Host "TaskName    : $taskName"
    Write-Host "Action      : $($action.Execute) $($action.Arguments)"
    Write-Host "Trigger     : Daily at $TaskTime"
    Write-Host "Principal   : $($principal.UserId) (RunLevel: $($principal.RunLevel), LogonType: $($principal.LogonType))"
    Write-Host "SharedState : $sharedPath"
    Write-Host "MaxAge      : ${MaxAgeHours}h (Bootstrap skips if inventory fresher)"
    Write-Host "Description : $description"
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Bootstrap exists: $((Test-Path $bootstrapScript)) | pwsh: $pwshPath"
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
Write-Host "  Trigger  : Daily at $TaskTime | Principal: $env:USERNAME (Highest)"
Write-Host "  Bootstrap: $bootstrapScript (-MaxAge $MaxAgeHours)"
Write-Host "  Output   : $sharedPath\inventories\$($env:COMPUTERNAME.ToLower()).json"
Write-Host ""
Write-Host "To run immediately: schtasks /run /tn `"$taskName`""
