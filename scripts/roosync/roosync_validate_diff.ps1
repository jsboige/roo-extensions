<#
.SYNOPSIS
    Script PowerShell autonome pour valider un rapport de diff granulaire RooSync
    Version: 1.0.0
    Date: 2025-11-10

.DESCRIPTION
    Ce script permet de valider un rapport de diff granulaire généré par roosync_granular_diff.ps1.
    Il offre une interface interactive pour examiner, filtrer et valider les différences détectées.

.PARAMETER ReportPath
    Chemin vers le fichier JSON du rapport de diff à valider

.PARAMETER OutputPath
    Chemin vers le fichier de sortie pour le rapport de validation (optionnel)

.PARAMETER SeverityFilter
    Filtre par sévérité (critical, high, medium, low, info)

.PARAMETER TypeFilter
    Filtre par type de différence

.PARAMETER Interactive
    Mode interactif pour validation manuelle

.PARAMETER AutoApprove
    Approuver automatiquement les différences non critiques

.EXAMPLE
    .\roosync_validate_diff.ps1 -ReportPath "diff-report.json" -Interactive

.EXAMPLE
    .\roosync_validate_diff.ps1 -ReportPath "diff-report.json" -SeverityFilter "critical,high" -OutputPath "validation-report.json"

.NOTES
    Auteur: Roo AI Assistant
    Projet: RooSync v2.1 - Phase 3B SDDD
    Dépendances: Aucune (script autonome)
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$ReportPath,
    
    [Parameter(Mandatory=$false)]
    [string]$OutputPath,
    
    [Parameter(Mandatory=$false)]
    [string]$SeverityFilter,
    
    [Parameter(Mandatory=$false)]
    [string]$TypeFilter,
    
    [Parameter(Mandatory=$false)]
    [switch]$Interactive,
    
    [Parameter(Mandatory=$false)]
    [switch]$AutoApprove
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

