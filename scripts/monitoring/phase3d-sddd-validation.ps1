#Requires -Version 5.1
<#
.SYNOPSIS
    Script de validation SDDD finale pour la Phase 3D

.DESCRIPTION
    Ce script valide la conformité SDDD complète de la Phase 3
    en vérifiant tous les critères méthodologiques et techniques.

.PARAMETER Comprehensive
    Exécute une validation complète et détaillée

.PARAMETER Report
    Génère un rapport de validation SDDD

.EXAMPLE
    .\phase3d-sddd-validation.ps1 -Comprehensive -Report
    Exécute la validation complète et génère le rapport

.NOTES
    Auteur: Roo Extensions Team
    Version: 1.0.0 - Phase 3D
    Date: 2025-12-04
#>

param (
    [switch]$Comprehensive,
    [switch]$Report
)

# Configuration globale
$ErrorActionPreference = "Stop"
$ProgressPreference = "Continue"
$PSDefaultParameterValues['Out-File:Encoding'] = 'utf8'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# Variables globales
$Timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$ValidationResults = @{}
$TotalCriteria = 0
$PassedCriteria = 0

# Fonction pour logger les résultats de validation
function Write-ValidationResult {
    param(
        [string]$Criterion,
        [bool]$Passed,
        [string]$Message = "",
        [object]$Details = $null,
        [int]$Weight = 1
    )
    
    $script:TotalCriteria += $Weight
    if ($Passed) {
        $script:PassedCriteria += $Weight
        Write-Host "✅ $Criterion" -ForegroundColor Green
    } else {
        Write-Host "❌ $Criterion" -ForegroundColor Red
        if ($Message) {
            Write-Host "   $Message" -ForegroundColor Yellow
        }
    }
    
    $script:ValidationResults[$Criterion] = @{
        Passed = $Passed
        Message = $Message
        Details = $Details
        Weight = $Weight
        Timestamp = Get-Date
    }
}

# Fonction pour valider le grounding sémantique
function Test-SemanticGrounding {
    Write-Host "🔍 VALIDATION GROUNDING SÉMANTIQUE" -ForegroundColor Cyan
    Write-Host "===================================" -ForegroundColor Cyan
    
    # Critère 1: Recherche sémantique initiale effectuée
    Write-Host "Test de la recherche sémantique initiale..." -ForegroundColor Gray
    $groundingDocs = @(
        "docs\planning\PHASE3_SDDD_PLANIFICATION_AVEC_POINTS_VALIDATION.md",
        "sddd-tracking\50-CHECKPOINT-4-PHASE3C-ROBUSTESSE-PERFORMANCE-2025-12-04.md"
    )
    
    $groundingExists = $true
    foreach ($doc in $groundingDocs) {
        if (Test-Path $doc) {
            $content = Get-Content $doc -Raw
            if ($content -match "codebase_search|grounding|sémantique") {
                Write-Host "  ✓ Grounding trouvé dans $(Split-Path $doc -Leaf)" -ForegroundColor Green
            } else {
                Write-Host "  ⚠ Grounding non explicite dans $(Split-Path $doc -Leaf)" -ForegroundColor Yellow
            }
        } else {
            Write-Host "  ✗ Document manquant: $(Split-Path $doc -Leaf)" -ForegroundColor Red
            $groundingExists = $false
        }
    }
    
    Write-ValidationResult -Criterion "Recherche Sémantique Initiale" -Passed $groundingExists -Weight 2
    
    # Critère 2: Analyse de l'état actuel documentée
    Write-Host "Test de l'analyse de l'état actuel..." -ForegroundColor Gray
    $analysisDocs = @(
        "sddd-tracking\51-CHECKPOINT-5-PHASE3D-FINALISATION-DOCUMENTATION-2025-12-04.md"
    )
    
    $analysisExists = $true
    foreach ($doc in $analysisDocs) {
        if (Test-Path $doc) {
            Write-Host "  ✓ Analyse trouvée: $(Split-Path $doc -Leaf)" -ForegroundColor Green
        } else {
            Write-Host "  ✗ Analyse manquante: $(Split-Path $doc -Leaf)" -ForegroundColor Red
            $analysisExists = $false
        }
    }
    
    Write-ValidationResult -Criterion "Analyse État Actuel" -Passed $analysisExists -Weight 2
    
    # Critère 3: Décisions basées sur données
    Write-Host "Test des décisions basées sur données..." -ForegroundColor Gray
    $dataDrivenDecisions = $true
    
    # Vérifier les rapports de tests
    $testReports = Get-ChildItem -Path "reports\phase3d-integration-*" -Filter "*.json" -ErrorAction SilentlyContinue
    if ($testReports.Count -gt 0) {
        Write-Host "  ✓ Rapports de tests trouvés: $($testReports.Count)" -ForegroundColor Green
        foreach ($report in $testReports) {
            try {
                $data = Get-Content $report.FullName -Raw | ConvertFrom-Json
                if ($data.Summary) {
                    Write-Host "    ✓ Métriques trouvées dans $(Split-Path $report.Name -Leaf)" -ForegroundColor Green
                }
            } catch {
                Write-Host "    ⚠ Rapport invalide: $(Split-Path $report.Name -Leaf)" -ForegroundColor Yellow
            }
        }
    } else {
        Write-Host "  ✗ Aucun rapport de test trouvé" -ForegroundColor Red
        $dataDrivenDecisions = $false
    }
    
    Write-ValidationResult -Criterion "Décisions Basées sur Données" -Passed $dataDrivenDecisions -Weight 3
    
    Write-Host ""
}

