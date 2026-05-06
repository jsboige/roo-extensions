<#
.SYNOPSIS
    Watchdog for Hermes mcp-remote bridge — auto-restart on ClosedResourceError (#2014).

.DESCRIPTION
    Monitors the Hermes Docker container for ClosedResourceError patterns in logs.
    If sustained errors detected, restarts the container with rate limiting.

    Designed for scheduled task "At startup + every 5 min" on myia-po-2026.

.PARAMETER ContainerName
    Docker container name. Default: 'hermes'

.PARAMETER Mode
    'poll' (default): check and repair. 'dry-run': check only, never repair.

.PARAMETER LogDir
    Directory for watchdog logs. Default: D:\roo-extensions\outputs\hermes-watchdog

.PARAMETER ErrorWindowMinutes
    How far back to check logs for errors. Default: 10

.PARAMETER MaxRestartsPerHour
    Rate limit for automatic restarts. Default: 3

.PARAMETER StateFile
    Path to state file tracking restart timestamps. Default: $LogDir\restart-state.json

.EXAMPLE
    .\hermes-bridge-watchdog.ps1
    .\hermes-bridge-watchdog.ps1 -Mode dry-run
#>

param(
    [string]$ContainerName = 'hermes',
    [ValidateSet('poll','dry-run')]
    [string]$Mode = 'poll',
    [string]$LogDir = 'D:\roo-extensions\outputs\hermes-watchdog',
    [int]$ErrorWindowMinutes = 10,
    [int]$MaxRestartsPerHour = 3,
    [string]$StateFile = ''
)

$ErrorActionPreference = 'Continue'

if (-not $StateFile) {
    $StateFile = Join-Path $LogDir 'restart-state.json'
}

# ---------- logging ----------
if (-not (Test-Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
}
$logFile = Join-Path $LogDir ("hermes-watchdog-{0}.log" -f (Get-Date -Format 'yyyyMMdd'))

function Write-Log {
    param([string]$Level, [string]$Message)
    $ts = Get-Date -Format 'yyyy-MM-ddTHH:mm:sszzz'
    $line = "{0} [{1,-5}] {2}" -f $ts, $Level, $Message
    Add-Content -Path $logFile -Value $line -Encoding utf8NoBOM
    Write-Host $line
}

# ---------- state management ----------
function Get-RestartState {
    if (Test-Path $StateFile) {
        try {
            return Get-Content $StateFile -Raw | ConvertFrom-Json
        } catch {
            return @{ timestamps = @() }
        }
    }
    return @{ timestamps = @() }
}

function Save-RestartState {
    param([hashtable]$State)
    $State | ConvertTo-Json -Depth 3 | Set-Content $StateFile -Encoding utf8NoBOM
}

function Get-RecentRestartCount {
    param([hashtable]$State)
    $cutoff = (Get-Date).AddHours(-1).ToString('o')
    return @($State.timestamps | Where-Object { $_ -gt $cutoff }).Count
}

function Record-Restart {
    param([hashtable]$State)
    $State.timestamps += (Get-Date).ToString('o')
    # Keep only last 24h of timestamps
    $cutoff = (Get-Date).AddHours(-24).ToString('o')
    $State.timestamps = @($State.timestamps | Where-Object { $_ -gt $cutoff })
    Save-RestartState $State
}

# ---------- main logic ----------
Write-Log 'INFO' "Hermes bridge watchdog starting (mode=$Mode, container=$ContainerName)"

# Check if Docker is available
$dockerAvailable = $false
try {
    $null = docker info 2>&1
    $dockerAvailable = $LASTEXITCODE -eq 0
} catch {
    $dockerAvailable = $false
}

if (-not $dockerAvailable) {
    Write-Log 'WARN' 'Docker not available — skipping check'
    exit 0
}

# Check container exists and is running
$containerStatus = docker inspect $ContainerName --format '{{.State.Status}}' 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Log 'WARN' "Container '$ContainerName' not found — skipping"
    exit 0
}

if ($containerStatus -ne 'running') {
    Write-Log 'WARN' "Container '$ContainerName' is '$containerStatus' (not running) — skipping"
    exit 0
}

# Check logs for ClosedResourceError in the window
$since = "{0}m" -f $ErrorWindowMinutes
$errorPatterns = @('ClosedResourceError', 'Connection closed', 'bridge.*stuck', 'MCP.*timeout.*permanent')

$logOutput = docker logs $ContainerName --since $since 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Log 'WARN' "Failed to read container logs — skipping"
    exit 0
}

$errorCount = 0
$matchedPattern = ''
foreach ($line in $logOutput) {
    foreach ($pattern in $errorPatterns) {
        if ($line -match $pattern) {
            $errorCount++
            $matchedPattern = $pattern
            break
        }
    }
}

if ($errorCount -eq 0) {
    Write-Log 'INFO' "Container '$ContainerName' healthy — 0 error patterns in last ${ErrorWindowMinutes}m"
    exit 0
}

Write-Log 'WARN' "Detected $errorCount error patterns (pattern='$matchedPattern') in last ${ErrorWindowMinutes}m"

if ($Mode -eq 'dry-run') {
    Write-Log 'INFO' 'Dry-run mode — would restart container but skipping'
    exit 0
}

# Check rate limit
$state = Get-RestartState
$recentCount = Get-RecentRestartCount $state

if ($recentCount -ge $MaxRestartsPerHour) {
    Write-Log 'ERROR' "Rate limit reached ($recentCount/$MaxRestartsPerHour restarts in last hour) — NOT restarting. Manual intervention required."
    # Attempt to report to dashboard (best effort)
    try {
        $dashboardMsg = "[WARN] Hermes bridge watchdog: $errorCount errors detected but rate limit ($MaxRestartsPerHour/h) reached. Container $ContainerName needs manual restart."
        Write-Log 'INFO' "Dashboard alert: $dashboardMsg"
    } catch {}
    exit 1
}

# Restart container
Write-Log 'INFO' "Restarting container '$ContainerName' (attempt $($recentCount + 1)/$MaxRestartsPerHour this hour)..."
docker restart $ContainerName 2>&1 | ForEach-Object { Write-Log 'INFO' "docker: $_" }

if ($LASTEXITCODE -eq 0) {
    Record-Restart $state
    Write-Log 'INFO' "Container '$ContainerName' restarted successfully"
} else {
    Write-Log 'ERROR' "Failed to restart container '$ContainerName'"
    exit 1
}

exit 0
