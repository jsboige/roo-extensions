<#
.SYNOPSIS
    Install/remove/list/test a Windows scheduled task for Copilot dispatcher bridge.

.DESCRIPTION
    Creates task `Copilot-Dispatcher` that runs every N hours and executes
    a lightweight bridge script. This is a transition scheduler (Phase B):
    claim/dispatch traceability, not full headless Copilot code execution.

.PARAMETER Action
    install | remove | list | test

.PARAMETER IntervalHours
    Repetition interval in hours (default: 3)

.PARAMETER TimeoutMinutes
    Task runtime timeout (default: 10)

.PARAMETER BudgetProfile
    Escalation policy profile: low | balanced | throughput.

.PARAMETER MaxConsecutiveBlocked
    Escalate when blocked status repeats this many times.

.PARAMETER MaxConsecutiveIdle
    Escalate for cadence review when idle repeats this many times.

.PARAMETER DryRun
    Preview only.
#>

[CmdletBinding()]
param(
    [ValidateSet('install','remove','list','test')]
    [string]$Action = 'list',
    [int]$IntervalHours = 3,
    [int]$TimeoutMinutes = 10,
    [ValidateSet('low','balanced','throughput')]
    [string]$BudgetProfile = 'balanced',
    [int]$MaxConsecutiveBlocked = 2,
    [int]$MaxConsecutiveIdle = 4,
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = (Split-Path (Split-Path $scriptDir -Parent) -Parent)
$taskName = "Copilot-Dispatcher"
$workerScript = Join-Path $scriptDir "start-copilot-dispatcher.ps1"

function Show-Task {
    $t = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
    if (-not $t) {
        Write-Host "[--] $taskName not installed" -ForegroundColor DarkGray
        return
    }
    Write-Host "[OK] $taskName" -ForegroundColor Green
    Write-Host "State: $($t.State)"
    Write-Host "Description: $($t.Description)"
}

function Install-Task {
    if ($DryRun) {
        Write-Host "[DRY-RUN] Would install $taskName" -ForegroundColor Yellow
        return
    }

    $existing = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
    if ($existing) { Unregister-ScheduledTask -TaskName $taskName -Confirm:$false }

    $taskCli = "-ExecutionPolicy Bypass -File `"$workerScript`" -BudgetProfile $BudgetProfile -MaxConsecutiveBlocked $MaxConsecutiveBlocked -MaxConsecutiveIdle $MaxConsecutiveIdle"
    $trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(5) `
        -RepetitionInterval (New-TimeSpan -Hours $IntervalHours) `
        -RepetitionDuration (New-TimeSpan -Days 365)

    $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument $taskCli -WorkingDirectory $repoRoot
    $settings = New-ScheduledTaskSettingsSet `
        -AllowStartIfOnBatteries `
        -DontStopIfGoingOnBatteries `
        -ExecutionTimeLimit (New-TimeSpan -Minutes $TimeoutMinutes) `
        -StartWhenAvailable `
        -MultipleInstances IgnoreNew

    Register-ScheduledTask -TaskName $taskName `
        -Description "Copilot dispatcher bridge (roo-state-manager V3 transition)." `
        -Trigger $trigger -Action $action -Settings $settings -RunLevel Limited | Out-Null

    Write-Host "[OK] Installed $taskName" -ForegroundColor Green
}

function Remove-Task {
    if ($DryRun) {
        Write-Host "[DRY-RUN] Would remove $taskName" -ForegroundColor Yellow
        return
    }
    $existing = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
    if ($existing) {
        Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
        Write-Host "[OK] Removed $taskName" -ForegroundColor Green
    } else {
        Write-Host "[--] $taskName not found" -ForegroundColor DarkGray
    }
}

function Test-Task {
    Write-Host "Running dispatcher in dry-run mode..." -ForegroundColor Cyan
    & powershell -ExecutionPolicy Bypass -File $workerScript -BudgetProfile $BudgetProfile -MaxConsecutiveBlocked $MaxConsecutiveBlocked -MaxConsecutiveIdle $MaxConsecutiveIdle -DryRun
}

switch ($Action) {
    'list' { Show-Task }
    'install' { Install-Task }
    'remove' { Remove-Task }
    'test' { Test-Task }
}
