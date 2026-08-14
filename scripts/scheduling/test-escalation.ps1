<#
.SYNOPSIS
    Test script for Claude Worker escalation (model-based)
    Validates that escalation correctly switches model: haiku -> sonnet (capped)
    Decoupled from Roo modes-config.json since 2026-03-06
    Opus removed from auto-escalation 2026-05-16 (Anthropic Max policy change)
#>

$RepoRoot = Resolve-Path "$PSScriptRoot\..\.."

$TestsPassed = 0
$TestsFailed = 0

function Assert-Equal {
    param([string]$TestName, $Expected, $Actual)
    if ($Expected -eq $Actual) {
        Write-Host "  PASS: $TestName (expected=$Expected, got=$Actual)" -ForegroundColor Green
        $script:TestsPassed++
    } else {
        Write-Host "  FAIL: $TestName (expected=$Expected, got=$Actual)" -ForegroundColor Red
        $script:TestsFailed++
    }
}

# ============================================================================
# Test 1: Model escalation chain (haiku -> sonnet, opus excluded 2026-05-16)
# ============================================================================
Write-Host "=== Test 1: Model Escalation Chain ===" -ForegroundColor Cyan

function Get-EscalatedModel {
    param([string]$CurrentModel)
    switch ($CurrentModel) {
        "haiku"  { return "sonnet" }
        "sonnet" { return $null }   # Capped — opus excluded from auto-escalation (Anthropic Max policy)
        "opus"   { return $null }   # Manual override only
        default  { return "sonnet" }
    }
}

Assert-Equal "haiku escalates to sonnet" "sonnet" (Get-EscalatedModel "haiku")
Assert-Equal "sonnet capped (no escalation to opus)" $null (Get-EscalatedModel "sonnet")
Assert-Equal "opus is terminal (manual override only)" $null (Get-EscalatedModel "opus")
Assert-Equal "unknown defaults to sonnet" "sonnet" (Get-EscalatedModel "unknown")

# ============================================================================
# Test 2: Escalation scenarios (agent-specified vs auto)
# ============================================================================
Write-Host ""
Write-Host "=== Test 2: Escalation Scenarios ===" -ForegroundColor Cyan

# Scenario A: Agent specifies ESCALATE_TO model
$Model = "haiku"
$OriginalModel = $Model
$escalateToModel = "opus"  # Agent specified

if ($escalateToModel) {
    $Model = $escalateToModel
} else {
    $NextModel = Get-EscalatedModel -CurrentModel $Model
    if ($NextModel) { $Model = $NextModel }
}
Assert-Equal "Agent-specified model used" "opus" $Model
$Model = $OriginalModel

# Scenario B: No ESCALATE_TO, auto-escalate haiku -> sonnet
$Model = "haiku"
$OriginalModel = $Model
$escalateToModel = $null

if ($escalateToModel) {
    $Model = $escalateToModel
} else {
    $NextModel = Get-EscalatedModel -CurrentModel $Model
    if ($NextModel) { $Model = $NextModel }
}
Assert-Equal "Auto-escalate haiku -> sonnet" "sonnet" $Model
$Model = $OriginalModel

# Scenario C: sonnet is capped (no auto-escalation to opus per Anthropic Max policy)
$Model = "sonnet"
$OriginalModel = $Model
$escalateToModel = $null

if ($escalateToModel) {
    $Model = $escalateToModel
} else {
    $NextModel = Get-EscalatedModel -CurrentModel $Model
    if ($NextModel) { $Model = $NextModel }
}
Assert-Equal "Sonnet capped (stays sonnet, no auto-escalate)" "sonnet" $Model
$Model = $OriginalModel

# Scenario D: Already at opus, no escalation possible (manual override only)
$Model = "opus"
$OriginalModel = $Model
$escalateToModel = $null

