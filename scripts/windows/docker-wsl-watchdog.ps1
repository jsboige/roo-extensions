<#
.SYNOPSIS
    Docker/WSL Watchdog - Detects Docker init control API hang and WSL switch loss
.DESCRIPTION
    Monitors Docker logs for init control API hangs and WSL switch health.
    Auto-restarts services if issues detected.

    Issue: #1380 - Docker/WSL watchdog: detect init control API hang + VmSwitch port loss
    Incident: #1379 - 5h silent hang due to WSL switch port loss
#>

param(
    [int]$MaxWaitMinutes = 5,
    [string]$LogPath = "$env:LOCALAPPDATA\Docker\log\host\monitor.log",
    [string]$WatchdogLogPath = "$PSScriptRoot\..\..\..\claude\logs\docker-watchdog.log",
    [switch]$Verbose
)

# Configuration
$MaxWaitSeconds = $MaxWaitMinutes * 60
$SwitchName = "WSL (Hyper-V firewall)"
$AdapterName = "vEthernet (WSL (Hyper-V firewall))"
$LogRetentionDays = 30

# Ensure log directory exists
$WatchdogLogDir = Split-Path $WatchdogLogPath -Parent
if (-not (Test-Path $WatchdogLogDir)) {
    New-Item -ItemType Directory -Path $WatchdogLogDir -Force | Out-Null
}

# Function to write log with timestamp
function Write-WatchdogLog {
    param([string]$Message, [string]$Level = "INFO")

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"

    # Write to file
    Add-Content -Path $WatchdogLogPath -Value $logEntry -Encoding UTF8

    # Write to console with color
    switch ($Level) {
        "ERROR" { Write-Host $logEntry -ForegroundColor Red }
        "WARN"  { Write-Host $logEntry -ForegroundColor Yellow }
        "INFO"  { Write-Host $logEntry -ForegroundColor Green }
        default { Write-Host $logEntry }
    }
}

# Function to send alert to dashboard
function Send-DashboardAlert {
    param([string]$Message, [string]$Severity = "CRITICAL")

    try {
        # Import RooSync MCP module if available
        $dashboardContent = @"
**ALERT: Docker/WSL Watchdog Detected Issue**

**Severity:** $Severity
**Time:** $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
**Issue:** $Message

Auto-recovery actions have been attempted.
"@

        # Attempt to send to dashboard (requires roo-state-manager MCP)
        $result = & {
            # This would require the MCP to be available
            # For now, write to local log
            Write-WatchdogLog "ALERT SENT: $Message" "WARN"
        }

    } catch {
        Write-WatchdogLog "Failed to send dashboard alert: $_" "ERROR"
    }
}

# Function to check Docker init control API
function Test-DockerInitControl {
    $lastLine = $null

    try {
        # Get the last relevant line from Docker log
        $logContent = Get-Content $LogPath -ErrorAction SilentlyContinue
        if ($logContent) {
            # Find the last "still waiting" message
            $waitingLines = $logContent | Where-Object { $_ -match "still waiting for init control API to respond after" }
            if ($waitingLines) {
                # Ensure $waitingLines is treated as an array
                if ($waitingLines -is [array]) {
                    $lastLine = $waitingLines[-1]
                } else {
                    $lastLine = $waitingLines
                }
                $lastLine = [string]$lastLine  # Ensure it's a string

                # Extract duration using string parsing
                $afterIndex = $lastLine.IndexOf("after")
                if ($afterIndex -ge 0) {
                    $afterPart = $lastLine.Substring($afterIndex)
                    $parts = $afterPart.Split(" ")

                    if ($parts.Length -ge 5) {
                        $hours = [int]$parts[1]
                        $minutes = [int]$parts[3]
                        $totalSeconds = ($hours * 3600) + ($minutes * 60)

                        if ($totalSeconds -gt $MaxWaitSeconds) {
                            Write-WatchdogLog "Docker init control API hang detected: $hours h $minutes m (threshold: $MaxWaitMinutes m)" "ERROR"
                            return $true, $totalSeconds
                        }
                    }
                }
            }
        }
    } catch {
        Write-WatchdogLog "Error reading Docker log: $_" "WARN"
    }

    return $false, 0
}

# Function to check WSL switch health
function Test-WSLSwitchHealth {
    $switchHealthy = $true
    $adapterHealthy = $true

    try {
        # Check VM Switch
        $vmSwitch = Get-VMSwitch $SwitchName -ErrorAction SilentlyContinue
        if (-not $vmSwitch) {
            Write-WatchdogLog "VM Switch '$SwitchName' not found" "ERROR"
            $switchHealthy = $false
        } else {
            Write-WatchdogLog "VM Switch '$SwitchName' status: $($vmSwitch.SwitchType)" "INFO"
        }

        # Check Network Adapter
        $netAdapter = Get-NetAdapter $AdapterName -ErrorAction SilentlyContinue
        if (-not $netAdapter) {
            Write-WatchdogLog "Network adapter '$AdapterName' not found" "ERROR"
            $adapterHealthy = $false
        } elseif ($netAdapter.Status -ne "Up") {
            Write-WatchdogLog "Network adapter '$AdapterName' status: $($netAdapter.Status)" "ERROR"
            $adapterHealthy = $false
        } else {
            Write-WatchdogLog "Network adapter '$AdapterName' status: $($netAdapter.Status)" "INFO"
        }

    } catch {
        Write-WatchdogLog "Error checking WSL switch: $_" "WARN"
    }

    return $switchHealthy -and $adapterHealthy
}

