# Script d'organisation simple des fichiers par categorie
# Date: 2025-10-19
# Objectif: Analyser et categoriser tous les fichiers modifies

Write-Host "=== ORGANISATION DES FICHIERS PAR CATEGORIE ===" -ForegroundColor Cyan
Write-Host "Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray

# Fichiers du repo principal
$mainRepoFiles = git status --porcelain
Write-Host "Repo principal : $($mainRepoFiles.Count) fichiers" -ForegroundColor Yellow

# Fichiers du sous-module
$submoduleFiles = @()
try {
    Set-Location "mcps/internal"
    $submoduleStatus = git status --porcelain
    if ($submoduleStatus) {
        $submoduleFiles = $submoduleStatus | ForEach-Object { "M mcps/internal/$($_.Substring(3))" }
    }
    Set-Location "../../"
} catch {
    Set-Location "../../"
}

# Tous les fichiers
$allFiles = $mainRepoFiles + $submoduleFiles
Write-Host "Total fichiers : $($allFiles.Count)" -ForegroundColor Green

# Categories
$scriptsGit = @()
$scriptsMessaging = @()
$scriptsRepair = @()
$documentation = @()
$tempBackup = @()
$submodules = @()
$other = @()

# Categorisation
foreach ($file in $allFiles) {
    $status = $file.Substring(0, 2).Trim()
    $filePath = $file.Substring(3)
    
    $fileInfo = @{
        Status = $status
        Path = $filePath
    }
    
    if ($filePath -match "mcps/internal") {
        $submodules += $fileInfo
    }
    elseif ($filePath -match "scripts/git/") {
        $scriptsGit += $fileInfo
    }
    elseif ($filePath -match "scripts/messaging/") {
        $scriptsMessaging += $fileInfo
    }
    elseif ($filePath -match "scripts/repair/") {
        $scriptsRepair += $fileInfo
    }
    elseif ($filePath -match "\.md$") {
        $documentation += $fileInfo
    }
    elseif ($filePath -match "backup|\.tmp|\.bak|\.old|diagnostic.*\.md") {
        $tempBackup += $fileInfo
    }
    else {
        $other += $fileInfo
    }
}

# Affichage par categorie
Write-Host "`n--- RECAPITULATIF PAR CATEGORIE ---" -ForegroundColor Yellow

if ($scriptsGit.Count -gt 0) {
    Write-Host "`nScripts-Git : $($scriptsGit.Count) fichiers" -ForegroundColor Green
    $scriptsGit | ForEach-Object { Write-Host "  $($_.Status) $($_.Path)" }
}

if ($scriptsMessaging.Count -gt 0) {
    Write-Host "`nScripts-Messaging : $($scriptsMessaging.Count) fichiers" -ForegroundColor Green
    $scriptsMessaging | ForEach-Object { Write-Host "  $($_.Status) $($_.Path)" }
}

if ($scriptsRepair.Count -gt 0) {
    Write-Host "`nScripts-Repair : $($scriptsRepair.Count) fichiers" -ForegroundColor Green
    $scriptsRepair | ForEach-Object { Write-Host "  $($_.Status) $($_.Path)" }
}

if ($documentation.Count -gt 0) {
    Write-Host "`nDocumentation : $($documentation.Count) fichiers" -ForegroundColor Green
    $documentation | ForEach-Object { Write-Host "  $($_.Status) $($_.Path)" }
}

if ($tempBackup.Count -gt 0) {
    Write-Host "`nTemp/Backup : $($tempBackup.Count) fichiers" -ForegroundColor Green
    $tempBackup | ForEach-Object { Write-Host "  $($_.Status) $($_.Path)" }
}

if ($submodules.Count -gt 0) {
    Write-Host "`nSubmodules : $($submodules.Count) fichiers" -ForegroundColor Green
    $submodules | ForEach-Object { Write-Host "  $($_.Status) $($_.Path)" }
}

if ($other.Count -gt 0) {
    Write-Host "`nOther : $($other.Count) fichiers" -ForegroundColor Green
    $other | ForEach-Object { Write-Host "  $($_.Status) $($_.Path)" }
}

# Plan de commits
Write-Host "`n--- PLAN DE COMMITS ---" -ForegroundColor Yellow

if ($scriptsGit.Count -gt 0) {
    Write-Host "1. Scripts-Git : $($scriptsGit.Count) fichiers" -ForegroundColor Cyan
    Write-Host "   Message: chore(git): Scripts de synchronisation et diagnostic Git"
}

if ($scriptsMessaging.Count -gt 0) {
    Write-Host "2. Scripts-Messaging : $($scriptsMessaging.Count) fichiers" -ForegroundColor Cyan
    Write-Host "   Message: feat(messaging): Scripts d'analyse messagerie roo-state-manager"
}

if ($scriptsRepair.Count -gt 0) {
    Write-Host "3. Scripts-Repair : $($scriptsRepair.Count) fichiers" -ForegroundColor Cyan
    Write-Host "   Message: fix(repair): Scripts de reparation mcp_settings.json"
}

if ($documentation.Count -gt 0) {
    Write-Host "4. Documentation : $($documentation.Count) fichiers" -ForegroundColor Cyan
    Write-Host "   Message: docs: Rapports et documentation"
}

if ($tempBackup.Count -gt 0) {
    Write-Host "5. Temp/Backup : $($tempBackup.Count) fichiers" -ForegroundColor Cyan
    Write-Host "   Message: chore: Nettoyage fichiers temporaires"
}

if ($submodules.Count -gt 0) {
    Write-Host "6. Submodules : $($submodules.Count) fichiers" -ForegroundColor Cyan
    Write-Host "   Message: chore(submodule): Nettoyage sous-module mcps/internal"
}

if ($other.Count -gt 0) {
    Write-Host "7. Other : $($other.Count) fichiers" -ForegroundColor Cyan
    Write-Host "   Message: chore: Fichiers divers"
}

Write-Host "`n=== ORGANISATION TERMINEE ===" -ForegroundColor Green
Write-Host "Total fichiers a traiter : $($allFiles.Count)" -ForegroundColor Cyan