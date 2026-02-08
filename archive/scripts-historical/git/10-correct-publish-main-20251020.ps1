# Script de correction du problème "publier notre branche main"
# Date : 2025-10-20
# Objectif : Corriger le tracking et synchroniser la branche main

Write-Host "=== CORRECTION DU TRACKING ===" -ForegroundColor Red

# S'assurer qu'on est sur la branche main
$currentBranch = git rev-parse --abbrev-ref HEAD
if ($currentBranch -ne "main") {
    Write-Host "Switch vers la branche main..." -ForegroundColor Yellow
    git checkout main
} else {
    Write-Host "✅ Déjà sur la branche main" -ForegroundColor Green
}

# Configurer correctement le tracking si nécessaire
$remoteConfig = git config --get branch.main.remote
$branchConfig = git config --get branch.main.merge

Write-Host "`nConfiguration actuelle :" -ForegroundColor Yellow
Write-Host "  Remote : $remoteConfig"
Write-Host "  Merge : $branchConfig"

if (-not $remoteConfig -or $remoteConfig -ne "origin") {
    Write-Host "Configuration du tracking de la branche main..." -ForegroundColor Yellow
    
    # Supprimer l'ancienne configuration si elle existe
    git config --unset branch.main.remote 2>$null
    git config --unset branch.main.merge 2>$null
    
    # Configurer le tracking correct
    git branch --set-upstream-to=origin/main main
    
    Write-Host "✅ Tracking configuré : main -> origin/main" -ForegroundColor Green
} else {
    Write-Host "✅ Tracking déjà correctement configuré" -ForegroundColor Green
}

# Vérifier la correction
Write-Host "`n--- Vérification post-correction ---" -ForegroundColor Yellow
git branch -vv
git status --branch

Write-Host "`n=== SYNCHRONISATION CORRECTE ===" -ForegroundColor Red

# Fetch pour mettre à jour les informations du remote
Write-Host "Fetch des informations du remote..." -ForegroundColor Yellow
git fetch origin

# Vérifier l'état après fetch
$localCommit = git rev-parse HEAD
$remoteCommit = git rev-parse origin/main 2>$null

Write-Host "Après fetch :"
Write-Host "  Local : $localCommit"
if ($remoteCommit) {
    Write-Host "  Remote : $remoteCommit"
    
    # Si on est en avance sur le remote, push normalement
    if ($localCommit -ne $remoteCommit) {
        $commitsAhead = git log --oneline origin/main..HEAD | Measure-Object
        $commitsBehind = git log --oneline HEAD..origin/main | Measure-Object
        
        Write-Host "Commits en avance : $($commitsAhead.Count)"
        Write-Host "Commits en retard : $($commitsBehind.Count)"
        
        if ($commitsAhead.Count -gt 0 -and $commitsBehind.Count -eq 0) {
            Write-Host "On est en avance, push normal..." -ForegroundColor Yellow
            git push origin main
        } elseif ($commitsBehind.Count -gt 0) {
            Write-Host "On est en retard, pull nécessaire..." -ForegroundColor Yellow
            git pull origin main
        } else {
            Write-Host "Divergence, merge nécessaire..." -ForegroundColor Yellow
            git pull origin main --no-ff
        }
    } else {
        Write-Host "✅ Déjà synchronisé" -ForegroundColor Green
    }
} else {
    Write-Host "❌ origin/main n'existe pas après fetch" -ForegroundColor Red
    Write-Host "Vérification de la connexion au remote..." -ForegroundColor Yellow
    git remote -v
}

Write-Host "`n=== VALIDATION FINALE ===" -ForegroundColor Red

# État final
Write-Host "`n--- État final ---" -ForegroundColor Yellow
git status --branch
git branch -vv

# Test de synchronisation
Write-Host "`n--- Test de synchronisation ---" -ForegroundColor Yellow
$finalLocal = git rev-parse HEAD
$finalRemote = git rev-parse origin/main 2>$null

if ($finalRemote -and $finalLocal -eq $finalRemote) {
    Write-Host "✅ SYNCHRONISATION PARFAITE" -ForegroundColor Green
    Write-Host "Local et remote sont identiques"
} else {
    Write-Host "❌ Problème persistant" -ForegroundColor Red
    Write-Host "Local : $finalLocal"
    Write-Host "Remote : $finalRemote"
}

# Vérifier que VS Code ne propose plus de "publier"
Write-Host "`n--- Diagnostic VS Code ---" -ForegroundColor Yellow
Write-Host "Si VS Code propose encore de 'publier la branche main', le problème persiste."
Write-Host "Dans ce cas, redémarrer VS Code peut résoudre le problème d'affichage."

Write-Host "`n=== CORRECTION TERMINÉE ===" -ForegroundColor Red