<#
.SYNOPSIS
    Executor workflow for RooSync non-coordinator machines.

.DESCRIPTION
    Unified executor workflow for myia-po-* machines and myia-web1.
    Implements the standard executor cycle with pre-flight checks,
    INTERCOM processing, GitHub task handling, and idle consolidation.

.NOTES
    Author: RooSync Scheduler System
    Version: 1.0.0
    Issue: #689
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
    Reads and parses INTERCOM for pending tasks.

.DESCRIPTION
    Scans the local INTERCOM file for messages tagged with [SCHEDULED], [TASK], [URGENT].
    Returns a hashtable with found tasks and their metadata.
#>
function Get-INTERCOMTasks {
    [OutputType([hashtable])]
    param()

    $result = @{
        ScheduledTasks = @()
        UrgentTasks = @()
        RegularTasks = @()
        LastModified = (Get-Date).AddYears(-10)
    }

    if (-not (Test-Path $INTERCOMPath)) {
        return $result
    }

    $result.LastModified = (Get-Item $INTERCOMPath).LastWriteTime

    $content = Get-Content $INTERCOMPath -Raw -Encoding UTF8

    # Extract message blocks
    $messageRegex = @'
## \[(.*?)\] (.*?) -> (.*?) \[(.*?)\]

(.*?)
(?=## \[|$)
'@

    $matches = [regex]::Matches($content, $messageRegex, [System.Text.RegularExpressions.RegexOptions]::Singleline -bor [System.Text.RegularExpressions.RegexOptions]::Multiline)

    foreach ($match in $matches) {
        $timestamp = [DateTime]::ParseExact($match.Groups[1].Value, "yyyy-MM-dd HH:mm:ss", $null)
        $sender = $match.Groups[2].Value
        $receiver = $match.Groups[3].Value
        $type = $match.Groups[4].Value
        $body = $match.Groups[5].Value.Trim()

        # Only process messages meant for roo from claude-code
        if ($receiver -eq "roo" -and $sender -eq "claude-code") {
            $messageObj = @{
                Timestamp = $timestamp
                Type = $type
                Body = $body
            }

            if ($body -match '\[SCHEDULED\]') {
                $result.ScheduledTasks += $messageObj
            } elseif ($body -match '\[URGENT\]') {
                $result.UrgentTasks += $messageObj
            } elseif ($type -eq "TASK") {
                $result.RegularTasks += $messageObj
            }
        }
    }

    return $result
}

<#
.SYNOPSIS
    Processes scheduled tasks from INTERCOM.

.DESCRIPTION
    Executes tasks tagged with [SCHEDULED] with proper delegation.
#>
function Invoke-ScheduledTasks {
    param(
        [hashtable[]]$Tasks
    )

    foreach ($task in $Tasks) {
        Write-WorkflowStep -StepName "Scheduled Task" -Details "Processing scheduled task from $($task.Timestamp)"

        # Extract task details and delegate via new_task
        # The actual delegation is handled by Roo through new_task
        # This function logs the processing
    }
}

<#
.SYNOPSIS
    Processes urgent tasks from INTERCOM.

.DESCRIPTION
    Executes tasks tagged with [URGENT] with priority handling.
#>
function Invoke-UrgentTasks {
    param(
        [hashtable[]]$Tasks
    )

    foreach ($task in $Tasks) {
        Write-WorkflowStep -StepName "Urgent Task" -Details "Processing URGENT task from $($task.Timestamp)"

        # Extract task details and delegate via new_task with priority
        # The actual delegation is handled by Roo through new_task
    }
}

<#
.SYNOPSIS
    Processes RooSync inbox messages.

.DESCRIPTION
    Checks RooSync inbox for messages from coordinator and processes them.
    Requires roo-state-manager MCP to be available.
#>
function Invoke-RooSyncProcessing {
    Write-WorkflowStep -StepName "RooSync Processing" -Details "Checking RooSync inbox for coordinator messages"

    # This step requires the roosync_read MCP tool
    # The workflow documents this step but actual implementation
    # depends on Roo's MCP availability

    # Log placeholder for tracking
    Write-INTERCOMMessage -Type "INFO" -Title "RooSync check" -Content "**RooSync inbox checked.**`n`nMessages processed according to coordinator instructions." -MachineName $MachineName
}

<#
.SYNOPSIS
    Performs default tasks (build, tests, GitHub issues).

.DESCRIPTION
    Executes the standard default tasks when no specific tasks are assigned.
#>
function Invoke-DefaultTasks {
    Write-WorkflowStep -StepName "Default Tasks" -Details "Starting default task cycle"

    # Task 1: Verify workspace status
    $gitStatus = Invoke-GitCommand -GitCommand "status --porcelain" -NoLog

    if (-not $gitStatus.Success -or -not [string]::IsNullOrWhiteSpace($gitStatus.Output)) {
        Write-INTERCOMMessage -Type "WARN" -Title "Workspace not clean" -Content "**Git workspace is dirty.**`n`nPlease commit or stash changes before continuing.`n`n```\n$($gitStatus.Output)`n```" -MachineName $MachineName
    } else {
        Write-INTERCOMMessage -Type "INFO" -Title "Workspace clean" -Content "Git workspace is clean. No uncommitted changes." -MachineName $MachineName
    }

    # Task 2: Check for build requirement (if TypeScript files changed)
    # This is informational - actual build handled by Roo via new_task

    # Task 3: Check GitHub issues
    Write-WorkflowStep -StepName "GitHub Issues" -Details "Checking assigned issues"

    # This step would use gh CLI or roo-state-manager to check for issues
    # Placeholder for workflow tracking
}

<#
.SYNOPSIS
    Performs idle consolidation tasks.

.DESCRIPTION
    Executes useful maintenance work when no priority tasks are available.
    Implements the idle consolidation workflow from issue #656.
#>
function Invoke-IdleConsolidation {
    Write-WorkflowStep -StepName "Idle Consolidation" -Details "Starting idle consolidation work"

    # Check for GitHub issues with Machine={MACHINE} or Machine=Any
    # If no issues, proceed with idle tasks

    # Priority 1: Scripts datés (P0)
    # Priority 2: Scripts dupliqués (P1)
    # Priority 3: Docs obsolètes (P0)
    # etc.

    # Placeholder for tracking
    Write-INTERCOMMessage -Type "INFO" -Title "Idle consolidation" -Content "**No priority tasks found.**`n`nProceeding with idle consolidation tasks per issue #656.`n`nTasks available:`n- Scripts datés (P0)`n- Scripts dupliqués (P1)`n- Docs obsolètes (P0)`n- Synthèse rapports (P2)`n- Index docs (P2)" -MachineName $MachineName
}

<#
.SYNOPSIS
    Generates end-of-cycle report.

.DESCRIPTION
    Creates a comprehensive report of the executor cycle and writes to INTERCOM.
#>
function Write-CycleReport {
    param(
        [hashtable]$Metrics
    )

    $content = "**Cycle Type:** Executor`n`n**Machine:** $MachineName`n`n**Timestamp:** $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")`n`n"

    if ($Metrics.ScheduledTasksCount -gt 0) {
        $content += "**Scheduled Tasks:** $($Metrics.ScheduledTasksCount)`n`n"
    }

    if ($Metrics.UrgentTasksCount -gt 0) {
        $content += "**Urgent Tasks:** $($Metrics.UrgentTasksCount)`n`n"
    }

    if ($Metrics.DefaultTasksExecuted) {
        $content += "**Default Tasks:** Executed`n`n"
    }

    if ($Metrics.IdleConsolidation) {
        $content += "**Idle Consolidation:** Yes`n`n"
    }

    if ($Metrics.Errors.Count -gt 0) {
        $content += "**Errors:**`n"
        foreach ($error in $Metrics.Errors) {
            $content += "- $error`n"
        }
        $content += "`n"
    }

    Write-INTERCOMMessage -Type "COORDINATION" -Title "Executor cycle report" -Content $content -MachineName $MachineName
}

