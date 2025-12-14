# Script de diagnostic Git simple - Mission Nettoyage et synchronisation
# Date: 2025-10-19
# Objectif: Diagnostic rapide de l'état Git

Write-Host "=== DIAGNOSTIC GIT SIMPLIFIÉ ===" -ForegroundColor Cyan
Write-Host "Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host "Répertoire: $(Get-Location)" -ForegroundColor Gray

# État du repo principal
Write-Host "`n--- État du repo principal ---" -ForegroundColor Yellow
$gitStatus = git status --porcelain
$gitStatusBranch = git status --branch

Write-Host "Status détaillé:"
$gitStatus | ForEach-Object { Write-Host "  $_" }
Write-Host "`nStatus branch:"
$gitStatusBranch | ForEach-Object { Write-Host "  $_" }

# Compter les fichiers
$notificationCount = ($gitStatus | Measure-Object).Count
Write-Host "`nNombre total de fichiers modifiés : $notificationCount" -ForegroundColor Green

# Analyser les types de modifications
$modified = $gitStatus | Where-Object { $_ -match "^ M" }
$untracked = $gitStatus | Where-Object { $_ -match "^??" }
$deleted = $gitStatus | Where-Object { $_ -match "^ D" }

Write-Host "Fichiers modifiés : $($modified.Count)"
Write-Host "Fichiers non suivis : $($untracked.Count)"
Write-Host "Fichiers supprimés : $($deleted.Count)"

# Branches et remote
Write-Host "`n--- Branches et remote ---" -ForegroundColor Yellow
$branches = git branch -a
$remotes = git remote -v

Write-Host "Branches:"
$branches | ForEach-Object { Write-Host "  $_" }

Write-Host "`nRemotes:"
$remotes | ForEach-Object { Write-Host "  $_" }

# Derniers commits
Write-Host "`n--- Derniers commits locaux ---" -ForegroundColor Yellow
git log --oneline -5 | ForEach-Object { Write-Host "  $_" }

try {
    Write-Host "`n--- Derniers commits remote ---" -ForegroundColor Yellow
    git log --oneline origin/main -5 | ForEach-Object { Write-Host "  $_" }
} catch {
    Write-Host "Impossible de récupérer les commits du remote" -ForegroundColor Red
}

Write-Host "`n=== DIAGNOSTIC TERMINÉ ===" -ForegroundColor Green
Write-Host "Total: $notificationCount fichiers à traiter" -ForegroundColor Cyan