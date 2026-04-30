# Script de test pour valider le diagnostic d'encodage
Write-Host "Test du diagnostic d'encodage Windows..." -ForegroundColor Cyan

# Exécuter le script de diagnostic
&pwsh -File "scripts/diagnostic-encoding-os-windows.ps1"

Write-Host "Test terminé." -ForegroundColor Green