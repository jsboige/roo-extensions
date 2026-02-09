<#
.SYNOPSIS
    Configure Windows Task Scheduler for Claude Code automated tasks.

.DESCRIPTION
    Creates, lists, or removes Windows Task Scheduler tasks for Claude Code:
    - Claude-PrepareIntercom: Write prioritized tasks to INTERCOM for Roo
    - Claude-AnalyzeRoo: Analyze Roo's latest work and provide feedback
    - Claude-SyncTour: Full synchronization tour (sync-tour-scheduled.ps1)

    Each task calls start-claude-worker.ps1 with appropriate parameters.

.PARAMETER Action
    Action to perform: install, remove, list, test (default: list)

.PARAMETER Tasks
    Which tasks to install/remove: all, prepare-intercom, analyze-roo, sync-tour
    Default: all

.PARAMETER IntervalHours
    Hours between runs for periodic tasks (default: 4)

.PARAMETER MaxMinutes
    Max runtime per task in minutes (default: 10 for intercom/analyze, 20 for sync)

.PARAMETER SkipPermissions
    Use --dangerously-skip-permissions for Claude (default: false)

.PARAMETER DryRun
    Show what would be done without making changes

.EXAMPLE
    .\setup-scheduler.ps1                          # List current tasks
    .\setup-scheduler.ps1 -Action install          # Install all tasks
    .\setup-scheduler.ps1 -Action install -Tasks prepare-intercom -DryRun
    .\setup-scheduler.ps1 -Action remove -Tasks all
    .\setup-scheduler.ps1 -Action test -Tasks prepare-intercom
#>

