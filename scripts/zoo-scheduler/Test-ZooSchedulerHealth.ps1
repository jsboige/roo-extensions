<#
.SYNOPSIS
    Detects silent Zoo scheduler auth failures by scanning task logs.

.DESCRIPTION
    Issue #2534 — Zoo scheduler on po-2025 went 9+ days at 100% auth failure
    without any alert. This script reads the JSON task logs that Zoo Code
    writes under globalStorage and classifies each task outcome.

    Classification per task:
      AUTH_FAIL    — `api_req_failed` with the auth-resolution error pattern
                     ("Could not resolve authentication method")
      OTHER_FAIL   — `api_req_failed` with a different error, OR task ended
                     without any `text`/`completion_result` from the assistant
      SUCCESS      — assistant produced a `completion_result` (ran to end)
      STALLED      — #3220: no `completion_result`, last message is a `say`
                     (not an `ask` awaiting input), quiet for >= StaleMinutes,
                     and last write within MaxAgeHours. Catches cycles that
                     died mid proxy-502 storm (rail of
                     `say: api_req_retry_delayed` then silence) and, by the
                     same primitive, tasks killed by timeout/kill: the signal
                     is the missing terminal marker, not the failure cause.
      UNKNOWN      — task has no ui_messages.json or is empty

    This is a post-flight detector, not a pre-flight blocker. It catches the
    silent-0%-success mode described in #2534 within hours instead of days.
    Pre-flight (read state.vscdb to validate modeApiConfigs) is left as a
    future enhancement — it needs a SQLite reader, which is not always
    available in the scheduler environment.

.PARAMETER TaskLimit
    Number of most-recent tasks to scan for the success-rate stats. Default: 12
    (~3 days at the 6h cadence). The #3220 stall scan always covers the full
    MaxAgeHours window regardless of this count.

.PARAMETER StaleMinutes
    #3220: a task with no completion_result is only STALLED once its
    ui_messages.json has been quiet for at least this many minutes — the gate
    that keeps live tasks (still retrying, still streaming) out of the alert.
    Default: 60.

.PARAMETER MaxAgeHours
    #3220: STALLED only flags tasks whose last write is within this window, so
    the [WARN] stays timely instead of resurfacing days-old corpses every run.
    Default: 24.

.PARAMETER Machine
    Machine name for reporting. Default: $env:COMPUTERNAME.

.PARAMETER TasksPath
    #3220: override the Zoo task store path (default: the Zoo Code
    globalStorage tasks dir). Only meant for synthetic-fixture tests —
    lets the STALLED gates be exercised without touching the real store.

.PARAMETER AsJson
    Emit machine-parseable JSON instead of human-readable text.

.PARAMETER PostToDashboard
    If set, appends a [WARN]/[ERROR] entry to the workspace dashboard via the
    roo-state-manager MCP when success rate is below threshold. Requires the
    MCP to be available in the calling session.

.PARAMETER WarnThreshold
    Success rate below which the script warns (0-100). Default: 50.

.PARAMETER CriticalThreshold
    Success rate below which the script exits CRITICAL (0-100). Default: 10.

.EXAMPLE
    .\Test-ZooSchedulerHealth.ps1
    Scans last 12 Zoo tasks, prints human-readable report.

.EXAMPLE
    .\Test-ZooSchedulerHealth.ps1 -TaskLimit 24 -AsJson
    Scans last 24 tasks, emits JSON.

.NOTES
    Exit codes: 0 = healthy, 1 = warn, 2 = critical, 3 = error (script-level)
    Issues: #2534 (auth-fail mode), #3220 (dead-cycle STALLED mode)
#>
param(
    [int]$TaskLimit = 12,
    [int]$StaleMinutes = 60,
    [int]$MaxAgeHours = 24,
    [string]$Machine = $env:COMPUTERNAME,
    [string]$TasksPath = "",
    [switch]$AsJson,
    [switch]$PostToDashboard,
    [double]$WarnThreshold = 50.0,
    [double]$CriticalThreshold = 10.0
)

$ErrorActionPreference = "Stop"

# -TasksPath overrides the default Zoo store (synthetic-fixture tests only)
$ZooTasksPath = if ($TasksPath) { $TasksPath } else {
    Join-Path $env:APPDATA "Code\User\globalStorage\zoocodeorganization.zoo-code\tasks"
}

# Auth-fail signature — exact error from #2534 / po-2025 diagnostic
$AuthFailPattern = "Could not resolve authentication method"

# #3220 — action guidance for dead cycles (shared by console + dashboard output)
$StalledAction = "dead Zoo cycle(s): no completion_result after going quiet (proxy 502 storm or kill). Identify the missed scheduled slot and re-dispatch lost work. See issue #3220."

