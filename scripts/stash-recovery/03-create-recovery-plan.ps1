#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Crée le plan de récupération des stashs avec analyse des doublons
    
.DESCRIPTION
    Analyse chaque stash pour déterminer :
    - Si le code existe déjà dans l'historique (doublon)
    - Si récupérable sans conflit
    - Si nécessite résolution manuelle
    
.NOTES
    Date: 2025-10-16
    Mission: Récupération de Stashs Git Perdus
    Tâche: 03 - Créer Plan de Récupération
#>

param(
    [string]$OutputDir = "mcps/internal/servers/roo-state-manager",
    [string]$Timestamp = (Get-Date -Format "yyyyMMdd-HHmmss")
)

function Test-StashInHistory {
    param(
        [string]$RepoPath,
        [string]$StashRef
    )
    
    Push-Location $RepoPath
    
    try {
        # Obtenir le hash du stash
        $stashHash = git rev-parse $StashRef 2>&1
        
        # Chercher ce hash dans l'historique
        $inHistory = git log --all --oneline | Select-String -Pattern $stashHash -Quiet
        
        if ($inHistory) {
            return @{
                Status = "AlreadyCommitted"
                Message = "Ce stash a déjà été commité dans l'historique"
            }
        }
        
        # Vérifier si le contenu existe (même si le hash diffère)
        $stashDiff = git stash show -p $StashRef 2>&1 | Out-String
        
        # Extraire les noms de fichiers modifiés
        $filesChanged = git stash show $StashRef --name-only 2>&1
        
        $allFilesUnchanged = $true
        foreach ($file in $filesChanged) {
            if ([string]::IsNullOrWhiteSpace($file)) { continue }
            
            # Vérifier si le fichier existe et comparer
            if (Test-Path $file) {
                # Comparer le contenu du fichier dans le stash avec HEAD
                $currentContent = Get-Content $file -Raw -ErrorAction SilentlyContinue
                
                # Appliquer temporairement le stash sur un nouveau index
                $stashContent = git show "$StashRef`:$file" 2>&1 | Out-String
                
                if ($currentContent -ne $stashContent) {
                    $allFilesUnchanged = $false
                    break
                }
            } else {
                $allFilesUnchanged = $false
                break
            }
        }
        
        if ($allFilesUnchanged -and $filesChanged.Count -gt 0) {
            return @{
                Status = "ContentAlreadyPresent"
                Message = "Le contenu du stash existe déjà dans la branche actuelle"
            }
        }
        
        return @{
            Status = "NotInHistory"
            Message = "Nouveau code non présent dans l'historique"
        }
        
    } finally {
        Pop-Location
    }
}

function Test-StashConflicts {
    param(
        [string]$RepoPath,
        [string]$StashRef
    )
    
    Push-Location $RepoPath
    
    try {
        # Tester l'application du stash avec --index pour détecter les conflits
        $testOutput = git stash show $StashRef --name-only 2>&1
        
        $hasConflicts = $false
        $conflictFiles = @()
        
        foreach ($file in $testOutput) {
            if ([string]::IsNullOrWhiteSpace($file)) { continue }
            
            # Vérifier si le fichier a été modifié depuis le stash
            if (Test-Path $file) {
                $gitStatus = git status --porcelain $file 2>&1
                if ($gitStatus) {
                    $hasConflicts = $true
                    $conflictFiles += $file
                }
            }
        }
        
        if ($hasConflicts) {
            return @{
                HasConflicts = $true
                ConflictFiles = $conflictFiles
                Message = "Conflits potentiels détectés avec les fichiers modifiés"
            }
        }
        
        return @{
            HasConflicts = $false
            ConflictFiles = @()
            Message = "Aucun conflit détecté, application devrait être propre"
        }
        
    } finally {
        Pop-Location
    }
}

