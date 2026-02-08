# ============================================================================
# PHASE 2.7 - EXECUTION DROPS SCRIPTS SYNC (NON-INTERACTIF)
# ============================================================================
# Date: 2025-10-22
# Mission: Dropper automatiquement les 5 stashs scripts sync
# Prérequis: Working tree clean, Phase 2.6 complétée
# ============================================================================

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host "`n==============================================================================" -ForegroundColor Cyan
Write-Host "  PHASE 2.7 - EXECUTION DROPS SCRIPTS SYNC (AUTOMATIQUE)" -ForegroundColor Cyan
Write-Host "==============================================================================" -ForegroundColor Cyan
Write-Host ""

# Variables
$DropsLog = @()
$StashsToDropOriginal = @(9, 8, 7, 5, 1)  # Ordre inverse
$ErrorOccurred = $false

# ============================================================================
# ÉTAPE 1: VÉRIFICATIONS PRÉLIMINAIRES
# ============================================================================

Write-Host "ÉTAPE 1: Vérifications préliminaires" -ForegroundColor Yellow
Write-Host "-------------------------------------" -ForegroundColor Yellow
Write-Host ""

# Vérifier working tree
$GitStatus = git status --porcelain
if ($GitStatus) {
    Write-Host "❌ ERREUR: Working tree NOT CLEAN" -ForegroundColor Red
    Write-Host ""
    Write-Host "Fichiers modifiés:" -ForegroundColor Yellow
    $GitStatus | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
    Write-Host ""
    Write-Host "ABANDON: Le working tree doit être clean avant les drops" -ForegroundColor Red
    exit 1
}
Write-Host "✅ Working tree CLEAN" -ForegroundColor Green
Write-Host ""

# Compter les stashs
$InitialStashCount = (git stash list).Count
Write-Host "Stashs actuels: $InitialStashCount" -ForegroundColor Cyan
Write-Host ""

# ============================================================================
# ÉTAPE 2: VÉRIFICATION CONTENU DES STASHS
# ============================================================================

Write-Host "ÉTAPE 2: Vérification contenu des stashs cibles" -ForegroundColor Yellow
Write-Host "------------------------------------------------" -ForegroundColor Yellow
Write-Host ""

$AllContainSyncScript = $true
foreach ($Index in $StashsToDropOriginal) {
    Write-Host "Vérification stash@{$Index}:" -ForegroundColor White
    $Files = git stash show "stash@{$Index}" --name-only 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  ❌ ERREUR: Impossible de lire le stash" -ForegroundColor Red
        $AllContainSyncScript = $false
    } else {
        $ContainsSyncScript = $Files | Where-Object { $_ -like "*sync_roo_environment.ps1*" }
        if ($ContainsSyncScript) {
            Write-Host "  ✅ Contient sync_roo_environment.ps1" -ForegroundColor Green
        } else {
            Write-Host "  ⚠️  NE CONTIENT PAS sync_roo_environment.ps1" -ForegroundColor Red
            $AllContainSyncScript = $false
        }
    }
}
Write-Host ""

if (-not $AllContainSyncScript) {
    Write-Host "❌ ERREUR: Certains stashs ne contiennent pas sync_roo_environment.ps1" -ForegroundColor Red
    Write-Host "ABANDON: Vérifier le mapping des stashs avant de continuer" -ForegroundColor Red
    exit 1
}

Write-Host "✅ Tous les stashs cibles contiennent sync_roo_environment.ps1" -ForegroundColor Green
Write-Host ""

# ============================================================================
# ÉTAPE 3: DROPS SÉQUENTIELS (ORDRE INVERSE)
# ============================================================================

Write-Host "ÉTAPE 3: Drops séquentiels (ordre INVERSE)" -ForegroundColor Yellow
Write-Host "-------------------------------------------" -ForegroundColor Yellow
Write-Host ""

$CurrentIndex = $StashsToDropOriginal.Clone()
$DropNumber = 1

