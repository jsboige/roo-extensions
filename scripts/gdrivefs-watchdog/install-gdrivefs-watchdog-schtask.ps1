<#
.SYNOPSIS
    Install or uninstall the GDriveFS-Watchdog scheduled task (#2875).

.DESCRIPTION
    GoogleDriveFS.exe dies silently with no auto-restart (HKCU Run = logon-only).
    This task runs gdrivefs-watchdog.ps1 as a short poll every 15 min: if the
    process is absent, it relaunches it in the user context (same launch command
    as the HKCU Run entry). Cuts the recurrence of the #2875 comm blackouts from
    hours/days down to ~15 min.

    Mirrors the dashboard-listener installer's self-healing shape (user principal,
    AtLogOn + AtStartup + repetition, IgnoreNew) — but the body is a short-lived
    poll, NOT a long-running wrapper, so ExecutionTimeLimit is bounded (5 min)
    rather than Zero.

    GDriveFS binds to the user account token, so the task MUST run as the user
    (NOT SYSTEM) — a SYSTEM-context relaunch cannot associate the core_controller.

.PARAMETER Uninstall
    Remove the scheduled task instead of creating it.

.EXAMPLE
    .\install-gdrivefs-watchdog-schtask.ps1
    .\install-gdrivefs-watchdog-schtask.ps1 -Uninstall

.NOTES
    Requires admin elevation (RunLevel Highest) for schtasks registration.
    Run from an elevated PowerShell:
    pwsh -ExecutionPolicy Bypass -File .\install-gdrivefs-watchdog-schtask.ps1
#>

param(
    [switch]$Uninstall,
    [int]$RepeatMinutes = 15,
    [int]$StartupDelayMinutes = 2
)

$scriptDir   = Split-Path $MyInvocation.MyCommand.Path -Parent
$watchdogPs1 = Join-Path $scriptDir "gdrivefs-watchdog.ps1"
$taskName    = "GDriveFS-Watchdog"

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

if (-not (Test-Path $watchdogPs1)) {
    Write-Host "ERROR: Watchdog body not found: $watchdogPs1"
    exit 1
}

# Remove old task if exists (idempotent reinstall).
$existing = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
if ($existing) {
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
    Write-Host "Removed existing task: $taskName"
}

$pwshPath = (Get-Command pwsh -ErrorAction SilentlyContinue).Source
if (-not $pwshPath) {
    Write-Host "ERROR: pwsh not found in PATH."
    exit 1
}

$action = New-ScheduledTaskAction -Execute $pwshPath -Argument "-ExecutionPolicy Bypass -NoProfile -WindowStyle Hidden -File `"$watchdogPs1`""

# Self-healing triggers, mirroring install-dashboard-listener-schtask.ps1 (#2431).
# - AtLogOn: covers the normal interactive-session start (matches the old HKCU Run).
# - AtStartup (+delay): covers a boot without an interactive logon yet.
# - Repeat every N min: resurrects a dead GDriveFS within the interval. IgnoreNew
#   makes this a no-op while the previous poll is still running.
$trigLogon   = New-ScheduledTaskTrigger -AtLogOn
$trigStartup = New-ScheduledTaskTrigger -AtStartup
$trigStartup.Delay = "PT${StartupDelayMinutes}M"
$trigRepeat  = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1) -RepetitionInterval (New-TimeSpan -Minutes $RepeatMinutes)

# USER principal (NOT SYSTEM): GDriveFS binds its core_controller to the user
# account token; a SYSTEM-context relaunch cannot restore the account association.
$principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -RunLevel Highest -LogonType Interactive

# Body is a short poll (~25s incl. the 20s init wait), NOT a long-running wrapper:
# bound ExecutionTimeLimit (5 min) is enough headroom without leaving a stray proc.
$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -RestartCount 3 `
    -RestartInterval (New-TimeSpan -Minutes 1) `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 5) `
    -MultipleInstances IgnoreNew

Register-ScheduledTask -TaskName $taskName -Action $action -Trigger @($trigLogon, $trigStartup, $trigRepeat) -Principal $principal -Settings $settings -Description "GDriveFS silent-exit watchdog #2875 — relaunch GoogleDriveFS.exe (user context) when absent, every $RepeatMinutes min" | Out-Null

Write-Host "Installed scheduled task: $taskName"
Write-Host "  Triggers: AtLogOn + AtStartup(+${StartupDelayMinutes}m) + repeat every ${RepeatMinutes}m | Principal: $env:USERNAME (Highest, Interactive)"
Write-Host "  ExecutionTimeLimit: 5 min | MultipleInstances: IgnoreNew"
Write-Host "  Body: $watchdogPs1"
Write-Host ""
Write-Host "To start immediately: schtasks /run /tn `"$taskName`""
Write-Host "To test the body standalone (no install): pwsh -File `"$watchdogPs1`" -Mode dry-run"
