# Script d'extraction des 48 améliorations de logging
# Phase 2.6 - Récupération sécurisée des corrections stash
# Date: 2025-10-22

$ErrorActionPreference = "Stop"

Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "PHASE 2.6 - EXTRACTION DES 48 AMÉLIORATIONS" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host ""

# Charger le rapport de classification
$classificationReportPath = "docs/git/phase2-migration-check/classification-report.json"
if (-not (Test-Path $classificationReportPath)) {
    Write-Host "❌ Fichier de classification non trouvé: $classificationReportPath" -ForegroundColor Red
    Exit 1
}

Write-Host "📖 Lecture du rapport de classification..." -ForegroundColor Yellow
$classificationData = Get-Content $classificationReportPath -Raw | ConvertFrom-Json

Write-Host "✅ Rapport chargé avec succès" -ForegroundColor Green
Write-Host ""

# Analyser les stashs et extraire les corrections IMPORTANTES
$allImportantCorrections = @()

foreach ($stashData in $classificationData.Stashs) {
    $stashIndex = $stashData.Index
    $importantItems = $stashData.Categories.Important
    
    if ($importantItems -and $importantItems.Count -gt 0) {
        Write-Host "📦 Stash @{$stashIndex}: $($importantItems.Count) corrections importantes" -ForegroundColor Cyan
        
        foreach ($item in $importantItems) {
            $correction = [PSCustomObject]@{
                StashIndex = $stashIndex
                LineIndex = $item.Index
                Category = $item.Category
                Type = $item.Type
                Reason = $item.Reason
                Line = $item.Line
                Priority = $item.Priority
            }
            $allImportantCorrections += $correction
        }
    }
}

Write-Host ""
Write-Host "📊 RÉSUMÉ DES CORRECTIONS" -ForegroundColor Cyan
Write-Host "=========================" -ForegroundColor Cyan
Write-Host "Total corrections importantes: $($allImportantCorrections.Count)" -ForegroundColor Yellow
Write-Host ""

# Grouper par stash pour affichage
$groupedByStash = $allImportantCorrections | Group-Object -Property StashIndex | Sort-Object Name

foreach ($group in $groupedByStash) {
    Write-Host "Stash @{$($group.Name)}: $($group.Count) corrections" -ForegroundColor Green
}

Write-Host ""
Write-Host "📝 CLASSIFICATION PAR TYPE" -ForegroundColor Cyan
Write-Host "==========================" -ForegroundColor Cyan

$groupedByReason = $allImportantCorrections | Group-Object -Property Reason | Sort-Object Count -Descending

foreach ($reasonGroup in $groupedByReason) {
    Write-Host "$($reasonGroup.Name): $($reasonGroup.Count) corrections" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "✅ Extraction terminée avec succès" -ForegroundColor Green
Write-Host ""

# Sauvegarder un rapport JSON détaillé
$outputPath = "docs/git/phase2-migration-check/extracted-corrections.json"
$allImportantCorrections | ConvertTo-Json -Depth 10 | Out-File $outputPath -Encoding UTF8
Write-Host "📁 Rapport détaillé sauvegardé: $outputPath" -ForegroundColor Cyan

Write-Host ""
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "PRÊT POUR L'APPLICATION DES CORRECTIONS" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan