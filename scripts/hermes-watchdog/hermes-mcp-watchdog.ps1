<#
.SYNOPSIS
    Watchdog for Hermes MCP-remote bridge (auto-restart on ClosedResourceError).

.DESCRIPTION
    Monitors the mcp-remote bridge inside Hermes Docker containers and auto-restarts
    when the bridge enters a ClosedResourceError state (fails to reconnect after upstream outage).

    Detection methods:
      1. Log scraping: scans container logs for error patterns sustained over time
      2. Process health: checks if mcp-remote process is responsive
      3. Docker health: verifies container is running and healthy

    Recovery action: docker restart <container> to recycle the mcp-remote bridge.

    Designed to run as a scheduled task (SYSTEM, every 5 min) on myia-po-2026.

.PARAMETER Mode
    'poll' (default): run one shot and exit. 'dry-run': probe only, never repair.

.PARAMETER ContainerName
    Hermes container name to monitor. Default: 'hermes' (gateway).
    Use 'hermes-dashboard' to monitor the dashboard container.

.PARAMETER ErrorThresholdMinutes
    Minutes of sustained errors before triggering restart. Default: 5.
    Prevents restart for transient blips.

.PARAMETER MaxRestartsPerHour
    Maximum restarts allowed per hour before escalating to human. Default: 3.
    Prevents infinite restart loops if root cause is not Docker-related.

.PARAMETER LogDir
    Directory for watchdog logs. Default: <repo-root>\outputs\hermes-watchdog

.PARAMETER HermesEnvFile
    Path to Hermes .env file for MCP_URL and MCP_BEARER (optional, for E2E probing).
    Default: C:\dev\hermes-agent\.env

.EXAMPLE
    .\hermes-mcp-watchdog.ps1
    .\hermes-mcp-watchdog.ps1 -Mode dry-run -ContainerName hermes-dashboard
    .\hermes-mcp-watchdog.ps1 -ErrorThresholdMinutes 10 -MaxRestartsPerHour 5
#>

param(
    [ValidateSet('poll','dry-run')]
    [string]$Mode = 'poll',
    [string]$ContainerName = 'hermes',
    [int]$ErrorThresholdMinutes = 5,
    [int]$MaxRestartsPerHour = 3,
    [string]$LogDir = 'C:\dev\roo-extensions\outputs\hermes-watchdog',
    [string]$HermesEnvFile = 'C:\dev\hermes-agent\.env',
    [int]$LogRetentionDays = 30
)

$ErrorActionPreference = 'Continue'
$script:repairs = @()
$script:alerts  = @()

