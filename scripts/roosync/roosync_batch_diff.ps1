<#
.SYNOPSIS
    Script PowerShell autonome pour le traitement par lots de diff granulaire RooSync
    Version: 1.0.0
    Date: 2025-11-10

.DESCRIPTION
    Ce script permet d'effectuer des comparaisons granulaires par lots sur plusieurs
    configurations ou machines, avec génération de rapports consolidés.

.PARAMETER ConfigDir
    Répertoire contenant les fichiers de configuration à comparer

.PARAMETER BaselinePath
    Chemin vers le fichier baseline de référence

.PARAMETER OutputDir
    Répertoire de sortie pour les rapports

.PARAMETER Pattern
    Pattern de filtrage des fichiers de configuration (ex: "*.json", "config-*.yml")

.PARAMETER Recursive
    Rechercher récursivement dans les sous-répertoires

.PARAMETER Parallel
    Exécuter les comparaisons en parallèle

.PARAMETER MaxParallelJobs
    Nombre maximum de jobs parallèles (défaut: 4)

.PARAMETER ConsolidateReport
    Générer un rapport consolidé à la fin

.PARAMETER ExportFormats
    Formats d'export pour les rapports (json,csv,html,md)

.EXAMPLE
    .\roosync_batch_diff.ps1 -ConfigDir "configs" -BaselinePath "baseline.json" -OutputDir "reports" -Pattern "*.json"

.EXAMPLE
    .\roosync_batch_diff.ps1 -ConfigDir "configs" -BaselinePath "baseline.json" -OutputDir "reports" -Parallel -ConsolidateReport

.NOTES
    Auteur: Roo AI Assistant
    Projet: RooSync v2.1 - Phase 3B SDDD
    Dépendances: Aucune (script autonome)
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$ConfigDir,
    
    [Parameter(Mandatory=$true)]
    [string]$BaselinePath,
    
    [Parameter(Mandatory=$true)]
    [string]$OutputDir,
    
    [Parameter(Mandatory=$false)]
    [string]$Pattern = "*.json",
    
    [Parameter(Mandatory=$false)]
    [switch]$Recursive,
    
    [Parameter(Mandatory=$false)]
    [switch]$Parallel,
    
    [Parameter(Mandatory=$false)]
    [int]$MaxParallelJobs = 4,
    
    [Parameter(Mandatory=$false)]
    [switch]$ConsolidateReport,
    
    [Parameter(Mandatory=$false)]
    [string[]]$ExportFormats = @("json")
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
    
    # Vérifier que le répertoire de configuration existe
    if (-not (Test-Path $ConfigDir)) {
        throw "Le répertoire de configuration '$ConfigDir' n'existe pas"
    }
    
    # Vérifier que le fichier baseline existe
    if (-not (Test-Path $BaselinePath)) {
        throw "Le fichier baseline '$BaselinePath' n'existe pas"
    }
    
    # Vérifier que le baseline est un JSON valide
    try {
        $null = Get-Content $BaselinePath -Raw | ConvertFrom-Json
        Write-Log "Fichier baseline JSON valide" "SUCCESS"
    }
    catch {
        throw "Le fichier baseline '$BaselinePath' n'est pas un JSON valide: $($_.Exception.Message)"
    }
    
    # Créer le répertoire de sortie
    if (-not (Test-Path $OutputDir)) {
        New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
        Write-Log "Répertoire de sortie créé: $OutputDir" "SUCCESS"
    }
    
    Write-Log "Prérequis vérifiés avec succès" "SUCCESS"
}

function Get-ConfigFiles {
    Write-Log "Recherche des fichiers de configuration..."
    
    $files = @()
    
    if ($Recursive) {
        $files = Get-ChildItem -Path $ConfigDir -Filter $Pattern -Recurse -File
    } else {
        $files = Get-ChildItem -Path $ConfigDir -Filter $Pattern -File
    }
    
    Write-Log "Fichiers trouvés: $($files.Count)" "INFO"
    
    return $files
}

