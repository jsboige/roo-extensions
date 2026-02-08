# Script de diagnostic et correction du problème "publier notre branche main"
# Date : 2025-10-20
# Objectif : Identifier et corriger le problème de tracking entre local et remote

Write-Host "=== DIAGNOSTIC URGENT : État des branches ===" -ForegroundColor Red

# État détaillé des branches locales et remote
Write-Host "`n--- Branches locales ---" -ForegroundColor Yellow
git branch -vv
git branch -a

# État du tracking
Write-Host "`n--- État du tracking ---" -ForegroundColor Yellow
git status --branch
git log --oneline -3

# Vérifier la relation avec origin/main
Write-Host "`n--- Relation avec origin/main ---" -ForegroundColor Yellow
$localCommit = git rev-parse HEAD
$remoteCommit = git rev-parse origin/main 2>$null

Write-Host "Local HEAD : $localCommit"
if ($remoteCommit) {
    Write-Host "Origin/main : $remoteCommit"
    if ($localCommit -eq $remoteCommit) {
        Write-Host "✅ Local et remote synchronisés" -ForegroundColor Green
    } else {
        Write-Host "❌ Divergence entre local et remote" -ForegroundColor Red
        Write-Host "Commits en plus localement :"
        git log --oneline origin/main..HEAD
        Write-Host "Commits en plus sur remote :"
        git log --oneline HEAD..origin/main
    }
} else {
    Write-Host "❌ origin/main n'existe pas !" -ForegroundColor Red
}

# Vérifier la configuration du remote
Write-Host "`n--- Configuration du remote ---" -ForegroundColor Yellow
git remote -v
git remote show origin

Write-Host "`n=== ANALYSE DE LA CAUSE ===" -ForegroundColor Red

# Vérifier si la branche main est correctement configurée
$branchConfig = git config --get branch.main.merge
$remoteConfig = git config --get branch.main.remote

Write-Host "Configuration de la branche main :"
Write-Host "  Remote : $remoteConfig"
Write-Host "  Merge : $branchConfig"

if (-not $remoteConfig -or $remoteConfig -ne "origin") {
    Write-Host "❌ Problème : La branche main n'est pas trackée avec origin" -ForegroundColor Red
}

if (-not $branchConfig -or $branchConfig -ne "refs/heads/main") {
    Write-Host "❌ Problème : La configuration de merge est incorrecte" -ForegroundColor Red
}

# Vérifier si on est sur la bonne branche
$currentBranch = git rev-parse --abbrev-ref HEAD
Write-Host "Branche actuelle : $currentBranch"

if ($currentBranch -ne "main") {
    Write-Host "❌ Problème : On n'est pas sur la branche main" -ForegroundColor Red
}

Write-Host "`n=== DIAGNOSTIC TERMINÉ ===" -ForegroundColor Red
Write-Host "Prochaines étapes : Exécuter le script de correction 10-correct-publish-main-20251020.ps1"