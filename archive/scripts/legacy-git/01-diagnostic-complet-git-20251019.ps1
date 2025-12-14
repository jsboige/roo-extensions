# Script de diagnostic complet Git - Mission Nettoyage et synchronisation
# Date: 2025-10-19
# Objectif: Diagnostic complet de l'état Git avant nettoyage

Write-Host "=== DIAGNOSTIC COMPLET DE L'ÉTAT GIT ===" -ForegroundColor Cyan
Write-Host "Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host "Répertoire: $(Get-Location)" -ForegroundColor Gray

# État du repo principal
Write-Host "`n--- État du repo principal ---" -ForegroundColor Yellow
$gitStatus = git status --porcelain
$gitStatusBranch = git status --branch
$gitLog = git log --oneline -5

Write-Host "Status détaillé:"
$gitStatus | ForEach-Object { Write-Host "  $_" }
Write-Host "`nStatus branch:"
$gitStatusBranch | ForEach-Object { Write-Host "  $_" }
Write-Host "`nDerniers commits:"
$gitLog | ForEach-Object { Write-Host "  $_" }

# Vérifier les notifications Git (VS Code)
Write-Host "`n--- Notifications Git VS Code ---" -ForegroundColor Yellow
$notificationCount = ($gitStatus | Measure-Object).Count
Write-Host "Nombre total de fichiers modifiés : $notificationCount"

# Analyser les types de modifications
$modified = $gitStatus | Where-Object { $_ -match "^ M" }
$untracked = $gitStatus | Where-Object { $_ -match "^??" }
$deleted = $gitStatus | Where-Object { $_ -match "^ D" }
$added = $gitStatus | Where-Object { $_ -match "^A " }
$renamed = $gitStatus | Where-Object { $_ -match "^R " }

Write-Host "Fichiers modifiés : $($modified.Count)"
Write-Host "Fichiers non suivis : $($untracked.Count)"
Write-Host "Fichiers supprimés : $($deleted.Count)"
Write-Host "Fichiers ajoutés : $($added.Count)"
Write-Host "Fichiers renommés : $($renamed.Count)"

# Détail des fichiers par catégorie
if ($modified.Count -gt 0) {
    Write-Host "`nFichiers modifiés détaillés:" -ForegroundColor Magenta
    $modified | ForEach-Object { Write-Host "  $_" }
}

if ($untracked.Count -gt 0) {
    Write-Host "`nFichiers non suivis détaillés:" -ForegroundColor Magenta
    $untracked | ForEach-Object { Write-Host "  $_" }
}

if ($deleted.Count -gt 0) {
    Write-Host "`nFichiers supprimés détaillés:" -ForegroundColor Magenta
    $deleted | ForEach-Object { Write-Host "  $_" }
}

# État des sous-modules
Write-Host "`n--- État des sous-modules ---" -ForegroundColor Yellow
try {
    $submoduleStatus = git submodule status
    if ($submoduleStatus) {
        $submoduleStatus | ForEach-Object { Write-Host "  $_" }
        
        Write-Host "`nDétail des sous-modules:"
        git submodule foreach 'echo "=== $name ===" && git status --porcelain && git log --oneline -3'
    } else {
        Write-Host "Aucun sous-module détecté" -ForegroundColor Gray
    }
} catch {
    Write-Host "Erreur lors de la vérification des sous-modules: $($_.Exception.Message)" -ForegroundColor Red
}

# Branches et remote
Write-Host "`n--- Branches et remote ---" -ForegroundColor Yellow
$branches = git branch -a
$remotes = git remote -v

Write-Host "Branches locales et distantes:"
$branches | ForEach-Object { Write-Host "  $_" }

Write-Host "`nRemotes configurés:"
$remotes | ForEach-Object { Write-Host "  $_" }

# État du remote
try {
    $remoteLog = git log --oneline origin/main -5
    Write-Host "`nDerniers commits sur origin/main:"
    $remoteLog | ForEach-Object { Write-Host "  $_" }
} catch {
    Write-Host "Impossible de récupérer les commits du remote: $($_.Exception.Message)" -ForegroundColor Red
}

# Analyse des fichiers par type
Write-Host "`n--- Analyse des fichiers par type ---" -ForegroundColor Yellow
$extensions = @{}
$directories = @{}

foreach ($file in $gitStatus) {
    $filePath = $file.Substring(3)
    $extension = [System.IO.Path]::GetExtension($filePath)
    $directory = Split-Path $filePath -Parent
    
    if ($extension) {
        if ($extensions.ContainsKey($extension)) {
            $extensions[$extension]++
        } else {
            $extensions[$extension] = 1
        }
    }
    
    if ($directory) {
        if ($directories.ContainsKey($directory)) {
            $directories[$directory]++
        } else {
            $directories[$directory] = 1
        }
    }
}

Write-Host "Répartition par extension:"
$extensions.GetEnumerator() | Sort-Object -Property Value -Descending | ForEach-Object { 
    Write-Host "  $($_.Key): $($_.Value) fichiers" 
}

Write-Host "`nRépartition par répertoire:"
$directories.GetEnumerator() | Sort-Object -Property Value -Descending | ForEach-Object { 
    Write-Host "  $($_.Key): $($_.Value) fichiers" 
}

# Sauvegarde du diagnostic
$diagnosticFile = "outputs/git-diagnostic-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
$diagnosticData = @{
    Date = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    Repository = Get-Location
    TotalFiles = $notificationCount
    Modified = $modified.Count
    Untracked = $untracked.Count
    Deleted = $deleted.Count
    Added = $added.Count
    Renamed = $renamed.Count
    Extensions = $extensions
    Directories = $directories
    Files = $gitStatus
}

$diagnosticData | ConvertTo-Json -Depth 3 | Out-File -FilePath $diagnosticFile -Encoding UTF8
Write-Host "`nDiagnostic sauvegardé dans: $diagnosticFile" -ForegroundColor Green

Write-Host "`n=== DIAGNOSTIC TERMINÉ ===" -ForegroundColor Green
Write-Host "Total: $notificationCount fichiers à traiter" -ForegroundColor Cyan