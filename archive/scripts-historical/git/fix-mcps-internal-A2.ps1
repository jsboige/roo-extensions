# Gestion du sous-module mcps/internal - Action A.2
# Date: 2025-10-13
# But: Vérifier et commiter les modifications dans mcps/internal

[CmdletBinding()]
param(
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

Write-Host "=== GESTION SOUS-MODULE mcps/internal ===" -ForegroundColor Cyan
Write-Host ""

$submodulePath = "mcps/internal"

if (-not (Test-Path $submodulePath)) {
    Write-Host "[ERREUR] Chemin $submodulePath introuvable" -ForegroundColor Red
    exit 1
}

Push-Location $submodulePath
try {
    Write-Host "Analyse de l'état..." -ForegroundColor Yellow
    
    # Statut
    Write-Host "`n1. STATUT:" -ForegroundColor Cyan
    git status
    
    # Branche
    Write-Host "`n2. BRANCHES:" -ForegroundColor Cyan
    $currentBranch = git branch --show-current
    if (-not $currentBranch) {
        Write-Host "  [DETACHED HEAD]" -ForegroundColor Red
        Write-Host "  Branches disponibles:" -ForegroundColor Yellow
        git branch -a
        
        Write-Host "`n  Action recommandée:" -ForegroundColor Yellow
        Write-Host "    git checkout local-integration-internal-mcps" -ForegroundColor Gray
        Write-Host "    (ou une autre branche appropriée)" -ForegroundColor Gray
        
        if (-not $DryRun) {
            Write-Host "`n  Tentative de checkout automatique sur local-integration-internal-mcps..." -ForegroundColor Cyan
            try {
                git checkout local-integration-internal-mcps
                Write-Host "  [OK] Branche local-integration-internal-mcps activée" -ForegroundColor Green
                $currentBranch = "local-integration-internal-mcps"
            } catch {
                Write-Host "  [ERREUR] Impossible de checkout: $_" -ForegroundColor Red
                Write-Host "`n  ARRÊT: Veuillez résoudre manuellement" -ForegroundColor Red
                exit 1
            }
        }
    } else {
        Write-Host "  Branche actuelle: $currentBranch" -ForegroundColor Green
    }
    
    if ($DryRun) {
        Write-Host "`n[MODE SIMULATION] Arrêt ici" -ForegroundColor Yellow
        exit 0
    }
    
    # Fichiers modifiés
    Write-Host "`n3. FICHIERS MODIFIES:" -ForegroundColor Cyan
    $modified = git diff --name-only
    if ($modified) {
        $modified | ForEach-Object { Write-Host "  M $_" -ForegroundColor Yellow }
    } else {
        Write-Host "  [AUCUN]" -ForegroundColor Green
        Write-Host "`n  Sous-module propre, rien à faire." -ForegroundColor Green
        exit 0
    }
    
    # Pull
    Write-Host "`n4. PULL DES DERNIERES MODIFICATIONS:" -ForegroundColor Cyan
    try {
        git pull origin $currentBranch --ff-only
        Write-Host "  [OK] Pull fast-forward réussi" -ForegroundColor Green
    } catch {
        Write-Host "  [ATTENTION] Pull --ff-only impossible" -ForegroundColor Red
        Write-Host "  Tentative avec merge..." -ForegroundColor Yellow
        try {
            git pull origin $currentBranch
            Write-Host "  [OK] Pull avec merge réussi" -ForegroundColor Green
        } catch {
            Write-Host "  [ERREUR] Pull impossible: $_" -ForegroundColor Red
            Write-Host "`n  ARRÊT: Résolution manuelle nécessaire" -ForegroundColor Red
            exit 1
        }
    }
    
    # Add
    Write-Host "`n5. STAGING DES MODIFICATIONS:" -ForegroundColor Cyan
    $toAdd = git diff --name-only
    if ($toAdd) {
        $toAdd | ForEach-Object {
            Write-Host "  Add: $_" -ForegroundColor Gray
            git add $_
        }
        Write-Host "  [OK] Tous les fichiers stagés" -ForegroundColor Green
    }
    
    # Commit
    Write-Host "`n6. COMMIT:" -ForegroundColor Cyan
    $staged = git diff --cached --name-only
    if ($staged) {
        $commitMsg = "fix(docs): correction chemins relatifs - Action A.2

Corrections des chemins relatifs suite à la réorganisation:
- ../docs/ -> ../../docs/ pour les serveurs internes

Fichiers corrigés: $($staged.Count)
Synchronisé avec dépôt principal"

        Write-Host "  Message de commit préparé" -ForegroundColor Gray
        git commit -m $commitMsg
        Write-Host "  [OK] Commit créé" -ForegroundColor Green
    } else {
        Write-Host "  [INFO] Aucun fichier à commiter" -ForegroundColor Gray
    }
    
    # Push
    Write-Host "`n7. PUSH VERS ORIGIN:" -ForegroundColor Cyan
    git push origin $currentBranch
    Write-Host "  [OK] Push réussi" -ForegroundColor Green
    
    Write-Host "`n=== SOUS-MODULE mcps/internal SYNCHRONISE ===" -ForegroundColor Green
    
} catch {
    Write-Host "`n=== ERREUR ===" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
} finally {
    Pop-Location
}