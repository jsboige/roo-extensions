<#
.SYNOPSIS
    Escalation protocol module for scheduler workflows.

.DESCRIPTION
    Unified escalation criteria and delegation rules for all scheduler
    workflows. Implements the 3-layer escalation mechanism.

.EXAMPLE
    Test-EscalationCriteria -CurrentMode "code-simple" -FailureCount 2 -TaskComplexity "medium"
#>

function Test-EscalationCriteria {
    <#
    .SYNOPSIS
        Tests whether escalation to a higher mode is required.

    .DESCRIPTION
        Evaluates escalation criteria based on:
        - Failure count in current mode
        - Task complexity
        - Tool requirements
        - Dependencies count

    .PARAMETER CurrentMode
        Current execution mode (e.g., "code-simple", "code-complex", "orchestrator-simple")

    .PARAMETER FailureCount
        Number of failures in current mode (default: 0)

    .PARAMETER TaskComplexity
        Task complexity: simple, medium, complex (default: "simple")

    .PARAMETER ToolRequirements
        Array of required tool categories (e.g., @("read", "edit", "browser", "command"))

    .PARAMETER DependenciesCount
        Number of dependencies/sub-tasks (default: 0)

    .PARAMETER FilesToModify
        Number of files to modify (default: 0)
    #>
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory=$true)]
        [string]$CurrentMode,

        [int]$FailureCount = 0,

        [ValidateSet('simple', 'medium', 'complex')]
        [string]$TaskComplexity = "simple",

        [string[]]$ToolRequirements = @(),

        [int]$DependenciesCount = 0,

        [int]$FilesToModify = 0
    )

    $result = @{
        ShouldEscalate = $false
        RecommendedMode = $CurrentMode
        Reason = ""
    }

    # Layer 1: Scheduler escalation (orchestrator-simple -> orchestrator-complex)
    if ($CurrentMode -eq "orchestrator-simple") {
        # Escalation criteria for orchestrator-simple
        $escalate = $false
        $reasons = @()

        if ($FailureCount -ge 2) {
            $escalate = $true
            $reasons += "2 or more failures in orchestrator-simple"
        }

        if ($TaskComplexity -eq "complex") {
            $escalate = $true
            $reasons += "Complex task detected"
        }

        if ($DependenciesCount -ge 3) {
            $escalate = $true
            $reasons += "3 or more dependencies"
        }

        if ($FilesToModify -ge 3) {
            $escalate = $true
            $reasons += "3 or more files to modify"
        }

        if ($ToolRequirements -contains "command" -and -not ($ToolRequirements -contains "mcp")) {
            # Terminal required but not available via MCP
            $escalate = $true
            $reasons += "Terminal access required (not available in orchestrator-simple)"
        }

        if ($escalate) {
            $result.ShouldEscalate = $true
            $result.RecommendedMode = "orchestrator-complex"
            $result.Reason = $reasons -join "; "
        }
    }

    # Layer 2: Mode escalation (*-simple -> *-complex)
    elseif ($CurrentMode -match "-simple$") {
        $modeFamily = $CurrentMode -replace "-simple$", ""
        $escalate = $false
        $reasons = @()

        if ($FailureCount -ge 2) {
            $escalate = $true
            $reasons += "2 or more failures in $CurrentMode"
        }

        if ($TaskComplexity -eq "complex") {
            $escalate = $true
            $reasons += "Complex task requires -complex mode"
        }

        if ($FilesToModify -ge 3) {
            $escalate = $true
            $reasons += "3 or more files to modify"
        }

        if ($DependenciesCount -ge 3) {
            $escalate = $true
            $reasons += "3 or more dependencies"
        }

        if ($escalate) {
            $result.ShouldEscalate = $true
            $result.RecommendedMode = "$modeFamily-complex"
            $result.Reason = $reasons -join "; "
        }
    }

    # Layer 3: Orchestration escalation (switch between mode families)
    # This is handled by the orchestrator, not this function

    return $result
}

<#
.SYNOPSIS
    Gets the escalation chain for a given starting mode.

.DESCRIPTION
    Returns the full escalation chain from simplest to most complex
    for a given mode family.

.PARAMETER StartMode
    Starting mode (e.g., "code-simple", "debug-simple")

.PARAMETER ModeFamily
    Mode family: code, debug, ask (optional, auto-detected from StartMode)
#>
function Get-EscalationChain {
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory=$true)]
        [string]$StartMode,

        [string]$ModeFamily
    )

    if (-not $ModeFamily) {
        # Auto-detect mode family
        if ($StartMode -match "^(code|debug|ask|orchestrator)-") {
            $ModeFamily = $matches[1]
        } else {
            throw "Cannot detect mode family from $StartMode"
        }
    }

    $chains = @{
        "code" = @("code-simple", "code-complex", "orchestrator-complex")
        "debug" = @("debug-simple", "debug-complex", "orchestrator-complex")
        "ask" = @("ask-simple", "ask-complex", "orchestrator-complex")
        "orchestrator" = @("orchestrator-simple", "orchestrator-complex")
    }

    if ($chains.ContainsKey($ModeFamily)) {
        $chain = $chains[$ModeFamily]
        $startIndex = [array]::IndexOf($chain, $StartMode)
        if ($startIndex -ge 0) {
            return $chain[$startIndex..($chain.Length - 1)]
        }
    }

    throw "Unknown mode family: $ModeFamily"
}

