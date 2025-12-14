# ============================================================================
# Script de Surveillance Quotidienne Roo Extensions
# Version: 1.0.0
# Description: Surveillance complète avec diagnostic MCP, maintenance et logging
# ============================================================================

param(
    [switch]$Verbose = $false,
    [string]$LogLevel = "INFO"
)

# Configuration globale
$Global:MonitoringConfig = @{
    BasePath = "d:/Dev/roo-extensions"
    ExecutionId = [System.Guid]::NewGuid().ToString()
    StartTime = Get-Date
    LogLevel = $LogLevel
    Verbose = $Verbose
    LogDir = "logs/daily-monitoring"
}

# Initialisation
Set-Location $Global:MonitoringConfig.BasePath
$LogDir = Join-Path $Global:MonitoringConfig.BasePath $Global:MonitoringConfig.LogDir
if (-not (Test-Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
}

$LogFile = Join-Path $LogDir "monitoring-$(Get-Date -Format 'yyyyMMdd').log"
$ReportFile = Join-Path $LogDir "health-report-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"

# ============================================================================
# FONCTIONS UTILITAIRES
# ============================================================================

function Write-MonitoringLog {
    param(
        [string]$Message,
        [string]$Level = "INFO",
        [string]$Component = "SYSTEM",
        [hashtable]$Data = @{}
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
    $logEntry = @{
        timestamp = $timestamp
        execution_id = $Global:MonitoringConfig.ExecutionId
        level = $Level
        component = $Component
        message = $Message
        data = $Data
    }
    
    # Affichage console avec couleurs
    $color = switch ($Level) {
        "ERROR" { "Red" }
        "WARNING" { "Yellow" }
        "SUCCESS" { "Green" }
        "INFO" { "Cyan" }
        default { "White" }
    }
    
    $displayMessage = "[$timestamp] [$Level] [$Component] $Message"
    Write-Host $displayMessage -ForegroundColor $color
    
    # Écriture dans le fichier log
    $logLine = $logEntry | ConvertTo-Json -Compress
    Add-Content -Path $LogFile -Value $logLine
    
    return $logEntry
}

function Test-GitHealth {
    Write-MonitoringLog "Début du diagnostic Git" "INFO" "GIT"
    
    $results = @{
        status = "SUCCESS"
        issues = @()
        details = @{}
    }
    
    try {
        # Vérification du statut Git
        $gitStatus = git status --porcelain 2>&1
        if ($LASTEXITCODE -ne 0) {
            $results.status = "ERROR"
            $results.issues += "Git status failed: $gitStatus"
        } else {
            $results.details.uncommitted_changes = ($gitStatus | Measure-Object).Count
            Write-MonitoringLog "Git status: $($results.details.uncommitted_changes) fichiers modifiés" "INFO" "GIT"
        }
        
        # Vérification des remotes
        $remotes = git remote -v 2>&1
        if ($LASTEXITCODE -eq 0) {
            $results.details.remotes = $remotes -split "`n" | Where-Object { $_ -ne "" }
            Write-MonitoringLog "Remotes Git configurés: $($results.details.remotes.Count)" "INFO" "GIT"
        }
        
        # Vérification des branches
        $branches = git branch -a 2>&1
        if ($LASTEXITCODE -eq 0) {
            $results.details.branches = $branches -split "`n" | Where-Object { $_ -ne "" }
            Write-MonitoringLog "Branches disponibles: $($results.details.branches.Count)" "INFO" "GIT"
        }
        
    } catch {
        $results.status = "ERROR"
        $results.issues += "Git health check failed: $_"
        Write-MonitoringLog "Erreur lors du diagnostic Git: $_" "ERROR" "GIT"
    }
    
    return $results
}

function Test-McpHealth {
    Write-MonitoringLog "Début du diagnostic MCP" "INFO" "MCP"
    
    $results = @{
        status = "SUCCESS"
        issues = @()
        details = @{}
    }
    
    try {
        # Exécution du script de diagnostic MCP
        $mcpScript = "roo-config/mcp-diagnostic-repair.ps1"
        if (Test-Path $mcpScript) {
            $mcpResult = & $mcpScript -Validate 2>&1
            $results.details.mcp_diagnostic = $mcpResult
            
            if ($mcpResult -match "CRITIQUE|ERREUR|X ") {
                $results.status = "WARNING"
                $results.issues += "Problèmes MCP détectés"
                Write-MonitoringLog "Problèmes MCP détectés" "WARNING" "MCP"
            } else {
                Write-MonitoringLog "MCPs en bon état" "SUCCESS" "MCP"
            }
        } else {
            $results.status = "WARNING"
            $results.issues += "Script de diagnostic MCP introuvable"
            Write-MonitoringLog "Script de diagnostic MCP introuvable" "WARNING" "MCP"
        }
        
    } catch {
        $results.status = "ERROR"
        $results.issues += "MCP health check failed: $_"
        Write-MonitoringLog "Erreur lors du diagnostic MCP: $_" "ERROR" "MCP"
    }
    
    return $results
}

function Test-ConfigurationFiles {
    Write-MonitoringLog "Début de la validation des configurations" "INFO" "CONFIG"
    
    $results = @{
        status = "SUCCESS"
        issues = @()
        details = @{}
    }
    
    $criticalFiles = @(
        "roo-config/settings/settings.json",
        "roo-config/settings/servers.json",
        "roo-config/settings/modes.json",
        ".roo/schedules.json"
    )
    
    $validFiles = 0
    $totalFiles = $criticalFiles.Count
    
    foreach ($file in $criticalFiles) {
        try {
            if (Test-Path $file) {
                $content = Get-Content $file -Raw | ConvertFrom-Json
                $validFiles++
                Write-MonitoringLog "Configuration valide: $file" "SUCCESS" "CONFIG"
            } else {
                $results.status = "WARNING"
                $results.issues += "Fichier manquant: $file"
                Write-MonitoringLog "Fichier manquant: $file" "WARNING" "CONFIG"
            }
        } catch {
            $results.status = "ERROR"
            $results.issues += "Erreur JSON dans $file : $_"
            Write-MonitoringLog "Erreur JSON dans $file : $_" "ERROR" "CONFIG"
        }
    }
    
    $results.details.valid_files = $validFiles
    $results.details.total_files = $totalFiles
    $results.details.validation_rate = [math]::Round(($validFiles / $totalFiles) * 100, 2)
    
    Write-MonitoringLog "Validation configurations: $validFiles/$totalFiles fichiers valides ($($results.details.validation_rate)%)" "INFO" "CONFIG"
    
    return $results
}

function Invoke-MaintenanceCleanup {
    Write-MonitoringLog "Début du nettoyage de maintenance" "INFO" "CLEANUP"
    
    $results = @{
        status = "SUCCESS"
        issues = @()
        details = @{}
    }
    
    try {
        # Exécution du script de maintenance
        $maintenanceScript = "roo-config/maintenance-routine.ps1"
        if (Test-Path $maintenanceScript) {
            $maintenanceResult = & $maintenanceScript 2>&1
            $results.details.maintenance_output = $maintenanceResult
            Write-MonitoringLog "Script de maintenance exécuté" "SUCCESS" "CLEANUP"
        } else {
            $results.status = "WARNING"
            $results.issues += "Script de maintenance introuvable"
            Write-MonitoringLog "Script de maintenance introuvable" "WARNING" "CLEANUP"
        }
        
        # Nettoyage des logs anciens (> 30 jours)
        $logDirs = @("logs", "sync_conflicts", "tests/results")
        $cleanedFiles = 0
        
        foreach ($dir in $logDirs) {
            if (Test-Path $dir) {
                $oldFiles = Get-ChildItem -Path $dir -Recurse -File | Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-30) }
                foreach ($file in $oldFiles) {
                    try {
                        Remove-Item $file.FullName -Force
                        $cleanedFiles++
                    } catch {
                        Write-MonitoringLog "Impossible de supprimer: $($file.FullName)" "WARNING" "CLEANUP"
                    }
                }
            }
        }
        
        $results.details.cleaned_files = $cleanedFiles
        Write-MonitoringLog "Nettoyage terminé: $cleanedFiles fichiers supprimés" "SUCCESS" "CLEANUP"
        
    } catch {
        $results.status = "ERROR"
        $results.issues += "Cleanup failed: $_"
        Write-MonitoringLog "Erreur lors du nettoyage: $_" "ERROR" "CLEANUP"
    }
    
    return $results
}

