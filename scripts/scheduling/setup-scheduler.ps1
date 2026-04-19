<#
.SYNOPSIS
    Configure Windows Task Scheduler for Claude Code automated tasks.

.DESCRIPTION
    Creates, lists, or removes Windows Task Scheduler tasks for the 3x2
    scheduling architecture. Supports 3 task types:

    - worker:            Executor tier (6h, Haiku baseline, all machines)
    - coordinator:       Coordinator tier (8h, Sonnet baseline, ai-01 only)
    - meta-audit:        Meta-Analyst tier (72h, Sonnet baseline, all machines)
    - dashboard-watcher: Dashboard gate (1h, spawns Opus only on actionable messages, all machines).
                         Default mode: multi-workspace — 1 task sweeps ALL workspace
                         dashboards discovered under $ROOSYNC_SHARED_PATH/dashboards/.
                         Use -Workspace to pin to a single workspace (legacy).
                         Use -Workspaces "a,b" to restrict to an explicit list.

    ESCALATION MECHANISM (#1027):
    Each scheduler uses a cost-effective baseline model with targeted escalation:
    - Thread main runs on baseline (Haiku/Sonnet)
    - Complex phases trigger sub-agent escalation (Sonnet/Opus)
    - Retry after failure auto-escalates (Get-EscalatedModel in worker script)

.PARAMETER Action
    Action to perform: install, remove, list, test (default: list)

.PARAMETER TaskType
    Type of scheduled task: worker, coordinator, meta-audit, dashboard-watcher (default: worker)

.PARAMETER Workspace
    Single workspace key to watch (dashboard-watcher, legacy single-ws mode). Example: "nanoclaw".
    When provided, TaskName is suffixed with -{Workspace}.

.PARAMETER Workspaces
    Comma-separated list of workspace keys (dashboard-watcher, explicit multi-ws mode).
    Example: "nanoclaw,roo-extensions". When empty and -Workspace also empty, the watcher
    auto-discovers every workspace under $ROOSYNC_SHARED_PATH/dashboards/workspace-*.md.

.PARAMETER IntervalHours
    Hours between runs (default depends on TaskType: worker=3, coordinator=8, meta-audit=24)

.PARAMETER Mode
    Claude mode to use (default: code-simple, only for worker)

.PARAMETER Model
    Claude model override (default depends on TaskType: worker=haiku, others=sonnet)
    See issue #1027 for escalation mechanism details

.PARAMETER MaxIterations
    Max iterations per run (default: 1, only for worker)

.PARAMETER TimeoutMinutes
    Task Scheduler kill timeout in minutes (default: worker=15, coordinator=30, meta-audit=30)

.PARAMETER DryRun
    Show what would be done without making changes

.PARAMETER Stub
    Opt-in stub mode for dashboard-watcher (Phase 1 testing). Default is live mode (Phase 2).
    When set, prints the decision but does not invoke spawn-claude.ps1.

.EXAMPLE
    .\setup-scheduler.ps1                                          # List current worker task
    .\setup-scheduler.ps1 -Action list -TaskType coordinator       # List coordinator task
    .\setup-scheduler.ps1 -Action install                          # Install worker (6h, Haiku baseline)
    .\setup-scheduler.ps1 -Action install -TaskType coordinator    # Install coordinator (8h, Sonnet baseline, ai-01 only)
    .\setup-scheduler.ps1 -Action install -TaskType meta-audit     # Install meta-audit (72h, Sonnet baseline)
    .\setup-scheduler.ps1 -Action test -TaskType coordinator       # Test coordinator in DryRun
    .\setup-scheduler.ps1 -Action remove -TaskType coordinator     # Remove coordinator task
    .\setup-scheduler.ps1 -Action install -TaskType dashboard-watcher -Workspace nanoclaw  # Install NanoClaw-only watcher (legacy)
    .\setup-scheduler.ps1 -Action install -TaskType dashboard-watcher                      # Install unified watcher, auto-discovers every workspace (all machines)
    .\setup-scheduler.ps1 -Action install -TaskType dashboard-watcher -Workspaces "nanoclaw,roo-extensions"  # Explicit multi-ws list
    .\setup-scheduler.ps1 -Action install -TaskType dashboard-watcher -Stub                 # Install watcher in stub mode (Phase 1 testing)

.NOTES
    Per-machine workspace configuration for dashboard-watcher:

    Option A (default): Auto-discovery - polls every workspace under $ROOSYNC_SHARED_PATH/dashboards/
    Option B (recommended): Set $env:DASHBOARD_WATCHER_WORKSPACES in ~/.claude/settings.json to restrict to specific workspaces

    Example ~/.claude/settings.json:
    {
      "terminal.integrated.env.windows": {
        "DASHBOARD_WATCHER_WORKSPACES": "roo-extensions"
      }
    }

    Or use -Workspaces parameter to set explicitly during installation.
#>

param(
    [ValidateSet('install', 'remove', 'list', 'test')]
    [string]$Action = 'list',

    [ValidateSet('worker', 'coordinator', 'meta-audit', 'dashboard-watcher', 'health-check')]
    [string]$TaskType = 'worker',

    [double]$IntervalHours = 0,
    [string]$Mode = 'code-simple',
    [string]$Model = '',
    [int]$MaxIterations = 1,
    [int]$TimeoutMinutes = 0,
    [string]$Workspace = '',
    [string]$Workspaces = '',
    [switch]$Stub,  # Opt-in stub mode for dashboard-watcher (Phase 1 testing). Default is live mode.
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
        DefaultTimeout = 120
        Description = "Claude Code automated worker: picks up ALL dispatched GitHub issues (not just roo-schedulable), starts with Haiku with auto-escalation to Sonnet/Opus. Exits cleanly if no work. Runs every 6h."
        MachineRestriction = $null  # all machines
    }
    'coordinator' = @{
        TaskName = "Claude-Coordinator"
        Script = Join-Path $scriptDir "start-claude-coordinator.ps1"
        DefaultInterval = 8
        DefaultModel = "sonnet"
        DefaultTimeout = 120
        Description = "Claude Code scheduled coordinator: analyzes RooSync traffic, git activity, workload balance. Dispatches and rebalances. Runs on Sonnet with sub-agent escalation to Opus for PR reviews."
        MachineRestriction = "myia-ai-01"
    }
    'meta-audit' = @{
        TaskName = "Claude-MetaAudit"
        Script = Join-Path $scriptDir "start-meta-audit.ps1"
        DefaultInterval = 72
        DefaultModel = "sonnet"
        DefaultTimeout = 120
        Description = "Claude Code meta-analyst: analyzes local Roo+Claude traces, cross-analyzes harnesses, proposes improvements. Runs every 72h on Sonnet with sub-agent escalation to Opus for architectural recommendations."
        MachineRestriction = $null  # all machines
    }
    'dashboard-watcher' = @{
        TaskName = "Claude-DashboardWatcher"  # Suffix -{Workspace} added only in legacy single-ws mode
        Script = Join-Path $RepoRoot "scripts/dashboard-scheduler/poll-dashboard.ps1"
        DefaultInterval = 1  # 1h polls
        DefaultModel = "opus"  # model used by spawn-claude.ps1 on actionable trigger
        DefaultTimeout = 15  # poll is fast; 10min reserved for spawned claude -p
        Description = "Claude Code dashboard watcher (#1430): polls workspace dashboard(s), filters actionable tags (ASK/TASK/BLOCKED), spawns claude -p ONLY when actionable messages are found. Multi-workspace by default (auto-discovers all workspace-*.md under ROOSYNC_SHARED_PATH/dashboards/). Use -Workspace for legacy single-ws. Phase 2 live mode (spawns Opus on actionable). Use -Stub to opt into Phase 1 stub mode."
        MachineRestriction = $null  # all machines
    }
    'health-check' = @{
        TaskName = "Claude-HealthCheck"
        Script = Join-Path $RepoRoot "scripts/monitoring/check-embeddings.ps1"
        DefaultInterval = 0.5  # 30 minutes
        DefaultModel = "haiku"  # only used if claude -p is spawned for alert
        DefaultTimeout = 5
        Description = "Claude Code health check (#1499): monitors embeddings endpoint (embeddings.myia.io/v1), posts [CRITICAL] on workspace dashboard if down. Runs every 30 min."
        MachineRestriction = $null  # all machines
    }
}