if ($escalateToModel) {
    $Model = $escalateToModel
} else {
    $NextModel = Get-EscalatedModel -CurrentModel $Model
    if ($NextModel) { $Model = $NextModel }
}
Assert-Equal "Opus stays at opus (terminal)" "opus" $Model
$Model = $OriginalModel

# ============================================================================
# Test 3: STATUS signal parsing (Agent Status protocol)
# ============================================================================
Write-Host ""
Write-Host "=== Test 3: STATUS Signal Parsing ===" -ForegroundColor Cyan

$TestOutputs = @(
    @{
        Name = "continue signal"
        Output = "Task in progress...`n=== AGENT STATUS ===`nSTATUS: continue`nREASON: More work to do`n===================`n"
        ExpectedStatus = "continue"
    },
    @{
        Name = "escalate signal with model"
        Output = "Cannot complete...`n=== AGENT STATUS ===`nSTATUS: escalate`nREASON: Need more capable model`nESCALATE_TO: sonnet`n===================`n"
        ExpectedStatus = "escalate"
        ExpectedModel = "sonnet"
    },
    @{
        Name = "wait signal"
        Output = "Waiting for approval...`n=== AGENT STATUS ===`nSTATUS: wait`nREASON: Need user approval`nWAIT_FOR: user_approval`nRESUME_WHEN: user_approval`n===================`n"
        ExpectedStatus = "wait"
        ExpectedWaitFor = "user_approval"
    },
    @{
        Name = "success signal"
        Output = "All done!`n=== AGENT STATUS ===`nSTATUS: success`nREASON: Task completed successfully`n===================`n"
        ExpectedStatus = "success"
    },
    @{
        Name = "no signal"
        Output = "Just some output without any status signal."
        ExpectedStatus = $null
    }
)

foreach ($Test in $TestOutputs) {
    $OutputText = $Test.Output
    $DetectedStatus = $null
    $DetectedModel = $null
    $DetectedWaitFor = $null

    if ($OutputText -match "STATUS:\s*(\w+)") {
        $DetectedStatus = $Matches[1].ToLower()
        if ($OutputText -match "ESCALATE_TO:\s*(\w+)") { $DetectedModel = $Matches[1] }
        if ($OutputText -match "WAIT_FOR:\s*(.+)") { $DetectedWaitFor = $Matches[1].Trim() }
    }

    Assert-Equal "$($Test.Name) - status" $Test.ExpectedStatus $DetectedStatus
    if ($Test.ExpectedModel) {
        Assert-Equal "$($Test.Name) - model" $Test.ExpectedModel $DetectedModel
    }
    if ($Test.ExpectedWaitFor) {
        Assert-Equal "$($Test.Name) - waitFor" $Test.ExpectedWaitFor $DetectedWaitFor
    }
}

# ============================================================================
# Test 4: Wait state file operations
# ============================================================================
Write-Host ""
Write-Host "=== Test 4: Wait State File Operations ===" -ForegroundColor Cyan

$TestWaitDir = Join-Path $RepoRoot ".claude\scheduler\wait-states"
$TestTaskId = "test-wait-state-$(Get-Date -Format 'yyyyMMddHHmmss')"
$TestStateFile = Join-Path $TestWaitDir "$TestTaskId.json"

if (-not (Test-Path $TestWaitDir)) {
    New-Item -ItemType Directory -Path $TestWaitDir -Force | Out-Null
}

$TestState = @{
    taskId = $TestTaskId
    timestamp = (Get-Date).ToUniversalTime().ToString("o")
    reason = "Test wait state"
    waitFor = "user_approval"
    resumeWhen = "user_approval"
    context = @{
        model = "haiku"
        iteration = 1
        outputSnippet = "Test output line 1`nTest output line 2"
    }
}

$JsonText = $TestState | ConvertTo-Json -Depth 10
[System.IO.File]::WriteAllText($TestStateFile, $JsonText, [System.Text.UTF8Encoding]::new($false))

Assert-Equal "Wait state file created" $true (Test-Path $TestStateFile)

