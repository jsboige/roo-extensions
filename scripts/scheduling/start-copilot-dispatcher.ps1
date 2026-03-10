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
    [double]$PremiumUsagePercent = -1,
    [double]$SoftUsageCapPercent = 70,
    [double]$HardUsageCapPercent = 90,
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
$budgetPolicyPath = Join-Path $stateDir "copilot-budget.json"

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
        [hashtable]$State,
        [string]$EffectiveProfile
    )

    if ($Status -eq "blocked" -and $State.consecutiveBlocked -ge $MaxConsecutiveBlocked) {
        switch ($EffectiveProfile) {
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

function Get-PremiumUsagePercent {
    if ($PremiumUsagePercent -ge 0) {
        return [double]$PremiumUsagePercent
    }

    if (Test-Path $budgetPolicyPath) {
        try {
            $policy = Get-Content -Path $budgetPolicyPath -Raw | ConvertFrom-Json -AsHashtable
            if ($policy.ContainsKey('premiumUsagePercent')) {
                return [double]$policy.premiumUsagePercent
            }
        } catch {
            Write-Log "Budget policy unreadable, ignoring: $budgetPolicyPath"
        }
    }

    $envValue = $env:COPILOT_PREMIUM_USAGE_PERCENT
    if ($envValue) {
        try {
            return [double]$envValue
        } catch {
            Write-Log "Invalid COPILOT_PREMIUM_USAGE_PERCENT value: $envValue"
        }
    }

    return -1
}

function Resolve-EffectiveProfile {
    param(
        [string]$RequestedProfile,
        [double]$UsagePercent
    )

    if ($UsagePercent -lt 0) {
        return $RequestedProfile
    }

    if ($UsagePercent -ge $HardUsageCapPercent) {
        return 'low'
    }

    if ($UsagePercent -ge $SoftUsageCapPercent) {
        switch ($RequestedProfile) {
            'throughput' { return 'balanced' }
            default { return 'low' }
        }
    }

    return $RequestedProfile
}

Write-Log "Copilot dispatcher started"
Write-Log "RepoRoot=$repoRoot"
Write-Log "BudgetProfile=$BudgetProfile SoftCap=$SoftUsageCapPercent HardCap=$HardUsageCapPercent BlockedThreshold=$MaxConsecutiveBlocked IdleThreshold=$MaxConsecutiveIdle"

$usagePercent = Get-PremiumUsagePercent
if ($usagePercent -ge 0) {
    Write-Log "PremiumUsagePercent=$usagePercent"
} else {
    Write-Log "PremiumUsagePercent=unknown (no telemetry configured)"
}

$effectiveProfile = Resolve-EffectiveProfile -RequestedProfile $BudgetProfile -UsagePercent $usagePercent
if ($effectiveProfile -ne $BudgetProfile) {
    Write-Log "Budget guard active: profile downgraded to $effectiveProfile"
}

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

$target = Resolve-EscalationTarget -Status $status -State $state -EffectiveProfile $effectiveProfile
$state.lastStatus = $status
$state.lastEscalation = $target
$state.lastRequestedProfile = $BudgetProfile
$state.lastEffectiveProfile = $effectiveProfile
$state.lastPremiumUsagePercent = $usagePercent

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
