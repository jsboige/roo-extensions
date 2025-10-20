# Script de synchronisation des sous-modules - Mission Nettoyage Git
# Date: 2025-10-19
# Objectif: Synchroniser les sous-modules et mettre à jour les références

Write-Host "=== SYNCHRONISATION DES SOUS-MODULES ===" -ForegroundColor Cyan
Write-Host "Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray

# Vérifier l'état actuel des sous-modules
Write-Host "`n--- État actuel des sous-modules ---" -ForegroundColor Yellow
git submodule status

# Vérifier s'il y a des modifications dans les sous-modules
Write-Host "`n--- Analyse détaillée des sous-modules ---" -ForegroundColor Yellow
$submodulesWithChanges = @()

git submodule foreach '
    echo "=== Analyse du sous-module: $name ==="
    submoduleStatus=$(git status --porcelain)
    submoduleCount=$(echo "$submoduleStatus" | wc -l)
    echo "Fichiers modifiés: $submoduleCount"
    
    if [ $submoduleCount -gt 0 ]; then
        echo "Fichiers modifiés détaillés:"
        echo "$submoduleStatus"
        echo "NECESSITE SYNCHRONISATION"
    else
        echo "Déjà à jour"
    fi
    echo "---"
' | ForEach-Object { 
    Write-Host "  $_"
    if ($_ -match "NECESSITE SYNCHRONISATION") {
        $submodulesWithChanges += $true
    }
}

# Synchroniser les sous-modules si nécessaire
if ($submodulesWithChanges.Count -gt 0) {
    Write-Host "`n--- Synchronisation des sous-modules ---" -ForegroundColor Yellow
    
    git submodule foreach '
        echo "=== Synchronisation de $name ==="
        submoduleStatus=$(git status --porcelain)
        submoduleCount=$(echo "$submoduleStatus" | wc -l)
        
        if [ $submoduleCount -gt 0 ]; then
            echo "Ajout des fichiers modifiés..."
            git add .
            
            echo "Création du commit de synchronisation..."
            git commit -m "Auto-sync $name - $(date +'%Y-%m-%d %H:%M:%S')"
            
            if [ $? -eq 0 ]; then
                echo "✅ $name synchronisé avec succès"
            else
                echo "❌ Erreur lors de la synchronisation de $name"
            fi
        else
            echo "✅ $name déjà à jour"
        fi
        echo "---"
    '
} else {
    Write-Host "`n✅ Tous les sous-modules sont déjà à jour" -ForegroundColor Green
}

# Mettre à jour les références des sous-modules dans le repo principal
Write-Host "`n--- Mise à jour des références des sous-modules ---" -ForegroundColor Yellow

# Vérifier si les références des sous-modules ont changé
$submoduleChanges = git status --porcelain | Where-Object { $_ -match "mcps/" }
if ($submoduleChanges) {
    Write-Host "Mise à jour des références des sous-modules détectée" -ForegroundColor Yellow
    
    foreach ($change in $submoduleChanges) {
        Write-Host "  $change"
    }
    
    # Ajouter les changements des sous-modules
    git add mcps/
    
    # Créer un commit pour mettre à jour les références
    git commit -m "chore(submodules): Update submodule references after sync - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Références des sous-modules mises à jour" -ForegroundColor Green
    } else {
        Write-Host "ℹ️ Aucune mise à jour nécessaire pour les références" -ForegroundColor Gray
    }
} else {
    Write-Host "ℹ️ Aucun changement de référence de sous-module à commité" -ForegroundColor Gray
}

# État final après synchronisation
Write-Host "`n--- État final après synchronisation ---" -ForegroundColor Yellow
$finalStatus = git status --porcelain
$finalCount = ($finalStatus | Measure-Object).Count

Write-Host "Fichiers modifiés après synchronisation : $finalCount" -ForegroundColor Cyan
if ($finalStatus) {
    Write-Host "Détail :"
    $finalStatus | ForEach-Object { Write-Host "  $_" }
} else {
    Write-Host "✅ Aucun fichier modifié après synchronisation" -ForegroundColor Green
}

# Afficher l'état final des sous-modules
Write-Host "`n--- État final des sous-modules ---" -ForegroundColor Yellow
git submodule status

# Statistiques des commits
$commitCount = (git log --oneline origin/main..HEAD | Measure-Object).Count
Write-Host "`n--- Statistiques ---" -ForegroundColor Yellow
Write-Host "Total des commits créés : $commitCount" -ForegroundColor Cyan
Write-Host "Commits à pousser vers origin/main : $commitCount" -ForegroundColor Cyan

Write-Host "`n=== SYNCHRONISATION DES SOUS-MODULES TERMINÉE ===" -ForegroundColor Green