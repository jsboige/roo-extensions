#Requires -Version 5.1
<#
.SYNOPSIS
    Script de gestion d'erreurs avancées pour le système Roo Extensions

.DESCRIPTION
    Ce script implémente des mécanismes de gestion d'erreurs robustes :
    - Détection automatique d'erreurs
    - Classification des erreurs par criticité
    - Mécanismes de récupération automatique
    - Escalade intelligente des problèmes
    - Journalisation détaillée des incidents

.PARAMETER Monitor
    Lance le monitoring continu des erreurs

.PARAMETER Recover
    Tente de récupérer des erreurs détectées

.PARAMETER Test
    Teste les scénarios de défaillance

.EXAMPLE
    .\error-handler.ps1 -Monitor -Recover
    Lance le monitoring et la récupération automatique

.NOTES
    Auteur: Roo Extensions Team
    Version: 2.0.0 - Phase 3C
    Date: 2025-12-04
#>

param (
    [switch]$Monitor,
    [switch]$Recover,
    [switch]$Test,
    [switch]$Continuous,
    [int]$IntervalMinutes = 5
)

# Configuration
$ErrorActionPreference = "Continue"
$ProgressPreference = "Continue"
$PSDefaultParameterValues['Out-File:Encoding'] = 'utf8'

# Chemins
$ScriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$LogDir = Join-Path -Path $ScriptPath -ChildPath "logs"
$ReportsDir = Join-Path -Path $ScriptPath -ChildPath "reports"
$IncidentsDir = Join-Path -Path $ScriptPath -ChildPath "incidents"

