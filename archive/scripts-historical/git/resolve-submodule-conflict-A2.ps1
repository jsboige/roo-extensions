# Résolution du conflit de sous-module mcps/internal - Action A.2
# Date: 2025-10-13

$ErrorActionPreference = "Stop"

Write-Host "=== RESOLUTION CONFLIT SOUS-MODULE mcps/internal ===" -ForegroundColor Cyan
Write-Host ""

# Aller dans le sous-module
Push-Location mcps/internal
try {
    Write-Host "1. État actuel du sous-module:" -ForegroundColor Yellow
    git status
    git log --oneline -5
    
    Write-Host "`n2. Branches disponibles:" -ForegroundColor Yellow
    git branch -a
    
    Write-Host "`n3. Tentative de merge du commit 584810d..." -ForegroundColor Cyan
    try {
        git merge 584810d --no-edit
        Write-Host "  [OK] Merge réussi" -ForegroundColor Green
    } catch {
        Write-Host "  [ERREUR] Merge impossible: $_" -ForegroundColor Red
        Write-Host "`n  Tentative alternative: rebase..." -ForegroundColor Yellow
        try {
            git rebase origin/local-integration-internal-mcps
            Write-Host "  [OK] Rebase réussi" -ForegroundColor Green
        } catch {
            Write-Host "  [ERREUR] Rebase impossible: $_" -ForegroundColor Red
            throw "Impossible de résoudre le conflit automatiquement"
        }
    }
    
    Write-Host "`n4. Push du résultat..." -ForegroundColor Cyan
    git push origin local-integration-internal-mcps
    Write-Host "  [OK] Push réussi" -ForegroundColor Green
    
} finally {
    Pop-Location
}

Write-Host "`n5. Retour au dépôt principal - enregistrement de la résolution..." -ForegroundColor Cyan
git add mcps/internal
Write-Host "  [OK] Sous-module mcps/internal ajouté" -ForegroundColor Green

Write-Host "`n6. Finalisation du merge dans le dépôt principal..." -ForegroundColor Cyan
git commit --no-edit
Write-Host "  [OK] Merge commit créé" -ForegroundColor Green

Write-Host "`n7. Push du dépôt principal..." -ForegroundColor Cyan
git push origin main
Write-Host "  [OK] Push réussi" -ForegroundColor Green

Write-Host "`n=== CONFLIT RESOLU ===" -ForegroundColor Green