$config = $TaskConfigs[$TaskType]
$TaskName = $config.TaskName
$WorkerScript = $config.Script

# Dashboard-watcher mode selection (#1430 multi-ws):
# - Legacy single-ws  : -Workspace nanoclaw        → TaskName "Claude-DashboardWatcher-nanoclaw"
# - Explicit multi-ws : -Workspaces "a,b"          → TaskName "Claude-DashboardWatcher"
# - Auto-discovery    : (neither param set)        → TaskName "Claude-DashboardWatcher"
if ($TaskType -eq 'dashboard-watcher') {
    if (-not [string]::IsNullOrEmpty($Workspace)) {
        if (-not [string]::IsNullOrEmpty($Workspaces)) {
            Write-Host "[ERROR] Pass either -Workspace (single) OR -Workspaces (multi), not both." -ForegroundColor Red
            exit 1
        }
        $TaskName = "$TaskName-$Workspace"
    }
}

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
                "-WindowStyle", "Hidden",
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
                "-WindowStyle", "Hidden",
                "-File", "`"$WorkerScript`"",
                "-Model", $Model
            )
        }
        'meta-audit' {
            $workerArgs = @(
                "-ExecutionPolicy", "Bypass",
                "-WindowStyle", "Hidden",
                "-File", "`"$WorkerScript`"",
                "-Model", $Model
            )
        }
        'dashboard-watcher' {
            # Phase 2: live mode by default (spawns claude -p on actionable).
            # Pass -Stub to opt into Phase 1 stub mode (0 token cost).
            $workerArgs = @(
                "-ExecutionPolicy", "Bypass",
                "-WindowStyle", "Hidden",
                "-File", "`"$WorkerScript`"",
                "-AllowedTags", "`"ASK,TASK,BLOCKED`""
            )
            # Pass -Stub flag if explicitly set
            if ($Stub) {
                $workerArgs += @("-Stub")
            } else {
                # Default to live mode (Phase 2)
                $workerArgs += @("-Stub:`$false")
            }
            if (-not [string]::IsNullOrEmpty($Workspace)) {
                $workerArgs += @("-Workspace", $Workspace)
            } elseif (-not [string]::IsNullOrEmpty($Workspaces)) {
                $workerArgs += @("-Workspaces", "`"$Workspaces`"")
            }
            # Otherwise: poll-dashboard.ps1 auto-discovers from $ROOSYNC_SHARED_PATH/dashboards
        }
        'health-check' {
            $workerArgs = @(
                "-ExecutionPolicy", "Bypass",
                "-WindowStyle", "Hidden",
                "-File", "`"$WorkerScript`""
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

        # Create trigger: repeat every N hours indefinitely (no expiration)
        # Start 5 minutes from now
        # NOTE: RepetitionDuration must be $null for indefinite repetition (Issue #967)
        $trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(5) `
            -RepetitionInterval (New-TimeSpan -Hours $IntervalHours)
        # Explicitly set indefinite duration and disable StopAtDurationEnd
        $trigger.Repetition.Duration = $null
        $trigger.Repetition.StopAtDurationEnd = $false

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
        Write-Status "  Check logs: outputs/scheduling/logs/ (or env CLAUDE_*_LOG_DIR)" DarkGray
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
        'dashboard-watcher' {
            $testArgs = @("-AllowedTags", "ASK,TASK,BLOCKED")
            # In test mode, always use stub mode for safety unless explicitly overridden
            $testArgs += @("-Stub")
            if (-not [string]::IsNullOrEmpty($Workspace)) {
                $testArgs += @("-Workspace", $Workspace)
                Write-Status "  Running: $WorkerScript -Workspace $Workspace -AllowedTags 'ASK,TASK,BLOCKED' -Stub (test mode)"
            } elseif (-not [string]::IsNullOrEmpty($Workspaces)) {
                $testArgs += @("-Workspaces", $Workspaces)
                Write-Status "  Running: $WorkerScript -Workspaces '$Workspaces' -AllowedTags 'ASK,TASK,BLOCKED' -Stub (test mode)"
            } else {
                Write-Status "  Running: $WorkerScript -AllowedTags 'ASK,TASK,BLOCKED' -Stub (auto-discover, test mode)"
            }
            Write-Status ""
            & powershell -ExecutionPolicy Bypass -File $WorkerScript @testArgs
        }
        'health-check' {
            Write-Status "  Running: $WorkerScript -DryRun"
            Write-Status ""
            & powershell -ExecutionPolicy Bypass -File $WorkerScript -DryRun
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
