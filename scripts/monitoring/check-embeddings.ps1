<#
.SYNOPSIS
    Monitor embeddings endpoint health and alert on failure.

.DESCRIPTION
    Tests the embeddings API endpoint (/v1/models) with Bearer auth.
    On failure, posts a [CRITICAL] alert on the workspace dashboard through
    rsm-dashboard-append.mjs (deterministic, NO agent spawned), at most once
    per UTC day and per failure kind -- see scripts/monitoring/embeddings-alert.ps1.
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
    Budget du second essai (default: 150), lance uniquement quand le premier
    a expire. Distingue « lent mais vivant » (DEGRADED) de « mort » (FAIL).
    Il doit etre STRICTEMENT SUPERIEUR au premier budget : un budget egal
    n apporte aucune information (les deux expireraient ensemble). A 150 s, un
    second timeout prouve la MORT (aucune reponse en 4 min), pas la lenteur.

.PARAMETER SlowThresholdMs
    Latence au-dela de laquelle la reponse est classee SLOW (vivant mais lent) plutot que OK. Default 5000 ms.

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
    [int]$ConfirmTimeoutSeconds = 150,
    [int]$SlowThresholdMs = 5000,
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"
$scriptDir = Split-Path $MyInvocation.MyCommand.Path -Parent
$repoRoot = (Split-Path (Split-Path $scriptDir -Parent) -Parent)
$machineName = ($env:COMPUTERNAME).ToLower()
$verdictFile = Join-Path $scriptDir "embeddings-verdict.ps1"
if (-not (Test-Path $verdictFile)) {
    Write-Host "[ERROR] verdict helper not found: $verdictFile" -ForegroundColor Red
    exit 1
}
. $verdictFile

# Helper d alerte : post deterministe par CLI, sans spawn d agent. Fichier
# separe pour etre testable sans executer la sonde (meme patron que le verdict).
$alertFile = Join-Path $scriptDir "embeddings-alert.ps1"
if (-not (Test-Path $alertFile)) {
    Write-Host "[ERROR] alert helper not found: $alertFile" -ForegroundColor Red
    exit 1
}
. $alertFile

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
$failureKind = ""

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
    $verdict = Get-EmbeddingsVerdict -ErrorRecord $_.Exception -Message $firstError

    if ($verdict.Status -eq "TIMEOUT") {
        # Un timeout ne prouve pas la mort : on CONFIRME avec un budget plus
        # grand sur la MEME URL. Un budget egal n apporte rien (les deux
        # expireraient ensemble) : celui de confirmation est plus long.
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
            $verdict2 = Get-EmbeddingsVerdict -ErrorRecord $_.Exception
            if ($verdict2.Status -eq "AUTH") {
                # Le vhost a repondu en refusant la cle : il est VIVANT. Le
                # timeout initial etait la latence, pas la mort.
                $status = "AUTH"
                $failureKind = "auth"
                $detail = $verdict2.Detail
                Write-Host "[AUTH] Embeddings a repondu mais refuse la cle: $detail" -ForegroundColor Yellow
            } elseif ($verdict2.Status -eq "HTTP") {
                $status = "FAIL"
                $failureKind = "http"
                $detail = $verdict2.Detail
                Write-Host "[FAIL] Embeddings DOWN ($failureKind): $detail" -ForegroundColor Red
            } elseif ($verdict2.Status -eq "FAILURE") {
                # Le second essai n a pas recu de reponse HTTP du tout (connexion
                # refusee ou coupee). Ce n est pas un timeout : le premier essai
                # a expire, mais celui-ci a echoue vite et sans reponse. Le
                # classer « timeout » enverrait l alerte qui affirme « les DEUX
                # essais ont expiré », soit une cause non mesuree.
                $status = "FAIL"
                $failureKind = "unknown"
                $detail = "timeout apres $TimeoutSeconds s ($firstError) ; second essai SANS reponse HTTP apres $($sw2.ElapsedMilliseconds) ms (budget $ConfirmTimeoutSeconds s) ($($_.Exception.Message))"
                Write-Host "[FAIL] Embeddings DOWN ($failureKind): $detail" -ForegroundColor Red
            } else {
                $status = "FAIL"
                $failureKind = "timeout"
                $detail = "timeout apres $TimeoutSeconds s ($firstError) ; second essai en echec apres $($sw2.ElapsedMilliseconds) ms (budget $ConfirmTimeoutSeconds s) ($($_.Exception.Message))"
                Write-Host "[FAIL] Embeddings DOWN ($failureKind): $detail" -ForegroundColor Red
            }
        }
    } elseif ($verdict.Status -eq "AUTH") {
        # 401/403 : le service REPOND et refuse la cle. Il n est pas mort,
        # et redemarrer vLLM ne changerait rien a un probleme de cle.
        $status = "AUTH"
        $failureKind = "auth"
        $detail = $verdict.Detail
        Write-Host "[AUTH] Embeddings a repondu mais refuse la cle: $detail" -ForegroundColor Yellow
    } else {
        $status = "FAIL"
        $failureKind = $verdict.FailureKind
        $detail = $verdict.Detail
        Write-Host "[FAIL] Embeddings DOWN ($failureKind): $detail" -ForegroundColor Red
    }

}
# --- Log ---
$logDir = "$repoRoot/outputs/monitoring/logs"
if (-not (Test-Path $logDir)) { New-Item -Path $logDir -ItemType Directory -Force | Out-Null }
$logFile = "$logDir/embeddings-$(Get-Date -Format 'yyyy-MM-dd').log"
$ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
"$ts | $status | $detail" | Out-File $logFile -Append -Encoding utf8

