<#
.SYNOPSIS
    Script PowerShell autonome pour exporter un rapport de diff granulaire RooSync
    Version: 1.0.0
    Date: 2025-11-10

.DESCRIPTION
    Ce script permet d'exporter un rapport de diff granulaire vers différents formats
    (JSON, CSV, HTML, Markdown) avec des options de filtrage et de personnalisation.

.PARAMETER ReportPath
    Chemin vers le fichier JSON du rapport de diff à exporter

.PARAMETER OutputPath
    Chemin vers le fichier de sortie

.PARAMETER Format
    Format d'export (json, csv, html, md)

.PARAMETER SeverityFilter
    Filtre par sévérité (critical, high, medium, low, info)

.PARAMETER TypeFilter
    Filtre par type de différence

.PARAMETER IncludeMetadata
    Inclure les métadonnées dans l'export

.PARAMETER GroupBy
    Grouper les différences par (severity, type, path)

.PARAMETER Template
    Modèle personnalisé pour l'export (chemin vers fichier template)

.EXAMPLE
    .\roosync_export_diff.ps1 -ReportPath "diff-report.json" -OutputPath "export.html" -Format "html"

.EXAMPLE
    .\roosync_export_diff.ps1 -ReportPath "diff-report.json" -OutputPath "export.csv" -Format "csv" -SeverityFilter "critical,high"

.NOTES
    Auteur: Roo AI Assistant
    Projet: RooSync v2.1 - Phase 3B SDDD
    Dépendances: Aucune (script autonome)
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$ReportPath,
    
    [Parameter(Mandatory=$true)]
    [string]$OutputPath,
    
    [Parameter(Mandatory=$true)]
    [ValidateSet("json", "csv", "html", "md")]
    [string]$Format,
    
    [Parameter(Mandatory=$false)]
    [string]$SeverityFilter,
    
    [Parameter(Mandatory=$false)]
    [string]$TypeFilter,
    
    [Parameter(Mandatory=$false)]
    [switch]$IncludeMetadata,
    
    [Parameter(Mandatory=$false)]
    [ValidateSet("severity", "type", "path")]
    [string]$GroupBy,
    
    [Parameter(Mandatory=$false)]
    [string]$Template
)

# Configuration
$ErrorActionPreference = "Stop"
$ProgressPreference = "Continue"

# Fonctions utilitaires
function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $color = switch ($Level) {
        "ERROR" { "Red" }
        "WARN" { "Yellow" }
        "SUCCESS" { "Green" }
        "INFO" { "White" }
        "DEBUG" { "Gray" }
        default { "White" }
    }
    
    Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $color
}

function Test-Prerequisites {
    Write-Log "Vérification des prérequis..."
    
    # Vérifier que le fichier de rapport existe
    if (-not (Test-Path $ReportPath)) {
        throw "Le fichier de rapport '$ReportPath' n'existe pas"
    }
    
    # Vérifier que le fichier est un JSON valide
    try {
        $null = Get-Content $ReportPath -Raw | ConvertFrom-Json
        Write-Log "Fichier de rapport JSON valide" "SUCCESS"
    }
    catch {
        throw "Le fichier de rapport '$ReportPath' n'est pas un JSON valide: $($_.Exception.Message)"
    }
    
    # Vérifier le template si spécifié
    if ($Template -and (-not (Test-Path $Template))) {
        throw "Le fichier de template '$Template' n'existe pas"
    }
    
    Write-Log "Prérequis vérifiés avec succès" "SUCCESS"
}

function Read-DiffReport {
    Write-Log "Lecture du rapport de diff..."
    
    try {
        $reportContent = Get-Content $ReportPath -Raw | ConvertFrom-Json
        Write-Log "Rapport lu avec succès" "SUCCESS"
        return $reportContent
    }
    catch {
        throw "Erreur lors de la lecture du rapport: $($_.Exception.Message)"
    }
}