# Fonction pour valider la documentation continue
function Test-ContinuousDocumentation {
    Write-Host "📚 VALIDATION DOCUMENTATION CONTINUE" -ForegroundColor Cyan
    Write-Host "=====================================" -ForegroundColor Cyan
    
    # Critère 1: Checkpoints réguliers créés
    Write-Host "Test des checkpoints réguliers..." -ForegroundColor Gray
    $checkpointPattern = "sddd-tracking\*-CHECKPOINT-*-*.md"
    $checkpoints = Get-ChildItem -Path $checkpointPattern -ErrorAction SilentlyContinue | Sort-Object Name
    
    if ($checkpoints.Count -ge 5) {
        Write-Host "  ✓ Checkpoints trouvés: $($checkpoints.Count)" -ForegroundColor Green
        $checkpointNumbers = @()
        foreach ($checkpoint in $checkpoints) {
            if ($checkpoint.Name -match 'CHECKPOINT-(\d+)') {
                $checkpointNumbers += [int]$matches[1]
            }
        }
        $checkpointNumbers = $checkpointNumbers | Sort-Object
        Write-Host "  ✓ Numérotation: $($checkpointNumbers -join ', ')" -ForegroundColor Green
        $checkpointsOk = $true
    } else {
        Write-Host "  ✗ Checkpoints insuffisants: $($checkpoints.Count)" -ForegroundColor Red
        $checkpointsOk = $false
    }
    
    Write-ValidationResult -Criterion "Checkpoints Réguliers" -Passed $checkpointsOk -Weight 2
    
    # Critère 2: Documentation technique complète
    Write-Host "Test de la documentation technique..." -ForegroundColor Gray
    $technicalDocs = @(
        "docs\planning\PHASE3_SDDD_PLANIFICATION_AVEC_POINTS_VALIDATION.md",
        "docs\planning\PHASE4_ROADMAP_INVESTIGATION_AMÉLIORATIONS.md",
        "docs\user-guide\README.md",
        "docs\user-guide\QUICK-START.md",
        "docs\user-guide\TROUBLESHOOTING.md"
    )
    
    $technicalDocsExist = $true
    foreach ($doc in $technicalDocs) {
        if (Test-Path $doc) {
            $lines = (Get-Content $doc).Count
            Write-Host "  ✓ $(Split-Path $doc -Leaf) ($lines lignes)" -ForegroundColor Green
        } else {
            Write-Host "  ✗ $(Split-Path $doc -Leaf) manquant" -ForegroundColor Red
            $technicalDocsExist = $false
        }
    }
    
    Write-ValidationResult -Criterion "Documentation Technique Complète" -Passed $technicalDocsExist -Weight 3
    
    # Critère 3: Métriques et KPIs documentés
    Write-Host "Test des métriques et KPIs..." -ForegroundColor Gray
    $metricsDocumented = $false
    
    # Vérifier les rapports de métriques
    $metricsReports = Get-ChildItem -Path "reports\*" -Filter "*metrics*.json" -ErrorAction SilentlyContinue
    if ($metricsReports.Count -gt 0) {
        Write-Host "  ✓ Rapports de métriques: $($metricsReports.Count)" -ForegroundColor Green
        $metricsDocumented = $true
    }
    
    # Vérifier les tableaux de bord
    $dashboardPath = "scripts\monitoring\dashboard-generator.ps1"
    if (Test-Path $dashboardPath) {
        Write-Host "  ✓ Générateur de tableau de bord trouvé" -ForegroundColor Green
        $metricsDocumented = $true
    }
    
    Write-ValidationResult -Criterion "Métriques et KPIs Documentés" -Passed $metricsDocumented -Weight 2
    
    Write-Host ""
}

