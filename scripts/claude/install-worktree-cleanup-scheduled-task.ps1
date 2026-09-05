# Install Worktree Cleanup Scheduled Task
# FAMILY: F3 (installeur) — installe la schtask Roo-Worktree-Cleanup (SYSTEM, daily 02:00)
# qui exécute `scripts/claude/worktree-cleanup.ps1 -Force`.
#
# Voir aussi (alignement Tâche A #3422, CONSOLIDATION-SCRIPTS-SUPERSEDED.md §2) :
#   - F1 (installeur)    : scripts/maintenance/install-worktree-cleanup-schtask.ps1
#                          — tâche MCP-Worktree-Cleanup, weekly Sunday 03:00.
#   - F2                 : scripts/worktrees/cleanup-worktree.ps1 (PR-workflow, pas de schtask).
#   - F3 (ce script)     : scripts/claude/install-worktree-cleanup-scheduled-task.ps1
#                          (+ scripts/claude/worktree-cleanup.ps1) — tâche Roo-Worktree-Cleanup,
#                          daily 02:00, skills debrief/git-sync, .roo/scheduler-workflow-executor.
#
# Différences F1 vs F3 :
#   - Schtask F1 : MCP-Worktree-Cleanup, weekly Sunday 03:00, lance cleanup-orphan-worktrees.ps1 -Execute -DaysThreshold 7.
#   - Schtask F3 : Roo-Worktree-Cleanup,  daily 02:00,        lance worktree-cleanup.ps1 -Force.
#   - Les 2 schtasks coexistent sur les machines qui ont installé les deux. PR #3422 ne les a pas fusionnés.
#
# PR #3422 n'a touché AUCUN comportement : ajout d'en-tête seulement.
# Description: Creates a Windows scheduled task to automatically cleanup orphan worktrees
# Issue: #895 - Le harnais scheduler PERD DU TRAVAIL
# Author: Claude Code (myia-po-2026)

param(
    [switch]$Remove,
    [switch]$WhatIf
)

$ErrorActionPreference = "Stop"

# Configuration
$script:TaskName = "Roo-Worktree-Cleanup"
$script:ScriptPath = Join-Path $PSScriptRoot "worktree-cleanup.ps1"
$script:RepoRoot = (git rev-parse --show-toplevel 2>$null)

if (-not $script:RepoRoot) {
    Write-Error "Not in a git repository"
    exit 1
}

# Colors
function Write-Info { param($msg) Write-Host "[INFO] $msg" -ForegroundColor Cyan }
function Write-Success { param($msg) Write-Host "[OK] $msg" -ForegroundColor Green }
function Write-Warn { param($msg) Write-Host "[WARN] $msg" -ForegroundColor Yellow }
function Write-Err { param($msg) Write-Host "[ERROR] $msg" -ForegroundColor Red }

# Check if script exists
if (-not (Test-Path $script:ScriptPath)) {
    Write-Err "Cleanup script not found: $script:ScriptPath"
    exit 1
}

# Remove task
if ($Remove) {
    Write-Info "Removing scheduled task: $script:TaskName"

    if ($WhatIf) {
        Write-Info "[WHATIF] Would remove task: $script:TaskName"
        Write-Info "Command: schtasks /Delete /TN '$script:TaskName' /F"
        exit 0
    }

    $result = schtasks /Delete /TN "$script:TaskName" /F 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Scheduled task removed successfully"
        Write-Info "Run with elevated privileges to remove from system"
    }
    else {
        Write-Warn "Task may not exist or requires elevated privileges"
    }
    exit 0
}

# Create task
Write-Host ""
Write-Host "=== Install Worktree Cleanup Scheduled Task ===" -ForegroundColor White
Write-Host "Repository: $script:RepoRoot"
Write-Host "Script: $script:ScriptPath"
Write-Host ""

# PowerShell command with execution policy
$psCommand = "powershell -ExecutionPolicy Bypass -File `"$script:ScriptPath`" -Force"

# Task parameters: Daily at 2 AM
$taskTrigger = "/SC DAILY /ST 02:00"
$taskRunAs = "/RU SYSTEM"

if ($WhatIf) {
    Write-Info "[WHATIF] Would create scheduled task with parameters:"
    Write-Host "  Task Name: $script:TaskName"
    Write-Host "  Trigger: Daily at 02:00"
    Write-Host "  Command: $psCommand"
    Write-Host "  Run As: SYSTEM"
    Write-Host ""
    Write-Info "Command: schtasks /Create /TN `"$script:TaskName`" /TR `"$psCommand`" $taskTrigger $taskRunAs /F"
    exit 0
}

Write-Info "Creating scheduled task..."
Write-Host "  Name: $script:TaskName"
Write-Host "  Schedule: Daily at 02:00"
Write-Host "  Script: $script:ScriptPath"
Write-Host ""

# Note: schtasks /Create requires elevated privileges
Write-Warn "Elevated privileges required (Run as Administrator)"

$result = schtasks /Create /TN "$script:TaskName" /TR "$psCommand" $taskTrigger $taskRunAs /F 2>&1

if ($LASTEXITCODE -eq 0) {
    Write-Success "Scheduled task created successfully"
    Write-Host ""
    Write-Info "To verify: schtasks /Query /TN `"$script:TaskName`""
    Write-Info "To run manually: schtasks /Run /TN `"$script:TaskName`""
    Write-Info "To remove: .\scripts\claude\install-worktree-cleanup-scheduled-task.ps1 -Remove"
    Write-Host ""
    Write-Info "The task will run daily at 02:00 to cleanup orphan worktrees and stale branches"
}
else {
    Write-Err "Failed to create scheduled task (exit code: $LASTEXITCODE)"
    Write-Host ""
    Write-Info "You may need to:"
    Write-Host "  1. Run PowerShell as Administrator"
    Write-Host "  2. Execute: .\scripts\claude\install-worktree-cleanup-scheduled-task.ps1"
    exit 1
}

exit 0
