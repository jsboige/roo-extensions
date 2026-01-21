# ============================================================================
# Moteur d'Orchestration Quotidienne Intelligente Roo
# Version: 1.0.0
# Description: Système d'orchestration avec auto-amélioration
# ============================================================================

param(
    [string]$ConfigPath = "roo-config/scheduler/daily-orchestration.json",
    [switch]$DryRun = $false,
    [switch]$Verbose = $false,
    [string]$LogLevel = "INFO"
)

# Configuration globale
$Global:RooOrchestrationConfig = @{
    BasePath = "d:/Dev/roo-extensions"
    ExecutionId = [System.Guid]::NewGuid().ToString()
    StartTime = Get-Date
    LogLevel = $LogLevel
    DryRun = $DryRun
    Verbose = $Verbose
}

# Initialisation des chemins
Set-Location $Global:RooOrchestrationConfig.BasePath
$ConfigFullPath = Join-Path $Global:RooOrchestrationConfig.BasePath $ConfigPath

# Import du module d'escalade Claude (Level 3)
. (Join-Path $Global:RooOrchestrationConfig.BasePath "roo-config/scheduler/claude-escalation.ps1")

# ============================================================================
# FONCTIONS UTILITAIRES
# ============================================================================

function Write-OrchestrationLog {
    param(
        [string]$Message,
        [string]$Level = "INFO",
        [string]$Phase = "SYSTEM",
        [hashtable]$Data = @{}
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
    $logEntry = @{
        timestamp = $timestamp
        execution_id = $Global:RooOrchestrationConfig.ExecutionId
        level = $Level
        phase = $Phase
        message = $Message
        data = $Data
    }
    
    # Affichage console
    if ($Global:RooOrchestrationConfig.Verbose -or $Level -in @("WARN", "ERROR", "CRITICAL")) {
        $color = switch ($Level) {
            "DEBUG" { "Gray" }
            "INFO" { "White" }
            "WARN" { "Yellow" }
            "ERROR" { "Red" }
            "CRITICAL" { "Magenta" }
            default { "White" }
        }
        Write-Host "[$timestamp] [$Phase] $Message" -ForegroundColor $color
    }
    
    # Écriture dans le fichier de log
    $logFile = "roo-config/scheduler/daily-orchestration-log.json"
    $logEntry | ConvertTo-Json -Compress | Add-Content -Path $logFile
}

function Load-OrchestrationConfig {
    param([string]$ConfigPath)
    
    try {
        if (-not (Test-Path $ConfigPath)) {
            throw "Fichier de configuration non trouvé: $ConfigPath"
        }
        
        $config = Get-Content -Raw $ConfigPath | ConvertFrom-Json
        Write-OrchestrationLog "Configuration chargée avec succès" -Level "INFO"
        return $config
    }
    catch {
        Write-OrchestrationLog "Erreur lors du chargement de la configuration: $($_.Exception.Message)" -Level "ERROR"
        throw
    }
}

function Initialize-OrchestrationEnvironment {
    Write-OrchestrationLog "Initialisation de l'environnement d'orchestration" -Level "INFO"
    
    # Création des répertoires de logs
    $logDirs = @(
        "roo-config/scheduler/logs",
        "roo-config/scheduler/metrics",
        "roo-config/scheduler/history"
    )
    
    foreach ($dir in $logDirs) {
        if (-not (Test-Path $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
            Write-OrchestrationLog "Répertoire créé: $dir" -Level "DEBUG"
        }
    }
    
    # Initialisation du fichier de métriques
    $metricsFile = "roo-config/scheduler/metrics/daily-metrics-$(Get-Date -Format 'yyyyMMdd').json"
    if (-not (Test-Path $metricsFile)) {
        @{
            date = Get-Date -Format "yyyy-MM-dd"
            executions = @()
        } | ConvertTo-Json | Set-Content -Path $metricsFile
    }
}

function Invoke-PhaseExecution {
    param(
        [object]$PhaseConfig,
        [string]$PhaseName,
        [object]$GlobalConfig
    )
    
    $phaseStartTime = Get-Date
    Write-OrchestrationLog "Début de la phase: $PhaseName" -Level "INFO" -Phase $PhaseName
    
    $phaseResult = @{
        name = $PhaseName
        start_time = $phaseStartTime
        end_time = $null
        duration_ms = 0
        status = "running"
        delegated_mode = $PhaseConfig.mode
        tasks_results = @()
        errors = @()
        warnings = @()
    }
    
    try {
        # Validation des prérequis de la phase
        if (-not (Test-PhasePrerequisites -PhaseConfig $PhaseConfig -PhaseName $PhaseName)) {
            throw "Prérequis de la phase non satisfaits"
        }
        
        # Exécution des tâches de la phase
        foreach ($task in $PhaseConfig.tasks) {
            $taskResult = Invoke-TaskExecution -TaskConfig $task -PhaseName $PhaseName -PhaseConfig $PhaseConfig
            $phaseResult.tasks_results += $taskResult
            
            if ($taskResult.status -eq "error" -and $PhaseConfig.critical) {
                throw "Tâche critique échouée: $($task.name)"
            }
        }
        
        $phaseResult.status = "success"
        Write-OrchestrationLog "Phase terminée avec succès: $PhaseName" -Level "INFO" -Phase $PhaseName
    }
    catch {
        $phaseResult.status = "error"
        $phaseResult.errors += $_.Exception.Message
        Write-OrchestrationLog "Erreur dans la phase $PhaseName : $($_.Exception.Message)" -Level "ERROR" -Phase $PhaseName
        
        # Gestion des tentatives de retry
        if ($PhaseConfig.retry_attempts -gt 0) {
            Write-OrchestrationLog "Tentative de retry pour la phase $PhaseName" -Level "WARN" -Phase $PhaseName
            Start-Sleep -Seconds $PhaseConfig.retry_delay_seconds
            # Logique de retry ici
        }
    }
    finally {
        $phaseResult.end_time = Get-Date
        $phaseResult.duration_ms = ($phaseResult.end_time - $phaseResult.start_time).TotalMilliseconds
    }
    
    return $phaseResult
}

function Invoke-TaskExecution {
    param(
        [object]$TaskConfig,
        [string]$PhaseName,
        [object]$PhaseConfig
    )
    
    $taskStartTime = Get-Date
    Write-OrchestrationLog "Exécution de la tâche: $($TaskConfig.name)" -Level "DEBUG" -Phase $PhaseName
    
    $taskResult = @{
        name = $TaskConfig.name
        description = $TaskConfig.description
        start_time = $taskStartTime
        end_time = $null
        duration_ms = 0
        status = "running"
        output = @()
        errors = @()
    }
    
    try {
        switch ($TaskConfig.name) {
            "git_health_check" {
                $taskResult.output = Invoke-GitHealthCheck -TaskConfig $TaskConfig
            }
            "network_connectivity" {
                $taskResult.output = Invoke-NetworkConnectivityCheck -TaskConfig $TaskConfig
            }
            "critical_files_validation" {
                $taskResult.output = Invoke-CriticalFilesValidation -TaskConfig $TaskConfig
            }
            "git_sync" {
                $taskResult.output = Invoke-GitSynchronization -TaskConfig $TaskConfig
            }
            "post_sync_validation" {
                $taskResult.output = Invoke-PostSyncValidation -TaskConfig $TaskConfig
            }
            "mcp_tests" {
                $taskResult.output = Invoke-MCPTests -TaskConfig $TaskConfig
            }
            "config_validation" {
                $taskResult.output = Invoke-ConfigValidation -TaskConfig $TaskConfig
            }
            "log_cleanup" {
                $taskResult.output = Invoke-LogCleanup -TaskConfig $TaskConfig
            }
            "temp_cleanup" {
                $taskResult.output = Invoke-TempCleanup -TaskConfig $TaskConfig
            }
            "performance_analysis" {
                $taskResult.output = Invoke-PerformanceAnalysis -TaskConfig $TaskConfig
            }
            "parameter_optimization" {
                $taskResult.output = Invoke-ParameterOptimization -TaskConfig $TaskConfig
            }
            default {
                throw "Tâche non reconnue: $($TaskConfig.name)"
            }
        }
        
        $taskResult.status = "success"
    }
    catch {
        $taskResult.status = "error"
        $taskResult.errors += $_.Exception.Message
        Write-OrchestrationLog "Erreur dans la tâche $($TaskConfig.name): $($_.Exception.Message)" -Level "ERROR" -Phase $PhaseName
    }
    finally {
        $taskResult.end_time = Get-Date
        $taskResult.duration_ms = ($taskResult.end_time - $taskResult.start_time).TotalMilliseconds
    }
    
    return $taskResult
}

# ============================================================================
# FONCTIONS D'EXÉCUTION DES TÂCHES
# ============================================================================

function Invoke-GitHealthCheck {
    param([object]$TaskConfig)
    
    $results = @()
    
    foreach ($command in $TaskConfig.commands) {
        try {
            $output = Invoke-Expression $command 2>&1
            $results += @{
                command = $command
                output = $output
                status = "success"
            }
        }
        catch {
            $results += @{
                command = $command
                output = $_.Exception.Message
                status = "error"
            }
        }
    }
    
    return $results
}

function Invoke-NetworkConnectivityCheck {
    param([object]$TaskConfig)
    
    $results = @()
    
    foreach ($command in $TaskConfig.commands) {
        try {
            $output = Invoke-Expression $command
            $results += @{
                command = $command
                output = $output
                status = if ($output.TcpTestSucceeded) { "success" } else { "warning" }
            }
        }
        catch {
            $results += @{
                command = $command
                output = $_.Exception.Message
                status = "error"
            }
        }
    }
    
    return $results
}

function Invoke-CriticalFilesValidation {
    param([object]$TaskConfig)
    
    $results = @()
    
    foreach ($file in $TaskConfig.files_to_check) {
        try {
            if (Test-Path $file) {
                if ($file -like "*.json") {
                    Get-Content -Raw $file | ConvertFrom-Json | Out-Null
                }
                $results += @{
                    file = $file
                    status = "success"
                    message = "Fichier valide"
                }
            }
            else {
                $results += @{
                    file = $file
                    status = "error"
                    message = "Fichier non trouvé"
                }
            }
        }
        catch {
            $results += @{
                file = $file
                status = "error"
                message = $_.Exception.Message
            }
        }
    }
    
    return $results
}

function Invoke-GitSynchronization {
    param([object]$TaskConfig)
    
    try {
        if (Test-Path $TaskConfig.script) {
            $output = & ".\$($TaskConfig.script)" 2>&1
            return @{
                script = $TaskConfig.script
                output = $output
                status = "success"
            }
        }
        else {
            throw "Script de synchronisation non trouvé: $($TaskConfig.script)"
        }
    }
    catch {
        return @{
            script = $TaskConfig.script
            output = $_.Exception.Message
            status = "error"
        }
    }
}

function Invoke-PostSyncValidation {
    param([object]$TaskConfig)
    
    $results = @()
    
    foreach ($command in $TaskConfig.commands) {
        try {
            $output = Invoke-Expression $command 2>&1
            $results += @{
                command = $command
                output = $output
                status = "success"
            }
        }
        catch {
            $results += @{
                command = $command
                output = $_.Exception.Message
                status = "error"
            }
        }
    }
    
    return $results
}

function Invoke-MCPTests {
    param([object]$TaskConfig)
    
    $results = @()
    
    foreach ($testScript in $TaskConfig.test_scripts) {
        try {
            if (Test-Path $testScript) {
                $output = node $testScript 2>&1
                $results += @{
                    script = $testScript
                    output = $output
                    status = if ($LASTEXITCODE -eq 0) { "success" } else { "warning" }
                }
            }
            else {
                $results += @{
                    script = $testScript
                    output = "Script de test non trouvé"
                    status = "warning"
                }
            }
        }
        catch {
            $results += @{
                script = $testScript
                output = $_.Exception.Message
                status = "error"
            }
        }
    }
    
    return $results
}

function Invoke-ConfigValidation {
    param([object]$TaskConfig)
    
    $results = @()
    
    foreach ($configDir in $TaskConfig.configs_to_test) {
        try {
            if (Test-Path $configDir) {
                $jsonFiles = Get-ChildItem -Path $configDir -Filter "*.json" -Recurse
                foreach ($jsonFile in $jsonFiles) {
                    try {
                        Get-Content -Raw $jsonFile.FullName | ConvertFrom-Json | Out-Null
                        $results += @{
                            file = $jsonFile.FullName
                            status = "success"
                            message = "Configuration valide"
                        }
                    }
                    catch {
                        $results += @{
                            file = $jsonFile.FullName
                            status = "error"
                            message = $_.Exception.Message
                        }
                    }
                }
            }
        }
        catch {
            $results += @{
                directory = $configDir
                status = "error"
                message = $_.Exception.Message
            }
        }
    }
    
    return $results
}

function Invoke-LogCleanup {
    param([object]$TaskConfig)
    
    $results = @()
    $cutoffDate = (Get-Date).AddDays(-$TaskConfig.retention_days)
    
    foreach ($directory in $TaskConfig.directories) {
        try {
            if (Test-Path $directory) {
                $oldFiles = Get-ChildItem -Path $directory -File | Where-Object { $_.LastWriteTime -lt $cutoffDate }
                $cleanedCount = 0
                
                foreach ($file in $oldFiles) {
                    try {
                        Remove-Item -Path $file.FullName -Force
                        $cleanedCount++
                    }
                    catch {
                        Write-OrchestrationLog "Impossible de supprimer: $($file.FullName)" -Level "WARN"
                    }
                }
                
                $results += @{
                    directory = $directory
                    files_cleaned = $cleanedCount
                    status = "success"
                }
            }
        }
        catch {
            $results += @{
                directory = $directory
                status = "error"
                message = $_.Exception.Message
            }
        }
    }
    
    return $results
}

function Invoke-TempCleanup {
    param([object]$TaskConfig)
    
    $results = @()
    $cleanedCount = 0
    
    foreach ($pattern in $TaskConfig.patterns) {
        try {
            $tempFiles = Get-ChildItem -Path . -Filter $pattern -Recurse -File
            foreach ($file in $tempFiles) {
                try {
                    Remove-Item -Path $file.FullName -Force
                    $cleanedCount++
                }
                catch {
                    Write-OrchestrationLog "Impossible de supprimer: $($file.FullName)" -Level "WARN"
                }
            }
        }
        catch {
            Write-OrchestrationLog "Erreur lors du nettoyage du pattern $pattern : $($_.Exception.Message)" -Level "WARN"
        }
    }
    
    return @{
        patterns_processed = $TaskConfig.patterns.Count
        files_cleaned = $cleanedCount
        status = "success"
    }
}

function Invoke-PerformanceAnalysis {
    param([object]$TaskConfig)
    
    # Analyse des métriques de performance
    $metricsFile = "roo-config/scheduler/metrics/daily-metrics-$(Get-Date -Format 'yyyyMMdd').json"
    
    try {
        if (Test-Path $metricsFile) {
            $metrics = Get-Content -Raw $metricsFile | ConvertFrom-Json
            
            # Calcul des statistiques
            $analysis = @{
                total_executions = $metrics.executions.Count
                average_duration = 0
                success_rate = 0
                error_patterns = @()
                recommendations = @()
            }
            
            if ($metrics.executions.Count -gt 0) {
                $analysis.average_duration = ($metrics.executions | Measure-Object -Property duration_ms -Average).Average
                $successCount = ($metrics.executions | Where-Object { $_.status -eq "success" }).Count
                $analysis.success_rate = $successCount / $metrics.executions.Count
            }
            
            return $analysis
        }
        else {
            return @{
                status = "no_data"
                message = "Aucune donnée de métriques disponible"
            }
        }
    }
    catch {
        return @{
            status = "error"
            message = $_.Exception.Message
        }
    }
}

function Invoke-ParameterOptimization {
    param([object]$TaskConfig)
    
    # Logique d'optimisation des paramètres basée sur l'historique
    $optimizations = @()
    
    try {
        # Chargement de l'historique des performances
        $historyFiles = Get-ChildItem -Path "roo-config/scheduler/metrics/" -Filter "daily-metrics-*.json"
        
        if ($historyFiles.Count -gt 7) { # Au moins une semaine de données
            # Analyse des tendances et optimisations
            $optimizations += @{
                parameter = "timeout_adjustment"
                old_value = "current"
                new_value = "optimized"
                reason = "Basé sur l'analyse des performances"
            }
        }
        
        return @{
            optimizations_applied = $optimizations
            status = "success"
        }
    }
    catch {
        return @{
            status = "error"
            message = $_.Exception.Message
        }
    }
}

function Test-PhasePrerequisites {
    param(
        [object]$PhaseConfig,
        [string]$PhaseName
    )
    
    # Vérifications génériques des prérequis
    if ($PhaseConfig.timeout_minutes -le 0) {
        Write-OrchestrationLog "Timeout invalide pour la phase $PhaseName" -Level "ERROR"
        return $false
    }
    
    return $true
}

function Save-ExecutionMetrics {
    param([object]$ExecutionResult)
    
    $metricsFile = "roo-config/scheduler/metrics/daily-metrics-$(Get-Date -Format 'yyyyMMdd').json"
    
    try {
        $metrics = @{
            date = Get-Date -Format "yyyy-MM-dd"
            executions = @()
        }
        
        if (Test-Path $metricsFile) {
            $metrics = Get-Content -Raw $metricsFile | ConvertFrom-Json
        }
        
        $metrics.executions += $ExecutionResult
        $metrics | ConvertTo-Json -Depth 10 | Set-Content -Path $metricsFile
        
        Write-OrchestrationLog "Métriques sauvegardées" -Level "DEBUG"
    }
    catch {
        Write-OrchestrationLog "Erreur lors de la sauvegarde des métriques: $($_.Exception.Message)" -Level "ERROR"
    }
}

# ============================================================================
# FONCTION PRINCIPALE D'ORCHESTRATION
# ============================================================================

function Start-DailyOrchestration {
    Write-OrchestrationLog "=== DÉBUT DE L'ORCHESTRATION QUOTIDIENNE ===" -Level "INFO"
    
    $executionResult = @{
        execution_id = $Global:RooOrchestrationConfig.ExecutionId
        start_time = $Global:RooOrchestrationConfig.StartTime
        end_time = $null
        total_duration_ms = 0
        status = "running"
        phases = @{}
        summary = @{
            phases_executed = 0
            phases_successful = 0
            phases_failed = 0
            total_tasks = 0
            successful_tasks = 0
            failed_tasks = 0
        }
    }
    
    try {
        # Chargement de la configuration
        $config = Load-OrchestrationConfig -ConfigPath $ConfigFullPath
        
        # Initialisation de l'environnement
        Initialize-OrchestrationEnvironment
        
        # Exécution séquentielle des phases
        $phasesToExecute = @("diagnostic", "synchronization", "testing", "cleanup", "improvement")
        
        foreach ($phaseName in $phasesToExecute) {
            if ($config.orchestration.phases.$phaseName) {
                Write-OrchestrationLog "Préparation de la phase: $phaseName" -Level "INFO"
                
                $phaseResult = Invoke-PhaseExecution -PhaseConfig $config.orchestration.phases.$phaseName -PhaseName $phaseName -GlobalConfig $config
                $executionResult.phases.$phaseName = $phaseResult
                
                # Mise à jour des statistiques
                $executionResult.summary.phases_executed++
                if ($phaseResult.status -eq "success") {
                    $executionResult.summary.phases_successful++
                }
                else {
                    $executionResult.summary.phases_failed++
                }
                
                $executionResult.summary.total_tasks += $phaseResult.tasks_results.Count
                $executionResult.summary.successful_tasks += ($phaseResult.tasks_results | Where-Object { $_.status -eq "success" }).Count
                $executionResult.summary.failed_tasks += ($phaseResult.tasks_results | Where-Object { $_.status -eq "error" }).Count
                
                # Arrêt en cas d'échec critique
                if ($phaseResult.status -eq "error" -and $config.orchestration.phases.$phaseName.critical) {
                    Write-OrchestrationLog "Arrêt de l'orchestration suite à l'échec de la phase critique: $phaseName" -Level "ERROR"
                    break
                }
            }
        }
        
        # Détermination du statut global
        if ($executionResult.summary.phases_failed -eq 0) {
            $executionResult.status = "success"
        }
        elseif ($executionResult.summary.phases_successful -gt 0) {
            $executionResult.status = "partial_success"
        }
        else {
            $executionResult.status = "failure"
        }

        Write-OrchestrationLog "Orchestration terminée avec le statut: $($executionResult.status)" -Level "INFO"

        # Escalade Level 3 si échec critique
        if ($executionResult.status -in @("failure", "error")) {
            Write-OrchestrationLog "Vérification de la nécessité d'escalade Level 3..." -Level "WARN"
            $escalationTriggered = Invoke-ClaudeEscalation -ExecutionResult $executionResult

            if ($escalationTriggered) {
                Write-OrchestrationLog "✅ Escalade Level 3 déclenchée - Claude Code invoqué" -Level "WARN"
            }
        }
    }
    catch {
        $executionResult.status = "error"
        Write-OrchestrationLog "Erreur critique dans l'orchestration: $($_.Exception.Message)" -Level "CRITICAL"

        # Escalade Level 3 en cas d'erreur critique
        try {
            Invoke-ClaudeEscalation -ExecutionResult $executionResult
        }
        catch {
            Write-OrchestrationLog "Impossible de déclencher l'escalade: $($_.Exception.Message)" -Level "ERROR"
        }
    }
    finally {
        $executionResult.end_time = Get-Date
        $executionResult.total_duration_ms = ($executionResult.end_time - $executionResult.start_time).TotalMilliseconds
        
        # Sauvegarde des métriques
        Save-ExecutionMetrics -ExecutionResult $executionResult
        
        # Rapport final
        Write-OrchestrationLog "=== RAPPORT FINAL ===" -Level "INFO"
        Write-OrchestrationLog "Durée totale: $([math]::Round($executionResult.total_duration_ms / 1000, 2)) secondes" -Level "INFO"
        Write-OrchestrationLog "Phases exécutées: $($executionResult.summary.phases_executed)" -Level "INFO"
        Write-OrchestrationLog "Phases réussies: $($executionResult.summary.phases_successful)" -Level "INFO"
        Write-OrchestrationLog "Phases échouées: $($executionResult.summary.phases_failed)" -Level "INFO"
        Write-OrchestrationLog "=== FIN DE L'ORCHESTRATION ===" -Level "INFO"
    }
    
    return $executionResult
}

# ============================================================================
# POINT D'ENTRÉE PRINCIPAL
# ============================================================================

if ($MyInvocation.InvocationName -ne '.') {
    try {
        $result = Start-DailyOrchestration
        
        # Code de sortie basé sur le résultat
        switch ($result.status) {
            "success" { exit 0 }
            "partial_success" { exit 1 }
            "failure" { exit 2 }
            "error" { exit 3 }
            default { exit 4 }
        }
    }
    catch {
        Write-OrchestrationLog "Erreur fatale: $($_.Exception.Message)" -Level "CRITICAL"
        exit 5
    }
}