<#
.SYNOPSIS
    Validation E2E live du serveur MCP roo-state-manager via JSON-RPC stdio.

.DESCRIPTION
    Demarre le serveur MCP via mcp-wrapper.cjs, envoie des requetes JSON-RPC
    via stdin/stdout, et valide les reponses. Teste:
    1. Demarrage du serveur (initialize handshake)
    2. tools/list - Verifie les 18 outils attendus
    3. tools/call - Appel minimal pour chaque outil testable (read-only)
    4. Genere un rapport pass/fail

    Utilise un helper Node.js (validate-mcp-helper.mjs) pour la communication
    JSON-RPC car PowerShell ne gere pas bien le stdin pipe avec le wrapper MCP.

.PARAMETER RepoRoot
    Racine du depot (auto-detecte si omis)

.PARAMETER Timeout
    Timeout en secondes pour chaque requete (defaut: 15)

.PARAMETER SkipCalls
    Sauter les tests tools/call (ne faire que tools/list)

.PARAMETER Verbose
    Afficher les details de chaque requete/reponse

.PARAMETER Json
    Sortie en format JSON brut (depuis le helper Node.js)

.EXAMPLE
    .\validate-mcp-live.ps1
    .\validate-mcp-live.ps1 -Verbose
    .\validate-mcp-live.ps1 -SkipCalls
    .\validate-mcp-live.ps1 -Json
#>

param(
    [string]$RepoRoot = "",
    [int]$Timeout = 15,
    [switch]$SkipCalls,
    [switch]$Verbose,
    [switch]$Json
)

$ErrorActionPreference = "Stop"

# ============================================================
# Configuration
# ============================================================

if (-not $RepoRoot) {
    $RepoRoot = git rev-parse --show-toplevel 2>$null
    if (-not $RepoRoot) {
        Write-Error "Pas dans un depot Git."
        exit 1
    }
}

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$helperPath = Join-Path $scriptDir "validate-mcp-helper.mjs"
$mcpRoot = Join-Path $RepoRoot "mcps/internal/servers/roo-state-manager"
$wrapperPath = Join-Path $mcpRoot "mcp-wrapper.cjs"

# Verify prerequisites
if (-not (Test-Path $helperPath)) {
    Write-Error "Helper Node.js non trouve: $helperPath"
    exit 1
}
if (-not (Test-Path $wrapperPath)) {
    Write-Error "Wrapper MCP non trouve: $wrapperPath"
    exit 1
}
if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    Write-Error "Node.js non disponible dans le PATH"
    exit 1
}

# ============================================================
# Execute Node.js helper
# ============================================================

$nodeArgs = @($helperPath, "--repo=$RepoRoot", "--timeout=$Timeout")
if ($SkipCalls) { $nodeArgs += "--skip-calls" }
if ($Verbose) { $nodeArgs += "--verbose" }

if (-not $Json) {
    Write-Host "=== MCP Live Validation ===" -ForegroundColor Cyan
    Write-Host "Machine: $($env:COMPUTERNAME)"
    Write-Host "Wrapper: $wrapperPath"
    Write-Host "Helper:  $helperPath"
    Write-Host ""
}

# Run the helper and capture stdout (JSON) and stderr (verbose logs)
$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName = "node"
$psi.Arguments = ($nodeArgs | ForEach-Object { """$_""" }) -join " "
$psi.WorkingDirectory = $RepoRoot
$psi.UseShellExecute = $false
$psi.RedirectStandardOutput = $true
$psi.RedirectStandardError = $true
$psi.CreateNoWindow = $true

$proc = [System.Diagnostics.Process]::Start($psi)

# Read stderr in background (for verbose output)
$stderrJob = $proc.StandardError.ReadToEndAsync()

# Read stdout (JSON result)
$stdout = $proc.StandardOutput.ReadToEnd()

$null = $proc.WaitForExit(($Timeout + 30) * 1000)
if (-not $proc.HasExited) {
    $proc.Kill()
    Write-Error "Helper Node.js timeout apres $($Timeout + 30)s"
    exit 1
}

$stderrOutput = $stderrJob.Result
$exitCode = $proc.ExitCode

# Show verbose output if requested
if ($Verbose -and $stderrOutput) {
    foreach ($line in ($stderrOutput -split "`n")) {
        if ($line.Trim()) {
            Write-Host "  $($line.Trim())" -ForegroundColor DarkGray
        }
    }
    Write-Host ""
}

# ============================================================
# Parse and display results
# ============================================================

