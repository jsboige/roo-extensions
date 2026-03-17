<#
.SYNOPSIS
    Configure Windows Task Scheduler for Claude Code automated tasks.

.DESCRIPTION
    Creates, lists, or removes Windows Task Scheduler tasks for the 3x2
    scheduling architecture. Supports 3 task types:

    - worker:      Executor tier (6h, Sonnet, all machines)
    - coordinator: Coordinator tier (8h, Opus, ai-01 only)
    - meta-audit:  Meta-Analyst tier (72h, Opus, all machines)

.PARAMETER Action
    Action to perform: install, remove, list, test (default: list)

.PARAMETER TaskType
    Type of scheduled task: worker, coordinator, meta-audit (default: worker)

.PARAMETER IntervalHours
    Hours between runs (default depends on TaskType: worker=3, coordinator=8, meta-audit=24)

.PARAMETER Mode
    Claude mode to use (default: code-simple, only for worker)

.PARAMETER Model
    Claude model override (default depends on TaskType: worker=sonnet, others=opus)

.PARAMETER MaxIterations
    Max iterations per run (default: 1, only for worker)

.PARAMETER TimeoutMinutes
    Task Scheduler kill timeout in minutes (default: worker=15, coordinator=30, meta-audit=30)

.PARAMETER DryRun
    Show what would be done without making changes

.EXAMPLE
    .\setup-scheduler.ps1                                          # List current worker task
    .\setup-scheduler.ps1 -Action list -TaskType coordinator       # List coordinator task
    .\setup-scheduler.ps1 -Action install                          # Install worker (3h, Sonnet)
    .\setup-scheduler.ps1 -Action install -TaskType coordinator    # Install coordinator (8h, Opus, ai-01 only)
    .\setup-scheduler.ps1 -Action install -TaskType meta-audit     # Install meta-audit (24h, Opus)
    .\setup-scheduler.ps1 -Action test -TaskType coordinator       # Test coordinator in DryRun
    .\setup-scheduler.ps1 -Action remove -TaskType coordinator     # Remove coordinator task
#>