param(
    [ValidateSet('install', 'remove', 'list', 'test')]
    [string]$Action = 'list',

    [ValidateSet('all', 'prepare-intercom', 'analyze-roo', 'sync-tour')]
    [string]$Tasks = 'all',

    [int]$IntervalHours = 4,
    [int]$MaxMinutes = 0,
    [switch]$SkipPermissions,
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

# --- Config ---
$scriptDir = Split-Path $MyInvocation.MyCommand.Path -Parent
$RepoRoot = (Split-Path (Split-Path $scriptDir -Parent) -Parent)
$machineName = ($env:COMPUTERNAME).ToLower()

# Task definitions
$taskDefs = @{
    'prepare-intercom' = @{
        Name        = 'Claude-PrepareIntercom'
        Description = "Claude Code: Write prioritized tasks to INTERCOM for Roo ($machineName)"
        Task        = 'prepare-intercom'
        MaxMinutes  = 10
        Interval    = $IntervalHours
    }
    'analyze-roo' = @{
        Name        = 'Claude-AnalyzeRoo'
        Description = "Claude Code: Analyze Roo's latest work and provide feedback ($machineName)"
        Task        = 'analyze-roo'
        MaxMinutes  = 10
        Interval    = $IntervalHours
    }
    'sync-tour' = @{
        Name        = 'Claude-SyncTour'
        Description = "Claude Code: Full sync tour with smart skip ($machineName)"
        Task        = 'sync-tour'
        MaxMinutes  = 20
        Interval    = $IntervalHours
        UseWrapper  = $true  # Uses sync-tour-scheduled.ps1 instead of start-claude-worker.ps1
    }
}

# Resolve task list
$selectedTasks = if ($Tasks -eq 'all') {
    @('prepare-intercom', 'analyze-roo', 'sync-tour')
} else {
    @($Tasks)
}

function Write-Status($msg, $color = 'White') {
    Write-Host $msg -ForegroundColor $color
}

# --- Action: List ---
function Show-Tasks {
    Write-Status "=== Claude Code Scheduled Tasks ===" Cyan
    Write-Status "Machine: $machineName"
    Write-Status ""

    foreach ($key in $taskDefs.Keys | Sort-Object) {
        $def = $taskDefs[$key]
        $taskName = $def.Name

        try {
            $existing = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
            if ($existing) {
                $trigger = $existing.Triggers | Select-Object -First 1
                $state = $existing.State
                Write-Status "  [OK] $taskName" Green
                Write-Status "       State: $state"
                Write-Status "       Description: $($existing.Description)"
                if ($trigger) {
                    Write-Status "       Trigger: Repetition every $($trigger.Repetition.Interval)"
                }
            } else {
                Write-Status "  [--] $taskName (not installed)" DarkGray
            }
        } catch {
            Write-Status "  [??] $taskName (error: $_)" Yellow
        }
    }

    Write-Status ""
    Write-Status "Use -Action install to create tasks." DarkGray
}

# --- Action: Install ---
function Install-Tasks {
    Write-Status "=== Installing Scheduled Tasks ===" Cyan
    Write-Status "Machine: $machineName"
    Write-Status "Interval: every ${IntervalHours}h"
    Write-Status ""

    foreach ($key in $selectedTasks) {
        $def = $taskDefs[$key]
        $taskName = $def.Name
        $taskMaxMin = if ($MaxMinutes -gt 0) { $MaxMinutes } else { $def.MaxMinutes }

        # Build the command
        if ($def.UseWrapper) {
            $script = Join-Path $scriptDir "sync-tour-scheduled.ps1"
            $arguments = "-ExecutionPolicy Bypass -File `"$script`" -MaxMinutes $taskMaxMin"
            if ($SkipPermissions) {
                $arguments += " -SkipPermissions"
            }
        } else {
            $script = Join-Path $scriptDir "start-claude-worker.ps1"
            $arguments = "-ExecutionPolicy Bypass -File `"$script`" -Task `"$($def.Task)`" -MaxMinutes $taskMaxMin"
            if ($SkipPermissions) {
                $arguments += " -SkipPermissions"
            }
        }

        Write-Status "  Task: $taskName" Yellow
        Write-Status "    Script: $script"
        Write-Status "    Args: $arguments"
        Write-Status "    Interval: ${IntervalHours}h, Timeout: ${taskMaxMin}min"

        if ($DryRun) {
            Write-Status "    [DRY RUN] Would create task" DarkGray
            continue
        }

        try {
            # Remove existing task if present
            $existing = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
            if ($existing) {
                Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
                Write-Status "    Removed existing task." DarkGray
            }

            # Create trigger: repeat every N hours, indefinitely
            $trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(5) `
                -RepetitionInterval (New-TimeSpan -Hours $IntervalHours) `
                -RepetitionDuration ([TimeSpan]::MaxValue)

            # Create action: run powershell with our script
            $action = New-ScheduledTaskAction `
                -Execute "powershell.exe" `
                -Argument $arguments `
                -WorkingDirectory $RepoRoot

            # Settings: allow on battery, don't stop on battery, kill after timeout+5min
            $settings = New-ScheduledTaskSettingsSet `
                -AllowStartIfOnBatteries `
                -DontStopIfGoingOnBatteries `
                -ExecutionTimeLimit (New-TimeSpan -Minutes ($taskMaxMin + 5)) `
                -StartWhenAvailable `
                -MultipleInstances IgnoreNew

            # Register
            Register-ScheduledTask `
                -TaskName $taskName `
                -Description $def.Description `
                -Trigger $trigger `
                -Action $action `
                -Settings $settings `
                -RunLevel Limited | Out-Null

            Write-Status "    [OK] Created successfully" Green
        } catch {
            Write-Status "    [FAIL] Error: $_" Red
            Write-Status "    TIP: Run as Administrator if access denied." Yellow
        }
    }

    Write-Status ""
    Write-Status "Done. Use -Action list to verify." DarkGray
}

# --- Action: Remove ---
function Remove-Tasks {
    Write-Status "=== Removing Scheduled Tasks ===" Cyan

    foreach ($key in $selectedTasks) {
        $def = $taskDefs[$key]
        $taskName = $def.Name

        if ($DryRun) {
            Write-Status "  [DRY RUN] Would remove $taskName" DarkGray
            continue
        }

        try {
            $existing = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
            if ($existing) {
                Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
                Write-Status "  [OK] Removed $taskName" Green
            } else {
                Write-Status "  [--] $taskName not found (nothing to remove)" DarkGray
            }
        } catch {
            Write-Status "  [FAIL] Error removing $taskName : $_" Red
        }
    }
}

# --- Action: Test ---
function Test-Tasks {
    Write-Status "=== Testing Tasks (DryRun) ===" Cyan

    foreach ($key in $selectedTasks) {
        $def = $taskDefs[$key]
        $taskMaxMin = if ($MaxMinutes -gt 0) { $MaxMinutes } else { $def.MaxMinutes }

        Write-Status "  Testing: $($def.Task)" Yellow

        if ($def.UseWrapper) {
            $script = Join-Path $scriptDir "sync-tour-scheduled.ps1"
            Write-Status "    Would run: $script -MaxMinutes $taskMaxMin"
        } else {
            $script = Join-Path $scriptDir "start-claude-worker.ps1"
            & powershell -ExecutionPolicy Bypass -File $script -Task $def.Task -MaxMinutes $taskMaxMin -DryRun
        }

        Write-Status ""
    }
}

# --- Main ---
switch ($Action) {
    'list'    { Show-Tasks }
    'install' { Install-Tasks }
    'remove'  { Remove-Tasks }
    'test'    { Test-Tasks }
}