function Get-StashRecommendation {
    param(
        [hashtable]$HistoryCheck,
        [hashtable]$ConflictCheck,
        [hashtable]$StashInfo
    )
    
    # Logique de décision
    if ($HistoryCheck.Status -eq "AlreadyCommitted") {
        return @{
            Category = "🗑️ OBSOLETE"
            Action = "git stash drop"
            Priority = "Basse"
            Risk = "Aucun"
            Reason = "Déjà présent dans l'historique des commits"
        }
    }
    
    if ($HistoryCheck.Status -eq "ContentAlreadyPresent") {
        return @{
            Category = "⚠️ DOUBLON PARTIEL"
            Action = "Vérification manuelle puis git stash drop"
            Priority = "Moyenne"
            Risk = "Faible"
            Reason = "Contenu similaire présent mais hash différent"
        }
    }
    
    if ($ConflictCheck.HasConflicts) {
        return @{
            Category = "🔧 RÉSOLUTION MANUELLE"
            Action = "git stash apply + résolution des conflits"
            Priority = "Haute"
            Risk = "Moyen"
            Reason = "Conflits avec les fichiers actuels - nécessite review"
            ConflictFiles = $ConflictCheck.ConflictFiles
        }
    }
    
    # Stash récent (< 7 jours) et sans conflit
    $stashDate = [DateTime]::Parse($StashInfo.Date)
    $daysSince = (Get-Date) - $stashDate
    
    if ($daysSince.TotalDays -lt 7) {
        return @{
            Category = "✅ RÉCUPÉRABLE PRIORITAIRE"
            Action = "git stash pop"
            Priority = "Très Haute"
            Risk = "Faible"
            Reason = "Stash récent, aucun conflit, nouveau code"
        }
    }
    
    if ($daysSince.TotalDays -lt 30) {
        return @{
            Category = "✅ RÉCUPÉRABLE"
            Action = "git stash apply (puis drop après validation)"
            Priority = "Haute"
            Risk = "Faible"
            Reason = "Stash relativement récent, nouveau code sans conflit"
        }
    }
    
    return @{
        Category = "⚠️ RÉCUPÉRABLE ANCIEN"
        Action = "git stash apply + review approfondie"
        Priority = "Moyenne"
        Risk = "Moyen"
        Reason = "Stash ancien (>30 jours) - vérifier pertinence actuelle"
    }
}

# Charger l'analyse détaillée
$analysisFile = Get-ChildItem "$PSScriptRoot/output/stash-detailed-analysis-*.md" | 
    Sort-Object LastWriteTime -Descending | 
    Select-Object -First 1

if (-not $analysisFile) {
    Write-Host "❌ Fichier d'analyse détaillée introuvable!" -ForegroundColor Red
    Write-Host "Exécutez d'abord 02-detailed-stash-analysis.ps1" -ForegroundColor Yellow
    exit 1
}

Write-Host "📄 Chargement de l'analyse: $($analysisFile.Name)" -ForegroundColor Cyan

# Parser les stashs depuis le rapport (simplification - utilise git directement)
$repos = @(
    @{ Name = "mcps-internal"; Path = "mcps/internal" },
    @{ Name = "roo-extensions"; Path = "." }
)

$plan = @"
# 📋 PLAN DE RÉCUPÉRATION DES STASHS GIT
**Date de création**: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
**Mission**: Récupération de Stashs Git Perdus

---

## 📊 RÉSUMÉ EXÉCUTIF

"@

$allStashes = @()
$categoryCounts = @{
    "✅ RÉCUPÉRABLE PRIORITAIRE" = 0
    "✅ RÉCUPÉRABLE" = 0
    "⚠️ RÉCUPÉRABLE ANCIEN" = 0
    "🔧 RÉSOLUTION MANUELLE" = 0
    "⚠️ DOUBLON PARTIEL" = 0
    "🗑️ OBSOLETE" = 0
}

Write-Host "`n=== ANALYSE DES STASHS ===" -ForegroundColor Magenta

