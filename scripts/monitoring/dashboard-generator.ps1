#Requires -Version 5.1
<#
.SYNOPSIS
    Générateur de tableau de bord pour le monitoring Roo Extensions

.DESCRIPTION
    Ce script génère des tableaux de bord interactifs :
    - Tableau de bord HTML avec graphiques en temps réel
    - Métriques système et MCP
    - Visualisation des alertes et incidents
    - Rapports de performance et tendances
    - Interface responsive et moderne

.PARAMETER Generate
    Génère le tableau de bord

.PARAMETER Serve
    Démarre le serveur web local pour le tableau de bord

.PARAMETER Port
    Port du serveur web (défaut: 8080)

.EXAMPLE
    .\dashboard-generator.ps1 -Generate -Serve -Port 8080
    Génère et sert le tableau de bord sur le port 8080

.NOTES
    Auteur: Roo Extensions Team
    Version: 2.0.0 - Phase 3C
    Date: 2025-12-04
#>

param (
    [switch]$Generate,
    [switch]$Serve,
    [int]$Port = 8080
)

# Configuration
$ErrorActionPreference = "Continue"
$ProgressPreference = "Continue"
$PSDefaultParameterValues['Out-File:Encoding'] = 'utf8'

# Chemins
$ScriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$OutputDir = Join-Path -Path $ScriptPath -ChildPath "dashboard"
$DataDir = Join-Path -Path $OutputDir -ChildPath "data"
$AssetsDir = Join-Path -Path $OutputDir -ChildPath "assets"

