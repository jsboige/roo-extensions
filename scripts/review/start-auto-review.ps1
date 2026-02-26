# Start Auto-Review - Script d'appel pour le scheduler
# Ce script est appelé par le scheduler via win-cli pour lancer l'auto-review

$ErrorActionPreference = "Stop"

Write-Host "[SCHEDULER] Auto-Review démarré sur ${env:COMPUTERNAME}" -ForegroundColor Green

# Chemin vers le script principal
$autoReviewScript = Join-Path $PSScriptRoot "auto-review.ps1"

# Vérifier si le script existe
if (-not (Test-Path $autoReviewScript)) {
    Write-Host "[SCHEDULER] ERREUR: Script auto-review.ps1 introuvable dans $PSScriptRoot" -ForegroundColor Red
    exit 1
}

# Appeler le script principal
try {
    & $autoReviewScript
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