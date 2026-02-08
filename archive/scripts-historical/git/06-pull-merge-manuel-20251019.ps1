# Script de pull méticuleux avec merge manuel - Mission Nettoyage Git
# Date: 2025-10-19
# Objectif: Pull avec merge manuel et préservation de l'historique

Write-Host "=== PULL MÉTICULEUX AVEC MERGE MANUEL ===" -ForegroundColor Cyan
Write-Host "Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray

# État actuel avant le pull
Write-Host "`n--- État actuel avant le pull ---" -ForegroundColor Yellow
git status --branch
git log --oneline -3

# Récupérer les informations du remote
Write-Host "`n--- Récupération des informations du remote ---" -ForegroundColor Yellow
git fetch origin

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Erreur lors du fetch du remote" -ForegroundColor Red
    exit 1
}

Write-Host "✅ Fetch réussi" -ForegroundColor Green

# Comparer les commits locaux et distants
Write-Host "`n--- Analyse des divergences ---" -ForegroundColor Yellow
$localCommit = git rev-parse HEAD
$remoteCommit = git rev-parse origin/main

Write-Host "Commit local : $localCommit"
Write-Host "Commit remote : $remoteCommit"

if ($localCommit -eq $remoteCommit) {
    Write-Host "✅ Repo principal déjà synchronisé avec origin/main" -ForegroundColor Green
    Write-Host "Aucun pull nécessaire" -ForegroundColor Cyan
} else {
    Write-Host "⚠️ Divergence détectée entre local et remote" -ForegroundColor Yellow
    
    # Afficher les commits qui vont être mergés
    Write-Host "`n--- Commits qui vont être mergés depuis origin/main ---" -ForegroundColor Yellow
    git log --oneline HEAD..origin/main | ForEach-Object { Write-Host "  + $_" }
    
    Write-Host "`n--- Nos commits locaux qui vont être préservés ---" -ForegroundColor Yellow
    git log --oneline origin/main..HEAD | ForEach-Object { Write-Host "  * $_" }
    
    # Créer un backup avant le merge
    $backupBranch = "backup-before-merge-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    Write-Host "`n--- Création du backup ---" -ForegroundColor Yellow
    git branch $backupBranch
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Branch de backup créée : $backupBranch" -ForegroundColor Green
    } else {
        Write-Host "❌ Erreur lors de la création du backup" -ForegroundColor Red
        exit 1
    }
    
    # Merge manuel avec stratégie --no-ff
    Write-Host "`n--- Merge manuel ---" -ForegroundColor Yellow
    Write-Host "Stratégie : merge --no-ff pour préserver l'historique complet" -ForegroundColor Cyan
    
    $mergeMessage = "Merge origin/main - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Préservation historique complet"
    git merge origin/main --no-ff -m $mergeMessage
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Merge réussi sans conflits" -ForegroundColor Green
    } else {
        Write-Host "❌ CONFLITS DÉTECTÉS - Résolution manuelle nécessaire" -ForegroundColor Red
        Write-Host "`nFichiers en conflit :" -ForegroundColor Yellow
        $conflicts = git diff --name-only --diff-filter=U
        $conflicts | ForEach-Object { Write-Host "  ⚠️ $_" }
        
        Write-Host "`nVeuillez résoudre les conflits manuellement puis exécuter :" -ForegroundColor Yellow
        Write-Host "  git add ." -ForegroundColor Gray
        Write-Host "  git commit -m 'Résolution des conflits'" -ForegroundColor Gray
        Write-Host "`nScript interrompu" -ForegroundColor Red
        exit 1
    }
}

# État après le merge
Write-Host "`n--- État après le merge ---" -ForegroundColor Yellow
git status --branch
git log --oneline -5

# Vérifier s'il y a des commits à pousser
$commitsToPush = git log --oneline origin/main..HEAD | Measure-Object
Write-Host "`n--- Statistiques des commits ---" -ForegroundColor Yellow
Write-Host "Commits à pousser : $($commitsToPush.Count)" -ForegroundColor Cyan

if ($commitsToPush.Count -gt 0) {
    Write-Host "`nDétail des commits à pousser :" -ForegroundColor Gray
    git log --oneline origin/main..HEAD | ForEach-Object { Write-Host "  $_" }
} else {
    Write-Host "Aucun commit à pousser" -ForegroundColor Gray
}

# Vérifier l'état des sous-modules après le merge
Write-Host "`n--- État des sous-modules après le merge ---" -ForegroundColor Yellow
git submodule status

Write-Host "`n=== PULL MÉTICULEUX TERMINÉ ===" -ForegroundColor Green
Write-Host "Prêt pour le push final" -ForegroundColor Cyan