function Show-ReportSummary {
    param($Report)
    
    Write-Log "=== RÉSUMÉ DU RAPPORT DE DIFF ===" "INFO"
    Write-Host "ID du rapport: $($Report.reportId)" -ForegroundColor Cyan
    Write-Host "Source: $($Report.sourceLabel)" -ForegroundColor Cyan
    Write-Host "Cible: $($Report.targetLabel)" -ForegroundColor Cyan
    Write-Host "Date: $($Report.metadata.timestamp)" -ForegroundColor Cyan
    Write-Host "Total différences: $($Report.summary.total)" -ForegroundColor Cyan
    Write-Host "Temps d'exécution: $($Report.performance.executionTime)ms" -ForegroundColor Cyan
    Write-Host "Nœuds comparés: $($Report.performance.nodesCompared)" -ForegroundColor Cyan
    
    Write-Host "`nRésumé par sévérité:" -ForegroundColor Yellow
    foreach ($severity in @("critical", "high", "medium", "low", "info")) {
        $count = $Report.summary.bySeverity.$severity
        if ($count -gt 0) {
            $color = switch ($severity) {
                "critical" { "Red" }
                "high" { "DarkRed" }
                "medium" { "Yellow" }
                "low" { "Green" }
                "info" { "Cyan" }
                default { "White" }
            }
            Write-Host "  $severity`: $count" -ForegroundColor $color
        }
    }
    
    Write-Host "`nRésumé par type:" -ForegroundColor Yellow
    foreach ($type in $Report.summary.byType.PSObject.Properties) {
        if ($type.Value -gt 0) {
            Write-Host "  $($type.Name): $($type.Value)" -ForegroundColor Gray
        }
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

function Show-Difference {
    param($Difference, [int]$Index)
    
    Write-Host "`n--- Différence #$Index ---" -ForegroundColor Cyan
    Write-Host "Sévérité: $($Difference.severity)" -ForegroundColor $(switch ($Difference.severity) {
        "critical" { "Red" }
        "high" { "DarkRed" }
        "medium" { "Yellow" }
        "low" { "Green" }
        "info" { "Cyan" }
        default { "White" }
    })
    Write-Host "Type: $($Difference.type)" -ForegroundColor Gray
    Write-Host "Chemin: $($Difference.path)" -ForegroundColor White
    Write-Host "Description: $($Difference.description)" -ForegroundColor Yellow
    
    if ($Difference.oldValue -ne $null) {
        Write-Host "Ancienne valeur: $($Difference.oldValue)" -ForegroundColor Red
    }
    
    if ($Difference.newValue -ne $null) {
        Write-Host "Nouvelle valeur: $($Difference.newValue)" -ForegroundColor Green
    }
    
    if ($Difference.metadata) {
        Write-Host "Métadonnées: $($Difference.metadata | ConvertTo-Json -Compress)" -ForegroundColor Gray
    }
}

function Invoke-InteractiveValidation {
    param($Report)
    
    Write-Log "Démarrage de la validation interactive..."
    
    $differences = $Report.diffs
    $validationResults = @()
    
    for ($i = 0; $i -lt $differences.Count; $i++) {
        $diff = $differences[$i]
        
        Clear-Host
        Write-Host "=== VALIDATION INTERACTIVE DES DIFFÉRENCES ===" -ForegroundColor Magenta
        Write-Host "Différence $($i + 1) / $($differences.Count)" -ForegroundColor Cyan
        Write-Host "Total validées: $($validationResults.Where({$_.action}).Count)" -ForegroundColor Green
        
        Show-Difference -Difference $diff -Index ($i + 1)
        
        Write-Host "`nOptions:" -ForegroundColor Yellow
        Write-Host "1. Approuver" -ForegroundColor Green
        Write-Host "2. Rejeter" -ForegroundColor Red
        Write-Host "3. Ignorer" -ForegroundColor Yellow
        Write-Host "4. Ajouter un commentaire" -ForegroundColor Cyan
        Write-Host "5. Voir le contexte" -ForegroundColor Blue
        Write-Host "6. Quitter" -ForegroundColor Magenta
        
        $choice = Read-Host "`nVotre choix (1-6)"
        
        $validationResult = @{
            index = $i
            path = $diff.path
            severity = $diff.severity
            type = $diff.type
            timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        }
        
        switch ($choice) {
            "1" {
                $validationResult.action = "approved"
                $validationResult.comment = Read-Host "Commentaire (optionnel)"
                Write-Log "Différence approuvée" "SUCCESS"
            }
            "2" {
                $validationResult.action = "rejected"
                $validationResult.comment = Read-Host "Raison du rejet (obligatoire)"
                Write-Log "Différence rejetée" "WARN"
            }
            "3" {
                $validationResult.action = "ignored"
                $validationResult.comment = Read-Host "Raison de l'ignorance (optionnel)"
                Write-Log "Différence ignorée" "INFO"
            }
            "4" {
                $comment = Read-Host "Commentaire"
                $validationResult.action = "commented"
                $validationResult.comment = $comment
                Write-Log "Commentaire ajouté" "INFO"
                $i--  # Revenir à la même différence
                continue
            }
            "5" {
                Write-Host "`nContexte:" -ForegroundColor Blue
                Write-Host "Chemin complet: $($diff.path)" -ForegroundColor Gray
                if ($diff.metadata) {
                    Write-Host "Métadonnées complètes:" -ForegroundColor Gray
                    Write-Host ($diff.metadata | ConvertTo-Json -Depth 10) -ForegroundColor Gray
                }
                Read-Host "Appuyez sur Entrée pour continuer"
                $i--  # Revenir à la même différence
                continue
            }
            "6" {
                Write-Log "Validation interactive interrompue" "WARN"
                break
            }
            default {
                Write-Log "Choix invalide, passage à la différence suivante" "WARN"
                $validationResult.action = "skipped"
            }
        }
        
        $validationResults += $validationResult
    }
    
    return $validationResults
}

function Invoke-AutoValidation {
    param($Report)
    
    Write-Log "Démarrage de la validation automatique..."
    
    $differences = $Report.diffs
    $validationResults = @()
    
    foreach ($diff in $differences) {
        $validationResult = @{
            index = $differences.IndexOf($diff)
            path = $diff.path
            severity = $diff.severity
            type = $diff.type
            timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        }
        
        # Logique d'auto-approbation
        if ($diff.severity -in @("low", "info")) {
            $validationResult.action = "approved"
            $validationResult.comment = "Auto-approuvé: sévérité faible"
        }
        elseif ($diff.type -in @("comment", "whitespace", "formatting")) {
            $validationResult.action = "approved"
            $validationResult.comment = "Auto-approuvé: type non critique"
        }
        else {
            $validationResult.action = "manual_review_required"
            $validationResult.comment = "Nécessite une validation manuelle"
        }
        
        $validationResults += $validationResult
    }
    
    Write-Log "Validation automatique terminée" "SUCCESS"
    return $validationResults
}

function Export-ValidationReport {
    param(
        $Report,
        $ValidationResults,
        [string]$OutputPath
    )
    
    $validationReport = @{
        validationId = "validation-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
        originalReportId = $Report.reportId
        validationTimestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        validator = "roosync_validate_diff.ps1"
        summary = @{
            totalDifferences = $Report.diffs.Count
            approved = ($ValidationResults | Where-Object { $_.action -eq "approved" }).Count
            rejected = ($ValidationResults | Where-Object { $_.action -eq "rejected" }).Count
            ignored = ($ValidationResults | Where-Object { $_.action -eq "ignored" }).Count
            manualReviewRequired = ($ValidationResults | Where-Object { $_.action -eq "manual_review_required" }).Count
        }
        results = $ValidationResults
        metadata = @{
            severityFilter = $SeverityFilter
            typeFilter = $TypeFilter
            autoApprove = $AutoApprove.IsPresent
            interactive = $Interactive.IsPresent
        }
    }
    
    if ($OutputPath) {
        $validationReport | ConvertTo-Json -Depth 10 | Out-File -FilePath $OutputPath -Encoding UTF8
        Write-Log "Rapport de validation exporté vers: $OutputPath" "SUCCESS"
    }
    
    return $validationReport
}

function Show-ValidationSummary {
    param($ValidationReport)
    
    Write-Log "=== RÉSUMÉ DE LA VALIDATION ===" "INFO"
    Write-Host "ID de validation: $($ValidationReport.validationId)" -ForegroundColor Cyan
    Write-Host "ID du rapport original: $($ValidationReport.originalReportId)" -ForegroundColor Cyan
    Write-Host "Date de validation: $($ValidationReport.validationTimestamp)" -ForegroundColor Cyan
    
    Write-Host "`nRésultats:" -ForegroundColor Yellow
    Write-Host "  Total différences: $($ValidationReport.summary.totalDifferences)" -ForegroundColor White
    Write-Host "  Approuvées: $($ValidationReport.summary.approved)" -ForegroundColor Green
    Write-Host "  Rejetées: $($ValidationReport.summary.rejected)" -ForegroundColor Red
    Write-Host "  Ignorées: $($ValidationReport.summary.ignored)" -ForegroundColor Yellow
    Write-Host "  Nécessitant révision manuelle: $($ValidationReport.summary.manualReviewRequired)" -ForegroundColor Magenta
    
    $approvalRate = if ($ValidationReport.summary.totalDifferences -gt 0) {
        [math]::Round(($ValidationReport.summary.approved / $ValidationReport.summary.totalDifferences) * 100, 2)
    } else { 0 }
    
    Write-Host "`nTaux d'approbation: $approvalRate%" -ForegroundColor $(if ($approvalRate -ge 80) { "Green" } elseif ($approvalRate -ge 60) { "Yellow" } else { "Red" })
}

# Programme principal
try {
    Write-Log "=== SCRIPT DE VALIDATION DE DIFF GRANULAIRE ROOSYNC ===" "INFO"
    Write-Log "Version: 1.0.0" "INFO"
    Write-Log "Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" "INFO"
    
    # Étape 1: Vérification des prérequis
    Test-Prerequisites
    
    # Étape 2: Lecture du rapport
    $report = Read-DiffReport
    
    # Étape 3: Affichage du résumé
    Show-ReportSummary -Report $report
    
    # Étape 4: Filtrage des différences
    $differences = Filter-Differences -Differences $report.diffs -SeverityFilter $SeverityFilter -TypeFilter $TypeFilter
    Write-Log "Différences après filtrage: $($differences.Count) / $($report.diffs.Count)" "INFO"
    
    if ($differences.Count -eq 0) {
        Write-Log "Aucune différence à valider après filtrage" "WARN"
        exit 0
    }
    
    # Étape 5: Validation
    if ($Interactive) {
        $validationResults = Invoke-InteractiveValidation -Report $report
    }
    elseif ($AutoApprove) {
        $validationResults = Invoke-AutoValidation -Report $report
    }
    else {
        Write-Log "Aucun mode de validation spécifié, utilisation du mode automatique" "INFO"
        $validationResults = Invoke-AutoValidation -Report $report
    }
    
    # Étape 6: Export du rapport
    $validationReport = Export-ValidationReport -Report $report -ValidationResults $validationResults -OutputPath $OutputPath
    
    # Étape 7: Affichage du résumé
    Show-ValidationSummary -ValidationReport $validationReport
    
    Write-Log "Validation de diff granulaire terminée avec succès" "SUCCESS"
    
}
catch {
    Write-Log "Erreur lors de la validation: $($_.Exception.Message)" "ERROR"
    Write-Log "Stack trace: $($_.ScriptStackTrace)" "ERROR"
    exit 1
}