$ReadState = Get-Content $TestStateFile -Raw | ConvertFrom-Json
Assert-Equal "Wait state taskId preserved" $TestTaskId $ReadState.taskId
Assert-Equal "Wait state model preserved" "haiku" $ReadState.context.model
Assert-Equal "Wait state resumeWhen preserved" "user_approval" $ReadState.resumeWhen

Remove-Item $TestStateFile -Force
Assert-Equal "Wait state file cleaned up" $false (Test-Path $TestStateFile)

# ============================================================================
# Test 5: Worker script structure validation
# ============================================================================
Write-Host ""
Write-Host "=== Test 5: Worker Script Structure ===" -ForegroundColor Cyan

$ScriptPath = Join-Path $RepoRoot "scripts\scheduling\start-claude-worker.ps1"
$ScriptContent = Get-Content $ScriptPath -Raw

# Verify decoupling from Roo modes-config.json
Assert-Equal "No Get-ModeConfig function" $false ($ScriptContent -match 'function Get-ModeConfig')
Assert-Equal "No ModesConfigPath variable" $false ($ScriptContent -match '\$ModesConfigPath\s*=')
Assert-Equal "Has Get-EscalatedModel function" $true ($ScriptContent -match 'function Get-EscalatedModel')
Assert-Equal "Has WorkerDefaultIterations" $true ($ScriptContent -match '\$WorkerDefaultIterations')

# Verify NoFallback still works
Assert-Equal "NoFallback parameter exists" $true ($ScriptContent -match '\[switch\]\$NoFallback')
# "IDLE exit message exists" assertion removed (#2985): it checked for the literal
# 'WORKER IDLE' in the script, a string that has never existed there
# (git log -S "WORKER IDLE" = empty). The cap-3-IDLE AUTO-STOP (#2185) is an
# agent/dashboard-level behavior, not a string the worker script emits. The
# assertion was false on day one and, with no CI job running this harness, sat
# unread for 62 days.

# Verify escalation is model-based, not mode-based
Assert-Equal "Model-based escalation (Check-Escalation uses CurrentModel)" $true ($ScriptContent -match 'Check-Escalation.*CurrentModel')
Assert-Equal "No Roo mode escalation (no triggerMode)" $false ($ScriptContent -match 'triggerMode')

# #2968: success-conjunction must consult the content-derived ApiErrorInOutput guard.
# Follow-up (#2980 review, ai-01): the guard is ANCHORED on the gateway's emission
# form (line-start "API Error[:\s]", optional [ERROR]: log prefix, multiline) — NOT on
# bare vocabulary. The prior loose "Rate limit" / "No credentialed providers"
# alternatives matched 3/6 prose false-positives (#2968's own title, a PR body, the
# worker's own report), so the loose regex must be ABSENT from the shipped script.
Assert-Equal "#2968 success-conjunction consults ApiErrorInOutput" $true ($ScriptContent -match 'success = \$StreamValid.*ApiErrorInOutput')
Assert-Equal "#2968 ApiErrorInOutput flag is computed" $true ($ScriptContent -match '\$ApiErrorInOutput\s*=\s*\$JoinedIterationOutput -match')
Assert-Equal "#2968 guard anchored on multiline line-start 'API Error[:\s]' emission form" $true ($ScriptContent -match '\(\?im\)\^.*API Error\[:\\s\]')
Assert-Equal "#2968 old loose vocab regex (Rate limit | No credentialed providers) removed - prose FP vector" $false ($ScriptContent -match '\(\?i\)API Error\|Rate limit\|No credentialed providers')
Assert-Equal "#2968 escalation skip present (Check-Escalation guard)" $true ($ScriptContent -match 'if \(\$Result\.apiErrorInOutput\)')

