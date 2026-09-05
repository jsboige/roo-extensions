<#
.SYNOPSIS
    Installe la scheduled task 'MCP-Worktree-Cleanup' (SYSTEM, weekly Sunday 03:00).

.FAMILY
    F1 (installeur) — installe la schtask qui exécute `scripts/maintenance/cleanup-orphan-worktrees.ps1` (-Execute -DaysThreshold 7).

    Voir aussi (alignement Tâche A #3422, CONSOLIDATION-SCRIPTS-SUPERSEDED.md §2) :
      - F1 planifiée : `scripts/maintenance/cleanup-orphan-worktrees.ps1` (chemin critique — worker + schtask + test).
      - F2 PR       : `scripts/worktrees/cleanup-worktree.ps1` (appelée par `create-worktree.ps1` + `submit-pr.ps1`).
      - F3 alternative : `scripts/claude/worktree-cleanup.ps1` + `scripts/claude/install-worktree-cleanup-scheduled-task.ps1`
                        (tâche `Roo-Worktree-Cleanup`, daily 02:00 SYSTEM — installeur séparé).

    Note : installateur F1 ≠ installeur F3. F1 = hebdomadaire dimanche (MCP-Worktree-Cleanup).
    F3 = quotidien 02h (Roo-Worktree-Cleanup). Les deux schtasks coexistent sur certaines machines — #3422 ne les a pas fusionnés (F1 chemin critique, F3 séparée par skills).

.DESCRIPTION
    Runs cleanup-orphan-worktrees.ps1 -Execute -DaysThreshold 7 automatically
    to prevent worktree husk accumulation (#1913).

    - Account: NT AUTHORITY\SYSTEM
    - Trigger: Weekly on Sunday at 03:00 (configurable)
    - Execution time limit: 10 minutes
    - Restart on failure: 3 attempts every 5 minutes

.PARAMETER TaskName
    Default: MCP-Worktree-Cleanup

.PARAMETER ScriptPath
    Default: <script dir>\cleanup-orphan-worktrees.ps1

.PARAMETER DaysThreshold
    Minimum age for orphan cleanup. Default: 7

.EXAMPLE
    # Must be run as admin
    .\install-worktree-cleanup-schtask.ps1
#>

param(
    [string]$TaskName     = 'MCP-Worktree-Cleanup',
    [string]$ScriptPath   = (Join-Path $PSScriptRoot 'cleanup-orphan-worktrees.ps1'),
    [int]$DaysThreshold   = 7,
    [string]$DayOfWeek    = 'Sunday',
    [int]$Hour            = 3
)

$ErrorActionPreference = 'Stop'

# Check admin
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Error "This script must be run as Administrator."
    exit 1
}

if (-not (Test-Path $ScriptPath)) {
    Write-Error "Script not found: $ScriptPath"
    exit 1
}

Write-Host "=== Install scheduled task: $TaskName ==="

# Remove existing
$existing = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
if ($existing) {
    Write-Host "Removing existing task..."
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
}

# Action: run cleanup script with -Execute flag
$action = New-ScheduledTaskAction `
    -Execute 'powershell.exe' `
    -Argument "-ExecutionPolicy Bypass -NoProfile -WindowStyle Hidden -File `"$ScriptPath`" -Execute -DaysThreshold $DaysThreshold" `
    -WorkingDirectory (Split-Path $ScriptPath -Parent)

# Trigger: weekly on specified day at specified hour
$trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek $DayOfWeek -At "$($Hour):00"

# Principal: SYSTEM, highest run level
$principal = New-ScheduledTaskPrincipal `
    -UserId 'SYSTEM' `
    -LogonType ServiceAccount `
    -RunLevel Highest

# Settings
$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 10) `
    -RestartInterval (New-TimeSpan -Minutes 5) `
    -RestartCount 3 `
    -MultipleInstances IgnoreNew

$task = New-ScheduledTask `
    -Action $action `
    -Trigger $trigger `
    -Principal $principal `
    -Settings $settings `
    -Description "Weekly cleanup of orphan git worktrees under .claude/worktrees/ (#1913). Runs cleanup-orphan-worktrees.ps1 -Execute -DaysThreshold $DaysThreshold."

Register-ScheduledTask -TaskName $TaskName -InputObject $task | Out-Null

Write-Host "=== Task installed ==="

$t = Get-ScheduledTask -TaskName $TaskName
Write-Host "State: $($t.State)"
Write-Host "Triggers:"
$t.Triggers | ForEach-Object {
    Write-Host ("  - {0} DaysOfWeek={1} StartBoundary={2}" -f $_.CimClass.CimClassName, ($_.DaysOfWeek -join ','), $_.StartBoundary)
}

Write-Host ""
Write-Host "To test immediately: Start-ScheduledTask -TaskName '$TaskName'"
