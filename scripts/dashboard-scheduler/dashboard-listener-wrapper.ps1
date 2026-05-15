<#
.SYNOPSIS
    Wrapper for dashboard-listener.ps1 with file logging (Task Scheduler swallows stdout).

.DESCRIPTION
    Redirects all listener output to a daily log file.
    Runs dashboard-listener.ps1 continuously, with auto-restart on exit.

    Log file: <repo-root>/outputs/scheduling/logs/listener-YYYYMMDD.log

.PARAMETER LogDir
    Override log directory. Default: <repo-root>/outputs/scheduling/logs.

.EXAMPLE
    .\dashboard-listener-wrapper.ps1
#>

param(
    [string]$LogDir = $env:DASHBOARD_WATCHER_LOG_DIR,
    [string]$HeartbeatDir = ""
)

$ErrorActionPreference = "Continue"

$scriptDir = Split-Path $MyInvocation.MyCommand.Path -Parent
$RepoRoot = (Split-Path (Split-Path $scriptDir -Parent) -Parent)

if ([string]::IsNullOrEmpty($LogDir)) {
    $LogDir = Join-Path $RepoRoot "outputs\scheduling\logs"
}
if (-not (Test-Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
}

# Heartbeat file for liveness monitoring (#2186).
# Touches a file after each listener iteration so watchdogs can verify the
# listener is alive without needing elevated privileges.
if ([string]::IsNullOrEmpty($HeartbeatDir)) {
    $HeartbeatDir = Join-Path $RepoRoot ".claude\locks"
}
if (-not (Test-Path $HeartbeatDir)) {
    New-Item -ItemType Directory -Path $HeartbeatDir -Force | Out-Null
}
$heartbeatFile = Join-Path $HeartbeatDir "dashboard-listener.heartbeat"

function Write-Heartbeat {
    try {
        $ts = (Get-Date).ToUniversalTime().ToString("o")
        [System.IO.File]::WriteAllText($heartbeatFile, $ts, [System.Text.UTF8Encoding]::new($false))
    } catch {
        # Non-blocking — heartbeat is a signal, not critical path
    }
}

$listenerScript = Join-Path $scriptDir "dashboard-listener.ps1"

while ($true) {
    $dateStamp = Get-Date -Format "yyyyMMdd"
    $logFile = Join-Path $LogDir "listener-$dateStamp.log"

    "=== Dashboard Listener started: $(Get-Date -Format o) ===" | Tee-Object -FilePath $logFile -Append
    Write-Heartbeat

    try {
        # *>&1 captures ALL streams (including Write-Host / Write-Information stream 6)
        # Previously used 2>&1 which missed Write-Host output, making logs nearly empty (#2186 Bug 1).
        & $listenerScript *>&1 | Tee-Object -FilePath $logFile -Append
        $exitCode = $LASTEXITCODE
    } catch {
        "ERROR uncaught: $_" | Tee-Object -FilePath $logFile -Append
        "Stack: $($_.ScriptStackTrace)" | Tee-Object -FilePath $logFile -Append
        $exitCode = 99
    }

    Write-Heartbeat
    "=== Dashboard Listener exit code ${exitCode}: $(Get-Date -Format o) ===" | Tee-Object -FilePath $logFile -Append

    # Auto-restart: 30s after clean exit, 60s after error
    if ($exitCode -eq 0) {
        "=== Clean exit, restarting in 30s... ===" | Tee-Object -FilePath $logFile -Append
        Start-Sleep -Seconds 30
    } else {
        "=== Unexpected exit ($exitCode), restarting in 60s... ===" | Tee-Object -FilePath $logFile -Append
        Start-Sleep -Seconds 60
    }
}
