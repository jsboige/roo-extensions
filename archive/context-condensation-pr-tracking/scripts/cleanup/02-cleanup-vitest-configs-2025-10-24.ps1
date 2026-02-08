# Script SDDD 12.2: Nettoyage des configurations Vitest experimentales
# Date: 2025-10-24T10:16:00Z
# Objectif: Supprimer les configurations Vitest experimentales tout en preservant la configuration principale

Write-Host "SDDD 12.2 - Nettoyage des configurations Vitest experimentales" -ForegroundColor Cyan

# Liste des fichiers de configuration a supprimer (basee sur l'analyse SDDD 11)
$configsToRemove = @(
    "webview-ui/vitest.config.automatic.ts",
    "webview-ui/vitest.config.babel.ts",
    "webview-ui/vitest.config.bare.ts",
    "webview-ui/vitest.config.final.ts",
    "webview-ui/vitest.config.fixed.ts",
    "webview-ui/vitest.config.isolated.ts",
    "webview-ui/vitest.config.jsx-fix.ts",
    "webview-ui/vitest.config.manual.ts",
    "webview-ui/vitest.config.test.ts"
)

# Fichiers de configuration a preserver
$configsToKeep = @(
    "webview-ui/vitest.config.ts"
)

Write-Host "Fichiers de configuration a preserver:" -ForegroundColor Yellow
$configsToKeep | ForEach-Object { Write-Host "  OK $_" -ForegroundColor Green }

Write-Host "`nFichiers de configuration a supprimer:" -ForegroundColor Yellow
$configsToRemove | ForEach-Object { Write-Host "  DELETE $_" -ForegroundColor Red }

$removedCount = 0
$keptCount = 0

foreach ($config in $configsToRemove) {
    if (Test-Path $config) {
        Remove-Item $config -Force
        Write-Host "  Supprime: $config" -ForegroundColor Green
        $removedCount++
    } else {
        Write-Host "  Non trouve: $config" -ForegroundColor Yellow
    }
}

foreach ($config in $configsToKeep) {
    if (Test-Path $config) {
        Write-Host "  Preserve: $config" -ForegroundColor Green
        $keptCount++
    } else {
        Write-Host "  Manquant: $config" -ForegroundColor Red
    }
}

Write-Host "`nResume SDDD 12.2:" -ForegroundColor Cyan
Write-Host "  Configurations supprimees: $removedCount" -ForegroundColor Green
Write-Host "  Configurations preservees: $keptCount" -ForegroundColor Green

if ($keptCount -eq $configsToKeep.Count) {
    Write-Host "Nettoyage SDDD 12.2 complete avec succes" -ForegroundColor Green
} else {
    Write-Host "Attention: Certains fichiers critiques manquent" -ForegroundColor Yellow
}