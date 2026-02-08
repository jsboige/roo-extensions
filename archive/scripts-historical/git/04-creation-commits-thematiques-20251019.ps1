# Script de création des commits thématiques - Mission Nettoyage Git
# Date: 2025-10-19
# Objectif: Créer des commits thématiques organisés

Write-Host "=== CRÉATION DES COMMITS THÉMATIQUES ===" -ForegroundColor Cyan
Write-Host "Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray

# Vérifier l'état actuel
Write-Host "`n--- État actuel avant commits ---" -ForegroundColor Yellow
$gitStatus = git status --porcelain
$gitStatusBranch = git status --branch

Write-Host "Fichiers à traiter : $($gitStatus.Count)" -ForegroundColor Cyan
$gitStatus | ForEach-Object { Write-Host "  $_" }

Write-Host "`nStatus branch:"
$gitStatusBranch | ForEach-Object { Write-Host "  $_" }

# Fonction pour créer un commit thématique
function New-ThematicCommit {
    param(
        [string]$Category,
        [array]$Files,
        [string]$Description
    )
    
    if ($Files.Count -eq 0) { 
        Write-Host "⚠️ Aucun fichier pour la catégorie $Category" -ForegroundColor Yellow
        return 
    }
    
    Write-Host "`n--- Commit : $Category ---" -ForegroundColor Yellow
    Write-Host "Description : $Description"
    Write-Host "Fichiers : $($Files.Count)"
    
    # Ajouter les fichiers au staging
    foreach ($file in $Files) {
        $filePath = $file.Path
        Write-Host "  + $filePath"
        git add $filePath
    }
    
    # Créer le commit
    $commitMessage = "$Description"
    git commit -m $commitMessage
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Commit créé : $commitMessage" -ForegroundColor Green
    } else {
        Write-Host "❌ Erreur lors de la création du commit" -ForegroundColor Red
    }
}

# Préparer les fichiers par catégorie
$scriptsGit = @()
$scriptsMessaging = @()
$scriptsRepair = @()
$other = @()

foreach ($file in $gitStatus) {
    $status = $file.Substring(0, 2).Trim()
    $filePath = $file.Substring(3)
    
    $fileInfo = @{
        Status = $status
        Path = $filePath
    }
    
    if ($filePath -match "scripts/git/") {
        $scriptsGit += $fileInfo
    }
    elseif ($filePath -match "scripts/messaging/") {
        $scriptsMessaging += $fileInfo
    }
    elseif ($filePath -match "scripts/repair/") {
        $scriptsRepair += $fileInfo
    }
    else {
        $other += $fileInfo
    }
}

# Créer les commits thématiques
Write-Host "`n=== DÉBUT DES COMMITS THÉMATIQUES ===" -ForegroundColor Green

# 1. Scripts Git
New-ThematicCommit -Category "Scripts-Git" -Files $scriptsGit -Description "chore(git): Scripts de synchronisation et diagnostic Git"

# 2. Scripts Messaging  
New-ThematicCommit -Category "Scripts-Messaging" -Files $scriptsMessaging -Description "feat(messaging): Scripts d'analyse messagerie roo-state-manager"

# 3. Scripts Repair
New-ThematicCommit -Category "Scripts-Repair" -Files $scriptsRepair -Description "fix(repair): Scripts de reparation mcp_settings.json"

# 4. Other files
if ($other.Count -gt 0) {
    New-ThematicCommit -Category "Other" -Files $other -Description "chore: Fichiers divers et organisation"
}

# Vérifier l'état après les commits
Write-Host "`n--- État après les commits ---" -ForegroundColor Yellow
$finalStatus = git status --porcelain
$finalCount = ($finalStatus | Measure-Object).Count

Write-Host "Fichiers restants non commités : $finalCount" -ForegroundColor Cyan
if ($finalStatus) {
    Write-Host "Détail :"
    $finalStatus | ForEach-Object { Write-Host "  $_" }
} else {
    Write-Host "✅ Tous les fichiers ont été commités" -ForegroundColor Green
}

# Afficher les commits créés
Write-Host "`n--- Commits récents ---" -ForegroundColor Yellow
git log --oneline -10 | ForEach-Object { Write-Host "  $_" }

# Statistiques des commits
$commitCount = (git log --oneline origin/main..HEAD | Measure-Object).Count
Write-Host "`n--- Statistiques ---" -ForegroundColor Yellow
Write-Host "Commits créés dans cette session : $commitCount" -ForegroundColor Cyan
Write-Host "Commits à pousser vers origin/main : $commitCount" -ForegroundColor Cyan

Write-Host "`n=== CRÉATION DES COMMITS TERMINÉE ===" -ForegroundColor Green