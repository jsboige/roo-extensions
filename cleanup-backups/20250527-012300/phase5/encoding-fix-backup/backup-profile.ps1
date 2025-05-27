# Script de sauvegarde du profil PowerShell
# Auteur: Roo (Assistant IA)
# Date: 26/05/2025

param(
    [string]$ProfilePath = "$env:USERPROFILE\OneDrive\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1",
    [string]$BackupSuffix = ".backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
)

Write-Host "=== Sauvegarde du profil PowerShell ===" -ForegroundColor Cyan
Write-Host "Profil source: $ProfilePath" -ForegroundColor Yellow

# Vérifier si le profil existe
if (-not (Test-Path $ProfilePath)) {
    Write-Host "ATTENTION: Le profil PowerShell n'existe pas à l'emplacement spécifié." -ForegroundColor Red
    Write-Host "Emplacement: $ProfilePath" -ForegroundColor Red
    Write-Host "Un nouveau profil sera créé lors de l'application de la correction." -ForegroundColor Yellow
    exit 0
}

# Créer la sauvegarde
$BackupPath = $ProfilePath + $BackupSuffix
try {
    Copy-Item -Path $ProfilePath -Destination $BackupPath -Force
    Write-Host "✓ Sauvegarde créée: $BackupPath" -ForegroundColor Green
    
    # Afficher le contenu actuel pour référence
    Write-Host "`n=== Contenu actuel du profil ===" -ForegroundColor Cyan
    Get-Content $ProfilePath | ForEach-Object { Write-Host $_ -ForegroundColor Gray }
    
    Write-Host "`n✓ Sauvegarde terminée avec succès" -ForegroundColor Green
} catch {
    Write-Host "✗ Erreur lors de la sauvegarde: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