function Test-SystemIntegrity {
    Write-MonitoringLog "Début de la vérification d'intégrité système" "INFO" "INTEGRITY"
    
    $results = @{
        status = "SUCCESS"
        issues = @()
        details = @{}
    }
    
    try {
        # Vérification de l'espace disque
        $drive = Get-WmiObject -Class Win32_LogicalDisk -Filter "DeviceID='D:'"
        $freeSpaceGB = [math]::Round($drive.FreeSpace / 1GB, 2)
        $totalSpaceGB = [math]::Round($drive.Size / 1GB, 2)
        $usagePercent = [math]::Round((($drive.Size - $drive.FreeSpace) / $drive.Size) * 100, 2)
        
        $results.details.disk_space = @{
            free_gb = $freeSpaceGB
            total_gb = $totalSpaceGB
            usage_percent = $usagePercent
        }
        
        if ($freeSpaceGB -lt 5) {
            $results.status = "WARNING"
            $results.issues += "Espace disque faible: $freeSpaceGB GB disponibles"
            Write-MonitoringLog "Espace disque faible: $freeSpaceGB GB disponibles" "WARNING" "INTEGRITY"
        } else {
            Write-MonitoringLog "Espace disque OK: $freeSpaceGB GB disponibles ($usagePercent% utilisé)" "SUCCESS" "INTEGRITY"
        }
        
        # Vérification de la connectivité réseau
        $networkTests = @("github.com", "api.github.com")
        $networkResults = @{}
        
        foreach ($testHost in $networkTests) {
            try {
                $result = Test-NetConnection -ComputerName $testHost -Port 443 -WarningAction SilentlyContinue
                $networkResults[$testHost] = $result.TcpTestSucceeded
                if ($result.TcpTestSucceeded) {
                    Write-MonitoringLog "Connectivité OK: $testHost" "SUCCESS" "INTEGRITY"
                } else {
                    $results.status = "WARNING"
                    $results.issues += "Connectivité échouée: $testHost"
                    Write-MonitoringLog "Connectivité échouée: $testHost" "WARNING" "INTEGRITY"
                }
            } catch {
                $networkResults[$testHost] = $false
                $results.status = "WARNING"
                $results.issues += "Test réseau échoué pour $testHost : $_"
                Write-MonitoringLog "Test réseau échoué pour $testHost : $_" "WARNING" "INTEGRITY"
            }
        }
        
        $results.details.network_connectivity = $networkResults
        
    } catch {
        $results.status = "ERROR"
        $results.issues += "System integrity check failed: $_"
        Write-MonitoringLog "Erreur lors de la vérification d'intégrité: $_" "ERROR" "INTEGRITY"
    }
    
    return $results
}

