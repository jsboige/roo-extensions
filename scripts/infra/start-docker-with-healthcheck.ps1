<#
.SYNOPSIS
    Start Docker Desktop and verify daemon responsiveness (healthcheck).
.DESCRIPTION
    Designed to be run as a scheduled task at system boot. Starts Docker Desktop,
    then polls `docker info` until the daemon is ready or timeout is reached.
    Logs all output to $env:PROGRAMDATA\Docker-Auto-Start\healthcheck.log.
.PARAMETER HealthCheckTimeout
    Maximum seconds to wait for Docker daemon (default 120)
.PARAMETER PollInterval
    Seconds between healthcheck attempts (default 10)
.PARAMETER DockerExe
    Path to Docker Desktop executable
.EXAMPLE
    .\start-docker-with-healthcheck.ps1
    .\start-docker-with-healthcheck.ps1 -HealthCheckTimeout 180
#>
[CmdletBinding()]
param(
    [int]$HealthCheckTimeout = 120,
    [int]$PollInterval = 10,
    [string]$DockerExe = 'C:\Program Files\Docker\Docker\Docker Desktop.exe'
)

$LogDir = Join-Path $env:ProgramData 'Docker-Auto-Start'
$LogFile = Join-Path $LogDir 'healthcheck.log'

if (-not (Test-Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
}

function Write-Log {
    param([string]$Message, [string]$Level = 'INFO')
    $ts = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $entry = "[$ts] [$Level] $Message"
    Add-Content -Path $LogFile -Value $entry -Encoding UTF8
    switch ($Level) {
        'ERROR' { Write-Host $entry -ForegroundColor Red }
        'WARN'  { Write-Host $entry -ForegroundColor Yellow }
        default { Write-Host $entry -ForegroundColor Green }
    }
}

# Rotate log if > 1MB
if ((Test-Path $LogFile) -and ((Get-Item $LogFile).Length -gt 1MB)) {
    $backup = "$LogFile.$(Get-Date -Format 'yyyyMMdd-HHmmss').bak"
    Move-Item $LogFile $backup -Force
    Write-Log "Log rotated from $backup"
}

Write-Log "=== Docker Auto-Start with Healthcheck ==="
Write-Log "Timeout: ${HealthCheckTimeout}s | Poll: ${PollInterval}s"

# Pre-check
if (-not (Test-Path $DockerExe)) {
    Write-Log "Docker Desktop not found at: $DockerExe" -Level ERROR
    exit 1
}

# Check if Docker is already running
$alreadyRunning = Get-Process -Name 'Docker Desktop' -ErrorAction SilentlyContinue
if ($alreadyRunning) {
    Write-Log "Docker Desktop already running (PID $($alreadyRunning.Id))"
} else {
    Write-Log "Starting Docker Desktop..."
    try {
        Start-Process -FilePath $DockerExe -WindowStyle Hidden
        Write-Log "Docker Desktop process launched"
    } catch {
        Write-Log "Failed to start Docker Desktop: $_" -Level ERROR
        exit 1
    }
}

# Healthcheck: poll docker info
$deadline = (Get-Date).AddSeconds($HealthCheckTimeout)
$attempt = 0

while ((Get-Date) -lt $deadline) {
    $attempt++
    try {
        $null = docker info 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Log "Docker daemon ready after $attempt attempt(s) ($($HealthCheckTimeout - ($deadline - (Get-Date)).TotalSeconds) seconds)"
            exit 0
        }
    } catch {
        # docker CLI not yet available, expected during early startup
    }
    Write-Log "Attempt $attempt - daemon not ready, waiting ${PollInterval}s..."
    Start-Sleep -Seconds $PollInterval
}

Write-Log "TIMEOUT: Docker daemon not responsive after ${HealthCheckTimeout}s ($attempt attempts)" -Level ERROR
exit 1
