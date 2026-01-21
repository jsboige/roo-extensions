# ============================================================================
# Système d'Auto-Amélioration pour l'Orchestration Quotidienne Roo
# Version: 1.0.0
# Description: Analyse des performances et optimisation automatique
# ============================================================================

param(
    [string]$MetricsPath = "roo-config/scheduler/metrics",
    [string]$ConfigPath = "roo-config/scheduler/daily-orchestration.json",
    [int]$AnalysisWindowDays = 30,
    [switch]$ApplyOptimizations = $true,
    [switch]$Verbose = $false,
    [string]$BasePath = ""  # Chemin racine du dépôt (auto-détecté si vide)
)

# Auto-détection du chemin racine si non spécifié
if (-not $BasePath) {
    $BasePath = (Resolve-Path (Join-Path $PSScriptRoot "..\..\")).Path.TrimEnd('\', '/')
}

# Configuration globale
$Global:SelfImprovementConfig = @{
    BasePath = $BasePath
    AnalysisId = [System.Guid]::NewGuid().ToString()
    StartTime = Get-Date
    Verbose = $Verbose
    LearningRate = 0.1
    ConfidenceThreshold = 0.8
}

Set-Location $Global:SelfImprovementConfig.BasePath

# ============================================================================
# FONCTIONS UTILITAIRES
# ============================================================================

function Write-ImprovementLog {
    param(
        [string]$Message,
        [string]$Level = "INFO",
        [hashtable]$Data = @{}
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
    $logEntry = @{
        timestamp = $timestamp
        analysis_id = $Global:SelfImprovementConfig.AnalysisId
        level = $Level
        message = $Message
        data = $Data
    }
    
    if ($Global:SelfImprovementConfig.Verbose -or $Level -in @("WARN", "ERROR", "CRITICAL")) {
        $color = switch ($Level) {
            "DEBUG" { "Gray" }
            "INFO" { "Cyan" }
            "WARN" { "Yellow" }
            "ERROR" { "Red" }
            "CRITICAL" { "Magenta" }
            default { "White" }
        }
        Write-Host "[$timestamp] [IMPROVEMENT] $Message" -ForegroundColor $color
    }
    
    # Écriture dans le fichier de log d'amélioration
    $logFile = "roo-config/scheduler/logs/improvement-$(Get-Date -Format 'yyyyMMdd').json"
    $logEntry | ConvertTo-Json -Compress | Add-Content -Path $logFile
}

function Get-HistoricalMetrics {
    param(
        [string]$MetricsPath,
        [int]$WindowDays
    )
    
    Write-ImprovementLog "Collecte des métriques historiques sur $WindowDays jours" -Level "INFO"
    
    $cutoffDate = (Get-Date).AddDays(-$WindowDays)
    $metricsFiles = Get-ChildItem -Path $MetricsPath -Filter "daily-metrics-*.json" | 
                   Where-Object { $_.LastWriteTime -gt $cutoffDate }
    
    $allMetrics = @()
    
    foreach ($file in $metricsFiles) {
        try {
            $dailyMetrics = Get-Content -Raw $file.FullName | ConvertFrom-Json
            if ($dailyMetrics.executions -and $dailyMetrics.executions.Count -gt 0) {
                $allMetrics += $dailyMetrics.executions
            }
        }
        catch {
            Write-ImprovementLog "Erreur lors de la lecture de $($file.Name): $($_.Exception.Message)" -Level "WARN"
        }
    }
    
    Write-ImprovementLog "Collecté $($allMetrics.Count) exécutions historiques" -Level "INFO"
    return $allMetrics
}

function Analyze-PerformanceMetrics {
    param([array]$Metrics)
    
    Write-ImprovementLog "Analyse des métriques de performance" -Level "INFO"
    
    if ($Metrics.Count -eq 0) {
        return @{
            status = "insufficient_data"
            message = "Pas assez de données pour l'analyse"
        }
    }
    
    $analysis = @{
        total_executions = $Metrics.Count
        success_rate = 0
        average_duration_ms = 0
        median_duration_ms = 0
        duration_trend = "stable"
        error_patterns = @{}
        phase_performance = @{}
        recommendations = @()
        confidence_score = 0
    }
    
    # Calcul du taux de succès
    $successfulExecutions = $Metrics | Where-Object { $_.status -eq "success" }
    $analysis.success_rate = if ($Metrics.Count -gt 0) { $successfulExecutions.Count / $Metrics.Count } else { 0 }
    
    # Analyse des durées
    $durations = $Metrics | ForEach-Object { $_.total_duration_ms }
    if ($durations.Count -gt 0) {
        $analysis.average_duration_ms = ($durations | Measure-Object -Average).Average
        $sortedDurations = $durations | Sort-Object
        $medianIndex = [math]::Floor($sortedDurations.Count / 2)
        $analysis.median_duration_ms = $sortedDurations[$medianIndex]
        
        # Analyse de tendance (comparaison première moitié vs seconde moitié)
        if ($durations.Count -gt 10) {
            $halfPoint = [math]::Floor($durations.Count / 2)
            $firstHalf = $durations[0..($halfPoint-1)] | Measure-Object -Average
            $secondHalf = $durations[$halfPoint..($durations.Count-1)] | Measure-Object -Average
            
            $trendRatio = $secondHalf.Average / $firstHalf.Average
            if ($trendRatio > 1.1) {
                $analysis.duration_trend = "degrading"
            }
            elseif ($trendRatio -lt 0.9) {
                $analysis.duration_trend = "improving"
            }
        }
    }
    
    # Analyse des patterns d'erreurs
    $errorMetrics = $Metrics | Where-Object { $_.status -ne "success" }
    foreach ($execution in $errorMetrics) {
        foreach ($phaseName in $execution.phases.PSObject.Properties.Name) {
            $phase = $execution.phases.$phaseName
            if ($phase.status -eq "error") {
                foreach ($error in $phase.errors) {
                    if (-not $analysis.error_patterns.ContainsKey($error)) {
                        $analysis.error_patterns[$error] = 0
                    }
                    $analysis.error_patterns[$error]++
                }
            }
        }
    }
    
    # Analyse des performances par phase
    $phaseNames = @("diagnostic", "synchronization", "testing", "cleanup", "improvement")
    foreach ($phaseName in $phaseNames) {
        $phaseMetrics = $Metrics | Where-Object { $_.phases.$phaseName } | ForEach-Object { $_.phases.$phaseName }
        if ($phaseMetrics.Count -gt 0) {
            $phaseSuccessRate = ($phaseMetrics | Where-Object { $_.status -eq "success" }).Count / $phaseMetrics.Count
            $phaseAvgDuration = ($phaseMetrics | Measure-Object -Property duration_ms -Average).Average
            
            $analysis.phase_performance[$phaseName] = @{
                success_rate = $phaseSuccessRate
                average_duration_ms = $phaseAvgDuration
                execution_count = $phaseMetrics.Count
            }
        }
    }
    
    # Calcul du score de confiance
    $analysis.confidence_score = [math]::Min(1.0, $Metrics.Count / 30.0) # Confiance maximale avec 30+ exécutions
    
    Write-ImprovementLog "Analyse terminée - Taux de succès: $([math]::Round($analysis.success_rate * 100, 2))%" -Level "INFO"
    
    return $analysis
}

function Generate-OptimizationRecommendations {
    param([object]$Analysis)
    
    Write-ImprovementLog "Génération des recommandations d'optimisation" -Level "INFO"
    
    $recommendations = @()
    
    # Recommandations basées sur le taux de succès
    if ($Analysis.success_rate -lt 0.8) {
        $recommendations += @{
            type = "timeout_increase"
            priority = "high"
            description = "Augmenter les timeouts en raison du faible taux de succès"
            current_value = "current_timeouts"
            recommended_value = "increased_by_25_percent"
            confidence = $Analysis.confidence_score
            reason = "Taux de succès de $([math]::Round($Analysis.success_rate * 100, 2))% inférieur au seuil de 80%"
        }
    }
    
    # Recommandations basées sur la durée d'exécution
    if ($Analysis.duration_trend -eq "degrading") {
        $recommendations += @{
            type = "performance_optimization"
            priority = "medium"
            description = "Optimiser les performances en raison de la dégradation des temps d'exécution"
            current_value = "current_sequence"
            recommended_value = "optimized_sequence"
            confidence = $Analysis.confidence_score
            reason = "Tendance de dégradation des performances détectée"
        }
    }
    
    # Recommandations basées sur les erreurs récurrentes
    $frequentErrors = $Analysis.error_patterns.GetEnumerator() | Where-Object { $_.Value -gt 2 } | Sort-Object -Property Value -Descending
    foreach ($error in $frequentErrors) {
        $recommendations += @{
            type = "error_mitigation"
            priority = "high"
            description = "Mitiger l'erreur récurrente: $($error.Key)"
            current_value = "current_error_handling"
            recommended_value = "enhanced_error_handling"
            confidence = [math]::Min(1.0, $error.Value / 10.0)
            reason = "Erreur survenue $($error.Value) fois"
        }
    }
    
    # Recommandations par phase
    foreach ($phaseName in $Analysis.phase_performance.Keys) {
        $phasePerf = $Analysis.phase_performance[$phaseName]
        
        if ($phasePerf.success_rate -lt 0.9) {
            $recommendations += @{
                type = "phase_timeout_adjustment"
                phase = $phaseName
                priority = "medium"
                description = "Ajuster le timeout de la phase $phaseName"
                current_value = "current_timeout"
                recommended_value = "increased_timeout"
                confidence = $Analysis.confidence_score
                reason = "Taux de succès de la phase: $([math]::Round($phasePerf.success_rate * 100, 2))%"
            }
        }
        
        if ($phasePerf.average_duration_ms -gt 900000) { # Plus de 15 minutes
            $recommendations += @{
                type = "phase_optimization"
                phase = $phaseName
                priority = "low"
                description = "Optimiser la phase $phaseName pour réduire la durée d'exécution"
                current_value = "current_implementation"
                recommended_value = "optimized_implementation"
                confidence = $Analysis.confidence_score
                reason = "Durée moyenne de $([math]::Round($phasePerf.average_duration_ms / 60000, 2)) minutes"
            }
        }
    }
    
    # Tri des recommandations par priorité et confiance
    $priorityOrder = @{ "high" = 3; "medium" = 2; "low" = 1 }
    $sortedRecommendations = $recommendations | Sort-Object -Property @{
        Expression = { $priorityOrder[$_.priority] }; Descending = $true
    }, @{
        Expression = { $_.confidence }; Descending = $true
    }
    
    Write-ImprovementLog "Généré $($recommendations.Count) recommandations d'optimisation" -Level "INFO"
    
    return $sortedRecommendations
}

function Apply-ConfigurationOptimizations {
    param(
        [array]$Recommendations,
        [string]$ConfigPath
    )
    
    Write-ImprovementLog "Application des optimisations de configuration" -Level "INFO"
    
    if (-not (Test-Path $ConfigPath)) {
        Write-ImprovementLog "Fichier de configuration non trouvé: $ConfigPath" -Level "ERROR"
        return $false
    }
    
    try {
        $config = Get-Content -Raw $ConfigPath | ConvertFrom-Json
        $optimizationsApplied = @()
        
        foreach ($recommendation in $Recommendations) {
            if ($recommendation.confidence -lt $Global:SelfImprovementConfig.ConfidenceThreshold) {
                Write-ImprovementLog "Recommandation ignorée (confiance insuffisante): $($recommendation.description)" -Level "DEBUG"
                continue
            }
            
            $applied = $false
            
            switch ($recommendation.type) {
                "timeout_increase" {
                    # Augmentation des timeouts de 25%
                    foreach ($phaseName in $config.orchestration.phases.PSObject.Properties.Name) {
                        $phase = $config.orchestration.phases.$phaseName
                        $oldTimeout = $phase.timeout_minutes
                        $newTimeout = [math]::Ceiling($oldTimeout * 1.25)
                        $phase.timeout_minutes = $newTimeout
                        
                        Write-ImprovementLog "Timeout de la phase ${phaseName}: ${oldTimeout} -> ${newTimeout} minutes" -Level "INFO"
                    }
                    $applied = $true
                }
                
                "phase_timeout_adjustment" {
                    if ($config.orchestration.phases.($recommendation.phase)) {
                        $phase = $config.orchestration.phases.($recommendation.phase)
                        $oldTimeout = $phase.timeout_minutes
                        $newTimeout = [math]::Ceiling($oldTimeout * 1.2)
                        $phase.timeout_minutes = $newTimeout
                        
                        Write-ImprovementLog "Timeout de la phase $($recommendation.phase): $oldTimeout -> $newTimeout minutes" -Level "INFO"
                        $applied = $true
                    }
                }
                
                "error_mitigation" {
                    # Augmentation des tentatives de retry
                    foreach ($phaseName in $config.orchestration.phases.PSObject.Properties.Name) {
                        $phase = $config.orchestration.phases.$phaseName
                        if ($phase.retry_attempts -lt 5) {
                            $oldRetry = $phase.retry_attempts
                            $phase.retry_attempts = [math]::Min(5, $oldRetry + 1)
                            
                            Write-ImprovementLog "Retry de la phase ${phaseName}: ${oldRetry} -> $($phase.retry_attempts)" -Level "INFO"
                        }
                    }
                    $applied = $true
                }
                
                "performance_optimization" {
                    # Activation du cache si disponible
                    if ($config.performance_optimization.caching) {
                        $config.performance_optimization.caching.enabled = $true
                        Write-ImprovementLog "Cache activé pour améliorer les performances" -Level "INFO"
                        $applied = $true
                    }
                }
            }
            
            if ($applied) {
                $optimizationsApplied += $recommendation
            }
        }
        
        # Mise à jour de la date de dernière modification
        $config.system.last_updated = Get-Date -Format "yyyy-MM-ddTHH:mm:ss.fffZ"
        
        # Sauvegarde de la configuration optimisée
        $config | ConvertTo-Json -Depth 10 | Set-Content -Path $ConfigPath
        
        Write-ImprovementLog "Configuration mise à jour avec $($optimizationsApplied.Count) optimisations" -Level "INFO"
        
        return $optimizationsApplied
    }
    catch {
        Write-ImprovementLog "Erreur lors de l'application des optimisations: $($_.Exception.Message)" -Level "ERROR"
        return $false
    }
}

function Save-ImprovementReport {
    param(
        [object]$Analysis,
        [array]$Recommendations,
        [array]$AppliedOptimizations
    )
    
    $reportPath = "roo-config/scheduler/history/improvement-report-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
    
    $report = @{
        analysis_id = $Global:SelfImprovementConfig.AnalysisId
        timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ss.fffZ"
        analysis = $Analysis
        recommendations = $Recommendations
        applied_optimizations = $AppliedOptimizations
        system_info = @{
            powershell_version = $PSVersionTable.PSVersion.ToString()
            os_version = [System.Environment]::OSVersion.ToString()
            machine_name = $env:COMPUTERNAME
        }
    }
    
    try {
        $report | ConvertTo-Json -Depth 10 | Set-Content -Path $reportPath
        Write-ImprovementLog "Rapport d'amélioration sauvegardé: $reportPath" -Level "INFO"
    }
    catch {
        Write-ImprovementLog "Erreur lors de la sauvegarde du rapport: $($_.Exception.Message)" -Level "ERROR"
    }
}

function Update-ScheduleDefinition {
    param([array]$AppliedOptimizations)
    
    # Mise à jour de la définition de tâche dans schedules.json si nécessaire
    $schedulesPath = ".roo/schedules.json"
    
    if (-not (Test-Path $schedulesPath)) {
        Write-ImprovementLog "Fichier schedules.json non trouvé" -Level "WARN"
        return
    }
    
    try {
        $schedules = Get-Content -Raw $schedulesPath | ConvertFrom-Json
        
        # Recherche de la tâche d'orchestration quotidienne
        $orchestrationTask = $schedules.schedules | Where-Object { $_.name -eq "Daily-Roo-Environment-Orchestration" }
        
        if ($orchestrationTask -and $AppliedOptimizations.Count -gt 0) {
            # Mise à jour de la date de dernière modification
            $orchestrationTask.updatedAt = Get-Date -Format "yyyy-MM-ddTHH:mm:ss.fffZ"
            
            # Ajout d'une note sur les optimisations appliquées
            $optimizationNote = "`n`n## OPTIMISATIONS AUTOMATIQUES APPLIQUÉES - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n"
            foreach ($optimization in $AppliedOptimizations) {
                $optimizationNote += "- $($optimization.description)`n"
            }
            
            $orchestrationTask.taskInstructions += $optimizationNote
            
            # Sauvegarde
            $schedules | ConvertTo-Json -Depth 10 | Set-Content -Path $schedulesPath
            
            Write-ImprovementLog "Définition de tâche mise à jour avec les optimisations" -Level "INFO"
        }
    }
    catch {
        Write-ImprovementLog "Erreur lors de la mise à jour de la définition de tâche: $($_.Exception.Message)" -Level "ERROR"
    }
}

# ============================================================================
# FONCTION PRINCIPALE D'AUTO-AMÉLIORATION
# ============================================================================

function Start-SelfImprovement {
    Write-ImprovementLog "=== DÉBUT DE L'AUTO-AMÉLIORATION ===" -Level "INFO"
    
    try {
        # Collecte des métriques historiques
        $historicalMetrics = Get-HistoricalMetrics -MetricsPath $MetricsPath -WindowDays $AnalysisWindowDays
        
        if ($historicalMetrics.Count -eq 0) {
            Write-ImprovementLog "Aucune métrique historique disponible pour l'analyse" -Level "WARN"
            return @{
                status = "no_data"
                message = "Pas assez de données pour l'amélioration"
            }
        }
        
        # Analyse des performances
        $analysis = Analyze-PerformanceMetrics -Metrics $historicalMetrics
        
        # Génération des recommandations
        $recommendations = Generate-OptimizationRecommendations -Analysis $analysis
        
        $appliedOptimizations = @()
        
        # Application des optimisations si demandé
        if ($ApplyOptimizations -and $recommendations.Count -gt 0) {
            $appliedOptimizations = Apply-ConfigurationOptimizations -Recommendations $recommendations -ConfigPath $ConfigPath
            
            if ($appliedOptimizations -and $appliedOptimizations.Count -gt 0) {
                Update-ScheduleDefinition -AppliedOptimizations $appliedOptimizations
            }
        }
        
        # Sauvegarde du rapport d'amélioration
        Save-ImprovementReport -Analysis $analysis -Recommendations $recommendations -AppliedOptimizations $appliedOptimizations
        
        Write-ImprovementLog "=== AUTO-AMÉLIORATION TERMINÉE ===" -Level "INFO"
        Write-ImprovementLog "Recommandations générées: $($recommendations.Count)" -Level "INFO"
        Write-ImprovementLog "Optimisations appliquées: $($appliedOptimizations.Count)" -Level "INFO"
        
        return @{
            status = "success"
            analysis = $analysis
            recommendations = $recommendations
            applied_optimizations = $appliedOptimizations
        }
    }
    catch {
        Write-ImprovementLog "Erreur critique dans l'auto-amélioration: $($_.Exception.Message)" -Level "CRITICAL"
        return @{
            status = "error"
            message = $_.Exception.Message
        }
    }
}

# ============================================================================
# POINT D'ENTRÉE PRINCIPAL
# ============================================================================

if ($MyInvocation.InvocationName -ne '.') {
    $result = Start-SelfImprovement
    
    switch ($result.status) {
        "success" { exit 0 }
        "no_data" { exit 1 }
        "error" { exit 2 }
        default { exit 3 }
    }
}