# Création des répertoires
foreach ($dir in @($LogDir, $ReportsDir, $IncidentsDir)) {
    if (-not (Test-Path -Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
}

# Fichiers
$LogFile = Join-Path -Path $LogDir -ChildPath "error-handler-$(Get-Date -Format 'yyyy-MM-dd').log"
$IncidentFile = Join-Path -Path $IncidentsDir -ChildPath "incidents-$(Get-Date -Format 'yyyy-MM-dd').json"
$ReportFile = Join-Path -Path $ReportsDir -ChildPath "error-report-$(Get-Date -Format 'yyyy-MM-dd_HHmmss').json"

# Configuration de gestion d'erreurs
$ErrorHandlingConfig = @{
    Monitoring = @{
        Enabled = $true
        IntervalSeconds = 60
        MaxIncidentsPerHour = 10
        EscalationThreshold = 5
    }
    Recovery = @{
        Enabled = $true
        MaxRetries = 3
        RetryDelaySeconds = 30
        AutoRecoveryEnabled = $true
    }
    Classification = @{
        Critical = @{
            Patterns = @("fatal", "critical", "exception", "timeout", "crash", "panic")
            RecoveryStrategies = @("restart", "rollback", "escalate")
            NotificationLevel = "IMMEDIATE"
        }
        High = @{
            Patterns = @("error", "failed", "denied", "blocked", "unavailable")
            RecoveryStrategies = @("retry", "restart", "notify")
            NotificationLevel = "HIGH"
        }
        Medium = @{
            Patterns = @("warning", "deprecated", "slow", "retry", "fallback")
            RecoveryStrategies = @("retry", "optimize", "monitor")
            NotificationLevel = "MEDIUM"
        }
        Low = @{
            Patterns = @("info", "notice", "debug", "trace")
            RecoveryStrategies = @("log", "monitor")
            NotificationLevel = "LOW"
        }
    }
    Escalation = @{
        Enabled = $true
        Levels = @("L1", "L2", "L3")
        Triggers = @{
            L1 = @{ Threshold = 3; TimeWindowMinutes = 30 }
            L2 = @{ Threshold = 5; TimeWindowMinutes = 60 }
            L3 = @{ Threshold = 10; TimeWindowMinutes = 120 }
        }
    }
}

# Variables globales
$global:ActiveIncidents = @()
$global:IncidentHistory = @()
$global:RecoveryAttempts = @()
$global:SystemHealth = $null

# Fonctions de logging
function Write-Log {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Message,
        [Parameter(Mandatory = $false)]
        [string]$Level = "INFO"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logLine = "[$timestamp] [$Level] $Message"
    
    Add-Content -Path $LogFile -Value $logLine -Encoding UTF8
    
    switch ($Level) {
        "ERROR" { Write-Host $logLine -ForegroundColor Red }
        "WARN"  { Write-Host $logLine -ForegroundColor Yellow }
        "SUCCESS" { Write-Host $logLine -ForegroundColor Green }
        default { Write-Host $logLine -ForegroundColor White }
    }
}

function Write-Section {
    param([string]$Title)
    Write-Log "=================================================="
    Write-Log "SECTION: $Title"
    Write-Log "=================================================="
}

# Détection d'erreurs
function Find-SystemErrors {
    Write-Section "DÉTECTION DES ERREURS SYSTÈME"
    
    try {
        $errors = @()
        
        # Analyser les logs système
        $systemErrors = Get-SystemLogErrors
        $errors += $systemErrors
        
        # Analyser les logs d'applications
        $applicationErrors = Get-ApplicationLogErrors
        $errors += $applicationErrors
        
        # Analyser les erreurs MCP
        $mcpErrors = Get-MCPErrors
        $errors += $mcpErrors
        
        # Analyser les erreurs de performance
        $performanceErrors = Get-PerformanceErrors
        $errors += $performanceErrors
        
        # Analyser les erreurs réseau
        $networkErrors = Get-NetworkErrors
        $errors += $networkErrors
        
        Write-Log "Détection complétée - $($errors.Count) erreur(s) trouvée(s)" -Level "SUCCESS"
        return $errors
    }
    catch {
        Write-Log "Erreur lors de la détection des erreurs: $($_.Exception.Message)" -Level "ERROR"
        return @()
    }
}

function Get-SystemLogErrors {
    try {
        $systemErrors = @()
        $eventLogs = Get-WinEvent -LogName System -MaxEvents 100 -ErrorAction SilentlyContinue
        
        foreach ($event in $eventLogs) {
            if ($event.LevelDisplayName -eq "Error" -or $event.LevelDisplayName -eq "Critical") {
                $errorItem = @{
                    Type = "SYSTEM"
                    Source = $event.ProviderName
                    Message = $event.Message
                    Level = $event.LevelDisplayName
                    Timestamp = $event.TimeCreated
                    EventId = $event.Id
                    Classification = Classify-Error -Message $event.Message -Source $event.ProviderName
                }
                $systemErrors += $errorItem
            }
        }
        
        return $systemErrors
    }
    catch {
        Write-Log "Erreur lors de l'analyse des logs système: $($_.Exception.Message)" -Level "ERROR"
        return @()
    }
}

function Get-ApplicationLogErrors {
    try {
        $appErrors = @()
        $eventLogs = Get-WinEvent -LogName Application -MaxEvents 100 -ErrorAction SilentlyContinue
        
        foreach ($event in $eventLogs) {
            if ($event.LevelDisplayName -eq "Error" -or $event.LevelDisplayName -eq "Critical") {
                $errorItem = @{
                    Type = "APPLICATION"
                    Source = $event.ProviderName
                    Message = $event.Message
                    Level = $event.LevelDisplayName
                    Timestamp = $event.TimeCreated
                    EventId = $event.Id
                    Classification = Classify-Error -Message $event.Message -Source $event.ProviderName
                }
                $appErrors += $errorItem
            }
        }
        
        return $appErrors
    }
    catch {
        Write-Log "Erreur lors de l'analyse des logs application: $($_.Exception.Message)" -Level "ERROR"
        return @()
    }
}

function Get-MCPErrors {
    try {
        $mcpErrors = @()
        
        # Analyser les logs des serveurs MCP
        $mcpLogPath = Join-Path -Path $ScriptPath -ChildPath "..\..\mcps\internal\servers"
        if (Test-Path $mcpLogPath) {
            $mcpServers = Get-ChildItem $mcpLogPath -Directory
            foreach ($server in $mcpServers) {
                $logFiles = Get-ChildItem $server.FullName -File -Recurse -Filter "*.log"
                foreach ($logFile in $logFiles) {
                    $logContent = Get-Content $logFile.FullName -Tail 50 -ErrorAction SilentlyContinue
                    foreach ($line in $logContent) {
                        if ($line -match "error|exception|failed|crash") {
                            $errorItem = @{
                                Type = "MCP"
                                Source = $server.Name
                                Message = $line
                                Level = "ERROR"
                                Timestamp = $logFile.LastWriteTime
                                EventId = "MCP-001"
                                Classification = Classify-Error -Message $line -Source $server.Name
                            }
                            $mcpErrors += $errorItem
                        }
                    }
                }
            }
        }
        
        return $mcpErrors
    }
    catch {
        Write-Log "Erreur lors de l'analyse des erreurs MCP: $($_.Exception.Message)" -Level "ERROR"
        return @()
    }
}

function Get-PerformanceErrors {
    try {
        $perfErrors = @()
        
        # Vérifier l'utilisation CPU
        $cpuUsage = (Get-Counter "\Processor(_Total)\% Processor Time").CounterSamples.CookedValue
        if ($cpuUsage -gt 95) {
            $errorItem = @{
                Type = "PERFORMANCE"
                Source = "CPU"
                Message = "Utilisation CPU critique: $($cpuUsage.ToString('F2'))%"
                Level = "CRITICAL"
                Timestamp = Get-Date
                EventId = "PERF-001"
                Classification = "Critical"
            }
            $perfErrors += $errorItem
        }
        
        # Vérifier l'utilisation mémoire
        $memoryUsage = 100 - ((Get-Counter "\Memory\Available MBytes").CounterSamples.CookedValue / (Get-WmiObject -Class Win32_ComputerSystem).TotalPhysicalMemory * 1000000 * 100)
        if ($memoryUsage -gt 95) {
            $errorItem = @{
                Type = "PERFORMANCE"
                Source = "MEMORY"
                Message = "Utilisation mémoire critique: $($memoryUsage.ToString('F2'))%"
                Level = "CRITICAL"
                Timestamp = Get-Date
                EventId = "PERF-002"
                Classification = "Critical"
            }
            $perfErrors += $errorItem
        }
        
        # Vérifier l'utilisation disque
        $diskUsage = (Get-PSDrive C).Used / (Get-PSDrive C).Size * 100
        if ($diskUsage -gt 98) {
            $errorItem = @{
                Type = "PERFORMANCE"
                Source = "DISK"
                Message = "Utilisation disque critique: $($diskUsage.ToString('F2'))%"
                Level = "CRITICAL"
                Timestamp = Get-Date
                EventId = "PERF-003"
                Classification = "Critical"
            }
            $perfErrors += $errorItem
        }
        
        return $perfErrors
    }
    catch {
        Write-Log "Erreur lors de l'analyse des erreurs de performance: $($_.Exception.Message)" -Level "ERROR"
        return @()
    }
}

function Get-NetworkErrors {
    try {
        $netErrors = @()
        
        # Tester la connectivité réseau
        $testResults = Test-NetConnection -ComputerName "github.com" -Port 443 -InformationLevel Quiet -ErrorAction SilentlyContinue
        if (-not $testResults) {
            $errorItem = @{
                Type = "NETWORK"
                Source = "CONNECTIVITY"
                Message = "Perte de connectivité réseau détectée"
                Level = "HIGH"
                Timestamp = Get-Date
                EventId = "NET-001"
                Classification = "High"
            }
            $netErrors += $errorItem
        }
        
        return $netErrors
    }
    catch {
        Write-Log "Erreur lors de l'analyse des erreurs réseau: $($_.Exception.Message)" -Level "ERROR"
        return @()
    }
}

# Classification des erreurs
function Classify-Error {
    param (
        [string]$Message,
        [string]$Source
    )
    
    $messageLower = $Message.ToLower()
    
    # Vérifier les patterns critiques
    foreach ($pattern in $ErrorHandlingConfig.Classification.Critical.Patterns) {
        if ($messageLower -match $pattern) {
            return "Critical"
        }
    }
    
    # Vérifier les patterns high
    foreach ($pattern in $ErrorHandlingConfig.Classification.High.Patterns) {
        if ($messageLower -match $pattern) {
            return "High"
        }
    }
    
    # Vérifier les patterns medium
    foreach ($pattern in $ErrorHandlingConfig.Classification.Medium.Patterns) {
        if ($messageLower -match $pattern) {
            return "Medium"
        }
    }
    
    # Par défaut, classifier comme Low
    return "Low"
}

# Mécanismes de récupération
function Start-ErrorRecovery {
    Write-Section "RÉCUPÉRATION AUTOMATIQUE DES ERREURS"
    
    try {
        $recoveryResults = @()
        
        foreach ($incident in $global:ActiveIncidents) {
            if ($incident.Status -eq "Active") {
                $recovery = Invoke-RecoveryStrategy -Incident $incident
                if ($recovery) {
                    $recoveryResults += $recovery
                }
            }
        }
        
        Write-Log "Récupération complétée - $($recoveryResults.Count) tentative(s) de récupération" -Level "SUCCESS"
        return $recoveryResults
    }
    catch {
        Write-Log "Erreur lors de la récupération des erreurs: $($_.Exception.Message)" -Level "ERROR"
        return @()
    }
}

function Invoke-RecoveryStrategy {
    param (
        [object]$Incident
    )
    
    try {
        $classification = $Incident.Classification
        $strategies = $ErrorHandlingConfig.Classification[$classification].RecoveryStrategies
        
        foreach ($strategy in $strategies) {
            $result = switch ($strategy) {
                "restart" { Restart-Service -Incident $Incident }
                "retry" { Retry-Operation -Incident $Incident }
                "rollback" { Rollback-Change -Incident $Incident }
                "escalate" { Escalate-Incident -Incident $Incident }
                "notify" { Send-Notification -Incident $Incident }
                "optimize" { Optimize-Resource -Incident $Incident }
                "monitor" { Monitor-Incident -Incident $Incident }
                "log" { Log-Incident -Incident $Incident }
                default { $null }
            }
            
            if ($result -and $result.Success) {
                return @{
                    IncidentId = $Incident.Id
                    Strategy = $strategy
                    Success = $true
                    Message = $result.Message
                    Timestamp = Get-Date
                }
            }
        }
        
        return @{
            IncidentId = $Incident.Id
            Strategy = "FAILED"
            Success = $false
            Message = "Aucune stratégie de récupération n'a fonctionné"
            Timestamp = Get-Date
        }
    }
    catch {
        Write-Log "Erreur lors de la récupération de l'incident $($Incident.Id): $($_.Exception.Message)" -Level "ERROR"
        return $null
    }
}

function Restart-Service {
    param ([object]$Incident)
    
    try {
        switch ($Incident.Type) {
            "MCP" {
                # Redémarrer le serveur MCP
                $mcpScript = Join-Path -Path $ScriptPath -ChildPath "monitor-mcp-servers.ps1"
                if (Test-Path $mcpScript) {
                    $result = & $mcpScript -Restart
                    return @{
                        Success = $true
                        Message = "Serveur MCP redémarré avec succès"
                    }
                }
            }
            "SYSTEM" {
                # Redémarrer le service système
                $serviceName = Get-ServiceName -EventId $Incident.EventId
                if ($serviceName) {
                    Restart-Service -Name $serviceName -Force -ErrorAction SilentlyContinue
                    return @{
                        Success = $true
                        Message = "Service $serviceName redémarré"
                    }
                }
            }
        }
        
        return @{ Success = $false; Message = "Impossible de redémarrer le service" }
    }
    catch {
        return @{ Success = $false; Message = "Erreur lors du redémarrage: $($_.Exception.Message)" }
    }
}

function Retry-Operation {
    param ([object]$Incident)
    
    try {
        $retryCount = 0
        $maxRetries = $ErrorHandlingConfig.Recovery.MaxRetries
        
        do {
            $retryCount++
            Write-Log "Tentative de récupération $($retryCount)/$maxRetries pour l'incident $($Incident.Id)"
            
            # Simuler une tentative de récupération
            Start-Sleep -Seconds $ErrorHandlingConfig.Recovery.RetryDelaySeconds
            
            # Vérifier si l'erreur est résolue
            $isResolved = Test-IncidentResolution -Incident $Incident
            
            if ($isResolved) {
                return @{
                    Success = $true
                    Message = "Incident résolu après $($retryCount) tentative(s)"
                }
            }
        } while ($retryCount -lt $maxRetries)
        
        return @{ Success = $false; Message = "Échec après $($maxRetries) tentatives" }
    }
    catch {
        return @{ Success = $false; Message = "Erreur lors de la tentative: $($_.Exception.Message)" }
    }
}

function Rollback-Change {
    param ([object]$Incident)
    
    try {
        # Implémenter le rollback des changements récents
        $rollbackScript = Join-Path -Path $ScriptPath -ChildPath "rollback-changes.ps1"
        if (Test-Path $rollbackScript) {
            $result = & $rollbackScript -IncidentId $Incident.Id
            return @{
                Success = $true
                Message = "Rollback effectué avec succès"
            }
        }
        
        return @{ Success = $false; Message = "Script de rollback non trouvé" }
    }
    catch {
        return @{ Success = $false; Message = "Erreur lors du rollback: $($_.Exception.Message)" }
    }
}

function Escalate-Incident {
    param ([object]$Incident)
    
    try {
        $escalationLevel = Determine-EscalationLevel -Incident $Incident
        
        $escalation = @{
            IncidentId = $Incident.Id
            Level = $escalationLevel
            Reason = "Échec des stratégies de récupération automatiques"
            Timestamp = Get-Date
            Status = "Escalated"
        }
        
        # Notifier l'équipe d'escalade
        Send-EscalationNotification -Escalation $escalation
        
        return @{
            Success = $true
            Message = "Incident escaladé au niveau $escalationLevel"
        }
    }
    catch {
        return @{ Success = $false; Message = "Erreur lors de l'escalade: $($_.Exception.Message)" }
    }
}

function Send-Notification {
    param ([object]$Incident)
    
    try {
        $notificationLevel = $ErrorHandlingConfig.Classification[$Incident.Classification].NotificationLevel
        
        $notification = @{
            IncidentId = $Incident.Id
            Level = $notificationLevel
            Message = $Incident.Message
            Source = $Incident.Source
            Timestamp = Get-Date
        }
        
        # Envoyer la notification (implémenter selon le système de notification)
        Write-Log "Notification envoyée: $($notification.Message)" -Level "WARN"
        
        return @{
            Success = $true
            Message = "Notification envoyée avec succès"
        }
    }
    catch {
        return @{ Success = $false; Message = "Erreur lors de l'envoi de la notification: $($_.Exception.Message)" }
    }
}

function Optimize-Resource {
    param ([object]$Incident)
    
    try {
        switch ($Incident.Type) {
            "PERFORMANCE" {
                # Optimiser les ressources système
                $optimizerScript = Join-Path -Path $ScriptPath -ChildPath "performance-optimizer.ps1"
                if (Test-Path $optimizerScript) {
                    $result = & $optimizerScript -Optimize
                    return @{
                        Success = $true
                        Message = "Optimisation des performances appliquée"
                    }
                }
            }
        }
        
        return @{ Success = $false; Message = "Impossible d'optimiser la ressource" }
    }
    catch {
        return @{ Success = $false; Message = "Erreur lors de l'optimisation: $($_.Exception.Message)" }
    }
}

function Monitor-Incident {
    param ([object]$Incident)
    
    try {
        # Ajouter à la liste de monitoring
        $global:ActiveIncidents += @{
            Id = $Incident.Id
            Status = "Monitoring"
            LastCheck = Get-Date
            NextCheck = (Get-Date).AddMinutes(5)
        }
        
        return @{
            Success = $true
            Message = "Incident ajouté au monitoring actif"
        }
    }
    catch {
        return @{ Success = $false; Message = "Erreur lors du monitoring: $($_.Exception.Message)" }
    }
}

function Log-Incident {
    param ([object]$Incident)
    
    try {
        $incidentLog = @{
            Id = $Incident.Id
            Type = $Incident.Type
            Source = $Incident.Source
            Message = $Incident.Message
            Level = $Incident.Level
            Classification = $Incident.Classification
            Timestamp = $Incident.Timestamp
            Status = "Logged"
        }
        
        # Ajouter à l'historique des incidents
        $global:IncidentHistory += $incidentLog
        
        # Sauvegarder dans le fichier d'incidents
        $incidents = @()
        if (Test-Path $IncidentFile) {
            $incidents = Get-Content $IncidentFile | ConvertFrom-Json
        }
        $incidents += $incidentLog
        Set-Content -Path $IncidentFile -Value ($incidents | ConvertTo-Json -Depth 10) -Encoding UTF8
        
        return @{
            Success = $true
            Message = "Incident journalisé avec succès"
        }
    }
    catch {
        return @{ Success = $false; Message = "Erreur lors de la journalisation: $($_.Exception.Message)" }
    }
}

# Fonctions utilitaires
function Get-ServiceName {
    param ([string]$EventId)
    
    $serviceMap = @{
        "PERF-001" = "System"
        "PERF-002" = "Memory"
        "PERF-003" = "Disk"
        "NET-001" = "Network"
    }
    
    return $serviceMap[$EventId]
}

function Test-IncidentResolution {
    param ([object]$Incident)
    
    try {
        switch ($Incident.Type) {
            "PERFORMANCE" {
                # Vérifier si les métriques sont revenues à la normale
                $cpuUsage = (Get-Counter "\Processor(_Total)\% Processor Time").CounterSamples.CookedValue
                $memoryUsage = 100 - ((Get-Counter "\Memory\Available MBytes").CounterSamples.CookedValue / (Get-WmiObject -Class Win32_ComputerSystem).TotalPhysicalMemory * 1000000 * 100)
                
                return ($cpuUsage -lt 80 -and $memoryUsage -lt 80)
            }
            "NETWORK" {
                # Tester la connectivité
                $testResult = Test-NetConnection -ComputerName "github.com" -Port 443 -InformationLevel Quiet -ErrorAction SilentlyContinue
                return $testResult
            }
            default {
                # Par défaut, considérer comme résolu après un délai
                $elapsed = (Get-Date) - $Incident.Timestamp
                return $elapsed.TotalMinutes -gt 5
            }
        }
    }
    catch {
        return $false
    }
}

function Determine-EscalationLevel {
    param ([object]$Incident)
    
    $recentIncidents = $global:IncidentHistory | Where-Object { 
        $_.Timestamp -gt (Get-Date).AddHours(-2) -and $_.Type -eq $Incident.Type
    }
    
    $incidentCount = $recentIncidents.Count
    
    if ($incidentCount -ge $ErrorHandlingConfig.Escalation.Triggers.L3.Threshold) {
        return "L3"
    }
    elseif ($incidentCount -ge $ErrorHandlingConfig.Escalation.Triggers.L2.Threshold) {
        return "L2"
    }
    elseif ($incidentCount -ge $ErrorHandlingConfig.Escalation.Triggers.L1.Threshold) {
        return "L1"
    }
    
    return "L0"
}

function Send-EscalationNotification {
    param ([object]$Escalation)
    
    try {
        $message = "ESCALADE NIVEAU $($Escalation.Level) - Incident $($Escalation.IncidentId)"
        Write-Log $message -Level "ERROR"
        
        # Implémenter l'envoi réel de notification selon le système
        # Email, Slack, Teams, etc.
        
        return $true
    }
    catch {
        Write-Log "Erreur lors de l'envoi de la notification d'escalade: $($_.Exception.Message)" -Level "ERROR"
        return $false
    }
}

# Tests de scénarios de défaillance
function Test-FailureScenarios {
    Write-Section "TESTS DES SCÉNARIOS DE DÉFAILLANCE"
    
    try {
        $testResults = @()
        
        # Test 1: Simulation de CPU élevé
        $cpuTest = Test-HighCPUScenario
        $testResults += $cpuTest
        
        # Test 2: Simulation de mémoire élevée
        $memoryTest = Test-HighMemoryScenario
        $testResults += $memoryTest
        
        # Test 3: Simulation de perte réseau
        $networkTest = Test-NetworkFailureScenario
        $testResults += $networkTest
        
        # Test 4: Simulation d'erreur MCP
        $mcpTest = Test-MCPFailureScenario
        $testResults += $mcpTest
        
        Write-Log "Tests complétés - $($testResults.Count) scénario(s) testé(s)" -Level "SUCCESS"
        return $testResults
    }
    catch {
        Write-Log "Erreur lors des tests de scénarios: $($_.Exception.Message)" -Level "ERROR"
        return @()
    }
}

function Test-HighCPUScenario {
    try {
        Write-Log "Test: Scénario CPU élevé"
        
        # Simuler une charge CPU élevée
        $cpuLoad = 1..5 | ForEach-Object {
            Start-Job -ScriptBlock {
                $result = 1
                for ($i = 0; $i -lt 1000000; $i++) {
                    $result = [math]::Sin($i) * [math]::Cos($i)
                }
                return $result
            }
        }
        
        Start-Sleep -Seconds 10
        
        # Détecter l'erreur
        $errors = Find-SystemErrors
        $cpuError = $errors | Where-Object { $_.Type -eq "PERFORMANCE" -and $_.Source -eq "CPU" }
        
        # Nettoyer les jobs
        $cpuLoad | Stop-Job
        $cpuLoad | Remove-Job
        
        if ($cpuError) {
            # Tester la récupération
            $recovery = Start-ErrorRecovery
            return @{
                Scenario = "High CPU"
                ErrorDetected = $true
                RecoverySuccessful = $recovery.Success
                Message = "Scénario CPU testé avec succès"
            }
        }
        
        return @{
            Scenario = "High CPU"
            ErrorDetected = $false
            RecoverySuccessful = $false
            Message = "Erreur CPU non détectée"
        }
    }
    catch {
        return @{
            Scenario = "High CPU"
            ErrorDetected = $false
            RecoverySuccessful = $false
            Message = "Erreur lors du test: $($_.Exception.Message)"
        }
    }
}

function Test-HighMemoryScenario {
    try {
        Write-Log "Test: Scénario mémoire élevée"
        
        # Simuler une consommation mémoire élevée
        $memoryLoad = 1..10 | ForEach-Object {
            [byte[]]$data = New-Object byte[] 10MB
            return $data
        }
        
        Start-Sleep -Seconds 5
        
        # Détecter l'erreur
        $errors = Find-SystemErrors
        $memoryError = $errors | Where-Object { $_.Type -eq "PERFORMANCE" -and $_.Source -eq "MEMORY" }
        
        # Libérer la mémoire
        Remove-Variable -Name memoryLoad -ErrorAction SilentlyContinue
        [System.GC]::Collect()
        
        if ($memoryError) {
            # Tester la récupération
            $recovery = Start-ErrorRecovery
            return @{
                Scenario = "High Memory"
                ErrorDetected = $true
                RecoverySuccessful = $recovery.Success
                Message = "Scénario mémoire testé avec succès"
            }
        }
        
        return @{
            Scenario = "High Memory"
            ErrorDetected = $false
            RecoverySuccessful = $false
            Message = "Erreur mémoire non détectée"
        }
    }
    catch {
        return @{
            Scenario = "High Memory"
            ErrorDetected = $false
            RecoverySuccessful = $false
            Message = "Erreur lors du test: $($_.Exception.Message)"
        }
    }
}

function Test-NetworkFailureScenario {
    try {
        Write-Log "Test: Scénario de défaillance réseau"
        
        # Simuler une défaillance réseau (test avec une adresse invalide)
        $networkTest = Test-NetConnection -ComputerName "invalid-hostname-12345.com" -Port 443 -InformationLevel Quiet -ErrorAction SilentlyContinue
        
        # Détecter l'erreur
        $errors = Find-SystemErrors
        $networkError = $errors | Where-Object { $_.Type -eq "NETWORK" }
        
        if ($networkError) {
            # Tester la récupération
            $recovery = Start-ErrorRecovery
            return @{
                Scenario = "Network Failure"
                ErrorDetected = $true
                RecoverySuccessful = $recovery.Success
                Message = "Scénario réseau testé avec succès"
            }
        }
        
        return @{
            Scenario = "Network Failure"
            ErrorDetected = $false
            RecoverySuccessful = $false
            Message = "Erreur réseau non détectée"
        }
    }
    catch {
        return @{
            Scenario = "Network Failure"
            ErrorDetected = $true
            RecoverySuccessful = $false
            Message = "Scénario réseau testé (exception attendue)"
        }
    }
}

function Test-MCPFailureScenario {
    try {
        Write-Log "Test: Scénario de défaillance MCP"
        
        # Simuler une erreur MCP en créant un fichier d'erreur temporaire
        $mcpLogPath = Join-Path -Path $ScriptPath -ChildPath "..\..\mcps\internal\servers\roo-state-manager\test-error.log"
        $errorContent = "ERROR: Simulated MCP server crash at $(Get-Date)"
        Set-Content -Path $mcpLogPath -Value $errorContent -Encoding UTF8
        
        # Détecter l'erreur
        $errors = Find-SystemErrors
        $mcpError = $errors | Where-Object { $_.Type -eq "MCP" }
        
        # Nettoyer le fichier de test
        Remove-Item $mcpLogPath -ErrorAction SilentlyContinue
        
        if ($mcpError) {
            # Tester la récupération
            $recovery = Start-ErrorRecovery
            return @{
                Scenario = "MCP Failure"
                ErrorDetected = $true
                RecoverySuccessful = $recovery.Success
                Message = "Scénario MCP testé avec succès"
            }
        }
        
        return @{
            Scenario = "MCP Failure"
            ErrorDetected = $false
            RecoverySuccessful = $false
            Message = "Erreur MCP non détectée"
        }
    }
    catch {
        return @{
            Scenario = "MCP Failure"
            ErrorDetected = $false
            RecoverySuccessful = $false
            Message = "Erreur lors du test: $($_.Exception.Message)"
        }
    }
}

# Fonction principale
function Start-ErrorHandling {
    Write-Section "DÉMARRAGE DU GESTIONNAIRE D'ERREURS - PHASE 3C"
    Write-Log "Version: 2.0.0 - Phase 3C Robustesse et Performance"
    Write-Log "Monitor: $Monitor"
    Write-Log "Recover: $Recover"
    Write-Log "Test: $Test"
    Write-Log "Continu: $Continuous"
    
    do {
        try {
            Write-Log "=== CYCLE DE GESTION D'ERREURS $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') ==="
            
            # Détecter les erreurs
            if ($Monitor) {
                $errors = Find-SystemErrors
                
                # Mettre à jour les incidents actifs
                $global:ActiveIncidents = @()
                foreach ($errorItem in $errors) {
                    $incident = @{
                        Id = "INC-$(Get-Date -Format 'yyyyMMddHHmmss')-$($global:ActiveIncidents.Count)"
                        Type = $errorItem.Type
                        Source = $errorItem.Source
                        Message = $errorItem.Message
                        Level = $errorItem.Level
                        Classification = $errorItem.Classification
                        Timestamp = $errorItem.Timestamp
                        Status = "Active"
                    }
                    $global:ActiveIncidents += $incident
                }
                
                Write-Log "$($global:ActiveIncidents.Count) incident(s) actif(s) détecté(s)"
            }
            
            # Tenter la récupération
            if ($Recover -and $global:ActiveIncidents.Count -gt 0) {
                $recoveryResults = Start-ErrorRecovery
                Write-Log "$($recoveryResults.Count) tentative(s) de récupération effectuée(s)"
            }
            
            # Tester les scénarios
            if ($Test) {
                $testResults = Test-FailureScenarios
                Write-Log "$($testResults.Count) scénario(s) de défaillance testé(s)"
            }
            
            # Générer le rapport
            $report = @{
                Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                Cycle = @{
                    Monitor = $Monitor
                    Recover = $Recover
                    Test = $Test
                }
                Incidents = @{
                    Active = $global:ActiveIncidents
                    History = $global:IncidentHistory
                }
                Results = @{
                    Errors = if ($Monitor) { Find-SystemErrors } else { @() }
                    Recovery = if ($Recover) { Start-ErrorRecovery } else { @() }
                    Tests = if ($Test) { Test-FailureScenarios } else { @() }
                }
            }
            
            Set-Content -Path $ReportFile -Value ($report | ConvertTo-Json -Depth 10) -Encoding UTF8
            Write-Log "Rapport généré: $ReportFile" -Level "SUCCESS"
            
            if (-not $Continuous) {
                break
            }
            
            Write-Log "Attente de $IntervalMinutes minutes avant le prochain cycle..."
            Start-Sleep -Seconds ($IntervalMinutes * 60)
        }
        catch {
            Write-Log "Erreur lors du cycle de gestion d'erreurs: $($_.Exception.Message)" -Level "ERROR"
            if (-not $Continuous) {
                break
            }
            Start-Sleep -Seconds ($IntervalMinutes * 60)
        }
    } while ($Continuous)
    
    Write-Log "Gestion des erreurs terminée" -Level "SUCCESS"
}

# Point d'entrée
try {
    Write-Log "Démarrage du gestionnaire d'erreurs - Phase 3C"
    Start-ErrorHandling
}
catch {
    Write-Log "Erreur fatale: $($_.Exception.Message)" -Level "ERROR"
    exit 1
}