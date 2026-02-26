<#
.SYNOPSIS
    Configure Windows Task Scheduler for Claude Code automated worker.

.DESCRIPTION
    Creates, lists, or removes a Windows Task Scheduler task that runs
    start-claude-worker.ps1 periodically. The worker automatically:
    - Checks RooSync inbox for assigned tasks
    - Checks GitHub for roo-schedulable issues
    - Runs Claude Haiku (cheap) with auto-escalation to Sonnet/Opus
    - Exits cleanly if no work is available (-NoFallback)

.PARAMETER Action
    Action to perform: install, remove, list, test (default: list)

.PARAMETER IntervalHours
    Hours between runs (default: 3)

.PARAMETER Mode
    Claude mode to use (default: code-simple)

.PARAMETER Model
    Claude model override (default: haiku)

.PARAMETER MaxIterations
    Max iterations per run (default: 1)

.PARAMETER TimeoutMinutes
    Task Scheduler kill timeout in minutes (default: 15)

.PARAMETER DryRun
    Show what would be done without making changes

.EXAMPLE
    .\setup-scheduler.ps1                              # List current task
    .\setup-scheduler.ps1 -Action install              # Install with defaults (3h, Haiku)
    .\setup-scheduler.ps1 -Action install -DryRun      # Preview install
    .\setup-scheduler.ps1 -Action install -IntervalHours 6  # Conservative 6h interval
    .\setup-scheduler.ps1 -Action test                 # Run worker in DryRun mode
    .\setup-scheduler.ps1 -Action remove               # Remove scheduled task
#>