function Filter-Differences {
    param(
        $Differences,
        [string]$SeverityFilter,
        [string]$TypeFilter
    )
    
    $filtered = $Differences
    
    if ($SeverityFilter) {
        $severities = $SeverityFilter -split ','
        $filtered = $filtered | Where-Object { $_.severity -in $severities }
    }
    
    if ($TypeFilter) {
        $types = $TypeFilter -split ','
        $filtered = $filtered | Where-Object { $_.type -in $types }
    }
    
    return $filtered
}

function Group-Differences {
    param(
        $Differences,
        [string]$GroupBy
    )
    
    if (-not $GroupBy) {
        return @{ "ungrouped" = $Differences }
    }
    
    $groups = @{}
    
    foreach ($diff in $Differences) {
        $key = switch ($GroupBy) {
            "severity" { $diff.severity }
            "type" { $diff.type }
            "path" { 
                # Extraire le premier niveau du chemin
                if ($diff.path -match '^([^/]+)') {
                    $matches[1]
                } else {
                    "root"
                }
            }
            default { "unknown" }
        }
        
        if (-not $groups.ContainsKey($key)) {
            $groups[$key] = @()
        }
        
        $groups[$key] += $diff
    }
    
    return $groups
}

function Export-Json {
    param(
        $Report,
        $FilteredDifferences,
        [string]$OutputPath
    )
    
    Write-Log "Export au format JSON..."
    
    $exportData = @{
        exportInfo = @{
            timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            format = "json"
            sourceReport = $Report.reportId
            filters = @{
                severity = $SeverityFilter
                type = $TypeFilter
                groupBy = $GroupBy
            }
        }
        summary = $Report.summary
        metadata = if ($IncludeMetadata) { $Report.metadata } else { $null }
        differences = $FilteredDifferences
    }
    
    if ($GroupBy) {
        $groups = Group-Differences -Differences $FilteredDifferences -GroupBy $GroupBy
        $exportData.groupedDifferences = $groups
    }
    
    $exportData | ConvertTo-Json -Depth 10 | Out-File -FilePath $OutputPath -Encoding UTF8
    Write-Log "Export JSON terminé: $OutputPath" "SUCCESS"
}

function Export-Csv {
    param(
        $Report,
        $FilteredDifferences,
        [string]$OutputPath
    )
    
    Write-Log "Export au format CSV..."
    
    $csvData = @()
    
    foreach ($diff in $FilteredDifferences) {
        $row = [PSCustomObject]@{
            Index = $FilteredDifferences.IndexOf($diff) + 1
            Severity = $diff.severity
            Type = $diff.type
            Path = $diff.path
            Description = $diff.description
            OldValue = if ($diff.oldValue -ne $null) { $diff.oldValue.ToString() } else { "" }
            NewValue = if ($diff.newValue -ne $null) { $diff.newValue.ToString() } else { "" }
            Metadata = if ($IncludeMetadata -and $diff.metadata) { ($diff.metadata | ConvertTo-Json -Compress) } else { "" }
        }
        
        $csvData += $row
    }
    
    $csvData | Export-Csv -Path $OutputPath -NoTypeInformation -Encoding UTF8
    Write-Log "Export CSV terminé: $OutputPath" "SUCCESS"
}

