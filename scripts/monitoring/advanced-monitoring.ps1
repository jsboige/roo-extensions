#Requires -Version 5.1
<#
.SYNOPSIS
    Script de monitoring avancé pour le système Roo Extensions Phase 3C

.DESCRIPTION
    Ce script implémente un système de monitoring complet avec :
    - Métriques temps réel
    - Alertes automatiques
    - Tableau de bord HTML
    - Analyse de performance
    - Détection de goulots d'étranglement
    - Gestion d'erreurs avancée

.PARAMETER Dashboard
    Génère un tableau de bord HTML interactif

.PARAMETER Alerts
    Active les alertes automatiques

.PARAMETER Performance
    Lance l'analyse de performance approfondie

.PARAMETER Continuous
    Mode monitoring continu (boucle infinie)

.EXAMPLE
    .\advanced-monitoring.ps1 -Dashboard -Alerts
    Génère le dashboard et active les alertes

.NOTES
    Auteur: Roo Extensions Team
    Version: 2.0.0 - Phase 3C
    Date: 2025-12-04
#>

param (
    [switch]$Dashboard,
    [switch]$Alerts,
    [switch]$Performance,
    [switch]$Continuous,
    [int]$IntervalSeconds = 60
)

# Configuration globale
$ErrorActionPreference = "Stop"
$ProgressPreference = "Continue"
$PSDefaultParameterValues['Out-File:Encoding'] = 'utf8'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# Chemins et configuration
$ScriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$LogDir = Join-Path -Path $ScriptPath -ChildPath "logs"
$ReportsDir = Join-Path -Path $ScriptPath -ChildPath "reports"
$DashboardDir = Join-Path -Path $ScriptPath -ChildPath "dashboard"
$ConfigFile = Join-Path -Path $ScriptPath -ChildPath "monitoring-config.json"

