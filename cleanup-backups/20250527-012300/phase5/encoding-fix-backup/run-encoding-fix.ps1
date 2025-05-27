# Script principal de correction d'encodage PowerShell
# Auteur: Roo (Assistant IA)
# Date: 26/05/2025

param(
    [switch]$SkipBackup,
    [switch]$SkipTest,
    [switch]$Force
)

$ScriptDir = Split-Path $MyInvocation.MyCommand.Path -Parent

Write-Host "=== Correction d'encodage PowerShell - Script principal ===" -ForegroundColor Cyan
Write-Host "Répertoire des scripts: $ScriptDir" -ForegroundColor Gray
Write-Host "Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray

# Étape 1: Sauvegarde (sauf si -SkipBackup)
if (-not $SkipBackup) {
    Write-Host "\n--- Étape 1: Sauvegarde du profil ---" -ForegroundColor Yellow
    & "$ScriptDir\backup-profile.ps1"
    if ($LASTEXITCODE -ne 0) {
        Write-Host "✗ Échec de la sauvegarde" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "\n--- Étape 1: Sauvegarde ignorée (SkipBackup) ---" -ForegroundColor Yellow
}

# Étape 2: Application de la correction
Write-Host "\n--- Étape 2: Application de la correction d'encodage ---" -ForegroundColor Yellow
$fixArgs = @()
if ($Force) { $fixArgs += "-Force" }
& "$ScriptDir\fix-encoding.ps1" @fixArgs
if ($LASTEXITCODE -ne 0) {
    Write-Host "✗ Échec de l'application de la correction" -ForegroundColor Red
    exit 1
}

# Étape 3: Test (sauf si -SkipTest)
if (-not $SkipTest) {
    Write-Host "\n--- Étape 3: Test de la configuration ---" -ForegroundColor Yellow
    Write-Host "⚠ IMPORTANT: Pour que les tests soient valides, vous devez redémarrer PowerShell" -ForegroundColor Yellow
    Write-Host "Voulez-vous exécuter les tests maintenant ? (O/N)" -ForegroundColor Yellow
    $runTest = Read-Host
    if ($runTest -match '^[OoYy]') {
        & "$ScriptDir\test-encoding.ps1"
    } else {
        Write-Host "Tests ignorés. Exécutez manuellement 'test-encoding.ps1' après redémarrage de PowerShell." -ForegroundColor Yellow
    }
} else {
    Write-Host "\n--- Étape 3: Tests ignorés (SkipTest) ---" -ForegroundColor Yellow
}

# Résumé final
Write-Host "\n=== Procédure terminée ===" -ForegroundColor Green
Write-Host "✓ Scripts disponibles dans: $ScriptDir" -ForegroundColor Green
Write-Host "✓ Documentation: README.md" -ForegroundColor Green
Write-Host "\n📋 Prochaines étapes:" -ForegroundColor Cyan
Write-Host "1. Redémarrer PowerShell" -ForegroundColor White
Write-Host "2. Exécuter 'test-encoding.ps1' pour valider" -ForegroundColor White
Write-Host "3. En cas de problème, utiliser 'restore-profile.ps1'" -ForegroundColor White

Write-Host "\n📁 Fichiers créés:" -ForegroundColor Cyan
Get-ChildItem $ScriptDir -Filter "*.ps1" | ForEach-Object {
    Write-Host "  • $($_.Name)" -ForegroundColor White
}
if (Test-Path "$ScriptDir\README.md") {
    Write-Host "  • README.md" -ForegroundColor White
}
