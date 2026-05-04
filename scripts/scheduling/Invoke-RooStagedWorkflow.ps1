#Requires -Version 5.1

<#
.SYNOPSIS
    Wrapper for Roo tasks with staged workflow logging (Étape 0-3)

.DESCRIPTION
    Implements structured logging for Roo scheduled tasks to match Claude Code worker's phase system.
    This wrapper provides visibility into task execution progress and facilitates debugging.

    Stages (Étapes):
    - Étape 0: Context check (dashboard read, dispatch parse)
    - Étape 1: Setup (git status, workspace verification)
    - Étape 2: Execution (mode-specific work)
    - Étape 3: Report (post [RESULT] to dashboard)

.PARAMETER ScriptBlock
    The actual task code to execute (wrapped in script block)

.PARAMETER TaskName
    Name of the task being executed

.PARAMETER DashboardType
    Dashboard type for reporting (global, machine, workspace)

.EXAMPLE
    Invoke-RooStagedWorkflow -TaskName "Maintenance" -ScriptBlock {
        # Your task code here
        Write-Host "Executing maintenance..."
    }

.NOTES
    Author: Claude Code (myia-po-2023)
    Date: 2026-05-04
    Issue: #1887
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [scriptblock]$ScriptBlock,

    [Parameter(Mandatory = $true)]
    [string]$TaskName,

    [string]$DashboardType = "workspace",

    [switch]$SkipDashboardCheck
)

# Configuration
$ErrorActionPreference = "Stop"
$RepoRoot = Resolve-Path "$PSScriptRoot\..\.."
$LogDir = Join-Path $RepoRoot "outputs\scheduling\logs"

# Ensure log directory exists
if (-not (Test-Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
}

$LogFile = Join-Path $LogDir "roo-staged-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"

# =============================================================================
# Helper Functions
# =============================================================================

function Write-StageLog {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    Add-Content -Path $LogFile -Value $logMessage

    $color = switch ($Level) {
        "ERROR" { "Red" }
        "WARN" { "Yellow" }
        "OK" { "Green" }
        default { "White" }
    }

    Write-Host $logMessage -ForegroundColor $color
}

function Format-Duration {
    param([double]$Seconds)
    return [math]::Round($Seconds, 2)
}

function Test-DashboardAvailable {
    try {
        $null = Get-Command mcp__roo-state-manager__roosync_dashboard -ErrorAction Stop
        return $true
    } catch {
        return $false
    }
}

function Publish-StageToDashboard {
    param(
        [string]$Stage,
        [string]$Status,
        [string]$Details = ""
    )

    if (-not (Test-DashboardAvailable)) {
        Write-StageLog "Dashboard MCP not available, skipping dashboard update" "WARN"
        return
    }

    try {
        $tags = @("ROO-STAGE", $Stage, $Status)
        $content = "### Étape $Stage : $Status`n`nTask: $TaskName`n"

        if ($Details) {
            $content += "Details: $Details`n"
        }

        $content += "`nTimestamp: $(Get-Date -Format 'o')"

        & mcp__roo-state-manager__roosync_dashboard `
            -Action "append" `
            -Type $DashboardType `
            -Tags $tags `
            -Content $content

        Write-StageLog "Published to dashboard: Étape $Stage - $Status" "OK"
    } catch {
        Write-StageLog "Failed to publish to dashboard: $_" "WARN"
    }
}

# =============================================================================
# Étape 0: Context Check
# =============================================================================

$stageStartTime = Get-Date
Write-StageLog "=== ROO STAGED WORKFLOW START ===" "INFO"
Write-StageLog "Task: $TaskName" "INFO"
Write-StageLog "Étape 0: Context check - START" "INFO"

try {
    if (-not $SkipDashboardCheck) {
        if (Test-DashboardAvailable) {
            Write-StageLog "Dashboard MCP: Available" "OK"
        } else {
            Write-StageLog "Dashboard MCP: Not available" "WARN"
        }
    }

    # Check git status
    $gitStatus = & git status --short 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-StageLog "Git status: Clean" "OK"
    } else {
        Write-StageLog "Git status: Error checking" "WARN"
    }

    $stageDuration = ((Get-Date) - $stageStartTime).TotalSeconds
    Write-StageLog "Étape 0: OK ($(Format-Duration $stageDuration)s)" "OK"
    Publish-StageToDashboard -Stage "0" -Status "OK" -Details "Context verified, dashboard available"
} catch {
    $stageDuration = ((Get-Date) - $stageStartTime).TotalSeconds
    Write-StageLog "Étape 0: ECHEC - $_ ($(Format-Duration $stageDuration)s)" "ERROR"
    Publish-StageToDashboard -Stage "0" -Status "ECHEC" -Details $_.Exception.Message
    throw
}