# Fonction pour valider la validation finale
function Test-FinalValidation {
    Write-Host "🎯 VALIDATION FINALE SDDD" -ForegroundColor Cyan
    Write-Host "===========================" -ForegroundColor Cyan
    
    # Critère 1: Tests finaux exécutés
    Write-Host "Test des tests finaux exécutés..." -ForegroundColor Gray
    $finalTests = Get-ChildItem -Path "reports\phase3d-integration-*" -Filter "*.json" -ErrorAction SilentlyContinue
    
    if ($finalTests.Count -gt 0) {
        Write-Host "  ✓ Tests finaux trouvés: $($finalTests.Count)" -ForegroundColor Green
        $latestTest = $finalTests | Sort-Object LastWriteTime -Descending | Select-Object -First 1
        try {
            $testData = Get-Content $latestTest.FullName -Raw | ConvertFrom-Json
            $successRate = $testData.Summary.SuccessRate
            Write-Host "  ✓ Taux de succès: $successRate%" -ForegroundColor Green
            $finalTestsOk = $successRate -ge 80
        } catch {
            Write-Host "  ✗ Impossible de lire les résultats des tests" -ForegroundColor Red
            $finalTestsOk = $false
        }
    } else {
        Write-Host "  ✗ Aucun test final trouvé" -ForegroundColor Red
        $finalTestsOk = $false
    }
    
    Write-ValidationResult -Criterion "Tests Finaux Exécutés" -Passed $finalTestsOk -Weight 3
    
    # Critère 2: Conformité globale mesurée
    Write-Host "Test de la conformité globale mesurée..." -ForegroundColor Gray
    $conformityMeasured = $false
    
    # Vérifier le rapport final de Phase 3D
    $finalReport = "sddd-tracking\51-CHECKPOINT-5-PHASE3D-FINALISATION-DOCUMENTATION-2025-12-04.md"
    if (Test-Path $finalReport) {
        $content = Get-Content $finalReport -Raw
        if ($content -match "Score de Conformité.*?(\d+\.?\d*)%") {
            $conformityScore = [double]$matches[1]
            Write-Host "  ✓ Score de conformité: $conformityScore%" -ForegroundColor Green
            $conformityMeasured = $conformityScore -ge 85
        }
    }
    
    Write-ValidationResult -Criterion "Conformité Globale Mesurée" -Passed $conformityMeasured -Weight 3
    
    # Critère 3: Leçons apprises documentées
    Write-Host "Test des leçons apprises documentées..." -ForegroundColor Gray
    $lessonsLearned = $false
    
    if (Test-Path $finalReport) {
        $content = Get-Content $finalReport -Raw
        if ($content -match "Leçons Apprises|Lessons Learned") {
            Write-Host "  ✓ Section leçons apprises trouvée" -ForegroundColor Green
            $lessonsLearned = $true
        }
    }
    
    Write-ValidationResult -Criterion "Leçons Apprises Documentées" -Passed $lessonsLearned -Weight 2
    
    Write-Host ""
}