# ---------- logging ----------
if (-not (Test-Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
}
$logFile = Join-Path $LogDir ("hermes-watchdog-{0}.log" -f (Get-Date -Format 'yyyyMMdd'))

function Write-Log {
    param([string]$Level, [string]$Message)
    $ts = Get-Date -Format 'yyyy-MM-ddTHH:mm:sszzz'
    $line = "{0} [{1,-5}] {2}" -f $ts, $Level, $Message
    Add-Content -Path $logFile -Value $line -Encoding utf8
    Write-Host $line
}

# ---------- state tracking for rate limiting ----------
$stateFile = Join-Path $LogDir "hermes-watchdog-state.json"

function Get-WatchdogState {
    if (Test-Path $stateFile) {
        try {
            $json = Get-Content -Path $stateFile -Raw -Encoding utf8 | ConvertFrom-Json
            $restartCount = if ($json.RestartCount) { $json.RestartCount } else { 0 }
            return @{
                LastRestartTime = if ($json.LastRestartTime) { [DateTime]::Parse($json.LastRestartTime) } else { $null }
                RestartCount = $restartCount
                FirstErrorTime = if ($json.FirstErrorTime) { [DateTime]::Parse($json.FirstErrorTime) } else { $null }
            }
        } catch {
            Write-Log 'WARN' "Failed to read state file: $($_.Exception.Message)"
        }
    }
    return @{
        LastRestartTime = $null
        RestartCount = 0
        FirstErrorTime = $null
    }
}

function Set-WatchdogState {
    param(
        [DateTime]$LastRestartTime,
        [int]$RestartCount,
        [DateTime]$FirstErrorTime
    )
    $state = @{
        LastRestartTime = if ($LastRestartTime) { $LastRestartTime.ToString('o') } else { $null }
        RestartCount = $RestartCount
        FirstErrorTime = if ($FirstErrorTime) { $FirstErrorTime.ToString('o') } else { $null }
        LastUpdate = (Get-Date).ToString('o')
    }
    $state | ConvertTo-Json -Depth 10 | Set-Content -Path $stateFile -Encoding utf8
}

# ---------- read hermes config ----------
function Read-EnvValue {
    param([string]$Path, [string]$Key)
    if (-not (Test-Path $Path)) { return $null }
    foreach ($line in Get-Content -Path $Path -Encoding utf8 -ErrorAction SilentlyContinue) {
        if ($line -match "^\s*$([regex]::Escape($Key))\s*=\s*(.+?)\s*$") {
            return $matches[1].Trim('"').Trim("'")
        }
    }
    return $null
}

# ---------- probes ----------
function Test-DockerContainer {
    param([string]$Name)

    try {
        $result = & docker inspect -f '{{.State.Status}}' $Name 2>&1
        if ($LASTEXITCODE -ne 0) {
            return @{ Ok = $false; Reason = "container_not_found"; Output = $result }
        }
        $status = $result.Trim()
        if ($status -eq 'running') {
            return @{ Ok = $true; Status = 'running' }
        } else {
            return @{ Ok = $false; Reason = "container_not_running"; Status = $status }
        }
    } catch {
        return @{ Ok = $false; Reason = "docker_exception"; Output = $_.Exception.Message }
    }
}

function Test-McpRemoteLogErrors {
    param(
        [string]$ContainerName,
        [int]$LookbackMinutes = 10
    )

    try {
        # Get recent logs (since N minutes ago)
        $since = (Get-Date).AddMinutes(-$LookbackMinutes).ToString('yyyy-MM-ddTHH:mm:ss')
        $logs = & docker logs --since $since $ContainerName 2>&1

        if ($LASTEXITCODE -ne 0) {
            return @{ Ok = $false; Reason = "docker_logs_failed"; Output = $logs }
        }

        # Look for ClosedResourceError patterns
        $errorPatterns = @(
            'ClosedResourceError',
            'MCP tool.*call failed',
            'Connection to provider dropped',
            'ReadTimeout',
            'ECONNREFUSED',
            'ETIMEDOUT'
        )

        $errorLines = @($logs | Where-Object {
            $line = $_
            $errorPatterns | Where-Object { $line -match $_ } | Out-Null
            $?
        })

        # Check for sustained errors (multiple occurrences)
        $errorCount = $errorLines.Count
        $hasClosedResourceError = $logs -match 'ClosedResourceError'

        return @{
            Ok = ($errorCount -eq 0)
            ErrorCount = $errorCount
            HasClosedResourceError = $hasClosedResourceError
            RecentErrors = $errorLines[-10..-1] # Last 10 error lines
        }
    } catch {
        return @{ Ok = $false; Reason = "log_scraping_exception"; Output = $_.Exception.Message }
    }
}

function Test-McpRemoteProcess {
    param([string]$ContainerName)

    try {
        # Check if mcp-remote process is running inside container
        $result = & docker exec $ContainerName ps aux 2>&1 | Select-String 'mcp-remote'
        if ($LASTEXITCODE -ne 0) {
            return @{ Ok = $false; Reason = "docker_exec_failed" }
        }

        if ($result) {
            # Parse process info
            $parts = $result.Line -split '\s+', 10
            $pid = $parts[1]
            $cpu = $parts[2]
            $mem = $parts[3]
            $cmd = $parts[10]

            return @{
                Ok = $true
                Pid = $pid
                Cpu = $cpu
                Mem = $mem
                Command = $cmd
            }
        } else {
            return @{ Ok = $false; Reason = "mcp_remote_not_running" }
        }
    } catch {
        return @{ Ok = $false; Reason = "process_check_exception"; Output = $_.Exception.Message }
    }
}

# ---------- repair actions ----------
function Invoke-RestartHermesContainer {
    param([string]$ContainerName)

    if ($Mode -eq 'dry-run') {
        Write-Log 'INFO' "DRY-RUN: would docker restart $ContainerName"
        return @{ Ok = $true; DryRun = $true }
    }

    Write-Log 'WARN' "Restarting Hermes container $ContainerName to recycle mcp-remote bridge"

    try {
        $out = & docker restart $ContainerName 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Log 'ERROR' "docker restart failed (exit=$LASTEXITCODE): $out"
            $script:alerts += "container-restart-failed: $out"
            return @{ Ok = $false; Reason = "restart_failed"; Output = $out }
        }

        $script:repairs += "container-restart:$ContainerName"

        # Wait for container to be healthy
        Start-Sleep -Seconds 10

        # Verify container is running
        $health = Test-DockerContainer -Name $ContainerName
        if ($health.Ok) {
            Write-Log 'INFO' "Container $ContainerName restarted successfully, waited 10s for stabilization"
            return @{ Ok = $true }
        } else {
            Write-Log 'ERROR' "Container $ContainerName failed to start after restart: $($health.Reason)"
            return @{ Ok = $false; Reason = "container_not_healthy_after_restart" }
        }
    } catch {
        Write-Log 'ERROR' "docker restart exception: $($_.Exception.Message)"
        $script:alerts += "container-restart-exception: $($_.Exception.Message)"
        return @{ Ok = $false; Reason = "restart_exception"; Output = $_.Exception.Message }
    }
}

