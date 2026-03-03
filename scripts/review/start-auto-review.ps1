# Start Auto-Review - Entry point for scheduler and Claude Worker
# Forwards all parameters to auto-review.ps1
# Called by: Roo scheduler (win-cli), Claude Worker (Invoke-GitSyncAndReview)

param(
    [string]$DiffRange = "HEAD~1",
    [int]$IssueNumber = 0,
    [switch]$BuildCheck,
    [switch]$DryRun,
    [switch]$Verbose
)

$ErrorActionPreference = "Stop"

Write-Host "[SCHEDULER] Auto-Review démarré sur ${env:COMPUTERNAME}" -ForegroundColor Green

# Chemin vers le script principal
$autoReviewScript = Join-Path $PSScriptRoot "auto-review.ps1"

if (-not (Test-Path $autoReviewScript)) {
    Write-Host "[SCHEDULER] ERREUR: Script auto-review.ps1 introuvable dans $PSScriptRoot" -ForegroundColor Red
    exit 1
}

# Build arguments to forward (hashtable splatting for named params)
$forwardArgs = @{ DiffRange = $DiffRange }
if ($IssueNumber -gt 0) { $forwardArgs["IssueNumber"] = $IssueNumber }
if ($BuildCheck)        { $forwardArgs["BuildCheck"] = $true }
if ($DryRun)            { $forwardArgs["DryRun"] = $true }
if ($Verbose)           { $forwardArgs["Verbose"] = $true }

$argDisplay = ($forwardArgs.GetEnumerator() | ForEach-Object { "-$($_.Key) $($_.Value)" }) -join " "
Write-Host "[SCHEDULER] Forwarding: $argDisplay" -ForegroundColor DarkGray

try {
    & $autoReviewScript @forwardArgs
    $exitCode = $LASTEXITCODE

    if ($exitCode -eq 0) {
        Write-Host "[SCHEDULER] Auto-review terminé avec succès" -ForegroundColor Green
    } else {
        Write-Host "[SCHEDULER] Auto-review terminé avec code $exitCode" -ForegroundColor Yellow
    }

    exit $exitCode
} catch {
    Write-Host "[SCHEDULER] ERREUR: $_" -ForegroundColor Red
    exit 1
}