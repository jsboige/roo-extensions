<#
.SYNOPSIS
    Install Docker Desktop auto-start scheduled task (Phase 1, #1171)
.DESCRIPTION
    Creates a Windows Scheduled Task that starts Docker Desktop at system boot,
    without requiring user logon. Idempotent: skips if task already exists.

    Decision R58 (2026-05-18): Option (b) approved fleet-wide.
    Phase 1 lead: myia-po-2024. Deadline 2026-05-20.
.PARAMETER Force
    Re-create task even if it already exists
.EXAMPLE
    .\install-docker-autostart.ps1
    .\install-docker-autostart.ps1 -Force
#>
[CmdletBinding()]
param(
    [switch]$Force
)

$TaskName = 'Docker-Auto-Start'
$DockerExe = 'C:\Program Files\Docker\Docker\Docker Desktop.exe'

# Pre-checks
if (-not (Test-Path $DockerExe)) {
    Write-Error "Docker Desktop not found at: $DockerExe"
    exit 1
}

# Check existing task
$existing = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
if ($existing -and -not $Force) {
    Write-Host "Task '$TaskName' already exists (State: $($existing.State)). Use -Force to recreate." -ForegroundColor Yellow
    exit 0
}

# Remove existing if Force
if ($existing -and $Force) {
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
    Write-Host "Removed existing task." -ForegroundColor Gray
}

# Create task
$action = New-ScheduledTaskAction -Execute "`"$DockerExe`"" -Argument '-WindowStyle Hidden'
$trigger = New-ScheduledTaskTrigger -AtStartup
$trigger.Delay = 'PT30S'
$principal = New-ScheduledTaskPrincipal -UserId 'NT AUTHORITY\SYSTEM' -LogonType ServiceAccount -RunLevel Highest
$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 5)

Register-ScheduledTask `
    -TaskName $TaskName `
    -Action $action `
    -Trigger $trigger `
    -Principal $principal `
    -Settings $settings `
    -Description 'Start Docker Desktop automatically at system boot without requiring user logon (#1171 Phase 1)' `
    -Force

# Verify
$task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
if ($task) {
    Write-Host "SUCCESS: Task '$TaskName' registered (State: $($task.State))" -ForegroundColor Green
    Write-Host "  Trigger: AtStartup + PT30S delay" -ForegroundColor Gray
    Write-Host "  Principal: NT AUTHORITY\SYSTEM (Highest)" -ForegroundColor Gray
    Write-Host "  Next step: Reboot machine to verify Docker starts without user logon" -ForegroundColor Cyan
} else {
    Write-Error "FAILED: Task was not registered. This script requires elevated (admin) privileges."
    Write-Host "Run from an elevated PowerShell: Start-Process powershell -Verb RunAs -ArgumentList '-File', '$PSCommandPath'" -ForegroundColor Yellow
    exit 1
}