function Send-DashboardAlert {
    param(
        [string]$Message,
        [string]$Tag = 'ALERT'
    )

    try {
        # Try to use roo-state-manager MCP if available
        $dashboardPath = Join-Path $env:USERPROFILE '.claude\projects'
        # This is a placeholder - actual dashboard posting would be done via MCP
        Write-Log 'INFO' "Dashboard alert would be posted: [$Tag] $Message"
    } catch {
        # Dashboard posting is optional, don't fail if unavailable
        Write-Log 'WARN' "Could not post to dashboard: $($_.Exception.Message)"
    }
}

# ---------- main ----------
Write-Log 'INFO' "Hermes MCP watchdog start (mode=$Mode, container=$ContainerName, errorThreshold=${ErrorThresholdMinutes}min)"

# Step 1: Check if container exists and is running
$containerHealth = Test-DockerContainer -Name $ContainerName
if (-not $containerHealth.Ok) {
    Write-Log 'ERROR' "Container check failed: $($containerHealth.Reason) - $($containerHealth.Output)"
    $script:alerts += "container_check_failed:$($containerHealth.Reason)"
    exit 1
}

Write-Log 'INFO' "Container $ContainerName is $($containerHealth.Status)"

# Step 2: Check mcp-remote process health
$processHealth = Test-McpRemoteProcess -ContainerName $ContainerName
if ($processHealth.Ok) {
    Write-Log 'INFO' "mcp-remote process running (PID=$($processHealth.Pid), CPU=$($processHealth.Cpu)%, MEM=$($processHealth.Mem)%)"
} else {
    Write-Log 'WARN' "mcp-remote process check failed: $($processHealth.Reason)"
    $script:alerts += "mcp_remote_process_check:$($processHealth.Reason)"
}

# Step 3: Scan logs for error patterns
$logHealth = Test-McpRemoteLogErrors -ContainerName $ContainerName -LookbackMinutes 10

if ($logHealth.Ok) {
    Write-Log 'OK' "No MCP errors detected in recent logs"
    # Reset error tracking if we had previous errors
    $state = Get-WatchdogState
    if ($state.FirstErrorTime) {
        Write-Log 'INFO' 'Clearing previous error state (errors have cleared)'
        Set-WatchdogState -FirstErrorTime $null -RestartCount $state.RestartCount
    }
    exit 0
}

