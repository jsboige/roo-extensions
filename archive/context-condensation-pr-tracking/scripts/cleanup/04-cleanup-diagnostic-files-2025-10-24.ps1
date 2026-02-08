# Script SDDD 12.4: Nettoyage des fichiers de diagnostic et setups experimentaux
# Date: 2025-10-24T10:16:00Z
# Objectif: Supprimer les fichiers de diagnostic et setups Vitest experimentaux

Write-Host "SDDD 12.4 - Nettoyage des fichiers de diagnostic et setups experimentaux" -ForegroundColor Cyan

# Liste des fichiers de diagnostic a supprimer
$diagnosticFilesToRemove = @(
    "webview-ui/debug-test-output.txt"
)

# Liste des setups Vitest experimentaux a supprimer
$setupsToRemove = @(
    "webview-ui/vitest.setup.fixed.ts",
    "webview-ui/vitest.setup.tsx"  # Extension incorrecte pour un setup
)

# Setups Vitest a preserver
$setupsToKeep = @(
    "webview-ui/vitest.setup.ts"
)

Write-Host "Fichiers de diagnostic a supprimer:" -ForegroundColor Yellow
$diagnosticFilesToRemove | ForEach-Object { Write-Host "  DELETE $_" -ForegroundColor Red }

Write-Host "`nSetups Vitest a preserver:" -ForegroundColor Yellow
$setupsToKeep | ForEach-Object { Write-Host "  OK $_" -ForegroundColor Green }

Write-Host "`nSetups Vitest experimentaux a supprimer:" -ForegroundColor Yellow
$setupsToRemove | ForEach-Object { Write-Host "  DELETE $_" -ForegroundColor Red }

$removedCount = 0
$keptCount = 0

# Suppression des fichiers de diagnostic
foreach ($file in $diagnosticFilesToRemove) {
    if (Test-Path $file) {
        Remove-Item $file -Force
        Write-Host "  Supprime: $file" -ForegroundColor Green
        $removedCount++
    } else {
        Write-Host "  Non trouve: $file" -ForegroundColor Yellow
    }
}

# Suppression des setups experimentaux
foreach ($setup in $setupsToRemove) {
    if (Test-Path $setup) {
        Remove-Item $setup -Force
        Write-Host "  Supprime: $setup" -ForegroundColor Green
        $removedCount++
    } else {
        Write-Host "  Non trouve: $setup" -ForegroundColor Yellow
    }
}

# Verification des setups a preserver
foreach ($setup in $setupsToKeep) {
    if (Test-Path $setup) {
        Write-Host "  Preserve: $setup" -ForegroundColor Green
        $keptCount++
    } else {
        Write-Host "  Manquant: $setup" -ForegroundColor Red
    }
}

Write-Host "`nResume SDDD 12.4:" -ForegroundColor Cyan
Write-Host "  Fichiers de diagnostic/setups supprimes: $removedCount" -ForegroundColor Green
Write-Host "  Setups preserves: $keptCount" -ForegroundColor Green

if ($keptCount -eq $setupsToKeep.Count) {
    Write-Host "Nettoyage SDDD 12.4 complete avec succes" -ForegroundColor Green
} else {
    Write-Host "Attention: Certains setups critiques manquent" -ForegroundColor Yellow
}