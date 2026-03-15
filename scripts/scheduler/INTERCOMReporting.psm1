<#
.SYNOPSIS
    INTERCOM reporting module for scheduler workflows.

.DESCRIPTION
    Standardized INTERCOM message formatting and reporting functions
    for all scheduler workflows (coordinator, executor, meta-analyst).

.EXAMPLE
    Write-INTERCOMMessage -Type "INFO" -Title "Cycle started" -Content "Starting executor cycle"
#>

function Write-INTERCOMMessage {
    <#
    .PARAMETER Type
    Message type: INFO, TASK, DONE, WARN, ERROR, ASK, REPLY, COORDINATION, CRITICAL

    .PARAMETER Title
    Message title (appears after ### in markdown)

    .PARAMETER Content
    Message body content (markdown supported)

    .PARAMETER Sender
    Message sender (default: "claude-code")

    .PARAMETER Receiver
    Message receiver (default: "roo")

    .PARAMETER MachineName
    Machine name for INTERCOM file path (default: auto-detect)
    #>
    [OutputType([void])]
    param(
        [ValidateSet('INFO', 'TASK', 'DONE', 'WARN', 'ERROR', 'ASK', 'REPLY', 'COORDINATION', 'CRITICAL')]
        [string]$Type,

        [Parameter(Mandatory=$true)]
        [string]$Title,

        [Parameter(Mandatory=$true)]
        [string]$Content,

        [string]$Sender = "claude-code",
        [string]$Receiver = "roo",
        [string]$MachineName = ($env:COMPUTERNAME).ToLower()
    )

    $intercomPath = ".claude/local/INTERCOM-$MachineName.md"
    $timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")

    $message = @"

## [$timestamp] $Sender -> $Receiver [$Type]

### $Title

$Content

---
"@

    Add-Content -Path $intercomPath -Value $message -ErrorAction SilentlyContinue
}

<#
.SYNOPSIS
    Writes a task assignment message to INTERCOM.

.DESCRIPTION
    Standard format for assigning tasks to Roo via INTERCOM.

.PARAMETER IssueNumber
    GitHub issue number (optional)

.PARAMETER TaskTitle
    Title of the task being assigned

.PARAMETER Priority
    Task priority: LOW, MEDIUM, HIGH, URGENT (default: MEDIUM)

.PARAMETER Instructions
    Detailed instructions for the task
#>
function Write-INTERCOMTask {
    [OutputType([void])]
    param(
        [int]$IssueNumber,
        [Parameter(Mandatory=$true)]
        [string]$TaskTitle,
        [ValidateSet('LOW', 'MEDIUM', 'HIGH', 'URGENT')]
        [string]$Priority = "MEDIUM",
        [Parameter(Mandatory=$true)]
        [string]$Instructions,
        [string]$MachineName = ($env:COMPUTERNAME).ToLower()
    )

    $content = "**Priority:** $Priority`n`n$Instructions"

    if ($IssueNumber -gt 0) {
        $content = "**Issue:** #$IssueNumber`n`n$content"
    }

    Write-INTERCOMMessage -Type "TASK" -Title $TaskTitle -Content $content -MachineName $MachineName
}

<#
.SYNOPSIS
    Writes a task completion message to INTERCOM.

.DESCRIPTION
    Standard format for reporting completed tasks to Roo.

.PARAMETER TaskTitle
    Title of the completed task

.PARAMETER IssueNumber
    GitHub issue number (optional)

.PARAMETER Results
    Summary of results/achievements

.PARAMETER CommitHash
    Git commit hash (if applicable)

.PARAMETER FilesModified
    List of modified files (optional)
#>
function Write-INTERCOMDone {
    [OutputType([void])]
    param(
        [Parameter(Mandatory=$true)]
        [string]$TaskTitle,

        [int]$IssueNumber,

        [Parameter(Mandatory=$true)]
        [string]$Results,

        [string]$CommitHash,

        [string[]]$FilesModified,

        [string]$MachineName = ($env:COMPUTERNAME).ToLower()
    )

    $content = $Results

    if ($IssueNumber -gt 0) {
        $content = "**Issue:** #$IssueNumber`n`n$content"
    }

    if ($CommitHash) {
        $content += "`n`n**Commit:** $CommitHash"
    }

    if ($FilesModified -and $FilesModified.Count -gt 0) {
        $content += "`n`n**Files modified:**`n"
        foreach ($file in $FilesModified) {
            $content += "- $file`n"
        }
    }

    Write-INTERCOMMessage -Type "DONE" -Title $TaskTitle -Content $content -MachineName $MachineName
}

<#
.SYNOPSIS
    Writes a scheduler cycle report to INTERCOM.

.DESCRIPTION
    Standard format for end-of-cycle scheduler reports.

.PARAMETER CycleType
    Type of scheduler cycle: executor, coordinator, meta-analyst

.PARAMETER ActionsTaken
    List of actions performed during the cycle

.PARAMETER TasksCreated
    Number of GitHub issues created (optional)

.PARAMETER TasksCompleted
    Number of GitHub issues completed (optional)

.PARAMETER Errors
    List of errors encountered (optional)

.PARAMETER NextActions
    List of recommended next actions (optional)
#>
function Write-INTERCOMCycleReport {
    [OutputType([void])]
    param(
        [Parameter(Mandatory=$true)]
        [string]$CycleType,

        [Parameter(Mandatory=$true)]
        [string[]]$ActionsTaken,

        [int]$TasksCreated = 0,

        [int]$TasksCompleted = 0,

        [string[]]$Errors = @(),

        [string[]]$NextActions = @(),

        [string]$MachineName = ($env:COMPUTERNAME).ToLower()
    )

    $content = "**Cycle type:** $CycleType`n`n**Actions taken:**`n"
    foreach ($action in $ActionsTaken) {
        $content += "- $action`n"
    }

    if ($TasksCreated -gt 0 -or $TasksCompleted -gt 0) {
        $content += "`n**Task counts:**`n"
        if ($TasksCreated -gt 0) {
            $content += "- Created: $TasksCreated`n"
        }
        if ($TasksCompleted -gt 0) {
            $content += "- Completed: $TasksCompleted`n"
        }
    }

    if ($Errors -and $Errors.Count -gt 0) {
        $content += "`n**Errors encountered:**`n"
        foreach ($error in $Errors) {
            $content += "- $error`n"
        }
    }

    if ($NextActions -and $NextActions.Count -gt 0) {
        $content += "`n**Recommended next actions:**`n"
        foreach ($action in $NextActions) {
            $content += "- $action`n"
        }
    }

    Write-INTERCOMMessage -Type "COORDINATION" -Title "Scheduler cycle report" -Content $content -MachineName $MachineName
}

<#
.SYNOPSIS
    Writes an error message to INTERCOM.

.DESCRIPTION
    Standard format for reporting errors to Roo.

.PARAMETER ErrorTitle
    Title of the error

.PARAMETER ErrorMessage
    Detailed error message

.PARAMETER ErrorDetails
    Additional error details (stack trace, command output, etc.)

.PARAMETER SuggestedAction
    Suggested action to resolve the error (optional)
#>
function Write-INTERCOMError {
    [OutputType([void])]
    param(
        [Parameter(Mandatory=$true)]
        [string]$ErrorTitle,

        [Parameter(Mandatory=$true)]
        [string]$ErrorMessage,

        [string]$ErrorDetails,

        [string]$SuggestedAction,

        [string]$MachineName = ($env:COMPUTERNAME).ToLower()
    )

    $content = "**Error:** $ErrorMessage"

    if ($ErrorDetails) {
        $content += "`n`n**Details:**`n````n$ErrorDetails````"
    }

    if ($SuggestedAction) {
        $content += "`n`n**Suggested action:** $SuggestedAction"
    }

    Write-INTERCOMMessage -Type "ERROR" -Title $ErrorTitle -Content $content -MachineName $MachineName
}

Export-ModuleMember -Function Write-INTERCOMMessage, Write-INTERCOMTask, Write-INTERCOMDone, Write-INTERCOMCycleReport, Write-INTERCOMError
