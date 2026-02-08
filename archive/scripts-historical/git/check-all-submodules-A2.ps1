# Script temporaire pour vérifier l'état de tous les sous-modules
$ErrorActionPreference = "Continue"

Write-Host "=== VÉRIFICATION DE TOUS LES SOUS-MODULES ===" -ForegroundColor Cyan
Write-Host ""

# Récupérer la liste des sous-modules
$submodules = git submodule | ForEach-Object { 
    $parts = $_.Trim() -split '\s+'
    if ($parts.Length -ge 2) {
        $parts[1]
    }
}

$results = @()

foreach ($sm in $submodules) {
    Write-Host "`n--- Sous-module: $sm ---" -ForegroundColor Yellow
    
    if (Test-Path $sm) {
        Push-Location $sm
        
        # Statut
        $status = git status --short
        Write-Host "Status: $(if ($status) { 'Modifié' } else { 'Clean' })" -ForegroundColor $(if ($status) { 'Red' } else { 'Green' })
        
        # Dernier commit
        $lastCommit = git log --oneline -1
        Write-Host "Dernier commit: $lastCommit" -ForegroundColor Cyan
        
        # Branche actuelle
        $branch = git rev-parse --abbrev-ref HEAD
        Write-Host "Branche: $branch" -ForegroundColor Magenta
        
        # Ajouter aux résultats
        $results += [PSCustomObject]@{
            Path = $sm
            Branch = $branch
            LastCommit = $lastCommit
            Status = if ($status) { "Modified" } else { "Clean" }
        }
        
        Pop-Location
    } else {
        Write-Host "ERREUR: Chemin non trouvé!" -ForegroundColor Red
    }
}

Write-Host "`n`n=== RÉSUMÉ ===" -ForegroundColor Cyan
$results | Format-Table -AutoSize

Write-Host "`nTotal sous-modules: $($results.Count)" -ForegroundColor Green