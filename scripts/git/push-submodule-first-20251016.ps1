#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Push SÉCURISÉ du sous-module mcps/internal (PHASE CRITIQUE)
.DESCRIPTION
    Ordre de push CRITIQUE : Sous-module EN PREMIER, Principal ENSUITE
    Raison : Le dépôt principal référence le sous-module
    Mission : Validation Fonctionnelle MCP et Push Final Sécurisé
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$SubmoduleDir = "d:/Dev/roo-extensions/mcps/internal"
Push-Location $SubmoduleDir

try {
    Write-Host "🚀 PUSH SOUS-MODULE mcps/internal" -ForegroundColor Cyan
    Write-Host "⚠️ PHASE CRITIQUE : Sous-module EN PREMIER" -ForegroundColor Yellow
    Write-Host ""

    # 1. Vérifier état local
    Write-Host "📊 ÉTAT LOCAL:" -ForegroundColor Cyan
    $currentBranch = git branch --show-current
    $currentSHA = git rev-parse HEAD
    Write-Host "  Branche: $currentBranch" -ForegroundColor Gray
    Write-Host "  SHA: $currentSHA" -ForegroundColor Gray
    
    $status = git status --short
    if ($status) {
        Write-Host ""
        Write-Host "⚠️ FICHIERS NON COMMITÉS:" -ForegroundColor Yellow
        Write-Host $status -ForegroundColor Gray
        Write-Host ""
        Write-Host "Ces fichiers ne seront PAS pushés (non commités)" -ForegroundColor Yellow
    }

    # 2. Vérifier commits à pusher
    Write-Host ""
    Write-Host "📤 COMMITS À PUSHER:" -ForegroundColor Cyan
    $commitsToPush = git log origin/$currentBranch..$currentBranch --oneline
    if (-not $commitsToPush) {
        Write-Host "  ℹ️ Aucun commit à pusher (déjà synchronisé)" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "✅ PUSH INUTILE - Déjà à jour" -ForegroundColor Green
        exit 0
    }
    Write-Host $commitsToPush -ForegroundColor Gray

    # 3. Vérifier commits distants non pullés
    Write-Host ""
    Write-Host "📥 COMMITS DISTANTS NON PULLÉS:" -ForegroundColor Cyan
    $remotesAhead = git log $currentBranch..origin/$currentBranch --oneline
    if ($remotesAhead) {
        Write-Host $remotesAhead -ForegroundColor Red
        Write-Host ""
        Write-Host "❌ ERREUR: Remote contient des commits non pullés" -ForegroundColor Red
        Write-Host "ACTION REQUISE: git pull --rebase avant push" -ForegroundColor Yellow
        exit 1
    }
    Write-Host "  ✅ Aucun commit distant non pullé" -ForegroundColor Green

    # 4. PUSH CRITIQUE
    Write-Host ""
    Write-Host "🚀 PUSH EN COURS..." -ForegroundColor Cyan
    Write-Host "  Commande: git push origin $currentBranch" -ForegroundColor Gray
    
    git push origin $currentBranch
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host ""
        Write-Host "❌ PUSH ÉCHOUÉ (Exit code: $LASTEXITCODE)" -ForegroundColor Red
        Write-Host ""
        Write-Host "🔍 DIAGNOSTIC:" -ForegroundColor Cyan
        git status
        Write-Host ""
        Write-Host "⚠️ NE CONTINUEZ PAS SANS RÉSOUDRE CETTE ERREUR" -ForegroundColor Yellow
        exit 1
    }

    # 5. Vérification post-push
    Write-Host ""
    Write-Host "✅ PUSH RÉUSSI" -ForegroundColor Green
    Write-Host ""
    Write-Host "🔍 VÉRIFICATION POST-PUSH:" -ForegroundColor Cyan
    
    # Forcer fetch pour mettre à jour refs
    git fetch origin $currentBranch | Out-Null
    
    $localSHA = git rev-parse HEAD
    $remoteSHA = git rev-parse origin/$currentBranch
    
    Write-Host "  Local HEAD:  $localSHA" -ForegroundColor Gray
    Write-Host "  Remote HEAD: $remoteSHA" -ForegroundColor Gray
    
    if ($localSHA -eq $remoteSHA) {
        Write-Host ""
        Write-Host "✅ SYNCHRONISATION CONFIRMÉE" -ForegroundColor Green
        Write-Host "Local et remote sont identiques" -ForegroundColor Gray
    } else {
        Write-Host ""
        Write-Host "⚠️ ATTENTION: Différence détectée après push" -ForegroundColor Yellow
        Write-Host "Cela peut être normal si d'autres commits ont été pushés" -ForegroundColor Gray
    }

    # 6. État final
    Write-Host ""
    Write-Host "📊 ÉTAT FINAL:" -ForegroundColor Cyan
    git status --short --branch

    Write-Host ""
    Write-Host "🎯 COMMITS PUSHÉS:" -ForegroundColor Cyan
    Write-Host $commitsToPush -ForegroundColor Green

} catch {
    Write-Host ""
    Write-Host "❌ ERREUR CRITIQUE: $_" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor Red
    exit 1
} finally {
    Pop-Location
}