<#
.SYNOPSIS
    Local watchdog for the Claude-DashboardListener zombie class (#3687).

.DESCRIPTION
    Detects the failure class observed on myia-po-2026 15-16/09 (#3686): the Task
    Scheduler reports Claude-DashboardListener as State=Running while NO wrapper
    process exists and the listener heartbeat is stale. With MultipleInstances
    IgnoreNew, every 15-min re-trigger is refused (LastTaskResult 0x800710E0
    "operator refused"), so self-healing is structurally impossible until the
    zombie state is purged.

    Remediation is the exact gesture applied manually on po-2026 16/09 06:22Z:
    Stop-ScheduledTask (purge zombie) + Start-ScheduledTask. Both are allowed for
    the task owner without elevation on an Interactive+Highest task.

    Detection signals (ALL required to act — the watchdog never kills a healthy
    listener):
      1. task exists AND task.State -eq "Running"
      2. no live wrapper chain, proven by the kernel mutex
         Global\RooSync-DashboardListener-Wrapper (the wrapper's single-instance
         guard, #3277): a live wrapper holds it, the kernel releases it on
         process death. A zero-timeout WaitOne probe is the exact life test.
         A command-line scan is kept as a secondary confirmation — measured on
         po-2026 16/09, the Task-Scheduler-launched wrapper pwsh exposes a NULL
         CommandLine, so the mutex is the only reliable discriminator.
      3. heartbeat stale > StaleSeconds — LOCAL heartbeat first (always in the
         real repo, exact); GDrive shared heartbeat fallback (cross-machine
         source of truth, may lag via the sync client).

    Timestamps: ONLY file mtimes (LastWriteTimeUtc) are compared. Listener log
    lines stamp LOCAL time with a misleading Z suffix (documented trap, #3686) —
    they are never used for staleness math.

    Forensics (issue demand 2): BEFORE any restart, the watchdog snapshots
    LastTaskResult + the tail of the latest listener log into
    outputs/scheduling/logs/zombie-watchdog-forensics-<timestamp>.txt.

    Idempotent: if already healing (task Disabled/Queued/starting), if healthy
    (live mutex/process OR fresh heartbeat), or if the task is absent
    (NOT_INSTALLED is an [INTERACTIVE-ONLY] condition), it exits 0 without
    touching anything.

    Runs non-elevated as the task owner, typically every 15 min via
    install-listener-zombie-watchdog-schtask.ps1. Best-effort: any GDrive or
    scheduler hiccup logs a WARN and defers to the next cycle.

.PARAMETER StaleSeconds
    Heartbeat age above which a Running-but-processless task is declared zombie.
    Default 900 (15 min). The listener heartbeats every 5 min on a healthy run,
    so 15 min of silence = 3 missed pings; tighter values risk racing GDrive
    sync lag, larger values defeat the purpose (the 15-min re-trigger is already
    being refused).

.PARAMETER DryRun
    Detect and report, but do NOT Stop/Start the task.

.PARAMETER Json
    Emit a machine-readable JSON verdict (plus human log lines on stderr-safe
    stdout only when not set).

.OUTPUTS
    Exit 0 = no action needed (healthy, healing, not installed, or dry-run).
    Exit 1 = zombie detected AND remediation applied (or attempted).

.EXAMPLE
    pwsh -ExecutionPolicy Bypass -File scripts\dashboard-scheduler\listener-zombie-watchdog.ps1
    pwsh -ExecutionPolicy Bypass -File scripts\dashboard-scheduler\listener-zombie-watchdog.ps1 -DryRun

.NOTES
    Related: #3686 (po-2026 zombie, 36h frozen heartbeat, ~26h human latency),
    #2431 (listener durability), #2576 (zombie verdict definition),
    #2928 (fleet detection gap).
#>

param(
    [int]$StaleSeconds = 900,
    [switch]$DryRun,
    [switch]$Json
)

$ErrorActionPreference = "Continue"

$taskName  = "Claude-DashboardListener"
$scriptDir = Split-Path $MyInvocation.MyCommand.Path -Parent
$RepoRoot  = (Split-Path (Split-Path $scriptDir -Parent) -Parent)
$logDir    = Join-Path $RepoRoot "outputs\scheduling\logs"
$nowUtc    = (Get-Date).ToUniversalTime()

$machineId = if ($env:ROOSYNC_MACHINE_ID) {
    $env:ROOSYNC_MACHINE_ID.ToLowerInvariant()
} elseif ($env:COMPUTERNAME) {
    $env:COMPUTERNAME.ToLowerInvariant()
} else {
    "unknown-machine"
}

function Write-WatchdogLog([string]$level, [string]$msg) {
    $line = "[{0}] [{1}] [zombie-watchdog] {2}" -f $nowUtc.ToString("yyyy-MM-ddTHH:mm:ssZ"), $level, $msg
    Write-Output $line
    if (-not (Test-Path $logDir)) {
        New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    }
    $logFile = Join-Path $logDir ("zombie-watchdog-" + $nowUtc.ToString("yyyyMMdd") + ".log")
    try {
        [System.IO.File]::AppendAllText($logFile, $line + "`r`n", [System.Text.UTF8Encoding]::new($false))
    } catch { }
}

function Get-HeartbeatAge($path) {
    if ([string]::IsNullOrEmpty($path) -or -not (Test-Path $path)) {
        return @{ exists = $false; ageSeconds = $null; mtime = $null }
    }
    $mt = (Get-Item $path).LastWriteTimeUtc
    return @{
        exists     = $true
        ageSeconds = [int]($nowUtc - $mt).TotalSeconds
        mtime      = $mt.ToString("yyyy-MM-ddTHH:mm:ssZ")
    }
}

# ---------- Signal 1: scheduled task state ----------
$task = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
$taskState = if ($task) { [string]$task.State } else { "NOT_INSTALLED" }
$taskInfo  = Get-ScheduledTaskInfo -TaskName $taskName -ErrorAction SilentlyContinue
$lastResultHex = $null
$lastRun = $null
$nextRun = $null
if ($taskInfo) {
    $lastResultHex = ('0x{0:X}' -f $taskInfo.LastTaskResult)
    if ($taskInfo.LastRunTime -and $taskInfo.LastRunTime -gt [datetime]'2000-01-01') {
        $lastRun = $taskInfo.LastRunTime.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    }
    if ($taskInfo.NextRunTime -and $taskInfo.NextRunTime -gt [datetime]'2000-01-01') {
        $nextRun = $taskInfo.NextRunTime.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    }
}

# ---------- Signal 2: live wrapper chain (kernel mutex + cmdline scan) ----------
# PRIMARY: the wrapper's named mutex (single-instance guard #3277). A live wrapper
# chain holds Global\RooSync-DashboardListener-Wrapper; the kernel releases it when
# the owning process dies. A zero-timeout acquire attempt = exact life test:
#   acquired            -> no live holder (dead or never started)
#   not acquired        -> a live wrapper holds it
#   AbandonedMutex      -> previous holder died without release (treated as dead)
# Measured po-2026 16/09: the Task-Scheduler-launched wrapper pwsh exposes a NULL
# CommandLine to Win32_Process, so a cmdline scan alone cannot prove life — only
# the mutex can. The scan is kept as a SECONDARY confirmation (belt and suspenders:
# if either signal says alive, the watchdog never acts).
$wrapperMutexName = "RooSync-DashboardListener-Wrapper"
$mutexHeld = $true   # conservative default: assume alive unless proven dead
$mutexProbe = $null
try {
    $mutexProbe = New-Object System.Threading.Mutex($false, "Global\$wrapperMutexName")
    $acquired = $mutexProbe.WaitOne(0)
    if ($acquired) {
        $mutexHeld = $false   # nobody holds it -> no live wrapper chain
    }
} catch [System.Threading.AbandonedMutexException] {
    # Previous holder died without release: acquisition succeeded, no live chain.
    $mutexHeld = $false
} catch {
    # Cannot probe (e.g. Global\ refused in this session) — fall back to the
    # Local\ namespace, then to cmdline-only below. Stay conservative: a failed
    # probe must never enable a kill.
    try {
        $mutexProbe = New-Object System.Threading.Mutex($false, "Local\$wrapperMutexName")
        $acquired2 = $mutexProbe.WaitOne(0)
        if ($acquired2) { $mutexHeld = $false }
    } catch [System.Threading.AbandonedMutexException] {
        $mutexHeld = $false
    } catch {
        $mutexHeld = $true
    }
}
if ($mutexProbe) {
    try { if (-not $mutexHeld) { $mutexProbe.ReleaseMutex() } } catch { }
    $mutexProbe.Dispose()
}

# SECONDARY: command-line scan for wrapper/listener script references.
$liveProcs = @(
    Get-CimInstance Win32_Process -Filter "Name like 'pwsh%' or Name like 'powershell%'" -ErrorAction SilentlyContinue |
        Where-Object { $_.CommandLine -and $_.CommandLine -match 'dashboard-listener(-wrapper)?\.ps1' -and $_.ProcessId -ne $PID }
)
$liveProcCount = $liveProcs.Count

# Combined life signal: ANY evidence of life vetoes remediation.
$wrapperAlive = $mutexHeld -or ($liveProcCount -gt 0)

# ---------- Signal 3: heartbeat freshness (mtime only — never log-line stamps) ----------
$localHb  = Get-HeartbeatAge (Join-Path $RepoRoot ".claude\locks\dashboard-listener.heartbeat")
$sharedPath = $env:ROOSYNC_SHARED_PATH
if (-not $sharedPath) {
    $sharedPath = [System.Environment]::GetEnvironmentVariable('ROOSYNC_SHARED_PATH', 'User')
}
$sharedHbFile = if ($sharedPath) { Join-Path (Join-Path $sharedPath "listener-heartbeats") "$machineId.heartbeat" } else { $null }
$sharedHb = Get-HeartbeatAge $sharedHbFile

# Authoritative staleness: prefer the LOCAL heartbeat (exact, written by the
# listener loop directly); fall back to the shared one when the local file is
# missing (e.g. repo moved). A process can be alive while GDrive sync lags —
# never let the shared copy alone convict a healthy listener.
$hbStale = $false
$hbSource = "none"
if ($localHb.exists) {
    $hbSource = "local"
    $hbStale = ($localHb.ageSeconds -gt $StaleSeconds)
} elseif ($sharedHb.exists) {
    $hbSource = "shared"
    $hbStale = ($sharedHb.ageSeconds -gt $StaleSeconds)
}

# ---------- Verdict ----------
$verdict = "HEALTHY"
$reason  = ""
if ($taskState -eq "NOT_INSTALLED") {
    $verdict = "NOT_INSTALLED"
    $reason  = "no $taskName task — elevated [INTERACTIVE-ONLY] install required, watchdog does not act"
} elseif ($taskState -ne "Running") {
    $verdict = "NOT_RUNNING"
    $reason  = "task State=$taskState — the 15-min IgnoreNew trigger can start it normally; not the zombie class"
} elseif ($wrapperAlive) {
    $verdict = "HEALTHY"
    $reason  = "wrapper chain alive (mutexHeld=$mutexHeld cmdlineProcs=$liveProcCount) — never act while any life signal is positive"
} elseif (-not $hbStale) {
    $verdict = "HEALTHY"
    $reason  = "no live wrapper chain but $hbSource heartbeat is fresh (<=$StaleSeconds s) — treat as transient, never act"
} else {
    $verdict = "ZOMBIE"
    $reason  = "State=Running + no live wrapper chain (mutex free, 0 cmdline procs) + $hbSource heartbeat stale (>$StaleSeconds s)"
}

Write-WatchdogLog "INFO" ("verdict=$verdict task=$taskState lastResult=$lastResultHex mutexHeld=$mutexHeld liveProcs=$liveProcCount hbSource=$hbSource hbStale=$hbStale — $reason")

$result = [PSCustomObject]@{
    machine        = $machineId
    checkedAtUtc   = $nowUtc.ToString("yyyy-MM-ddTHH:mm:ssZ")
    verdict        = $verdict
    reason         = $reason
    taskState      = $taskState
    lastTaskResult = $lastResultHex
    lastRunUtc     = $lastRun
    nextRunUtc     = $nextRun
    liveProcesses  = $liveProcCount
    wrapperMutexHeld = $mutexHeld
    localHeartbeat = $localHb
    sharedHeartbeat = $sharedHb
    heartbeatSource = $hbSource
    dryRun         = [bool]$DryRun
    remediation    = $null
}

# ---------- Remediation (zombie only) ----------
if ($verdict -eq "ZOMBIE") {
    # Forensics FIRST (issue demand 2): LastTaskResult + log tail before restart.
    $forensics = @()
    $forensics += "=== zombie-watchdog forensics $machineId $($nowUtc.ToString('yyyy-MM-ddTHH:mm:ssZ')) ==="
    $forensics += "TaskState=$taskState LastTaskResult=$lastResultHex LastRunUtc=$lastRun NextRunUtc=$nextRun"
    $forensics += "LiveWrapperChain: mutexHeld=$mutexHeld cmdlineProcs=$liveProcCount"
    $forensics += ("LocalHeartbeat: " + $(if ($localHb.exists) { "age=$($localHb.ageSeconds)s mtime=$($localHb.mtime)" } else { "MISSING" }))
    $forensics += ("SharedHeartbeat: " + $(if ($sharedHb.exists) { "age=$($sharedHb.ageSeconds)s mtime=$($sharedHb.mtime)" } else { "MISSING" }))
    $latestLog = Get-ChildItem -Path $logDir -Filter "listener-*.log" -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($latestLog) {
        $forensics += "--- tail of $($latestLog.Name) (last 30 lines; note: log line stamps are LOCAL time with a misleading Z suffix) ---"
        $forensics += @(Get-Content $latestLog.FullName -Tail 30 -ErrorAction SilentlyContinue)
    } else {
        $forensics += "--- no listener-*.log found in $logDir ---"
    }
    if (-not (Test-Path $logDir)) {
        New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    }
    $forensicsFile = Join-Path $logDir ("zombie-watchdog-forensics-" + $nowUtc.ToString("yyyyMMddTHHmmss") + "Z.txt")
    try {
        [System.IO.File]::WriteAllText($forensicsFile, ($forensics -join "`r`n"), [System.Text.UTF8Encoding]::new($false))
        Write-WatchdogLog "INFO" "forensics captured: $forensicsFile"
    } catch {
        Write-WatchdogLog "WARN" "forensics write failed (continuing): $_"
    }

    if ($DryRun) {
        $result.remediation = "DRY-RUN: would Stop-ScheduledTask + Start-ScheduledTask $taskName"
        Write-WatchdogLog "INFO" "DRY-RUN — no Stop/Start performed"
    } else {
        $stopOk = $false
        $startOk = $false
        try {
            Stop-ScheduledTask -TaskName $taskName -ErrorAction Stop
            $stopOk = $true
            Write-WatchdogLog "INFO" "Stop-ScheduledTask $taskName OK (zombie state purged)"
        } catch {
            Write-WatchdogLog "WARN" "Stop-ScheduledTask failed: $_"
        }
        try {
            Start-ScheduledTask -TaskName $taskName -ErrorAction Stop
            $startOk = $true
            Write-WatchdogLog "INFO" "Start-ScheduledTask $taskName OK"
        } catch {
            Write-WatchdogLog "WARN" "Start-ScheduledTask failed: $_"
        }
        $result.remediation = "stop=$stopOk start=$startOk forensics=$forensicsFile"
        if ($startOk) {
            Write-WatchdogLog "INFO" "remediation applied — next 5-min heartbeat will confirm recovery"
        } else {
            Write-WatchdogLog "ERROR" "remediation incomplete — task may need INTERACTIVE-ONLY attention"
        }
    }
    if ($Json) { $result | ConvertTo-Json -Depth 5 }
    exit 1
}

if ($Json) { $result | ConvertTo-Json -Depth 5 }
exit 0
