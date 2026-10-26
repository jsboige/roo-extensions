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
    HTTP request timeout in seconds (default: 90).

    90 s, pas 15 s : le vhost embeddings.myia.io repond en 5,9-26 s (mesure
    ai-01 26/10 04:18-04:25Z). Un budget de 15 s classait un service SANTE
    comme DOWN (8 fausses alertes [CRITICAL] le 26/10) et faisait dire
    restart vLLM alors que le conteneur vLLM etait healthy. Le budget doit
    couvrir la latence du vhost, pas seulement celle du modele.

.PARAMETER ConfirmTimeoutSeconds
    Budget du second essai (default: 90), lance uniquement quand le premier
    a expire. Distingue « lent mais vivant » (DEGRADED) de « mort » (FAIL).

.PARAMETER SlowThresholdMs
    Latence au-dela de laquelle la reponse est classee SLOW (vivant mais lent) plutot que OK. Default 15000 ms (seuil eval-harness).

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
    [int]$TimeoutSeconds = 90,
    [int]$ConfirmTimeoutSeconds = 90,
    [int]$SlowThresholdMs = 15000,
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

# Un service lent n est pas un service mort : les deux se ressemblent au
# premier essai (un timeout), mais ils ne se soignent pas de la meme facon.
# Un timeout sur le vhost (mesure ai-01 26/10 : conteneur vLLM healthy,
# 5,9-26 s de latence vhost) n a jamais justifie un restart de vLLM.
# La levee de cette ambiguite est une CONFIRMATION : si le premier essai
# expire, on reessaie avec un budget plus long sur la MEME URL.
#   - le second essai repond  -> DEGRADED : lent mais vivant -> [WARN]
#   - le second essai echoue -> FAIL : mort               -> [CRITICAL]
$headers = @{ "Authorization" = "Bearer $apiKey" }

try {
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $response = Invoke-RestMethod -Uri "$ApiBase/models" -Headers $headers -TimeoutSec $TimeoutSeconds
    $sw.Stop()
    $models = ($response.data | ForEach-Object { $_.id }) -join ", "
    $detail = "$($sw.ElapsedMilliseconds)ms, models: $models"
    if ($sw.ElapsedMilliseconds -gt $SlowThresholdMs) {
        $status = "SLOW"
        Write-Host "[SLOW] Embeddings alive but slow ($detail) (threshold $SlowThresholdMs ms)" -ForegroundColor Yellow
    } else {
        Write-Host "[OK] Embeddings healthy ($detail)" -ForegroundColor Green
    }
} catch {
    $firstError = $_.Exception.Message
    $isTimeout = ($_.Exception -is [System.Net.WebException]) -and
                  ($_.Exception.Status -eq [System.Net.WebExceptionStatus]::Timeout)

    if (-not $isTimeout) {
        $status = "FAIL"
        $detail = $firstError
        Write-Host "[FAIL] Embeddings DOWN: $detail" -ForegroundColor Red
    } else {
        $sw2 = [System.Diagnostics.Stopwatch]::StartNew()
        try {
            $response2 = Invoke-RestMethod -Uri "$ApiBase/models" -Headers $headers -TimeoutSec $ConfirmTimeoutSeconds
            $sw2.Stop()
            $models2 = ($response2.data | ForEach-Object { $_.id }) -join ", "
            $status = "DEGRADED"
            $detail = "timeout apres $TimeoutSeconds s ($firstError) ; reponse a $($sw2.ElapsedMilliseconds) ms au second essai (budget $ConfirmTimeoutSeconds s) -> service VIVANT mais lent, models: $models2"
            Write-Host "[DEGRADED] Embeddings lent mais vivant: $detail" -ForegroundColor Yellow
        } catch {
            $sw2.Stop()
            $status = "FAIL"
            $detail = "timeout apres $TimeoutSeconds s ($firstError) ; second essai en echec apres $($sw2.ElapsedMilliseconds) ms ($($_.Exception.Message))"
            Write-Host "[FAIL] Embeddings DOWN: $detail" -ForegroundColor Red
        }
    }
}
# --- Log ---
$logDir = "$repoRoot/outputs/monitoring/logs"
if (-not (Test-Path $logDir)) { New-Item -Path $logDir -ItemType Directory -Force | Out-Null }
$logFile = "$logDir/embeddings-$(Get-Date -Format 'yyyy-MM-dd').log"
$ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
"$ts | $status | $detail" | Out-File $logFile -Append -Encoding utf8

function Send-DashboardAlert {
    param([string]$Prompt)
    $mcpConfig = Join-Path $env:USERPROFILE ".claude.json"
    $claudeExe = Get-Command claude -ErrorAction SilentlyContinue
    if (-not $claudeExe) {
        Write-Host "[WARN] claude not in PATH -- dashboard alert skipped" -ForegroundColor Yellow
        return $false
    }
    $prevErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        & claude -p $Prompt --mcp-config $mcpConfig --model haiku --allowedTools "mcp__roo-state-manager__roosync_dashboard" --permission-mode acceptEdits --output-format text 2>$null | Out-Null
        $exitCode = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $prevErrorActionPreference
    }
    if ($exitCode -eq 0) { return $true }
    Write-Host "[WARN] claude -p failed (exit $exitCode)" -ForegroundColor Yellow
    return $false
}

# --- Alert on failure ---
# DEGRADED : le service repond, seule la latence du vhost est mauvaise ->
# [WARN] et AUCUN restart de vLLM (le backend est vivant : le dire serait
# un faux diagnostic). FAIL : le backend ne repond pas -> [CRITICAL].
if ($status -eq "DEGRADED" -and -not $DryRun) {
    $prompt = "Post a [WARN] alert to the workspace dashboard (roosync_dashboard action=append type=workspace tags=[WARN,health-check]) saying: Embeddings endpoint $ApiBase is DEGRADED on $machineName. Error: $detail. The embeddings backend is ALIVE (it answered a second attempt with a longer budget) -- the latency comes from the vhost, so DO NOT restart vLLM. Action: check the vhost/ARR path and the upstream routing; semantic search and meta-analysis are degraded by the added latency."

    if (Send-DashboardAlert -Prompt $prompt) {
        Write-Host "[ALERT] Dashboard notification sent (DEGRADED)" -ForegroundColor Yellow
    }
}

if ($status -eq "FAIL" -and -not $DryRun) {
    $prompt = "Post a [CRITICAL] alert to the workspace dashboard (roosync_dashboard action=append type=workspace tags=['CRITICAL','health-check']) saying: Embeddings endpoint $ApiBase is DOWN on $machineName. Error: $detail. Semantic search and meta-analysis are affected. Action: check vLLM backend and restart if needed."

    if (Send-DashboardAlert -Prompt $prompt) {
        Write-Host "[ALERT] Dashboard notification sent" -ForegroundColor Yellow
    }
}

if ($status -eq "FAIL") { exit 1 }
if ($status -eq "DEGRADED") { exit 0 }
if ($status -eq "SLOW") { exit 0 }
