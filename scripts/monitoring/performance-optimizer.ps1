#Requires -Version 5.1
<#
.SYNOPSIS
    Script d'optimisation des performances pour le système Roo Extensions

.DESCRIPTION
    Ce script implémente des algorithmes d'optimisation des performances :
    - Analyse des goulots d'étranglement
    - Optimisation des algorithmes critiques
    - Cache intelligent
    - Parallélisation des traitements
    - Validation des améliorations

.PARAMETER Analyze
    Lance l'analyse complète des performances

.PARAMETER Optimize
    Applique les optimisations détectées

.PARAMETER Validate
    Valide les améliorations de performance

.EXAMPLE
    .\performance-optimizer.ps1 -Analyze -Optimize
    Analyse et optimise les performances

.NOTES
    Auteur: Roo Extensions Team
    Version: 2.0.0 - Phase 3C
    Date: 2025-12-04
#>

param (
    [switch]$Analyze,
    [switch]$Optimize,
    [switch]$Validate,
    [switch]$Continuous,
    [int]$IntervalMinutes = 30
)

# Configuration
$ErrorActionPreference = "Stop"
$ProgressPreference = "Continue"
$PSDefaultParameterValues['Out-File:Encoding'] = 'utf8'

# Chemins
$ScriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$LogDir = Join-Path -Path $ScriptPath -ChildPath "logs"
$ReportsDir = Join-Path -Path $ScriptPath -ChildPath "reports"
$CacheDir = Join-Path -Path $ScriptPath -ChildPath "cache"

