<#
.SYNOPSIS
    Test script for Claude Worker escalation (model-based)
    Validates that escalation correctly switches model: haiku -> sonnet -> opus
    Decoupled from Roo modes-config.json since 2026-03-06
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
# Test 1: Model escalation chain (haiku -> sonnet -> opus)
# ============================================================================
Write-Host "=== Test 1: Model Escalation Chain ===" -ForegroundColor Cyan

function Get-EscalatedModel {
    param([string]$CurrentModel)
    switch ($CurrentModel) {
        "haiku"  { return "sonnet" }
        "sonnet" { return "opus" }
        "opus"   { return $null }
        default  { return "sonnet" }
    }
}

Assert-Equal "haiku escalates to sonnet" "sonnet" (Get-EscalatedModel "haiku")
Assert-Equal "sonnet escalates to opus" "opus" (Get-EscalatedModel "sonnet")
Assert-Equal "opus is max (no escalation)" $null (Get-EscalatedModel "opus")
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

# Scenario C: Auto-escalate sonnet -> opus
$Model = "sonnet"
$OriginalModel = $Model
$escalateToModel = $null

if ($escalateToModel) {
    $Model = $escalateToModel
} else {
    $NextModel = Get-EscalatedModel -CurrentModel $Model
    if ($NextModel) { $Model = $NextModel }
}
Assert-Equal "Auto-escalate sonnet -> opus" "opus" $Model
$Model = $OriginalModel

# Scenario D: Already at opus, no escalation possible
$Model = "opus"
$OriginalModel = $Model
$escalateToModel = $null

if ($escalateToModel) {
    $Model = $escalateToModel
} else {
    $NextModel = Get-EscalatedModel -CurrentModel $Model
    if ($NextModel) { $Model = $NextModel }
}
Assert-Equal "Opus stays at opus (no escalation)" "opus" $Model
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
Assert-Equal "IDLE exit message exists" $true ($ScriptContent -match 'WORKER IDLE')

# Verify escalation is model-based, not mode-based
Assert-Equal "Model-based escalation (Check-Escalation uses CurrentModel)" $true ($ScriptContent -match 'Check-Escalation.*CurrentModel')
Assert-Equal "No Roo mode escalation (no triggerMode)" $false ($ScriptContent -match 'triggerMode')

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
