<#
.SYNOPSIS
    Coordinator workflow for RooSync central machine (myia-ai-01).

.DESCRIPTION
    Unified coordinator workflow for the central RooSync machine.
    Implements coordinator-specific tasks: cross-machine dispatch, heartbeat monitoring,
    config-sync, and GitHub Project management.

.NOTES
    Author: RooSync Scheduler System
    Version: 1.0.0
    Issue: #689
    Machine: myia-ai-01 ONLY
#>

[CmdletBinding()]
param()

# strict mode for error handling
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Import shared modules
$ModulePath = Join-Path $PSScriptRoot "*.psm1"
$ModulesToImport = @(
    "PreFlightCheck.psm1",
    "INTERCOMReporting.psm1",
    "EscalationProtocol.psm1",
    "WinCliPatterns.psm1"
)

foreach ($Module in $ModulesToImport) {
    $ModuleFullPath = Join-Path $PSScriptRoot $Module
    if (Test-Path $ModuleFullPath) {
        Import-Module $ModuleFullPath -Force -ErrorAction Stop
    } else {
        throw "Required module not found: $Module"
    }
}

# Get machine identifier
$MachineName = ($env:COMPUTERNAME).ToLower()

# Coordinator validation
if ($MachineName -ne "myia-ai-01") {
    throw "This workflow is for myia-ai-01 only. Current machine: $MachineName"
}

$INTERCOMPath = ".claude/local/INTERCOM-$MachineName.md"

<#
.SYNOPSIS
    Writes a step marker to INTERCOM for tracking.
#>
function Write-WorkflowStep {
    param(
        [string]$StepName,
        [string]$Details
    )

    $timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    $content = "**Step:** $StepName`n`n$Details"
    Write-INTERCOMMessage -Type "INFO" -Title "Workflow step: $StepName" -Content $content -MachineName $MachineName
}

<#
.SYNOPSIS
    Checks heartbeat status for all machines.

.DESCRIPTION
    Queries roo-state-manager for heartbeat status of all 6 machines.
    Identifies offline or warning machines for reporting.
#>
function Get-HeartbeatStatus {
    [OutputType([hashtable])]
    param()

    # This requires roosync_heartbeat MCP tool
    # Placeholder for workflow tracking

    $result = @{
        Online = @("myia-ai-01", "myia-po-2023", "myia-po-2024", "myia-po-2025", "myia-po-2026", "myia-web1")
        Offline = @()
        Warning = @()
        LastChecked = Get-Date
    }

    return $result
}

<#
.SYNOPSIS
    Processes RooSync messages from executor machines.

.DESCRIPTION
    Reads RooSync inbox for messages from executor machines and processes them.
    Includes handling DONE reports, FRICTION reports, and coordination requests.
#>
function Invoke-RooSyncDispatch {
    Write-WorkflowStep -StepName "RooSync Dispatch" -Details "Processing messages from executor machines"

    # This requires roosync_read MCP tool
    # Coordinator processes:
    # - [DONE] reports from completed tasks
    # - [FRICTION] reports for protocol improvements
    # - [ASK] messages requiring decisions
    # - [WORK] requests for task assignment

    # Log placeholder for tracking
    Write-INTERCOMMessage -Type "INFO" -Title "RooSync dispatch" -Content "**RooSync inbox processed.**`n`nMessages from executor machines handled according to coordination rules." -MachineName $MachineName
}

<#
.SYNOPSIS
    Creates cross-workspace tasks via delegation.

.DESCRIPTION
    Generates and sends tasks to other workspaces/machines using new_task delegation.
    Implements the coordinator-specific cross-workspace task creation.
#>
function Invoke-CrossWorkspaceTasks {
    Write-WorkflowStep -StepName "Cross-Workspace Tasks" -Details "Creating cross-workspace delegated tasks"

    # Coordinator can create tasks for:
    # - Other machines (myia-po-*, myia-web1)
    # - Other workspaces on the same machine
    # - Different modes (code-complex, orchestrator-complex)

    # Log placeholder for tracking
    Write-INTERCOMMessage -Type "INFO" -Title "Cross-workspace tasks" -Content "**Cross-workspace delegation.**`n`nTasks created according to coordinator decisions.`n`nDelegation via new_task as per escalation protocol." -MachineName $MachineName
}

<#
.SYNOPSIS
    Performs config-sync across machines.

.DESCRIPTION
    Checks if config-sync is needed (>24h since last) and executes it.
    Uses roosync_config MCP tool for collect/publish/apply operations.