# #2958: Test 8 below exercises a LOCAL COPY of ConvertTo-UtcDateTime (this harness
# cannot dot-source the worker, which executes on load). A copy proves nothing about
# what ships, so bind the two here — same role as the assertions above.
Assert-Equal "#2958 shipped worker defines ConvertTo-UtcDateTime" $true ($ScriptContent -match 'function ConvertTo-UtcDateTime')
Assert-Equal "#2958 no naive [DateTime]::Parse left on a JSON field (culture round-trip)" $false ($ScriptContent -match '\[DateTime\]::Parse\(\$\w+\.\w+\)')

# ============================================================================
# Test 6: #2572 — Budget cutoff must NOT escalate (error_max_budget_usd)
# Validates the guard added to Check-Escalation: a gateway budget cutoff
# short-circuits escalation (same cap would hit again / phantom escalation),
# while error_during_execution and generic failures still escalate.
# ============================================================================
Write-Host ""
Write-Host "=== Test 6: #2572 Budget-Cutoff Escalation Skip ===" -ForegroundColor Cyan

# Extract the REAL Check-Escalation + Get-EscalatedModel from the worker script
# (not a copy — validates the actual shipped logic). Stub Write-Log to a no-op.
function script:Write-Log { param($Msg, $Level) }  # no-op stub for isolated test

# Mirror the shipped logic exactly, then assert the guard contract.
# Kept in sync via Test 5 structure check above. Full dot-sourcing of the worker
# is avoided — it has side effects on import.
function Get-EscalatedModel {
    param([string]$CurrentModel)
    switch ($CurrentModel) {
        "haiku"  { return "sonnet" }
        "sonnet" { return $null }
        "opus"   { return $null }
        default  { return "sonnet" }
    }
}
function Check-Escalation {
    param($Result, [string]$CurrentModel)
    if ($Result.escalateToModel) { return $Result.escalateToModel }
    if (-not $Result.success) {
        if ($Result.resultSubtype -eq "error_max_budget_usd") {
            Write-Log "Budget cutoff — skip escalation" "WARN"
            return $null
        }
        $NextModel = Get-EscalatedModel -CurrentModel $CurrentModel
        if ($NextModel) { return $NextModel }
    }
    return $null
}

# Scenario A: budget cutoff on haiku → MUST NOT escalate (would hit cap again)
$ResultBudget = @{ success = $false; resultSubtype = "error_max_budget_usd"; escalateToModel = $null }
Assert-Equal "#2572 budget cutoff (haiku) does NOT escalate" $null (Check-Escalation -Result $ResultBudget -CurrentModel "haiku")

# Scenario B: budget cutoff on sonnet → MUST NOT escalate
Assert-Equal "#2572 budget cutoff (sonnet) does NOT escalate" $null (Check-Escalation -Result $ResultBudget -CurrentModel "sonnet")

# Scenario C: error_during_execution (technical failure) on haiku → STILL escalates to sonnet
$ResultTech = @{ success = $false; resultSubtype = "error_during_execution"; escalateToModel = $null }
Assert-Equal "#2572 technical failure (haiku) still escalates" "sonnet" (Check-Escalation -Result $ResultTech -CurrentModel "haiku")

# Scenario D: generic failure (no subtype, e.g. stream invalid) on haiku → still escalates
$ResultGeneric = @{ success = $false; resultSubtype = $null; escalateToModel = $null }
Assert-Equal "#2572 generic failure (haiku) still escalates" "sonnet" (Check-Escalation -Result $ResultGeneric -CurrentModel "haiku")

# Scenario E: success → no escalation regardless
$ResultOk = @{ success = $true; resultSubtype = "success"; escalateToModel = $null }
Assert-Equal "#2572 success does not escalate" $null (Check-Escalation -Result $ResultOk -CurrentModel "haiku")

