# Script: reorganize-docs-root.ps1
# Description: Réorganisation automatique de la racine docs/
# Date: 2025-10-11
# Phase: SDDD Action A.1

param(
    [switch]$WhatIf = $false,
    [switch]$Verbose = $false
)

$ErrorActionPreference = "Stop"
$baseDir = "docs"

# Définition des déplacements
$moves = @{
    "configuration" = @(
        "configuration-mcp-roo.md",
        "configuration-win-cli-operateurs.md",
        "guide-configuration-mcps.md",
        "mcp_configuration_summary.md"
    )
    "analyses" = @(
        "competitive_analysis.md",
        "Jupyter_MCP_Failure_Analysis.md",
        "rapport-analyse-organisation-actuelle.md"
    )
    "monitoring" = @(
        "daily-monitoring-implementation-report.md",
        "daily-monitoring-system.md",
        "mcp-debug-logging-system.md"
    )
    "architecture" = @(
        "conversation-discovery-architecture.md",
        "diagramme-nouvelle-structure.md",
        "analyse-synchronisation-orchestration-dynamique.md",
        "repository-map.md"
    )
    "guides" = @(
        "consolidated-task-management-guide.md",
        "guide-complet-modes-roo.md",
        "GUIDE-ENCODAGE.md",
        "guide-exploration-prompts-natifs.md",
        "guide-synchronisation-submodules.md",
        "guide-utilisation-mcp-jupyter.md",
        "guide-utilisation-profils-modes.md",
        "mcp-deployment.md",
        "procedures-maintenance.md"
    )
    "project" = @(
        "project-changelog.md",
        "project-status.md",
        "plan-mise-a-jour-orchestration-dynamique.md",
        "plan-reorganisation-depot.md",
        "instructions-implementation-reorganisation.md"
    )
    "rapports" = @(
        "git-sync-report-20250915.md",
        "rapport-configuration-mcps-github-20250914.md",
        "rapport-configurations-modes-natifs.md",
        "rapport-etat-mcps.md",
        "rapport-final-mission-sddd-troncature-architecture-20250915.md",
        "rapport-mise-a-jour-orchestration-dynamique.md",
        "rapport-synthese-modes-roo.md",
        "rapport-validation-evolutions-20250915.md",
        "system_validation_report_20250920.md"
    )
    "fixes" = @(
        "REPAIR-ROO-STATE-MANAGER-220GB-LEAK-FIX.md"
    )
}

Write-Host "=== REORGANISATION docs/ - Phase 2 SDDD ===" -ForegroundColor Cyan
Write-Host ""

# Statistiques
$totalFiles = ($moves.Values | ForEach-Object { $_.Count } | Measure-Object -Sum).Sum
$totalCategories = $moves.Keys.Count
$createdDirs = 0
$movedFiles = 0
$errors = 0

Write-Host "Plan de deplacement:" -ForegroundColor Yellow
Write-Host "   - Categories: $totalCategories" -ForegroundColor Gray
Write-Host "   - Fichiers a deplacer: $totalFiles" -ForegroundColor Gray
Write-Host ""

if ($WhatIf) {
    Write-Host "MODE SIMULATION (WhatIf active)" -ForegroundColor Yellow
    Write-Host ""
}

# Traitement par catégorie
foreach ($category in $moves.Keys) {
    $targetDir = Join-Path $baseDir $category
    $files = $moves[$category]
    
    Write-Host "Categorie: $category ($($files.Count) fichiers)" -ForegroundColor Green
    
    # Créer le dossier si nécessaire
    if (-not (Test-Path $targetDir)) {
        if ($WhatIf) {
            Write-Host "   [SIMULATION] Creerait: $targetDir" -ForegroundColor DarkGray
        } else {
            New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
            Write-Host "   Cree: $targetDir" -ForegroundColor DarkGreen
            $createdDirs++
        }
    } else {
        Write-Host "   Existe deja: $targetDir" -ForegroundColor DarkGray
    }
    
    # Déplacer les fichiers
    foreach ($file in $files) {
        $sourcePath = Join-Path $baseDir $file
        $targetPath = Join-Path $targetDir $file
        
        if (Test-Path $sourcePath) {
            if ($WhatIf) {
                Write-Host "   [SIMULATION] Deplacerait: $file" -ForegroundColor DarkGray
            } else {
                try {
                    Move-Item -Path $sourcePath -Destination $targetPath -Force
                    Write-Host "   Deplace: $file" -ForegroundColor DarkGreen
                    $movedFiles++
                    
                    if ($Verbose) {
                        Write-Host "      Source: $sourcePath" -ForegroundColor DarkGray
                        Write-Host "      Dest:   $targetPath" -ForegroundColor DarkGray
                    }
                } catch {
                    Write-Host "   ERREUR: $file - $($_.Exception.Message)" -ForegroundColor Red
                    $errors++
                }
            }
        } else {
            Write-Host "   INTROUVABLE: $file" -ForegroundColor Yellow
            $errors++
        }
    }
    
    Write-Host ""
}

# Rapport final
Write-Host "=== RAPPORT FINAL ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "Statistiques:" -ForegroundColor Yellow
Write-Host "   - Dossiers crees: $createdDirs / $totalCategories" -ForegroundColor Gray
Write-Host "   - Fichiers deplaces: $movedFiles / $totalFiles" -ForegroundColor Gray
Write-Host "   - Erreurs: $errors" -ForegroundColor $(if ($errors -eq 0) { "Green" } else { "Red" })
Write-Host ""

if ($WhatIf) {
    Write-Host "Pour executer reellement, relancez sans -WhatIf" -ForegroundColor Yellow
} elseif ($errors -eq 0) {
    Write-Host "REORGANISATION TERMINEE AVEC SUCCES" -ForegroundColor Green
} else {
    Write-Host "REORGANISATION TERMINEE AVEC ERREURS" -ForegroundColor Red
    exit 1
}