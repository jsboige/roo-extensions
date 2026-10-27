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

    Thresholds (grain definition, comment 6447705634; the RAM and conn-timeout rules
    come from the #4388 review: po-2023 fell on TOTAL memory -- 24 hosts, 16.9 GB
    private, 0.7 GB free RAM -- which maxPrivMB alone never sees, and its 95 cold-pool
    timeouts were counted but never judged):
      - max private memory above -MaxPrivateMBThreshold (default 1536 MB);
      - at least -CloudOnlyPerHourThreshold (cloud-only?) events per observed hour
        (default 1);
      - at least -ConnTimeoutPerHourThreshold connection-timeout events per observed
        hour (default 5: po-2023 measured 95/18.1 h = 5.25/h, WARN; ai-01 0/h, OK);
      - free physical RAM under -FreeRamWarnPercent percent of total (default 10) OR
        under -FreeRamWarnFloorMB (default 4096 MB). Unknown RAM judges nothing.

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

    [double]$ConnTimeoutPerHourThreshold = 5,

    [double]$FreeRamWarnPercent = 10,

    [double]$FreeRamWarnFloorMB = 4096,

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
        $RamMetrics,
        [double]$HoursObserved = 1,
        [double]$MaxPrivateMBThreshold = 1536,
        [double]$CloudOnlyPerHourThreshold = 1,
        [double]$ConnTimeoutPerHourThreshold = 5,
        [double]$FreeRamWarnPercent = 10,
        [double]$FreeRamWarnFloorMB = 4096
    )

    $hostList = @($Hosts | Where-Object { $_ -ne $null })
    $hostCount = $hostList.Count
    $maxPrivateMB = 0
    $totalPrivateMB = 0
    if ($hostCount -gt 0) {
        $maxPrivateMB = ($hostList | Measure-Object -Property PrivateMB -Maximum).Maximum
        # #4388: the sum, not the max, is what ate po-2023's RAM (24 modest hosts,
        # 16.9 GB together). Informational in the line; the WARN itself fires on
        # free RAM, which is the consequence a seat actually feels.
        $sumResult = ($hostList | Measure-Object -Property PrivateMB -Sum).Sum
        if ($null -ne $sumResult) { $totalPrivateMB = [double]$sumResult }
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

    # Unknown RAM (non-Windows, CIM failure) stays null and judges nothing.
    $freeRamMB = $null
    $totalRamMB = $null
    if ($RamMetrics) {
        if ($null -ne $RamMetrics.FreeRamMB) { $freeRamMB = [double]$RamMetrics.FreeRamMB }
        if ($null -ne $RamMetrics.TotalRamMB) { $totalRamMB = [double]$RamMetrics.TotalRamMB }
    }

    $windowHours = $HoursObserved
    if (-not $windowHours -or $windowHours -le 0) { $windowHours = 1 }
    $cloudOnlyPerHour = [math]::Round($cloudOnly / $windowHours, 2)
    $connTimeoutPerHour = [math]::Round($connTimeouts / $windowHours, 2)

    # Reasons ride the same greppable line as Format-RsmHealthLine, so they owe the
    # same invariant-decimal contract: a French seat renders 5.25 as "5,25", which
    # breaks the key=value line the coordinator greps (caught by the #4388 tests
    # running under fr-FR; the cloud-only reason carried the same latent bug).
    $inv = [System.Globalization.CultureInfo]::InvariantCulture
    $reasons = @()
    if ($maxPrivateMB -gt $MaxPrivateMBThreshold) {
        $reasons += ('max-memory: {0}MB > {1}MB' -f [int]$maxPrivateMB, [int]$MaxPrivateMBThreshold)
    }
    if ($cloudOnlyPerHour -ge $CloudOnlyPerHourThreshold) {
        $reasons += ('cloud-only: {0}/h >= {1}/h' -f `
            $cloudOnlyPerHour.ToString('0.##', $inv), $CloudOnlyPerHourThreshold.ToString('0.##', $inv))
    }
    if ($connTimeoutPerHour -ge $ConnTimeoutPerHourThreshold) {
        $reasons += ('conn-timeout: {0}/h >= {1}/h' -f `
            $connTimeoutPerHour.ToString('0.##', $inv), $ConnTimeoutPerHourThreshold.ToString('0.##', $inv))
    }
    if ($null -ne $freeRamMB -and $null -ne $totalRamMB -and $totalRamMB -gt 0) {
        $pctFree = [math]::Round(100 * $freeRamMB / $totalRamMB, 1)
        $underPercent = $freeRamMB -lt ($totalRamMB * $FreeRamWarnPercent / 100)
        $underFloor = $freeRamMB -lt $FreeRamWarnFloorMB
        if ($underPercent -or $underFloor) {
            $reasons += ('free-ram: {0}MB free of {1}MB ({2}%) -- under {3}% or {4}MB' -f `
                [int]$freeRamMB, [int]$totalRamMB, $pctFree.ToString('0.#', $inv), $FreeRamWarnPercent.ToString('0.#', $inv), [int]$FreeRamWarnFloorMB)
        }
    }

    $verdict = if ($reasons.Count -gt 0) { 'WARN' } else { 'OK' }

    return [pscustomobject]@{
        HostCount                = $hostCount
        MaxPrivateMB             = [int]$maxPrivateMB
        TotalPrivateMB           = [int]$totalPrivateMB
        FreeRamMB                = $freeRamMB
        TotalRamMB               = $totalRamMB
        CloudOnly                = $cloudOnly
        CloudOnlyPerHour         = $cloudOnlyPerHour
        ConnectionTimeouts       = $connTimeouts
        ConnTimeoutPerHour       = $connTimeoutPerHour
        PgMedianMs               = Get-MedianValue -Values $pgLatencies
        PgSamples                = $pgLatencies.Count
        LogFiles                 = $logFiles
        WindowHours              = [math]::Round($windowHours, 1)
        ThresholdMaxPrivateMB    = $MaxPrivateMBThreshold
        ThresholdCloudOnlyPerH   = $CloudOnlyPerHourThreshold
        ThresholdConnTimeoutPerH = $ConnTimeoutPerHourThreshold
        ThresholdFreeRamPct      = $FreeRamWarnPercent
        ThresholdFreeRamFloorMB  = $FreeRamWarnFloorMB
        Verdict                  = $verdict
        Reasons                  = @($reasons)
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

    $freeRam = 'n/a'
    if ($null -ne $Report.FreeRamMB) {
        $freeRam = ([double]$Report.FreeRamMB).ToString('0.#', $inv)
    }

    $line = '[RSM-HEALTH] hosts={0} maxPrivMB={1} totalPrivMB={2} freeRamMB={3} cloudOnly={4} connTimeout={5} pgMedianMs={6} pgSamples={7} window={8}h verdict={9}' -f `
        $Report.HostCount, $Report.MaxPrivateMB, $Report.TotalPrivateMB, $freeRam, $Report.CloudOnly, $Report.ConnectionTimeouts,
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

function Get-RamMetrics {
    <#
        Free and total physical RAM in MB. The free-ram verdict is what caught po-2023
        (0.7 GB free) while maxPrivMB stayed blind to it: the seats that suffer are the
        ones whose TOTAL host memory ate the machine, with no single fat host.
        Non-Windows / CIM failure returns null fields: unknown RAM judges nothing.
    #>
    $freeKB = $null
    $totalKB = $null
    try {
        $os = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
        $freeKB = $os.FreePhysicalMemory
        $totalKB = $os.TotalVisibleMemorySize
    } catch {
        return [pscustomobject]@{ FreeRamMB = $null; TotalRamMB = $null }
    }
    $freeMB = $null
    $totalMB = $null
    if ($null -ne $freeKB) { $freeMB = [math]::Round([double]$freeKB / 1024, 0) }
    if ($null -ne $totalKB) { $totalMB = [math]::Round([double]$totalKB / 1024, 0) }
    return [pscustomobject]@{ FreeRamMB = $freeMB; TotalRamMB = $totalMB }
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
            -RamMetrics (Get-RamMetrics) `
            -HoursObserved $hoursObserved `
            -MaxPrivateMBThreshold $MaxPrivateMBThreshold `
            -CloudOnlyPerHourThreshold $CloudOnlyPerHourThreshold `
            -ConnTimeoutPerHourThreshold $ConnTimeoutPerHourThreshold `
            -FreeRamWarnPercent $FreeRamWarnPercent `
            -FreeRamWarnFloorMB $FreeRamWarnFloorMB

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