# Fonction pour valider la discoverabilité
function Test-Discoverability {
    Write-Host "🔍 VALIDATION DISCOVERABILITÉ" -ForegroundColor Cyan
    Write-Host "================================" -ForegroundColor Cyan
    
    # Critère 1: Indexation sémantique
    Write-Host "Test de l'indexation sémantique..." -ForegroundColor Gray
    $semanticIndex = $false
    
    # Vérifier la structure des documents
    $sdddDocs = Get-ChildItem -Path "sddd-tracking\*.md" -ErrorAction SilentlyContinue
    if ($sdddDocs.Count -gt 0) {
        Write-Host "  ✓ Documents SDDD indexés: $($sdddDocs.Count)" -ForegroundColor Green
        $numberedDocs = $sdddDocs | Where-Object { $_.Name -match '^\d+-' }
        Write-Host "  ✓ Documents numérotés: $($numberedDocs.Count)" -ForegroundColor Green
        $semanticIndex = $numberedDocs.Count -ge 10
    }
    
    Write-ValidationResult -Criterion "Indexation Sémantique" -Passed $semanticIndex -Weight 2
    
    # Critère 2: Références croisées
    Write-Host "Test des références croisées..." -ForegroundColor Gray
    $crossReferences = $false
    
    # Vérifier les références dans les documents
    $planDoc = "docs\planning\PHASE3_SDDD_PLANIFICATION_AVEC_POINTS_VALIDATION.md"
    if (Test-Path $planDoc) {
        $content = Get-Content $planDoc -Raw
        # Utiliser une méthode simple pour compter les références
        $referenceCount = ($content -split '\[').Count - 1
        Write-Host "  ✓ Références trouvées: $referenceCount" -ForegroundColor Green
        $crossReferences = $referenceCount -ge 20
    }
    
    Write-ValidationResult -Criterion "Références Croisées" -Passed $crossReferences -Weight 2
    
    # Critère 3: Continuité documentaire
    Write-Host "Test de la continuité documentaire..." -ForegroundColor Gray
    $documentaryContinuity = $false
    
    # Vérifier la chaîne de documentation
    $docChain = @(
        "docs\planning\PHASE3_SDDD_PLANIFICATION_AVEC_POINTS_VALIDATION.md",
        "sddd-tracking\50-CHECKPOINT-4-PHASE3C-ROBUSTESSE-PERFORMANCE-2025-12-04.md",
        "sddd-tracking\51-CHECKPOINT-5-PHASE3D-FINALISATION-DOCUMENTATION-2025-12-04.md",
        "docs\planning\PHASE4_ROADMAP_INVESTIGATION_AMÉLIORATIONS.md"
    )
    
    $chainComplete = $true
    foreach ($doc in $docChain) {
        if (Test-Path $doc) {
            Write-Host "  ✓ Maillon de la chaîne: $(Split-Path $doc -Leaf)" -ForegroundColor Green
        } else {
            Write-Host "  ✗ Maillon manquant: $(Split-Path $doc -Leaf)" -ForegroundColor Red
            $chainComplete = $false
        }
    }
    
    $documentaryContinuity = $chainComplete
    Write-ValidationResult -Criterion "Continuité Documentaire" -Passed $documentaryContinuity -Weight 2
    
    Write-Host ""
}

