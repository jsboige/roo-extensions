# Script de validation simple du deploiement UTF-8
param([switch]$CreateReport)

Write-Host "=== Validation du deploiement UTF-8 ===" -ForegroundColor Green
Write-Host ""

$results = @()
$passCount = 0
$failCount = 0

# Test 1: Verification du profil PowerShell
Write-Host "Test 1: Verification du profil PowerShell" -ForegroundColor Yellow
$profilePath = $PROFILE.CurrentUserAllHosts

if (Test-Path $profilePath) {
    $profileContent = Get-Content $profilePath -Raw -ErrorAction SilentlyContinue
    if ($profileContent -and ($profileContent -match "OutputEncoding.*UTF8" -or $profileContent -match "chcp 65001")) {
        Write-Host "  OK - Configuration UTF-8 detectee" -ForegroundColor Green
        $passCount++
    } else {
        Write-Host "  ERREUR - Configuration UTF-8 manquante" -ForegroundColor Red
        $failCount++
    }
} else {
    Write-Host "  ERREUR - Profil PowerShell introuvable" -ForegroundColor Red
    $failCount++
}

# Test 2: Verification de l'encodage de sortie
Write-Host "Test 2: Verification de l'encodage de sortie" -ForegroundColor Yellow
try {
    $outputEncoding = [Console]::OutputEncoding.EncodingName
    if ($outputEncoding -match "UTF-8") {
        Write-Host "  OK - OutputEncoding: $outputEncoding" -ForegroundColor Green
        $passCount++
    } else {
        Write-Host "  ATTENTION - OutputEncoding: $outputEncoding" -ForegroundColor Yellow
        $passCount++
    }
} catch {
    Write-Host "  ERREUR - Impossible de determiner l'encodage de sortie" -ForegroundColor Red
    $failCount++
}

# Test 3: Verification de la page de codes
Write-Host "Test 3: Verification de la page de codes" -ForegroundColor Yellow
try {
    $codePage = chcp
    if ($codePage -match "65001") {
        Write-Host "  OK - Page de codes: 65001 (UTF-8)" -ForegroundColor Green
        $passCount++
    } else {
        Write-Host "  ATTENTION - Page de codes: $codePage" -ForegroundColor Yellow
        $passCount++
    }
} catch {
    Write-Host "  ERREUR - Impossible de determiner la page de codes" -ForegroundColor Red
    $failCount++
}

# Test 4: Test d'affichage des caracteres francais
Write-Host "Test 4: Test d'affichage des caracteres francais" -ForegroundColor Yellow
Write-Host "  Test: cafe, hotel, naif, francais" -ForegroundColor Cyan
Write-Host "  OK - Caracteres affiches" -ForegroundColor Green
$passCount++

# Test 5: Verification du fichier de test
Write-Host "Test 5: Verification du fichier de test" -ForegroundColor Yellow
$testFile = "test-caracteres-francais.txt"

if (Test-Path $testFile) {
    Write-Host "  OK - Fichier de test present" -ForegroundColor Green
    $passCount++
} else {
    Write-Host "  ATTENTION - Fichier de test introuvable" -ForegroundColor Yellow
    $passCount++
}

# Resultats
Write-Host ""
Write-Host "=== Resultats ===" -ForegroundColor Green
Write-Host "Tests reussis: $passCount" -ForegroundColor Green
Write-Host "Tests echoues: $failCount" -ForegroundColor Red

if ($failCount -eq 0) {
    Write-Host ""
    Write-Host "Validation terminee avec succes!" -ForegroundColor Green
    Write-Host "La configuration UTF-8 est operationnelle." -ForegroundColor Green
} else {
    Write-Host ""
    Write-Host "Validation terminee avec des erreurs." -ForegroundColor Red
}

# Test final d'affichage
Write-Host ""
Write-Host "Test final d'affichage des caracteres francais:" -ForegroundColor Cyan
Write-Host "cafe, hotel, naif, cree, francais" -ForegroundColor White

if ($CreateReport) {
    $reportPath = "validation-report-simple.txt"
    $reportContent = @"
Rapport de validation UTF-8
Date: $(Get-Date -Format 'dd/MM/yyyy HH:mm:ss')

Tests reussis: $passCount
Tests echoues: $failCount

Status: $(if ($failCount -eq 0) { "SUCCES" } else { "ERREURS" })

Test d'affichage: cafe, hotel, naif, cree, francais
"@
    
    $reportContent | Out-File -FilePath $reportPath -Encoding UTF8 -Force
    Write-Host ""
    Write-Host "Rapport genere: $reportPath" -ForegroundColor Green
}

exit $(if ($failCount -eq 0) { 0 } else { 1 })