# Send-DashboardAlert vit dans embeddings-alert.ps1 (source ci-dessus) : post
# deterministe par le CLI RSM, AUCUN `claude -p`. Le spawn etait le
# multiplicateur : une boucle d agents par ligne FAIL, mesuree a 35 agents
# pour UN incident le 27/10 (outillage de mesure : #4381 pour le texte).

# --- Alert on failure ---
# DEGRADED : le service repond, seule la latence du vhost est mauvaise ->
# [WARN] et AUCUN restart de vLLM (le backend est vivant : le dire serait
# un faux diagnostic). FAIL : le backend ne repond pas -> [CRITICAL].
if ($status -eq "DEGRADED" -and -not $DryRun) {
    $message = "Embeddings endpoint $ApiBase is DEGRADED on $machineName. Error: $detail. The embeddings backend is ALIVE (it answered a second attempt with a longer budget) -- the latency comes from the vhost, so DO NOT restart vLLM. Action: check the vhost/ARR path and the upstream routing; semantic search and meta-analysis are degraded by the added latency."

    if (Send-DashboardAlert -Tag "WARN" -Message $message -FailureKind "degraded") {
        Write-Host "[ALERT] Dashboard notification sent (DEGRADED)" -ForegroundColor Yellow
    }
}

# AUTH (401/403) : le service REPOND et refuse la cle. Probleme de
# configuration, pas panne : signale dans le journal et sur stdout, SANS
# spawn d agent -- une alerte toutes les 30 min pour une cle a faire
# tourner serait exactement le multiplicateur que ce correctif combat.
if ($status -eq "FAIL" -and -not $DryRun) {
    if ($failureKind -eq "timeout") {
        $message = "Embeddings endpoint $ApiBase is UNREACHABLE on $machineName. Error: $detail. Both attempts timed out (first budget $TimeoutSeconds seconds, confirmation budget $ConfirmTimeoutSeconds seconds), so the vhost embeddings.myia.io no longer answers at all. Action: DO NOT restart vLLM first -- check the vhost/ARR path, the TLS termination and the upstream routing to the embeddings backend; the vLLM container may well be healthy while the vhost is the broken link. Semantic search and meta-analysis are affected."
    } elseif ($failureKind -eq "http") {
        $message = "Embeddings endpoint $ApiBase is DOWN as seen from $machineName. Error: $detail. The probe received an explicit HTTP error (not a timeout): the endpoint DID answer, with an error status -- the probe did NOT establish which layer is at fault, so do not read the status code as a diagnosis. Action: identify FIRST the host that actually serves this endpoint (the probing machine $machineName is generally NOT the host running the embeddings backend -- for embeddings.myia.io the backend runs on another machine, po-2023), then check the vhost/ARR path, the TLS termination and the upstream routing to that backend. Do NOT restart a backend you have not proven to be the culprit. Semantic search and meta-analysis are affected."
    } else {
        $message = "Embeddings endpoint $ApiBase is UNREACHABLE from $machineName. Error: $detail. NO HTTP response was received (TCP connect failed or was dropped): neither the backend nor the model is implicated by this probe -- it measured that the connection did not complete, and nothing more. Action: do NOT restart anything. Check first whether the IIS host accepts connections (listener, backlog, ARR), from the LAN as well as from the public path, using curl --resolve so SNI and the certificate are kept. Semantic search and meta-analysis are affected."
    }

    # Kind = clef d idempotence : 1 alerte par jour UTC et par kind. Un
    # changement de kind (http -> tcp -> timeout) est une information
    # nouvelle et poste donc a nouveau ; la meme panne repetee non.
    if (Send-DashboardAlert -Tag "CRITICAL" -Message $message -FailureKind $failureKind) {
        Write-Host "[ALERT] Dashboard notification sent" -ForegroundColor Yellow
    }
}

if ($status -eq "FAIL") { exit 1 }
if ($status -eq "AUTH") { exit 0 }
if ($status -eq "DEGRADED") { exit 0 }
if ($status -eq "SLOW") { exit 0 }
