<#
.SYNOPSIS
    Copilot scheduler bridge worker (Phase B).

.DESCRIPTION
    Transitional worker for regular cadence without full headless Copilot runtime.
    It validates prerequisites and emits a traceable heartbeat-style log.

    Future Phase C can replace this with actual task execution once a stable
    headless Copilot runtime is validated.

.PARAMETER DryRun
    Print actions only.
#>

[CmdletBinding()]
param(
    [ValidateSet('low','balanced','throughput')]
    [string]$BudgetProfile = 'balanced',
    [int]$MaxConsecutiveBlocked = 2,
    [int]$MaxConsecutiveIdle = 4,
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = (Split-Path (Split-Path $scriptDir -Parent) -Parent)
$logDir = Join-Path $repoRoot ".claude\logs"
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir | Out-Null }
$logFile = Join-Path $logDir ("copilot-dispatcher-" + (Get-Date -Format "yyyyMMdd-HHmmss") + ".log")
$stateDir = Join-Path $repoRoot ".claude\scheduler"
if (-not (Test-Path $stateDir)) { New-Item -ItemType Directory -Path $stateDir | Out-Null }
$stateFile = Join-Path $stateDir "copilot-dispatcher-state.json"

function Write-Log {
    param([string]$Message)
    $line = "[{0}] [INFO] {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Message
    Write-Host $line
    Add-Content -Path $logFile -Value $line
}

function Load-State {
    if (-not (Test-Path $stateFile)) {
        return @{
            consecutiveBlocked = 0
            consecutiveIdle = 0
            lastStatus = "none"
            lastEscalation = "none"
        }
    }

    try {
        return (Get-Content -Path $stateFile -Raw | ConvertFrom-Json -AsHashtable)
    } catch {
        Write-Log "State file unreadable, resetting: $stateFile"
        return @{
            consecutiveBlocked = 0
            consecutiveIdle = 0
            lastStatus = "none"
            lastEscalation = "none"
        }
    }
}

function Save-State {
    param([hashtable]$State)

    $json = $State | ConvertTo-Json -Depth 5
    [System.IO.File]::WriteAllText($stateFile, $json, [System.Text.UTF8Encoding]::new($false))
}

function Resolve-EscalationTarget {
    param(
        [string]$Status,
        [hashtable]$State
    )

    if ($Status -eq "blocked" -and $State.consecutiveBlocked -ge $MaxConsecutiveBlocked) {
        switch ($BudgetProfile) {
            'low' { return 'claude-worker-haiku' }
            'balanced' { return 'claude-worker-sonnet' }
            'throughput' { return 'claude-worker-opus' }
        }
    }

    if ($Status -eq "idle" -and $State.consecutiveIdle -ge $MaxConsecutiveIdle) {
        return 'coordinator-review-cadence'
    }

    return 'none'
}

Write-Log "Copilot dispatcher started"
Write-Log "RepoRoot=$repoRoot"
Write-Log "BudgetProfile=$BudgetProfile BlockedThreshold=$MaxConsecutiveBlocked IdleThreshold=$MaxConsecutiveIdle"

$copilotConfig = Join-Path $HOME ".copilot\mcp-config.json"
$status = "idle"
if (Test-Path $copilotConfig) {
    Write-Log "Found Copilot MCP config: $copilotConfig"
} else {
    Write-Log "Copilot MCP config missing: $copilotConfig"
    $status = "blocked"
}

$state = Load-State
if ($status -eq "blocked") {
    $state.consecutiveBlocked = [int]$state.consecutiveBlocked + 1
    $state.consecutiveIdle = 0
} else {
    $state.consecutiveIdle = [int]$state.consecutiveIdle + 1
    $state.consecutiveBlocked = 0
}

$target = Resolve-EscalationTarget -Status $status -State $state
$state.lastStatus = $status
$state.lastEscalation = $target

if ($target -ne 'none') {
    Write-Log "Escalation requested: $target"
} else {
    Write-Log "No escalation required"
}

Save-State -State $state

if ($DryRun) {
    Write-Log "DryRun mode: no external actions"
    exit 0
}

# Phase B behavior intentionally conservative: keep regular cadence + observability
# without assuming a stable headless Copilot executor is available.
Write-Log "Phase B bridge complete (no-op dispatch)."
Write-Log "Next step: upgrade to Phase C when headless execution is validated."
