<#
.SYNOPSIS
    Test script for escalation model resolution
    Validates that escalation correctly switches model from haiku to the target mode's model
#>

$RepoRoot = Resolve-Path "$PSScriptRoot\..\.."
$ModesConfigPath = Join-Path $RepoRoot ".claude\modes\modes-config.json"

function Get-ModeConfig {
    param([string]$ModeId)
    $Config = Get-Content $ModesConfigPath | ConvertFrom-Json
    $Config.modes | Where-Object { $_.id -eq $ModeId }
}

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
# Test 1: Mode config models are correct
# ============================================================================
Write-Host "=== Test 1: Mode Config Models ===" -ForegroundColor Cyan

$cfg = Get-ModeConfig -ModeId "sync-simple"
Assert-Equal "sync-simple model" "haiku" $cfg.model
Assert-Equal "sync-simple escalation" "sync-complex" $cfg.escalation.triggerMode

$cfg = Get-ModeConfig -ModeId "sync-complex"
Assert-Equal "sync-complex model" "sonnet" $cfg.model

$cfg = Get-ModeConfig -ModeId "code-simple"
Assert-Equal "code-simple model" "haiku" $cfg.model
Assert-Equal "code-simple escalation" "code-complex" $cfg.escalation.triggerMode

$cfg = Get-ModeConfig -ModeId "code-complex"
Assert-Equal "code-complex model" "sonnet" $cfg.model
Assert-Equal "code-complex escalation" "code-critical" $cfg.escalation.triggerMode

$cfg = Get-ModeConfig -ModeId "code-critical"
Assert-Equal "code-critical model" "opus" $cfg.model

# ============================================================================
# Test 2: Escalation model resolution (the bug fix)
# ============================================================================
Write-Host ""
Write-Host "=== Test 2: Escalation Model Resolution ===" -ForegroundColor Cyan

# Scenario A: Agent specifies ESCALATE_TO model
$Model = "haiku"
$EscalateMode = "sync-complex"
$OriginalModel = $Model
$escalateToModel = "opus"  # Agent specified

if ($escalateToModel) {
    $Model = $escalateToModel
} else {
    $EscModeConfig = Get-ModeConfig -ModeId $EscalateMode
    if ($EscModeConfig -and $EscModeConfig.model) {
        $Model = $EscModeConfig.model
    }
}
Assert-Equal "Agent-specified model used" "opus" $Model
$Model = $OriginalModel  # Restore

# Scenario B: No ESCALATE_TO, should use mode config model
$Model = "haiku"
$EscalateMode = "sync-complex"
$OriginalModel = $Model
$escalateToModel = $null  # Agent did NOT specify

if ($escalateToModel) {
    $Model = $escalateToModel
} else {
    $EscModeConfig = Get-ModeConfig -ModeId $EscalateMode
    if ($EscModeConfig -and $EscModeConfig.model) {
        $Model = $EscModeConfig.model
    }
}
Assert-Equal "Mode-config model used (sync-complex=sonnet)" "sonnet" $Model
$Model = $OriginalModel  # Restore

# Scenario C: code-simple escalates to code-complex (sonnet)
$Model = "haiku"
$EscalateMode = "code-complex"
$OriginalModel = $Model
$escalateToModel = $null

if ($escalateToModel) {
    $Model = $escalateToModel
} else {
    $EscModeConfig = Get-ModeConfig -ModeId $EscalateMode
    if ($EscModeConfig -and $EscModeConfig.model) {
        $Model = $EscModeConfig.model
    }
}
Assert-Equal "Mode-config model used (code-complex=sonnet)" "sonnet" $Model
$Model = $OriginalModel

# Scenario D: code-complex escalates to code-critical (opus)
$Model = "sonnet"
$EscalateMode = "code-critical"
$OriginalModel = $Model
$escalateToModel = $null

if ($escalateToModel) {
    $Model = $escalateToModel
} else {
    $EscModeConfig = Get-ModeConfig -ModeId $EscalateMode
    if ($EscModeConfig -and $EscModeConfig.model) {
        $Model = $EscModeConfig.model
    }
}
Assert-Equal "Mode-config model used (code-critical=opus)" "opus" $Model
$Model = $OriginalModel

# ============================================================================
# Test 3: STATUS signal parsing (Ralph Wiggum)
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

# Ensure directory exists
if (-not (Test-Path $TestWaitDir)) {
    New-Item -ItemType Directory -Path $TestWaitDir -Force | Out-Null
}

# Create test wait state
$TestState = @{
    taskId = $TestTaskId
    timestamp = (Get-Date).ToUniversalTime().ToString("o")
    reason = "Test wait state"
    waitFor = "user_approval"
    resumeWhen = "user_approval"
    context = @{
        mode = "sync-simple"
        model = "haiku"
        iteration = 1
        outputSnippet = "Test output line 1`nTest output line 2"
    }
}

$JsonText = $TestState | ConvertTo-Json -Depth 10
[System.IO.File]::WriteAllText($TestStateFile, $JsonText, [System.Text.UTF8Encoding]::new($false))

Assert-Equal "Wait state file created" $true (Test-Path $TestStateFile)

# Read it back
$ReadState = Get-Content $TestStateFile -Raw | ConvertFrom-Json
Assert-Equal "Wait state taskId preserved" $TestTaskId $ReadState.taskId
Assert-Equal "Wait state mode preserved" "sync-simple" $ReadState.context.mode
Assert-Equal "Wait state model preserved" "haiku" $ReadState.context.model
Assert-Equal "Wait state resumeWhen preserved" "user_approval" $ReadState.resumeWhen

# Clean up
Remove-Item $TestStateFile -Force
Assert-Equal "Wait state file cleaned up" $false (Test-Path $TestStateFile)

# ============================================================================
# Test 5: Graceful Idle (NoFallback mode)
# ============================================================================
Write-Host ""
Write-Host "=== Test 5: Graceful Idle (NoFallback) ===" -ForegroundColor Cyan

# Verify the script parameter accepts -NoFallback
$ScriptPath = Join-Path $RepoRoot "scripts\scheduling\start-claude-worker.ps1"
$ScriptContent = Get-Content $ScriptPath -Raw

Assert-Equal "NoFallback parameter exists" $true ($ScriptContent -match '\[switch\]\$NoFallback')
Assert-Equal "NoFallbackMode propagation exists" $true ($ScriptContent -match '\$script:NoFallbackMode = \$NoFallback')
Assert-Equal "NoFallback check in Get-NextTask" $true ($ScriptContent -match 'if \(\$script:NoFallbackMode\)')
Assert-Equal "Null task exit path exists" $true ($ScriptContent -match 'if \(-not \$Task\)')
Assert-Equal "IDLE exit message exists" $true ($ScriptContent -match 'WORKER IDLE')

# ============================================================================
# Test 6: Escalation in main workflow code
# ============================================================================
Write-Host ""
Write-Host "=== Test 6: Escalation Code Path in Script ===" -ForegroundColor Cyan

# Verify the bug fix is in place (uses mode config model, not just agent model)
Assert-Equal "Bug fix: Get-ModeConfig in escalation" $true ($ScriptContent -match 'Get-ModeConfig -ModeId \$EscalateMode')
Assert-Equal "Bug fix: Uses EscModeConfig.model" $true ($ScriptContent -match '\$EscModeConfig\.model')
Assert-Equal "Bug fix: Comment explains the fix" $true ($ScriptContent -match 'BUG FIX.*modèle configuré')

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