function Read-Baseline {
    Write-Log "Lecture du baseline..."
    
    try {
        $baselineContent = Get-Content $BaselinePath -Raw | ConvertFrom-Json
        Write-Log "Baseline lu avec succès" "SUCCESS"
        return $baselineContent
    }
    catch {
        throw "Erreur lors de la lecture du baseline: $($_.Exception.Message)"
    }
}

function Read-ConfigFile {
    param([System.IO.FileInfo]$File)
    
    try {
        $configContent = Get-Content $File.FullName -Raw | ConvertFrom-Json
        return @{
            File = $File
            Content = $configContent
            Success = $true
            Error = $null
        }
    }
    catch {
        return @{
            File = $File
            Content = $null
            Success = $false
            Error = $_.Exception.Message
        }
    }
}

function Invoke-SingleDiff {
    param(
        $Baseline,
        $ConfigData,
        [string]$OutputDir
    )
    
    $configFile = $ConfigData.File
    $configContent = $ConfigData.Content
    
    if (-not $ConfigData.Success) {
        Write-Log "Erreur de lecture pour $($configFile.Name): $($ConfigData.Error)" "ERROR"
        return $null
    }
    
    Write-Log "Comparaison avec $($configFile.Name)..." "DEBUG"
    
    try {
        # Préparer les données pour le script Node.js
        $env:SOURCE_DATA = $Baseline | ConvertTo-Json -Depth 20 -Compress
        $env:TARGET_DATA = $configContent | ConvertTo-Json -Depth 20 -Compress
        $env:SOURCE_LABEL = "baseline"
        $env:TARGET_LABEL = $configFile.BaseName
        
        # Exécuter le script Node.js
        $nodeScript = Join-Path $PSScriptRoot "granular-diff-runner.js"
        $result = & node $nodeScript 2>&1
        
        if ($LASTEXITCODE -ne 0) {
            throw "Erreur lors de l'exécution du diff: $result"
        }
        
        # Extraire le rapport JSON de la sortie
        $jsonStart = $result | Select-String "=== RAPPORT COMPLET ===" | Select-Object -First 1
        if ($jsonStart) {
            $startIndex = $result.IndexOf($jsonStart.Line) + $jsonStart.Line.Length
            $jsonContent = $result.Substring($startIndex).Trim()
            $report = $jsonContent | ConvertFrom-Json
        } else {
            throw "Impossible de trouver le rapport JSON dans la sortie"
        }
        
        # Sauvegarder le rapport
        $reportPath = Join-Path $OutputDir "diff-$($configFile.BaseName).json"
        $report | ConvertTo-Json -Depth 10 | Out-File -FilePath $reportPath -Encoding UTF8
        
        # Exporter dans les autres formats si demandé
        foreach ($format in $ExportFormats) {
            if ($format -ne "json") {
                $exportPath = Join-Path $OutputDir "diff-$($configFile.BaseName).$format"
                
                $exportScript = Join-Path $PSScriptRoot "roosync_export_diff.ps1"
                & $exportScript -ReportPath $reportPath -OutputPath $exportPath -Format $format
            }
        }
        
        Write-Log "Diff terminé pour $($configFile.Name): $($report.summary.total) différences" "SUCCESS"
        
        return @{
            File = $configFile
            Report = $report
            ReportPath = $reportPath
            Success = $true
            Error = $null
        }
    }
    catch {
        Write-Log "Erreur lors du diff pour $($configFile.Name): $($_.Exception.Message)" "ERROR"
        return @{
            File = $configFile
            Report = $null
            ReportPath = $null
            Success = $false
            Error = $_.Exception.Message
        }
    }
    finally {
        # Nettoyer les variables d'environnement
        Remove-Item -Path "env:SOURCE_DATA" -ErrorAction SilentlyContinue
        Remove-Item -Path "env:TARGET_DATA" -ErrorAction SilentlyContinue
        Remove-Item -Path "env:SOURCE_LABEL" -ErrorAction SilentlyContinue
        Remove-Item -Path "env:TARGET_LABEL" -ErrorAction SilentlyContinue
    }
}

