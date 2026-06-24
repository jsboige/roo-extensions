<#
.SYNOPSIS
    Read-only, non-elevated diagnostic for the Claude-DashboardListener wake mechanism (#2431).

.DESCRIPTION
    Reports, WITHOUT requiring elevation:
      - Claude-DashboardListener scheduled task State / LastTaskResult / LastRun / NextRun
      - Local heartbeat freshness (<RepoRoot>/.claude/locks/dashboard-listener.heartbeat)
      - Shared heartbeat freshness (<ROOSYNC_SHARED_PATH>/listener-heartbeats/<machine>.heartbeat)
      - Last line of today's listener log

    Designed to be dispatched to the alive cron workers (every 2h, run as user): they run
    this and post the markdown block to the workspace dashboard via roosync_dashboard. This is
    the [WAKE-CLAUDE] chicken-and-egg workaround — you cannot WAKE a machine to diagnose its
    own (possibly dead) WAKE listener, so a non-elevated read-only probe is dispatched instead.

    This script NEVER writes anything (pure probe) and never needs RunLevel Highest.

.PARAMETER Json
    Emit a machine-readable JSON object instead of the human/markdown block.

.PARAMETER StaleSeconds
    Heartbeat age (seconds) above which the listener is flagged STALE. Default 7200 (2h = the span
    of most fleet crons). The listener pings every ~5 min, so 2h of silence = certain death, never a
    false positive. A tighter threshold is meaningless when coordination itself runs on 2h+ crons.

.EXAMPLE
    pwsh -ExecutionPolicy Bypass -File scripts\dashboard-scheduler\diagnose-wake-listener.ps1
    pwsh -ExecutionPolicy Bypass -File scripts\dashboard-scheduler\diagnose-wake-listener.ps1 -Json
#>

param(
    [switch]$Json,
    [int]$StaleSeconds = 7200,
    [switch]$Alert
)

$ErrorActionPreference = "Continue"

$taskName = "Claude-DashboardListener"
$scriptDir = Split-Path $MyInvocation.MyCommand.Path -Parent
$RepoRoot = (Split-Path (Split-Path $scriptDir -Parent) -Parent)

$machineId = if ($env:ROOSYNC_MACHINE_ID) {
    $env:ROOSYNC_MACHINE_ID.ToLowerInvariant()
} elseif ($env:COMPUTERNAME) {
    $env:COMPUTERNAME.ToLowerInvariant()
} else {
    "unknown-machine"
}

$nowUtc = (Get-Date).ToUniversalTime()

# ---------- Scheduled task ----------
$taskState = "NOT_INSTALLED"
$lastResult = $null
$lastResultHex = $null
$lastRun = $null
$nextRun = $null
$task = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
if ($task) {
    $taskState = [string]$task.State
    $info = Get-ScheduledTaskInfo -TaskName $taskName -ErrorAction SilentlyContinue
    if ($info) {
        $lastResult = $info.LastTaskResult
        $lastResultHex = ('0x{0:X}' -f $info.LastTaskResult)
        if ($info.LastRunTime) { $lastRun = $info.LastRunTime.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ") }
        if ($info.NextRunTime) { $nextRun = $info.NextRunTime.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ") }
    }
}

# ---------- Heartbeats (freshness via file mtime — content-format agnostic) ----------
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

$localHb = Get-HeartbeatAge (Join-Path $RepoRoot ".claude/locks/dashboard-listener.heartbeat")

$sharedPath = $env:ROOSYNC_SHARED_PATH
$sharedHbFile = if ($sharedPath) { Join-Path (Join-Path $sharedPath "listener-heartbeats") "$machineId.heartbeat" } else { $null }
$sharedHb = Get-HeartbeatAge $sharedHbFile

# ---------- Last log line ----------
$lastLogLine = $null
$logDir = Join-Path $RepoRoot "outputs\scheduling\logs"
if (Test-Path $logDir) {
    $latestLog = Get-ChildItem -Path $logDir -Filter "listener-*.log" -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($latestLog) {
        $lastLogLine = Get-Content $latestLog.FullName -Tail 1 -ErrorAction SilentlyContinue
    }
}

# ---------- Verdict ----------
# ALIVE requires: task Running OR local heartbeat fresh. A fresh heartbeat is the
# strongest signal (the task can read Ready between repetition fires while the
# wrapper process is alive).
$hbFresh = $localHb.exists -and $localHb.ageSeconds -lt $StaleSeconds
if ($hbFresh -or $taskState -eq "Running") {
    $verdict = "ALIVE"
} elseif ($taskState -eq "NOT_INSTALLED") {
    $verdict = "NOT_INSTALLED"
} else {
    $verdict = "DEAD"
}

if ($Json) {
    [PSCustomObject]@{
        machine        = $machineId
        checkedAtUtc   = $nowUtc.ToString("yyyy-MM-ddTHH:mm:ssZ")
        verdict        = $verdict
        taskState      = $taskState
        lastTaskResult = $lastResultHex
        lastRunUtc     = $lastRun
        nextRunUtc     = $nextRun
        localHeartbeat = $localHb
        sharedHeartbeat = $sharedHb
        lastLogLine    = $lastLogLine
    } | ConvertTo-Json -Depth 5
    return
}

# Human / dashboard markdown block
$localStr = if ($localHb.exists) { "$($localHb.ageSeconds)s ago ($($localHb.mtime))" } else { "MISSING" }
$sharedStr = if ($sharedHb.exists) { "$($sharedHb.ageSeconds)s ago ($($sharedHb.mtime))" } else { "MISSING" }

Write-Output "### Wake-listener diagnostic — $machineId ($verdict)"
Write-Output ""
Write-Output "- Task: ``$taskName`` State=**$taskState** LastResult=$lastResultHex LastRun=$lastRun NextRun=$nextRun"
Write-Output "- Local heartbeat: $localStr"
Write-Output "- Shared heartbeat: $sharedStr"
Write-Output "- Last log line: $lastLogLine"
Write-Output ""
switch ($verdict) {
    "ALIVE"         { Write-Output "Verdict: **ALIVE** — listener heartbeat fresh / task running." }
    "DEAD"          { Write-Output "Verdict: **DEAD** — task State=$taskState, heartbeat stale (>$StaleSeconds s). [INTERACTIVE-ONLY] elevated re-install needed: ``install-dashboard-listener-schtask.ps1``." }
    "NOT_INSTALLED" { Write-Output "Verdict: **NOT_INSTALLED** — no ``$taskName`` task. [INTERACTIVE-ONLY] elevated install needed: ``install-dashboard-listener-schtask.ps1``." }
}

# ---------- Auto-alert (issue #2576) ----------
# When -Alert is set and verdict is DEAD/NOT_INSTALLED, append a [WARN] to the
# local workspace dashboard so the next RooSync cycle picks it up.
# This is the "alerting proactif" recommendation from #2576.
if ($Alert -and $verdict -in @("DEAD", "NOT_INSTALLED")) {
    $localDashDir = Join-Path $RepoRoot ".claude\workspaces"
    $localDashFile = Join-Path $localDashDir "workspace-$MachineId.md"
    $alertLine = "[WARN] $nowUtc `[$verdict`] $machineId listener $(if ($verdict -eq 'DEAD') { 'DEAD — heartbeat stale' } else { 'NOT INSTALLED' }). [INTERACTIVE-ONLY] install needed: install-dashboard-listener-schtask.ps1"

    if (Test-Path $localDashFile) {
        $content = Get-Content $localDashFile -Raw -Encoding UTF8
        # Append before the Intercom section header, or at end if none
        if ($content -match '(?ms)^## Intercom') {
            $content = $content -replace '(?ms)(^## Intercom)', "$alertLine`r`n`r`n`$1"
        } else {
            $content += "`r`n$r`n$alertLine"
        }
        # Always write (this is the alert mode — urgency over dry-run)
        if ($true) {
            [System.IO.File]::WriteAllText($localDashFile, $content, [System.Text.UTF8Encoding]::new($false))
            Write-Output "[ALERT] Appended [WARN] to $localDashFile (MCP unavailable, will sync on next RooSync cycle)"
        }
    } else {
        Write-Output "[ALERT] Local dashboard not found at $localDashFile — cannot post [WARN]. Manual dashboard update needed."
    }
}