foreach ($repo in $repos) {
    Write-Host "`n📦 Dépôt: $($repo.Name)" -ForegroundColor Cyan
    
    Push-Location $repo.Path
    
    try {
        $stashList = git stash list --date=iso 2>&1
        if ($LASTEXITCODE -ne 0 -or $stashList.Count -eq 0) {
            Write-Host "  Aucun stash trouvé" -ForegroundColor Gray
            continue
        }
        
        for ($i = 0; $i -lt $stashList.Count; $i++) {
            $stashRef = "stash@{$i}"
            Write-Host "  Analyse $stashRef..." -ForegroundColor Gray
            
            $stashInfo = $stashList[$i]
            
            # Parser les infos
            $branch = if ($stashInfo -match 'On ([^:]+):') { $matches[1] } else { "unknown" }
            $date = if ($stashInfo -match '\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}') { $matches[0] } else { "unknown" }
            $description = if ($stashInfo -match ': (.+)$') { $matches[1] } else { "No description" }
            
            # Obtenir stats
            $stats = git stash show $stashRef --stat 2>&1
            $filesChanged = ($stats | Where-Object { $_ -match '\|' } | Measure-Object).Count
            
            $stashData = @{
                Repo = $repo.Name
                RepoPath = $repo.Path
                Reference = $stashRef
                Index = $i
                Branch = $branch
                Date = $date
                Description = $description
                FilesChanged = $filesChanged
            }
            
            # Analyser historique
            Write-Host "    Vérification historique..." -ForegroundColor DarkGray
            $historyCheck = Test-StashInHistory -RepoPath $repo.Path -StashRef $stashRef
            
            # Analyser conflits
            Write-Host "    Vérification conflits..." -ForegroundColor DarkGray
            $conflictCheck = Test-StashConflicts -RepoPath $repo.Path -StashRef $stashRef
            
            # Obtenir recommandation
            $recommendation = Get-StashRecommendation -HistoryCheck $historyCheck -ConflictCheck $conflictCheck -StashInfo $stashData
            
            $stashData.HistoryCheck = $historyCheck
            $stashData.ConflictCheck = $conflictCheck
            $stashData.Recommendation = $recommendation
            
            $allStashes += $stashData
            $categoryCounts[$recommendation.Category]++
            
            Write-Host "    → $($recommendation.Category)" -ForegroundColor Yellow
        }
        
    } finally {
        Pop-Location
    }
}

# Construire le résumé
$plan += @"

| Catégorie | Nombre | Action Recommandée |
|-----------|--------|-------------------|
| ✅ Récupérable Prioritaire | $($categoryCounts["✅ RÉCUPÉRABLE PRIORITAIRE"]) | Appliquer immédiatement |
| ✅ Récupérable | $($categoryCounts["✅ RÉCUPÉRABLE"]) | Appliquer avec validation |
| ⚠️ Récupérable Ancien | $($categoryCounts["⚠️ RÉCUPÉRABLE ANCIEN"]) | Review puis appliquer |
| 🔧 Résolution Manuelle | $($categoryCounts["🔧 RÉSOLUTION MANUELLE"]) | Résoudre conflits |
| ⚠️ Doublon Partiel | $($categoryCounts["⚠️ DOUBLON PARTIEL"]) | Vérifier puis supprimer |
| 🗑️ Obsolète | $($categoryCounts["🗑️ OBSOLETE"]) | Supprimer en sécurité |
| **TOTAL** | **$($allStashes.Count)** | |

---

## 📝 ANALYSE DÉTAILLÉE PAR STASH

"@

# Grouper par catégorie
$groupedByCategory = $allStashes | Group-Object { $_.Recommendation.Category }

foreach ($group in ($groupedByCategory | Sort-Object {
    switch ($_.Name) {
        "✅ RÉCUPÉRABLE PRIORITAIRE" { 1 }
        "✅ RÉCUPÉRABLE" { 2 }
        "⚠️ RÉCUPÉRABLE ANCIEN" { 3 }
        "🔧 RÉSOLUTION MANUELLE" { 4 }
        "⚠️ DOUBLON PARTIEL" { 5 }
        "🗑️ OBSOLETE" { 6 }
        default { 99 }
    }
})) {
    $plan += @"

### $($group.Name) ($($group.Count) stash(s))

"@
    
    foreach ($stash in $group.Group) {
        $plan += @"

#### 📌 [$($stash.Repo)] $($stash.Reference)

**Description**: *$($stash.Description)*

| Propriété | Valeur |
|-----------|--------|
| Branche | ``$($stash.Branch)`` |
| Date | $($stash.Date) |
| Fichiers modifiés | $($stash.FilesChanged) |
| Priorité | **$($stash.Recommendation.Priority)** |
| Risque | $($stash.Recommendation.Risk) |

**Analyse**:
- **Historique**: $($stash.HistoryCheck.Message)
- **Conflits**: $($stash.ConflictCheck.Message)
- **Raison**: $($stash.Recommendation.Reason)

**Action recommandée**:
``````bash
cd $($stash.RepoPath)
$($stash.Recommendation.Action) $($stash.Reference)
``````

"@
        
        if ($stash.ConflictCheck.HasConflicts -and $stash.ConflictCheck.ConflictFiles.Count -gt 0) {
            $plan += @"

**Fichiers en conflit**:
"@
            foreach ($file in $stash.ConflictCheck.ConflictFiles) {
                $plan += "- ``$file```n"
            }
        }
        
        $plan += "`n---`n"
    }
}

# Ajouter plan d'action
$plan += @"

## 🎯 PLAN D'ACTION RECOMMANDÉ