foreach ($OriginalIndex in $StashsToDropOriginal) {
    # Calculer l'index actuel (après les drops précédents)
    $ActualIndex = $OriginalIndex - ($DropNumber - 1)
    
    Write-Host ""
    Write-Host "=== DROP $DropNumber/5 : stash@{$OriginalIndex} (actuel: @{$ActualIndex}) ===" -ForegroundColor Cyan
    Write-Host ""
    
    # Afficher contenu
    Write-Host "Contenu:" -ForegroundColor White
    $Stats = git stash show "stash@{$ActualIndex}" --stat 2>&1
    if ($LASTEXITCODE -eq 0) {
        $Stats | Select-Object -First 5 | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
    }
    Write-Host ""
    
    # Exécuter le drop
    Write-Host "Exécution du drop..." -ForegroundColor White
    git stash drop "stash@{$ActualIndex}" 2>&1 | Out-Null
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ stash@{$OriginalIndex} droppé avec succès" -ForegroundColor Green
        
        # Log
        $DropsLog += [PSCustomObject]@{
            DropNumber = $DropNumber
            OriginalIndex = $OriginalIndex
            ActualIndex = $ActualIndex
            Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            Success = $true
        }
        
        # Compter restants
        $RemainingCount = (git stash list).Count
        Write-Host "Stashs restants: $RemainingCount" -ForegroundColor Cyan
    } else {
        Write-Host "❌ ERREUR lors du drop" -ForegroundColor Red
        $ErrorOccurred = $true
        
        $DropsLog += [PSCustomObject]@{
            DropNumber = $DropNumber
            OriginalIndex = $OriginalIndex
            ActualIndex = $ActualIndex
            Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            Success = $false
        }
        
        break
    }
    
    $DropNumber++
}

# ============================================================================
# ÉTAPE 4: VÉRIFICATION POST-DROPS
# ============================================================================

Write-Host ""
Write-Host "==============================================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "ÉTAPE 4: Vérification post-drops" -ForegroundColor Yellow
Write-Host "---------------------------------" -ForegroundColor Yellow
Write-Host ""

$FinalStashCount = (git stash list).Count
Write-Host "Statistiques:" -ForegroundColor White
Write-Host "  - Stashs initiaux: $InitialStashCount" -ForegroundColor Cyan
Write-Host "  - Stashs droppés: $($DropsLog.Count)" -ForegroundColor Cyan
Write-Host "  - Stashs restants: $FinalStashCount" -ForegroundColor Cyan
Write-Host "  - Attendu: 6 stashs restants (11 - 5 drops)" -ForegroundColor Cyan
Write-Host ""

# Vérifier le résultat
if ($ErrorOccurred) {
    Write-Host "⚠️  ATTENTION: Des erreurs se sont produites" -ForegroundColor Red
} elseif ($FinalStashCount -eq 6) {
    Write-Host "✅ SUCCÈS: Nombre de stashs correct (6)" -ForegroundColor Green
} else {
    Write-Host "⚠️  ATTENTION: Nombre de stashs inattendu (attendu: 6, réel: $FinalStashCount)" -ForegroundColor Yellow
}
Write-Host ""

# Liste finale
Write-Host "Stashs restants:" -ForegroundColor White
Write-Host ""
git stash list | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
Write-Host ""

# ============================================================================
# RÉSUMÉ FINAL
# ============================================================================

Write-Host "==============================================================================" -ForegroundColor Cyan
Write-Host "  RÉSUMÉ FINAL - PHASE 2.7" -ForegroundColor Cyan
Write-Host "==============================================================================" -ForegroundColor Cyan
Write-Host ""

if (-not $ErrorOccurred) {
    Write-Host "✅ PHASE 2.7 TERMINÉE AVEC SUCCÈS" -ForegroundColor Green
} else {
    Write-Host "⚠️  PHASE 2.7 TERMINÉE AVEC ERREURS" -ForegroundColor Yellow
}
Write-Host ""

Write-Host "Log des drops:" -ForegroundColor White
$DropsLog | Format-Table -AutoSize

Write-Host ""
Write-Host "Prochaines étapes:" -ForegroundColor Yellow
Write-Host "  1. ✅ Générer rapport d'exécution détaillé" -ForegroundColor White
Write-Host "  2. ✅ Mettre à jour documentation globale" -ForegroundColor White
Write-Host "  3. ⏭️  Pull conservateur avec merges manuels" -ForegroundColor White
Write-Host "  4. ⏭️  Push des modifications" -ForegroundColor White
Write-Host "  5. ⏭️  Merge branche vers main" -ForegroundColor White
Write-Host ""

Write-Host "==============================================================================" -ForegroundColor Cyan
Write-Host ""

# Sauvegarder le log pour le rapport
$DropsLog | ConvertTo-Json | Out-File "docs/git/phase2-drops-execution-log.json" -Encoding UTF8
Write-Host "📝 Log sauvegardé: docs/git/phase2-drops-execution-log.json" -ForegroundColor Cyan
Write-Host ""