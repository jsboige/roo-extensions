<#
.SYNOPSIS
    Copilot scheduler worker (Phase C fallback via gh copilot -p).

.DESCRIPTION
    Scheduled worker that validates prerequisites, executes a real non-interactive
    Copilot request through `gh copilot -p`, and records usage evidence.

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
$reportDir = Join-Path $repoRoot "outputs\scheduling\reports"
if (-not (Test-Path $reportDir)) { New-Item -ItemType Directory -Path $reportDir | Out-Null }
$reportFile = Join-Path $reportDir ("copilot-dispatcher-" + (Get-Date -Format "yyyyMMdd-HHmmss") + ".md")
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

function Get-DefaultState {
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

function ConvertTo-Hashtable {
    param([Parameter(ValueFromPipeline)]$InputObject)
    if ($null -eq $InputObject) { return @{} }
    if ($InputObject -is [System.Collections.IDictionary]) { return $InputObject }
    $ht = @{}
    $InputObject.PSObject.Properties | ForEach-Object { $ht[$_.Name] = $_.Value }
    return $ht
}

function Load-State {
    if (-not (Test-Path $stateFile)) {
        return Get-DefaultState
    }

    try {
        $json = Get-Content -Path $stateFile -Raw | ConvertFrom-Json
        # PS 5.1 returns PSCustomObject; PS 7+ with -AsHashtable returns hashtable.
        # Normalize to hashtable for consistent property access.
        if ($json -is [System.Collections.IDictionary]) { return $json }
        return ($json | ConvertTo-Hashtable)
    } catch {
        Write-Log "State file unreadable, resetting: $stateFile"
        return Get-DefaultState
    }
}

function Save-State {
    param([hashtable]$State)

    $json = $State | ConvertTo-Json -Depth 5
    [System.IO.File]::WriteAllText($stateFile, $json, [System.Text.UTF8Encoding]::new($false))
}

function Save-Report {
    param([string]$Content)

    if ([string]::IsNullOrWhiteSpace($Content)) {
        return
    }

    [System.IO.File]::WriteAllText($reportFile, $Content, [System.Text.UTF8Encoding]::new($false))
    Write-Log "Saved work report: $reportFile"
}

function Get-SanitizedReport {
    param([object[]]$Lines)

    $reportLines = @($Lines | ForEach-Object { [string]$_ })
    $startIndex = -1
    for ($index = 0; $index -lt $reportLines.Count; $index++) {
        if ($reportLines[$index] -match '^## ') {
            $startIndex = $index
            break
        }
    }

    if ($startIndex -ge 0) {
        $reportLines = $reportLines[$startIndex..($reportLines.Count - 1)]
    }

    $reportLines = $reportLines | Where-Object {
        $_ -notmatch '^(●|└|│)' -and
        $_ -notmatch '^Changes\s+' -and
        $_ -notmatch '^Requests\s+' -and
        $_ -notmatch '^Tokens\s+' -and
        $_ -notmatch '^What do you need me to do\?' -and
        $_ -notmatch '^I.m starting as the scheduled Copilot dispatcher' -and
        $_ -notmatch '^Let me ' -and
        $_ -notmatch '^\*\*Dispatcher session initiated' -and
        $_ -notmatch '^No active todos'
    }

    return (($reportLines -join "`n").Trim())
}

function Convert-JsonWorkReport {
    param([string]$RawOutput)

    if ([string]::IsNullOrWhiteSpace($RawOutput)) {
        return ''
    }

    $jsonMatches = [regex]::Matches($RawOutput, '\{[\s\S]*?\}')
    if ($jsonMatches.Count -eq 0) {
        return ''
    }

    for ($index = $jsonMatches.Count - 1; $index -ge 0; $index--) {
        $candidate = $jsonMatches[$index].Value
        try {
            $json = $candidate | ConvertFrom-Json
            $workSummary = [string]$json.work_summary
            $nextAction = [string]$json.next_action
            $risk = [string]$json.risk
            if ($workSummary -or $nextAction -or $risk) {
                return @(
                    '## Work Summary',
                    $workSummary,
                    '## Next Action',
                    $nextAction,
                    '## Risk',
                    $risk
                ) -join "`n"
            }
        } catch {
        }
    }

    return ''
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

function Invoke-PhaseCDispatch {
    param(
        [string]$Profile,
        [string]$RepositoryRoot,
        [string]$Prompt
    )

    $result = @{
        status = 'blocked'
        exitCode = -1
        premiumRequests = -1.0
        output = @()
        error = ''
        report = ''
    }

    try {
        Push-Location $RepositoryRoot
        # --allow-all-tools is REQUIRED for non-interactive mode (-p): without it,
        # Copilot cannot execute any tool (shell/file/git) and falls back to a
        # conversational "ready, standing by" no-op instead of doing real work
        # (gh copilot --help: "required for non-interactive mode", env COPILOT_ALLOW_ALL).
        # Refs: #622 (dispatcher consumed premium but produced no real work), user mandate.
        $cmdOutput = & gh copilot -p $Prompt --allow-all-tools 2>&1
        $exit = $LASTEXITCODE
        Pop-Location

        $result.exitCode = $exit
        $result.output = @($cmdOutput)
        $rawOutput = ($cmdOutput | Out-String)
        $result.report = Convert-JsonWorkReport -RawOutput $rawOutput
        if ([string]::IsNullOrWhiteSpace($result.report)) {
            $result.report = Get-SanitizedReport -Lines $cmdOutput
        }

        $joined = ($cmdOutput | Out-String)
        $match = [regex]::Match($joined, 'Requests\s+([0-9]+(?:\.[0-9]+)?)\s+Premium', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
        if ($match.Success) {
            $result.premiumRequests = [double]$match.Groups[1].Value
        }

        if ($exit -eq 0) {
            $result.status = 'active'
        } else {
            $result.status = 'blocked'
        }
    } catch {
        $result.error = $_.Exception.Message
        if ((Get-Location).Path -ne $RepositoryRoot) {
            try { Pop-Location } catch { }
        }
    }

    return $result
}

function Get-WorkPrompt {
    param(
        [string]$Profile,
        [hashtable]$State,
        [string]$RepositoryRoot
    )

    $gitSummary = ''
    try {
        $gitSummary = (& git -C $RepositoryRoot status --short --branch 2>$null | Select-Object -First 12) -join "`n"
    } catch {
        $gitSummary = ''
    }

    if ([string]::IsNullOrWhiteSpace($gitSummary)) {
        $gitSummary = 'clean-or-unavailable'
    }

    $previousStatus = if ($State.ContainsKey('lastStatus')) { [string]$State.lastStatus } else { 'none' }
    $lastObservedPremium = if ($State.ContainsKey('lastObservedPremiumRequests')) { [string]$State.lastObservedPremiumRequests } else { 'unknown' }

    return @"
You are the scheduled Copilot dispatcher for the repository roo-extensions.

Return exactly one JSON object with these keys:
- work_summary
- next_action
- risk

Constraints:
- The full response must be valid JSON only.
- No markdown.
- No code fences.
- Be concrete and repository-specific.
- Focus on useful fleet work, not acknowledgements.
- Never ask a question.
- Never mention tools, sessions, or interactive behavior in your output.
- Keep each value to one short sentence.

Investigation (ground your answer in real findings, not assumptions):
- Use available tools to inspect the repository: run `git log --oneline -10`, read recently changed files, check `gh issue list --state open --limit 20` for actionable work.
- Base work_summary and next_action on what you actually observe, so the dispatch consumes real analysis rather than producing a "ready, standing by" acknowledgement.

Context:
- Profile: $Profile
- Previous dispatcher status: $previousStatus
- Last observed premium requests: $lastObservedPremium
- Repository root: $RepositoryRoot
- Git status summary:
$gitSummary
"@
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

$dispatch = $null
if ($status -ne 'blocked') {
    if ($DryRun) {
        Write-Log "DryRun: skipping gh copilot execution"
    } else {
        $workPrompt = Get-WorkPrompt -Profile $effectiveProfile -State (Load-State) -RepositoryRoot $repoRoot
        Write-Log "Executing Phase C fallback via gh copilot -p"
        $dispatch = Invoke-PhaseCDispatch -Profile $effectiveProfile -RepositoryRoot $repoRoot -Prompt $workPrompt
        $status = [string]$dispatch.status
        if ($dispatch.exitCode -eq 0) {
            Write-Log "Phase C execution success (exit=0)"
            if ($dispatch.premiumRequests -ge 0) {
                Write-Log "Observed Copilot premium requests: $($dispatch.premiumRequests)"
            } else {
                Write-Log "Copilot output did not expose premium usage metric"
            }
            Save-Report -Content $dispatch.report
        } else {
            Write-Log "Phase C execution failed (exit=$($dispatch.exitCode))"
            if ($dispatch.error) {
                Write-Log "Dispatch error: $($dispatch.error)"
            }
            if ($dispatch.output.Count -gt 0) {
                $tailLines = $dispatch.output | Select-Object -Last 6
                foreach ($line in $tailLines) {
                    Write-Log "Dispatch output: $line"
                }
            }
        }
    }
}

$state = Load-State
Write-Log "GitHub issue comment channel disabled for scheduled routine runs"

if ($status -eq "blocked") {
    $state.consecutiveBlocked = [int]$state.consecutiveBlocked + 1
    $state.consecutiveIdle = 0
} elseif ($status -eq 'active') {
    $state.consecutiveIdle = 0
    $state.consecutiveBlocked = 0
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
if ($dispatch) {
    $state.lastDispatchStatus = [string]$dispatch.status
    $state.lastDispatchExitCode = [int]$dispatch.exitCode
    if ($dispatch.premiumRequests -ge 0) {
        $state.lastObservedPremiumRequests = [double]$dispatch.premiumRequests
    }
    if (-not [string]::IsNullOrWhiteSpace($dispatch.report)) {
        $state.lastReportFile = $reportFile
    }
}

if ($target -ne 'none') {
    Register-Escalation -State $state
    Write-Log "Escalation requested: $target"
} else {
    Write-Log "No escalation required"
}

Save-State -State $state

if ($DryRun) {
    Write-Log "DryRun mode: no external actions"
    exit 0
}

if ($status -eq 'active') {
    Write-Log "Phase C fallback complete (real Copilot request executed)."
} elseif ($status -eq 'blocked') {
    Write-Log "Phase C fallback blocked (check gh copilot auth/runtime)."
} else {
    Write-Log "Phase C fallback ended idle."
}
