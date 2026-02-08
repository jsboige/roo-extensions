# Script SDDD 12.3: Nettoyage des fichiers de test temporaires
# Date: 2025-10-24T10:16:00Z
# Objectif: Supprimer les fichiers de test temporaires tout en preservant les tests officiels

Write-Host "SDDD 12.3 - Nettoyage des fichiers de test temporaires" -ForegroundColor Cyan

# Liste des fichiers de test temporaires a supprimer (basee sur l'analyse SDDD 11)
$testFilesToRemove = @(
    "webview-ui/debug-test.spec.tsx",
    "webview-ui/src/debug-test.spec.tsx",
    "webview-ui/src/basic-react-test.spec.tsx",
    "webview-ui/src/basic-react-test-js.spec.ts",
    "webview-ui/src/basic-react-test-with-providers.spec.tsx"
)

# Fichiers de test a preserver (tests officiels)
$testFilesToKeep = @(
    "webview-ui/src/components/settings/__tests__/CondensationProviderSettings.spec.tsx"
)

Write-Host "Fichiers de test officiels a preserver:" -ForegroundColor Yellow
$testFilesToKeep | ForEach-Object { Write-Host "  OK $_" -ForegroundColor Green }

Write-Host "`nFichiers de test temporaires a supprimer:" -ForegroundColor Yellow
$testFilesToRemove | ForEach-Object { Write-Host "  DELETE $_" -ForegroundColor Red }

$removedCount = 0
$keptCount = 0

foreach ($testFile in $testFilesToRemove) {
    if (Test-Path $testFile) {
        Remove-Item $testFile -Force
        Write-Host "  Supprime: $testFile" -ForegroundColor Green
        $removedCount++
    } else {
        Write-Host "  Non trouve: $testFile" -ForegroundColor Yellow
    }
}

foreach ($testFile in $testFilesToKeep) {
    if (Test-Path $testFile) {
        Write-Host "  Preserve: $testFile" -ForegroundColor Green
        $keptCount++
    } else {
        Write-Host "  Manquant: $testFile" -ForegroundColor Red
    }
}

Write-Host "`nResume SDDD 12.3:" -ForegroundColor Cyan
Write-Host "  Fichiers de test supprimes: $removedCount" -ForegroundColor Green
Write-Host "  Fichiers de test preserves: $keptCount" -ForegroundColor Green

if ($keptCount -eq $testFilesToKeep.Count) {
    Write-Host "Nettoyage SDDD 12.3 complete avec succes" -ForegroundColor Green
} else {
    Write-Host "Attention: Certains fichiers de test critiques manquent" -ForegroundColor Yellow
}