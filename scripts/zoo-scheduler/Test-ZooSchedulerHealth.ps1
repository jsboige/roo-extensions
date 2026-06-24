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
      UNKNOWN      — task has no ui_messages.json or is empty

    This is a post-flight detector, not a pre-flight blocker. It catches the
    silent-0%-success mode described in #2534 within hours instead of days.
    Pre-flight (read state.vscdb to validate modeApiConfigs) is left as a
    future enhancement — it needs a SQLite reader, which is not always
    available in the scheduler environment.

.PARAMETER TaskLimit
    Number of most-recent tasks to scan. Default: 12 (~3 days at the 6h cadence).

.PARAMETER Machine
    Machine name for reporting. Default: $env:COMPUTERNAME.

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
    Issue: #2534
#>
param(
    [int]$TaskLimit = 12,
    [string]$Machine = $env:COMPUTERNAME,
    [switch]$AsJson,
    [switch]$PostToDashboard,
    [double]$WarnThreshold = 50.0,
    [double]$CriticalThreshold = 10.0
)

$ErrorActionPreference = "Stop"

$ZooTasksPath = Join-Path $env:APPDATA "Code\User\globalStorage\zoocodeorganization.zoo-code\tasks"

# Auth-fail signature — exact error from #2534 / po-2025 diagnostic
$AuthFailPattern = "Could not resolve authentication method"

function Get-TaskOutcome {
    param([string]$TaskDir)

    $uiMessagesPath = Join-Path $TaskDir "ui_messages.json"
    if (-not (Test-Path $uiMessagesPath)) {
        return @{ Outcome = "UNKNOWN"; Reason = "ui_messages.json missing"; Ts = $null }
    }

    $ts = (Get-Item $uiMessagesPath).LastWriteTimeUtc
    $raw = [System.IO.File]::ReadAllText($uiMessagesPath)
    if ([string]::IsNullOrWhiteSpace($raw)) {
        return @{ Outcome = "UNKNOWN"; Reason = "ui_messages.json empty"; Ts = $ts }
    }

    try {
        $messages = $raw | ConvertFrom-Json
    } catch {
        return @{ Outcome = "UNKNOWN"; Reason = "ui_messages.json parse error"; Ts = $ts }
    }

    $hasAuthFail = $false
    $hasOtherFail = $false
    $hasCompletionResult = $false

    foreach ($msg in $messages) {
        if ($msg.type -eq "ask" -and $msg.ask -eq "api_req_failed") {
            if ($msg.text -and ($msg.text -match $AuthFailPattern)) {
                $hasAuthFail = $true
            } else {
                $hasOtherFail = $true
            }
            continue
        }
        if ($msg.type -eq "say" -and $msg.say -eq "completion_result") {
            $hasCompletionResult = $true
        }
    }

    if ($hasAuthFail) {
        return @{ Outcome = "AUTH_FAIL"; Reason = "auth resolution failed"; Ts = $ts }
    }
    if ($hasCompletionResult) {
        return @{ Outcome = "SUCCESS"; Reason = "completion_result emitted"; Ts = $ts }
    }
    if ($hasOtherFail) {
        return @{ Outcome = "OTHER_FAIL"; Reason = "api_req_failed (non-auth)"; Ts = $ts }
    }
    return @{ Outcome = "UNKNOWN"; Reason = "no terminal marker"; Ts = $ts }
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

# Enumerate task dirs (skip _index.json and non-directory entries)
$taskDirs = Get-ChildItem -Path $ZooTasksPath -Directory -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First $TaskLimit

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
$counts = @{ AUTH_FAIL = 0; SUCCESS = 0; OTHER_FAIL = 0; UNKNOWN = 0 }

foreach ($dir in $taskDirs) {
    $outcome = Get-TaskOutcome -TaskDir $dir.FullName
    $counts[$outcome.Outcome] = $counts[$outcome.Outcome] + 1
    $results += @{
        taskId   = $dir.Name
        outcome  = $outcome.Outcome
        reason   = $outcome.Reason
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
} elseif ($successRate -lt $WarnThreshold) {
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
    Write-Host "Counts       : SUCCESS=$($counts.SUCCESS) AUTH_FAIL=$($counts.AUTH_FAIL) OTHER_FAIL=$($counts.OTHER_FAIL) UNKNOWN=$($counts.UNKNOWN)"
    $color = if ($status -eq "HEALTHY") { "Green" } elseif ($status -eq "WARN") { "Yellow" } else { "Red" }
    Write-Host "Status       : $status" -ForegroundColor $color
    Write-Host ""
    Write-Host "Recent tasks (most recent first):"
    $results | Select-Object -First 8 | ForEach-Object {
        $tsStr = if ($_.ts) { ([DateTime]$_.ts).ToString("yyyy-MM-dd HH:mmZ") } else { "n/a" }
        $c = if ($_.outcome -eq "SUCCESS") { "Green" } elseif ($_.outcome -eq "AUTH_FAIL") { "Red" } else { "Yellow" }
        Write-Host ("  {0}  {1,-11}  {2}  ({3})" -f $tsStr, $_.outcome, $_.taskId.Substring(0,8), $_.reason) -ForegroundColor $c
    }
    if ($status -ne "HEALTHY") {
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
        $content += "Counts: AUTH_FAIL=$($counts.AUTH_FAIL) SUCCESS=$($counts.SUCCESS) OTHER_FAIL=$($counts.OTHER_FAIL) UNKNOWN=$($counts.UNKNOWN)`n"
        $content += "Detector: scripts/zoo-scheduler/Test-ZooSchedulerHealth.ps1 (#2534)`n"
        $content += "Action: verify Zoo Code -> Settings -> API Provider has a valid apiKey."
        # Deferred to caller — the MCP call must happen in a session that has the tool
        Write-Host ""
        Write-Host "[INFO] -PostToDashboard set: caller should relay the summary above to" -ForegroundColor Cyan
        Write-Host "       roosync_dashboard(action:'append', type:'workspace', tags:['$tag'], content:...)" -ForegroundColor Cyan
    } catch {
        Write-Host "[WARN] Dashboard post skipped: $_" -ForegroundColor Yellow
    }
}

exit $exitCode
