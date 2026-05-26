<#
.SYNOPSIS
    Install Docker Desktop auto-start scheduled task with healthcheck (Phase 1, #1171)
.DESCRIPTION
    Creates a Windows Scheduled Task that starts Docker Desktop at system boot,
    with a healthcheck that verifies the Docker daemon is responsive. Idempotent.

    Decision R58 (2026-05-18): Option (b) approved fleet-wide.
    Phase 1 lead: myia-po-2024.
.PARAMETER Force
    Re-create task even if it already exists
.PARAMETER HealthCheckTimeout
    Seconds to wait for Docker daemon after startup (default 120)
.EXAMPLE
    .\install-docker-autostart.ps1
    .\install-docker-autostart.ps1 -Force
    .\install-docker-autostart.ps1 -HealthCheckTimeout 180
#>
[CmdletBinding()]
param(
    [switch]$Force,
    [int]$HealthCheckTimeout = 120
)

$TaskName = 'Docker-Auto-Start'
$DockerExe = 'C:\Program Files\Docker\Docker\Docker Desktop.exe'
$WrapperScript = Join-Path $PSScriptRoot 'start-docker-with-healthcheck.ps1'

# Pre-checks
if (-not (Test-Path $DockerExe)) {
    Write-Error "Docker Desktop not found at: $DockerExe"
    exit 1
}

if (-not (Test-Path $WrapperScript)) {
    Write-Error "Wrapper script not found at: $WrapperScript"
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

# Create task — runs wrapper which starts Docker + healthcheck
$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$WrapperScript`" -HealthCheckTimeout $HealthCheckTimeout"
$trigger = New-ScheduledTaskTrigger -AtStartup
$trigger.Delay = 'PT60S'
$principal = New-ScheduledTaskPrincipal -UserId 'NT AUTHORITY\SYSTEM' -LogonType ServiceAccount -RunLevel Highest
$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 10)

Register-ScheduledTask `
    -TaskName $TaskName `
    -Action $action `
    -Trigger $trigger `
    -Principal $principal `
    -Settings $settings `
    -Description 'Start Docker Desktop at boot with daemon healthcheck (#1171 Phase 1)' `
    -Force

# Verify
$task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
if ($task) {
    Write-Host "SUCCESS: Task '$TaskName' registered (State: $($task.State))" -ForegroundColor Green
    Write-Host "  Trigger: AtStartup + PT60S delay" -ForegroundColor Gray
    Write-Host "  Principal: NT AUTHORITY\SYSTEM (Highest)" -ForegroundColor Gray
    Write-Host "  Wrapper: $WrapperScript" -ForegroundColor Gray
    Write-Host "  Healthcheck timeout: ${HealthCheckTimeout}s" -ForegroundColor Gray
    Write-Host "  Log: $env:ProgramData\Docker-Auto-Start\healthcheck.log" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  Test: Start-ScheduledTask -TaskName '$TaskName'" -ForegroundColor Cyan
    Write-Host "  Verify: Get-Content $env:ProgramData\Docker-Auto-Start\healthcheck.log" -ForegroundColor Cyan
} else {
    Write-Error "FAILED: Task was not registered. This script requires elevated (admin) privileges."
    Write-Host "Run from an elevated PowerShell: Start-Process powershell -Verb RunAs -ArgumentList '-File', '$PSCommandPath'" -ForegroundColor Yellow
    exit 1
}
