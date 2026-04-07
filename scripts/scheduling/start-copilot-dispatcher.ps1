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
    [int]$IssueNumber = 0,
    [double]$PremiumUsagePercent = -1,
    [double]$SoftUsageCapPercent = 70,
    [double]$HardUsageCapPercent = 90,
    [int]$MaxConsecutiveBlocked = 2,
    [int]$MaxConsecutiveIdle = 4,
    [int]$MinEscalationIntervalMinutes = 180,
    [int]$MaxEscalationsPerDay = 3,
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = (Split-Path (Split-Path $scriptDir -Parent) -Parent)
$logDir = if (-not [string]::IsNullOrWhiteSpace($env:COPILOT_DISPATCHER_LOG_DIR)) {
    $env:COPILOT_DISPATCHER_LOG_DIR
} else {
    Join-Path $repoRoot "outputs\scheduling\logs"
}
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
            lastEscalationAt = ""
            escalationWindowStart = ""
            escalationsInWindow = 0
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
            lastEscalationAt = ""
            escalationWindowStart = ""
            escalationsInWindow = 0
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

function Test-EscalationAllowed {
    param([hashtable]$State)

    $now = Get-Date

    if (-not $State.ContainsKey('escalationWindowStart') -or [string]::IsNullOrWhiteSpace([string]$State.escalationWindowStart)) {
        return $true
    }

    try {
        $windowStart = [DateTime]::Parse([string]$State.escalationWindowStart)
        if (($now - $windowStart).TotalHours -ge 24) {
            return $true
        }
    } catch {
        return $true
    }

    $count = [int]$State.escalationsInWindow
    if ($count -ge $MaxEscalationsPerDay) {
        Write-Log "Escalation guardrail active: MaxEscalationsPerDay reached ($count/$MaxEscalationsPerDay)"
        return $false
    }

    if ($State.ContainsKey('lastEscalationAt') -and -not [string]::IsNullOrWhiteSpace([string]$State.lastEscalationAt)) {
        try {
            $lastEscalation = [DateTime]::Parse([string]$State.lastEscalationAt)
            if (($now - $lastEscalation).TotalMinutes -lt $MinEscalationIntervalMinutes) {
                Write-Log "Escalation guardrail active: cooldown not reached (min $MinEscalationIntervalMinutes min)"
                return $false
            }
        } catch {
            return $true
        }
    }

    return $true
}

function Register-Escalation {
    param([hashtable]$State)

    $now = Get-Date

    if (-not $State.ContainsKey('escalationWindowStart') -or [string]::IsNullOrWhiteSpace([string]$State.escalationWindowStart)) {
        $State.escalationWindowStart = $now.ToString('o')
        $State.escalationsInWindow = 1
    } else {
        try {
            $windowStart = [DateTime]::Parse([string]$State.escalationWindowStart)
            if (($now - $windowStart).TotalHours -ge 24) {
                $State.escalationWindowStart = $now.ToString('o')
                $State.escalationsInWindow = 1
            } else {
                $State.escalationsInWindow = [int]$State.escalationsInWindow + 1
            }
        } catch {
            $State.escalationWindowStart = $now.ToString('o')
            $State.escalationsInWindow = 1
        }
    }

    $State.lastEscalationAt = $now.ToString('o')
}

function Test-GitHubIssueLock {
    param([int]$Issue)

    if ($Issue -le 0) { return $false }

    try {
        $commentsJson = & gh issue view $Issue --repo jsboige/roo-extensions --json comments --jq '.comments[-3:]' 2>$null
        if ($LASTEXITCODE -ne 0 -or -not $commentsJson) { return $false }

        $comments = $commentsJson | ConvertFrom-Json
        foreach ($comment in $comments) {
            $body = [string]$comment.body
            $createdAt = [DateTime]::Parse($comment.createdAt)
            $age = (Get-Date).ToUniversalTime() - $createdAt.ToUniversalTime()
            if (($body -match 'LOCK:' -or $body -match 'Claimed by') -and $age.TotalMinutes -lt 5) {
                return $true
            }
        }
    } catch {
        return $false
    }

    return $false
}

function Test-RecentIdleOnIssue {
    param([int]$Issue)

    if ($Issue -le 0) { return $false }

    try {
        $commentsJson = & gh issue view $Issue --repo jsboige/roo-extensions --json comments --jq '.comments[-10:]' 2>$null
        if ($LASTEXITCODE -ne 0 -or -not $commentsJson) { return $false }

        $comments = $commentsJson | ConvertFrom-Json
        foreach ($comment in $comments) {
            $body = [string]$comment.body
            $createdAt = [DateTime]::Parse($comment.createdAt)
            $age = (Get-Date).ToUniversalTime() - $createdAt.ToUniversalTime()
            if ($body -match 'agent: copilot-dispatcher' -and $body -match 'result: idle' -and $age.TotalHours -lt 24) {
                return $true
            }
        }
    } catch {
        return $false
    }

    return $false
}