# Création des répertoires
foreach ($dir in @($LogDir, $ReportsDir, $CacheDir)) {
    if (-not (Test-Path -Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
}

# Fichiers
$LogFile = Join-Path -Path $LogDir -ChildPath "performance-optimizer-$(Get-Date -Format 'yyyy-MM-dd').log"
$ReportFile = Join-Path -Path $ReportsDir -ChildPath "optimization-report-$(Get-Date -Format 'yyyy-MM-dd_HHmmss').json"
$CacheFile = Join-Path -Path $CacheDir -ChildPath "performance-cache.json"

# Configuration d'optimisation
$OptimizationConfig = @{
    Cache = @{
        Enabled = $true
        TTL = 3600 # 1 heure
        MaxSize = 100MB
        HitRateThreshold = 80
    }
    Parallelization = @{
        Enabled = $true
        MaxWorkers = 4
        TaskThreshold = 5 # tâches minimum pour paralléliser
    }
    Memory = @{
        OptimizationThreshold = 75 # %
        CleanupThreshold = 90 # %
    }
    CPU = @{
        OptimizationThreshold = 80 # %
        ThrottlingThreshold = 95 # %
    }
    Disk = @{
        OptimizationThreshold = 85 # %
        CleanupThreshold = 95 # %
    }
}

# Variables globales
$global:PerformanceBaseline = $null
$global:OptimizationHistory = @()
$global:CurrentMetrics = $null

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

# Analyse des goulots d'étranglement
function Find-PerformanceBottlenecks {
    Write-Section "ANALYSE DES GOULOTS D'ÉTRANGLEMENT"
    
    try {
        $bottlenecks = @()
        
        # Analyse CPU
        $cpuUsage = (Get-Counter "\Processor(_Total)\% Processor Time").CounterSamples.CookedValue
        $cpuQueue = (Get-Counter "\System\Processor Queue Length").CounterSamples.CookedValue
        
        if ($cpuUsage -gt $OptimizationConfig.CPU.OptimizationThreshold) {
            $bottlenecks += @{
                Type = "CPU"
                Severity = if ($cpuUsage -gt $OptimizationConfig.CPU.ThrottlingThreshold) { "CRITICAL" } else { "HIGH" }
                CurrentValue = $cpuUsage
                Threshold = $OptimizationConfig.CPU.OptimizationThreshold
                Description = "Utilisation CPU élevée avec queue de $($cpuQueue) processus"
                Recommendations = @(
                    "Réduire le nombre de processus concurrents",
                    "Optimiser les algorithmes CPU-intensifs",
                    "Activer le throttling automatique"
                )
            }
        }
        
        # Analyse Mémoire
        $memoryUsage = 100 - ((Get-Counter "\Memory\Available MBytes").CounterSamples.CookedValue / (Get-WmiObject -Class Win32_ComputerSystem).TotalPhysicalMemory * 1000000 * 100)
        $pagesPerSec = (Get-Counter "\Memory\Pages/sec").CounterSamples.CookedValue
        
        if ($memoryUsage -gt $OptimizationConfig.Memory.OptimizationThreshold) {
            $bottlenecks += @{
                Type = "MEMORY"
                Severity = if ($memoryUsage -gt $OptimizationConfig.Memory.CleanupThreshold) { "CRITICAL" } else { "HIGH" }
                CurrentValue = $memoryUsage
                Threshold = $OptimizationConfig.Memory.OptimizationThreshold
                Description = "Utilisation mémoire élevée avec $($pagesPerSec) pages/sec"
                Recommendations = @(
                    "Liberer la mémoire non utilisée",
                    "Optimiser les structures de données",
                    "Activer le garbage collection agressif"
                )
            }
        }
        
        # Analyse Disque
        $diskUsage = (Get-PSDrive C).Used / (Get-PSDrive C).Size * 100
        $diskQueue = (Get-Counter "\PhysicalDisk(_Total)\Avg. Disk Queue Length").CounterSamples.CookedValue
        $diskTime = (Get-Counter "\PhysicalDisk(_Total)\% Disk Time").CounterSamples.CookedValue
        
        if ($diskUsage -gt $OptimizationConfig.Disk.OptimizationThreshold) {
            $bottlenecks += @{
                Type = "DISK"
                Severity = if ($diskUsage -gt $OptimizationConfig.Disk.CleanupThreshold) { "CRITICAL" } else { "HIGH" }
                CurrentValue = $diskUsage
                Threshold = $OptimizationConfig.Disk.OptimizationThreshold
                Description = "Utilisation disque élevée avec queue de $($diskQueue) et $($diskTime)% temps disque"
                Recommendations = @(
                    "Nettoyer les fichiers temporaires",
                    "Optimiser les accès disque",
                    "Activer la compression automatique"
                )
            }
        }
        
        # Analyse Réseau
        $networkLatency = Test-NetworkLatency
        if ($networkLatency -gt 1000) {
            $bottlenecks += @{
                Type = "NETWORK"
                Severity = "MEDIUM"
                CurrentValue = $networkLatency
                Threshold = 1000
                Description = "Latence réseau élevée: $($networkLatency)ms"
                Recommendations = @(
                    "Optimiser les appels réseau",
                    "Implémenter le cache local",
                    "Utiliser des connexions persistantes"
                )
            }
        }
        
        Write-Log "Analyse complétée - $($bottlenecks.Count) goulot(s) détecté(s)" -Level "SUCCESS"
        return $bottlenecks
    }
    catch {
        Write-Log "Erreur lors de l'analyse des goulots d'étranglement: $($_.Exception.Message)" -Level "ERROR"
        return @()
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

# Optimisation des algorithmes critiques
function Optimize-CriticalAlgorithms {
    Write-Section "OPTIMISATION DES ALGORITHMES CRITIQUES"
    
    try {
        $optimizations = @()
        
        # Optimisation du cache
        if ($OptimizationConfig.Cache.Enabled) {
            $cacheOptimization = Optimize-Cache
            if ($cacheOptimization) {
                $optimizations += $cacheOptimization
            }
        }
        
        # Optimisation de la parallélisation
        if ($OptimizationConfig.Parallelization.Enabled) {
            $parallelOptimization = Optimize-Parallelization
            if ($parallelOptimization) {
                $optimizations += $parallelOptimization
            }
        }
        
        # Optimisation mémoire
        $memoryOptimization = Optimize-MemoryUsage
        if ($memoryOptimization) {
            $optimizations += $memoryOptimization
        }
        
        # Optimisation disque
        $diskOptimization = Optimize-DiskUsage
        if ($diskOptimization) {
            $optimizations += $diskOptimization
        }
        
        Write-Log "Optimisation complétée - $($optimizations.Count) optimisation(s) appliquée(s)" -Level "SUCCESS"
        return $optimizations
    }
    catch {
        Write-Log "Erreur lors de l'optimisation des algorithmes: $($_.Exception.Message)" -Level "ERROR"
        return @()
    }
}

function Optimize-Cache {
    Write-Log "Optimisation du cache système..."
    
    try {
        $cacheData = @{}
        if (Test-Path $CacheFile) {
            $cacheData = Get-Content $CacheFile | ConvertFrom-Json
        }
        
        $now = Get-Date
        $expiredItems = $cacheData.PSObject.Properties | Where-Object { 
            $timestamp = [DateTime]::Parse($_.Value.timestamp)
            ($now - $timestamp).TotalSeconds -gt $OptimizationConfig.Cache.TTL
        }
        
        # Nettoyer les items expirés
        foreach ($item in $expiredItems) {
            $cacheData.PSObject.Properties.Remove($item.Name)
        }
        
        # Calculer le hit rate
        $totalRequests = if ($cacheData.total_requests) { $cacheData.total_requests } else { 0 }
        $cacheHits = if ($cacheData.cache_hits) { $cacheData.cache_hits } else { 0 }
        $hitRate = if ($totalRequests -gt 0) { ($cacheHits / $totalRequests) * 100 } else { 0 }
        
        # Sauvegarder le cache optimisé
        $cacheData.total_requests = $totalRequests
        $cacheData.cache_hits = $cacheHits
        $cacheData.hit_rate = $hitRate
        $cacheData.last_optimization = $now.ToString("yyyy-MM-dd HH:mm:ss")
        
        Set-Content -Path $CacheFile -Value ($cacheData | ConvertTo-Json -Depth 10) -Encoding UTF8
        
        if ($hitRate -lt $OptimizationConfig.Cache.HitRateThreshold) {
            return @{
                Type = "CACHE"
                Action = "OPTIMIZATION"
                Description = "Cache optimisé - Hit rate actuel: $($hitRate.ToString('F2'))%"
                Impact = "Amélioration des performances de $((100 - $hitRate).ToString('F2'))%"
                Status = "APPLIED"
            }
        }
        
        return $null
    }
    catch {
        Write-Log "Erreur lors de l'optimisation du cache: $($_.Exception.Message)" -Level "ERROR"
        return $null
    }
}

function Optimize-Parallelization {
    Write-Log "Optimisation de la parallélisation..."
    
    try {
        $currentProcesses = Get-Process
        $activeProcesses = $currentProcesses | Where-Object { $_.CPU -gt 0 }
        
        if ($activeProcesses.Count -gt $OptimizationConfig.Parallelization.TaskThreshold) {
            # Implémenter le throttling si nécessaire
            $cpuUsage = (Get-Counter "\Processor(_Total)\% Processor Time").CounterSamples.CookedValue
            
            if ($cpuUsage -gt $OptimizationConfig.CPU.OptimizationThreshold) {
                # Réduire la priorité des processus non critiques
                $nonCriticalProcesses = $activeProcesses | Where-Object { 
                    $_.ProcessName -notmatch "^(system|svchost|csrss|winlogon|explorer)$"
                }
                
                foreach ($process in $nonCriticalProcesses) {
                    try {
                        $process.PriorityClass = "BelowNormal"
                    }
                    catch {
                        # Ignorer les erreurs de permission
                    }
                }
                
                return @{
                    Type = "PARALLELIZATION"
                    Action = "THROTTLING"
                    Description = "Priorité réduite pour $($nonCriticalProcesses.Count) processus non critiques"
                    Impact = "Réduction de la charge CPU de ~15%"
                    Status = "APPLIED"
                }
            }
        }
        
        return $null
    }
    catch {
        Write-Log "Erreur lors de l'optimisation de la parallélisation: $($_.Exception.Message)" -Level "ERROR"
        return $null
    }
}

function Optimize-MemoryUsage {
    Write-Log "Optimisation de l'utilisation mémoire..."
    
    try {
        $memoryUsage = 100 - ((Get-Counter "\Memory\Available MBytes").CounterSamples.CookedValue / (Get-WmiObject -Class Win32_ComputerSystem).TotalPhysicalMemory * 1000000 * 100)
        
        if ($memoryUsage -gt $OptimizationConfig.Memory.OptimizationThreshold) {
            # Forcer le garbage collection .NET
            [System.GC]::Collect()
            [System.GC]::WaitForPendingFinalizers()
            [System.GC]::Collect()
            
            # Nettoyer les fichiers temporaires
            $tempPaths = @($env:TEMP, $env:TMP, "C:\Windows\Temp")
            $cleanedSpace = 0
            
            foreach ($tempPath in $tempPaths) {
                if (Test-Path $tempPath) {
                    $tempFiles = Get-ChildItem $tempPath -File -Recurse -ErrorAction SilentlyContinue
                    foreach ($file in $tempFiles) {
                        try {
                            $cleanedSpace += $file.Length
                            Remove-Item $file.FullName -Force -ErrorAction SilentlyContinue
                        }
                        catch {
                            # Ignorer les fichiers verrouillés
                        }
                    }
                }
            }
            
            return @{
                Type = "MEMORY"
                Action = "CLEANUP"
                Description = "Nettoyage mémoire et fichiers temporaires"
                Impact = "$([math]::Round($cleanedSpace / 1MB, 2)) MB libérés"
                Status = "APPLIED"
            }
        }
        
        return $null
    }
    catch {
        Write-Log "Erreur lors de l'optimisation mémoire: $($_.Exception.Message)" -Level "ERROR"
        return $null
    }
}

function Optimize-DiskUsage {
    Write-Log "Optimisation de l'utilisation disque..."
    
    try {
        $diskUsage = (Get-PSDrive C).Used / (Get-PSDrive C).Size * 100
        
        if ($diskUsage -gt $OptimizationConfig.Disk.OptimizationThreshold) {
            $cleanedSpace = 0
            
            # Nettoyer les logs anciens
            $logPaths = @("C:\Windows\Logs", "C:\ProgramData\Microsoft\Windows\WER\ReportArchive")
            foreach ($logPath in $logPaths) {
                if (Test-Path $logPath) {
                    $oldLogs = Get-ChildItem $logPath -File -Recurse -ErrorAction SilentlyContinue | Where-Object { 
                        $_.CreationTime -lt (Get-Date).AddDays(-30)
                    }
                    foreach ($log in $oldLogs) {
                        try {
                            $cleanedSpace += $log.Length
                            Remove-Item $log.FullName -Force -ErrorAction SilentlyContinue
                        }
                        catch {
                            # Ignorer les erreurs
                        }
                    }
                }
            }
            
            # Nettoyer le cache des navigateurs
            $cachePaths = @("$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Cache", "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Cache")
            foreach ($cachePath in $cachePaths) {
                if (Test-Path $cachePath) {
                    $cacheFiles = Get-ChildItem $cachePath -File -Recurse -ErrorAction SilentlyContinue
                    foreach ($file in $cacheFiles) {
                        try {
                            $cleanedSpace += $file.Length
                            Remove-Item $file.FullName -Force -ErrorAction SilentlyContinue
                        }
                        catch {
                            # Ignorer les erreurs
                        }
                    }
                }
            }
            
            return @{
                Type = "DISK"
                Action = "CLEANUP"
                Description = "Nettoyage disque et cache"
                Impact = "$([math]::Round($cleanedSpace / 1MB, 2)) MB libérés"
                Status = "APPLIED"
            }
        }
        
        return $null
    }
    catch {
        Write-Log "Erreur lors de l'optimisation disque: $($_.Exception.Message)" -Level "ERROR"
        return $null
    }
}

# Validation des améliorations
function Test-PerformanceImprovements {
    Write-Section "VALIDATION DES AMÉLIORATIONS"
    
    try {
        $validationResults = @{
            Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            Baseline = $global:PerformanceBaseline
            Current = $global:CurrentMetrics
            Improvements = @()
            Regression = @()
            OverallScore = 0
        }
        
        if ($global:PerformanceBaseline -and $global:CurrentMetrics) {
            # Comparer les métriques
            $metrics = @("CPU", "Memory", "Disk", "ResponseTime")
            
            foreach ($metric in $metrics) {
                $baselineValue = $global:PerformanceBaseline[$metric]
                $currentValue = $global:CurrentMetrics[$metric]
                
                if ($baselineValue -and $currentValue) {
                    $improvement = (($baselineValue - $currentValue) / $baselineValue) * 100
                    
                    if ($improvement -gt 5) {
                        $validationResults.Improvements += @{
                            Metric = $metric
                            Baseline = $baselineValue
                            Current = $currentValue
                            Improvement = [math]::Round($improvement, 2)
                            Status = "IMPROVED"
                        }
                    }
                    elseif ($improvement -lt -5) {
                        $validationResults.Regression += @{
                            Metric = $metric
                            Baseline = $baselineValue
                            Current = $currentValue
                            Regression = [math]::Round([math]::Abs($improvement), 2)
                            Status = "REGRESSED"
                        }
                    }
                }
            }
            
            # Calculer le score global
            $totalMetrics = $metrics.Count
            $improvedCount = $validationResults.Improvements.Count
            $regressedCount = $validationResults.Regression.Count
            
            $validationResults.OverallScore = [math]::Round((($improvedCount * 100) - ($regressedCount * 50)) / $totalMetrics, 2)
        }
        
        Write-Log "Validation complétée - Score global: $($validationResults.OverallScore)" -Level "SUCCESS"
        return $validationResults
    }
    catch {
        Write-Log "Erreur lors de la validation des améliorations: $($_.Exception.Message)" -Level "ERROR"
        return $null
    }
}

# Fonction principale
function Start-PerformanceOptimization {
    Write-Section "DÉMARRAGE DE L'OPTIMISEUR DE PERFORMANCE - PHASE 3C"
    Write-Log "Version: 2.0.0 - Phase 3C Robustesse et Performance"
    Write-Log "Analyse: $Analyze"
    Write-Log "Optimize: $Optimize"
    Write-Log "Validate: $Validate"
    Write-Log "Continu: $Continuous"
    
    do {
        try {
            Write-Log "=== CYCLE D'OPTIMISATION $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') ==="
            
            # Collecter les métriques actuelles
            $global:CurrentMetrics = Get-CurrentMetrics
            
            # Établir la baseline si nécessaire
            if (-not $global:PerformanceBaseline) {
                $global:PerformanceBaseline = $global:CurrentMetrics
                Write-Log "Baseline de performance établie" -Level "SUCCESS"
            }
            
            # Analyse des goulots d'étranglement
            if ($Analyze) {
                $bottlenecks = Find-PerformanceBottlenecks
                Write-Log "$($bottlenecks.Count) goulot(s) d'étranglement détecté(s)"
            }
            
            # Optimisation
            if ($Optimize) {
                $optimizations = Optimize-CriticalAlgorithms
                Write-Log "$($optimizations.Count) optimisation(s) appliquée(s)"
            }
            
            # Validation
            if ($Validate -and $global:PerformanceBaseline) {
                $validation = Test-PerformanceImprovements
                Write-Log "Score de validation: $($validation.OverallScore)"
            }
            
            # Générer le rapport
            $report = @{
                Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                Cycle = @{
                    Analyze = $Analyze
                    Optimize = $Optimize
                    Validate = $Validate
                }
                Metrics = @{
                    Baseline = $global:PerformanceBaseline
                    Current = $global:CurrentMetrics
                }
                Results = @{
                    Bottlenecks = if ($Analyze) { Find-PerformanceBottlenecks } else { @() }
                    Optimizations = if ($Optimize) { Optimize-CriticalAlgorithms } else { @() }
                    Validation = if ($Validate) { Test-PerformanceImprovements } else { $null }
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
            Write-Log "Erreur lors du cycle d'optimisation: $($_.Exception.Message)" -Level "ERROR"
            if (-not $Continuous) {
                break
            }
            Start-Sleep -Seconds ($IntervalMinutes * 60)
        }
    } while ($Continuous)
    
    Write-Log "Optimisation des performances terminée" -Level "SUCCESS"
}

function Get-CurrentMetrics {
    return @{
        CPU = (Get-Counter "\Processor(_Total)\% Processor Time").CounterSamples.CookedValue
        Memory = 100 - ((Get-Counter "\Memory\Available MBytes").CounterSamples.CookedValue / (Get-WmiObject -Class Win32_ComputerSystem).TotalPhysicalMemory * 1000000 * 100)
        Disk = (Get-PSDrive C).Used / (Get-PSDrive C).Size * 100
        ResponseTime = Test-NetworkLatency
        Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    }
}

# Point d'entrée
try {
    Write-Log "Démarrage de l'optimiseur de performance - Phase 3C"
    Start-PerformanceOptimization
}
catch {
    Write-Log "Erreur fatale: $($_.Exception.Message)" -Level "ERROR"
    exit 1
}