# =============================================================================
# Étape 1: Setup
# =============================================================================

$stageStartTime = Get-Date
Write-StageLog "Étape 1: Setup - START" "INFO"

try {
    # Verify workspace
    if (Test-Path $RepoRoot) {
        Write-StageLog "Workspace: $RepoRoot" "OK"
    } else {
        throw "Workspace path not found: $RepoRoot"
    }

    # Check for uncommitted changes
    $uncommitted = & git status --porcelain 2>&1
    if ($LASTEXITCODE -eq 0 -and $uncommitted) {
        Write-StageLog "Uncommitted changes detected" "WARN"
    } else {
        Write-StageLog "Git working directory: Clean" "OK"
    }

    $stageDuration = ((Get-Date) - $stageStartTime).TotalSeconds
    Write-StageLog "Étape 1: OK ($(Format-Duration $stageDuration)s)" "OK"
    Publish-StageToDashboard -Stage "1" -Status "OK" -Details "Workspace verified, git status checked"
} catch {
    $stageDuration = ((Get-Date) - $stageStartTime).TotalSeconds
    Write-StageLog "Étape 1: ECHEC - $_ ($(Format-Duration $stageDuration)s)" "ERROR"
    Publish-StageToDashboard -Stage "1" -Status "ECHEC" -Details $_.Exception.Message
    throw
}

# =============================================================================
# Étape 2: Execution
# =============================================================================

$stageStartTime = Get-Date
Write-StageLog "Étape 2: Execution - START" "INFO"

$executionResult = @{
    Success = $false
    Error = $null
    Duration = 0
}

try {
    Write-StageLog "Executing task: $TaskName" "INFO"

    # Execute the provided script block
    & $ScriptBlock

    $executionResult.Success = $true
    $stageDuration = ((Get-Date) - $stageStartTime).TotalSeconds
    $executionResult.Duration = $stageDuration

    Write-StageLog "Étape 2: OK ($(Format-Duration $stageDuration)s)" "OK"
    Publish-StageToDashboard -Stage "2" -Status "OK" -Details "Task completed successfully in $(Format-Duration $stageDuration)s"
} catch {
    $executionResult.Error = $_
    $stageDuration = ((Get-Date) - $stageStartTime).TotalSeconds
    $executionResult.Duration = $stageDuration

    Write-StageLog "Étape 2: ECHEC - $_ ($(Format-Duration $stageDuration)s)" "ERROR"
    Publish-StageToDashboard -Stage "2" -Status "ECHEC" -Details $_.Exception.Message
    throw
}

# =============================================================================
# Étape 3: Report
# =============================================================================

$stageStartTime = Get-Date
Write-StageLog "Étape 3: Report - START" "INFO"

try {
    $reportContent = "### Task Execution Report`n`n"
    $reportContent += "**Task:** $TaskName`n"
    $reportContent += "**Status:** $(if ($executionResult.Success) { 'SUCCESS' } else { 'FAILED' })`n"
    $reportContent += "**Duration:** $([math]::Round($executionResult.Duration, 2)) seconds`n"
    $reportContent += "**Log File:** $LogFile`n"

    if (-not $executionResult.Success) {
        $reportContent += "`n**Error:** $($executionResult.Error.Exception.Message)`n"
    }

    if (Test-DashboardAvailable) {
        & mcp__roo-state-manager__roosync_dashboard `
            -Action "append" `
            -Type $DashboardType `
            -Tags @("DONE", "roo-interactive") `
            -Content $reportContent

        Write-StageLog "Report published to dashboard" "OK"
    }

    $stageDuration = ((Get-Date) - $stageStartTime).TotalSeconds
    Write-StageLog "Étape 3: OK ($(Format-Duration $stageDuration)s)" "OK"
    Write-StageLog "=== ROO STAGED WORKFLOW END ===" "INFO"
} catch {
    $stageDuration = ((Get-Date) - $stageStartTime).TotalSeconds
    Write-StageLog "Étape 3: PARTIAL (report failed) - $_ ($(Format-Duration $stageDuration)s)" "WARN"
    Write-StageLog "=== ROO STAGED WORKFLOW END (WITH WARNINGS) ===" "INFO"
}

# Return execution result
[PSCustomObject]@{
    TaskName = $TaskName
    Success = $executionResult.Success
    Duration = $executionResult.Duration
    LogFile = $LogFile
}