<#
.SYNOPSIS
    Formats a delegation instruction for new_task.

.DESCRIPTION
    Creates a standardized delegation instruction string for use with
    the new_task tool in Roo orchestrator modes.

.PARAMETER TargetMode
    Target mode to delegate to

.PARAMETER TaskDescription
    Description of the task to delegate

.PARAMETER Context
    Additional context for the task (optional)

.PARAMETER Constraints
    Any constraints or limitations (optional)
#>
function Format-DelegationInstruction {
    [OutputType([string])]
    param(
        [Parameter(Mandatory=$true)]
        [string]$TargetMode,

        [Parameter(Mandatory=$true)]
        [string]$TaskDescription,

        [string]$Context,

        [string]$Constraints
    )

    $instruction = "DELEGUER à $TargetMode :`n`n$TaskDescription"

    if ($Context) {
        $instruction += "`n`nCONTEXTE :`n$Context"
    }

    if ($Constraints) {
        $instruction += "`n`nCONTRAINTES :`n$Constraints"
    }

    $instruction += "`n`nRAPPEL : TOUJOURS utiliser new_task pour déléguer. NE PAS faire le travail toi-même."

    return $instruction
}

<#
.SYNOPSIS
    Writes an escalation event to INTERCOM.

.DESCRIPTION
    Logs an escalation decision to INTERCOM for tracking and analysis.

.PARAMETER FromMode
    Mode being escalated from

.PARAMETER ToMode
    Mode being escalated to

.PARAMETER Reason
    Reason for escalation

.PARAMETER TaskContext
    Context about the task being escalated (optional)

.PARAMETER MachineName
    Machine name for INTERCOM file path (default: auto-detect)
#>
function Write-EscalationEvent {
    [OutputType([void])]
    param(
        [Parameter(Mandatory=$true)]
        [string]$FromMode,

        [Parameter(Mandatory=$true)]
        [string]$ToMode,

        [Parameter(Mandatory=$true)]
        [string]$Reason,

        [string]$TaskContext,

        [string]$MachineName = ($env:COMPUTERNAME).ToLower()
    )

    $content = "**Escalation:** $FromMode → $ToMode`n`n**Reason:** $Reason"

    if ($TaskContext) {
        $content += "`n`n**Task context:**`n$TaskContext"
    }

    Write-INTERCOMMessage -Type "INFO" -Title "Mode escalation" -Content $content -MachineName $MachineName
}

<#
.SYNOPSIS
    Evaluates if a task should start directly in complex mode.

.DESCRIPTION
    Determines whether a task is complex enough to skip simple mode
    and start directly in complex mode (avoiding wasted attempts).

.PARAMETER TaskDescription
    Description of the task

.PARAMETER EstimatedFiles
    Estimated number of files to modify

.PARAMETER HasDependencies
    Whether the task has sub-dependencies

.PARAMETER RequiresTerminal
    Whether the task requires terminal access

.PARAMETER PreviousAttempts
    Number of previous attempts (if any)
#>
function Test-SkipSimpleMode {
    [OutputType([hashtable])]
    param(
        [string]$TaskDescription,

        [int]$EstimatedFiles = 0,

        [switch]$HasDependencies,

        [switch]$RequiresTerminal,

        [int]$PreviousAttempts = 0
    )

    $result = @{
        ShouldSkip = $false
        RecommendedMode = "code-simple"
        Reason = ""
    }

    # Criteria for skipping simple mode
    if ($EstimatedFiles -ge 5) {
        $result.ShouldSkip = $true
        $result.RecommendedMode = "code-complex"
        $result.Reason = "5 or more files to modify"
    }

    if ($HasDependencies -and $EstimatedFiles -ge 3) {
        $result.ShouldSkip = $true
        $result.RecommendedMode = "code-complex"
        $result.Reason = "Multiple dependencies + 3+ files"
    }

    if ($RequiresTerminal) {
        $result.ShouldSkip = $true
        $result.RecommendedMode = "code-complex"
        $result.Reason = "Terminal access required"
    }

    if ($PreviousAttempts -ge 1) {
        $result.ShouldSkip = $true
        $result.RecommendedMode = "code-complex"
        $result.Reason = "$PreviousAttempts previous attempt(s) failed"
    }

    return $result
}

# Import INTERCOMReporting module for Write-INTERCOMMessage
Import-Module (Join-Path $PSScriptRoot "INTERCOMReporting.psm1") -ErrorAction SilentlyContinue

Export-ModuleMember -Function Test-EscalationCriteria, Get-EscalationChain, Format-DelegationInstruction, Write-EscalationEvent, Test-SkipSimpleMode
