#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Script de diagnostic complet pour architecture Git multi-sous-modules
    
.DESCRIPTION
    Ce script analyse l'architecture Git complète du projet roo-extensions,
    identifie tous les sous-modules et cartographie leur état.
    
    MISSION CRITIQUE: Opération Git Multi-Sous-Modules - 24 Notifications
    Phase 1: Diagnostic Architecture Git Complète
    
.PARAMETER WorkspaceRoot
    Racine du workspace (défaut: d:/dev/roo-extensions)
    
.EXAMPLE
    .\diagnostic-multi-submodules.ps1
    
.NOTES
    Auteur: Roo State Manager
    Version: 1.0.0
    Criticité: MAXIMUM - Architecture distribuée
#>

param(
    [string]$WorkspaceRoot = "d:/dev/roo-extensions"
)

# Configuration et couleurs
$ErrorActionPreference = "Continue"
$OriginalLocation = Get-Location

try {
    # ============================================================================
    # PHASE 1.1: DIAGNOSTIC DÉPÔT PRINCIPAL
    # ============================================================================
    
    Write-Host "🔍 ARCHITECTURE GIT - DIAGNOSTIC COMPLET" -ForegroundColor Yellow
    Write-Host "=" * 60 -ForegroundColor Gray
    
    Set-Location $WorkspaceRoot
    Write-Host "📍 Workspace: $(Get-Location)" -ForegroundColor Cyan
    
    Write-Host "`n📂 DÉPÔT PRINCIPAL - ÉTAT DÉTAILLÉ:" -ForegroundColor Cyan
    Write-Host "-" * 40 -ForegroundColor Gray
    
    # Status git détaillé
    $mainStatus = git status --porcelain
    if ($mainStatus) {
        Write-Host "⚠️  CHANGEMENTS DÉTECTÉS DANS LE DÉPÔT PRINCIPAL:" -ForegroundColor Yellow
        $mainStatus | ForEach-Object { 
            Write-Host "   $_" -ForegroundColor White 
        }
        
        # Statistiques
        $modified = ($mainStatus | Where-Object {$_ -match '^ M'}).Count
        $untracked = ($mainStatus | Where-Object {$_ -match '^\?\?'}).Count
        $deleted = ($mainStatus | Where-Object {$_ -match '^ D'}).Count
        $added = ($mainStatus | Where-Object {$_ -match '^A '}).Count
        
        Write-Host "`n📊 STATISTIQUES DÉPÔT PRINCIPAL:" -ForegroundColor Cyan
        Write-Host "   ✏️  Modifiés: $modified" -ForegroundColor $(if ($modified -gt 0) { 'Yellow' } else { 'Green' })
        Write-Host "   ➕ Nouveaux: $untracked" -ForegroundColor $(if ($untracked -gt 0) { 'Yellow' } else { 'Green' })
        Write-Host "   ➖ Supprimés: $deleted" -ForegroundColor $(if ($deleted -gt 0) { 'Red' } else { 'Green' })
        Write-Host "   📝 Ajoutés: $added" -ForegroundColor $(if ($added -gt 0) { 'Green' } else { 'Gray' })
    } else {
        Write-Host "✅ DÉPÔT PRINCIPAL: Aucun changement" -ForegroundColor Green
    }
    
    # ============================================================================
    # PHASE 1.2: ANALYSE SOUS-MODULES OFFICIELS
    # ============================================================================
    
    Write-Host "`n📂 SOUS-MODULES OFFICIELS (.gitmodules):" -ForegroundColor Cyan
    Write-Host "-" * 40 -ForegroundColor Gray
    
    if (Test-Path ".gitmodules") {
        Write-Host "📋 Fichier .gitmodules détecté:" -ForegroundColor Green
        Get-Content ".gitmodules" | ForEach-Object { Write-Host "   $_" -ForegroundColor White }
        
        Write-Host "`n🔍 État des sous-modules:" -ForegroundColor Cyan
        git submodule status | ForEach-Object {
            Write-Host "   $_" -ForegroundColor White
        }
    } else {
        Write-Host "ℹ️  Aucun fichier .gitmodules - Pas de sous-modules Git officiels" -ForegroundColor Blue
    }
    
    # ============================================================================
    # PHASE 1.3: DÉTECTION RÉPERTOIRES .git INDEPENDANTS
    # ============================================================================
    
    Write-Host "`n📁 RÉPERTOIRES GIT INDÉPENDANTS:" -ForegroundColor Cyan
    Write-Host "-" * 40 -ForegroundColor Gray
    
    $gitDirectories = Get-ChildItem -Directory | Where-Object { 
        Test-Path (Join-Path $_.FullName '.git') 
    }
    
    if ($gitDirectories) {
        $componentResults = @{}
        
        foreach ($dir in $gitDirectories) {
            Write-Host "`n📁 COMPOSANT: $($dir.Name)" -ForegroundColor Magenta
            Push-Location $dir.FullName
            
            try {
                # Analyse détaillée du composant
                $componentStatus = git status --porcelain
                $branch = git branch --show-current
                $remoteUrl = git remote get-url origin 2>$null
                
                $componentData = @{
                    Name = $dir.Name
                    Path = $dir.FullName
                    Branch = $branch
                    RemoteUrl = $remoteUrl
                    Changes = $componentStatus
                    ChangeCount = ($componentStatus | Measure-Object).Count
                    Status = if ($componentStatus) { "CHANGEMENTS" } else { "PROPRE" }
                }
                
                $componentResults[$dir.Name] = $componentData
                
                # Affichage
                Write-Host "   🌿 Branche: $branch" -ForegroundColor $(if ($branch -eq 'main') { 'Green' } else { 'Yellow' })
                Write-Host "   🔗 Remote: $remoteUrl" -ForegroundColor Gray
                Write-Host "   📊 Changements: $($componentData.ChangeCount)" -ForegroundColor $(if ($componentData.ChangeCount -gt 0) { 'Yellow' } else { 'Green' })
                
                if ($componentStatus) {
                    Write-Host "   📝 Détails changements:" -ForegroundColor Yellow
                    $componentStatus | ForEach-Object { Write-Host "      $_" -ForegroundColor White }
                }
                
            } catch {
                Write-Host "   ❌ Erreur analyse: $($_.Exception.Message)" -ForegroundColor Red
                $componentResults[$dir.Name] = @{
                    Name = $dir.Name
                    Status = "ERREUR"
                    Error = $_.Exception.Message
                }
            }
            
            Pop-Location
        }
        
        # ============================================================================
        # PHASE 1.4: SYNTHÈSE ARCHITECTURE
        # ============================================================================
        
        Write-Host "`n🎯 SYNTHÈSE ARCHITECTURE MULTI-COMPOSANTS:" -ForegroundColor Yellow
        Write-Host "=" * 60 -ForegroundColor Gray
        
        $totalComponents = $componentResults.Count
        $componentsWithChanges = ($componentResults.Values | Where-Object { $_.ChangeCount -gt 0 }).Count
        $totalChanges = ($componentResults.Values | ForEach-Object { $_.ChangeCount } | Measure-Object -Sum).Sum
        
        Write-Host "📈 STATISTIQUES GLOBALES:" -ForegroundColor Cyan
        Write-Host "   🏗️  Composants détectés: $totalComponents" -ForegroundColor White
        Write-Host "   ⚡ Composants avec changements: $componentsWithChanges" -ForegroundColor $(if ($componentsWithChanges -gt 0) { 'Yellow' } else { 'Green' })
        Write-Host "   📊 Total changements: $totalChanges" -ForegroundColor $(if ($totalChanges -gt 0) { 'Yellow' } else { 'Green' })
        
        Write-Host "`n📋 RÉSUMÉ PAR COMPOSANT:" -ForegroundColor Cyan
        $componentResults.GetEnumerator() | Sort-Object Name | ForEach-Object {
            $comp = $_.Value
            $statusColor = switch ($comp.Status) {
                "PROPRE" { "Green" }
                "CHANGEMENTS" { "Yellow" }
                "ERREUR" { "Red" }
                default { "Gray" }
            }
            Write-Host "   $($comp.Status.PadRight(12)) | $($comp.Name)" -ForegroundColor $statusColor
        }
        
        # ============================================================================
        # PHASE 1.5: RECOMMANDATIONS STRATÉGIQUES
        # ============================================================================
        
        Write-Host "`n🎯 RECOMMANDATIONS STRATÉGIQUES:" -ForegroundColor Yellow
        Write-Host "-" * 40 -ForegroundColor Gray
        
        if ($totalChanges -eq 0) {
            Write-Host "✅ ARCHITECTURE STABLE - Aucun changement détecté" -ForegroundColor Green
            Write-Host "   → Validation simple suffisante" -ForegroundColor Green
        } elseif ($totalChanges -lt 10) {
            Write-Host "⚡ CHANGEMENTS MODÉRÉS - $totalChanges modifications" -ForegroundColor Yellow
            Write-Host "   → Commits séquentiels recommandés" -ForegroundColor Yellow
        } else {
            Write-Host "🚨 CHANGEMENTS IMPORTANTS - $totalChanges modifications" -ForegroundColor Red
            Write-Host "   → Opération critique avec sauvegarde préalable" -ForegroundColor Red
        }
        
        Write-Host "`n🔄 ORDRE DE TRAITEMENT SUGGÉRÉ:" -ForegroundColor Cyan
        $processingOrder = $componentResults.Values | 
            Sort-Object { 
                # Priorité: mcps d'abord, puis par nombre de changements
                if ($_.Name -eq "mcps") { 0 }
                elseif ($_.Name -like "*roo-*") { 1 }
                else { 2 + $_.ChangeCount }
            }
        
        $processingOrder | ForEach-Object {
            $priority = switch ($_.Name) {
                "mcps" { "[INFRA]" }
                { $_ -like "*roo-*" } { "[CORE]" }
                default { "[COMP]" }
            }
            Write-Host "   $priority | $($_.Name) ($($_.ChangeCount) changements)" -ForegroundColor White
        }
        
        # Sauvegarde résultats
        $results = @{
            Timestamp = Get-Date -Format "yyyy-MM-dd-HH:mm:ss"
            WorkspaceRoot = $WorkspaceRoot
            MainStatus = $mainStatus
            Components = $componentResults
            Statistics = @{
                TotalComponents = $totalComponents
                ComponentsWithChanges = $componentsWithChanges
                TotalChanges = $totalChanges
            }
            ProcessingOrder = $processingOrder
        }
        
        $resultsPath = "analysis-reports/git-diagnostic-$(Get-Date -Format 'yyyy-MM-dd-HHmm').json"
        $results | ConvertTo-Json -Depth 5 | Out-File -FilePath $resultsPath -Encoding UTF8
        Write-Host "`n💾 Diagnostic sauvegardé: $resultsPath" -ForegroundColor Blue
        
    } else {
        Write-Host "ℹ️  Aucun répertoire Git indépendant détecté" -ForegroundColor Blue
    }
    
    Write-Host "`n✅ DIAGNOSTIC ARCHITECTURE COMPLÉTÉ" -ForegroundColor Green
    Write-Host "=" * 60 -ForegroundColor Gray
    
} catch {
    Write-Host "ERREUR CRITIQUE: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
} finally {
    Set-Location $OriginalLocation
}