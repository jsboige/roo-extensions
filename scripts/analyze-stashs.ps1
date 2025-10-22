# Script d'analyse des stashs Git
# Génère un rapport détaillé pour chaque stash

Write-Host "=== ANALYSE DES STASHS GIT ===" -ForegroundColor Green
Write-Host ""

# Liste tous les stashs
$stashList = git stash list

Write-Host "Nombre total de stashs: $($stashList.Count)" -ForegroundColor Cyan
Write-Host ""

# Analyser chaque stash
for ($i = 0; $i -lt $stashList.Count; $i++) {
    Write-Host "=== STASH@{$i} ===" -ForegroundColor Yellow
    Write-Host "Message: $($stashList[$i])" -ForegroundColor White
    Write-Host ""
    
    # Statistiques
    Write-Host "Fichiers modifiés:" -ForegroundColor Cyan
    git stash show "stash@{$i}" --stat
    Write-Host ""
    
    # Fichiers (name-only)
    Write-Host "Liste des fichiers:" -ForegroundColor Cyan
    git stash show "stash@{$i}" --name-only
    Write-Host ""
    Write-Host "----------------------------------------" -ForegroundColor Gray
    Write-Host ""
}