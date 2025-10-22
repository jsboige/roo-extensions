# ============================================================================
# PHASE 2.7 - EXECUTION DROPS SCRIPTS SYNC
# ============================================================================
# Date: 2025-10-22
# Mission: Dropper de manière sécurisée les 5 stashs scripts sync
# Prérequis: Phase 2.6 complétée, améliorations récupérées
# ============================================================================

# Configuration UTF-8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host "`n==============================================================================" -ForegroundColor Cyan
Write-Host "  PHASE 2.7 - EXECUTION DROPS SCRIPTS SYNC" -ForegroundColor Cyan
Write-Host "==============================================================================" -ForegroundColor Cyan
Write-Host ""

# ============================================================================
# ÉTAPE 1: VÉRIFICATION ÉTAT ACTUEL
# ============================================================================

Write-Host "ÉTAPE 1: Vérification état actuel" -ForegroundColor Yellow
Write-Host "-----------------------------------" -ForegroundColor Yellow
Write-Host ""

# Vérifier working tree
Write-Host "Vérification working tree..." -ForegroundColor White
$GitStatus = git status --porcelain
if ($GitStatus) {
    Write-Host ""
    Write-Host "⚠️  ATTENTION: Working tree NOT CLEAN" -ForegroundColor Red
    Write-Host ""
    Write-Host "Fichiers modifiés/non suivis détectés:" -ForegroundColor Yellow
    $GitStatus | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
    Write-Host ""
    Write-Host "RECOMMANDATION:" -ForegroundColor Yellow
    Write-Host "  1. Stasher les changements: git stash push -u -m 'WIP avant drops Phase 2.7'" -ForegroundColor White
    Write-Host "  2. Ou committer les changements si approprié" -ForegroundColor White
    Write-Host ""
    $Response = Read-Host "Voulez-vous continuer malgré tout? (o/N)"
    if ($Response -ne 'o') {
        Write-Host ""
        Write-Host "❌ Opération annulée par l'utilisateur" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "✅ Working tree CLEAN" -ForegroundColor Green
}

Write-Host ""

# Lister les stashs actuels
Write-Host "Liste des stashs actuels:" -ForegroundColor White
Write-Host ""
$StashList = git stash list
$StashList | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
Write-Host ""
Write-Host "Total: $($StashList.Count) stashs" -ForegroundColor Cyan
Write-Host ""

# ============================================================================
# ÉTAPE 2: VÉRIFICATION CONTENU DES STASHS CIBLES
# ============================================================================

Write-Host "ÉTAPE 2: Vérification contenu des stashs cibles" -ForegroundColor Yellow
Write-Host "------------------------------------------------" -ForegroundColor Yellow
Write-Host ""

$StashsToCheck = @(1, 5, 7, 8, 9)

foreach ($Index in $StashsToCheck) {
    Write-Host "stash@{$Index}:" -ForegroundColor Cyan
    $Files = git stash show "stash@{$Index}" --name-only 2>&1
    if ($LASTEXITCODE -eq 0) {
        $Files | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
    } else {
        Write-Host "  ⚠️  Erreur lors de la lecture du stash" -ForegroundColor Red
    }
    Write-Host ""
}

Write-Host ""
$Confirm = Read-Host "Les stashs ci-dessus contiennent-ils bien sync_roo_environment.ps1 ? (o/N)"
if ($Confirm -ne 'o') {
    Write-Host ""
    Write-Host "❌ Mapping non confirmé - Opération annulée" -ForegroundColor Red
    exit 1
}

Write-Host ""

# ============================================================================
# ÉTAPE 3: DROPS SÉQUENTIELS (ORDRE INVERSE)
# ============================================================================

Write-Host "ÉTAPE 3: Drops séquentiels (ordre INVERSE)" -ForegroundColor Yellow
Write-Host "-------------------------------------------" -ForegroundColor Yellow
Write-Host ""

$DropsLog = @()

# Fonction pour dropper un stash
function Drop-Stash {
    param(
        [int]$OriginalIndex,
        [int]$CurrentIndex,
        [int]$DropNumber,
        [int]$TotalDrops
    )
    
    Write-Host ""
    Write-Host "=== DROP $DropNumber/$TotalDrops : stash@{$OriginalIndex} (actuel: @{$CurrentIndex}) ===" -ForegroundColor Cyan
    Write-Host ""
    
    # Afficher contenu
    Write-Host "Contenu du stash:" -ForegroundColor White
    git stash show "stash@{$CurrentIndex}" --stat 2>&1 | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
    Write-Host ""
    
    # Confirmation utilisateur
    Write-Host "⚠️  CONFIRMER DROP de stash@{$CurrentIndex} (ancien @{$OriginalIndex})" -ForegroundColor Yellow
    $Confirm = Read-Host "Appuyer sur Entrée pour confirmer, ou 'n' pour annuler"
    
    if ($Confirm -eq 'n') {
        Write-Host ""
        Write-Host "❌ Drop annulé par l'utilisateur" -ForegroundColor Red
        return $false
    }
    
    # Exécuter le drop
    Write-Host ""
    Write-Host "Exécution du drop..." -ForegroundColor White
    git stash drop "stash@{$CurrentIndex}" 2>&1 | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Host "✅ stash@{$OriginalIndex} droppé avec succès" -ForegroundColor Green
        
        # Log
        $DropsLog += @{
            OriginalIndex = $OriginalIndex
            CurrentIndex = $CurrentIndex
            DropNumber = $DropNumber
            Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            Success = $true
        }
        
        # Afficher nouveau compte
        $NewCount = (git stash list).Count
        Write-Host "Stashs restants: $NewCount" -ForegroundColor Cyan
        
        return $true
    } else {
        Write-Host ""
        Write-Host "❌ ERREUR lors du drop" -ForegroundColor Red
        return $false
    }
}

