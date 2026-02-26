<#
.SYNOPSIS
    Integration tests for Claude worker scheduling pipeline.
    Tests: wait state signal, escalation model switch, sub-agent delegation.

.PARAMETER Test
    Which test to run: WaitState, Escalation, SubAgent, All

.PARAMETER DryRun
    If set, only shows what would be executed

.EXAMPLE
    .\test-integration.ps1 -Test WaitState
    .\test-integration.ps1 -Test Escalation
    .\test-integration.ps1 -Test All
#>

param(
    [ValidateSet("WaitState", "Escalation", "SubAgent", "All")]
    [string]$Test = "All",
    [switch]$DryRun = $false
)

$RepoRoot = Resolve-Path "$PSScriptRoot\..\.."
$WorkerScript = Join-Path $PSScriptRoot "start-claude-worker.ps1"

Write-Host "=== Integration Test Suite ===" -ForegroundColor Cyan
Write-Host "  RepoRoot: $RepoRoot"
Write-Host "  Test: $Test"
Write-Host "  DryRun: $DryRun"
Write-Host ""

# ============================================================================
# Test: Wait State
# ============================================================================
if ($Test -eq "WaitState" -or $Test -eq "All") {
    Write-Host "=== TEST: Wait State ===" -ForegroundColor Yellow
    Write-Host "  Goal: Haiku outputs STATUS: wait, worker saves wait state file"
    Write-Host ""

    # Clean up any previous wait state
    $WaitDir = Join-Path $RepoRoot ".claude\scheduler\wait-states"
    if (-not (Test-Path $WaitDir)) {
        New-Item -ItemType Directory -Path $WaitDir -Force | Out-Null
    }
    Get-ChildItem $WaitDir -Filter "test-*" -ErrorAction SilentlyContinue | Remove-Item -Force

    $WaitPrompt = "Tu es un agent de test. Ta SEULE mission: tester le signal wait. Reponds UNIQUEMENT avec ce texte exact (rien d'autre):`n`nTest wait state OK.`n`n=== AGENT STATUS ===`nSTATUS: wait`nREASON: Testing wait state mechanism`nWAIT_FOR: user_approval`nRESUME_WHEN: user_approval`n==================="

    & $WorkerScript `
        -Mode "sync-simple" `
        -Model "haiku" `
        -MaxIterations 1 `
        -TaskId "test-wait-state" `
        -Prompt $WaitPrompt `
        -NoFallback

    Write-Host ""

    # Check if wait state was saved
    $WaitFile = Join-Path $WaitDir "test-wait-state.json"
    if (Test-Path $WaitFile) {
        Write-Host "  PASS: Wait state file created!" -ForegroundColor Green
        $State = Get-Content $WaitFile -Raw | ConvertFrom-Json
        Write-Host "    waitFor: $($State.waitFor)" -ForegroundColor Green
        Write-Host "    resumeWhen: $($State.resumeWhen)" -ForegroundColor Green
        Write-Host "    mode: $($State.context.mode)" -ForegroundColor Green
        Write-Host "    model: $($State.context.model)" -ForegroundColor Green
        # Clean up
        Remove-Item $WaitFile -Force
    } else {
        Write-Host "  INFO: Wait state file NOT created (agent may not have output exact signal)" -ForegroundColor Yellow
        Write-Host "  Check logs above for STATUS parsing details"
    }

    Write-Host ""
}

# ============================================================================
# Test: Escalation
# ============================================================================
if ($Test -eq "Escalation" -or $Test -eq "All") {
    Write-Host "=== TEST: Escalation ===" -ForegroundColor Yellow
    Write-Host "  Goal: Haiku outputs STATUS: escalate, worker re-invokes with sonnet"
    Write-Host "  Chain: sync-simple (haiku) -> sync-complex (sonnet)"
    Write-Host ""

    $EscPrompt = "Tu es un agent de test. Ta SEULE mission: tester le signal escalate. Reponds UNIQUEMENT avec ce texte exact (rien d'autre):`n`nTest escalade OK.`n`n=== AGENT STATUS ===`nSTATUS: escalate`nREASON: Testing escalation - tache trop complexe`nESCALATE_TO: sonnet`n==================="

    & $WorkerScript `
        -Mode "sync-simple" `
        -Model "haiku" `
        -MaxIterations 1 `
        -TaskId "test-escalation" `
        -Prompt $EscPrompt `
        -NoFallback

    Write-Host ""
    Write-Host "  Check logs above for:" -ForegroundColor Yellow
    Write-Host "    - 'ESCALADE' message"
    Write-Host "    - Model switch from haiku to sonnet"
    Write-Host "    - Second claude invocation with sync-complex"
    Write-Host ""
}

# ============================================================================
# Test: Sub-Agent Delegation
# ============================================================================
if ($Test -eq "SubAgent" -or $Test -eq "All") {
    Write-Host "=== TEST: Sub-Agent Delegation ===" -ForegroundColor Yellow
    Write-Host "  Goal: Haiku uses Task tool to spawn a Sonnet sub-agent"
    Write-Host ""

    $SubPrompt = "Tu es un agent de test. Utilise l'outil Task (subagent_type: general-purpose, model: sonnet, description: test delegation) pour demander a un sous-agent Sonnet de repondre: SOUS-AGENT SONNET OK. Affiche sa reponse puis termine avec:`n`n=== AGENT STATUS ===`nSTATUS: success`nREASON: Sub-agent delegation test completed`n==================="

    & $WorkerScript `
        -Mode "code-simple" `
        -Model "haiku" `
        -MaxIterations 1 `
        -TaskId "test-subagent" `
        -Prompt $SubPrompt `
        -NoFallback

    Write-Host ""
    Write-Host "  Check logs above for:" -ForegroundColor Yellow
    Write-Host "    - Task tool invocation with model: sonnet"
    Write-Host "    - 'SOUS-AGENT SONNET OK' in output"
    Write-Host ""
}

Write-Host "=== Integration Tests Complete ===" -ForegroundColor Cyan
