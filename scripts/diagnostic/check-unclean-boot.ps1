<#
.SYNOPSIS
    Detect an unreported crash (unclean shutdown) on this seat — po-2028 crash guard.

.DESCRIPTION
    Mandat user (06/11, dashboard ai-01|Maintenance): every seat crash must produce a
    forensic AND a guard. On po-2028 the night of 05->06/11 the machine crashed at
    07:08 (Kernel-Power 41, no BugCheck = power loss / hard hang), auto-rebooted at
    09:23, and the crash went UNNOTICED by the lane until the user woke it — the
    executor cycle never looked at the boot/crash state, so a crash-restart read as a
    normal session start.

    This probe closes that gap. It scans the System event log for unclean-shutdown
    markers (Event 41 Kernel-Power "restarted without cleanly shutting down", Event
    6008 EventLog "previous shutdown was unexpected") and reports the MOST RECENT one
    that has not yet been acknowledged by a previous pre-flight run.

    Why "most recent unacknowledged" and not "did THIS boot follow a crash": a crash
    is frequently followed by a CLEAN manual reboot (the user power-cycles the box)
    before the next executor cycle runs. Anchoring only on the current boot would miss
    exactly those crashes — measured on po-2028 06/11: crash 07:08 -> auto-boot 09:23
    (Event 41) -> clean manual reboot 09:52 (Event 1074). The 09:23 crash must still be
    reported even though the CURRENT boot (09:52) is clean.

    Acknowledgement is a machine-local marker under %LOCALAPPDATA%\claude-executor
    (outside any repo, outside ~/.claude — sanctuary rule), holding the timestamp of the
    last crash the pre-flight has relayed. A crash already acknowledged is not
    re-reported; a NEW crash (newer than the marker) is.

    Exit contract (instrument, same posture as measure-rsm-health.ps1):
      0 = no unacknowledged crash — no noise.
      2 = a crash has not been reported yet — the caller relays [WARN] (forensic).
      1 = instrument error (event log unreadable) — state UNKNOWN, relay [WARN].

    Non-blocking by design: a crash is a FACT to surface, not a reason to stop the
    cycle. The guard makes the crash VISIBLE at the next pre-flight instead of waiting
    for the user to notice a stalled lane.

.PARAMETER LookbackDays
    How far back to scan for crash markers (default 3). Bounds the search so a very old,
    already-acknowledged crash cannot re-alert.

.PARAMETER Acknowledge
    Record the most recent crash marker as reported. The pre-flight calls this AFTER it
    has actually relayed the [WARN]; a failed relay must NOT acknowledge, so the crash
    is retried next cycle (visible beats deduplicated, review #4388 r3).

.PARAMETER Quiet
    Suppress the human-readable line (only the exit code matters).

.EXAMPLE
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/diagnostic/check-unclean-boot.ps1
    # exit 2 + "[UNCLEAN-BOOT] ..." line when an unacknowledged crash exists.

.EXAMPLE
    ... -Acknowledge
    # after the pre-flight relayed the WARN, mark the crash as reported.
#>
param(
    [int]$LookbackDays = 3,
    [switch]$Acknowledge,
    [switch]$Quiet
)

$ErrorActionPreference = 'Stop'

function Get-CrashStateDir {
    $base = $env:LOCALAPPDATA
    if (-not $base) { $base = [System.IO.Path]::GetTempPath() }
    return (Join-Path $base 'claude-executor')
}

function Out-Line([string]$s) { if (-not $Quiet) { Write-Output $s } }

try {
    $stateDir = Get-CrashStateDir
    $machineId = ($env:COMPUTERNAME).ToLowerInvariant()
    $ackFile = Join-Path $stateDir ('unclean-boot-ack-{0}.txt' -f $machineId)

    $since = (Get-Date).AddDays(-[Math]::Abs($LookbackDays))

    # Newest unclean-shutdown marker in the window. 41 (Kernel-Power) and 6008
    # (EventLog) are both written at the startup that FOLLOWS the crash.
    $latest = Get-WinEvent -FilterHashtable @{ LogName = 'System'; Id = 41, 6008; StartTime = $since } -ErrorAction Stop |
        Sort-Object TimeCreated -Descending |
        Select-Object -First 1

    if (-not $latest) {
        Out-Line "[UNCLEAN-BOOT] OK - no unclean-shutdown marker in the last $LookbackDays day(s)."
        exit 0
    }

    # Last acknowledged crash timestamp (if any).
    $acked = $null
    if (Test-Path $ackFile) {
        $raw = (Get-Content $ackFile -Raw -ErrorAction SilentlyContinue)
        if ($raw) { $parsed = [DateTime]::MinValue; if ([DateTime]::TryParse($raw.Trim(), [ref]$parsed)) { $acked = $parsed } }
    }

    if ($Acknowledge) {
        if (-not (Test-Path $stateDir)) { New-Item -ItemType Directory -Path $stateDir -Force | Out-Null }
        [System.IO.File]::WriteAllText($ackFile, $latest.TimeCreated.ToString('o'), [System.Text.UTF8Encoding]::new($false))
        Out-Line "[UNCLEAN-BOOT] ACK - recorded crash $($latest.TimeCreated.ToString('yyyy-MM-dd HH:mm:ss')) as reported."
        exit 0
    }

    if ($acked -and $latest.TimeCreated -le $acked) {
        Out-Line "[UNCLEAN-BOOT] OK - latest crash marker ($($latest.TimeCreated.ToString('yyyy-MM-dd HH:mm:ss'))) already reported."
        exit 0
    }

    $crashNote = if ($latest.Id -eq 41) { 'Kernel-Power 41 (power loss / hard hang, no clean shutdown)' } else { 'EventLog 6008 (previous shutdown was unexpected)' }
    $boot = (Get-CimInstance Win32_OperatingSystem).LastBootUpTime
    Out-Line "[UNCLEAN-BOOT] CRASH - unreported unclean shutdown: $crashNote logged $($latest.TimeCreated.ToString('yyyy-MM-dd HH:mm:ss')). Current boot $($boot.ToString('yyyy-MM-dd HH:mm:ss')). This seat crashed; the previous cycle may not have ended cleanly. Relay [WARN] (forensic + confirm cadence survived), then re-run with -Acknowledge."
    exit 2
} catch {
    Out-Line "[UNCLEAN-BOOT] INSTRUMENT-ERROR - could not read crash state: $($_.Exception.Message). Crash state UNKNOWN this cycle; relay [WARN]."
    exit 1
}
