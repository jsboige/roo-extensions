# Install SDDD Eval Harness Scheduled Task (#2609 V1 cadence)
# FAMILY: F-installeur — registers Roo-Eval-Harness-2609 (daily 03:37, current user,
# unelevated, StartWhenAvailable) which runs run-eval-harness.ps1 against the MAIN
# checkout: vitest eval-harness (real Qdrant/PG) + dashboard verdict post (claude -p haiku).
#
# No elevation required: the task runs as the registering user with an interactive
# token (user-level task, no UAC window consumed — cf. limited-user-task memory).
# The minute is deliberately off-:00 (jitter) and avoids the 02:00 worktree-cleanup
# and 03:00 Sunday MCP-Worktree-Cleanup windows.
#
# Issue: #2609 (Epic V1). Author: Claude Code (myia-ai-01)

param(
    # Wrapper the task invokes. Default: sibling of this installer. Override to point at
    # the MAIN checkout copy when installing from a worktree BEFORE the PR merges — the
    # task outlives worktrees, its target must too (until merge the wrapper's guards
    # exit 2 with a clear message; post-merge + pull it goes live).
    [string]$WrapperPath = (Join-Path $PSScriptRoot 'run-eval-harness.ps1'),
    [switch]$Remove,
    [switch]$WhatIf
)

$ErrorActionPreference = 'Stop'

$TaskName = 'Roo-Eval-Harness-2609'
$ScriptPath = $WrapperPath

function Write-Info { param($msg) Write-Host "[INFO] $msg" -ForegroundColor Cyan }
function Write-Success { param($msg) Write-Host "[OK] $msg" -ForegroundColor Green }
function Write-Warn { param($msg) Write-Host "[WARN] $msg" -ForegroundColor Yellow }

if (-not (Test-Path $ScriptPath)) {
    if ($PSBoundParameters.ContainsKey('WrapperPath')) {
        Write-Warn "Wrapper not found yet: $ScriptPath (explicit override — registering anyway; guards exit 2 until the file lands post-merge)"
    }
    else {
        Write-Host "[ERROR] Wrapper not found: $ScriptPath"
        exit 1
    }
}

if ($Remove) {
    if ($WhatIf) {
        Write-Info "[WHATIF] Would remove task: $TaskName (Unregister-ScheduledTask -Confirm:`$false)"
        exit 0
    }
    try {
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction Stop
        Write-Success "Scheduled task removed: $TaskName"
    }
    catch {
        Write-Warn "Task may not exist: $_"
    }
    exit 0
}

$taskArgs = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$ScriptPath`""

Write-Host ''
Write-Host '=== Install Eval Harness Scheduled Task (#2609 V1) ===' -ForegroundColor White
Write-Info "Task      : $TaskName"
Write-Info "Schedule  : Daily 03:37 (StartWhenAvailable)"
Write-Info "Command   : powershell.exe $taskArgs"
Write-Host ''

if ($WhatIf) {
    Write-Info '[WHATIF] Would run:'
    Write-Info "  New-ScheduledTaskAction -Execute 'powershell.exe' -Argument '$taskArgs'"
    Write-Info '  New-ScheduledTaskTrigger -Daily -At 03:37'
    Write-Info "  Register-ScheduledTask -TaskName $TaskName (current user, unelevated)"
    exit 0
}

try {
    $action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument $taskArgs
    $trigger = New-ScheduledTaskTrigger -Daily -At '03:37'
    $settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Hours 1) -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
    Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Settings $settings -Description 'Epic #2609 V1: daily SDDD eval-harness run (real Qdrant/PG) + dashboard verdict post' -ErrorAction Stop | Out-Null
    Write-Success "Scheduled task registered: $TaskName (daily 03:37, current user, unelevated)"
    Write-Info "Manual fire: Start-ScheduledTask -TaskName $TaskName"
    Write-Info "Logs       : %TEMP%\eval-harness-2609\run-*.log"
}
catch {
    Write-Host "[ERROR] Registration failed: $_"
    exit 1
}
