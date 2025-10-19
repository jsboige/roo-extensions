# Script d'analyse rapide des stashs autosave
# Génère un rapport structuré pour décision de recyclage

$repo = "d:/roo-extensions"
Set-Location $repo

Write-Host "=== ANALYSE STASHS AUTOSAVE - DÉPÔT PRINCIPAL ===" -ForegroundColor Cyan
Write-Host ""

# Analyser stashs @{2} à @{10}, @{12} à @{14} (autosave sync pull)
$autosaveIndices = 2..10 + 12..14

foreach ($i in $autosaveIndices) {
    Write-Host "--- Stash @{$i} ---" -ForegroundColor Yellow
    
    # Obtenir message et date
    $stashInfo = git stash list --date=iso | Select-String "stash@\{$i\}"
    Write-Host "Info: $stashInfo"
    
    # Obtenir statistiques fichiers
    Write-Host "Fichiers modifiés:"
    git stash show --stat "stash@{$i}"
    
    Write-Host ""
}

# Analyser stash @{11} (Roo temporary stash)
Write-Host "--- Stash @{11} (Roo temporary) ---" -ForegroundColor Yellow
$stashInfo = git stash list --date=iso | Select-String "stash@\{11\}"
Write-Host "Info: $stashInfo"
Write-Host "Fichiers modifiés:"
git stash show --stat "stash@{11}"
Write-Host ""

Write-Host "=== ANALYSE TERMINÉE ===" -ForegroundColor Green