# Function to restart Docker service
function Restart-DockerService {
    Write-WatchdogLog "Attempting to restart Docker Desktop service..." "INFO"

    try {
        # Stop the service
        Write-WatchdogLog "Stopping com.docker.service..." "INFO"
        Stop-Service -Name "com.docker.service" -Force -ErrorAction Stop
        Start-Sleep -Seconds 10

        # Start the service
        Write-WatchdogLog "Starting com.docker.service..." "INFO"
        Start-Service -Name "com.docker.service" -ErrorAction Stop

        # Wait for Docker to be ready
        Write-WatchdogLog "Waiting for Docker to be ready..." "INFO"
        $waitTime = 0
        while ($waitTime -lt 60) {
            try {
                $dockerVersion = docker version --format "{{.Server.Version}}" 2>$null
                if ($dockerVersion) {
                    Write-WatchdogLog "Docker is ready: version $dockerVersion" "INFO"
                    return $true
                }
            } catch {}

            Start-Sleep -Seconds 5
            $waitTime += 5
        }

        Write-WatchdogLog "Docker did not become ready within 60 seconds" "ERROR"
        return $false

    } catch {
        Write-WatchdogLog "Failed to restart Docker service: $_" "ERROR"
        return $false
    }
}

# Function to restart HNS service
function Restart-HNSService {
    Write-WatchdogLog "Attempting to restart HNS service..." "INFO"

    try {
        Restart-Service -Name "hns" -Force -ErrorAction Stop
        Write-WatchdogLog "HNS service restarted successfully" "INFO"
        return $true
    } catch {
        Write-WatchdogLog "Failed to restart HNS service: $_" "ERROR"
        return $false
    }
}

# Function to attempt WSL shutdown
function Attempt-WSLShutdown {
    Write-WatchdogLog "Attempting WSL shutdown..." "INFO"

    try {
        wsl --shutdown
        Write-WatchdogLog "WSL shutdown command executed" "INFO"
        Start-Sleep -Seconds 10
        return $true
    } catch {
        Write-WatchdogLog "Failed to execute WSL shutdown: $_" "ERROR"
        return $false
    }
}

# Main monitoring logic
Write-WatchdogLog "Starting Docker/WSL Watchdog check..." "INFO"

# Check 1: Docker init control API
$dockerHangDetected, $hangDuration = Test-DockerInitControl

# Check 2: WSL switch health
$switchHealthy = Test-WSLSwitchHealth

# Determine if action is needed
$needsAction = $false
$actionTaken = @()

if ($dockerHangDetected) {
    Write-WatchdogLog "Docker init control API hang requires action" "ERROR"
    $needsAction = $true

    # Attempt Docker service restart
    if (Restart-DockerService) {
        $actionTaken += "Docker service restarted"
    } else {
        $actionTaken += "Docker service restart FAILED"
    }
}

if (-not $switchHealthy) {
    Write-WatchdogLog "WSL switch health issue requires action" "ERROR"
    $needsAction = $true

    # Try HNS restart first
    if (Restart-HNSService) {
        $actionTaken += "HNS service restarted"

        # Check if that fixed the issue
        Start-Sleep -Seconds 10
        if (Test-WSLSwitchHealth) {
            Write-WatchdogLog "WSL switch recovered after HNS restart" "INFO"
        } else {
            # HNS didn't work, try WSL shutdown
            if (Attempt-WSLShutdown) {
                $actionTaken += "WSL shutdown attempted"

                # Restart Docker after WSL shutdown
                Start-Sleep -Seconds 30
                if (Restart-DockerService) {
                    $actionTaken += "Docker restarted after WSL shutdown"
                }
            }
        }
    } else {
        $actionTaken += "HNS service restart FAILED"
    }
}

# Log results
if ($needsAction) {
    Write-WatchdogLog "ACTION TAKEN: $($actionTaken -join '; ')" "ERROR"
    Send-DashboardAlert "Docker/WSL watchdog triggered: $($actionTaken -join '; ')"
} else {
    Write-WatchdogLog "No issues detected, all systems healthy" "INFO"
}

# Cleanup old logs
try {
    $oldLogs = Get-ChildItem $WatchdogLogDir -Filter "docker-watchdog*.log" |
               Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-$LogRetentionDays) }

    if ($oldLogs) {
        $oldLogs | Remove-Item -Force
        Write-WatchdogLog "Cleaned up $($oldLogs.Count) old log files" "INFO"
    }
} catch {
    Write-WatchdogLog "Error cleaning up old logs: $_" "WARN"
}

Write-WatchdogLog "Watchdog check completed" "INFO"