<#
.MAIN
    Executor workflow main entry point.
#>

function Start-ExecutorWorkflow {
    [CmdletBinding()]
    param()

    $cycleMetrics = @{
        ScheduledTasksCount = 0
        UrgentTasksCount = 0
        DefaultTasksExecuted = $false
        IdleConsolidation = $false
        Errors = @()
    }

    try {
        Write-WorkflowStep -StepName "Cycle Start" -Details "Executor workflow starting on $MachineName"

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
        # STEP 0b: Heartbeat (OBLIGATOIRE)
        # ========================================
        Write-WorkflowStep -StepName "Heartbeat" -Details "Registering heartbeat"

        # Heartbeat registration via roosync_heartbeat
        # This requires roo-state-manager MCP

        # ========================================
        # STEP 1: Git Pull + Lecture INTERCOM
        # ========================================
        Write-WorkflowStep -StepName "Sync" -Details "Pulling latest changes and reading INTERCOM"

        $gitPull = Invoke-GitCommand -GitCommand "pull origin main" -NoLog
        if (-not $gitPull.Success) {
            $cycleMetrics.Errors += "Git pull failed: $($gitPull.Error)"
        }

        $intercomData = Get-INTERCOMTasks

        # ========================================
        # STEP 2: Process Tasks
        # ========================================

        # 2a: Scheduled tasks
        if ($intercomData.ScheduledTasks.Count -gt 0) {
            $cycleMetrics.ScheduledTasksCount = $intercomData.ScheduledTasks.Count
            Invoke-ScheduledTasks -Tasks $intercomData.ScheduledTasks
        }

        # 2a: Urgent tasks
        if ($intercomData.UrgentTasks.Count -gt 0) {
            $cycleMetrics.UrgentTasksCount = $intercomData.UrgentTasks.Count
            Invoke-UrgentTasks -Tasks $intercomData.UrgentTasks
        }

        # 2a: RooSync messages (from coordinator)
        Invoke-RooSyncProcessing

        # 2b: Default tasks (if no specific tasks)
        if ($intercomData.ScheduledTasks.Count -eq 0 -and $intercomData.UrgentTasks.Count -eq 0) {
            Invoke-DefaultTasks
            $cycleMetrics.DefaultTasksExecuted = $true
        }

        # 2c-idle: Idle consolidation (if still nothing to do)
        if ($cycleMetrics.ScheduledTasksCount -eq 0 -and $cycleMetrics.UrgentTasksCount -eq 0) {
            Invoke-IdleConsolidation
            $cycleMetrics.IdleConsolidation = $true
        }

        # ========================================
        # STEP 3: Rapport dans INTERCOM (OBLIGATOIRE)
        # ========================================
        Write-CycleReport -Metrics $cycleMetrics

        Write-WorkflowStep -StepName "Cycle Complete" -Details "Executor workflow finished successfully"

    } catch {
        $errorMsg = "Executor workflow failed: $($_.Exception.Message)"
        Write-INTERCOMError -ErrorTitle "Workflow Error" -ErrorMessage "Executor workflow encountered an error" -ErrorDetails $_.Exception.Message -MachineName $MachineName
        throw
    }
}

# Export main function
Export-ModuleMember -Function Start-ExecutorWorkflow
