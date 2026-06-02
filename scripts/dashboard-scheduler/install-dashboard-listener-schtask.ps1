<#
.SYNOPSIS
    Install or uninstall Claude-DashboardListener scheduled task (#2004).

.DESCRIPTION
    Creates a Windows scheduled task that runs dashboard-listener-wrapper.ps1
    at user logon. The listener replaces the old poll-based DashboardWatcher.

.PARAMETER Uninstall
    Remove the scheduled task instead of creating it.

.EXAMPLE
    .\install-dashboard-listener-schtask.ps1
    .\install-dashboard-listener-schtask.ps1 -Uninstall

.NOTES
    Requires admin elevation (RunLevel Highest) for schtasks registration.
    Run from an elevated PowerShell: pwsh -ExecutionPolicy Bypass -File .\install-dashboard-listener-schtask.ps1
#>

param(
    [switch]$Uninstall
)

$scriptDir = Split-Path $MyInvocation.MyCommand.Path -Parent
$wrapperScript = Join-Path $scriptDir "dashboard-listener-wrapper.ps1"

$taskName = "Claude-DashboardListener"

if ($Uninstall) {
    $existing = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
    if ($existing) {
        Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
        Write-Host "Removed scheduled task: $taskName"
    } else {
        Write-Host "Task not found: $taskName"
    }
    exit 0
}

if (-not (Test-Path $wrapperScript)) {
    Write-Host "ERROR: Wrapper script not found: $wrapperScript"
    exit 1
}

# Remove old task if exists
$existing = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
if ($existing) {
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
    Write-Host "Removed existing task: $taskName"
}

# Also disable old poll-based watcher if present
$oldTask = Get-ScheduledTask -TaskName "Claude-DashboardWatcher" -ErrorAction SilentlyContinue
if ($oldTask -and $oldTask.State -ne "Disabled") {
    Disable-ScheduledTask -TaskName "Claude-DashboardWatcher" | Out-Null
    Write-Host "Disabled old Claude-DashboardWatcher task."
}

$pwshPath = (Get-Command pwsh -ErrorAction SilentlyContinue).Source
if (-not $pwshPath) {
    Write-Host "ERROR: pwsh not found in PATH."
    exit 1
}

# Ensure ROOSYNC_SHARED_PATH is set at user level (#2431).
# The listener requires this to locate GDrive .shared-state dashboards.
$sharedPath = [System.Environment]::GetEnvironmentVariable('ROOSYNC_SHARED_PATH', 'User')
if (-not $sharedPath) {
    # Try to auto-detect from common GDrive paths
    $candidates = @(
        "$env:USERPROFILE\Google Drive\Mon Drive\Synchronisation\RooSync\.shared-state",
        "G:\Mon Drive\Synchronisation\RooSync\.shared-state",
        "D:\Google Drive\Mon Drive\Synchronisation\RooSync\.shared-state"
    )
    $detected = $candidates | Where-Object { Test-Path $_ } | Select-Object -First 1
    if ($detected) {
        [System.Environment]::SetEnvironmentVariable('ROOSYNC_SHARED_PATH', $detected, 'User')
        Write-Host "Set ROOSYNC_SHARED_PATH = $detected (auto-detected, User level)"
    } else {
        Write-Host "WARNING: ROOSYNC_SHARED_PATH not set and no GDrive .shared-state found."
        Write-Host "  The listener will fail to start. Set it manually:"
        Write-Host '  [System.Environment]::SetEnvironmentVariable("ROOSYNC_SHARED_PATH", "<path>", "User")'
    }
} else {
    Write-Host "ROOSYNC_SHARED_PATH already set: $sharedPath"
}

$action = New-ScheduledTaskAction -Execute $pwshPath -Argument "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$wrapperScript`""

# #2431 durability: self-healing triggers. The wrapper is a long-running process.
# The old lone -AtLogOn trigger fired only at interactive logon, and the default
# 72h ExecutionTimeLimit force-terminated the wrapper (SCHED_S_TASK_TERMINATED)
# with nothing to relaunch it — so the listener was dead for days/weeks at a time.
# Mirror the watchdog idiom (install-watchdog-schtask.ps1): logon + startup + a
# 15-min repetition that resurrects a dead wrapper within the interactive session.
$trigLogon = New-ScheduledTaskTrigger -AtLogOn
$trigStartup = New-ScheduledTaskTrigger -AtStartup
$trigStartup.Delay = "PT1M"
$trigRepeat = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1) -RepetitionInterval (New-TimeSpan -Minutes 15)

# Keep Interactive/user principal: the listener spawns user-context `claude -p`
# (like the working Claude-Worker task) — it must NOT run as SYSTEM.
$principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -RunLevel Highest -LogonType Interactive

# #2431: -ExecutionTimeLimit Zero removes the 72h kill of the long-running wrapper;
# -MultipleInstances IgnoreNew makes the 15-min repetition a no-op while a wrapper
# is already alive (so it only ever relaunches a dead one).
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1) -ExecutionTimeLimit ([TimeSpan]::Zero) -MultipleInstances IgnoreNew

Register-ScheduledTask -TaskName $taskName -Action $action -Trigger @($trigLogon, $trigStartup, $trigRepeat) -Principal $principal -Settings $settings -Description "Dashboard listener #2004 — event-driven spawn on actionable messages (self-healing #2431)" | Out-Null

Write-Host "Installed scheduled task: $taskName"
Write-Host "  Triggers: AtLogOn + AtStartup(+1m) + repeat every 15m | Principal: $env:USERNAME (Highest)"
Write-Host "  ExecutionTimeLimit: none (Zero) | MultipleInstances: IgnoreNew"
Write-Host "  Wrapper: $wrapperScript"
Write-Host ""
Write-Host "To start immediately: schtasks /run /tn `"$taskName`""
