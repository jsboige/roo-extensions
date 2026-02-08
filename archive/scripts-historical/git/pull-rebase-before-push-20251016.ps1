#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Pull --rebase sécurisé avant push final
.DESCRIPTION
    Résout la divergence entre local et remote avant push
    Ordre : Pull rebase PRINCIPAL -> Push SOUS-MODULE -> Push PRINCIPAL
    Mission : Validation Fonctionnelle MCP et Push Final Sécurisé
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$RootDir = "d:/Dev/roo-extensions"
Push-Location $RootDir

try {
    Write-Host "🔄 PULL REBASE SÉCURISÉ - DÉPÔT PRINCIPAL" -ForegroundColor Cyan
    Write-Host ""

    # 1. État avant rebase
    Write-Host "📊 ÉTAT AVANT REBASE:" -ForegroundColor Cyan
    git status --short --branch
    
    Write-Host ""
    Write-Host "📈 Commits locaux (à rejouer après rebase):" -ForegroundColor Cyan
    git log origin/main..HEAD --oneline
    
    Write-Host ""
    Write-Host "📥 Commits distants (à intégrer):" -ForegroundColor Cyan
    git log HEAD..origin/main --oneline

    # 2. Vérifier fichiers non commités
    $uncommitted = git status --short
    if ($uncommitted) {
        Write-Host ""
        Write-Host "⚠️ FICHIERS NON COMMITÉS DÉTECTÉS:" -ForegroundColor Yellow
        Write-Host $uncommitted -ForegroundColor Gray
        
        # Filtrer fichiers critiques vs scripts temporaires
        $criticalFiles = $uncommitted | Where-Object { 
            $_ -notmatch "scripts/git/.*\.ps1" -and 
            $_ -notmatch "mcps/internal.*scripts.*\.ps1"
        }
        
        if ($criticalFiles) {
            Write-Host ""
            Write-Host "❌ ERREUR: Fichiers critiques non commités" -ForegroundColor Red
            Write-Host $criticalFiles -ForegroundColor Red
            Write-Host ""
            Write-Host "ACTION REQUISE: Committez ou stash ces fichiers avant rebase" -ForegroundColor Yellow
            exit 1
        } else {
            Write-Host ""
            Write-Host "✅ Uniquement scripts temporaires non commités (OK)" -ForegroundColor Green
        }
    }

    # 3. PULL REBASE
    Write-Host ""
    Write-Host "🔄 EXÉCUTION PULL REBASE..." -ForegroundColor Cyan
    Write-Host "  Commande: git pull --rebase origin main" -ForegroundColor Gray
    
    git pull --rebase origin main
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host ""
        Write-Host "❌ REBASE ÉCHOUÉ (Exit code: $LASTEXITCODE)" -ForegroundColor Red
        Write-Host ""
        Write-Host "🔍 DIAGNOSTIC:" -ForegroundColor Cyan
        git status
        Write-Host ""
        Write-Host "⚠️ ACTIONS POSSIBLES:" -ForegroundColor Yellow
        Write-Host "  - Résoudre conflits : git status, éditer fichiers, git add, git rebase --continue" -ForegroundColor Gray
        Write-Host "  - Annuler rebase : git rebase --abort" -ForegroundColor Gray
        exit 1
    }

    # 4. Vérification post-rebase
    Write-Host ""
    Write-Host "✅ REBASE RÉUSSI" -ForegroundColor Green
    Write-Host ""
    Write-Host "📊 ÉTAT APRÈS REBASE:" -ForegroundColor Cyan
    git status --short --branch
    
    Write-Host ""
    Write-Host "📜 HISTORIQUE RÉÉCRIT (5 derniers commits):" -ForegroundColor Cyan
    git log --oneline -5

    # 5. Vérifier sous-module
    Write-Host ""
    Write-Host "📦 VÉRIFICATION SOUS-MODULE mcps/internal:" -ForegroundColor Cyan
    $submoduleStatus = git submodule status mcps/internal
    Write-Host "  $submoduleStatus" -ForegroundColor Gray
    
    $submoduleSHA = (git rev-parse HEAD:mcps/internal)
    Write-Host "  Référence dans principal: $submoduleSHA" -ForegroundColor Gray

    # 6. État final
    Write-Host ""
    Write-Host "🎯 RÉSUMÉ:" -ForegroundColor Cyan
    $ahead = (git rev-list --count origin/main..HEAD)
    $behind = (git rev-list --count HEAD..origin/main)
    
    Write-Host "  Commits local ahead: $ahead" -ForegroundColor Gray
    Write-Host "  Commits remote ahead: $behind" -ForegroundColor Gray
    
    if ($behind -gt 0) {
        Write-Host ""
        Write-Host "⚠️ ATTENTION: Encore des commits distants non intégrés" -ForegroundColor Yellow
        exit 1
    }
    
    Write-Host ""
    Write-Host "✅ REBASE COMPLET - Prêt pour push" -ForegroundColor Green

} catch {
    Write-Host ""
    Write-Host "❌ ERREUR CRITIQUE: $_" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor Red
    exit 1
} finally {
    Pop-Location
}