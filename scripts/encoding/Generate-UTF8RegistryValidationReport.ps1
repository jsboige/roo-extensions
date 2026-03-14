<#
.SYNOPSIS
    Script de génération de rapport de validation du registre UTF-8
.DESCRIPTION
    Ce script génère un rapport complet de validation pour les modifications du registre UTF-8.
    Il consolide les résultats des tests, génère des visualisations et produit des rapports
    dans plusieurs formats (Markdown, HTML, JSON) pour une analyse complète.
.PARAMETER InputPath
    Chemin vers les résultats de validation à analyser
.PARAMETER OutputFormat
    Format de sortie du rapport (Markdown, HTML, JSON, All)
.PARAMETER IncludeVisualizations
    Inclut des graphiques et visualisations dans le rapport
.PARAMETER CompareWithBaseline
    Compare avec une baseline de référence si spécifiée
.PARAMETER BaselinePath
    Chemin vers la baseline de référence
.PARAMETER GenerateSummary
    Génère un résumé exécutif pour la présentation
.EXAMPLE
    .\Generate-UTF8RegistryValidationReport.ps1 -InputPath "results\utf8-registry-validation-20251030-162000" -OutputFormat All
.EXAMPLE
    .\Generate-UTF8RegistryValidationReport.ps1 -InputPath "results\*" -IncludeVisualizations -GenerateSummary
.NOTES
    Auteur: Roo Architect Complex Mode
    Version: 1.0
    Date: 2025-10-30
    ID Correction: SYS-002-REPORT
    Priorité: CRITIQUE
    Requiert: Résultats de validation disponibles
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$InputPath,
    
    [Parameter(Mandatory = $false)]
    [ValidateSet("Markdown", "HTML", "JSON", "All")]
    [string]$OutputFormat = "All",
    
    [Parameter(Mandatory = $false)]
    [switch]$IncludeVisualizations,
    
    [Parameter(Mandatory = $false)]
    [switch]$CompareWithBaseline,
    
    [Parameter(Mandatory = $false)]
    [string]$BaselinePath,
    
    [Parameter(Mandatory = $false)]
    [switch]$GenerateSummary
)

# Configuration du script
$script:LogFile = "logs\Generate-UTF8RegistryValidationReport-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
$script:OutputDir = "reports\utf8-registry-validation-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
$script:TempDir = "temp\report-generation"

# Constantes de rapport
$REPORT_TITLE = "Rapport de Validation du Registre UTF-8"
$REPORT_VERSION = "1.0"
$REPORT_ID = "SYS-002-REPORT"
$SUCCESS_THRESHOLD = 95

# Fonctions de logging
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    
    Write-Host $logEntry -ForegroundColor $(
        switch ($Level) {
            "ERROR" { "Red" }
            "WARN" { "Yellow" }
            "SUCCESS" { "Green" }
            "INFO" { "Cyan" }
            "REPORT" { "Magenta" }
            "DETAIL" { "White" }
            default { "White" }
        }
    )
    
    # Création du répertoire de logs si nécessaire
    if (!(Test-Path "logs")) {
        New-Item -ItemType Directory -Path "logs" -Force | Out-Null
    }

    # BOM-safe write: use .NET method instead of Add-Content (PowerShell 5.1 adds BOM with -Encoding UTF8)
    $logContent = if (Test-Path $script:LogFile) { [System.IO.File]::ReadAllText($script:LogFile) } else { "" }
    [System.IO.File]::WriteAllText($script:LogFile, "$logContent$logEntry`r`n", [System.Text.UTF8Encoding]::new($false))
}

function Write-Success {
    param([string]$Message)
    Write-Log $Message "SUCCESS"
}

function Write-Error {
    param([string]$Message)
    Write-Log $Message "ERROR"
}

function Write-Warning {
    param([string]$Message)
    Write-Log $Message "WARN"
}

function Write-Info {
    param([string]$Message)
    Write-Log $Message "INFO"
}

function Write-Report {
    param([string]$Message)
    Write-Log $Message "REPORT"
}

