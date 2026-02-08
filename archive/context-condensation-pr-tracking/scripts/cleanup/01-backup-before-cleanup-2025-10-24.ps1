# Script SDDD 12.1: Backup avant nettoyage
# Date: 2025-10-24T10:16:00Z
# Objectif: Creer un backup de securite avant le nettoyage

Write-Host "SDDD 12.1 - Creation du backup avant nettoyage" -ForegroundColor Cyan

# Creer une branche de backup
try {
    $currentBranch = git rev-parse --abbrev-ref HEAD
    Write-Host "Branche actuelle: $currentBranch" -ForegroundColor Yellow
    
    # Creer une branche de backup avec timestamp
    $backupBranch = "backup-sddd12-cleanup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    git checkout -b $backupBranch
    Write-Host "Branche de backup creee: $backupBranch" -ForegroundColor Green
    
    # Stash des changements actuels
    git stash push -m "SDDD12-backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    Write-Host "Changements stashes avec succes" -ForegroundColor Green
    
    # Revenir a la branche principale
    git checkout main 2>$null
    if ($LASTEXITCODE -ne 0) {
        git checkout master 2>$null
    }
    
    Write-Host "Backup SDDD 12.1 complete avec succes" -ForegroundColor Green
} catch {
    Write-Host "Erreur lors du backup: $_" -ForegroundColor Red
    exit 1
}