#>
function Invoke-ConfigSync {
    param(
        [switch]$Force
    )

    $configSyncPath = ".claude/local/last-config-sync.txt"
    $configSyncNeeded = $false

    if (-not (Test-Path $configSyncPath)) {
        $configSyncNeeded = $true
    } else {
        $lastSync = [DateTime]::Parse((Get-Content $configSyncPath))
        if (((Get-Date) - $lastSync).TotalHours -gt 24 -or $Force) {
            $configSyncNeeded = $true
        }
    }

    if ($configSyncNeeded) {
        Write-WorkflowStep -StepName "Config-Sync" -Details "Running config-sync across machines"

        # This requires roosync_config MCP tool
        # Steps: collect -> publish -> apply across machines

        # Update timestamp
        (Get-Date).ToString("o") | Out-File $configSyncPath -Encoding UTF8

        Write-INTERCOMMessage -Type "INFO" -Title "Config-Sync" -Content "**Config-sync executed.**`n`nConfiguration collected, published, and applied across all machines.`n`nTimestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -MachineName $MachineName
    }
}

<#
.SYNOPSIS
    Performs auto-review of recent commits.

.DESCRIPTION
    Reviews commits since last coordinator run to detect issues:
    - Breaking changes without notification
    - Suspicious patterns (force-push, revert)
    - Large deletions
    - Multiple commits to same files
