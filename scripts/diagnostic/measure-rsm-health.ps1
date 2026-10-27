<#
.SYNOPSIS
    Measures this seat's RSM health and prints one [RSM-HEALTH] line (#4289, grain h-RSM).

.DESCRIPTION
    A seat whose RSM is struggling cannot report it through RSM, so the coordinator reads
    silence as health (user, 27/10: "quand RSM est en souffrance, tu ne vois rien"). This
    instrument makes the suffering readable from the seat itself, at every pre-flight.

    It measures four things:
      - the number of live RSM hosts on the machine;
      - the max private memory of a single host;
      - the [pg-resume] connection-timeout and (cloud-only?) events in today's RSM log;
      - the median [dashboard-pg] read latency.

    WARN never blocks (#3169 posture): exit 0 = OK, 2 = WARN, 1 = instrument error.
    The pre-flight relays the WARN, it does not stop the cycle.

    Thresholds (grain definition, comment 6447705634):
      - max private memory above -MaxPrivateMBThreshold (default 1536 MB);
      - at least -CloudOnlyPerHourThreshold (cloud-only?) events per observed hour
        (default 1).

    Counting rule -- the log is NOT one-line-per-event. A single failure writes an event
    header (`[2026-10-27 00:28:59] [WARN] [pg-cold-pool-resume] ...`) followed by indented
    JSON detail lines that repeat the same words. A naive `grep -c "connection timeout"`
    double- and triple-counts (measured 27/10 on myia-po-2023: 298 raw lines, 95 events).
    Only lines that begin with `[` are counted, so one event costs one.

.NOTES
    PS 5.1 compatible. ASCII only on purpose: a non-ASCII .ps1 without a UTF-8 BOM is
    decoded as cp1252 by 5.1 (ps51-parse-class.Tests.ps1).

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File scripts/diagnostic/measure-rsm-health.ps1
.EXAMPLE
    powershell -ExecutionPolicy Bypass -File scripts/diagnostic/measure-rsm-health.ps1 -Json
#>
[CmdletBinding()]
param(
    # RSM log files. Default: today's log under the RSM temp log directory.
    [string[]]$LogPath,

    # Local-time day used to pick the default log file (YYYYMMDD).
    [string]$DayStamp = (Get-Date).ToString('yyyyMMdd'),

    [double]$MaxPrivateMBThreshold = 1536,

    [double]$CloudOnlyPerHourThreshold = 1,

    # Machine-readable output instead of the [RSM-HEALTH] line.
    [switch]$Json
)

$ErrorActionPreference = 'Stop'

# --- pure helpers -----------------------------------------------------------

function Get-MedianValue {
    param([double[]]$Values)

    if (-not $Values -or $Values.Count -eq 0) { return $null }
    $sorted = @($Values | Sort-Object)
    $count = $sorted.Count
    if ($count % 2 -eq 1) {
        return [double]$sorted[[int](($count - 1) / 2)]
    }
    $mid = $count / 2
    return [double](($sorted[$mid - 1] + $sorted[$mid]) / 2)
}

function Get-RsmLogMetrics {
    <#
        Counts events, not log lines (see .DESCRIPTION). Returns an object with
        CloudOnly, ConnectionTimeouts, PgLatencies and LogFiles. A missing log file is
        not an error: it means no RSM activity was logged today.
    #>
    param([string[]]$Files)

    $cloudOnly = 0
    $connTimeouts = 0
    $latencies = New-Object System.Collections.Generic.List[double]
    $seen = 0

    foreach ($file in @($Files)) {
        if (-not $file -or -not (Test-Path -LiteralPath $file)) { continue }
        $seen++
        foreach ($line in (Get-Content -LiteralPath $file -ErrorAction SilentlyContinue)) {
            # Event headers start with the timestamp bracket; JSON detail lines are indented.
            if ($line -notmatch '^\[') { continue }
            if ($line -match 'cloud-only\?') { $cloudOnly++ }
            if ($line -match 'connection timeout') { $connTimeouts++ }
            if ($line -match '\[dashboard-pg\] dashboard served from PG in (\d+)ms') {
                $latencies.Add([double]$Matches[1])
            }
        }
    }

    return [pscustomobject]@{
        CloudOnly          = $cloudOnly
        ConnectionTimeouts = $connTimeouts
        PgLatencies        = @($latencies)
        LogFiles           = $seen
    }
}

function Get-RsmHealthReport {
    <#
        Pure aggregation + verdict. Inputs are already-measured data so the Pester test
        can run on any OS without touching real processes or files.
    #>
    param(
        $Hosts,
        $LogMetrics,
        [double]$HoursObserved = 1,
        [double]$MaxPrivateMBThreshold = 1536,
        [double]$CloudOnlyPerHourThreshold = 1
    )

    $hostList = @($Hosts | Where-Object { $_ -ne $null })
    $hostCount = $hostList.Count
    $maxPrivateMB = 0
    if ($hostCount -gt 0) {
        $maxPrivateMB = ($hostList | Measure-Object -Property PrivateMB -Maximum).Maximum
    }

    $cloudOnly = 0
    $connTimeouts = 0
    $pgLatencies = @()
    $logFiles = 0
    if ($LogMetrics) {
        $cloudOnly = [int]$LogMetrics.CloudOnly
        $connTimeouts = [int]$LogMetrics.ConnectionTimeouts
        $pgLatencies = @($LogMetrics.PgLatencies)
        $logFiles = [int]$LogMetrics.LogFiles
    }

    $windowHours = $HoursObserved
    if (-not $windowHours -or $windowHours -le 0) { $windowHours = 1 }
    $cloudOnlyPerHour = [math]::Round($cloudOnly / $windowHours, 2)

    $reasons = @()
    if ($maxPrivateMB -gt $MaxPrivateMBThreshold) {
        $reasons += ('max-memory: {0}MB > {1}MB' -f [int]$maxPrivateMB, [int]$MaxPrivateMBThreshold)
    }
    if ($cloudOnlyPerHour -ge $CloudOnlyPerHourThreshold) {
        $reasons += ('cloud-only: {0}/h >= {1}/h' -f $cloudOnlyPerHour, $CloudOnlyPerHourThreshold)
    }

    $verdict = if ($reasons.Count -gt 0) { 'WARN' } else { 'OK' }

    return [pscustomobject]@{
        HostCount             = $hostCount
        MaxPrivateMB          = [int]$maxPrivateMB
        CloudOnly             = $cloudOnly
        CloudOnlyPerHour      = $cloudOnlyPerHour
        ConnectionTimeouts    = $connTimeouts
        PgMedianMs            = Get-MedianValue -Values $pgLatencies
        PgSamples             = $pgLatencies.Count
        LogFiles              = $logFiles
        WindowHours           = [math]::Round($windowHours, 1)
        ThresholdMaxPrivateMB = $MaxPrivateMBThreshold
        ThresholdCloudOnlyPerH = $CloudOnlyPerHourThreshold
        Verdict               = $verdict
        Reasons               = @($reasons)
    }
}

function Format-RsmHealthLine {
    param($Report)

    if (-not $Report) { return '[RSM-HEALTH] no report' }

    # Invariant culture: a French seat renders 139,5 with a comma, which breaks the
    # "one key=value line" contract the coordinator greps.
    $inv = [System.Globalization.CultureInfo]::InvariantCulture
    $median = 'n/a'
    if ($null -ne $Report.PgMedianMs) {
        # '0.##' keeps a fractional median (139.5) and drops the noise on an integer
        # one (139). Formatting with '0' would silently round 139.5 up to 140: a
        # measurement that moves without saying so.
        $median = ([double]$Report.PgMedianMs).ToString('0.##', $inv)
    }

    $line = '[RSM-HEALTH] hosts={0} maxPrivMB={1} cloudOnly={2} connTimeout={3} pgMedianMs={4} pgSamples={5} window={6}h verdict={7}' -f `
        $Report.HostCount, $Report.MaxPrivateMB, $Report.CloudOnly, $Report.ConnectionTimeouts,
        $median, $Report.PgSamples, ([double]$Report.WindowHours).ToString('0.0', $inv), $Report.Verdict

    if ($Report.Reasons -and $Report.Reasons.Count -gt 0) {
        $line += ' (' + ($Report.Reasons -join '; ') + ')'
    }
    return $line
}

# --- impure measurement -----------------------------------------------------

function Get-RsmHostMetrics {
    <#
        Live RSM hosts: node processes whose command line mentions roo-state-manager.
        Private memory (not working set) is the number that matters for the hourly sweep
        cost: each host hydrates its own copy of the skeleton cache.
    #>
    $metrics = @()
    $candidates = @()
    try {
        $candidates = @(Get-CimInstance Win32_Process -Filter "Name='node.exe'" -ErrorAction Stop |
            Where-Object { $_.CommandLine -and $_.CommandLine -match 'roo-state-manager' })
    } catch {
        # Get-CimInstance is Windows-only; on another OS the host count is simply unknown
        # (0) and the rest of the line still stands.
        return $metrics
    }

    foreach ($proc in $candidates) {
        $procId = [int]$proc.ProcessId
        $privateMB = 0
        $gp = Get-Process -Id $procId -ErrorAction SilentlyContinue
        if ($gp) {
            try { $privateMB = [int][math]::Round($gp.PrivateMemorySize64 / 1MB, 0) } catch { $privateMB = 0 }
            $gp.Dispose()
        }
        $metrics += [pscustomobject]@{ ProcessId = $procId; PrivateMB = $privateMB }
    }
    return $metrics
}

function Get-DefaultRsmLogPaths {
    param([string]$DayStamp)

    $logDir = Join-Path ([System.IO.Path]::GetTempPath()) 'roo-state-manager-logs'
    $file = Join-Path $logDir ('roosync-{0}.log' -f $DayStamp)
    return @($file)
}

# --- main -------------------------------------------------------------------

# Dot-sourced by the Pester test: expose the functions, run nothing.
if ($MyInvocation.InvocationName -ne '.') {
    try {
        $files = @($LogPath)
        if ($files.Count -eq 0 -or -not $files[0]) {
            $files = Get-DefaultRsmLogPaths -DayStamp $DayStamp
        }

        $now = Get-Date
        $midnight = $now.Date
        $hoursObserved = ($now - $midnight).TotalHours
        if ($hoursObserved -lt 1) { $hoursObserved = 1 }

        $report = Get-RsmHealthReport `
            -Hosts (Get-RsmHostMetrics) `
            -LogMetrics (Get-RsmLogMetrics -Files $files) `
            -HoursObserved $hoursObserved `
            -MaxPrivateMBThreshold $MaxPrivateMBThreshold `
            -CloudOnlyPerHourThreshold $CloudOnlyPerHourThreshold

        if ($Json) {
            $report | ConvertTo-Json -Depth 4
        } else {
            $line = Format-RsmHealthLine -Report $report
            if ($report.Verdict -eq 'WARN') {
                Write-Warning $line
            } else {
                Write-Host $line
            }
        }

        if ($report.Verdict -eq 'WARN') { exit 2 }
        exit 0
    } catch {
        $detail = if ($_.Exception) { $_.Exception.Message } else { $_.ToString() }
        Write-Error ('[RSM-HEALTH] instrument error: {0}' -f $detail)
        exit 1
    }
}