function Invoke-ParallelDiff {
    param(
        $Baseline,
        $ConfigFiles,
        [string]$OutputDir
    )
    
    Write-Log "Démarrage du traitement parallèle ($MaxParallelJobs jobs)..."
    
    $jobs = @()
    $results = @()
    $configData = @()
    
    # Précharger tous les fichiers de configuration
    Write-Log "Préchargement des fichiers de configuration..."
    foreach ($file in $ConfigFiles) {
        $configData += Read-ConfigFile -File $file
    }
    
    # Traiter en parallèle
    for ($i = 0; $i -lt $configData.Count; $i += $MaxParallelJobs) {
        $batch = $configData[$i..[Math]::Min($i + $MaxParallelJobs - 1, $configData.Count - 1)]
        
        Write-Log "Traitement du batch $($i / $MaxParallelJobs + 1) / $([Math]::Ceiling($configData.Count / $MaxParallelJobs))"
        
        $batchJobs = @()
        foreach ($data in $batch) {
            $job = Start-Job -ScriptBlock {
                param($Baseline, $ConfigData, $OutputDir, $PSScriptRoot, $ExportFormats)
                
                # Importer les fonctions nécessaires
                . (Join-Path $PSScriptRoot "roosync_batch_diff.ps1")
                
                # Exécuter le diff
                Invoke-SingleDiff -Baseline $Baseline -ConfigData $ConfigData -OutputDir $OutputDir
            } -ArgumentList $Baseline, $data, $OutputDir, $PSScriptRoot, $ExportFormats
            
            $batchJobs += $job
        }
        
        # Attendre la fin du batch
        $batchResults = $batchJobs | Wait-Job | Receive-Job
        $results += $batchResults
        
        # Nettoyer les jobs
        $batchJobs | Remove-Job
    }
    
    Write-Log "Traitement parallèle terminé" "SUCCESS"
    return $results
}

function Invoke-SequentialDiff {
    param(
        $Baseline,
        $ConfigFiles,
        [string]$OutputDir
    )
    
    Write-Log "Démarrage du traitement séquentiel..."
    
    $results = @()
    $progress = 0
    
    foreach ($file in $ConfigFiles) {
        $progress++
        Write-Progress -Activity "Traitement des fichiers" -Status "Fichier $progress / $($ConfigFiles.Count)" -PercentComplete (($progress / $ConfigFiles.Count) * 100)
        
        $configData = Read-ConfigFile -File $file
        $result = Invoke-SingleDiff -Baseline $Baseline -ConfigData $configData -OutputDir $OutputDir
        $results += $result
    }
    
    Write-Progress -Activity "Traitement des fichiers" -Completed
    Write-Log "Traitement séquentiel terminé" "SUCCESS"
    
    return $results
}

