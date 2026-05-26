<#
.SYNOPSIS
    Test script for Docker auto-start scheduled task (#1171 Phase 1)
.DESCRIPTION
    Recreates the task with -Force, verifies registration, triggers manually,
    and checks healthcheck log. Run from elevated PowerShell.
#>
param(
    [switch]$SkipTrigger
)

$TaskName = 'Docker-Auto-Start'
$InstallScript = Join-Path $PSScriptRoot 'install-docker-autostart.ps1'
$LogFile = Join-Path $env:ProgramData 'Docker-Auto-Start\healthcheck.log'

Write-Host "`n=== Step 1: Reinstall task (-Force) ===" -ForegroundColor Cyan
& $InstallScript -Force
if ($LASTEXITCODE -ne 0) {
    Write-Host "INSTALL FAILED — aborting" -ForegroundColor Red
    return
}

Write-Host "`n=== Step 2: Verify task registration ===" -ForegroundColor Cyan
$task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
if ($task) {
    Write-Host "  TaskName: $($task.TaskName)" -ForegroundColor Green
    Write-Host "  State:    $($task.State)" -ForegroundColor Green
    Write-Host "  Action:   $($task.Actions[0].Execute) $($task.Actions[0].Arguments)" -ForegroundColor Gray
    Write-Host "  Trigger:  $($task.Triggers[0].StartBoundary) delay=$($task.Triggers[0].Delay)" -ForegroundColor Gray
} else {
    Write-Host "  Task NOT FOUND" -ForegroundColor Red
    return
}

if ($SkipTrigger) {
    Write-Host "`n=== Skipping trigger (-SkipTrigger) ===" -ForegroundColor Yellow
    Write-Host "  To test manually: Start-ScheduledTask -TaskName '$TaskName'" -ForegroundColor Gray
    return
}

Write-Host "`n=== Step 3: Trigger task manually ===" -ForegroundColor Cyan
Start-ScheduledTask -TaskName $TaskName
Write-Host "  Task triggered. Waiting 30s for Docker startup..." -ForegroundColor Yellow
Start-Sleep -Seconds 30

Write-Host "`n=== Step 4: Check healthcheck log ===" -ForegroundColor Cyan
if (Test-Path $LogFile) {
    Get-Content $LogFile -Tail 20
} else {
    Write-Host "  Log file not found: $LogFile" -ForegroundColor Yellow
    Write-Host "  Task may still be starting. Check again in 60s." -ForegroundColor Gray
}

Write-Host "`n=== Done ===" -ForegroundColor Green
