<#
.SYNOPSIS
    Monitor embeddings endpoint health and alert on failure.

.DESCRIPTION
    Tests the embeddings API endpoint (/v1/models) with Bearer auth.
    On failure, spawns claude -p to post a [CRITICAL] alert on the workspace dashboard.
    Designed to run as a scheduled task every 30 minutes on any machine.

.PARAMETER ApiBase
    Base URL of the embeddings API (default: https://embeddings.myia.io/v1).

.PARAMETER TimeoutSeconds
    HTTP request timeout in seconds (default: 15).

.PARAMETER DryRun
    Test endpoint but skip dashboard alert on failure.

.EXAMPLE
    .\check-embeddings.ps1
    .\check-embeddings.ps1 -DryRun
    .\check-embeddings.ps1 -ApiBase "http://localhost:8080/v1"

.NOTES
    Issue #1499. API key read from mcps/internal/servers/roo-state-manager/.env.
#>

param(
    [string]$ApiBase = "https://embeddings.myia.io/v1",
    [int]$TimeoutSeconds = 15,
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"
$scriptDir = Split-Path $MyInvocation.MyCommand.Path -Parent
$repoRoot = (Split-Path (Split-Path $scriptDir -Parent) -Parent)
$machineName = ($env:COMPUTERNAME).ToLower()

# --- Read API key from MCP .env ---
$envFile = "$repoRoot/mcps/internal/servers/roo-state-manager/.env"
if (-not (Test-Path $envFile)) {
    Write-Host "[ERROR] .env not found: $envFile" -ForegroundColor Red
    exit 1
}

$apiKey = ""
foreach ($line in Get-Content $envFile) {
    if ($line -match '^EMBEDDING_API_KEY=(.+)$') {
        $apiKey = $Matches[1]
        break
    }
}
if ([string]::IsNullOrEmpty($apiKey)) {
    Write-Host "[ERROR] EMBEDDING_API_KEY not found in .env" -ForegroundColor Red
    exit 1
}

# --- Test endpoint ---
$status = "OK"
$detail = ""
$models = ""

try {
    $headers = @{ "Authorization" = "Bearer $apiKey" }
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $response = Invoke-RestMethod -Uri "$ApiBase/models" -Headers $headers -TimeoutSec $TimeoutSeconds
    $sw.Stop()
    $models = ($response.data | ForEach-Object { $_.id }) -join ", "
    $detail = "$($sw.ElapsedMilliseconds)ms, models: $models"
    Write-Host "[OK] Embeddings healthy ($detail)" -ForegroundColor Green
} catch {
    $status = "FAIL"
    $detail = $_.Exception.Message
    Write-Host "[FAIL] Embeddings DOWN: $detail" -ForegroundColor Red
}

# --- Log ---
$logDir = "$repoRoot/outputs/monitoring/logs"
if (-not (Test-Path $logDir)) { New-Item -Path $logDir -ItemType Directory -Force | Out-Null }
$logFile = "$logDir/embeddings-$(Get-Date -Format 'yyyy-MM-dd').log"
$ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
"$ts | $status | $detail" | Out-File $logFile -Append -Encoding utf8

# --- Alert on failure ---
if ($status -eq "FAIL" -and -not $DryRun) {
    $prompt = "Post a [CRITICAL] alert to the workspace dashboard (roosync_dashboard action=append type=workspace tags=['CRITICAL','health-check']) saying: Embeddings endpoint $ApiBase is DOWN on $machineName. Error: $detail. Semantic search and meta-analysis are affected. Action: check vLLM backend and restart if needed."

    $mcpConfig = Join-Path $env:USERPROFILE ".claude.json"
    $claudeExe = Get-Command claude -ErrorAction SilentlyContinue

    if ($claudeExe) {
        try {
            & claude -p $prompt --mcp-config $mcpConfig --model haiku --output-format text 2>$null
            Write-Host "[ALERT] Dashboard notification sent" -ForegroundColor Yellow
        } catch {
            Write-Host "[WARN] claude -p failed: $_" -ForegroundColor Yellow
        }
    } else {
        Write-Host "[WARN] claude not in PATH — dashboard alert skipped" -ForegroundColor Yellow
    }
}

if ($status -eq "FAIL") { exit 1 }
