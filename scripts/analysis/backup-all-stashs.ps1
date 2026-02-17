# Script de backup de tous les stashs en .patch
# Crée un fichier .patch pour chaque stash pour archivage sécurisé

$backupDir = "docs/git/stash-backups"

# Créer le répertoire de backup s'il n'existe pas
if (-not (Test-Path $backupDir)) {
    New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
    Write-Host "Répertoire de backup créé: $backupDir" -ForegroundColor Green
}

# Lister tous les stashs
$stashList = git stash list
Write-Host "Création de backups pour $($stashList.Count) stashs..." -ForegroundColor Cyan
Write-Host ""

# Créer un backup pour chaque stash
for ($i = 0; $i -lt $stashList.Count; $i++) {
    $patchFile = "$backupDir/stash$i.patch"
    
    Write-Host "Backup stash@{$i} -> $patchFile" -ForegroundColor Yellow
    git stash show -p "stash@{$i}" > $patchFile
    
    if (Test-Path $patchFile) {
        $size = (Get-Item $patchFile).Length
        Write-Host "  ✓ Créé ($size octets)" -ForegroundColor Green
    } else {
        Write-Host "  ✗ Échec" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "Backups terminés! Fichiers dans: $backupDir" -ForegroundColor Green