# Script PowerShell pour surveiller TurboQuant

# Configuration
$ScriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$NodePath = "node"
$MonitorScript = Join-Path $ScriptPath "monitor-turboquant.js"
$ReportsDir = Join-Path $ScriptPath "..\reports"
$LogPath = Join-Path $ReportsDir "turboquant-monitor.log"

# S'assurer que les répertoires existent
if (-not (Test-Path $ReportsDir)) {
    New-Item -ItemType Directory -Path $ReportsDir -Force | Out-Null
}

# Fonction de logging
function Write-Log {
    param (
        [string]$Message,
        [string]$Level = "INFO"
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    Add-Content -Path $LogPath -Value $logEntry
    Write-Host $logEntry
}

# Vérifier Node.js
try {
    $nodeVersion = & $nodePath --version 2>$null
    if ($LASTEXITCODE -ne 0) {
        throw "Node.js is not available or not working"
    }
    Write-Log "Node.js version: $nodeVersion"
} catch {
    Write-Log "Node.js not found: $_" "ERROR"
    exit 1
}

# Exécuter le script Node.js
Write-Log "Starting TurboQuant monitoring..."

try {
    $env:NODE_ENV = "production"
    $result = & $NodePath $MonitorScript

    if ($LASTEXITCODE -eq 0) {
        Write-Log "Monitoring completed successfully"
    } else {
        Write-Log "Monitoring failed with exit code $LASTEXITCODE" "ERROR"
    }
} catch {
    Write-Log "Error executing monitoring script: $_" "ERROR"
}

# Nettoyer les anciens rapports (garder les 7 derniers jours)
Write-Log "Cleaning up old reports..."
$oldReports = Get-ChildItem $ReportsDir "turboquant-monitor-*.json" | Where-Object { $_.CreationTime -lt (Get-Date).AddDays(-7) }
foreach ($report in $oldReports) {
    Remove-Item $report.FullName -Force
    Write-Log "Removed old report: $($report.Name)"
}

Write-Log "Monitoring cycle completed"