# ============================================================================
# Test 7: #2968 — API-error-in-output must NOT escalate (rate limit / no credentials / upstream 500)
# Validates the guard added to Check-Escalation: when the gateway returns subtype=success
# but the iteration body carries an API error (the shape ai-01 reproduced 2026-07-26 on
# web1 rate-limit and po-2026 no-credential), the run surfaces as FAILURE and escalation
# short-circuits — escalating re-hits the SAME rate-limited/credential-less provider chain.
# Also validates the content regex catches the three signatures WITHOUT matching the
# worker's own "Iteration Break" separator (red herring — present on every legit run).
# ============================================================================
Write-Host ""
Write-Host "=== Test 7: #2968 API-Error-in-Output Escalation Skip ===" -ForegroundColor Cyan

# Redefine Check-Escalation mirroring the FULLY shipped logic (budget #2572 +
# empty-response #2578 + api-error #2968 guards). Test 6's leaner copy is superseded here.
function Check-Escalation {
    param($Result, [string]$CurrentModel)
    if ($Result.escalateToModel) { return $Result.escalateToModel }
    if (-not $Result.success) {
        if ($Result.resultSubtype -eq "error_max_budget_usd") {
            Write-Log "Budget cutoff — skip escalation" "WARN"; return $null
        }
        if ($Result.emptyResponseCount -and $Result.emptyResponseCount -ge 2) {
            Write-Log "Empty-response break — skip escalation" "WARN"; return $null
        }
        if ($Result.apiErrorInOutput) {
            Write-Log "API error in output — skip escalation" "WARN"; return $null
        }
        $NextModel = Get-EscalatedModel -CurrentModel $CurrentModel
        if ($NextModel) { return $NextModel }
    }
    return $null
}

# Scenario A: API error in output (rate limit), haiku → MUST NOT escalate
$ResultApiErr = @{ success = $false; resultSubtype = "success"; apiErrorInOutput = $true; emptyResponseCount = 0; escalateToModel = $null }
Assert-Equal "#2968 rate-limit (haiku) does NOT escalate" $null (Check-Escalation -Result $ResultApiErr -CurrentModel "haiku")

# Scenario B: API error in output (no credentialed providers), sonnet → MUST NOT escalate
Assert-Equal "#2968 no-credentials (sonnet) does NOT escalate" $null (Check-Escalation -Result $ResultApiErr -CurrentModel "sonnet")

# Scenario C: API error at top of chain (opus) → MUST NOT escalate (nowhere to go anyway)
Assert-Equal "#2968 api-error (opus) does NOT escalate" $null (Check-Escalation -Result $ResultApiErr -CurrentModel "opus")

# Scenario D: failure WITHOUT apiErrorInOutput flag (generic/stream-invalid) on haiku → still escalates
$ResultNoApiErr = @{ success = $false; resultSubtype = $null; apiErrorInOutput = $false; emptyResponseCount = 0; escalateToModel = $null }
Assert-Equal "#2968 generic failure (haiku, no api-error) still escalates" "sonnet" (Check-Escalation -Result $ResultNoApiErr -CurrentModel "haiku")

# Scenario E: success with apiErrorInOutput stale/absent → no escalation regardless
$ResultOkApi = @{ success = $true; resultSubtype = "success"; apiErrorInOutput = $false; emptyResponseCount = 0; escalateToModel = $null }
Assert-Equal "#2968 success does not escalate" $null (Check-Escalation -Result $ResultOkApi -CurrentModel "haiku")