if ($Json) {
    # Raw JSON output
    Write-Output $stdout
    exit $exitCode
}

try {
    $results = $stdout | ConvertFrom-Json
}
catch {
    Write-Host "  [FAIL] Impossible de parser la sortie JSON du helper" -ForegroundColor Red
    if ($stdout) {
        Write-Host "  Sortie brute:" -ForegroundColor Yellow
        Write-Host $stdout
    }
    exit 1
}

# Phase 1: Server start
Write-Host "--- Phase 1: Demarrage du serveur ---" -ForegroundColor Cyan
if ($results.phase1) {
    Write-Host "  [PASS] Serveur MCP demarre (PID: $($results.phase1.pid))" -ForegroundColor Green
    if ($results.phase1.init.status -eq "ok") {
        Write-Host "  [PASS] Initialize OK (protocol: $($results.phase1.init.protocolVersion), server: $($results.phase1.init.serverName))" -ForegroundColor Green
    }
    else {
        Write-Host "  [FAIL] Initialize echoue: $($results.phase1.init.error)" -ForegroundColor Red
    }
}
else {
    Write-Host "  [FAIL] Serveur non demarre" -ForegroundColor Red
}

# Phase 2: tools/list
Write-Host ""
Write-Host "--- Phase 2: tools/list ---" -ForegroundColor Cyan
if ($results.phase2) {
    $p2 = $results.phase2
    if ($p2.actual -eq $p2.expected) {
        Write-Host "  [PASS] Nombre d'outils: $($p2.actual) (attendu: $($p2.expected))" -ForegroundColor Green
    }
    else {
        Write-Host "  [FAIL] Nombre d'outils: $($p2.actual) (attendu: $($p2.expected))" -ForegroundColor Red
    }

    if ($p2.missing -and $p2.missing.Count -gt 0) {
        foreach ($m in $p2.missing) {
            Write-Host "  [FAIL] Outil manquant: $m" -ForegroundColor Red
        }
    }
    if ($p2.extra -and $p2.extra.Count -gt 0) {
        foreach ($e in $p2.extra) {
            Write-Host "  [WARN] Outil inattendu: $e" -ForegroundColor Yellow
        }
    }

    if ($p2.status -eq "ok") {
        Write-Host "  [PASS] Tous les 18 outils presents" -ForegroundColor Green
    }

    if ($Verbose -and $p2.tools) {
        Write-Host "  Outils:" -ForegroundColor DarkGray
        foreach ($t in $p2.tools) {
            Write-Host "    - $t" -ForegroundColor DarkGray
        }
    }
}

# Phase 3: tools/call
if ($results.phase3 -and $results.phase3.Count -gt 0) {
    Write-Host ""
    Write-Host "--- Phase 3: tools/call ---" -ForegroundColor Cyan

    foreach ($call in $results.phase3) {
        switch ($call.status) {
            "passed" {
                Write-Host "  [PASS] $($call.tool) ($($call.duration_ms)ms)" -ForegroundColor Green
            }
            "failed" {
                $errMsg = if ($call.error) { $call.error.Substring(0, [Math]::Min(80, $call.error.Length)) } else { "unknown" }
                Write-Host "  [FAIL] $($call.tool) - $errMsg" -ForegroundColor Red
            }
            "skipped" {
                $reason = if ($call.reason -eq "not_safe_to_call") { "Non teste (modifie l'etat)" } else { $call.reason }
                Write-Host "  [SKIP] $($call.tool) - $reason" -ForegroundColor Yellow
            }
        }
    }
}

# Fatal error
if ($results.fatal) {
    Write-Host ""
    Write-Host "  [FATAL] $($results.fatal)" -ForegroundColor Red
}

# Summary
Write-Host ""
Write-Host "=== Rapport ===" -ForegroundColor Cyan
$s = $results.summary
Write-Host "  Total:   $($s.total)"
Write-Host "  Passed:  $($s.passed)" -ForegroundColor Green
if ($s.failed -gt 0) {
    Write-Host "  Failed:  $($s.failed)" -ForegroundColor Red
}
else {
    Write-Host "  Failed:  0"
}
if ($s.skipped -gt 0) {
    Write-Host "  Skipped: $($s.skipped)" -ForegroundColor Yellow
}

Write-Host ""
if ($exitCode -eq 0) {
    Write-Host "RESULTAT: PASS" -ForegroundColor Green
}
else {
    Write-Host "RESULTAT: FAIL" -ForegroundColor Red
}

exit $exitCode
