# Script de nettoyage des fichiers temporaires - Mission Nettoyage Git
# Date: 2025-10-19
# Objectif: Nettoyer les fichiers temporaires et backups

Write-Host "=== NETTOYAGE DES FICHIERS TEMPORAIRES ===" -ForegroundColor Cyan
Write-Host "Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray

# Fichiers temporaires identifiés
$tempFiles = @(
    "mcps/internal/servers/roo-state-manager/.env.backup-20251016-232046"
)

Write-Host "Fichiers temporaires à nettoyer : $($tempFiles.Count)" -ForegroundColor Yellow

# Nettoyage du fichier de backup dans le sous-module
Write-Host "`n--- Nettoyage du sous-module mcps/internal ---" -ForegroundColor Yellow

try {
    Set-Location "mcps/internal"
    
    foreach ($tempFile in $tempFiles) {
        $relativePath = $tempFile -replace "mcps/internal/", ""
        
        if (Test-Path $relativePath) {
            Write-Host "Suppression : $relativePath" -ForegroundColor Red
            Remove-Item $relativePath -Force
            
            if ($LASTEXITCODE -eq 0) {
                Write-Host "✅ Fichier supprimé avec succès" -ForegroundColor Green
            } else {
                Write-Host "❌ Erreur lors de la suppression" -ForegroundColor Red
            }
        } else {
            Write-Host "⚠️ Fichier non trouvé : $relativePath" -ForegroundColor Yellow
        }
    }
    
    # Vérifier l'état après nettoyage
    Write-Host "`n--- État du sous-module après nettoyage ---" -ForegroundColor Yellow
    $status = git status --porcelain
    if ($status) {
        Write-Host "Fichiers restants :"
        $status | ForEach-Object { Write-Host "  $_" }
    } else {
        Write-Host "✅ Sous-module propre" -ForegroundColor Green
    }
    
    Set-Location "../../"
    
} catch {
    Set-Location "../../"
    Write-Host "❌ Erreur lors du nettoyage du sous-module: $($_.Exception.Message)" -ForegroundColor Red
}

# Vérifier s'il y a d'autres fichiers temporaires dans le repo principal
Write-Host "`n--- Recherche d'autres fichiers temporaires ---" -ForegroundColor Yellow

$gitStatus = git status --porcelain
$otherTempFiles = @()

foreach ($file in $gitStatus) {
    $filePath = $file.Substring(3)
    if ($filePath -match "\.tmp$|\.bak$|\.old$|\.corrupted$|backup|\.backup-") {
        $otherTempFiles += $file
    }
}

if ($otherTempFiles.Count -gt 0) {
    Write-Host "Autres fichiers temporaires détectés : $($otherTempFiles.Count)" -ForegroundColor Yellow
    foreach ($file in $otherTempFiles) {
        Write-Host "  $file" -ForegroundColor Gray
    }
    
    Write-Host "`nVoulez-vous supprimer ces fichiers ? (y/N)" -ForegroundColor Yellow
    $response = Read-Host
    
    if ($response -eq "y" -or $response -eq "Y") {
        foreach ($file in $otherTempFiles) {
            $status = $file.Substring(0, 2).Trim()
            $filePath = $file.Substring(3)
            
            Write-Host "Suppression : $filePath" -ForegroundColor Red
            
            if ($status -eq "??") {
                # Fichier non suivi - suppression directe
                Remove-Item $filePath -Force -ErrorAction SilentlyContinue
            } else {
                # Fichier suivi - suppression avec git
                git rm $filePath 2>$null
            }
        }
        Write-Host "✅ Fichiers temporaires supplémentaires nettoyés" -ForegroundColor Green
    } else {
        Write-Host "⚠️ Fichiers temporaires conservés" -ForegroundColor Yellow
    }
} else {
    Write-Host "✅ Aucun autre fichier temporaire détecté" -ForegroundColor Green
}

# État final après nettoyage
Write-Host "`n--- ÉTAT FINAL APRÈS NETTOYAGE ---" -ForegroundColor Yellow
$finalStatus = git status --porcelain
$finalCount = ($finalStatus | Measure-Object).Count

Write-Host "Fichiers restants à traiter : $finalCount" -ForegroundColor Cyan
if ($finalStatus) {
    Write-Host "Détail :"
    $finalStatus | ForEach-Object { Write-Host "  $_" }
}

Write-Host "`n=== NETTOYAGE TERMINÉ ===" -ForegroundColor Green
Write-Host "Fichiers temporaires nettoyés avec succès" -ForegroundColor Cyan