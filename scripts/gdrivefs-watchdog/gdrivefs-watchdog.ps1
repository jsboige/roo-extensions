<#
.SYNOPSIS
    Watchdog for GoogleDriveFS.exe (silent-exit #2875 + hung-process #2933 + cooldown C2).

.DESCRIPTION
    GoogleDriveFS.exe dies silently with NO auto-restart: the HKCU Run entry
    fires only at interactive logon, not after a crash. When it dies, the host
    loses 2-way comm with the RooSync fleet (dashboard reads/writes hit local
    disk only, MCP roosync_dashboard returns "success" while nothing syncs),
    and the fleet reports the host "dead/non-responsive" for hours/days.

    This watchdog polls every ~15 min via scheduled task:
      C1 (silent-exit) : is GoogleDriveFS.exe running? If not → relaunch.
      C2 (hung-process): if it IS running but unresponsive (CPU stuck at 0%
                          for a sample window while sync is expected) → relaunch.
      C3 (cooldown)    : after N consecutive relaunch failures, suppress further
                          attempts for a cooldown window and emit an Error-level
                          alert. Re-arms on next successful detection.

    Designed to run as a short-lived scheduled task every ~15 min.

    Limitation: if the account token was dropped (not just the process), a clean
    relaunch may require a one-time interactive re-auth (WebView2 prompt). The
    watchdog restores the process; the common case (process dead, token still
    cached) restores comm. Persistent auth loss still needs the user.

.PARAMETER Mode
    'poll' (default): run one shot and exit (relaunches if dead/hung).
    'dry-run': probe only, never relaunch, never touch state file.

.PARAMETER LogDir
    Directory for logs and state file. Default: <repo-root>\outputs\gdrivefs-watchdog

.PARAMETER LogRetentionDays
    Log files older than this are pruned each run. Default: 14.

.PARAMETER HungSampleSeconds
    C1 — Window (seconds) over which to sample CPU delta for hung-process detection.
    0 disables C1. Default: 30.

.PARAMETER HungCpuPctLow
    C1 — Below this CPU% delta over the window → considered hung (idle/no I/O).
    Default: 0.5.

.PARAMETER MaxConsecutiveFailures
    C2 — After this many consecutive relaunch failures without recovery, enter
    cooldown. Default: 3.

.PARAMETER CooldownHours
    C2 — Hours to suppress further relaunch attempts after the failure threshold.
    Default: 24.

.EXAMPLE
    .\gdrivefs-watchdog.ps1
    .\gdrivefs-watchdog.ps1 -Mode dry-run
    .\gdrivefs-watchdog.ps1 -LogDir D:\tmp\gdrivefs-watchdog
#>

param(
    [ValidateSet('poll','dry-run')]
    [string]$Mode = 'poll',
    [string]$LogDir,
    [int]$LogRetentionDays = 14,
    [int]$HungSampleSeconds = 30,
    [double]$HungCpuPctLow = 0.5,
    [int]$MaxConsecutiveFailures = 3,
    [int]$CooldownHours = 24
)

$ErrorActionPreference = 'Continue'
$script:repairs = @()
$script:alerts  = @()

# ---------- paths ----------
$scriptDir = Split-Path $MyInvocation.MyCommand.Path -Parent
# Repo root = two levels above scripts/gdrivefs-watchdog/.
$repoRoot  = Split-Path (Split-Path $scriptDir -Parent) -Parent
if (-not $LogDir) { $LogDir = Join-Path $repoRoot 'outputs\gdrivefs-watchdog' }

if (-not (Test-Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
}
$logFile  = Join-Path $LogDir ("watchdog-{0}.log" -f (Get-Date -Format 'yyyyMMdd'))
$stateFile = Join-Path $LogDir 'watchdog-state.json'

# ---------- logging ----------
function Write-Log {
    param([string]$Level, [string]$Message)
    $ts = Get-Date -Format 'yyyy-MM-ddTHH:mm:sszzz'
    $line = "{0} [{1,-5}] {2}" -f $ts, $Level, $Message
    Add-Content -Path $logFile -Value $line -Encoding utf8
    Write-Host $line
}

# ---------- event log ----------
function Write-WatchdogEvent {
    param([int]$EventId, [string]$EntryType, [string]$Message)
    try {
        $src = 'GDriveFS-Watchdog'
        if (-not [System.Diagnostics.EventLog]::SourceExists($src)) {
            New-EventLog -LogName Application -Source $src -ErrorAction SilentlyContinue
        }
        Write-EventLog -LogName Application -Source $src -EventId $EventId -EntryType $EntryType -Message $Message -ErrorAction SilentlyContinue
    } catch {}
}

# ---------- state file (C2) ----------
function Read-WatchdogState {
    if (-not (Test-Path $stateFile)) {
        return @{
            consecutive_relaunch_failures = 0
            last_relaunch_attempt         = $null
            last_alert_at                 = $null
            cooldown_until                = $null
        }
    }
    try {
        $raw = Get-Content -Path $stateFile -Raw -ErrorAction Stop
        $obj = $raw | ConvertFrom-Json -ErrorAction Stop
        return @{
            consecutive_relaunch_failures = [int]$obj.consecutive_relaunch_failures
            last_relaunch_attempt         = $obj.last_relaunch_attempt
            last_alert_at                 = $obj.last_alert_at
            cooldown_until                = $obj.cooldown_until
        }
    } catch {
        Write-Log 'WARN' "Could not parse state file ($stateFile) — starting fresh. ($($_.Exception.Message))"
        return @{
            consecutive_relaunch_failures = 0
            last_relaunch_attempt         = $null
            last_alert_at                 = $null
            cooldown_until                = $null
        }
    }
}

function Save-WatchdogState {
    param($State)
    if ($Mode -eq 'dry-run') { return }   # dry-run never mutates state
    try {
        $json = $State | ConvertTo-Json -Depth 4 -ErrorAction Stop
        [System.IO.File]::WriteAllText($stateFile, $json, [System.Text.UTF8Encoding]::new($false))
    } catch {
        Write-Log 'WARN' "Could not write state file ($stateFile): $($_.Exception.Message)"
    }
}

# ---------- locate the GDriveFS binary ----------
# The versioned dir (e.g. 128.0.0.0, 127.0.1.0) changes on every Drive update, so
# we never hardcode it. Prefer the HKCU Run entry (canonical launch command),
# then fall back to the highest versioned dir under Program Files.
function Resolve-GDriveFSPath {
    # 1. HKCU Run entry (authoritative — matches how Windows normally starts it).
    try {
        $runKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
        $entry = (Get-ItemProperty -Path $runKey -Name 'GoogleDriveFS' -ErrorAction SilentlyContinue).GoogleDriveFS
        if ($entry) {
            # Entry is like:  "C:\...\128.0.0.0\GoogleDriveFS.exe" --startup_mode
            if ($entry -match '"([^"]+GoogleDriveFS\.exe)"') { return $matches[1] }
            if ($entry -match '^([^\s]+GoogleDriveFS\.exe)')  { return $matches[1] }
        }
    } catch {}

    # 2. Glob versioned dirs, pick the highest (sortable as version).
    $base = "$env:ProgramFiles\Google\Drive File Stream"
    if (Test-Path $base) {
        $candidates = Get-ChildItem -Path $base -Directory -ErrorAction SilentlyContinue |
            Where-Object { Test-Path (Join-Path $_.FullName 'GoogleDriveFS.exe') }
        if ($candidates) {
            $latest = $candidates | Sort-Object -Property Name -Descending | Select-Object -First 1
            return (Join-Path $latest.FullName 'GoogleDriveFS.exe')
        }
    }
    return $null
}

# ---------- liveness ----------
function Test-GDriveFSAlive {
    # Healthy Drive File Stream runs >=1 GoogleDriveFS.exe process.
    $procs = Get-Process -Name 'GoogleDriveFS' -ErrorAction SilentlyContinue
    if ($procs -and @($procs).Count -ge 1) {
        return @{ Alive = $true; Pids = (@($procs).Id -join ',') }
    }
    return @{ Alive = $false; Pids = '' }
}

# ---------- C1: hung-process detection ----------
# Sample cumulative CPU across all GoogleDriveFS processes at T0 and T0+window,
# compute delta% per process. If ALL processes are below the low threshold, the
# process is alive but unresponsive (no I/O / no heartbeat) → treat as hung.
# Cores is used to convert "CPU seconds" into a percent-of-one-core.
function Test-GDriveFSHung {
    param([int]$WindowSeconds, [double]$LowPct, [switch]$DryRun)

    if ($WindowSeconds -le 0) {
        return @{ Hung = $false; Reason = 'c1-disabled' }
    }

    $cores  = [Environment]::ProcessorCount
    if ($cores -lt 1) { $cores = 1 }

    if ($DryRun) {
        Write-Log 'INFO' "DRY-RUN: would sample GoogleDriveFS CPU over ${WindowSeconds}s (cores=$cores, low=${LowPct}%)"
        return @{ Hung = $false; Reason = 'dry-run' }
    }

    $procs = @(Get-Process -Name 'GoogleDriveFS' -ErrorAction SilentlyContinue)
    if (-not $procs -or $procs.Count -eq 0) {
        return @{ Hung = $false; Reason = 'no-procs' }
    }

    $t0 = @{}
    foreach ($p in $procs) {
        $t0[$p.Id] = [double]$p.CPU
    }

    Write-Log 'INFO' "C1 sample: tracking $($procs.Count) process(es) for ${WindowSeconds}s"
    Start-Sleep -Seconds $WindowSeconds

    $procs2 = @(Get-Process -Name 'GoogleDriveFS' -ErrorAction SilentlyContinue)
    if (-not $procs2 -or $procs2.Count -eq 0) {
        return @{ Hung = $false; Reason = 'no-procs-after-sample' }
    }

    $below = 0
    foreach ($p2 in $procs2) {
        $cpu0 = if ($t0.ContainsKey($p2.Id)) { $t0[$p2.Id] } else { 0 }
        $delta = [double]$p2.CPU - $cpu0
        $pct   = ($delta / $WindowSeconds) * 100.0 / $cores
        if ($pct -lt $LowPct) {
            $below++
        }
        Write-Log 'INFO' "C1 sample pid=$($p2.Id) cpu_delta=${delta}s → ${pct}% (low=${LowPct}%)"
    }

    if ($below -eq $procs2.Count) {
        return @{ Hung = $true; Reason = "all-$($procs2.Count)-procs-below-${LowPct}%"}
    }
    return @{ Hung = $false; Reason = 'responsive' }
}

# ---------- C2: cooldown gate ----------
function Test-CooldownActive {
    param($State)
    if (-not $State.cooldown_until) { return $false }
    $until = $State.cooldown_until
    if ($until -is [string]) {
        try { $until = [datetime]::Parse($until) } catch { return $false }
    }
    if ($until -is [datetime]) {
        return ($until -gt (Get-Date))
    }
    return $false
}

# ---------- relaunch ----------
function Invoke-RelaunchGDriveFS {
    param([string]$BinaryPath)
    if ($Mode -eq 'dry-run') {
        Write-Log 'INFO' "DRY-RUN: would Start-Process '$BinaryPath' --startup_mode"
        return
    }
    Write-Log 'WARN' "GoogleDriveFS.exe absent — relaunching (user context, --startup_mode)"
    try {
        Start-Process -FilePath $BinaryPath -ArgumentList '--startup_mode' -ErrorAction Stop
        $script:repairs += 'gdrivefs-relaunch'
        Write-Log 'INFO' "Start-Process issued for $BinaryPath — waiting 20s for core_controller init"
        Start-Sleep -Seconds 20
    } catch {
        Write-Log 'ERROR' "Start-Process failed: $($_.Exception.Message)"
        $script:alerts += "relaunch-failed: $($_.Exception.Message)"
    }
}

# ---------- main ----------
Write-Log 'INFO' "GDriveFS watchdog start (mode=$Mode, host=$env:COMPUTERNAME, user=$env:USERNAME, hungWindowSec=$HungSampleSeconds)"

# Load state (C2)
$state = Read-WatchdogState
if ($Mode -ne 'dry-run') {
    Write-Log 'INFO' "C2 state: consecutive_failures=$($state.consecutive_relaunch_failures), cooldown_until=$($state.cooldown_until)"
}

$binary = Resolve-GDriveFSPath
if (-not $binary -or -not (Test-Path $binary)) {
    Write-Log 'ERROR' "GDriveFS binary not found (HKCU Run + Program Files glob both empty). Cannot relaunch."
    $script:alerts += 'binary-not-found'
} else {
    $needsRelaunch = $false
    $reason        = ''

    # C0: process existence check (existing behavior)
    $live = Test-GDriveFSAlive
    if (-not $live.Alive) {
        $needsRelaunch = $true
        $reason        = 'process-absent'
        Write-Log 'FAIL' "GoogleDriveFS.exe NOT running — triggering relaunch"
    } else {
        Write-Log 'OK' "GoogleDriveFS.exe alive (pids=$($live.Pids)) — checking health (C1)"

        # C1: hung-process detection (only if process is alive)
        $hung = Test-GDriveFSHung -WindowSeconds $HungSampleSeconds -LowPct $HungCpuPctLow -DryRun:($Mode -eq 'dry-run')
        if ($hung.Hung) {
            $needsRelaunch = $true
            $reason        = "hung: $($hung.Reason)"
            Write-Log 'FAIL' "GoogleDriveFS.exe hung ($($hung.Reason)) — triggering relaunch"
        } else {
            Write-Log 'OK' "GoogleDriveFS.exe healthy (C1 verdict: $($hung.Reason))"
        }
    }

    if ($needsRelaunch) {
        # C2: cooldown gate — if we're in cooldown, log + alert, skip relaunch
        if (Test-CooldownActive -State $state) {
            $msg = "Cooldown active until $($state.cooldown_until) — SKIPPING relaunch (reason=$reason). Manual intervention or next AtLogOn trigger required."
            Write-Log 'WARN' $msg
            $script:alerts += "cooldown-skip: $reason"
        } else {
            Invoke-RelaunchGDriveFS -BinaryPath $binary

            # Re-check after the wait.
            $after = Test-GDriveFSAlive
            if ($after.Alive) {
                Write-Log 'OK' "GoogleDriveFS.exe recovered after relaunch (pids=$($after.Pids))"
                # C2: success → reset failure counter
                if ($Mode -ne 'dry-run') {
                    $state.consecutive_relaunch_failures = 0
                    $state.cooldown_until                = $null
                    Save-WatchdogState -State $state
                }
            } else {
                Write-Log 'WARN' "GoogleDriveFS.exe still absent 20s after relaunch — may need one-time interactive re-auth (WebView2), or binary failed to init. See GDriveFS logs."
                $script:alerts += 'still-absent-after-relaunch'

                # C2: increment failure counter, escalate if over threshold
                if ($Mode -ne 'dry-run') {
                    $state.consecutive_relaunch_failures = $state.consecutive_relaunch_failures + 1
                    $state.last_relaunch_attempt         = (Get-Date).ToString('o')

                    if ($state.consecutive_relaunch_failures -ge $MaxConsecutiveFailures) {
                        $state.cooldown_until = (Get-Date).AddHours($CooldownHours).ToString('o')
                        $state.last_alert_at   = (Get-Date).ToString('o')
                        Save-WatchdogState -State $state
                        $escMsg = "GDriveFS watchdog ESCALATION: $($state.consecutive_relaunch_failures) consecutive relaunch failures. Cooldown engaged until $((Get-Date).AddHours($CooldownHours)). Manual intervention required."
                        Write-Log 'ERROR' $escMsg
                        Write-WatchdogEvent -EventId 2001 -EntryType Error -Message $escMsg
                        $script:alerts += "escalation: cooldown-until $($state.cooldown_until)"
                    } else {
                        Save-WatchdogState -State $state
                    }
                }
            }
        }
    } else {
        # C2: alive + healthy → reset failure counter (catch-up recovery)
        if ($Mode -ne 'dry-run' -and $state.consecutive_relaunch_failures -gt 0) {
            Write-Log 'INFO' "C2 reset: GDriveFS healthy → clearing consecutive_relaunch_failures=$($state.consecutive_relaunch_failures)"
            $state.consecutive_relaunch_failures = 0
            $state.cooldown_until                = $null
            Save-WatchdogState -State $state
        }
    }
}

# ---------- summary + event log ----------
if ($script:repairs.Count -gt 0) {
    $summary = "GDriveFS watchdog repaired: $($script:repairs -join ', ')"
    Write-Log 'INFO' $summary
    Write-WatchdogEvent -EventId 1000 -EntryType Information -Message $summary
}

if ($script:alerts.Count -gt 0) {
    $alertMsg = "GDriveFS watchdog ALERT: $($script:alerts -join '; ')"
    Write-Log 'ALERT' $alertMsg
    Write-WatchdogEvent -EventId 2000 -EntryType Error -Message $alertMsg
}

# ---------- log rotation ----------
try {
    Get-ChildItem -Path $LogDir -Filter 'watchdog-*.log' -ErrorAction SilentlyContinue |
        Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-$LogRetentionDays) } |
        Remove-Item -Force -ErrorAction SilentlyContinue
} catch {}

# Exit code: 0 if GDriveFS is alive at end (or dry-run), 1 if still dead/hung.
$final = Test-GDriveFSAlive
if ($Mode -eq 'dry-run' -or $final.Alive) { exit 0 } else { exit 1 }