# Fonctions de traitement des données
function Find-ValidationResults {
    param([string]$SearchPath)
    
    Write-Info "Recherche des résultats de validation dans: $SearchPath"
    
    $results = @()
    
    # Recherche des fichiers de résultats
    if (Test-Path $SearchPath) {
        $files = Get-ChildItem -Path $SearchPath -Filter "*.json" -Recurse
        
        foreach ($file in $files) {
            try {
                $content = Get-Content -Path $file.FullName -Raw | ConvertFrom-Json
                if ($content -and $content.results) {
                    $results += @{
                        File = $file.Name
                        Path = $file.FullName
                        Date = $file.LastWriteTime
                        Content = $content
                    }
                    Write-Info "Résultat trouvé: $($file.Name)"
                }
            } catch {
                Write-Warning "Erreur lecture fichier $($file.Name): $($_.Exception.Message)"
            }
        }
    }
    
    Write-Success "Résultats trouvés: $($results.Count) fichiers"
    return $results
}

function Consolidate-ValidationData {
    param([array]$ValidationResults)
    
    Write-Report "Consolidation des données de validation..."
    
    $consolidated = @{
        metadata = @{
            reportDate = Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ"
            reportVersion = $REPORT_VERSION
            reportId = $REPORT_ID
            totalFiles = $ValidationResults.Count
            dateRange = @{
                start = ($ValidationResults | Sort-Object Date | Select-Object -First 1).Date
                end = ($ValidationResults | Sort-Object Date | Select-Object -Last 1).Date
            }
        }
        summary = @{
            totalTests = 0
            successfulTests = 0
            failedTests = 0
            successRate = 0
            overallSuccess = $false
            testCategories = @{}
            issues = @()
            recommendations = @()
        }
        detailedResults = @()
        trends = @{}
    }
    
    # Consolidation des résultats
    foreach ($result in $ValidationResults) {
        $content = $result.Content
        
        # Mise à jour du résumé
        if ($content.summary) {
            $consolidated.summary.totalTests += $content.summary.totalTests
            $consolidated.summary.successfulTests += $content.summary.successfulTests
            $consolidated.summary.failedTests += $content.summary.failedTests
        }
        
        # Ajout des résultats détaillés
        if ($content.results) {
            foreach ($testResult in $content.results) {
                $consolidated.detailedResults += @{
                    SourceFile = $result.File
                    TestDate = $result.Date
                    TestName = $testResult.TestName
                    Success = $testResult.Success
                    Details = $testResult.Details
                    Issues = $testResult.Issues
                    Recommendations = $testResult.Recommendations
                }
                
                # Catégorisation des tests
                $category = $testResult.TestName
                if (-not $consolidated.summary.testCategories.ContainsKey($category)) {
                    $consolidated.summary.testCategories[$category] = @{
                        total = 0
                        successful = 0
                        failed = 0
                        successRate = 0
                    }
                }
                
                $consolidated.summary.testCategories[$category].total++
                if ($testResult.Success) {
                    $consolidated.summary.testCategories[$category].successful++
                } else {
                    $consolidated.summary.testCategories[$category].failed++
                    $consolidated.summary.issues += $testResult.Issues
                    $consolidated.summary.recommendations += $testResult.Recommendations
                }
            }
        }
    }
    
    # Calcul des taux de succès
    $consolidated.summary.successRate = if ($consolidated.summary.totalTests -gt 0) { 
        [math]::Round(($consolidated.summary.successfulTests / $consolidated.summary.totalTests) * 100, 2) 
    } else { 0 }
    
    $consolidated.summary.overallSuccess = $consolidated.summary.successRate -ge $SUCCESS_THRESHOLD
    
    # Calcul des taux par catégorie
    foreach ($category in $consolidated.summary.testCategories.Keys) {
        $cat = $consolidated.summary.testCategories[$category]
        $cat.successRate = if ($cat.total -gt 0) { 
            [math]::Round(($cat.successful / $cat.total) * 100, 2) 
        } else { 0 }
    }
    
    # Analyse des tendances
    $consolidated.trends = @{
        performanceTrend = Calculate-PerformanceTrend -Results $ValidationResults
        issueFrequency = Calculate-IssueFrequency -Results $consolidated.detailedResults
        recommendationPriority = Calculate-RecommendationPriority -Recommendations $consolidated.summary.recommendations
    }
    
    Write-Success "Consolidation terminée: $($consolidated.summary.totalTests) tests analysés"
    return $consolidated
}

