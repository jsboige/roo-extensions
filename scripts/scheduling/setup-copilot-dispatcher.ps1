<#
.SYNOPSIS
    Install/remove/list/test a Windows scheduled task for Copilot dispatcher worker.

.DESCRIPTION
    Creates task `Copilot-Dispatcher` that runs every N hours and executes
    the Copilot dispatcher worker. The default mode writes logs and local
    work reports without posting routine GitHub issue comments.

.PARAMETER Action
    install | remove | list | test

.PARAMETER IntervalHours
    Repetition interval in hours (default: 3)

.PARAMETER TimeoutMinutes
    Task runtime timeout (default: 10)

.PARAMETER BudgetProfile
    Escalation policy profile: low | balanced | throughput.

.PARAMETER IssueNumber
    Optional legacy GitHub issue number. Default 0 disables issue-comment notifications.

.PARAMETER PremiumUsagePercent
    Optional premium usage percentage override (0..100).

.PARAMETER SoftUsageCapPercent
    Soft cap above which effective profile is downgraded.

.PARAMETER HardUsageCapPercent
    Hard cap above which profile is forced to low.

.PARAMETER MaxConsecutiveBlocked
    Escalate when blocked status repeats this many times.

.PARAMETER MaxConsecutiveIdle
    Escalate for cadence review when idle repeats this many times.

.PARAMETER MinEscalationIntervalMinutes
    Cooldown between two escalation events.

.PARAMETER MaxEscalationsPerDay
    Max escalation events allowed in a rolling 24h window.

