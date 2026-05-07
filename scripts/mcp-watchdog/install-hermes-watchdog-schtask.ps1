<#
.SYNOPSIS
    Install scheduled task for Hermes bridge watchdog (#2014).

.DESCRIPTION
    Creates a Windows scheduled task that runs the Hermes bridge watchdog every 5 minutes.
    The task runs as the current user with highest privileges.

.PARAMETER Uninstall
    Remove the scheduled task instead of creating it.

.EXAMPLE
    .\install-hermes-watchdog-schtask.ps1
    .\install-hermes-watchdog-schtask.ps1 -Uninstall
#>

param(
    [switch]$Uninstall
)

$taskName = 'Hermes-Bridge-Watchdog'
$scriptPath = Join-Path $PSScriptRoot 'hermes-bridge-watchdog.ps1'

if ($Uninstall) {
    Write-Host "Removing scheduled task '$taskName'..."
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
    Write-Host 'Done.'
    exit 0
}

if (-not (Test-Path $scriptPath)) {
    Write-Error "Watchdog script not found: $scriptPath"
    exit 1
}

Write-Host "Installing scheduled task '$taskName'..."
Write-Host "  Script: $scriptPath"

# Remove existing task if present
Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue

$action = New-ScheduledTaskAction -Execute 'pwsh.exe' -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`" -Mode poll"
$trigger = @(
    (New-ScheduledTaskTrigger -AtStartup),
    (New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Minutes 5) -RepetitionDuration (New-TimeSpan -Days 9999))
)
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Minutes 5)

$principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -RunLevel Highest

Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Description 'Hermes mcp-remote bridge watchdog — auto-restart on ClosedResourceError (#2014)' | Out-Null

# Start immediately
Start-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue

Write-Host "Scheduled task '$taskName' installed (every 5 min + at startup)."
Write-Host "State: $((Get-ScheduledTask -TaskName $taskName).State)"
