# E2E Tests for RooSync Environment Variables Standardization
# SDDD Phase 3 - P0-2 Correction

# Configuration de l'environnement avec variables standardisées
$env:ROOSYNC_SHARED_PATH = "G:/Mon Drive/Synchronisation/RooSync/.shared-state"
$env:ROOSYNC_MACHINE_ID = "E2E-TEST-MACHINE"
$env:ROOSYNC_AUTO_SYNC = "false"
$env:ROOSYNC_CONFLICT_STRATEGY = "manual"
$env:ROOSYNC_LOG_LEVEL = "info"
$env:NODE_ENV = "test"
$env:NODE_OPTIONS = "--max-old-space-size=8192"

Write-Host "🔧 Variables d'environnement standardisées:"
Write-Host "  ROOSYNC_SHARED_PATH: $env:ROOSYNC_SHARED_PATH"
Write-Host "  ROOSYNC_MACHINE_ID: $env:ROOSYNC_MACHINE_ID"
Write-Host "  NODE_OPTIONS: $env:NODE_OPTIONS"

# Exécuter les tests unitaires avec l'environnement standardisé
Write-Host "`n--- Tests unitaires avec ROOSYNC_SHARED_PATH ---`"
Set-Location -Path "mcps/internal/servers/roo-state-manager" -PassThru
npm run test:unit

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Tests unitaires échoués avec ROOSYNC_SHARED_PATH"
    exit $LASTEXITCODE
}

# Exécuter les tests E2E avec l'environnement standardisé
Write-Host "`n--- Tests E2E avec ROOSYNC_SHARED_PATH ---`"
npm run test:e2e

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Tests E2E échoués avec ROOSYNC_SHARED_PATH"
    exit $LASTEXITCODE
}

Write-Host "✅ P0-2 terminé : Variables d'environnement standardisées"