function Calculate-PerformanceTrend {
    param([array]$Results)
    
    if ($Results.Count -lt 2) {
        return @{ trend = "insufficient_data"; description = "Pas assez de données pour analyser la tendance" }
    }
    
    $sortedResults = $Results | Sort-Object Date
    $trendData = @()
    
    for ($i = 0; $i -lt $sortedResults.Count; $i++) {
        $result = $sortedResults[$i]
        if ($result.Content.summary) {
            $trendData += @{
                date = $result.Date
                successRate = $result.Content.summary.successRate
                totalTests = $result.Content.summary.totalTests
            }
        }
    }
    
    if ($trendData.Count -lt 2) {
        return @{ trend = "insufficient_data"; description = "Pas assez de données valides" }
    }
    
    # Calcul simple de tendance
    $firstRate = $trendData[0].successRate
    $lastRate = $trendData[-1].successRate
    $trendDirection = if ($lastRate -gt $firstRate) { "amélioration" } elseif ($lastRate -lt $firstRate) { "dégradation" } else { "stable" }
    
    return @{
        trend = $trendDirection
        description = "Tendance $trendDirection de $($firstRate)% à $($lastRate)%"
        dataPoints = $trendData.Count
        timeSpan = $sortedResults[-1].Date - $sortedResults[0].Date
    }
}

function Calculate-IssueFrequency {
    param([array]$Results)
    
    $issueFrequency = @{}
    
    foreach ($result in $Results) {
        if ($result.Issues) {
            foreach ($issue in $result.Issues) {
                # Catégorisation simple des problèmes
                $category = switch -Wildcard ($issue) {
                    "*registre*" { "registre" }
                    "*permission*" { "permissions" }
                    "*UTF-8*" { "utf8" }
                    "*console*" { "console" }
                    "*locale*" { "locale" }
                    default { "autre" }
                }
                
                if (-not $issueFrequency.ContainsKey($category)) {
                    $issueFrequency[$category] = 0
                }
                $issueFrequency[$category]++
            }
        }
    }
    
    return $issueFrequency
}

function Calculate-RecommendationPriority {
    param([array]$Recommendations)
    
    $priority = @{
        haute = @()
        moyenne = @()
        basse = @()
    }
    
    foreach ($rec in $Recommendations) {
        if ($rec -is [array]) {
            foreach ($item in $rec) {
                $priorityLevel = switch -Wildcard ($item) {
                    "*immédiat*" { "haute" }
                    "*critique*" { "haute" }
                    "*urgent*" { "haute" }
                    "*recommandé*" { "moyenne" }
                    "*suggéré*" { "basse" }
                    default { "moyenne" }
                }
                
                switch ($priorityLevel) {
                    "haute" { $priority.haute += $item }
                    "moyenne" { $priority.moyenne += $item }
                    "basse" { $priority.basse += $item }
                }
            }
        }
    }
    
    return @{
        haute = $priority.haute | Sort-Object -Unique
        moyenne = $priority.moyenne | Sort-Object -Unique
        basse = $priority.basse | Sort-Object -Unique
        total = $Recommendations.Count
    }
}