# ============================================================================
# DROPS DANS L'ORDRE INVERSE
# ============================================================================

$Success = $true

# Drop 1: stash@{9}
$Success = $Success -and (Drop-Stash -OriginalIndex 9 -CurrentIndex 9 -DropNumber 1 -TotalDrops 5)
if (-not $Success) { exit 1 }

# Drop 2: stash@{8} (devient @{7})
$Success = $Success -and (Drop-Stash -OriginalIndex 8 -CurrentIndex 7 -DropNumber 2 -TotalDrops 5)
if (-not $Success) { exit 1 }

# Drop 3: stash@{7} (devient @{6})
$Success = $Success -and (Drop-Stash -OriginalIndex 7 -CurrentIndex 6 -DropNumber 3 -TotalDrops 5)
if (-not $Success) { exit 1 }

# Drop 4: stash@{5} (devient @{4})
$Success = $Success -and (Drop-Stash -OriginalIndex 5 -CurrentIndex 4 -DropNumber 4 -TotalDrops 5)
if (-not $Success) { exit 1 }

# Drop 5: stash@{1} (devient @{0})
$Success = $Success -and (Drop-Stash -OriginalIndex 1 -CurrentIndex 0 -DropNumber 5 -TotalDrops 5)
if (-not $Success) { exit 1 }

# ============================================================================
# ÉTAPE 4: VÉRIFICATION POST-DROPS
# ============================================================================

Write-Host ""
Write-Host "==============================================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "ÉTAPE 4: Vérification post-drops" -ForegroundColor Yellow
Write-Host "---------------------------------" -ForegroundColor Yellow
Write-Host ""

# Compter les stashs restants
$FinalStashCount = (git stash list).Count
Write-Host "Stashs restants: $FinalStashCount" -ForegroundColor Cyan
Write-Host ""

# Afficher les stashs restants
Write-Host "Liste finale des stashs:" -ForegroundColor White
Write-Host ""
git stash list | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
Write-Host ""

# Vérifier intégrité
Write-Host "Vérification intégrité repository:" -ForegroundColor White
$StatusFinal = git status --short
if ($StatusFinal) {
    Write-Host "  ⚠️  Changements détectés" -ForegroundColor Yellow
} else {
    Write-Host "  ✅ Working tree clean" -ForegroundColor Green
}
Write-Host ""

# ============================================================================
# RÉSUMÉ FINAL
# ============================================================================

Write-Host "==============================================================================" -ForegroundColor Cyan
Write-Host "  RÉSUMÉ FINAL - PHASE 2.7" -ForegroundColor Cyan
Write-Host "==============================================================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "✅ PHASE 2.7 TERMINÉE AVEC SUCCÈS" -ForegroundColor Green
Write-Host ""
Write-Host "Statistiques:" -ForegroundColor White
Write-Host "  - Stashs droppés: 5" -ForegroundColor Cyan
Write-Host "  - Stashs restants: $FinalStashCount" -ForegroundColor Cyan
Write-Host "  - Backups disponibles: Oui (docs/git/stash-backups/)" -ForegroundColor Cyan
Write-Host ""

Write-Host "Prochaines étapes:" -ForegroundColor Yellow
Write-Host "  1. Générer rapport d'exécution" -ForegroundColor White
Write-Host "  2. Mettre à jour documentation globale" -ForegroundColor White
Write-Host "  3. Merge branche feature/recover-stash-logging-improvements vers main" -ForegroundColor White
Write-Host "  4. Phase 3: Analyse des stashs critiques restants" -ForegroundColor White
Write-Host ""

Write-Host "==============================================================================" -ForegroundColor Cyan
Write-Host ""

# Retourner les logs pour génération du rapport
return $DropsLog