param(
    [ValidateSet('install', 'remove', 'list', 'test')]
    [string]$Action = 'list',

    [ValidateSet('worker', 'coordinator', 'meta-audit')]
    [string]$TaskType = 'worker',

    [int]$IntervalHours = 0,
    [string]$Mode = 'code-simple',
    [string]$Model = '',
    [int]$MaxIterations = 1,
    [int]$TimeoutMinutes = 0,
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

# --- Config ---
$scriptDir = Split-Path $MyInvocation.MyCommand.Path -Parent
$RepoRoot = (Split-Path (Split-Path $scriptDir -Parent) -Parent)
$machineName = ($env:COMPUTERNAME).ToLower()

# --- Guard: Detect worktree installation (Issue #731) ---
# Installing from a worktree hardcodes a temporary path into schtasks.
# When the worktree is deleted, the scheduled task silently fails.
if ($scriptDir -match '[/\\]\.claude[/\\]worktrees[/\\]') {
    Write-Error @"
ERROR: setup-scheduler.ps1 is being run from inside a worktree:
  $scriptDir

This will hardcode the worktree path into the scheduled task.
When the worktree is deleted, the task will silently fail (see issue #731).

SOLUTION: Run this script from the main repository:
  cd D:\dev\roo-extensions\scripts\scheduling
  .\setup-scheduler.ps1 -Action install

Aborting.
"@
    exit 1
}

# --- Task Type Defaults ---
$TaskConfigs = @{
    'worker' = @{
        TaskName = "Claude-Worker"
        Script = Join-Path $scriptDir "start-claude-worker.ps1"
        DefaultInterval = 6
        DefaultModel = "haiku"
        DefaultTimeout = 15
        Description = "Claude Code automated worker: picks up roo-schedulable GitHub issues, starts with Haiku (cheapest) with auto-escalation to Sonnet then Opus. Exits cleanly if no work. Runs every 6h."
        MachineRestriction = $null  # all machines
    }
    'coordinator' = @{
        TaskName = "Claude-Coordinator"
        Script = Join-Path $scriptDir "start-claude-coordinator.ps1"
        DefaultInterval = 8
        DefaultModel = "opus"
        DefaultTimeout = 30
        Description = "Claude Code scheduled coordinator: analyzes RooSync traffic, git activity, workload balance. Dispatches and rebalances."
        MachineRestriction = "myia-ai-01"
    }
    'meta-audit' = @{
        TaskName = "Claude-MetaAudit"
        Script = Join-Path $scriptDir "start-meta-audit.ps1"
        DefaultInterval = 72
        DefaultModel = "opus"
        DefaultTimeout = 30
        Description = "Claude Code meta-analyst: analyzes local Roo+Claude traces, cross-analyzes harnesses, proposes improvements. Runs every 72h."
        MachineRestriction = $null  # all machines
    }
}

$config = $TaskConfigs[$TaskType]
$TaskName = $config.TaskName
$WorkerScript = $config.Script

# Apply defaults if not explicitly set
if ($IntervalHours -eq 0) { $IntervalHours = $config.DefaultInterval }
if ($Model -eq '') { $Model = $config.DefaultModel }
if ($TimeoutMinutes -eq 0) { $TimeoutMinutes = $config.DefaultTimeout }

# Check machine restriction
if ($config.MachineRestriction -and $machineName -ne $config.MachineRestriction) {
    Write-Host "[ERROR] Task type '$TaskType' can only run on $($config.MachineRestriction) (current: $machineName)" -ForegroundColor Red
    exit 1
}

function Write-Status($msg, $color = 'White') {
    Write-Host $msg -ForegroundColor $color
}

# --- Action: List ---
function Show-Task {
    Write-Status "=== Claude Code Scheduled Task ($TaskType) ===" Cyan
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
    Write-Status "Use -Action install -TaskType $TaskType to create task." DarkGray
}

# --- Action: Install ---
function Install-Task {
    Write-Status "=== Installing Scheduled Task ($TaskType) ===" Cyan
    Write-Status "Machine: $machineName"
    Write-Status "Interval: every ${IntervalHours}h"
    Write-Status "Model: $Model"
    Write-Status "Timeout: ${TimeoutMinutes}min"
    Write-Status ""

    # Build arguments depending on task type
    switch ($TaskType) {
        'worker' {
            $workerArgs = @(
                "-ExecutionPolicy", "Bypass",
                "-File", "`"$WorkerScript`"",
                "-Mode", $Mode,
                "-Model", $Model,
                "-MaxIterations", $MaxIterations,
                "-NoFallback"
            )
        }
        'coordinator' {
            $workerArgs = @(
                "-ExecutionPolicy", "Bypass",
                "-File", "`"$WorkerScript`"",
                "-Model", $Model
            )
        }
        'meta-audit' {
            $workerArgs = @(
                "-ExecutionPolicy", "Bypass",
                "-File", "`"$WorkerScript`"",
                "-Model", $Model
            )
        }
    }
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
        $description = "$($config.Description) Interval: ${IntervalHours}h ($machineName)"

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
        Write-Status "  Check logs: .claude/logs/" DarkGray
        Write-Status "  Remove with: .\setup-scheduler.ps1 -Action remove -TaskType $TaskType" DarkGray
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
    Write-Status "=== Testing $TaskType (DryRun) ===" Cyan

    switch ($TaskType) {
        'worker' {
            Write-Status "  Running: $WorkerScript -Mode $Mode -Model $Model -MaxIterations $MaxIterations -NoFallback -DryRun"
            Write-Status ""
            & powershell -ExecutionPolicy Bypass -File $WorkerScript `
                -Mode $Mode -Model $Model -MaxIterations $MaxIterations -NoFallback -DryRun
        }
        'coordinator' {
            Write-Status "  Running: $WorkerScript -Model $Model -DryRun"
            Write-Status ""
            & powershell -ExecutionPolicy Bypass -File $WorkerScript -Model $Model -DryRun
        }
        'meta-audit' {
            Write-Status "  Running: $WorkerScript -Model $Model -DryRun"
            Write-Status ""
            & powershell -ExecutionPolicy Bypass -File $WorkerScript -Model $Model -DryRun
        }
    }
}

# --- Main ---
switch ($Action) {
    'list'    { Show-Task }
    'install' { Install-Task }
    'remove'  { Remove-Task }
    'test'    { Test-Task }
}