function New-ConsolidatedReport {
    param(
        $Results,
        [string]$OutputDir
    )
    
    Write-Log "Génération du rapport consolidé..."
    
    $successfulResults = $Results | Where-Object { $_.Success }
    $failedResults = $Results | Where-Object { -not $_.Success }
    
    $totalDifferences = 0
    $severitySummary = @{
        critical = 0
        high = 0
        medium = 0
        low = 0
        info = 0
    }
    
    foreach ($result in $successfulResults) {
        $totalDifferences += $result.Report.summary.total
        
        foreach ($severity in $severitySummary.Keys) {
            $severitySummary[$severity] += $result.Report.summary.bySeverity.$severity
        }
    }
    
    $consolidatedReport = @{
        reportId = "consolidated-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
        timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        summary = @{
            totalFiles = $Results.Count
            successfulComparisons = $successfulResults.Count
            failedComparisons = $failedResults.Count
            totalDifferences = $totalDifferences
            severityBreakdown = $severitySummary
        }
        results = $successfulResults | ForEach-Object {
            @{
                fileName = $_.File.Name
                reportPath = $_.ReportPath
                totalDifferences = $_.Report.summary.total
                severityBreakdown = $_.Report.summary.bySeverity
                executionTime = $_.Report.performance.executionTime
            }
        }
        failures = $failedResults | ForEach-Object {
            @{
                fileName = $_.File.Name
                error = $_.Error
            }
        }
    }
    
    # Sauvegarder le rapport consolidé
    $consolidatedPath = Join-Path $OutputDir "consolidated-report.json"
    $consolidatedReport | ConvertTo-Json -Depth 10 | Out-File -FilePath $consolidatedPath -Encoding UTF8
    
    # Exporter dans les autres formats si demandé
    foreach ($format in $ExportFormats) {
        if ($format -ne "json") {
            $exportPath = Join-Path $OutputDir "consolidated-report.$format"
            
            $exportScript = Join-Path $PSScriptRoot "roosync_export_diff.ps1"
            & $exportScript -ReportPath $consolidatedPath -OutputPath $exportPath -Format $format
        }
    }
    
    Write-Log "Rapport consolidé généré: $consolidatedPath" "SUCCESS"
    
    # Afficher le résumé
    Write-Log "=== RÉSUMÉ CONSOLIDÉ ===" "INFO"
    Write-Host "Total fichiers: $($Results.Count)" -ForegroundColor Cyan
    Write-Host "Comparaisons réussies: $($successfulResults.Count)" -ForegroundColor Green
    Write-Host "Comparaisons échouées: $($failedResults.Count)" -ForegroundColor Red
    Write-Host "Total différences: $totalDifferences" -ForegroundColor Yellow
    
    Write-Host "`nRépartition par sévérité:" -ForegroundColor Yellow
    foreach ($severity in $severitySummary.Keys) {
        if ($severitySummary[$severity] -gt 0) {
            $color = switch ($severity) {
                "critical" { "Red" }
                "high" { "DarkRed" }
                "medium" { "Yellow" }
                "low" { "Green" }
                "info" { "Cyan" }
                default { "White" }
            }
            Write-Host "  $severity`: $($severitySummary[$severity])" -ForegroundColor $color
        }
    }
    
    return $consolidatedReport
}

# Programme principal
try {
    Write-Log "=== SCRIPT DE TRAITEMENT PAR LOTS DE DIFF GRANULAIRE ROOSYNC ===" "INFO"
    Write-Log "Version: 1.0.0" "INFO"
    Write-Log "Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" "INFO"
    
    # Étape 1: Vérification des prérequis
    Test-Prerequisites
    
    # Étape 2: Recherche des fichiers de configuration
    $configFiles = Get-ConfigFiles
    
    if ($configFiles.Count -eq 0) {
        Write-Log "Aucun fichier de configuration trouvé avec le pattern '$Pattern'" "WARN"
        exit 0
    }
    
    # Étape 3: Lecture du baseline
    $baseline = Read-Baseline
    
    # Étape 4: Traitement des diffs
    if ($Parallel) {
        $results = Invoke-ParallelDiff -Baseline $baseline -ConfigFiles $configFiles -OutputDir $OutputDir
    } else {
        $results = Invoke-SequentialDiff -Baseline $baseline -ConfigFiles $configFiles -OutputDir $OutputDir
    }
    
    # Étape 5: Génération du rapport consolidé si demandé
    if ($ConsolidateReport) {
        $consolidatedReport = New-ConsolidatedReport -Results $results -OutputDir $OutputDir
    }
    
    # Étape 6: Résumé final
    $successfulCount = ($results | Where-Object { $_.Success }).Count
    $failedCount = ($results | Where-Object { -not $_.Success }).Count
    
    Write-Log "=== RÉSUMÉ FINAL ===" "INFO"
    Write-Host "Fichiers traités: $($results.Count)" -ForegroundColor Cyan
    Write-Host "Succès: $successfulCount" -ForegroundColor Green
    Write-Host "Échecs: $failedCount" -ForegroundColor Red
    
    if ($failedCount -gt 0) {
        Write-Log "`nFichiers en erreur:" "WARN"
        $results | Where-Object { -not $_.Success } | ForEach-Object {
            Write-Host "  $($_.File.Name): $($_.Error)" -ForegroundColor Red
        }
    }
    
    Write-Log "Traitement par lots terminé avec succès" "SUCCESS"
    
}
catch {
    Write-Log "Erreur lors du traitement par lots: $($_.Exception.Message)" "ERROR"
    Write-Log "Stack trace: $($_.ScriptStackTrace)" "ERROR"
    exit 1
}