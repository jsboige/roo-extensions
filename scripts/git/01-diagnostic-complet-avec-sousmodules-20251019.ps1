# Script de diagnostic complet Git avec sous-modules - Mission Nettoyage et synchronisation
# Date: 2025-10-19
# Objectif: Diagnostic complet de l'état Git incluant les sous-modules

Write-Host "=== DIAGNOSTIC COMPLET GIT AVEC SOUS-MODULES ===" -ForegroundColor Cyan
Write-Host "Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host "Répertoire: $(Get-Location)" -ForegroundColor Gray

# État du repo principal
Write-Host "`n--- ÉTAT DU REPO PRINCIPAL ---" -ForegroundColor Yellow
$gitStatus = git status --porcelain
$gitStatusBranch = git status --branch

Write-Host "Status détaillé:"
$gitStatus | ForEach-Object { Write-Host "  $_" }
Write-Host "`nStatus branch:"
$gitStatusBranch | ForEach-Object { Write-Host "  $_" }

$mainRepoCount = ($gitStatus | Measure-Object).Count
Write-Host "`nFichiers modifiés dans le repo principal : $mainRepoCount" -ForegroundColor Green

# Analyser les types de modifications dans le repo principal
$modified = $gitStatus | Where-Object { $_ -match "^ M" }
$untracked = $gitStatus | Where-Object { $_ -match "^??" }
$deleted = $gitStatus | Where-Object { $_ -match "^ D" }

Write-Host "Fichiers modifiés : $($modified.Count)"
Write-Host "Fichiers non suivis : $($untracked.Count)"
Write-Host "Fichiers supprimés : $($deleted.Count)"

# État des sous-modules
Write-Host "`n--- ÉTAT DES SOUS-MODULES ---" -ForegroundColor Yellow
try {
    $submoduleStatus = git submodule status
    if ($submoduleStatus) {
        Write-Host "Sous-modules détectés:"
        $submoduleStatus | ForEach-Object { Write-Host "  $_" }
        
        $totalSubmoduleFiles = 0
        
        Write-Host "`nAnalyse détaillée des sous-modules:"
        git submodule foreach '
            echo "=== Sous-module: $name ==="
            cd $toplevel/$path
            submoduleStatus=$(git status --porcelain)
            submoduleCount=$(echo "$submoduleStatus" | wc -l)
            echo "Fichiers modifiés: $submoduleCount"
            if [ $submoduleCount -gt 0 ]; then
                echo "$submoduleStatus"
            fi
            echo "---"
        ' | ForEach-Object { 
            Write-Host "  $_"
            if ($_ -match "Fichiers modifiés: (\d+)") {
                $totalSubmoduleFiles += [int]$matches[1]
            }
        }
        
        Write-Host "`nTotal fichiers dans les sous-modules : $totalSubmoduleFiles" -ForegroundColor Green
    } else {
        Write-Host "Aucun sous-module détecté" -ForegroundColor Gray
    }
} catch {
    Write-Host "Erreur lors de la vérification des sous-modules: $($_.Exception.Message)" -ForegroundColor Red
}

# Total des notifications Git
$totalNotifications = $mainRepoCount + $totalSubmoduleFiles
Write-Host "`n--- TOTAL DES NOTIFICATIONS GIT ---" -ForegroundColor Yellow
Write-Host "Repo principal : $mainRepoCount fichiers" -ForegroundColor Cyan
Write-Host "Sous-modules : $totalSubmoduleFiles fichiers" -ForegroundColor Cyan
Write-Host "TOTAL : $totalNotifications notifications Git" -ForegroundColor Green

# Branches et remote
Write-Host "`n--- BRANCHES ET REMOTE ---" -ForegroundColor Yellow
$branches = git branch -a
$remotes = git remote -v

Write-Host "Branches:"
$branches | ForEach-Object { Write-Host "  $_" }

Write-Host "`nRemotes:"
$remotes | ForEach-Object { Write-Host "  $_" }

# Derniers commits
Write-Host "`n--- DERNIERS COMMITS LOCAUX ---" -ForegroundColor Yellow
git log --oneline -5 | ForEach-Object { Write-Host "  $_" }

try {
    Write-Host "`n--- DERNIERS COMMITS REMOTE ---" -ForegroundColor Yellow
    git log --oneline origin/main -5 | ForEach-Object { Write-Host "  $_" }
} catch {
    Write-Host "Impossible de récupérer les commits du remote" -ForegroundColor Red
}

# Sauvegarde du diagnostic complet
$diagnosticFile = "outputs/git-diagnostic-complet-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
$diagnosticData = @{
    Date = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    Repository = Get-Location
    MainRepoFilesCount = $mainRepoCount
    SubmoduleFilesCount = $totalSubmoduleFiles
    TotalNotifications = $totalNotifications
    MainRepoModified = $modified.Count
    MainRepoUntracked = $untracked.Count
    MainRepoDeleted = $deleted.Count
    MainRepoFiles = $gitStatus
}

$diagnosticData | ConvertTo-Json -Depth 3 | Out-File -FilePath $diagnosticFile -Encoding UTF8
Write-Host "`nDiagnostic complet sauvegardé dans: $diagnosticFile" -ForegroundColor Green

Write-Host "`n=== DIAGNOSTIC COMPLET TERMINÉ ===" -ForegroundColor Green
Write-Host "Total des notifications Git à traiter : $totalNotifications" -ForegroundColor Cyan