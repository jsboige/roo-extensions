# Script de restauration du profil PowerShell
# Auteur: Roo (Assistant IA)
# Date: 26/05/2025

param(
    [string]$ProfilePath = "$env:USERPROFILE\OneDrive\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1",
    [string]$BackupPath = ""
)

Write-Host "=== Restauration du profil PowerShell ===" -ForegroundColor Cyan

# Si aucun chemin de sauvegarde spécifié, chercher la sauvegarde la plus récente
if (-not $BackupPath) {
    $ProfileDir = Split-Path $ProfilePath -Parent
    $ProfileName = Split-Path $ProfilePath -Leaf
    
    # Chercher les fichiers de sauvegarde
    $BackupFiles = Get-ChildItem -Path $ProfileDir -Filter "$ProfileName.backup-*" | Sort-Object LastWriteTime -Descending
    
    if ($BackupFiles.Count -eq 0) {
        Write-Host "✗ Aucune sauvegarde trouvée dans $ProfileDir" -ForegroundColor Red
        Write-Host "Recherche de fichiers: $ProfileName.backup-*" -ForegroundColor Gray
        exit 1
    }
    
    $BackupPath = $BackupFiles[0].FullName
    Write-Host "Sauvegarde la plus récente trouvée: $BackupPath" -ForegroundColor Yellow
    
    if ($BackupFiles.Count -gt 1) {
        Write-Host "\nAutres sauvegardes disponibles:" -ForegroundColor Gray
        $BackupFiles[1..($BackupFiles.Count-1)] | ForEach-Object {
            Write-Host "  • $($_.Name) ($(Get-Date $_.LastWriteTime -Format 'yyyy-MM-dd HH:mm:ss'))" -ForegroundColor Gray
        }
    }
}

# Vérifier que la sauvegarde existe
if (-not (Test-Path $BackupPath)) {
    Write-Host "✗ Fichier de sauvegarde introuvable: $BackupPath" -ForegroundColor Red
    exit 1
}

# Afficher le contenu de la sauvegarde
Write-Host "\n=== Contenu de la sauvegarde ===" -ForegroundColor Cyan
Get-Content $BackupPath | ForEach-Object { Write-Host $_ -ForegroundColor Gray }

# Demander confirmation
Write-Host "\n⚠ Voulez-vous restaurer cette sauvegarde ? (O/N)" -ForegroundColor Yellow
$confirmation = Read-Host
if ($confirmation -notmatch '^[OoYy]') {
    Write-Host "Restauration annulée." -ForegroundColor Yellow
    exit 0
}

# Effectuer la restauration
try {
    # Créer une sauvegarde de l'état actuel avant restauration
    $CurrentBackup = "$ProfilePath.before-restore-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    if (Test-Path $ProfilePath) {
        Copy-Item -Path $ProfilePath -Destination $CurrentBackup -Force
        Write-Host "✓ Sauvegarde de l'état actuel: $CurrentBackup" -ForegroundColor Green
    }
    
    # Restaurer la sauvegarde
    Copy-Item -Path $BackupPath -Destination $ProfilePath -Force
    Write-Host "✓ Profil restauré depuis: $BackupPath" -ForegroundColor Green
    
    Write-Host "\n=== Restauration terminée ===" -ForegroundColor Green
    Write-Host "⚠ Redémarrez PowerShell pour appliquer les changements" -ForegroundColor Yellow
    
} catch {
    Write-Host "✗ Erreur lors de la restauration: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
