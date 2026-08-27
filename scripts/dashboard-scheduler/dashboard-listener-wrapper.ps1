<#
.SYNOPSIS
    Wrapper for dashboard-listener.ps1 with file logging (Task Scheduler swallows stdout).

.DESCRIPTION
    Redirects all listener output to a daily log file.
    Runs dashboard-listener.ps1 continuously, with auto-restart on exit.

    Single-instance guard (#3277): a named mutex eliminates any second
    wrapper chain, whatever its spawn path. On 25/08 two concurrent chains
    double-dispatched one [WAKE-VIBE] into 3 paid sessions. If the mutex is
    already held, this instance exits cleanly with a trace — it never
    silently coexists.

    If the child listener exits with code 75 (its own single-instance guard
    tripped — a bare listener invocation holds the mutex), the wrapper stops
    instead of restarting: another live listener is already serving.

    Log file: <repo-root>/outputs/scheduling/logs/listener-YYYYMMDD.log

.PARAMETER LogDir
    Override log directory. Default: <repo-root>/outputs/scheduling/logs.

.PARAMETER HeartbeatDir
    Override heartbeat directory. Default: <repo-root>/.claude/locks.

.PARAMETER InstanceSuffix
    Appended to the mutex name for test isolation. Default: empty.

.EXAMPLE
    .\dashboard-listener-wrapper.ps1
#>

param(
    [string]$LogDir = $env:DASHBOARD_WATCHER_LOG_DIR,
    [string]$HeartbeatDir = "",
    [string]$InstanceSuffix = ""
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

function Write-WrapLog {
    param([string]$Message)
    # Date evaluated per call so each write targets the current day's file.
    $logFile = Join-Path $LogDir ("listener-{0}.log" -f (Get-Date).ToUniversalTime().ToString("yyyyMMdd"))
    $ts = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
    "$Message [$ts]" | Tee-Object -FilePath $logFile -Append
}

. (Join-Path $RepoRoot "scripts\common\single-instance-mutex.ps1")

$singleInstance = Get-SingleInstance -Name "RooSync-DashboardListener-Wrapper$InstanceSuffix"
if (-not $singleInstance.Acquired) {
    Write-WrapLog "=== Another wrapper instance is active — exiting (single-instance guard, #3277). ==="
    exit 0
}

$listenerScript = Join-Path $scriptDir "dashboard-listener.ps1"

try {
    while ($true) {
        Write-WrapLog "=== Dashboard Listener starting ==="

        try {
            # *>&1 captures ALL streams (including Write-Host / Write-Information stream 6)
            # Previously used 2>&1 which missed Write-Host output, making logs nearly empty (#2186 Bug 1).
            $dateStamp = (Get-Date).ToUniversalTime().ToString("yyyyMMdd")
            $logFile = Join-Path $LogDir "listener-$dateStamp.log"
            & $listenerScript *>&1 | Tee-Object -FilePath $logFile -Append
            $exitCode = $LASTEXITCODE
        } catch {
            Write-WrapLog "ERROR uncaught: $_"
            Write-WrapLog "Stack: $($_.ScriptStackTrace)"
            $exitCode = 99
        }

        Write-Heartbeat

        # 75 = the listener's own single-instance guard tripped: a live
        # listener exists outside this wrapper. Restarting would fight it.
        if ($exitCode -eq 75) {
            Write-WrapLog "=== Listener reports another instance active (exit 75) — stopping this chain. ==="
            break
        }

        Write-WrapLog "=== Dashboard Listener exit code ${exitCode} ==="

        # Auto-restart: 30s after clean exit, 60s after error
        if ($exitCode -eq 0) {
            Write-WrapLog "=== Clean exit, restarting in 30s... ==="
            Start-Sleep -Seconds 30
        } else {
            Write-WrapLog "=== Unexpected exit ($exitCode), restarting in 60s... ==="
            Start-Sleep -Seconds 60
        }
    }
} finally {
    Release-SingleInstance $singleInstance
}