function Write-GitHubIssueComment {
    param(
        [int]$Issue,
        [string]$Body
    )

    if ($Issue -le 0 -or [string]::IsNullOrWhiteSpace($Body)) {
        return
    }

    try {
        & gh issue comment $Issue --repo jsboige/roo-extensions --body $Body 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-Log "Posted GitHub comment to issue #$Issue"
        } else {
            Write-Log "Unable to post GitHub comment to issue #$Issue"
        }
    } catch {
        Write-Log "Unable to post GitHub comment to issue #$Issue"
    }
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
Write-Log "IssueNumber=$IssueNumber EscalationCooldownMinutes=$MinEscalationIntervalMinutes MaxEscalationsPerDay=$MaxEscalationsPerDay"

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

$copilotConfigCandidates = @(
    (Join-Path $env:APPDATA "Code\User\mcp.json"),
    (Join-Path $HOME ".copilot\mcp-config.json")
)
$copilotConfig = $null
$copilotConfig = $copilotConfigCandidates | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1
$status = "idle"
if ($copilotConfig) {
    Write-Log "Found Copilot MCP config: $copilotConfig"
} else {
    Write-Log "Copilot MCP config missing: checked $($copilotConfigCandidates -join ', ')"
    $status = "blocked"
}

$state = Load-State

$skipClaim = $false
if ($IssueNumber -gt 0 -and -not $DryRun) {
    if (Test-RecentIdleOnIssue -Issue $IssueNumber) {
        Write-Log "Skipping claim on issue #$IssueNumber — recent idle by copilot-dispatcher within 24h (spin-loop guard)"
        $skipClaim = $true
    } elseif (Test-GitHubIssueLock -Issue $IssueNumber) {
        Write-Log "Lock active on issue #$IssueNumber (recent claim)"
        $skipClaim = $true
    } else {
        $claimTimestamp = Get-Date -Format "o"
        Write-GitHubIssueComment -Issue $IssueNumber -Body "Claimed by copilot-dispatcher on $($env:COMPUTERNAME.ToLower()) at $claimTimestamp"
        Write-GitHubIssueComment -Issue $IssueNumber -Body "STATUS: started`nagent: copilot-dispatcher`nmachine: $($env:COMPUTERNAME.ToLower())`nmode: scheduled`nprofile: $effectiveProfile"
    }
}

if ($status -eq "blocked") {
    $state.consecutiveBlocked = [int]$state.consecutiveBlocked + 1
    $state.consecutiveIdle = 0
} else {
    $state.consecutiveIdle = [int]$state.consecutiveIdle + 1
    $state.consecutiveBlocked = 0
}

$target = Resolve-EscalationTarget -Status $status -State $state -EffectiveProfile $effectiveProfile
if ($target -ne 'none' -and -not (Test-EscalationAllowed -State $state)) {
    Write-Log "Escalation suppressed by guardrails"
    $target = 'none'
}

$state.lastStatus = $status
$state.lastEscalation = $target
$state.lastRequestedProfile = $BudgetProfile
$state.lastEffectiveProfile = $effectiveProfile
$state.lastPremiumUsagePercent = $usagePercent
if ($IssueNumber -gt 0) {
    $state.lastIssueNumber = $IssueNumber
}

if ($target -ne 'none') {
    Register-Escalation -State $state
    Write-Log "Escalation requested: $target"
    if ($IssueNumber -gt 0 -and -not $DryRun) {
        $handoffPayload = @(
            "STATUS: blocked",
            "agent: copilot-dispatcher",
            "machine: $($env:COMPUTERNAME.ToLower())",
            "resume_when: github_comment|intercom_message|timeout_hours:3",
            "handoff_target: $target",
            "handoff_reason: repeated_$status"
        ) -join "`n"
        Write-GitHubIssueComment -Issue $IssueNumber -Body $handoffPayload
    }
} else {
    Write-Log "No escalation required"
    if ($IssueNumber -gt 0 -and -not $DryRun -and -not $skipClaim) {
        Write-GitHubIssueComment -Issue $IssueNumber -Body "STATUS: done`nagent: copilot-dispatcher`nresult: $status`nescalation: none"
    }
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