# Errors detected - check if sustained
$state = Get-WatchdogState
$now = Get-Date

if ($null -eq $state.FirstErrorTime) {
    # First error detection - record timestamp
    Write-Log 'WARN' "First error detected (count=$($logHealth.ErrorCount), ClosedResourceError=$($logHealth.HasClosedResourceError))"
    Set-WatchdogState -FirstErrorTime $now -RestartCount $state.RestartCount
    exit 0
}

$errorDuration = ($now - $state.FirstErrorTime).TotalMinutes

if ($errorDuration -lt $ErrorThresholdMinutes) {
    Write-Log 'WARN' "Errors detected but not sustained yet ($([int]$errorDuration)min < ${ErrorThresholdMinutes}min threshold)"
    Write-Log 'INFO' "Error details: count=$($logHealth.ErrorCount), ClosedResourceError=$($logHealth.HasClosedResourceError)"
    exit 0
}

# Threshold exceeded - check rate limiting
$restartsInLastHour = 0
if ($state.LastRestartTime) {
    $timeSinceLastRestart = ($now - $state.LastRestartTime).TotalMinutes
    if ($timeSinceLastRestart -lt 60) {
        $restartsInLastHour = $state.RestartCount + 1
    } else {
        # More than an hour since last restart, reset counter
        $restartsInLastHour = 1
    }
} else {
    $restartsInLastHour = 1
}

if ($restartsInLastHour -gt $MaxRestartsPerHour) {
    Write-Log 'ERROR' "Rate limit exceeded: $restartsInLastHour restarts in last hour (max=$MaxRestartsPerHour)"
    $script:alerts += "rate_limit_exceeded:$restartsInLastHour restarts/hour"
    Send-DashboardAlert -Message "Hermes watchdog rate limit: $restartsInLastHour restarts in last hour. Manual intervention required." -Tag 'CRITICAL'
    exit 1
}

# All checks passed - trigger restart
Write-Log 'WARN' "Error threshold exceeded: sustained errors for $([int]$errorDuration)min (threshold=${ErrorThresholdMinutes}min)"
Write-Log 'INFO' "Error summary: count=$($logHealth.ErrorCount), ClosedResourceError=$($logHealth.HasClosedResourceError)"

if ($logHealth.RecentErrors) {
    Write-Log 'INFO' 'Recent error patterns:'
    $logHealth.RecentErrors | ForEach-Object {
        $line = $_ -replace '\s+', ' '
        Write-Log 'INFO' "  - $($line.Substring(0, [Math]::Min(150, $line.Length)))"
    }
}

$restartResult = Invoke-RestartHermesContainer -ContainerName $ContainerName

if ($restartResult.Ok) {
    Write-Log 'OK' "Container restarted successfully"

    # Update state
    Set-WatchdogState -LastRestartTime $now -RestartCount $restartsInLastHour -FirstErrorTime $null

    # Send recovery notification
    $msg = "Hermes container $ContainerName auto-restarted after $([int]$errorDuration)min of MCP errors. Restart #$restartsInLastHour in last hour."
    Send-DashboardAlert -Message $msg -Tag 'RECOVERY'
} else {
    Write-Log 'ERROR' "Container restart failed: $($restartResult.Reason)"
    $script:alerts += "restart_final_failed:$($restartResult.Reason)"
    Send-DashboardAlert -Message "Hermes watchdog failed to restart container: $($restartResult.Reason). Manual intervention required." -Tag 'CRITICAL'
    exit 1
}

# ---------- cleanup old logs ----------
try {
    $cutoff = (Get-Date).AddDays(-$LogRetentionDays)
    Get-ChildItem -Path $LogDir -Filter 'hermes-watchdog-*.log' |
        Where-Object { $_.LastWriteTime -lt $cutoff } |
        Remove-Item -Force -ErrorAction SilentlyContinue
} catch {
    Write-Log 'WARN' "Failed to cleanup old logs: $($_.Exception.Message)"
}

Write-Log 'INFO' "Watchdog run complete (repairs=$($script:repairs.Count), alerts=$($script:alerts.Count))"