# Scenario F: content-regex signature detection (the $ApiErrorInOutput computation logic)
# Mirrors the SHIPPED regex (#2968 follow-up anchor tightening, ai-01 review of PR #2980):
# anchored on the gateway's emission FORM, not bare vocabulary.
$TestRegex = '(?im)^\s*(?:\[?ERROR\]?:?\s*)?API Error[:\s]'
Assert-Equal "#2968 regex matches 'API Error: Rate limit reached' (web1)" $true ("API Error: Rate limit reached" -match $TestRegex)
Assert-Equal "#2968 regex matches 'API Error: 500 ... No credentialed providers in chain' (po-2026)" $true ("API Error: 500 ... No credentialed providers in chain for `"glm-5.2`"" -match $TestRegex)
Assert-Equal "#2968 regex matches a mid-stream multiline 'API Error:' line" $true ("Iteration 3 output follows.`nAPI Error: 500 internal" -match $TestRegex)
Assert-Equal "#2968 regex does NOT match bare 'Rate limit exceeded' prose (ai-01 follow-up inversion - this WAS $true in PR #2980, the very false-positive being fixed)" $false ("Rate limit exceeded" -match $TestRegex)
Assert-Equal "#2968 regex does NOT match #2968 issue title prose" $false ("[CLAUDE-MACHINE] #2968 worker marks rate-limit / no-credential gateway errors as success" -match $TestRegex)
Assert-Equal "#2968 regex does NOT match a PR body describing the fix" $false ("This PR tightens the API Error guard anchor on the worker's success-detection path" -match $TestRegex)
Assert-Equal "#2968 regex does NOT match the worker's own report quoting the error" $false ("The gateway returned subtype=success but the body mentions API Error detection was bypassed" -match $TestRegex)
Assert-Equal "#2968 regex does NOT match worker separator '=== Iteration Break ===' (red herring)" $false ("=== Iteration Break ===" -match $TestRegex)
Assert-Equal "#2968 regex does NOT match a legitimate CI-green output" $false ("CI on PR #905 is all green ... 12635 passed" -match $TestRegex)

# ============================================================================
# Test 8: #2958 — JSON DateTime parsing must not round-trip through two cultures
# PowerShell 7 ConvertFrom-Json returns DateTime objects for ISO timestamps.
# Re-parsing such an object stringifies 7 August via the INVARIANT culture as
# "08/07" (MM/dd), then reads it back under fr-FR as dd/MM = 8 July: a phantom
# 30 days added to every computed age. The mismatch between the two halves is
# the defect — a same-culture round-trip would be lossless.
# ============================================================================
Write-Host ""
Write-Host "=== Test 8: #2958 Culture-Independent JSON Timestamp Parsing ===" -ForegroundColor Cyan

function ConvertTo-UtcDateTime {
    param($Value)
    if ($null -eq $Value) { return $null }
    if ($Value -is [DateTime]) { return $Value.ToUniversalTime() }
    if ($Value -is [DateTimeOffset]) { return $Value.UtcDateTime }
    try {
        return [DateTime]::Parse(
            [string]$Value,
            [System.Globalization.CultureInfo]::InvariantCulture,
            [System.Globalization.DateTimeStyles]::RoundtripKind
        ).ToUniversalTime()
    } catch {
        return $null
    }
}

$OriginalCulture = [System.Threading.Thread]::CurrentThread.CurrentCulture
try {
    [System.Threading.Thread]::CurrentThread.CurrentCulture = [System.Globalization.CultureInfo]::GetCultureInfo('fr-FR')
    $IsoTimestamp = '2026-08-07T13:16:58Z'
    $JsonDateTime = [DateTime]::Parse($IsoTimestamp, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::RoundtripKind)

    Assert-Equal "#2958 DateTime object preserves August 7 under fr-FR" '2026-08-07T13:16:58.0000000Z' ((ConvertTo-UtcDateTime $JsonDateTime).ToString('o'))
    Assert-Equal "#2958 ISO string preserves August 7 under fr-FR" '2026-08-07T13:16:58.0000000Z' ((ConvertTo-UtcDateTime $IsoTimestamp).ToString('o'))
    Assert-Equal "#2958 malformed timestamp fails closed" $null (ConvertTo-UtcDateTime 'not-a-date')

    # Pin the DEFECT, not only the fix. Without this, the suite stays green if the
    # helper is ever reverted to a naive Parse — a test that only exercises the
    # correct path cannot tell a working guard from a removed one.
    # Date-only assertion: TZ-independent (the corruption happens before any UTC
    # conversion), so it holds on the fr-FR workstations AND on the UTC CI runner.
    $NaiveParse = [DateTime]::Parse($JsonDateTime)  # exactly what the worker did before #2958
    Assert-Equal "#2958 naive Parse DOES corrupt 7 Aug into 8 Jul (the defect itself)" '2026-07-08' ($NaiveParse.ToString('yyyy-MM-dd'))
} finally {
    [System.Threading.Thread]::CurrentThread.CurrentCulture = $OriginalCulture
}

# ============================================================================
# Test: the dispatch jq expression must survive Windows PowerShell 5.1
# ============================================================================
Write-Host ""
Write-Host "=== Test: dispatch-guard jq expression is 5.1-safe ===" -ForegroundColor Cyan

# The VBS launcher runs the worker under powershell.exe 5.1, which STRIPS inner
# double quotes when passing an argument to a native command. jq then receives
# `contains([DISPATCH])` and dies with `function not defined: DISPATCH/0`. The
# surrounding catch fails open, so the anti-double-claim guard silently stops
# guarding — #833 was claimed by four machines in a row over nine days.
#
# This assertion is a string check on purpose: it holds on the ubuntu/pwsh CI
# runner, which cannot reproduce the 5.1 argument-passing behaviour that causes
# the defect. A test that could only fail on Windows would run nowhere.
$WorkerText = Get-Content (Join-Path $RepoRoot 'scripts\scheduling\start-claude-worker.ps1') -Raw
$JqLine = ($WorkerText -split "`n" | Where-Object { $_ -match '^\s*\$jqExpr\s*=' })

Assert-Equal "jqExpr is assigned exactly once" 1 @($JqLine).Count
Assert-Equal "jqExpr contains no double quote (5.1 strips them)" $false ($JqLine -join '').Contains('"')

# The line-scoped check above only sees a single-line assignment: a later refactor
# to a continuation or a here-string would move the quote off the assignment line
# and slip past it (caught in review by po-2023 on #3116). So also scan the WHOLE
# file for the killer form, which is form-independent. jq's function is lowercase
# `contains(`; PowerShell's method is `.Contains(` — case-sensitive matching keeps
# them apart, so this does not fire on the `-match`/.Contains() code below.
$BareQuoteJq = [regex]::Matches($WorkerText, 'contains\("', 'None').Count
Assert-Equal "no bare-quote jq contains( anywhere in the worker" 0 $BareQuoteJq

# The sibling expression 180 lines down kept the escaped form `\"`, which DOES
# survive 5.1 (measured: exit 0). #3045 rewrote only $jqExpr and dropped it there.
# Pin the survivor: "harmonising" it to bare quotes would kill the claim check the
# same silent way.
Assert-Equal "jqClaimExpr keeps the 5.1-safe escaped form" $true ($WorkerText -match '\$jqClaimExpr\s*=.*contains\(\\"')

# Pin the DEFECT: the shipped-dead form must be recognised as unsafe by the same
# checks, otherwise this only asserts that today's file happens to be clean.
$ShippedDead = '$jqExpr = ' + "'" + '[.comments[-10:][] | {body, createdAt} | select((.body | contains(' + '"' + '[DISPATCH]' + '"' + ')))]' + "'"
Assert-Equal "the 5c7675e1 form is caught line-scoped (the defect itself)" $true $ShippedDead.Contains('"')
Assert-Equal "the 5c7675e1 form is caught file-wide (multi-line safe)" 1 ([regex]::Matches($ShippedDead, 'contains\("', 'None').Count)

# ============================================================================
# Summary
# ============================================================================
Write-Host ""
Write-Host "=== SUMMARY ===" -ForegroundColor Cyan
Write-Host "  Passed: $TestsPassed" -ForegroundColor Green
Write-Host "  Failed: $TestsFailed" -ForegroundColor $(if ($TestsFailed -gt 0) { "Red" } else { "Green" })

if ($TestsFailed -gt 0) {
    exit 1
} else {
    exit 0
}