function Generate-HealthReport {
    param(
        $GitResults,
        $McpResults,
        $ConfigResults,
        $CleanupResults,
        $IntegrityResults
    )
    
    Write-MonitoringLog "Génération du rapport de santé" "INFO" "REPORT"
    
    $overallStatus = "SUCCESS"
    $totalIssues = 0
    
    # Déterminer le statut global
    $allResults = @($GitResults, $McpResults, $ConfigResults, $CleanupResults, $IntegrityResults)
    foreach ($result in $allResults) {
        if ($result.status -eq "ERROR") {
            $overallStatus = "ERROR"
        } elseif ($result.status -eq "WARNING" -and $overallStatus -ne "ERROR") {
            $overallStatus = "WARNING"
        }
        $totalIssues += $result.issues.Count
    }
    
    $report = @{
        execution_info = @{
            execution_id = $Global:MonitoringConfig.ExecutionId
            start_time = $Global:MonitoringConfig.StartTime
            end_time = Get-Date
            duration_seconds = [math]::Round(((Get-Date) - $Global:MonitoringConfig.StartTime).TotalSeconds, 2)
        }
        overall_status = $overallStatus
        total_issues = $totalIssues
        components = @{
            git = $GitResults
            mcp = $McpResults
            configuration = $ConfigResults
            cleanup = $CleanupResults
            integrity = $IntegrityResults
        }
        summary = @{
            git_health = $GitResults.status
            mcp_health = $McpResults.status
            config_health = $ConfigResults.status
            cleanup_status = $CleanupResults.status
            integrity_status = $IntegrityResults.status
        }
        recommendations = @()
    }
    
    # Générer des recommandations
    if ($GitResults.issues.Count -gt 0) {
        $report.recommendations += "Vérifier et résoudre les problèmes Git détectés"
    }
    if ($McpResults.issues.Count -gt 0) {
        $report.recommendations += "Exécuter la réparation MCP avec: roo-config/mcp-diagnostic-repair.ps1 -Repair"
    }
    if ($ConfigResults.issues.Count -gt 0) {
        $report.recommendations += "Vérifier et corriger les fichiers de configuration"
    }
    if ($IntegrityResults.issues.Count -gt 0) {
        $report.recommendations += "Vérifier l'espace disque et la connectivité réseau"
    }
    
    # Sauvegarder le rapport
    $report | ConvertTo-Json -Depth 10 | Out-File -FilePath $ReportFile -Encoding UTF8
    
    Write-MonitoringLog "Rapport de santé généré: $ReportFile" "SUCCESS" "REPORT"
    Write-MonitoringLog "Statut global: $overallStatus ($totalIssues problèmes détectés)" "INFO" "REPORT"
    
    return $report
}

# ============================================================================
# EXECUTION PRINCIPALE
# ============================================================================

function Start-DailyMonitoring {
    Write-MonitoringLog "=== DÉBUT DE LA SURVEILLANCE QUOTIDIENNE ===" "INFO" "MAIN"
    Write-MonitoringLog "ID d'exécution: $($Global:MonitoringConfig.ExecutionId)" "INFO" "MAIN"
    
    try {
        # Exécution des diagnostics
        $gitResults = Test-GitHealth
        $mcpResults = Test-McpHealth
        $configResults = Test-ConfigurationFiles
        $cleanupResults = Invoke-MaintenanceCleanup
        $integrityResults = Test-SystemIntegrity
        
        # Génération du rapport
        $report = Generate-HealthReport $gitResults $mcpResults $configResults $cleanupResults $integrityResults
        
        Write-MonitoringLog "=== SURVEILLANCE QUOTIDIENNE TERMINÉE ===" "SUCCESS" "MAIN"
        Write-MonitoringLog "Durée totale: $($report.execution_info.duration_seconds) secondes" "INFO" "MAIN"
        
        return $report
        
    } catch {
        Write-MonitoringLog "Erreur critique lors de la surveillance: $_" "ERROR" "MAIN"
        throw
    }
}

# Exécution si le script est appelé directement
if ($MyInvocation.InvocationName -ne '.') {
    Start-DailyMonitoring
}