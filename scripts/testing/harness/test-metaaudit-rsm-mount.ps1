# Static harness: start-meta-audit.ps1 must actually MOUNT roo-state-manager in the
# spawned claude, and its post-run check must see the truth.
#
# The defects this pins (measured po-2026 2026-09-14, #3575 — 2 no-RSM cycles in 9 runs):
#   1. The pre-flight ensure-build-fresh invocation carried no -RepoRoot. Under the schtask
#      chain (wscript/VBS) the CWD is outside the repo, so the child's own git-rev-parse
#      found nothing and every single run since deployment logged
#      "[SKIP] Not in a git repo and -RepoRoot not given" — the one known reproducible
#      cause of "RSM absent at spawn" (#2822) was never pre-flighted by any run.
#   2. The spawn gave the headless child no MCP startup budget. Both failing cycles ran on
#      a cold machine (09-10: boot 23:40, spawn 23:46; 08-25: 6h without any claude
#      process) and lost the ENTIRE MCP layer — 0 mcp__* tool_use across ALL servers, empty
#      stderr, exit 0. RSM's cold warmup alone measures 75-90s, past the default ~30s MCP
#      startup timeout, after which claude -p proceeds without the failed servers.
#   3. The post-run check counted SUBSTRING hits of "mcp__roo-state-manager", which match
#      the agent's own prose about the absent tools: both failing cycles were declared "OK"
#      (8 and 14 hits) on sessions containing 0 actual RSM call.
#
# Pure: reads the production script as text + AST. No network, no disk writes, no schtask,
# no Windows dependency — runs on ubuntu-latest pwsh alongside the other wired harnesses.

$ErrorActionPreference = 'Stop'
$script:Fails = 0

function Assert-That([string]$Label, [bool]$Condition) {
    if ($Condition) { Write-Host "  OK   $Label" }
    else { $script:Fails++; Write-Host "  FAIL $Label" -ForegroundColor Red }
}

$Target = Join-Path $PSScriptRoot '..' '..' 'scheduling' 'start-meta-audit.ps1'
$Target = [System.IO.Path]::GetFullPath($Target)
Write-Host "=== meta-audit RSM mount harness ==="
Write-Host "Target: $Target"

if (-not (Test-Path $Target)) {
    Write-Host "  FAIL start-meta-audit.ps1 introuvable" -ForegroundColor Red
    exit 1
}

$Text = Get-Content $Target -Raw
$Lines = Get-Content $Target
$ParseErrors = $null
[System.Management.Automation.Language.Parser]::ParseFile($Target, [ref]$null, [ref]$ParseErrors) | Out-Null
Assert-That "le script production parse sans erreur" (@($ParseErrors).Count -eq 0)

# --- 1. Pre-flight: -RepoRoot passe a ensure-build-fresh ----------------------
# Sans lui, le CWD de la chaine schtask (System32) fait SKIPper le pre-flight
# build-fresh — la cause connue #2822 n'etait donc jamais eliminee avant le spawn.
Assert-That "ensure-build-fresh recoit -RepoRoot (SKIP systematique sinon, #3575)" `
    ($Text -match '-File\s+\$EnsureBuildScript\s+-RepoRoot\s+\$RepoRoot\.Path')

# --- 2. Budget MCP herite par l'enfant, AVANT le Start-Process ----------------
$StartProcLine = @($Lines | Select-String -Pattern '-FilePath\s+\$ClaudeCmd' | Select-Object -First 1)
Assert-That "le Start-Process du spawn est identifiable" ($StartProcLine.Count -eq 1)

foreach ($pair in @(
    @{ Env = 'MCP_TIMEOUT';    Var = 'McpStartupTimeoutMs'; Ms = '180000' },
    @{ Env = 'MCP_TOOL_TIMEOUT'; Var = 'McpToolTimeoutMs';   Ms = '900000' }
)) {
    $assign = @($Lines | Select-String -Pattern ("^\s*\`$env:{0}\s*=" -f $pair.Env))
    Assert-That "`$env:$($pair.Env) est pose (une affectation)" ($assign.Count -eq 1)
    if ($assign.Count -eq 1 -and $StartProcLine.Count -eq 1) {
        Assert-That "`$env:$($pair.Env) est pose AVANT le Start-Process" `
            ($assign[0].LineNumber -lt $StartProcLine[0].LineNumber)
    }
    # Valeur single-source : la constante porte le literal, l'affectation la reference.
    # Un literal recopie dans l'affectation deriverait silencieusement de la preview.
    $lit = @($Lines | Select-String -Pattern ("^\s*\`${0}\s*=\s*'{1}'" -f $pair.Var, $pair.Ms))
    Assert-That "`$$($pair.Var) = '$($pair.Ms)' defini une seule fois" ($lit.Count -eq 1)
    Assert-That "l'affectation env reference la constante (pas un literal)" `
        ($Text -match ("\`$env:{0}\s*=\s*\`${1}" -f $pair.Env, $pair.Var))
}

# --- 3. Compteur post-run : tool_use reels, pas des sous-chaines -------------
Assert-That "le post-run parse les blocs tool_use (compteur d'appels reels)" `
    ($Text -match "\`$Block\.type -eq 'tool_use'" -and $Text -match "\`$Block\.name -like 'mcp__roo-state-manager__\*'")
Assert-That "le compteur borne aux messages assistant (prose/snapshots exclus)" `
    ($Text -match "\`$Entry\.type -ne 'assistant'")
Assert-That "l'ancien grep par sous-chaine 'mcp__roo-state-manager' est ABSENT (comptait la prose)" `
    (-not ($Text -match 'Select-String\s+-Path\s+\`$SessionJsonl\.FullName\s+-Pattern\s+"mcp__roo-state-manager"'))

# --- 4. La preview DryRun montre le budget qu'elle executera -------------------
$PreviewEnv = @($Lines | Select-String -Pattern 'env au spawn: MCP_TIMEOUT=\$McpStartupTimeoutMs')
Assert-That "la preview DryRun expose le budget MCP (single-source avec le spawn)" ($PreviewEnv.Count -eq 1)

Write-Host ""
if ($script:Fails -gt 0) {
    Write-Host "=== $($script:Fails) assertion(s) en echec ===" -ForegroundColor Red
    exit 1
}
Write-Host "=== toutes les assertions passent ==="
exit 0