### Phase 1 : Récupération Prioritaire (Risque Faible)
**Stashs**: ✅ RÉCUPÉRABLE PRIORITAIRE

``````bash
# Exemple pour mcps-internal stash@{0}
cd mcps/internal
git stash pop stash@{0}
# Vérifier que tout compile
npm run build
# Commiter si OK
git add .
git commit -m "chore: recover stash - [description]"
``````

### Phase 2 : Récupération Standard (Validation Requise)
**Stashs**: ✅ RÉCUPÉRABLE

``````bash
# Appliquer sans supprimer le stash
cd <repo-path>
git stash apply stash@{N}
# Tester, valider
# Si OK:
git add .
git commit -m "chore: recover stash - [description]"
git stash drop stash@{N}
``````

### Phase 3 : Résolution Manuelle (Conflits)
**Stashs**: 🔧 RÉSOLUTION MANUELLE

``````bash
cd <repo-path>
git stash apply stash@{N}
# Résoudre les conflits
git status
git diff
# Après résolution
git add .
git commit -m "chore: recover stash with conflict resolution - [description]"
git stash drop stash@{N}
``````

### Phase 4 : Nettoyage (Doublons et Obsolètes)
**Stashs**: 🗑️ OBSOLETE, ⚠️ DOUBLON PARTIEL

``````bash
# Vérifier une dernière fois le contenu
cd <repo-path>
git stash show -p stash@{N}
# Si vraiment obsolète
git stash drop stash@{N}
``````

---

## ⚠️ PRÉCAUTIONS IMPORTANTES

1. **Backup avant opération**: Faire un backup git avant toute opération
   ``````bash
   git stash list > stash-backup-$Timestamp.txt
   ``````

2. **Tester après chaque récupération**:
   - Vérifier que le code compile
   - Lancer les tests
   - Vérifier que les fonctionnalités marchent

3. **Commiter progressivement**:
   - Ne pas mélanger plusieurs stashs dans un commit
   - Commiter après chaque stash récupéré avec succès

4. **Documentation**:
   - Noter les décisions prises
   - Documenter les résolutions de conflits

---

## 📈 SUIVI DE PROGRESSION

- [ ] Phase 1 : Récupération Prioritaire ($($categoryCounts["✅ RÉCUPÉRABLE PRIORITAIRE"]) stash(s))
- [ ] Phase 2 : Récupération Standard ($($categoryCounts["✅ RÉCUPÉRABLE"]) + $($categoryCounts["⚠️ RÉCUPÉRABLE ANCIEN"]) stash(s))
- [ ] Phase 3 : Résolution Manuelle ($($categoryCounts["🔧 RÉSOLUTION MANUELLE"]) stash(s))
- [ ] Phase 4 : Nettoyage ($($categoryCounts["🗑️ OBSOLETE"]) + $($categoryCounts["⚠️ DOUBLON PARTIEL"]) stash(s))

---

*Généré automatiquement le $(Get-Date -Format "yyyy-MM-dd HH:mm:ss") par 03-create-recovery-plan.ps1*
"@

# Sauvegarder le plan
$planFile = "$OutputDir/STASH_RECOVERY_PLAN.md"
$plan | Out-File -FilePath $planFile -Encoding utf8

Write-Host "`n========================================" -ForegroundColor Magenta
Write-Host "✅ Plan de récupération créé!" -ForegroundColor Green
Write-Host "📄 Fichier: $planFile" -ForegroundColor Cyan
Write-Host "`n📊 Statistiques:" -ForegroundColor Yellow
Write-Host "  ✅ Récupérables immédiats: $($categoryCounts["✅ RÉCUPÉRABLE PRIORITAIRE"])" -ForegroundColor Green
Write-Host "  ✅ Récupérables standard: $($categoryCounts["✅ RÉCUPÉRABLE"])" -ForegroundColor Green
Write-Host "  ⚠️ Récupérables anciens: $($categoryCounts["⚠️ RÉCUPÉRABLE ANCIEN"])" -ForegroundColor Yellow
Write-Host "  🔧 Nécessitent résolution: $($categoryCounts["🔧 RÉSOLUTION MANUELLE"])" -ForegroundColor Yellow
Write-Host "  ⚠️ Doublons partiels: $($categoryCounts["⚠️ DOUBLON PARTIEL"])" -ForegroundColor DarkYellow
Write-Host "  🗑️ Obsolètes: $($categoryCounts["🗑️ OBSOLETE"])" -ForegroundColor Red

return $planFile