function Export-Html {
    param(
        $Report,
        $FilteredDifferences,
        [string]$OutputPath
    )
    
    Write-Log "Export au format HTML..."
    
    $htmlTemplate = if ($Template -and (Test-Path $Template)) {
        Get-Content $Template -Raw
    } else {
        Get-HtmlTemplate
    }
    
    # Remplacer les placeholders
    $htmlContent = $htmlTemplate -replace '\{\{REPORT_ID\}\}', $Report.reportId
    $htmlContent = $htmlContent -replace '\{\{TIMESTAMP\}\}', (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
    $htmlContent = $htmlContent -replace '\{\{SOURCE_LABEL\}\}', $Report.sourceLabel
    $htmlContent = $htmlContent -replace '\{\{TARGET_LABEL\}\}', $Report.targetLabel
    $htmlContent = $htmlContent -replace '\{\{TOTAL_DIFFERENCES\}\}', $FilteredDifferences.Count
    
    # Générer le tableau des différences
    $diffRows = ""
    foreach ($diff in $FilteredDifferences) {
        $severityClass = switch ($diff.severity) {
            "critical" { "danger" }
            "high" { "warning" }
            "medium" { "info" }
            "low" { "success" }
            "info" { "secondary" }
            default { "light" }
        }
        
        $oldValue = if ($diff.oldValue -ne $null) { [System.Web.HttpUtility]::HtmlEncode($diff.oldValue.ToString()) } else { "&nbsp;" }
        $newValue = if ($diff.newValue -ne $null) { [System.Web.HttpUtility]::HtmlEncode($diff.newValue.ToString()) } else { "&nbsp;" }
        
        $diffRows += @"
        <tr>
            <td><span class="badge badge-$severityClass">$($diff.severity)</span></td>
            <td>$($diff.type)</td>
            <td><code>$($diff.path)</code></td>
            <td>$($diff.description)</td>
            <td>$oldValue</td>
            <td>$newValue</td>
        </tr>
"@
    }
    
    $htmlContent = $htmlContent -replace '\{\{DIFF_ROWS\}\}', $diffRows
    
    # Ajouter les métadonnées si demandé
    if ($IncludeMetadata) {
        $metadataHtml = "<h3>Métadonnées</h3><pre>$($Report.metadata | ConvertTo-Json -Depth 10)</pre>"
        $htmlContent = $htmlContent -replace '\{\{METADATA_SECTION\}\}', $metadataHtml
    } else {
        $htmlContent = $htmlContent -replace '\{\{METADATA_SECTION\}\}', ""
    }
    
    $htmlContent | Out-File -FilePath $OutputPath -Encoding UTF8
    Write-Log "Export HTML terminé: $OutputPath" "SUCCESS"
}

function Export-Markdown {
    param(
        $Report,
        $FilteredDifferences,
        [string]$OutputPath
    )
    
    Write-Log "Export au format Markdown..."
    
    $mdContent = @"
# Rapport de Diff Granulaire

**ID du rapport:** $($Report.reportId)  
**Source:** $($Report.sourceLabel)  
**Cible:** $($Report.targetLabel)  
**Date:** $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")  
**Total différences:** $($FilteredDifferences.Count)

## Résumé

| Sévérité | Nombre |
|----------|--------|
"@
    
    # Ajouter le résumé par sévérité
    foreach ($severity in @("critical", "high", "medium", "low", "info")) {
        $count = ($FilteredDifferences | Where-Object { $_.severity -eq $severity }).Count
        if ($count -gt 0) {
            $mdContent += "| $severity | $count |`n"
        }
    }
    
    $mdContent += @"

## Différences

| # | Sévérité | Type | Chemin | Description | Ancienne valeur | Nouvelle valeur |
|---|-----------|------|--------|-------------|-----------------|----------------|
"@
    
    # Ajouter les différences
    foreach ($diff in $FilteredDifferences) {
        $index = $FilteredDifferences.IndexOf($diff) + 1
        $oldValue = if ($diff.oldValue -ne $null) { $diff.oldValue.ToString().Replace("`n", " ").Replace("|", "\|") } else { "" }
        $newValue = if ($diff.newValue -ne $null) { $diff.newValue.ToString().Replace("`n", " ").Replace("|", "\|") } else { "" }
        
        $mdContent += "| $index | $($diff.severity) | $($diff.type) | `$($diff.path)` | $($diff.description) | $oldValue | $newValue |`n"
    }
    
    # Ajouter les métadonnées si demandé
    if ($IncludeMetadata) {
        $mdContent += @"

## Métadonnées

````json
$($Report.metadata | ConvertTo-Json -Depth 10)
````
"@
    }
    
    $mdContent | Out-File -FilePath $OutputPath -Encoding UTF8
    Write-Log "Export Markdown terminé: $OutputPath" "SUCCESS"
}

function Get-HtmlTemplate {
    return @"
<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Rapport de Diff Granulaire - {{REPORT_ID}}</title>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.1.3/dist/css/bootstrap.min.css" rel="stylesheet">
    <style>
        .diff-table { font-size: 0.9em; }
        .diff-table code { background-color: #f8f9fa; padding: 2px 4px; border-radius: 3px; }
        .old-value { background-color: #f8d7da; }
        .new-value { background-color: #d4edda; }
    </style>
</head>
<body>
    <div class="container-fluid py-4">
        <div class="row">
            <div class="col-12">
                <h1 class="mb-4">Rapport de Diff Granulaire</h1>
                
                <div class="card mb-4">
                    <div class="card-header">
                        <h3 class="card-title mb-0">Informations</h3>
                    </div>
                    <div class="card-body">
                        <div class="row">
                            <div class="col-md-6">
                                <p><strong>ID du rapport:</strong> {{REPORT_ID}}</p>
                                <p><strong>Source:</strong> {{SOURCE_LABEL}}</p>
                                <p><strong>Cible:</strong> {{TARGET_LABEL}}</p>
                            </div>
                            <div class="col-md-6">
                                <p><strong>Date:</strong> {{TIMESTAMP}}</p>
                                <p><strong>Total différences:</strong> {{TOTAL_DIFFERENCES}}</p>
                            </div>
                        </div>
                    </div>
                </div>
                
                <div class="card">
                    <div class="card-header">
                        <h3 class="card-title mb-0">Différences</h3>
                    </div>
                    <div class="card-body">
                        <div class="table-responsive">
                            <table class="table table-striped diff-table">
                                <thead>
                                    <tr>
                                        <th>Sévérité</th>
                                        <th>Type</th>
                                        <th>Chemin</th>
                                        <th>Description</th>
                                        <th>Ancienne valeur</th>
                                        <th>Nouvelle valeur</th>
                                    </tr>
                                </thead>
                                <tbody>
                                    {{DIFF_ROWS}}
                                </tbody>
                            </table>
                        </div>
                    </div>
                </div>
                
                {{METADATA_SECTION}}
            </div>
        </div>
    </div>
    
    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.1.3/dist/js/bootstrap.bundle.min.js"></script>
</body>
</html>
"@
}

# Programme principal
try {
    Write-Log "=== SCRIPT D'EXPORT DE DIFF GRANULAIRE ROOSYNC ===" "INFO"
    Write-Log "Version: 1.0.0" "INFO"
    Write-Log "Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" "INFO"
    
    # Étape 1: Vérification des prérequis
    Test-Prerequisites
    
    # Étape 2: Lecture du rapport
    $report = Read-DiffReport
    
    # Étape 3: Filtrage des différences
    $filteredDifferences = Filter-Differences -Differences $report.diffs -SeverityFilter $SeverityFilter -TypeFilter $TypeFilter
    Write-Log "Différences après filtrage: $($filteredDifferences.Count) / $($report.diffs.Count)" "INFO"
    
    if ($filteredDifferences.Count -eq 0) {
        Write-Log "Aucune différence à exporter après filtrage" "WARN"
        exit 0
    }
    
    # Étape 4: Export selon le format demandé
    switch ($Format.ToLower()) {
        "json" {
            Export-Json -Report $report -FilteredDifferences $filteredDifferences -OutputPath $OutputPath
        }
        "csv" {
            Export-Csv -Report $report -FilteredDifferences $filteredDifferences -OutputPath $OutputPath
        }
        "html" {
            Export-Html -Report $report -FilteredDifferences $filteredDifferences -OutputPath $OutputPath
        }
        "md" {
            Export-Markdown -Report $report -FilteredDifferences $filteredDifferences -OutputPath $OutputPath
        }
        default {
            throw "Format d'export non supporté: $Format"
        }
    }
    
    Write-Log "Export de diff granulaire terminé avec succès" "SUCCESS"
    Write-Log "Fichier exporté: $OutputPath" "SUCCESS"
    
}
catch {
    Write-Log "Erreur lors de l'export: $($_.Exception.Message)" "ERROR"
    Write-Log "Stack trace: $($_.ScriptStackTrace)" "ERROR"
    exit 1
}