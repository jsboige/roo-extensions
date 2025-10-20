# Script de synchronisation des sous-modules (Simple) - Mission Nettoyage Git
# Date: 2025-10-19
# Objectif: Synchroniser les sous-modules

Write-Host "=== SYNCHRONISATION DES SOUS-MODULES ===" -ForegroundColor Cyan
Write-Host "Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray

# État actuel des sous-modules
Write-Host "`n--- État actuel des sous-modules ---" -ForegroundColor Yellow
git submodule status

# Vérifier l'état du sous-module mcps/internal
Write-Host "`n--- Vérification du sous-module mcps/internal ---" -ForegroundColor Yellow
try {
    Set-Location "mcps/internal"
    $submoduleStatus = git status --porcelain
    
    if ($submoduleStatus) {
        Write-Host "Fichiers modifiés détectés :"
        $submoduleStatus | ForEach-Object { Write-Host "  $_" }
        
        Write-Host "`nAjout des fichiers et commit..." -ForegroundColor Yellow
        git add .
        git commit -m "Auto-sync mcps/internal - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ Sous-module mcps/internal synchronisé" -ForegroundColor Green
        } else {
            Write-Host "ℹ️ Aucun commit nécessaire pour mcps/internal" -ForegroundColor Gray
        }
    } else {
        Write-Host "✅ mcps/internal déjà à jour" -ForegroundColor Green
    }
    
    Set-Location "../../"
} catch {
    Set-Location "../../"
    Write-Host "❌ Erreur lors de la synchronisation de mcps/internal" -ForegroundColor Red
}

# Mettre à jour les références dans le repo principal
Write-Host "`n--- Mise à jour des références des sous-modules ---" -ForegroundColor Yellow
$mainStatus = git status --porcelain
$submoduleChanges = $mainStatus | Where-Object { $_ -match "mcps/" }

if ($submoduleChanges) {
    Write-Host "Changements de sous-modules détectés :"
    $submoduleChanges | ForEach-Object { Write-Host "  $_" }
    
    Write-Host "Mise à jour des références..." -ForegroundColor Yellow
    git add mcps/
    git commit -m "chore(submodules): Update submodule references - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Références des sous-modules mises à jour" -ForegroundColor Green
    } else {
        Write-Host "ℹ️ Aucune mise à jour nécessaire" -ForegroundColor Gray
    }
} else {
    Write-Host "ℹ️ Aucun changement de référence à mettre à jour" -ForegroundColor Gray
}

# État final
Write-Host "`n--- État final ---" -ForegroundColor Yellow
$finalStatus = git status --porcelain
$finalCount = ($finalStatus | Measure-Object).Count

Write-Host "Fichiers modifiés : $finalCount" -ForegroundColor Cyan
if ($finalStatus) {
    $finalStatus | ForEach-Object { Write-Host "  $_" }
} else {
    Write-Host "✅ Aucun fichier modifié" -ForegroundColor Green
}

Write-Host "`nÉtat final des sous-modules:" -ForegroundColor Yellow
git submodule status

# Statistiques
$commitCount = (git log --oneline origin/main..HEAD | Measure-Object).Count
Write-Host "`n--- Statistiques ---" -ForegroundColor Yellow
Write-Host "Total commits créés : $commitCount" -ForegroundColor Cyan
Write-Host "Commits à pousser : $commitCount" -ForegroundColor Cyan

Write-Host "`n=== SYNCHRONISATION TERMINÉE ===" -ForegroundColor Green