# Création des répertoires
foreach ($dir in @($OutputDir, $DataDir, $AssetsDir)) {
    if (-not (Test-Path -Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
}

# Fichiers
$IndexFile = Join-Path -Path $OutputDir -ChildPath "index.html"
$DataFile = Join-Path -Path $DataDir -ChildPath "metrics.json"
$LogFile = Join-Path -Path $ScriptPath -ChildPath "logs\dashboard-$(Get-Date -Format 'yyyy-MM-dd').log"

# Configuration du tableau de bord
$DashboardConfig = @{
    RefreshInterval = 30 # secondes
    MaxDataPoints = 100
    ChartColors = @{
        Primary = "#007bff"
        Success = "#28a745"
        Warning = "#ffc107"
        Danger = "#dc3545"
        Info = "#17a2b8"
        Dark = "#343a40"
        Light = "#f8f9fa"
    }
    Metrics = @(
        "CPU", "Memory", "Disk", "Network", "MCP", "Alerts", "Incidents", "Performance"
    )
}

# Variables globales
$global:DashboardData = @{}
$global:HistoricalData = @()

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

# Collecte des données
function Get-DashboardData {
    Write-Section "COLLECTE DES DONNÉES DU TABLEAU DE BORD"
    
    try {
        $data = @{
            Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            System = Get-SystemMetrics
            MCP = Get-MCPMetrics
            Alerts = Get-AlertMetrics
            Performance = Get-PerformanceMetrics
            Health = Get-HealthMetrics
        }
        
        # Ajouter aux données historiques
        $global:HistoricalData += $data
        
        # Limiter le nombre de points de données
        if ($global:HistoricalData.Count -gt $DashboardConfig.MaxDataPoints) {
            $global:HistoricalData = $global:HistoricalData | Select-Object -Last $DashboardConfig.MaxDataPoints
        }
        
        Write-Log "Données collectées - $($global:HistoricalData.Count) points historiques" -Level "SUCCESS"
        return $data
    }
    catch {
        Write-Log "Erreur lors de la collecte des données: $($_.Exception.Message)" -Level "ERROR"
        return $null
    }
}

function Get-SystemMetrics {
    try {
        $cpuUsage = (Get-Counter "\Processor(_Total)\% Processor Time").CounterSamples.CookedValue
        $memoryUsage = 100 - ((Get-Counter "\Memory\Available MBytes").CounterSamples.CookedValue / (Get-WmiObject -Class Win32_ComputerSystem).TotalPhysicalMemory * 1000000 * 100)
        $diskUsage = (Get-PSDrive C).Used / (Get-PSDrive C).Size * 100
        
        return @{
            CPU = [math]::Round($cpuUsage, 2)
            Memory = [math]::Round($memoryUsage, 2)
            Disk = [math]::Round($diskUsage, 2)
            Network = Test-NetworkLatency
            Uptime = (Get-Date) - (Get-CimInstance -ClassName Win32_OperatingSystem).LastBootUpTime
        }
    }
    catch {
        Write-Log "Erreur lors de la collecte des métriques système: $($_.Exception.Message)" -Level "ERROR"
        return @{
            CPU = 0
            Memory = 0
            Disk = 0
            Network = 0
            Uptime = [TimeSpan]::Zero
        }
    }
}

function Get-MCPMetrics {
    try {
        $mcpScript = Join-Path -Path $ScriptPath -ChildPath "monitor-mcp-servers.ps1"
        if (Test-Path $mcpScript) {
            $mcpStatus = & $mcpScript -Status -ErrorAction SilentlyContinue
            
            $totalServers = $mcpStatus.Count
            $runningServers = ($mcpStatus | Where-Object { $_.Status -eq "Running" }).Count
            $downServers = ($mcpStatus | Where-Object { $_.Status -eq "Down" }).Count
            
            return @{
                Total = $totalServers
                Running = $runningServers
                Down = $downServers
                Availability = if ($totalServers -gt 0) { [math]::Round(($runningServers / $totalServers) * 100, 2) } else { 0 }
                Servers = $mcpStatus
            }
        }
        
        return @{
            Total = 0
            Running = 0
            Down = 0
            Availability = 0
            Servers = @()
        }
    }
    catch {
        Write-Log "Erreur lors de la collecte des métriques MCP: $($_.Exception.Message)" -Level "ERROR"
        return @{
            Total = 0
            Running = 0
            Down = 0
            Availability = 0
            Servers = @()
        }
    }
}

function Get-AlertMetrics {
    try {
        $alertFile = Join-Path -Path $ScriptPath -ChildPath "reports\alerts-$(Get-Date -Format 'yyyy-MM-dd').json"
        
        if (Test-Path $alertFile) {
            $alertData = Get-Content $alertFile | ConvertFrom-Json
            
            $activeAlerts = $alertData.Active | Where-Object { $_.Status -eq "Active" }
            $criticalAlerts = $activeAlerts | Where-Object { $_.Severity -eq "Critical" -or $_.Severity -eq "Emergency" }
            $warningAlerts = $activeAlerts | Where-Object { $_.Severity -eq "Warning" }
            
            return @{
                Total = $activeAlerts.Count
                Critical = $criticalAlerts.Count
                Warning = $warningAlerts.Count
                Info = ($activeAlerts.Count - $criticalAlerts.Count - $warningAlerts.Count)
                History = $alertData.History
                Suppressed = $alertData.Suppressed.Count
            }
        }
        
        return @{
            Total = 0
            Critical = 0
            Warning = 0
            Info = 0
            History = @()
            Suppressed = 0
        }
    }
    catch {
        Write-Log "Erreur lors de la collecte des métriques d'alertes: $($_.Exception.Message)" -Level "ERROR"
        return @{
            Total = 0
            Critical = 0
            Warning = 0
            Info = 0
            History = @()
            Suppressed = 0
        }
    }
}

function Get-PerformanceMetrics {
    try {
        $perfFile = Join-Path -Path $ScriptPath -ChildPath "reports\optimization-report-$(Get-Date -Format 'yyyy-MM-dd')*.json"
        $perfReports = Get-ChildItem $perfFile -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
        
        if ($perfReports) {
            $report = Get-Content $perfReports.FullName | ConvertFrom-Json
            
            return @{
                Score = if ($report.Results.Validation) { $report.Results.Validation.OverallScore } else { 0 }
                Bottlenecks = if ($report.Results.Bottlenecks) { $report.Results.Bottlenecks.Count } else { 0 }
                Optimizations = if ($report.Results.Optimizations) { $report.Results.Optimizations.Count } else { 0 }
                LastOptimization = $perfReports.LastWriteTime
                Trend = Calculate-PerformanceTrend
            }
        }
        
        return @{
            Score = 0
            Bottlenecks = 0
            Optimizations = 0
            LastOptimization = $null
            Trend = "Stable"
        }
    }
    catch {
        Write-Log "Erreur lors de la collecte des métriques de performance: $($_.Exception.Message)" -Level "ERROR"
        return @{
            Score = 0
            Bottlenecks = 0
            Optimizations = 0
            LastOptimization = $null
            Trend = "Unknown"
        }
    }
}

function Get-HealthMetrics {
    try {
        $systemMetrics = Get-SystemMetrics
        $mcpMetrics = Get-MCPMetrics
        $alertMetrics = Get-AlertMetrics
        
        # Calculer le score de santé global
        $systemScore = Calculate-SystemHealthScore -Metrics $systemMetrics
        $mcpScore = $mcpMetrics.Availability
        $alertScore = Calculate-AlertHealthScore -Metrics $alertMetrics
        
        $overallScore = ($systemScore + $mcpScore + $alertScore) / 3
        
        return @{
            Overall = [math]::Round($overallScore, 2)
            System = $systemScore
            MCP = $mcpScore
            Alerts = $alertScore
            Status = Get-HealthStatus -Score $overallScore
            LastCheck = Get-Date
        }
    }
    catch {
        Write-Log "Erreur lors de la collecte des métriques de santé: $($_.Exception.Message)" -Level "ERROR"
        return @{
            Overall = 0
            System = 0
            MCP = 0
            Alerts = 0
            Status = "Unknown"
            LastCheck = Get-Date
        }
    }
}

function Test-NetworkLatency {
    try {
        $result = Test-NetConnection -ComputerName "github.com" -Port 443 -InformationLevel Quiet
        $latency = (Measure-Command { $result }).TotalMilliseconds
        return [math]::Round($latency, 2)
    }
    catch {
        return 9999
    }
}

function Calculate-SystemHealthScore {
    param (
        [object]$Metrics
    )
    
    $cpuScore = [math]::Max(0, 100 - $Metrics.CPU)
    $memoryScore = [math]::Max(0, 100 - $Metrics.Memory)
    $diskScore = [math]::Max(0, 100 - $Metrics.Disk)
    $networkScore = if ($Metrics.Network -lt 1000) { 100 } elseif ($Metrics.Network -lt 5000) { 50 } else { 0 }
    
    return ($cpuScore + $memoryScore + $diskScore + $networkScore) / 4
}

function Calculate-AlertHealthScore {
    param (
        [object]$Metrics
    )
    
    $criticalPenalty = $Metrics.Critical * 25
    $warningPenalty = $Metrics.Warning * 10
    $baseScore = 100
    
    return [math]::Max(0, $baseScore - $criticalPenalty - $warningPenalty)
}

function Calculate-PerformanceTrend {
    try {
        if ($global:HistoricalData.Count -lt 2) {
            return "Stable"
        }
        
        $recentData = $global:HistoricalData | Select-Object -Last 10
        $performanceScores = $recentData | ForEach-Object { $_.Performance.Score }
        
        if ($performanceScores.Count -lt 2) {
            return "Stable"
        }
        
        $firstHalf = $performanceScores | Select-Object -First ($performanceScores.Count / 2)
        $secondHalf = $performanceScores | Select-Object -Last ($performanceScores.Count / 2)
        
        $firstAvg = $firstHalf | Measure-Object -Average | Select-Object -ExpandProperty Average
        $secondAvg = $secondHalf | Measure-Object -Average | Select-Object -ExpandProperty Average
        
        $difference = $secondAvg - $firstAvg
        
        if ($difference -gt 5) {
            return "Improving"
        } elseif ($difference -lt -5) {
            return "Degrading"
        } else {
            return "Stable"
        }
    }
    catch {
        return "Unknown"
    }
}

function Get-HealthStatus {
    param (
        [double]$Score
    )
    
    if ($Score -ge 90) {
        return "Excellent"
    } elseif ($Score -ge 75) {
        return "Good"
    } elseif ($Score -ge 60) {
        return "Fair"
    } elseif ($Score -ge 40) {
        return "Poor"
    } else {
        return "Critical"
    }
}

# Génération du HTML
function New-DashboardHTML {
    Write-Section "GÉNÉRATION DU TABLEAU DE BORD HTML"
    
    try {
        $html = @"
<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Roo Extensions - Tableau de Bord Monitoring</title>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.1.3/dist/css/bootstrap.min.css" rel="stylesheet">
    <link href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.0.0/css/all.min.css" rel="stylesheet">
    <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
    <style>
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background-color: #f8f9fa;
        }
        .navbar {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
        }
        .card {
            border: none;
            border-radius: 15px;
            box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
            transition: transform 0.3s ease;
        }
        .card:hover {
            transform: translateY(-5px);
        }
        .metric-card {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
        }
        .status-excellent { color: #28a745; }
        .status-good { color: #17a2b8; }
        .status-fair { color: #ffc107; }
        .status-poor { color: #fd7e14; }
        .status-critical { color: #dc3545; }
        .chart-container {
            position: relative;
            height: 300px;
        }
        .refresh-btn {
            position: fixed;
            bottom: 20px;
            right: 20px;
            z-index: 1000;
        }
        .loading {
            display: none;
            position: fixed;
            top: 50%;
            left: 50%;
            transform: translate(-50%, -50%);
            z-index: 9999;
        }
    </style>
</head>
<body>
    <nav class="navbar navbar-dark mb-4">
        <div class="container">
            <span class="navbar-brand mb-0 h1">
                <i class="fas fa-chart-line me-2"></i>
                Roo Extensions - Monitoring Phase 3C
            </span>
            <span class="navbar-text text-white">
                <i class="fas fa-clock me-1"></i>
                <span id="lastUpdate">Chargement...</span>
            </span>
        </div>
    </nav>

    <div class="container-fluid">
        <!-- Cartes de métriques principales -->
        <div class="row mb-4">
            <div class="col-md-3 mb-3">
                <div class="card metric-card">
                    <div class="card-body text-center">
                        <h5 class="card-title">
                            <i class="fas fa-microchip me-2"></i>CPU
                        </h5>
                        <h2 class="card-text" id="cpuMetric">0%</h2>
                        <div class="progress mt-2">
                            <div class="progress-bar" id="cpuProgress" role="progressbar" style="width: 0%"></div>
                        </div>
                    </div>
                </div>
            </div>
            <div class="col-md-3 mb-3">
                <div class="card metric-card">
                    <div class="card-body text-center">
                        <h5 class="card-title">
                            <i class="fas fa-memory me-2"></i>Mémoire
                        </h5>
                        <h2 class="card-text" id="memoryMetric">0%</h2>
                        <div class="progress mt-2">
                            <div class="progress-bar" id="memoryProgress" role="progressbar" style="width: 0%"></div>
                        </div>
                    </div>
                </div>
            </div>
            <div class="col-md-3 mb-3">
                <div class="card metric-card">
                    <div class="card-body text-center">
                        <h5 class="card-title">
                            <i class="fas fa-hdd me-2"></i>Disque
                        </h5>
                        <h2 class="card-text" id="diskMetric">0%</h2>
                        <div class="progress mt-2">
                            <div class="progress-bar" id="diskProgress" role="progressbar" style="width: 0%"></div>
                        </div>
                    </div>
                </div>
            </div>
            <div class="col-md-3 mb-3">
                <div class="card metric-card">
                    <div class="card-body text-center">
                        <h5 class="card-title">
                            <i class="fas fa-server me-2"></i>MCP
                        </h5>
                        <h2 class="card-text" id="mcpMetric">0%</h2>
                        <small class="text-white-50">
                            <span id="mcpServers">0/0</span> serveurs
                        </small>
                    </div>
                </div>
            </div>
        </div>

        <!-- Cartes de santé et alertes -->
        <div class="row mb-4">
            <div class="col-md-6 mb-3">
                <div class="card">
                    <div class="card-body">
                        <h5 class="card-title">
                            <i class="fas fa-heartbeat me-2"></i>Santé Globale
                        </h5>
                        <div class="text-center">
                            <h1 class="display-4" id="healthScore">0%</h1>
                            <span class="badge badge-secondary" id="healthStatus">Unknown</span>
                        </div>
                        <div class="row mt-3">
                            <div class="col-4 text-center">
                                <small>Système</small>
                                <div id="systemHealth">0%</div>
                            </div>
                            <div class="col-4 text-center">
                                <small>MCP</small>
                                <div id="mcpHealth">0%</div>
                            </div>
                            <div class="col-4 text-center">
                                <small>Alertes</small>
                                <div id="alertHealth">0%</div>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
            <div class="col-md-6 mb-3">
                <div class="card">
                    <div class="card-body">
                        <h5 class="card-title">
                            <i class="fas fa-exclamation-triangle me-2"></i>Alertes Actives
                        </h5>
                        <div class="row text-center">
                            <div class="col-3">
                                <div class="text-danger">
                                    <h3 id="criticalAlerts">0</h3>
                                    <small>Critiques</small>
                                </div>
                            </div>
                            <div class="col-3">
                                <div class="text-warning">
                                    <h3 id="warningAlerts">0</h3>
                                    <small>Avertissements</small>
                                </div>
                            </div>
                            <div class="col-3">
                                <div class="text-info">
                                    <h3 id="infoAlerts">0</h3>
                                    <small>Infos</small>
                                </div>
                            </div>
                            <div class="col-3">
                                <div class="text-secondary">
                                    <h3 id="totalAlerts">0</h3>
                                    <small>Total</small>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </div>

        <!-- Graphiques -->
        <div class="row mb-4">
            <div class="col-md-6 mb-3">
                <div class="card">
                    <div class="card-body">
                        <h5 class="card-title">
                            <i class="fas fa-chart-line me-2"></i>Tendances Système
                        </h5>
                        <div class="chart-container">
                            <canvas id="systemTrendsChart"></canvas>
                        </div>
                    </div>
                </div>
            </div>
            <div class="col-md-6 mb-3">
                <div class="card">
                    <div class="card-body">
                        <h5 class="card-title">
                            <i class="fas fa-chart-pie me-2"></i>Répartition des Alertes
                        </h5>
                        <div class="chart-container">
                            <canvas id="alertsChart"></canvas>
                        </div>
                    </div>
                </div>
            </div>
        </div>

        <!-- Performance et optimisation -->
        <div class="row mb-4">
            <div class="col-md-12 mb-3">
                <div class="card">
                    <div class="card-body">
                        <h5 class="card-title">
                            <i class="fas fa-tachometer-alt me-2"></i>Performance et Optimisation
                        </h5>
                        <div class="row">
                            <div class="col-md-3 text-center">
                                <h4 id="performanceScore">0</h4>
                                <small>Score Performance</small>
                            </div>
                            <div class="col-md-3 text-center">
                                <h4 id="bottlenecksCount">0</h4>
                                <small>Goulots d'étranglement</small>
                            </div>
                            <div class="col-md-3 text-center">
                                <h4 id="optimizationsCount">0</h4>
                                <small>Optimisations appliquées</small>
                            </div>
                            <div class="col-md-3 text-center">
                                <h4 id="performanceTrend">Stable</h4>
                                <small>Tendance</small>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </div>

        <!-- Liste des serveurs MCP -->
        <div class="row mb-4">
            <div class="col-md-12 mb-3">
                <div class="card">
                    <div class="card-body">
                        <h5 class="card-title">
                            <i class="fas fa-server me-2"></i>État des Serveurs MCP
                        </h5>
                        <div class="table-responsive">
                            <table class="table table-striped">
                                <thead>
                                    <tr>
                                        <th>Serveur</th>
                                        <th>Statut</th>
                                        <th>Dernière vérification</th>
                                        <th>Actions</th>
                                    </tr>
                                </thead>
                                <tbody id="mcpServersTable">
                                    <tr>
                                        <td colspan="4" class="text-center">Chargement...</td>
                                    </tr>
                                </tbody>
                            </table>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    </div>

    <!-- Bouton de rafraîchissement -->
    <button class="btn btn-primary refresh-btn" onclick="refreshData()">
        <i class="fas fa-sync-alt me-2"></i>Rafraîchir
    </button>

    <!-- Indicateur de chargement -->
    <div class="loading">
        <div class="spinner-border text-primary" role="status">
            <span class="visually-hidden">Chargement...</span>
        </div>
    </div>

    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.1.3/dist/js/bootstrap.bundle.min.js"></script>
    <script>
        // Variables globales
        let systemTrendsChart = null;
        let alertsChart = null;
        let refreshInterval = null;

        // Initialisation
        document.addEventListener('DOMContentLoaded', function() {
            initializeCharts();
            refreshData();
            startAutoRefresh();
        });

        // Initialisation des graphiques
        function initializeCharts() {
            // Graphique des tendances système
            const systemCtx = document.getElementById('systemTrendsChart').getContext('2d');
            systemTrendsChart = new Chart(systemCtx, {
                type: 'line',
                data: {
                    labels: [],
                    datasets: [
                        {
                            label: 'CPU',
                            data: [],
                            borderColor: '#dc3545',
                            backgroundColor: 'rgba(220, 53, 69, 0.1)',
                            tension: 0.4
                        },
                        {
                            label: 'Mémoire',
                            data: [],
                            borderColor: '#ffc107',
                            backgroundColor: 'rgba(255, 193, 7, 0.1)',
                            tension: 0.4
                        },
                        {
                            label: 'Disque',
                            data: [],
                            borderColor: '#28a745',
                            backgroundColor: 'rgba(40, 167, 69, 0.1)',
                            tension: 0.4
                        }
                    ]
                },
                options: {
                    responsive: true,
                    maintainAspectRatio: false,
                    scales: {
                        y: {
                            beginAtZero: true,
                            max: 100
                        }
                    }
                }
            });

            // Graphique des alertes
            const alertsCtx = document.getElementById('alertsChart').getContext('2d');
            alertsChart = new Chart(alertsCtx, {
                type: 'doughnut',
                data: {
                    labels: ['Critiques', 'Avertissements', 'Infos'],
                    datasets: [{
                        data: [0, 0, 0],
                        backgroundColor: ['#dc3545', '#ffc107', '#17a2b8']
                    }]
                },
                options: {
                    responsive: true,
                    maintainAspectRatio: false
                }
            });
        }

        // Rafraîchissement des données
        function refreshData() {
            showLoading();
            
            fetch('/data')
                .then(response => response.json())
                .then(data => {
                    updateMetrics(data);
                    updateCharts(data);
                    hideLoading();
                })
                .catch(error => {
                    console.error('Erreur lors du rafraîchissement:', error);
                    hideLoading();
                });
        }

        // Mise à jour des métriques
        function updateMetrics(data) {
            // Métriques système
            document.getElementById('cpuMetric').textContent = data.System.CPU.toFixed(1) + '%';
            document.getElementById('cpuProgress').style.width = data.System.CPU + '%';
            
            document.getElementById('memoryMetric').textContent = data.System.Memory.toFixed(1) + '%';
            document.getElementById('memoryProgress').style.width = data.System.Memory + '%';
            
            document.getElementById('diskMetric').textContent = data.System.Disk.toFixed(1) + '%';
            document.getElementById('diskProgress').style.width = data.System.Disk + '%';
            
            // Métriques MCP
            document.getElementById('mcpMetric').textContent = data.MCP.Availability.toFixed(1) + '%';
            document.getElementById('mcpServers').textContent = data.MCP.Running + '/' + data.MCP.Total;
            
            // Santé globale
            document.getElementById('healthScore').textContent = data.Health.Overall.toFixed(1) + '%';
            document.getElementById('healthStatus').textContent = data.Health.Status;
            document.getElementById('healthStatus').className = 'badge badge-' + getHealthBadgeClass(data.Health.Status);
            
            document.getElementById('systemHealth').textContent = data.Health.System.toFixed(1) + '%';
            document.getElementById('mcpHealth').textContent = data.Health.MCP.toFixed(1) + '%';
            document.getElementById('alertHealth').textContent = data.Health.Alerts.toFixed(1) + '%';
            
            // Alertes
            document.getElementById('criticalAlerts').textContent = data.Alerts.Critical;
            document.getElementById('warningAlerts').textContent = data.Alerts.Warning;
            document.getElementById('infoAlerts').textContent = data.Alerts.Info;
            document.getElementById('totalAlerts').textContent = data.Alerts.Total;
            
            // Performance
            document.getElementById('performanceScore').textContent = data.Performance.Score;
            document.getElementById('bottlenecksCount').textContent = data.Performance.Bottlenecks;
            document.getElementById('optimizationsCount').textContent = data.Performance.Optimizations;
            document.getElementById('performanceTrend').textContent = data.Performance.Trend;
            
            // Tableau des serveurs MCP
            updateMCPServersTable(data.MCP.Servers);
            
            // Dernière mise à jour
            document.getElementById('lastUpdate').textContent = new Date().toLocaleString();
        }

        // Mise à jour des graphiques
        function updateCharts(data) {
            // Mettre à jour le graphique des tendances
            fetch('/historical')
                .then(response => response.json())
                .then(historicalData => {
                    const labels = historicalData.map(d => new Date(d.Timestamp).toLocaleTimeString());
                    const cpuData = historicalData.map(d => d.System.CPU);
                    const memoryData = historicalData.map(d => d.System.Memory);
                    const diskData = historicalData.map(d => d.System.Disk);
                    
                    systemTrendsChart.data.labels = labels;
                    systemTrendsChart.data.datasets[0].data = cpuData;
                    systemTrendsChart.data.datasets[1].data = memoryData;
                    systemTrendsChart.data.datasets[2].data = diskData;
                    systemTrendsChart.update();
                });
            
            // Mettre à jour le graphique des alertes
            alertsChart.data.datasets[0].data = [data.Alerts.Critical, data.Alerts.Warning, data.Alerts.Info];
            alertsChart.update();
        }

        // Mise à jour du tableau des serveurs MCP
        function updateMCPServersTable(servers) {
            const tbody = document.getElementById('mcpServersTable');
            tbody.innerHTML = '';
            
            servers.forEach(server => {
                const row = document.createElement('tr');
                row.innerHTML = `
                    <td>${server.Name}</td>
                    <td><span class="badge badge-${server.Status === 'Running' ? 'success' : 'danger'}">${server.Status}</span></td>
                    <td>${new Date(server.LastCheck).toLocaleString()}</td>
                    <td>
                        <button class="btn btn-sm btn-primary" onclick="restartServer('${server.Name}')">
                            <i class="fas fa-redo"></i>
                        </button>
                    </td>
                `;
                tbody.appendChild(row);
            });
        }

        // Fonctions utilitaires
        function getHealthBadgeClass(status) {
            switch(status) {
                case 'Excellent': return 'success';
                case 'Good': return 'info';
                case 'Fair': return 'warning';
                case 'Poor': return 'secondary';
                case 'Critical': return 'danger';
                default: return 'secondary';
            }
        }

        function showLoading() {
            document.querySelector('.loading').style.display = 'block';
        }

        function hideLoading() {
            document.querySelector('.loading').style.display = 'none';
        }

        function startAutoRefresh() {
            refreshInterval = setInterval(refreshData, $($DashboardConfig.RefreshInterval) * 1000);
        }

        function restartServer(serverName) {
            if (confirm('Redémarrer le serveur ' + serverName + ' ?')) {
                fetch('/restart-server', {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json'
                    },
                    body: JSON.stringify({ server: serverName })
                })
                .then(response => response.json())
                .then(data => {
                    if (data.success) {
                        alert('Serveur redémarré avec succès');
                        refreshData();
                    } else {
                        alert('Erreur lors du redémarrage: ' + data.message);
                    }
                })
                .catch(error => {
                    alert('Erreur: ' + error.message);
                });
            }
        }
    </script>
</body>
</html>
"@
        
        Set-Content -Path $IndexFile -Value $html -Encoding UTF8
        Write-Log "Tableau de bord HTML généré: $IndexFile" -Level "SUCCESS"
        return $IndexFile
    }
    catch {
        Write-Log "Erreur lors de la génération du HTML: $($_.Exception.Message)" -Level "ERROR"
        return $null
    }
}

# Serveur web
function Start-WebServer {
    Write-Section "DÉMARRAGE DU SERVEUR WEB"
    
    try {
        $listener = New-Object System.Net.HttpListener
        $listener.Prefixes.Add("http://localhost:$Port/")
        $listener.Start()
        
        Write-Log "Serveur web démarré sur http://localhost:$Port" -Level "SUCCESS"
        Write-Log "Tableau de bord disponible à l'adresse: http://localhost:$Port" -Level "SUCCESS"
        
        try {
            while ($listener.IsListening) {
                $context = $listener.GetContext()
                $request = $context.Request
                $response = $context.Response
                
                try {
                    $path = $request.Url.LocalPath
                    
                    switch ($path) {
                        "/" {
                            $content = Get-Content $IndexFile -Raw -Encoding UTF8
                            $response.ContentType = "text/html; charset=utf-8"
                        }
                        "/data" {
                            $data = Get-DashboardData
                            $content = $data | ConvertTo-Json -Depth 10
                            $response.ContentType = "application/json; charset=utf-8"
                        }
                        "/historical" {
                            $content = $global:HistoricalData | ConvertTo-Json -Depth 10
                            $response.ContentType = "application/json; charset=utf-8"
                        }
                        "/restart-server" {
                            if ($request.HttpMethod -eq "POST") {
                                $body = New-Object System.IO.StreamReader($request.InputStream)
                                $json = $body.ReadToEnd()
                                $data = $json | ConvertFrom-Json
                                
                                $result = Restart-MCPServer -ServerName $data.server
                                $content = $result | ConvertTo-Json
                                $response.ContentType = "application/json; charset=utf-8"
                            } else {
                                $content = "Méthode non autorisée"
                                $response.StatusCode = 405
                            }
                        }
                        default {
                            $content = "Page non trouvée"
                            $response.StatusCode = 404
                        }
                    }
                    
                    $buffer = [System.Text.Encoding]::UTF8.GetBytes($content)
                    $response.ContentLength64 = $buffer.Length
                    $response.OutputStream.Write($buffer, 0, $buffer.Length)
                }
                catch {
                    Write-Log "Erreur lors du traitement de la requête: $($_.Exception.Message)" -Level "ERROR"
                    $response.StatusCode = 500
                }
                finally {
                    $response.Close()
                }
            }
        }
        finally {
            $listener.Stop()
            Write-Log "Serveur web arrêté" -Level "INFO"
        }
    }
    catch {
        Write-Log "Erreur lors du démarrage du serveur web: $($_.Exception.Message)" -Level "ERROR"
    }
}

function Restart-MCPServer {
    param (
        [string]$ServerName
    )
    
    try {
        $mcpScript = Join-Path -Path $ScriptPath -ChildPath "monitor-mcp-servers.ps1"
        if (Test-Path $mcpScript) {
            $result = & $mcpScript -Restart -ServerName $ServerName -ErrorAction SilentlyContinue
            return @{
                success = $true
                message = "Serveur $ServerName redémarré"
            }
        }
        
        return @{
            success = $false
            message = "Script de monitoring MCP non trouvé"
        }
    }
    catch {
        return @{
            success = $false
            message = "Erreur: $($_.Exception.Message)"
        }
    }
}

# Fonction principale
function Start-DashboardGenerator {
    Write-Section "DÉMARRAGE DU GÉNÉRATEUR DE TABLEAU DE BORD - PHASE 3C"
    Write-Log "Version: 2.0.0 - Phase 3C Robustesse et Performance"
    Write-Log "Generate: $Generate"
    Write-Log "Serve: $Serve"
    Write-Log "Port: $Port"
    
    try {
        # Générer le tableau de bord
        if ($Generate) {
            $htmlFile = New-DashboardHTML
            if ($htmlFile) {
                Write-Log "Tableau de bord généré avec succès" -Level "SUCCESS"
                
                if (-not $Serve) {
                    Write-Log "Pour démarrer le serveur web, utilisez: .\dashboard-generator.ps1 -Serve -Port $Port" -Level "INFO"
                }
            }
        }
        
        # Démarrer le serveur web
        if ($Serve) {
            # S'assurer que le HTML est généré
            if (-not (Test-Path $IndexFile)) {
                New-DashboardHTML | Out-Null
            }
            
            Start-WebServer
        }
        
        Write-Log "Générateur de tableau de bord terminé" -Level "SUCCESS"
    }
    catch {
        Write-Log "Erreur fatale: $($_.Exception.Message)" -Level "ERROR"
        exit 1
    }
}

# Point d'entrée
try {
    Write-Log "Démarrage du générateur de tableau de bord - Phase 3C"
    Start-DashboardGenerator
}
catch {
    Write-Log "Erreur fatale: $($_.Exception.Message)" -Level "ERROR"
    exit 1
}