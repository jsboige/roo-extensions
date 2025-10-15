# Merge manuel prudent mcps/internal - Action A.2
# Date: 2025-10-14

$ErrorActionPreference = "Stop"

Write-Host "=== MERGE MANUEL mcps/internal ===" -ForegroundColor Cyan
Write-Host ""

Push-Location mcps/internal
try {
    Write-Host "1. État avant merge:" -ForegroundColor Yellow
    git status
    
    Write-Host "`n2. Lancement du merge avec 584810d..." -ForegroundColor Yellow
    try {
        git merge 584810d --no-ff --no-commit
        Write-Host "[INFO] Merge préparé, inspection des conflits..." -ForegroundColor Cyan
    } catch {
        Write-Host "[ATTENTION] Conflits détectés - c'est attendu" -ForegroundColor Yellow
    }
    
    Write-Host "`n3. État après tentative de merge:" -ForegroundColor Yellow
    git status
    
    Write-Host "`n4. Liste des fichiers en conflit:" -ForegroundColor Yellow
    $conflicts = git diff --name-only --diff-filter=U
    if ($conflicts) {
        Write-Host "[CONFLITS]" -ForegroundColor Red
        $conflicts | ForEach-Object { Write-Host "  ! $_" -ForegroundColor Red }
    } else {
        Write-Host "[PAS DE CONFLITS] Merge propre!" -ForegroundColor Green
    }
    
    Write-Host "`n=== PROCHAINES ÉTAPES MANUELLES ===" -ForegroundColor Cyan
    Write-Host ""
    if ($conflicts) {
        Write-Host "Des conflits ont été détectés. Pour chaque fichier:" -ForegroundColor Yellow
        $conflicts | ForEach-Object {
            Write-Host "`nFichier: $_" -ForegroundColor White
            Write-Host "  1. Ouvrir le fichier dans l'éditeur" -ForegroundColor Gray
            Write-Host "  2. Chercher les marqueurs <<<<<<< HEAD" -ForegroundColor Gray
            Write-Host "  3. Résoudre manuellement" -ForegroundColor Gray
            Write-Host "  4. git add $_" -ForegroundColor Gray
        }
        Write-Host "`nAprès résolution de TOUS les conflits:" -ForegroundColor Yellow
        Write-Host "  git commit" -ForegroundColor Gray
        Write-Host "  git push origin local-integration-internal-mcps" -ForegroundColor Gray
    } else {
        Write-Host "Pas de conflits! Finaliser:" -ForegroundColor Green
        Write-Host "  git commit" -ForegroundColor Gray
        Write-Host "  git push origin local-integration-internal-mcps" -ForegroundColor Gray
    }
    
} finally {
    Pop-Location
}

Write-Host "`n=== SCRIPT TERMINÉ ===" -ForegroundColor Cyan
Write-Host "Le merge est préparé mais NON commité." -ForegroundColor Yellow
Write-Host "Vérifiez les conflits et finalisez manuellement." -ForegroundColor Yellow