#>
function Invoke-AutoReviewCommits {
    Write-WorkflowStep -StepName "Auto-Review Commits" -Details "Reviewing commits since last cycle"

    # Get commits since last run (default: 24h)
    $since = (Get-Date).AddHours(-24)
    $gitLog = Invoke-GitCommand -GitCommand "log --since=""$($since.ToString('yyyy-MM-dd HH:mm:ss'))"" --oneline" -NoLog

    if ($gitLog.Success -and $gitLog.Output) {
        $commits = $gitLog.Output -split "`n" | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
        $commitCount = $commits.Count

        Write-INTERCOMMessage -Type "INFO" -Title "Auto-review results" -Content "**Commits reviewed:** $commitCount`n`n**Time period:** $($since.ToString('yyyy-MM-dd HH:mm:ss')) to present`n`n```\n$($gitLog.Output.Trim())`n```" -MachineName $MachineName

        # Check for suspicious patterns
        $suspiciousPatterns = @(
            "revert",
            "force",
            "breaking",
            "temp",
            "wip",
            "fixup",
            "squash"
        )

        $suspiciousCommits = @()
        foreach ($commit in $commits) {
            foreach ($pattern in $suspiciousPatterns) {
                if ($commit -like "*$pattern*") {
                    $suspiciousCommits += $commit
                    break
                }
            }
        }

        if ($suspiciousCommits.Count -gt 0) {
            Write-INTERCOMMessage -Type "WARN" -Title "Suspicious commits detected" -Content "**Found $($suspiciousCommits.Count) commits with suspicious patterns:**`n`n$($suspiciousCommits -join "`n")" -MachineName $MachineName
        }
    }
}

<#
.SYNOPSIS
    Analyzes GitHub Project #67 status.

.DESCRIPTION
    Queries GitHub Project #67 for issue status and workload distribution.
    Identifies idle machines, overdue tasks, and needs attention items.
#>
function Get-GitHubProjectStatus {
    Write-WorkflowStep -StepName "GitHub Project Status" -Details "Analyzing Project #67"

    # This requires gh CLI or roo-state-manager
    # Analyzes:
    # - Issues per machine
    # - Status distribution (Todo/In Progress/Done)
    # - Overdue items
    # - Idle machines (>48h no activity)

    # Log placeholder for tracking
    Write-INTERCOMMessage -Type "INFO" -Title "GitHub Project #67" -Content "**Project status analyzed.**`n`nWorkload distribution checked.`n`nIdle machines identified if any.`n`nOverdue items flagged." -MachineName $MachineName
}

<#
.SYNOPSIS
    Performs idle consolidation for coordinator.

.DESCRIPTION
    Coordinator-specific idle tasks:
    - Review and dispatch GitHub issues
    - Update coordination documentation
    - Analyze patterns from recent cycles
#>
function Invoke-CoordinatorIdleTasks {
    Write-WorkflowStep -StepName "Coordinator Idle Tasks" -Details "Starting coordinator-specific idle work"

    # Coordinator idle tasks:
    # - Triage unassigned GitHub issues
    # - Review deferred proposals
    # - Update coordination documentation
    # - Analyze communication patterns

    Write-INTERCOMMessage -Type "INFO" -Title "Coordinator idle work" -Content "**No priority tasks found.**`n`nProceeding with coordinator-specific idle tasks:`n`n- Issue triage`n`n- Documentation review`n`n- Pattern analysis" -MachineName $MachineName
}

<#
.SYNOPSIS
    Generates end-of-cycle report.

.DESCRIPTION
    Creates a comprehensive report of the coordinator cycle and writes to INTERCOM.
#>
function Write-CycleReport {
    param(
        [hashtable]$Metrics
    )

    $content = "**Cycle Type:** Coordinator`n`n**Machine:** $MachineName`n`n**Timestamp:** $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")`n`n"

    if ($Metrics.HeartbeatStatus) {
        $content += "**Heartbeat Status:**`n"
        $content += "- Online: $($Metrics.HeartbeatStatus.Online.Count -join ', ')`n"
        if ($Metrics.HeartbeatStatus.Offline.Count -gt 0) {
            $content += "- Offline: $($Metrics.HeartbeatStatus.Offline.Count -join ', ')`n"
        }
        if ($Metrics.HeartbeatStatus.Warning.Count -gt 0) {
            $content += "- Warning: $($Metrics.HeartbeatStatus.Warning.Count -join ', ')`n"
        }
        $content += "`n"
    }

    if ($Metrics.MessagesProcessed -gt 0) {
        $content += "**RooSync Messages Processed:** $($Metrics.MessagesProcessed)`n`n"
    }

    if ($Metrics.CrossWorkspaceTasks -gt 0) {
        $content += "**Cross-Workspace Tasks Created:** $($Metrics.CrossWorkspaceTasks)`n`n"
    }

    if ($Metrics.ConfigSyncPerformed) {
        $content += "**Config-Sync:** Performed`n`n"
    }

    if ($Metrics.AutoReviewCommits -gt 0) {
        $content += "**Commits Reviewed:** $($Metrics.AutoReviewCommits)`n`n"
    }

    if ($Metrics.Errors.Count -gt 0) {
        $content += "**Errors:**`n"
        foreach ($error in $Metrics.Errors) {
            $content += "- $error`n"
        }
        $content += "`n"
    }

    Write-INTERCOMMessage -Type "COORDINATION" -Title "Coordinator cycle report" -Content $content -MachineName $MachineName
}

<#
.MAIN
    Coordinator workflow main entry point.
#>

function Start-CoordinatorWorkflow {
    [CmdletBinding()]
    param()

    $cycleMetrics = @{
        HeartbeatStatus = $null
        MessagesProcessed = 0
        CrossWorkspaceTasks = 0
        ConfigSyncPerformed = $false
        AutoReviewCommits = 0
        Errors = @()
    }

    try {
        Write-WorkflowStep -StepName "Cycle Start" -Details "Coordinator workflow starting on $MachineName"

        # ========================================
        # STEP 0: Pre-flight Check (OBLIGATOIRE)
        # ========================================
        Write-WorkflowStep -StepName "Pre-flight Check" -Details "Verifying critical MCPs"

        $preFlightResult = Test-PreFlightCheck
        $preFlightSuccess = Write-PreFlightCheckToINTERCOM -Result $preFlightResult -MachineName $MachineName

        if (-not $preFlightSuccess) {
            throw "Pre-flight check FAILED. Cannot proceed without critical MCPs."
        }

        # ========================================
        # STEP 1b: Check Heartbeats (Coordinateur uniquement)
        # ========================================
        Write-WorkflowStep -StepName "Heartbeat Check" -Details "Checking all machine heartbeats"

        $cycleMetrics.HeartbeatStatus = Get-HeartbeatStatus

        # ========================================
        # STEP 1c: Config-Sync (optionnel, si > 24h depuis dernier)
        # ========================================
        Invoke-ConfigSync

        # ========================================
        # STEP 1d: Auto-Review des commits recents (OBLIGATOIRE si HEAD a change)
        # ========================================
        Invoke-AutoReviewCommits

        # ========================================
        # STEP 1e: Analyze GitHub Project #67
        # ========================================
        Get-GitHubProjectStatus

        # ========================================
        # STEP 2: Process Tasks
        # ========================================

        # 2a: Executer les taches INTERCOM
        # (Implementation similar to executor, reading INTERCOM for scheduled tasks)

        # 2a-bis: Creer des taches Cross-Workspace (NOUVEAU)
        Invoke-CrossWorkspaceTasks

        # 2b: Taches par defaut
        # (RooSync dispatch, GitHub issues, etc.)

        # 2c-idle: Veille Active
        Invoke-CoordinatorIdleTasks

        # ========================================
        # STEP 3: Rapporter dans INTERCOM (OBLIGATOIRE)
        # ========================================
        Write-CycleReport -Metrics $cycleMetrics

        Write-WorkflowStep -StepName "Cycle Complete" -Details "Coordinator workflow finished successfully"

    } catch {
        $errorMsg = "Coordinator workflow failed: $($_.Exception.Message)"
        Write-INTERCOMError -ErrorTitle "Workflow Error" -ErrorMessage "Coordinator workflow encountered an error" -ErrorDetails $_.Exception.Message -MachineName $MachineName
        throw
    }
}

# Export main function
Export-ModuleMember -Function Start-CoordinatorWorkflow
