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
    [string]$LogDir = $env:DASHBOARD_WATCHER_LOG_DIR
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

$listenerScript = Join-Path $scriptDir "dashboard-listener.ps1"

while ($true) {
    $dateStamp = Get-Date -Format "yyyyMMdd"
    $logFile = Join-Path $LogDir "listener-$dateStamp.log"

    "=== Dashboard Listener started: $(Get-Date -Format o) ===" | Tee-Object -FilePath $logFile -Append

    try {
        & $listenerScript 2>&1 | Tee-Object -FilePath $logFile -Append
        $exitCode = $LASTEXITCODE
    } catch {
        "ERROR uncaught: $_" | Tee-Object -FilePath $logFile -Append
        "Stack: $($_.ScriptStackTrace)" | Tee-Object -FilePath $logFile -Append
        $exitCode = 99
    }

    "=== Dashboard Listener exit code ${exitCode}: $(Get-Date -Format o) ===" | Tee-Object -FilePath $logFile -Append

    # Auto-restart after 30s unless clean shutdown (exit 0 from -Once)
    if ($exitCode -eq 0) {
        "=== Clean exit, restarting in 30s... ===" | Tee-Object -FilePath $logFile -Append
    } else {
        "=== Unexpected exit ($exitCode), restarting in 60s... ===" | Tee-Object -FilePath $logFile -Append
        Start-Sleep -Seconds 60
    }
    Start-Sleep -Seconds 30
}