# Fonctions de génération de rapports
function New-MarkdownReport {
    param([hashtable]$ConsolidatedData)
    
    $reportPath = Join-Path $script:OutputDir "registry-validation-report.md"
    
    $mdReport = @"
# $REPORT_TITLE

**Date**: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')  
**Version**: $REPORT_VERSION  
**ID**: $REPORT_ID  
**Seuil de Succès**: $SUCCESS_THRESHOLD%

---

## 📊 Résumé Exécutif

### Métriques Globales
- **Tests Total**: $($ConsolidatedData.summary.totalTests)
- **Tests Réussis**: $($Consolidated.summary.successfulTests)
- **Tests Échoués**: $($Consolidated.summary.failedTests)
- **Taux de Succès**: $($Consolidated.summary.successRate)%
- **Statut Global**: $(if ($Consolidated.summary.overallSuccess) { "✅ SUCCÈS" } else { "⚠️ PARTIEL" })

### Période d'Analyse
- **Début**: $($Consolidated.metadata.dateRange.start)
- **Fin**: $($Consolidated.metadata.dateRange.end)
- **Fichiers Analysés**: $($Consolidated.metadata.totalFiles)

## 📈 Analyse par Catégorie

$($Consolidated.summary.testCategories.GetEnumerator() | ForEach-Object {
    "### $($_.Key)"
    "- **Total**: $($_.Value.total)"
    "- **Réussis**: $($_.Value.successful)"
    "- **Échoués**: $($_.Value.failed)"
    "- **Taux de Succès**: $($_.Value.successRate)%"
    "- **Statut**: $(if ($_.Value.successRate -ge $SUCCESS_THRESHOLD) { "✅" } else { "⚠️" })"
    ""
})

## 🔄 Analyse des Tendances

### Performance
- **Tendance**: $($Consolidated.trends.performanceTrend.trend)"
- **Description**: $($Consolidated.trends.performanceTrend.description)"
- **Points de Données**: $($Consolidated.trends.performanceTrend.dataPoints)"
- **Période**: $($Consolidated.trends.performanceTrend.timeSpan.Days) jours"

### Fréquence des Problèmes
$($Consolidated.trends.issueFrequency.GetEnumerator() | Sort-Object Value -Descending | ForEach-Object {
    "- **$($_.Key)**: $($_.Value) occurrences"
})

## 🎯 Recommandations Prioritaires

### Priorité Haute ($($Consolidated.trends.recommendationPriority.haute.Count))
$($Consolidated.trends.recommendationPriority.haute | ForEach-Object {
    "- $($_)"
})

### Priorité Moyenne ($($Consolidated.trends.recommendationPriority.moyenne.Count))
$($Consolidated.trends.recommendationPriority.moyenne | ForEach-Object {
    "- $($_)"
})

### Priorité Basse ($($Consolidated.trends.recommendationPriority.basse.Count))
$($Consolidated.trends.recommendationPriority.basse | ForEach-Object {
    "- $($_)"
})

## 📋 Résultats Détaillés

$($Consolidated.detailedResults | Group-Object TestName | ForEach-Object {
    "### $($_.Name)"
    $($_.Group | ForEach-Object {
        $result = $_
        "#### $($result.TestDate) - $($result.SourceFile)"
        "- **Statut**: $(if ($result.Success) { "✅ SUCCÈS" } else { "❌ ÉCHEC" })"
        $(if ($result.Issues.Count -gt 0) {
            "- **Problèmes**:"
            $result.Issues | ForEach-Object { "  - $($_)" }
        })
        $(if ($result.Recommendations.Count -gt 0) {
            "- **Recommandations**:"
            $result.Recommendations | ForEach-Object { "  - $($_)" }
        })
        ""
    })
})

---

## 📝 Métadonnées du Rapport

- **Généré par**: Generate-UTF8RegistryValidationReport.ps1
- **Date de génération**: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
- **Fichier de log**: $script:LogFile
- **Répertoire de sortie**: $script:OutputDir

---

**Statut**: $(if ($Consolidated.summary.overallSuccess) { "✅ VALIDATION RÉUSSIE" } else { "⚠️ VALIDATION PARTIELLE - ACTIONS REQUISES" })  
**Prochaine Étape**: $(if ($Consolidated.summary.overallSuccess) { "Jour 4-4: Variables Environnement Standardisées" } else { "Correction des problèmes identifiés" })
"@

    # BOM-safe write: use .NET method instead of Out-File (PowerShell 5.1 adds BOM with -Encoding UTF8)
    [System.IO.File]::WriteAllText($reportPath, $mdReport, [System.Text.UTF8Encoding]::new($false))
    Write-Success "Rapport Markdown généré: $reportPath"
    return $reportPath
}