# Création des répertoires
foreach ($dir in @($LogDir, $ReportsDir, $DashboardDir)) {
    if (-not (Test-Path -Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
}

# Fichiers de log et rapport
$LogFile = Join-Path -Path $LogDir -ChildPath "advanced-monitoring-$(Get-Date -Format 'yyyy-MM-dd').log"
$MetricsFile = Join-Path -Path $ReportsDir -ChildPath "metrics-$(Get-Date -Format 'yyyy-MM-dd_HHmmss').json"
$DashboardFile = Join-Path -Path $DashboardDir -ChildPath "dashboard.html"

# Configuration des seuils d'alerte
$AlertThresholds = @{
    System = @{
        MemoryUsage = 80      # %
        CPUUsage = 85         # %
        DiskUsage = 90        # %
        NetworkLatency = 1000 # ms
    }
    MCP = @{
        ResponseTime = 5000   # ms
        SuccessRate = 95      # %
        ActiveConnections = 50
        ErrorRate = 5         # %
    }
    Performance = @{
        TaskExecutionTime = 30000 # ms
        QueueSize = 100
        CacheHitRate = 80     # %
        Throughput = 1000     # ops/min
    }
}

# Variables globales
$global:Metrics = @{}
$global:Alerts = @()
$global:PerformanceHistory = @()
$global:SystemHealth = "HEALTHY"

# Fonctions de logging
function Write-Log {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Message,
        [Parameter(Mandatory = $false)]
        [string]$Level = "INFO",
        [Parameter(Mandatory = $false)]
        [switch]$NoConsole
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logLine = "[$timestamp] [$Level] $Message"
    
    # Écrire dans le fichier de log
    Add-Content -Path $LogFile -Value $logLine -Encoding UTF8
    
    # Afficher dans la console si demandé
    if (-not $NoConsole) {
        switch ($Level) {
            "ERROR" { Write-Host $logLine -ForegroundColor Red }
            "WARN"  { Write-Host $logLine -ForegroundColor Yellow }
            "SUCCESS" { Write-Host $logLine -ForegroundColor Green }
            default { Write-Host $logLine -ForegroundColor White }
        }
    }
}

function Write-Section {
    param([string]$Title)
    Write-Log "=================================================="
    Write-Log "SECTION: $Title"
    Write-Log "=================================================="
}

# Fonctions de collecte de métriques système
function Get-SystemMetrics {
    Write-Log "Collecte des métriques système..."
    
    try {
        $metrics = @{
            Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            Memory = @{
                Usage = [math]::Round((Get-Counter "\Memory\Available MBytes").CounterSamples.CookedValue / (Get-WmiObject -Class Win32_ComputerSystem).TotalPhysicalMemory * 1000000 * 100, 2)
                Available = [math]::Round((Get-Counter "\Memory\Available MBytes").CounterSamples.CookedValue, 2)
                Total = [math]::Round((Get-WmiObject -Class Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 2)
            }
            CPU = @{
                Usage = [math]::Round((Get-Counter "\Processor(_Total)\% Processor Time").CounterSamples.CookedValue, 2)
                Cores = (Get-WmiObject -Class Win32_Processor).NumberOfCores
            }
            Disk = @{
                Usage = [math]::Round((Get-PSDrive C).Used / (Get-PSDrive C).Size * 100, 2)
                Free = [math]::Round((Get-PSDrive C).Free / 1GB, 2)
                Total = [math]::Round((Get-PSDrive C).Used / 1GB + (Get-PSDrive C).Free / 1GB, 2)
            }
            Network = @{
                Latency = Test-NetworkLatency
                Bandwidth = Get-NetworkBandwidth
            }
            Processes = @{
                Total = (Get-Process).Count
                Active = (Get-Process | Where-Object { $_.CPU -gt 0 }).Count
            }
        }
        
        Write-Log "Métriques système collectées avec succès" -Level "SUCCESS"
        return $metrics
    }
    catch {
        Write-Log "Erreur lors de la collecte des métriques système: $($_.Exception.Message)" -Level "ERROR"
        return $null
    }
}

function Test-NetworkLatency {
    try {
        $result = Test-NetConnection -ComputerName "github.com" -Port 443 -InformationLevel Quiet
        $latency = (Measure-Command { $result }).TotalMilliseconds
        return [math]::Round($latency, 2)
    }
    catch {
        return 9999 # Valeur d'erreur
    }
}

function Get-NetworkBandwidth {
    try {
        $adapter = Get-NetAdapter | Where-Object { $_.Status -eq "Up" } | Select-Object -First 1
        if ($adapter) {
            return @{
                Name = $adapter.Name
                Speed = $adapter.LinkSpeed / 1MB
                Status = $adapter.Status
            }
        }
        return $null
    }
    catch {
        return $null
    }
}

# Fonctions de monitoring MCP
function Get-MCPMetrics {
    Write-Log "Collecte des métriques MCP..."
    
    try {
        $mcpMetrics = @{
            Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            Servers = @()
            Global = @{
                TotalServers = 0
                ActiveServers = 0
                AverageResponseTime = 0
                SuccessRate = 0
            }
        }
        
        # Vérifier les serveurs MCP connus
        $mcpServers = @(
            @{ Name = "quickfiles"; Port = 3003; Path = "mcps/internal/servers/quickfiles-server" },
            @{ Name = "jupyter"; Port = 3001; Path = "mcps/internal/servers/jupyter-mcp-server" },
            @{ Name = "jinavigator"; Port = 3002; Path = "mcps/internal/servers/jinavigator-server" },
            @{ Name = "searxng"; Port = 3004; Path = "mcps/internal/servers/searxng-server" },
            @{ Name = "roo-state-manager"; Port = 3005; Path = "mcps/internal/servers/roo-state-manager" }
        )
        
        $totalResponseTime = 0
        $activeCount = 0
        
        foreach ($server in $mcpServers) {
            $serverMetrics = Test-MCPServer -Server $server
            $mcpMetrics.Servers += $serverMetrics
            
            if ($serverMetrics.Status -eq "ACTIVE") {
                $totalResponseTime += $serverMetrics.ResponseTime
                $activeCount++
            }
        }
        
        $mcpMetrics.Global.TotalServers = $mcpServers.Count
        $mcpMetrics.Global.ActiveServers = $activeCount
        $mcpMetrics.Global.AverageResponseTime = if ($activeCount -gt 0) { [math]::Round($totalResponseTime / $activeCount, 2) } else { 0 }
        $mcpMetrics.Global.SuccessRate = [math]::Round(($activeCount / $mcpServers.Count) * 100, 2)
        
        Write-Log "Métriques MCP collectées: $($mcpMetrics.Global.ActiveServers)/$($mcpMetrics.Global.TotalServers) serveurs actifs" -Level "SUCCESS"
        return $mcpMetrics
    }
    catch {
        Write-Log "Erreur lors de la collecte des métriques MCP: $($_.Exception.Message)" -Level "ERROR"
        return $null
    }
}

function Test-MCPServer {
    param(
        [hashtable]$Server
    )
    
    $serverMetrics = @{
        Name = $Server.Name
        Port = $Server.Port
        Status = "INACTIVE"
        ResponseTime = 0
        ProcessID = $null
        MemoryUsage = 0
        CPUUsage = 0
        LastCheck = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    }
    
    try {
        # Vérifier si le processus est en cours d'exécution
        $processes = Get-Process -Name "node" -ErrorAction SilentlyContinue
        $serverProcess = $processes | Where-Object { $_.CommandLine -like "*$($Server.Name)*" } | Select-Object -First 1
        
        if ($serverProcess) {
            $serverMetrics.ProcessID = $serverProcess.Id
            $serverMetrics.MemoryUsage = [math]::Round($serverProcess.WorkingSet64 / 1MB, 2)
            $serverMetrics.CPUUsage = [math]::Round($serverProcess.CPU, 2)
            
            # Test de connexion HTTP
            $response = Invoke-WebRequest -Uri "http://localhost:$($Server.Port)/health" -TimeoutSec 5 -UseBasicParsing -ErrorAction Stop
            if ($response.StatusCode -eq 200) {
                $serverMetrics.Status = "ACTIVE"
                $serverMetrics.ResponseTime = [math]::Round((Measure-Command { $response }).TotalMilliseconds, 2)
            }
        }
    }
    catch {
        # Le serveur n'est pas accessible
        $serverMetrics.Status = "INACTIVE"
    }
    
    return $serverMetrics
}

# Fonctions d'analyse de performance
function Get-PerformanceMetrics {
    Write-Log "Analyse des performances système..."
    
    try {
        $performanceMetrics = @{
            Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            System = @{
                BootTime = (Get-CimInstance -ClassName Win32_OperatingSystem).LastBootUpTime
                Uptime = (Get-Date) - (Get-CimInstance -ClassName Win32_OperatingSystem).LastBootUpTime
                ContextSwitches = (Get-Counter "\System\Context Switches/sec").CounterSamples.CookedValue
                ProcessorQueueLength = (Get-Counter "\System\Processor Queue Length").CounterSamples.CookedValue
            }
            Memory = @{
                PagesPerSec = (Get-Counter "\Memory\Pages/sec").CounterSamples.CookedValue
                CacheFaultsPerSec = (Get-Counter "\Memory\Cache Faults/sec").CounterSamples.CookedValue
                CommittedBytes = (Get-Counter "\Memory\Committed Bytes").CounterSamples.CookedValue
                AvailableMBytes = (Get-Counter "\Memory\Available MBytes").CounterSamples.CookedValue
            }
            Disk = @{
                AvgDiskQueueLength = (Get-Counter "\PhysicalDisk(_Total)\Avg. Disk Queue Length").CounterSamples.CookedValue
                DiskReadBytesPerSec = (Get-Counter "\PhysicalDisk(_Total)\Disk Read Bytes/sec").CounterSamples.CookedValue
                DiskWriteBytesPerSec = (Get-Counter "\PhysicalDisk(_Total)\Disk Write Bytes/sec").CounterSamples.CookedValue
                PercentDiskTime = (Get-Counter "\PhysicalDisk(_Total)\% Disk Time").CounterSamples.CookedValue
            }
            Network = @{
                BytesReceivedPerSec = (Get-Counter "\Network Interface(*)\Bytes Received/sec").CounterSamples.CookedValue
                BytesSentPerSec = (Get-Counter "\Network Interface(*)\Bytes Sent/sec").CounterSamples.CookedValue
                OutputQueueLength = (Get-Counter "\Network Interface(*)\Output Queue Length").CounterSamples.CookedValue
            }
        }
        
        # Calculer les métriques dérivées
        $performanceMetrics.Derived = @{
            SystemEfficiency = Calculate-SystemEfficiency $performanceMetrics
            BottleneckDetection = Detect-Bottlenecks $performanceMetrics
            PerformanceScore = Calculate-PerformanceScore $performanceMetrics
        }
        
        Write-Log "Analyse de performance complétée - Score: $($performanceMetrics.Derived.PerformanceScore)" -Level "SUCCESS"
        return $performanceMetrics
    }
    catch {
        Write-Log "Erreur lors de l'analyse de performance: $($_.Exception.Message)" -Level "ERROR"
        return $null
    }
}

function Calculate-SystemEfficiency {
    param([hashtable]$Metrics)
    
    $cpuScore = [math]::Max(0, 100 - $Metrics.System.ProcessorQueueLength * 10)
    $memoryScore = [math]::Max(0, 100 - $Metrics.Memory.PagesPerSec / 100)
    $diskScore = [math]::Max(0, 100 - $Metrics.Disk.PercentDiskTime)
    
    return [math]::Round(($cpuScore + $memoryScore + $diskScore) / 3, 2)
}

function Detect-Bottlenecks {
    param([hashtable]$Metrics)
    
    $bottlenecks = @()
    
    if ($Metrics.System.ProcessorQueueLength -gt 2) {
        $bottlenecks += @{ Type = "CPU"; Severity = "HIGH"; Value = $Metrics.System.ProcessorQueueLength }
    }
    
    if ($Metrics.Memory.PagesPerSec -gt 1000) {
        $bottlenecks += @{ Type = "MEMORY"; Severity = "HIGH"; Value = $Metrics.Memory.PagesPerSec }
    }
    
    if ($Metrics.Disk.PercentDiskTime -gt 80) {
        $bottlenecks += @{ Type = "DISK"; Severity = "MEDIUM"; Value = $Metrics.Disk.PercentDiskTime }
    }
    
    if ($Metrics.Disk.AvgDiskQueueLength -gt 2) {
        $bottlenecks += @{ Type = "DISK_QUEUE"; Severity = "HIGH"; Value = $Metrics.Disk.AvgDiskQueueLength }
    }
    
    return $bottlenecks
}

function Calculate-PerformanceScore {
    param([hashtable]$Metrics)
    
    $weights = @{
        CPU = 0.3
        Memory = 0.3
        Disk = 0.2
        Network = 0.2
    }
    
    $cpuScore = [math]::Max(0, 100 - $Metrics.System.ProcessorQueueLength * 20)
    $memoryScore = [math]::Max(0, 100 - $Metrics.Memory.PagesPerSec / 20)
    $diskScore = [math]::Max(0, 100 - $Metrics.Disk.PercentDiskTime)
    $networkScore = 100 # Simplifié pour l'instant
    
    $totalScore = ($cpuScore * $weights.CPU) + ($memoryScore * $weights.Memory) + ($diskScore * $weights.Disk) + ($networkScore * $weights.Network)
    
    return [math]::Round($totalScore, 2)
}

# Fonctions de gestion des alertes
function Test-AlertThresholds {
    param(
        [hashtable]$SystemMetrics,
        [hashtable]$MCPMetrics,
        [hashtable]$PerformanceMetrics
    )
    
    $alerts = @()
    
    # Vérifier les seuils système
    if ($SystemMetrics) {
        if ($SystemMetrics.Memory.Usage -gt $AlertThresholds.System.MemoryUsage) {
            $alerts += @{
                Type = "SYSTEM"
                Component = "MEMORY"
                Severity = "HIGH"
                Message = "Utilisation mémoire élevée: $($SystemMetrics.Memory.Usage)%"
                Value = $SystemMetrics.Memory.Usage
                Threshold = $AlertThresholds.System.MemoryUsage
                Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            }
        }
        
        if ($SystemMetrics.CPU.Usage -gt $AlertThresholds.System.CPUUsage) {
            $alerts += @{
                Type = "SYSTEM"
                Component = "CPU"
                Severity = "MEDIUM"
                Message = "Utilisation CPU élevée: $($SystemMetrics.CPU.Usage)%"
                Value = $SystemMetrics.CPU.Usage
                Threshold = $AlertThresholds.System.CPUUsage
                Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            }
        }
        
        if ($SystemMetrics.Disk.Usage -gt $AlertThresholds.System.DiskUsage) {
            $alerts += @{
                Type = "SYSTEM"
                Component = "DISK"
                Severity = "CRITICAL"
                Message = "Utilisation disque élevée: $($SystemMetrics.Disk.Usage)%"
                Value = $SystemMetrics.Disk.Usage
                Threshold = $AlertThresholds.System.DiskUsage
                Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            }
        }
    }
    
    # Vérifier les seuils MCP
    if ($MCPMetrics) {
        if ($MCPMetrics.Global.SuccessRate -lt $AlertThresholds.MCP.SuccessRate) {
            $alerts += @{
                Type = "MCP"
                Component = "SUCCESS_RATE"
                Severity = "HIGH"
                Message = "Taux de succès MCP faible: $($MCPMetrics.Global.SuccessRate)%"
                Value = $MCPMetrics.Global.SuccessRate
                Threshold = $AlertThresholds.MCP.SuccessRate
                Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            }
        }
        
        if ($MCPMetrics.Global.AverageResponseTime -gt $AlertThresholds.MCP.ResponseTime) {
            $alerts += @{
                Type = "MCP"
                Component = "RESPONSE_TIME"
                Severity = "MEDIUM"
                Message = "Temps de réponse MCP élevé: $($MCPMetrics.Global.AverageResponseTime)ms"
                Value = $MCPMetrics.Global.AverageResponseTime
                Threshold = $AlertThresholds.MCP.ResponseTime
                Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            }
        }
    }
    
    # Vérifier les seuils de performance
    if ($PerformanceMetrics) {
        if ($PerformanceMetrics.Derived.PerformanceScore -lt 70) {
            $alerts += @{
                Type = "PERFORMANCE"
                Component = "SCORE"
                Severity = "MEDIUM"
                Message = "Score de performance faible: $($PerformanceMetrics.Derived.PerformanceScore)"
                Value = $PerformanceMetrics.Derived.PerformanceScore
                Threshold = 70
                Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            }
        }
        
        if ($PerformanceMetrics.Derived.BottleneckDetection.Count -gt 0) {
            foreach ($bottleneck in $PerformanceMetrics.Derived.BottleneckDetection) {
                $alerts += @{
                    Type = "PERFORMANCE"
                    Component = "BOTTLENECK"
                    Severity = $bottleneck.Severity
                    Message = "Goulot d'étranglement détecté: $($bottleneck.Type) - $($bottleneck.Value)"
                    Value = $bottleneck.Value
                    Threshold = "N/A"
                    Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                }
            }
        }
    }
    
    return $alerts
}

function Send-Alert {
    param([hashtable]$Alert)
    
    Write-Log "ALERTE: $($Alert.Message)" -Level "ERROR"
    
    # Ajouter à la liste globale des alertes
    $global:Alerts += $Alert
    
    # Envoyer par email si configuré (placeholder)
    # Send-EmailAlert -Alert $Alert
    
    # Envoyer notification système
    if ($Alert.Severity -eq "CRITICAL") {
        [System.Windows.Forms.MessageBox]::Show($Alert.Message, "ALERTE CRITIQUE - Roo Monitoring", "OK", "Error") | Out-Null
    }
}

# Fonctions de génération de dashboard
function New-DashboardHTML {
    param(
        [hashtable]$SystemMetrics,
        [hashtable]$MCPMetrics,
        [hashtable]$PerformanceMetrics,
        [array]$Alerts
    )
    
    $html = @"
<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Roo Extensions - Dashboard Monitoring</title>
    <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
    <style>
        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; margin: 0; padding: 20px; background-color: #f5f5f5; }
        .header { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 20px; border-radius: 10px; margin-bottom: 20px; text-align: center; }
        .dashboard { display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 20px; margin-bottom: 20px; }
        .card { background: white; padding: 20px; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        .card h3 { margin-top: 0; color: #333; border-bottom: 2px solid #667eea; padding-bottom: 10px; }
        .metric { display: flex; justify-content: space-between; align-items: center; margin: 10px 0; padding: 10px; background: #f8f9fa; border-radius: 5px; }
        .metric-value { font-weight: bold; font-size: 1.2em; }
        .status-healthy { color: #28a745; }
        .status-warning { color: #ffc107; }
        .status-critical { color: #dc3545; }
        .alert { background: #f8d7da; border: 1px solid #f5c6cb; color: #721c24; padding: 10px; border-radius: 5px; margin: 5px 0; }
        .chart-container { position: relative; height: 300px; margin-top: 20px; }
        .refresh-btn { background: #667eea; color: white; border: none; padding: 10px 20px; border-radius: 5px; cursor: pointer; margin: 10px; }
        .refresh-btn:hover { background: #5a6fd8; }
    </style>
</head>
<body>
    <div class="header">
        <h1>🚀 Roo Extensions - Dashboard Monitoring</h1>
        <p>Dernière mise à jour: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')</p>
        <button class="refresh-btn" onclick="location.reload()">🔄 Actualiser</button>
    </div>
    
    <div class="dashboard">
        <!-- État système -->
        <div class="card">
            <h3>🖥️ État Système</h3>
            <div class="metric">
                <span>CPU:</span>
                <span class="metric-value status-$(Get-StatusClass $SystemMetrics.CPU.Usage 80 90)">$($SystemMetrics.CPU.Usage)%</span>
            </div>
            <div class="metric">
                <span>Mémoire:</span>
                <span class="metric-value status-$(Get-StatusClass $SystemMetrics.Memory.Usage 75 85)">$($SystemMetrics.Memory.Usage)%</span>
            </div>
            <div class="metric">
                <span>Disque:</span>
                <span class="metric-value status-$(Get-StatusClass $SystemMetrics.Disk.Usage 80 90)">$($SystemMetrics.Disk.Usage)%</span>
            </div>
            <div class="metric">
                <span>Processus:</span>
                <span class="metric-value">$($SystemMetrics.Processes.Active)/$($SystemMetrics.Processes.Total)</span>
            </div>
        </div>
        
        <!-- État MCP -->
        <div class="card">
            <h3>🔧 Serveurs MCP</h3>
            <div class="metric">
                <span>Serveurs actifs:</span>
                <span class="metric-value status-$(Get-StatusClass $MCPMetrics.Global.SuccessRate 90 95)">$($MCPMetrics.Global.ActiveServers)/$($MCPMetrics.Global.TotalServers)</span>
            </div>
            <div class="metric">
                <span>Taux de succès:</span>
                <span class="metric-value status-$(Get-StatusClass $MCPMetrics.Global.SuccessRate 90 95)">$($MCPMetrics.Global.SuccessRate)%</span>
            </div>
            <div class="metric">
                <span>Temps de réponse moyen:</span>
                <span class="metric-value status-$(Get-StatusClass $MCPMetrics.Global.AverageResponseTime 3000 5000)">$($MCPMetrics.Global.AverageResponseTime)ms</span>
            </div>
        </div>
        
        <!-- Performance -->
        <div class="card">
            <h3>📊 Performance</h3>
            <div class="metric">
                <span>Score global:</span>
                <span class="metric-value status-$(Get-StatusClass $PerformanceMetrics.Derived.PerformanceScore 70 85)">$($PerformanceMetrics.Derived.PerformanceScore)/100</span>
            </div>
            <div class="metric">
                <span>Efficacité système:</span>
                <span class="metric-value">$($PerformanceMetrics.Derived.SystemEfficiency)%</span>
            </div>
            <div class="metric">
                <span>Goulots d'étranglement:</span>
                <span class="metric-value status-$(if ($PerformanceMetrics.Derived.BottleneckDetection.Count -gt 0) { 'warning' } else { 'healthy' })">$($PerformanceMetrics.Derived.BottleneckDetection.Count)</span>
            </div>
        </div>
        
        <!-- Alertes -->
        <div class="card">
            <h3>🚨 Alertes Actives</h3>
            @if ($Alerts.Count -gt 0) {
                foreach ($alert in $Alerts) {
                    <div class="alert">
                        <strong>[$($alert.Severity)] $($alert.Component):</strong> $($alert.Message)
                        <br><small>$($alert.Timestamp)</small>
                    </div>
                }
            } else {
                <p style="color: #28a745; text-align: center;">✅ Aucune alerte active</p>
            }
        </div>
    </div>
    
    <!-- Graphiques -->
    <div class="dashboard">
        <div class="card">
            <h3>📈 Utilisation Ressources</h3>
            <div class="chart-container">
                <canvas id="resourceChart"></canvas>
            </div>
        </div>
        
        <div class="card">
            <h3>🔧 État Serveurs MCP</h3>
            <div class="chart-container">
                <canvas id="mcpChart"></canvas>
            </div>
        </div>
    </div>
    
    <script>
        // Graphique d'utilisation des ressources
        const resourceCtx = document.getElementById('resourceChart').getContext('2d');
        new Chart(resourceCtx, {
            type: 'doughnut',
            data: {
                labels: ['CPU', 'Mémoire', 'Disque'],
                datasets: [{
                    data: [$($SystemMetrics.CPU.Usage), $($SystemMetrics.Memory.Usage), $($SystemMetrics.Disk.Usage)],
                    backgroundColor: ['#FF6384', '#36A2EB', '#FFCE56'],
                    borderWidth: 2
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                plugins: {
                    legend: { position: 'bottom' }
                }
            }
        });
        
        // Graphique des serveurs MCP
        const mcpCtx = document.getElementById('mcpChart').getContext('2d');
        new Chart(mcpCtx, {
            type: 'bar',
            data: {
                labels: ['Actifs', 'Inactifs'],
                datasets: [{
                    label: 'Serveurs MCP',
                    data: [$($MCPMetrics.Global.ActiveServers), $($MCPMetrics.Global.TotalServers - $MCPMetrics.Global.ActiveServers)],
                    backgroundColor: ['#28a745', '#dc3545'],
                    borderWidth: 2
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                scales: {
                    y: { beginAtZero: true }
                }
            }
        });
        
        // Auto-rafraîchissement toutes les 60 secondes
        setTimeout(() => location.reload(), 60000);
    </script>
</body>
</html>
"@
    
    return $html
}

function Get-StatusClass {
    param(
        [double]$Value,
        [double]$WarningThreshold,
        [double]$CriticalThreshold
    )
    
    if ($Value -ge $CriticalThreshold) { return "critical" }
    if ($Value -ge $WarningThreshold) { return "warning" }
    return "healthy"
}

# Fonction principale de monitoring
function Start-AdvancedMonitoring {
    Write-Section "DÉMARRAGE DU MONITORING AVANCÉ - PHASE 3C"
    Write-Log "Version: 2.0.0 - Phase 3C Robustesse et Performance"
    Write-Log "Intervalle: $IntervalSeconds secondes"
    Write-Log "Dashboard: $Dashboard"
    Write-Log "Alertes: $Alerts"
    Write-Log "Performance: $Performance"
    Write-Log "Continu: $Continuous"
    
    do {
        try {
            Write-Log "=== CYCLE DE MONITORING $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') ==="
            
            # Collecte des métriques
            $systemMetrics = Get-SystemMetrics
            $mcpMetrics = Get-MCPMetrics
            $performanceMetrics = Get-PerformanceMetrics
            
            # Stocker les métriques globales
            $global:Metrics = @{
                Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                System = $systemMetrics
                MCP = $mcpMetrics
                Performance = $performanceMetrics
            }
            
            # Ajouter à l'historique
            $global:PerformanceHistory += $global:Metrics
            
            # Tester les seuils d'alerte
            if ($Alerts) {
                $newAlerts = Test-AlertThresholds -SystemMetrics $systemMetrics -MCPMetrics $mcpMetrics -PerformanceMetrics $performanceMetrics
                foreach ($alert in $newAlerts) {
                    Send-Alert -Alert $alert
                }
            }
            
            # Générer le dashboard
            if ($Dashboard) {
                $dashboardHTML = New-DashboardHTML -SystemMetrics $systemMetrics -MCPMetrics $mcpMetrics -PerformanceMetrics $performanceMetrics -Alerts $global:Alerts
                Set-Content -Path $DashboardFile -Value $dashboardHTML -Encoding UTF8
                Write-Log "Dashboard généré: $DashboardFile" -Level "SUCCESS"
            }
            
            # Analyse de performance approfondie
            if ($Performance) {
                Write-Log "Lancement de l'analyse de performance approfondie..."
                # Implémentation de l'analyse approfondie ici
            }
            
            # Sauvegarder les métriques
            $metricsJson = $global:Metrics | ConvertTo-Json -Depth 10
            Set-Content -Path $MetricsFile -Value $metricsJson -Encoding UTF8
            
            # Déterminer l'état de santé global
            $criticalAlerts = $global:Alerts | Where-Object { $_.Severity -eq "CRITICAL" }
            $global:SystemHealth = if ($criticalAlerts.Count -gt 0) { "CRITICAL" } 
                                 elseif ($global:Alerts.Count -gt 0) { "WARNING" } 
                                 else { "HEALTHY" }
            
            Write-Log "=== FIN DU CYCLE - État: $global:SystemHealth ==="
            
            if (-not $Continuous) {
                break
            }
            
            Write-Log "Attente de $IntervalSeconds secondes avant le prochain cycle..."
            Start-Sleep -Seconds $IntervalSeconds
        }
        catch {
            Write-Log "Erreur lors du cycle de monitoring: $($_.Exception.Message)" -Level "ERROR"
            if (-not $Continuous) {
                break
            }
            Start-Sleep -Seconds $IntervalSeconds
        }
    } while ($Continuous)
    
    Write-Log "Monitoring avancé terminé" -Level "SUCCESS"
}

# Point d'entrée principal
try {
    Write-Log "Démarrage du script de monitoring avancé - Phase 3C"
    Start-AdvancedMonitoring
}
catch {
    Write-Log "Erreur fatale: $($_.Exception.Message)" -Level "ERROR"
    exit 1
}