function Get-TaskOutcome {
    param([string]$TaskDir)

    $uiMessagesPath = Join-Path $TaskDir "ui_messages.json"
    if (-not (Test-Path $uiMessagesPath)) {
        return @{ Outcome = "UNKNOWN"; Reason = "ui_messages.json missing"; Ts = $null; LastEvent = $null }
    }

    $ts = (Get-Item $uiMessagesPath).LastWriteTimeUtc
    $raw = [System.IO.File]::ReadAllText($uiMessagesPath)
    if ([string]::IsNullOrWhiteSpace($raw)) {
        return @{ Outcome = "UNKNOWN"; Reason = "ui_messages.json empty"; Ts = $ts; LastEvent = $null }
    }

    try {
        $messages = $raw | ConvertFrom-Json
    } catch {
        return @{ Outcome = "UNKNOWN"; Reason = "ui_messages.json parse error"; Ts = $ts; LastEvent = $null }
    }

    $hasAuthFail = $false
    $hasOtherFail = $false
    $hasCompletionResult = $false
    # #3220: identifier of the FINAL message ("say:<x>" / "ask:<x>"). A trailing
    # `ask` means the task is parked on external input (followup, tool approval) —
    # alive from the detector's point of view, never STALLED.
    $lastEvent = $null

    foreach ($msg in $messages) {
        if ($msg.type -eq "ask" -and $msg.ask) {
            $lastEvent = "ask:$($msg.ask)"
            if ($msg.ask -eq "api_req_failed") {
                if ($msg.text -and ($msg.text -match $AuthFailPattern)) {
                    $hasAuthFail = $true
                } else {
                    $hasOtherFail = $true
                }
            }
            continue
        }
        if ($msg.type -eq "say" -and $msg.say) {
            $lastEvent = "say:$($msg.say)"
            if ($msg.say -eq "completion_result") {
                $hasCompletionResult = $true
            }
        }
    }

    if ($hasAuthFail) {
        return @{ Outcome = "AUTH_FAIL"; Reason = "auth resolution failed"; Ts = $ts; LastEvent = $lastEvent }
    }
    if ($hasCompletionResult) {
        return @{ Outcome = "SUCCESS"; Reason = "completion_result emitted"; Ts = $ts; LastEvent = $lastEvent }
    }
    if ($hasOtherFail) {
        return @{ Outcome = "OTHER_FAIL"; Reason = "api_req_failed (non-auth)"; Ts = $ts; LastEvent = $lastEvent }
    }
    return @{ Outcome = "UNKNOWN"; Reason = "no terminal marker"; Ts = $ts; LastEvent = $lastEvent }
}

if (-not (Test-Path $ZooTasksPath)) {
    $msg = "Zoo tasks path not found: $ZooTasksPath (Zoo Code not installed or never run)"
    if ($AsJson) {
        @{ status = "ERROR"; error = $msg; machine = $Machine } | ConvertTo-Json -Compress
    } else {
        Write-Host "[ERROR] $msg" -ForegroundColor Red
    }
    exit 3
}

$nowUtc = [DateTime]::UtcNow

# Enumerate task dirs (skip _index.json and non-directory entries).
# #3220: union of the TaskLimit most recent (success-rate window, #2534
# semantics) with every dir written inside MaxAgeHours — a corpse from this
# morning must not escape the stall scan just because a busy interactive day
# buried it deeper than TaskLimit.
$allDirs = Get-ChildItem -Path $ZooTasksPath -Directory -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending
$stallCutoff = $nowUtc.AddHours(-$MaxAgeHours)
$taskDirs = @()
$pos = 0
foreach ($d in $allDirs) {
    if ($pos -lt $TaskLimit -or $d.LastWriteTimeUtc -ge $stallCutoff) {
        $taskDirs += $d
    }
    $pos++
}

if (-not $taskDirs -or $taskDirs.Count -eq 0) {
    $msg = "No Zoo tasks found in $ZooTasksPath"
    if ($AsJson) {
        @{ status = "UNKNOWN"; error = $msg; machine = $Machine; scanned = 0 } | ConvertTo-Json -Compress
    } else {
        Write-Host "[UNKNOWN] $msg" -ForegroundColor Yellow
    }
    exit 3
}

$results = @()
$counts = @{ AUTH_FAIL = 0; SUCCESS = 0; OTHER_FAIL = 0; STALLED = 0; UNKNOWN = 0 }

foreach ($dir in $taskDirs) {
    $outcome = Get-TaskOutcome -TaskDir $dir.FullName
    $out = $outcome.Outcome
    $reason = $outcome.Reason

    # #3220: a task with no terminal marker that went quiet is a dead cycle —
    # 502-storm (rail of say:api_req_retry_delayed) or kill/timeout, same
    # primitive. Recent writes mean still live (retrying/streaming): skip.
    if ($out -eq "UNKNOWN" -and $outcome.Ts -and $outcome.LastEvent -and
        $outcome.LastEvent -notlike "ask:*") {
        $quietMin = ($nowUtc - $outcome.Ts).TotalMinutes
        if ($quietMin -ge $StaleMinutes -and $quietMin -le ($MaxAgeHours * 60)) {
            $out = "STALLED"
            $reason = "no completion_result, last event $($outcome.LastEvent), quiet $([int]$quietMin) min"
        }
    }

    $counts[$out] = $counts[$out] + 1
    $results += @{
        taskId   = $dir.Name
        outcome  = $out
        reason   = $reason
        ts       = $outcome.Ts
    }
}

