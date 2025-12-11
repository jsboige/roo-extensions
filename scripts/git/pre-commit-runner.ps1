#!/usr/bin/env pwsh

# scripts/git/pre-commit-runner.ps1
# Script exécuté par le hook pre-commit Git pour valider les changements avant commit.
# Exécute une sélection de tests critiques.

Write-Host "🔍 [Pre-commit] Lancement de la validation..." -ForegroundColor Cyan

# Configuration des tests à exécuter
$CriticalTests = @(
    "tests/Configuration.tests.ps1"
    # Ajoutez d'autres fichiers de tests critiques ici
)

$TotalTests = 0
$FailedTests = 0
$PassedTests = 0

$TestResults = @()

foreach ($TestFile in $CriticalTests) {
    if (Test-Path $TestFile) {
        Write-Host "   Running $TestFile..." -NoNewline
        
        # Exécution de Pester en mode PassThru pour récupérer les résultats
        # On utilise Invoke-Pester standard pour compatibilité maximale entre versions Pester
        $Result = Invoke-Pester -Path $TestFile -PassThru
        
        $TotalTests += $Result.TotalCount
        $FailedTests += $Result.FailedCount
        $PassedTests += $Result.PassedCount

        if ($Result.FailedCount -gt 0) {
            Write-Host " ❌ ÉCHEC" -ForegroundColor Red
            $TestResults += [PSCustomObject]@{
                File = $TestFile
                Status = "Failed"
                FailedCount = $Result.FailedCount
            }
        } else {
            Write-Host " ✅ SUCCÈS" -ForegroundColor Green
             $TestResults += [PSCustomObject]@{
                File = $TestFile
                Status = "Passed"
                FailedCount = 0
            }
        }
    } else {
        Write-Host " ⚠️ INTROUVABLE: $TestFile" -ForegroundColor Yellow
        # On ne bloque pas le commit si un test est introuvable, mais on avertit
    }
}

# --- Résumé ---
Write-Host "`n📊 [Pre-commit] Résumé :" -ForegroundColor Cyan
Write-Host "   Total Tests : $TotalTests"
Write-Host "   Succès      : $PassedTests" -ForegroundColor Green
Write-Host "   Échecs      : $FailedTests" -ForegroundColor ($FailedTests -gt 0 ? "Red" : "Green")

if ($FailedTests -gt 0) {
    Write-Host "`n⛔ [Pre-commit] Des tests critiques ont échoué. Le commit est bloqué." -ForegroundColor Red
    Write-Host "   Veuillez corriger les erreurs avant de commiter."
    exit 1
} else {
    Write-Host "`n✅ [Pre-commit] Tous les tests critiques ont réussi. Commit autorisé." -ForegroundColor Green
    exit 0
}