# Fonction pour générer le rapport de validation SDDD
function New-SDDDValidationReport {
    if (-not $Report) { return }
    
    Write-Host "📊 GÉNÉRATION DU RAPPORT DE VALIDATION SDDD" -ForegroundColor Yellow
    Write-Host "--------------------------------------------" -ForegroundColor Yellow
    
    $conformityScore = if ($TotalCriteria -gt 0) { [math]::Round($PassedCriteria / $TotalCriteria * 100, 2) } else { 0 }
    
    $reportData = @{
        Timestamp = $Timestamp
        ValidationType = "SDDD Phase 3D Finale"
        Summary = @{
            TotalCriteria = $TotalCriteria
            PassedCriteria = $PassedCriteria
            FailedCriteria = $TotalCriteria - $PassedCriteria
            ConformityScore = $conformityScore
            Status = if ($conformityScore -ge 90) { "EXCELLENT" } elseif ($conformityScore -ge 80) { "BON" } elseif ($conformityScore -ge 70) { "ACCEPTABLE" } else { "INSUFFISANT" }
        }
        ValidationResults = $ValidationResults
        Recommendations = @()
    }
    
    # Ajouter les recommandations basées sur les échecs
    foreach ($result in $ValidationResults.GetEnumerator()) {
        if (-not $result.Value.Passed) {
            $recommendation = switch ($result.Key) {
                "Recherche Sémantique Initiale" { "Effectuer une recherche sémantique complète avant toute implémentation" }
                "Analyse État Actuel" { "Documenter l'analyse détaillée de l'état actuel du système" }
                "Décisions Basées sur Données" { "Baser toutes les décisions sur des métriques et données concrètes" }
                "Checkpoints Réguliers" { "Créer des checkpoints réguliers toutes les 3-5 jours" }
                "Documentation Technique Complète" { "Documenter tous les aspects techniques de manière complète" }
                "Métriques et KPIs Documentés" { "Documenter toutes les métriques et indicateurs de performance" }
                "Tests Finaux Exécutés" { "Exécuter des tests finaux complets avec taux de succès > 80%" }
                "Conformité Globale Mesurée" { "Mesurer et documenter la conformité globale du projet" }
                "Leçons Apprises Documentées" { "Documenter les leçons apprises et recommandations" }
                "Indexation Sémantique" { "Assurer une indexation sémantique complète de tous les documents" }
                "Références Croisées" { "Créer des références croisées entre tous les documents" }
                "Continuité Documentaire" { "Maintenir une continuité documentaire tout au long du projet" }
                default { "Corriger le critère de validation échoué" }
            }
            $reportData.Recommendations += $recommendation
        }
    }
    
    # Génération du rapport JSON
    $jsonReport = $reportData | ConvertTo-Json -Depth 10
    $jsonPath = "reports\sddd-validation-$Timestamp.json"
    $jsonReport | Out-File -FilePath $jsonPath -Encoding UTF8
    
    # Génération du rapport HTML
    $htmlReport = @"
<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Rapport de Validation SDDD - Phase 3D</title>
    <style>
        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; margin: 20px; background-color: #f5f5f5; }
        .container { max-width: 1200px; margin: 0 auto; background: white; padding: 30px; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        h1 { color: #2c3e50; border-bottom: 3px solid #3498db; padding-bottom: 10px; }
        h2 { color: #34495e; margin-top: 30px; }
        .summary { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 20px; margin: 20px 0; }
        .metric { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 20px; border-radius: 10px; text-align: center; }
        .metric h3 { margin: 0 0 10px 0; font-size: 2em; }
        .metric p { margin: 0; opacity: 0.9; }
        .validation-result { margin: 10px 0; padding: 15px; border-radius: 5px; border-left: 4px solid; }
        .validation-passed { background-color: #d4edda; border-left-color: #28a745; }
        .validation-failed { background-color: #f8d7da; border-left-color: #dc3545; }
        .conformity-score { font-size: 2em; font-weight: bold; color: $(if ($conformityScore -ge 90) { '#28a745' } elseif ($conformityScore -ge 80) { '#ffc107' } elseif ($conformityScore -ge 70) { '#fd7e14' } else { '#dc3545' }); }
        .recommendations { background-color: #fff3cd; border: 1px solid #ffeaa7; border-radius: 5px; padding: 20px; margin: 20px 0; }
        .recommendations h3 { color: #856404; margin-top: 0; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🔍 Rapport de Validation SDDD - Phase 3D</h1>
        <p><strong>Date:</strong> $Timestamp</p>
        <p><strong>Type:</strong> Validation SDDD Phase 3D Finale</p>
        
        <div class="summary">
            <div class="metric">
                <h3>$($reportData.Summary.TotalCriteria)</h3>
                <p>Critères Total</p>
            </div>
            <div class="metric">
                <h3>$($reportData.Summary.PassedCriteria)</h3>
                <p>Critères Réussis</p>
            </div>
            <div class="metric">
                <h3>$($reportData.Summary.FailedCriteria)</h3>
                <p>Critères Échoués</p>
            </div>
            <div class="metric">
                <h3 class="conformity-score">$($reportData.Summary.ConformityScore)%</h3>
                <p>Score de Conformité</p>
            </div>
        </div>
        
        <h2>📊 Résultats de Validation</h2>
"@
    
    foreach ($result in $ValidationResults.GetEnumerator()) {
        $statusClass = if ($result.Value.Passed) { "validation-passed" } else { "validation-failed" }
        $statusIcon = if ($result.Value.Passed) { "✅" } else { "❌" }
        
        $htmlReport += @"
        <div class="validation-result $statusClass">
            <h3>$statusIcon $($result.Key)</h3>
            <p><strong>Statut:</strong> $(if ($result.Value.Passed) { 'Réussi' } else { 'Échoué' })</p>
            $(if ($result.Value.Message) { "<p><strong>Message:</strong> $($result.Value.Message)</p>" } )
            <p><strong>Poids:</strong> $($result.Value.Weight)</p>
        </div>
"@
    }
    
    if ($reportData.Recommendations.Count -gt 0) {
        $htmlReport += @"
        <div class="recommendations">
            <h3>📋 Recommandations</h3>
            <ul>
"@
        foreach ($recommendation in $reportData.Recommendations) {
            $htmlReport += "                <li>$recommendation</li>`n"
        }
        $htmlReport += @"
            </ul>
        </div>
"@
    }
    
    $htmlReport += @"
    </div>
</body>
</html>
"@
    
    $htmlPath = "reports\sddd-validation-$Timestamp.html"
    $htmlReport | Out-File -FilePath $htmlPath -Encoding UTF8
    
    Write-Host "  ✓ Rapport JSON généré: $jsonPath" -ForegroundColor Green
    Write-Host "  ✓ Rapport HTML généré: $htmlPath" -ForegroundColor Green
    Write-Host ""
}

# Programme principal
try {
    Write-Host "🔍 DÉMARRAGE DE LA VALIDATION SDDD PHASE 3D" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "Timestamp: $Timestamp" -ForegroundColor Gray
    Write-Host "Mode: $(if ($Comprehensive) { 'Complet' } else { 'Standard' })" -ForegroundColor Gray
    Write-Host ""
    
    # Exécution des validations
    Test-SemanticGrounding
    Test-ContinuousDocumentation
    Test-FinalValidation
    Test-Discoverability
    
    # Génération du rapport
    New-SDDDValidationReport
    
    # Calcul du score final
    $finalScore = if ($TotalCriteria -gt 0) { [math]::Round($PassedCriteria / $TotalCriteria * 100, 2) } else { 0 }
    
    # Affichage du résumé final
    Write-Host "📊 RÉSUMÉ FINAL DE VALIDATION SDDD" -ForegroundColor Cyan
    Write-Host "=====================================" -ForegroundColor Cyan
    Write-Host "Critères totaux: $TotalCriteria" -ForegroundColor White
    Write-Host "Critères réussis: $PassedCriteria" -ForegroundColor Green
    Write-Host "Critères échoués: $($TotalCriteria - $PassedCriteria)" -ForegroundColor Red
    Write-Host "Score de conformité: $finalScore%" -ForegroundColor $(if ($finalScore -ge 90) { "Green" } elseif ($finalScore -ge 80) { "Yellow" } else { "Red" })
    
    Write-Host ""
    Write-Host "📁 Rapports générés dans: reports\" -ForegroundColor Gray
    
    if ($Report) {
        Write-Host "🌐 Ouvrir le rapport HTML: start $htmlPath" -ForegroundColor Gray
    }
    
    # Validation du statut final
    if ($finalScore -ge 90) {
        Write-Host "🎉 VALIDATION SDDD EXCELLENTE" -ForegroundColor Green
        Write-Host "La Phase 3D atteint un niveau de conformité exceptionnel" -ForegroundColor Green
        exit 0
    } elseif ($finalScore -ge 80) {
        Write-Host "✅ VALIDATION SDDD BONNE" -ForegroundColor Green
        Write-Host "La Phase 3D atteint un bon niveau de conformité" -ForegroundColor Green
        exit 0
    } elseif ($finalScore -ge 70) {
        Write-Host "⚠️ VALIDATION SDDD ACCEPTABLE" -ForegroundColor Yellow
        Write-Host "La Phase 3D atteint un niveau acceptable mais des améliorations sont possibles" -ForegroundColor Yellow
        exit 0
    } else {
        Write-Host "❌ VALIDATION SDDD INSUFFISANTE" -ForegroundColor Red
        Write-Host "La Phase 3D nécessite des améliorations significatives" -ForegroundColor Red
        exit 1
    }
    
} catch {
    Write-Host "❌ ERREUR CRITIQUE PENDANT LA VALIDATION SDDD" -ForegroundColor Red
    Write-Host "Erreur: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack Trace: $($_.ScriptStackTrace)" -ForegroundColor Red
    exit 2
}