$scanned = $results.Count
$successCount = $counts.SUCCESS
$successRate = if ($scanned -gt 0) { ($successCount / $scanned) * 100.0 } else { 0.0 }

$status = "HEALTHY"
$exitCode = 0
if ($successRate -lt $CriticalThreshold) {
    $status = "CRITICAL"
    $exitCode = 2
} elseif ($successRate -lt $WarnThreshold -or $counts.STALLED -gt 0) {
    # #3220: even one dead cycle warrants WARN on its own — a stalled task is
    # invisible to the success-rate thresholds once healthy cycles resume.
    $status = "WARN"
    $exitCode = 1
}

$report = @{
    status        = $status
    machine       = $Machine
    scanned       = $scanned
    successRate   = [math]::Round($successRate, 1)
    counts        = $counts
    tasks         = $results
    thresholds    = @{ warn = $WarnThreshold; critical = $CriticalThreshold }
    generatedAt   = (Get-Date).ToUniversalTime().ToString("o")
}

if ($AsJson) {
    $report | ConvertTo-Json -Depth 6
} else {
    Write-Host ""
    Write-Host "=== Zoo Scheduler Health ($Machine) ===" -ForegroundColor Cyan
    Write-Host "Scanned      : $scanned most-recent tasks"
    Write-Host "Success rate : $($report.successRate)% ($successCount/$scanned)"
    Write-Host "Counts       : SUCCESS=$($counts.SUCCESS) AUTH_FAIL=$($counts.AUTH_FAIL) OTHER_FAIL=$($counts.OTHER_FAIL) STALLED=$($counts.STALLED) UNKNOWN=$($counts.UNKNOWN)"
    $color = if ($status -eq "HEALTHY") { "Green" } elseif ($status -eq "WARN") { "Yellow" } else { "Red" }
    Write-Host "Status       : $status" -ForegroundColor $color
    Write-Host ""
    Write-Host "Recent tasks (most recent first):"
    $results | Select-Object -First 8 | ForEach-Object {
        $tsStr = if ($_.ts) { ([DateTime]$_.ts).ToString("yyyy-MM-dd HH:mmZ") } else { "n/a" }
        $c = if ($_.outcome -eq "SUCCESS") { "Green" } elseif ($_.outcome -in @("AUTH_FAIL", "STALLED")) { "Red" } else { "Yellow" }
        Write-Host ("  {0}  {1,-11}  {2}  ({3})" -f $tsStr, $_.outcome, $_.taskId.Substring(0,8), $_.reason) -ForegroundColor $c
    }
    if ($counts.STALLED -gt 0) {
        Write-Host ""
        Write-Host "Action: $StalledAction" -ForegroundColor Yellow
    }
    if ($status -ne "HEALTHY" -and $counts.AUTH_FAIL -gt 0) {
        Write-Host ""
        Write-Host "Action: Zoo provider config likely missing/invalid apiKey." -ForegroundColor Yellow
        Write-Host "        Open Zoo Code -> Settings -> API Provider and verify the" -ForegroundColor Yellow
        Write-Host "        selected profile has a valid apiKey. See issue #2534." -ForegroundColor Yellow
    }
}

# Optional dashboard post (only when degraded — silent-fail detection)
if ($PostToDashboard -and $status -ne "HEALTHY") {
    try {
        $tag = if ($status -eq "CRITICAL") { "ERROR" } else { "WARN" }
        $content = "[$tag] Zoo scheduler health ($Machine): $status`n"
        $content += "Success rate: $($report.successRate)% ($successCount/$scanned over $scanned tasks)`n"
        $content += "Counts: AUTH_FAIL=$($counts.AUTH_FAIL) SUCCESS=$($counts.SUCCESS) OTHER_FAIL=$($counts.OTHER_FAIL) STALLED=$($counts.STALLED) UNKNOWN=$($counts.UNKNOWN)`n"
        if ($counts.STALLED -gt 0) {
            $stalledList = @($results | Where-Object { $_.outcome -eq "STALLED" } |
                ForEach-Object { "$($_.taskId.Substring(0,8)) ($($_.reason))" })
            $content += "Dead cycles (#3220):`n" + (($stalledList | Select-Object -First 5 | ForEach-Object { "- $_" }) -join "`n") + "`n"
        }
        $content += "Detector: scripts/zoo-scheduler/Test-ZooSchedulerHealth.ps1 (#2534, #3220)`n"
        $content += "Action: verify Zoo Code -> Settings -> API Provider has a valid apiKey."
        if ($counts.STALLED -gt 0) {
            $content += "`nAction: $StalledAction"
        }
        # Deferred to caller — the MCP call must happen in a session that has the tool
        Write-Host ""
        Write-Host "[INFO] -PostToDashboard set: caller should relay the summary above to" -ForegroundColor Cyan
        Write-Host "       roosync_dashboard(action:'append', type:'workspace', tags:['$tag'], content:...)" -ForegroundColor Cyan
    } catch {
        Write-Host "[WARN] Dashboard post skipped: $_" -ForegroundColor Yellow
    }
}

exit $exitCode