.PARAMETER TargetRepoSlug
    owner/name of the repo the dispatcher works on (issue pool + delivery).
    Required together with -TargetRepoPath: without the pair the worker runs
    in local mode, which fail-closes with zero Copilot calls (#4669) — a
    task registered that way could never deliver, so install refuses.

.PARAMETER TargetRepoPath
    Local clone of the target repo. Work happens in a throwaway worktree of
    it, never in its main checkout.

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
    [int]$IssueNumber = 0,
    [double]$PremiumUsagePercent = -1,
    [double]$SoftUsageCapPercent = 70,
    [double]$HardUsageCapPercent = 90,
    [int]$MaxConsecutiveBlocked = 2,
    [int]$MaxConsecutiveIdle = 4,
    [int]$MinEscalationIntervalMinutes = 180,
    [int]$MaxEscalationsPerDay = 3,
    [string]$TargetRepoSlug = '',
    [string]$TargetRepoPath = '',
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
    # #4669: the task command line must carry the retarget pair or the
    # registered worker runs in local mode — no delivery geometry, the worker
    # fail-closes with zero Copilot calls and a blocked streak. Refuse rather
    # than register a task that could never deliver a PR. Each refusal is
    # ALSO printed as a plain line: the pwsh error-record renderer wraps
    # throw text across lines with pipe prefixes and ANSI codes, which
    # scrambles the message for scripts and humans grepping logs.
    $slugGiven = -not [string]::IsNullOrWhiteSpace($TargetRepoSlug)
    $pathGiven = -not [string]::IsNullOrWhiteSpace($TargetRepoPath)
    if ($slugGiven -xor $pathGiven) {
        $refusal = "install refused: -TargetRepoSlug and -TargetRepoPath must be given TOGETHER - half a retarget cannot deliver (worker fail-closes on local mode, #4669)"
        Write-Host "[REFUSED] $refusal" -ForegroundColor Red
        throw $refusal
    }
    if (-not $slugGiven) {
        $refusal = "install refused: no delivery geometry - pass -TargetRepoSlug <owner/repo> and -TargetRepoPath <local clone>; without the pair the worker skips every Copilot call (local mode, #4669)"
        Write-Host "[REFUSED] $refusal" -ForegroundColor Red
        throw $refusal
    }
    if (-not (Test-Path $TargetRepoPath)) {
        $refusal = "install refused: -TargetRepoPath '$TargetRepoPath' does not exist - the worker needs the target repo's local clone"
        Write-Host "[REFUSED] $refusal" -ForegroundColor Red
        throw $refusal
    }

    # A trailing \ or / would escape the closing quote in the interpolated
    # command line below and mangle the task's argument parsing.
    $targetPathNorm = $TargetRepoPath.TrimEnd('\', '/')
    $taskCli = "-ExecutionPolicy Bypass -File `"$workerScript`" -BudgetProfile $BudgetProfile -IssueNumber $IssueNumber -PremiumUsagePercent $PremiumUsagePercent -SoftUsageCapPercent $SoftUsageCapPercent -HardUsageCapPercent $HardUsageCapPercent -MaxConsecutiveBlocked $MaxConsecutiveBlocked -MaxConsecutiveIdle $MaxConsecutiveIdle -MinEscalationIntervalMinutes $MinEscalationIntervalMinutes -MaxEscalationsPerDay $MaxEscalationsPerDay -TargetRepoSlug $TargetRepoSlug -TargetRepoPath `"$targetPathNorm`""

    # #4669: the task's Execute must be an ABSOLUTE path resolved at
    # INSTALL time. The Task Scheduler fires the tir with a minimal
    # environment that does not guarantee the installer's PATH: a bare
    # "pwsh.exe" registers without complaint, then fails at fire time with
    # 0x80070002 (file not found) while every manual replay works. Resolve
    # the full source path now; the fallback is the canonical Windows
    # PowerShell 5.1 location (the worker is 5.1/7-portable). pwsh
    # preferred: ConvertFrom-Json hashtable support and modern syntax.
    $psCommand = Get-Command pwsh.exe -ErrorAction SilentlyContinue
    $psExe = if ($psCommand) { $psCommand.Source } else { Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe' }

    if ($DryRun) {
        Write-Host "[DRY-RUN] Would install $taskName" -ForegroundColor Yellow
        Write-Host "[DRY-RUN] Execute: $psExe"
        Write-Host "[DRY-RUN] Task args: $taskCli"
        return
    }

    $existing = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
    if ($existing) { Unregister-ScheduledTask -TaskName $taskName -Confirm:$false }
    $trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(5) `
        -RepetitionInterval (New-TimeSpan -Hours $IntervalHours) `
        -RepetitionDuration (New-TimeSpan -Days 365)

    $action = New-ScheduledTaskAction -Execute $psExe -Argument $taskCli -WorkingDirectory $repoRoot
    $settings = New-ScheduledTaskSettingsSet `
        -AllowStartIfOnBatteries `
        -DontStopIfGoingOnBatteries `
        -ExecutionTimeLimit (New-TimeSpan -Minutes $TimeoutMinutes) `
        -StartWhenAvailable `
        -MultipleInstances IgnoreNew

    Register-ScheduledTask -TaskName $taskName `
        -Description "Copilot dispatcher worker (silent issue channel, local reports)." `
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
    $psExe = if (Get-Command pwsh -ErrorAction SilentlyContinue) { "pwsh" } else { "powershell" }
    # #4669: forward the retarget pair so the dry-run exercises the same
    # geometry the scheduled task would run (a dry-run of local mode proves
    # nothing about delivery).
    $retargetArgs = @()
    if (-not [string]::IsNullOrWhiteSpace($TargetRepoSlug) -and -not [string]::IsNullOrWhiteSpace($TargetRepoPath)) {
        $retargetArgs = @('-TargetRepoSlug', $TargetRepoSlug, '-TargetRepoPath', $TargetRepoPath)
    }
    & $psExe -ExecutionPolicy Bypass -File $workerScript -BudgetProfile $BudgetProfile -IssueNumber $IssueNumber -PremiumUsagePercent $PremiumUsagePercent -SoftUsageCapPercent $SoftUsageCapPercent -HardUsageCapPercent $HardUsageCapPercent -MaxConsecutiveBlocked $MaxConsecutiveBlocked -MaxConsecutiveIdle $MaxConsecutiveIdle -MinEscalationIntervalMinutes $MinEscalationIntervalMinutes -MaxEscalationsPerDay $MaxEscalationsPerDay @retargetArgs -DryRun
}

switch ($Action) {
    'list' { Show-Task }
    'install' { Install-Task }
    'remove' { Remove-Task }
    'test' { Test-Task }
}