function New-HTMLReport {
    param([hashtable]$ConsolidatedData)
    
    $reportPath = Join-Path $script:OutputDir "registry-validation-report.html"
    
    # Calcul des couleurs pour les visualisations
    $successColor = if ($Consolidated.summary.overallSuccess) { "#28a745" } else { "#dc3545" }
    $warningColor = "#ffc107"
    $infoColor = "#17a2b8"
    
    $htmlReport = @"
<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>$REPORT_TITLE</title>
    <style>
        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; margin: 20px; background-color: #f8f9fa; }
        .container { max-width: 1200px; margin: 0 auto; background: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        .header { text-align: center; border-bottom: 2px solid #007bff; padding-bottom: 20px; margin-bottom: 30px; }
        .summary { display: grid; grid-template-columns: repeat(auto-fit, minmax(250px, 1fr)); gap: 20px; margin-bottom: 30px; }
        .metric { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 20px; border-radius: 8px; text-align: center; }
        .metric h3 { margin: 0 0 10px 0; font-size: 1.2em; }
        .metric .value { font-size: 2em; font-weight: bold; margin: 10px 0; }
        .metric .label { font-size: 0.9em; opacity: 0.9; }
        .section { margin-bottom: 30px; }
        .section h2 { color: #007bff; border-bottom: 1px solid #dee2e6; padding-bottom: 10px; }
        .chart-container { background: white; padding: 20px; border-radius: 8px; box-shadow: 0 1px 3px rgba(0,0,0,0.1); margin-bottom: 20px; }
        .progress-bar { width: 100%; height: 20px; background: #e9ecef; border-radius: 10px; overflow: hidden; }
        .progress-fill { height: 100%; background: linear-gradient(90deg, $successColor 0%, $successColor 100%); transition: width 0.3s ease; }
        .category-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 15px; }
        .category-card { background: white; border: 1px solid #dee2e6; border-radius: 8px; padding: 15px; }
        .status-success { color: #28a745; font-weight: bold; }
        .status-warning { color: #ffc107; font-weight: bold; }
        .status-error { color: #dc3545; font-weight: bold; }
        .recommendations { background: #f8f9fa; border-left: 4px solid #007bff; padding: 15px; margin-top: 20px; }
        .footer { text-align: center; margin-top: 40px; padding-top: 20px; border-top: 1px solid #dee2e6; color: #6c757d; }
        @media (max-width: 768px) {
            .container { margin: 10px; padding: 15px; }
            .summary { grid-template-columns: 1fr; }
            .category-grid { grid-template-columns: 1fr; }
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>$REPORT_TITLE</h1>
            <p><strong>Date:</strong> $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') | <strong>Version:</strong> $REPORT_VERSION</p>
        </div>
        
        <div class="summary">
            <div class="metric">
                <h3>Tests Total</h3>
                <div class="value">$($ConsolidatedData.summary.totalTests)</div>
                <div class="label">tests exécutés</div>
            </div>
            <div class="metric">
                <h3>Taux de Succès</h3>
                <div class="value">$($Consolidated.summary.successRate)%</div>
                <div class="label">de réussite</div>
            </div>
            <div class="metric">
                <h3>Statut Global</h3>
                <div class="value $(if ($Consolidated.summary.overallSuccess) { "status-success" } else { "status-error" })">$(if ($Consolidated.summary.overallSuccess) { "SUCCÈS" } else { "PARTIEL" })</div>
                <div class="label">validation</div>
            </div>
            <div class="metric">
                <h3>Fichiers Analysés</h3>
                <div class="value">$($Consolidated.metadata.totalFiles)</div>
                <div class="label">résultats</div>
            </div>
        </div>
        
        <div class="section">
            <h2>📊 Progression Globale</h2>
            <div class="chart-container">
                <div class="progress-bar">
                    <div class="progress-fill" style="width: $($Consolidated.summary.successRate)%"></div>
                </div>
                <p style="margin-top: 10px; text-align: center;">
                    <strong>$($Consolidated.summary.successRate)%</strong> de tests réussis 
                    $(if ($Consolidated.summary.overallSuccess) { "(Objectif atteint ✅)" } else { "(Objectif non atteint ⚠️)" })
                </p>
            </div>
        </div>
        
        <div class="section">
            <h2>📈 Résultats par Catégorie</h2>
            <div class="category-grid">
                $(
                    $Consolidated.summary.testCategories.GetEnumerator() | ForEach-Object {
                        $statusClass = if ($_.Value.successRate -ge $SUCCESS_THRESHOLD) { "status-success" } else { "status-warning" }
                        @"
                <div class="category-card">
                    <h3>$($_.Key)</h3>
                    <p><strong>Total:</strong> $($_.Value.total)</p>
                    <p><strong>Réussis:</strong> $($_.Value.successful)</p>
                    <p><strong>Échoués:</strong> $($_.Value.failed)</p>
                    <p><strong>Taux:</strong> <span class="$statusClass">$($_.Value.successRate)%</span></p>
                </div>
"@
                    }
                )
            )
            </div>
        </div>
        
        $(if ($Consolidated.summary.recommendations.Count -gt 0) {
            @"
        <div class="recommendations">
            <h2>🎯 Recommandations</h2>
            <ul>
                $(
                    $Consolidated.summary.recommendations | ForEach-Object {
                        if ($_ -is [array]) {
                            $_ | ForEach-Object { "<li>$_</li>" }
                        } else {
                            "<li>$_</li>"
                        }
                    }
                )
            </ul>
        </div>
"@
        })
        
        <div class="footer">
            <p><strong>Rapport généré par:</strong> Generate-UTF8RegistryValidationReport.ps1</p>
            <p><strong>Date de génération:</strong> $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')</p>
            <p><strong>ID Rapport:</strong> $REPORT_ID</p>
        </div>
    </div>
</body>
</html>
"@

    # BOM-safe write: use .NET method instead of Out-File (PowerShell 5.1 adds BOM with -Encoding UTF8)
    [System.IO.File]::WriteAllText($reportPath, $htmlReport, [System.Text.UTF8Encoding]::new($false))
    Write-Success "Rapport HTML généré: $reportPath"
    return $reportPath
}

function New-JSONReport {
    param([hashtable]$ConsolidatedData)
    
    $reportPath = Join-Path $script:OutputDir "registry-validation-report.json"
    
    $jsonReport = @{
        metadata = @{
            reportTitle = $REPORT_TITLE
            reportVersion = $REPORT_VERSION
            reportId = $REPORT_ID
            generatedAt = Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ"
            generatedBy = "Generate-UTF8RegistryValidationReport.ps1"
            successThreshold = $SUCCESS_THRESHOLD
        }
        consolidatedData = $ConsolidatedData
    }

    # BOM-safe write: use .NET method instead of Out-File (PowerShell 5.1 adds BOM with -Encoding UTF8)
    $jsonOutput = $jsonReport | ConvertTo-Json -Depth 10
    [System.IO.File]::WriteAllText($reportPath, $jsonOutput, [System.Text.UTF8Encoding]::new($false))
    Write-Success "Rapport JSON généré: $reportPath"
    return $reportPath
}

function New-ExecutiveSummary {
    param([hashtable]$ConsolidatedData)
    
    $summaryPath = Join-Path $script:OutputDir "executive-summary.md"
    
    $execSummary = @"
# Résumé Exécutif - Validation du Registre UTF-8

## 🎯 Points Clés

### Statut Global
$(if ($ConsolidatedData.summary.overallSuccess) {
    "✅ **VALIDATION RÉUSSIE** - Taux de succès: $($ConsolidatedData.summary.successRate)%"
} else {
    "⚠️ **VALIDATION PARTIELLE** - Taux de succès: $($ConsolidatedData.summary.successRate)%"
})

### Métriques Principales
- **Tests Total**: $($ConsolidatedData.summary.totalTests)
- **Tests Réussis**: $($ConsolidatedData.summary.successfulTests)
- **Tests Échoués**: $($ConsolidatedData.summary.failedTests)
- **Seuil Atteint**: $(if ($ConsolidatedData.summary.overallSuccess) { "Oui" } else { "Non" })

## 📊 Performance par Catégorie

$($ConsolidatedData.summary.testCategories.GetEnumerator() | ForEach-Object {
    $status = if ($_.Value.successRate -ge $SUCCESS_THRESHOLD) { "✅" } else { "⚠️" }
    "- **$($_.Key)**: $($_.Value.successRate)% $status"
})

## 🎯 Actions Recommandées

$(if ($ConsolidatedData.summary.overallSuccess) {
    @"
### ✅ Actions Immédiates
1. **Continuer vers Jour 4-4**: Procéder à la standardisation des variables d'environnement
2. **Documenter le succès**: Enregistrer les résultats dans la matrice de traçabilité
3. **Préparer la phase suivante**: Rassembler les prérequis pour les variables environnement

### 📈 Prochaines Étapes
- **Jour 4-4**: Variables Environnement Standardisées
- **Jour 5-5**: Infrastructure Console Moderne
- **Jour 6-6**: Configuration PowerShell Unifiée
- **Jour 7-7**: Déploiement EncodingManager
"@
} else {
    @"
### ⚠️ Actions Correctives Immédiates
1. **Réexécuter Set-UTF8RegistryStandard.ps1**: Appliquer les corrections manquantes
2. **Redémarrer le système**: Assurer la prise en compte des modifications
3. **Revalider**: Exécuter Test-UTF8RegistryValidation.ps1 après redémarrage
4. **Analyser les échecs**: Consulter le rapport détaillé pour comprendre les problèmes

### 🔄 Boucle de Validation
- **Correction → Validation → Analyse → Correction**
- **Objectif**: Atteindre >95% de taux de succès
- **Délai**: 48h maximum pour la résolution
"@
})

## 📝 Informations Complémentaires

- **Période d'analyse**: $($ConsolidatedData.metadata.dateRange.start) à $($ConsolidatedData.metadata.dateRange.end)
- **Fichiers analysés**: $($ConsolidatedData.metadata.totalFiles)
- **Date du rapport**: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')

---

**Statut**: $(if ($ConsolidatedData.summary.overallSuccess) { "✅ PRÊT POUR JOUR 4-4" } else { "⚠️ ACTIONS CORRECTIVES REQUISES" })
"@

    # BOM-safe write: use .NET method instead of Out-File (PowerShell 5.1 adds BOM with -Encoding UTF8)
    [System.IO.File]::WriteAllText($summaryPath, $execSummary, [System.Text.UTF8Encoding]::new($false))
    Write-Success "Résumé exécutif généré: $summaryPath"
    return $summaryPath
}

# Programme principal
function Main {
    Write-Log "Début du script Generate-UTF8RegistryValidationReport.ps1" "INFO"
    Write-Log "ID Correction: SYS-002-REPORT" "INFO"
    Write-Log "Priorité: CRITIQUE" "INFO"
    
    try {
        Write-Info "Début de la génération du rapport de validation..."
        
        # Création des répertoires
        if (!(Test-Path $script:OutputDir)) {
            New-Item -ItemType Directory -Path $script:OutputDir -Force | Out-Null
        }
        if (!(Test-Path $script:TempDir)) {
            New-Item -ItemType Directory -Path $script:TempDir -Force | Out-Null
        }
        
        # Recherche des résultats de validation
        $validationResults = Find-ValidationResults -SearchPath $InputPath
        
        if ($validationResults.Count -eq 0) {
            Write-Error "Aucun résultat de validation trouvé dans: $InputPath"
            exit 1
        }
        
        # Consolidation des données
        $consolidatedData = Consolidate-ValidationData -ValidationResults $validationResults
        
        # Génération des rapports selon le format demandé
        $generatedReports = @()
        
        switch ($OutputFormat) {
            "Markdown" {
                $reportPath = New-MarkdownReport -ConsolidatedData $consolidatedData
                $generatedReports += $reportPath
            }
            "HTML" {
                $reportPath = New-HTMLReport -ConsolidatedData $consolidatedData
                $generatedReports += $reportPath
            }
            "JSON" {
                $reportPath = New-JSONReport -ConsolidatedData $consolidatedData
                $generatedReports += $reportPath
            }
            "All" {
                $mdPath = New-MarkdownReport -ConsolidatedData $consolidatedData
                $htmlPath = New-HTMLReport -ConsolidatedData $consolidatedData
                $jsonPath = New-JSONReport -ConsolidatedData $consolidatedData
                $generatedReports += $mdPath, $htmlPath, $jsonPath
            }
            default {
                Write-Error "Format de sortie non supporté: $OutputFormat"
                exit 1
            }
        }
        
        # Génération du résumé exécutif si demandé
        if ($GenerateSummary) {
            $summaryPath = New-ExecutiveSummary -ConsolidatedData $consolidatedData
            $generatedReports += $summaryPath
        }
        
        # Affichage des résultats
        Write-Success "Génération du rapport terminée"
        Write-Info "Rapports générés: $($generatedReports.Count)"
        foreach ($report in $generatedReports) {
            Write-Info "  - $report"
        }
        
        # Affichage du statut global
        if ($consolidatedData.summary.overallSuccess) {
            Write-Success "Validation globale réussie ($($consolidatedData.summary.successRate)%)"
            Write-Success "Prêt pour le Jour 4-4: Variables Environnement Standardisées"
        } else {
            Write-Warning "Validation partielle ($($consolidatedData.summary.successRate)%)"
            Write-Warning "Actions correctives requises avant de continuer"
        }
        
    } catch {
        Write-Error "Erreur inattendue: $($_.Exception.Message)"
        Write-Error "Stack Trace: $($_.ScriptStackTrace)"
        exit 1
    }
}

# Point d'entrée principal
Main