param(
    [ValidateSet('install', 'remove', 'list', 'test')]
    [string]$Action = 'list',

    [int]$IntervalHours = 3,
    [string]$Mode = 'code-simple',
    [string]$Model = 'haiku',
    [int]$MaxIterations = 1,
    [int]$TimeoutMinutes = 15,
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

# --- Config ---
$scriptDir = Split-Path $MyInvocation.MyCommand.Path -Parent
$RepoRoot = (Split-Path (Split-Path $scriptDir -Parent) -Parent)
$machineName = ($env:COMPUTERNAME).ToLower()
$TaskName = "Claude-Worker"
$WorkerScript = Join-Path $scriptDir "start-claude-worker.ps1"

function Write-Status($msg, $color = 'White') {
    Write-Host $msg -ForegroundColor $color
}

# --- Action: List ---
function Show-Task {
    Write-Status "=== Claude Code Scheduled Task ===" Cyan
    Write-Status "Machine: $machineName"
    Write-Status "RepoRoot: $RepoRoot"
    Write-Status ""

    try {
        $existing = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
        if ($existing) {
            $trigger = $existing.Triggers | Select-Object -First 1
            $state = $existing.State
            $actionObj = $existing.Actions | Select-Object -First 1
            Write-Status "  [OK] $TaskName" Green
            Write-Status "       State: $state"
            Write-Status "       Description: $($existing.Description)"
            if ($trigger -and $trigger.Repetition) {
                Write-Status "       Interval: $($trigger.Repetition.Interval)"
            }
            if ($actionObj) {
                Write-Status "       Execute: $($actionObj.Execute)"
                Write-Status "       Arguments: $($actionObj.Arguments)"
                Write-Status "       WorkingDir: $($actionObj.WorkingDirectory)"
            }
        } else {
            Write-Status "  [--] $TaskName (not installed)" DarkGray
        }
    } catch {
        Write-Status "  [??] $TaskName (error: $_)" Yellow
    }

    Write-Status ""
    Write-Status "Use -Action install to create task." DarkGray
}

# --- Action: Install ---
function Install-Task {
    Write-Status "=== Installing Scheduled Task ===" Cyan
    Write-Status "Machine: $machineName"
    Write-Status "Interval: every ${IntervalHours}h"
    Write-Status "Mode: $Mode | Model: $Model | MaxIterations: $MaxIterations"
    Write-Status "Timeout: ${TimeoutMinutes}min"
    Write-Status ""

    # Build arguments for start-claude-worker.ps1
    $workerArgs = @(
        "-ExecutionPolicy", "Bypass",
        "-File", "`"$WorkerScript`"",
        "-Mode", $Mode,
        "-Model", $Model,
        "-MaxIterations", $MaxIterations,
        "-NoFallback"
    )
    $arguments = $workerArgs -join " "

    Write-Status "  Task: $TaskName" Yellow
    Write-Status "    Worker: $WorkerScript"
    Write-Status "    Args: $arguments"

    if ($DryRun) {
        Write-Status "    [DRY RUN] Would create task with above settings" DarkGray
        Write-Status ""
        Write-Status "  Full command that would be scheduled:" DarkGray
        Write-Status "    powershell.exe $arguments" DarkGray
        return
    }

    try {
        # Remove existing task if present
        $existing = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
        if ($existing) {
            Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
            Write-Status "    Removed existing task." DarkGray
        }

        # Create trigger: repeat every N hours for 1 year (re-run setup yearly)
        # Start 5 minutes from now
        $trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(5) `
            -RepetitionInterval (New-TimeSpan -Hours $IntervalHours) `
            -RepetitionDuration (New-TimeSpan -Days 365)

        # Create action
        $taskAction = New-ScheduledTaskAction `
            -Execute "powershell.exe" `
            -Argument $arguments `
            -WorkingDirectory $RepoRoot

        # Settings: allow on battery, kill after timeout, skip if already running
        $settings = New-ScheduledTaskSettingsSet `
            -AllowStartIfOnBatteries `
            -DontStopIfGoingOnBatteries `
            -ExecutionTimeLimit (New-TimeSpan -Minutes $TimeoutMinutes) `
            -StartWhenAvailable `
            -MultipleInstances IgnoreNew

        # Register (as current user, no elevated privileges needed)
        $description = "Claude Code automated worker: picks up roo-schedulable GitHub issues, runs Haiku with auto-escalation, exits cleanly if no work. Interval: ${IntervalHours}h ($machineName)"

        Register-ScheduledTask `
            -TaskName $TaskName `
            -Description $description `
            -Trigger $trigger `
            -Action $taskAction `
            -Settings $settings `
            -RunLevel Limited | Out-Null

        Write-Status "    [OK] Task '$TaskName' created successfully" Green
        Write-Status ""
        Write-Status "  First run in ~5 minutes. Then every ${IntervalHours}h." Cyan
        Write-Status "  Check logs: .claude/logs/worker-*.log" DarkGray
        Write-Status "  Remove with: .\setup-scheduler.ps1 -Action remove" DarkGray
    } catch {
        Write-Status "    [FAIL] Error: $_" Red
        Write-Status "    TIP: Run as Administrator if access denied." Yellow
    }
}

# --- Action: Remove ---
function Remove-Task {
    Write-Status "=== Removing Scheduled Task ===" Cyan

    if ($DryRun) {
        Write-Status "  [DRY RUN] Would remove $TaskName" DarkGray
        return
    }

    try {
        $existing = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
        if ($existing) {
            Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
            Write-Status "  [OK] Removed $TaskName" Green
        } else {
            Write-Status "  [--] $TaskName not found (nothing to remove)" DarkGray
        }
    } catch {
        Write-Status "  [FAIL] Error removing: $_" Red
    }
}

# --- Action: Test ---
function Test-Task {
    Write-Status "=== Testing Worker (DryRun) ===" Cyan
    Write-Status "  Running: $WorkerScript -Mode $Mode -Model $Model -MaxIterations $MaxIterations -NoFallback -DryRun"
    Write-Status ""

    & powershell -ExecutionPolicy Bypass -File $WorkerScript `
        -Mode $Mode -Model $Model -MaxIterations $MaxIterations -NoFallback -DryRun
}

# --- Main ---
switch ($Action) {
    'list'    { Show-Task }
    'install' { Install-Task }
    'remove'  { Remove-Task }
    'test'    { Test-Task }
}
