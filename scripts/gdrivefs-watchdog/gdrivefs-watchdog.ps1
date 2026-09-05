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
      C0 (silent-exit) : is GoogleDriveFS.exe running? If not → relaunch.
      C1 (hung-process): if it IS running, can the configured DriveFS mount serve
                          a bounded metadata request? Timeout/error → relaunch.
                          Enabled by default; succeeds even when DriveFS is idle.
      C2 (cooldown)    : after N consecutive relaunch failures, suppress further
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

.PARAMETER MountPath
    C1 — DriveFS mount to probe. Default: G:\.

.PARAMETER MountProbeTimeoutSeconds
    C1 — Maximum seconds allowed for a mount metadata request. Default: 5.
    0 disables C1 for recovery or hosts without a mounted drive.

.PARAMETER MaxConsecutiveFailures
    C2 — After this many consecutive relaunch failures without recovery, enter
    cooldown. Default: 3.

.PARAMETER CooldownHours
    C2 — Hours to suppress further relaunch attempts after the failure threshold.
    Default: 24.

.PARAMETER StartupGraceSeconds
    Guard (#3466) — never kill an instance younger than this. Derived from the
    observed GoogleDriveFS mount init time (~11-20 min on ai-01, 2026-09-05).
    An instance still inside this window when the C1 probe fails is a relaunch
    mid-init, not a genuine hang; the watchdog leaves it alone and defers its
    verdict. The post-relaunch verification window is this factor, not a fixed
    90s constant. Default: 1200 (20 min).

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
    [string]$MountPath = 'G:\',
    [ValidateRange(0, 60)]
    [int]$MountProbeTimeoutSeconds = 5,
    [int]$MaxConsecutiveFailures = 3,
    [int]$CooldownHours = 24,
    [ValidateRange(0, 86400)]
    [int]$StartupGraceSeconds = 1200
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

# ---------- C1: positive mount liveness probe ----------
# Probe a positive signal from DriveFS: a metadata request against the configured
# mount must complete within a bounded timeout. Unlike CPU sampling, this succeeds
# when DriveFS is idle and fails when core_controller stops serving filesystem I/O.
function Test-GDriveFSMountLive {
    param([string]$Path, [int]$TimeoutSeconds)

    if ($TimeoutSeconds -le 0) {
        return @{ Live = $true; Reason = 'c1-disabled' }
    }

    $job = $null
    try {
        $job = Start-Job -ScriptBlock {
            param($ProbePath)
            $item = Get-Item -LiteralPath $ProbePath -Force -ErrorAction Stop
            [pscustomobject]@{
                FullName    = $item.FullName
                PSIsContainer = $item.PSIsContainer
            }
        } -ArgumentList $Path

        if (-not (Wait-Job -Job $job -Timeout $TimeoutSeconds)) {
            return @{ Live = $false; Reason = "mount-probe-timeout-${TimeoutSeconds}s" }
        }

        $probeError = @()
        $result = Receive-Job -Job $job -ErrorAction SilentlyContinue -ErrorVariable probeError
        if ($job.State -eq 'Completed' -and $result -and $result.PSIsContainer -and $probeError.Count -eq 0) {
            return @{ Live = $true; Reason = 'mount-stat-ok' }
        }

        $detail = if ($job.ChildJobs[0].JobStateInfo.Reason) {
            $job.ChildJobs[0].JobStateInfo.Reason.Message
        } elseif ($probeError.Count -gt 0) {
            $probeError[0].Exception.Message
        } else {
            "job-state-$($job.State)"
        }
        return @{ Live = $false; Reason = "mount-probe-error: $detail" }
    } catch {
        return @{ Live = $false; Reason = "mount-probe-error: $($_.Exception.Message)" }
    } finally {
        if ($job) {
            Stop-Job -Job $job -ErrorAction SilentlyContinue
            Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
        }
    }
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

# ---------- startup grace (A0.1/A0.2, #3466) ----------
# GoogleDriveFS mount init takes ~11-20 min on slow hosts (measured ai-01
# 2026-09-05, #3466). A watchdog that kills an instance younger than the
# observed init time dark-drops a relaunch that was still completing, and its
# next tick kills the instance the previous tick launched. Anchor the grace on
# (a) the process StartTime (host-native / manually-started instances) and (b)
# the last_relaunch_attempt field we already persist but never read (instances
# the watchdog itself launched). This is the reader the #3466 issue calls for.
function Test-IsInStartupGrace {
    param(
        [datetime]$Now,
        [object[]]$Processes,
        [object]$LastRelaunchAttempt,
        [int]$GraceSeconds
    )
    if ($GraceSeconds -le 0) { return $false }

    # (a) instance age — youngest process StartTime. A young process that fails
    #     the C1 mount probe is a relaunch mid-init, not a genuine hang.
    if ($Processes -and @($Processes).Count -gt 0) {
        $youngestStart = ($Processes | Measure-Object -Property StartTime -Maximum).Maximum
        if ($youngestStart -and (($Now - $youngestStart).TotalSeconds -lt $GraceSeconds)) {
            return $true
        }
    }

    # (b) watchdog's own relaunch timestamp (persisted, never read until now).
    if ($LastRelaunchAttempt) {
        try {
            $lastAt = if ($LastRelaunchAttempt -is [datetime]) {
                $LastRelaunchAttempt
            } else {
                [datetime]::Parse([string]$LastRelaunchAttempt)
            }
            if (($Now - $lastAt).TotalSeconds -lt $GraceSeconds) {
                return $true
            }
        } catch {}
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
    # DriveFS is single-instance: Start-Process while a wedged instance is still alive
    # is a no-op (observed 2026-08-06 on ai-01: relaunch "issued", same PIDs survived,
    # mount stayed dead). Kill any existing instance first — no-op in the C0
    # (process-absent) case, required in the C1 (hung) case.
    $existing = Get-Process -Name 'GoogleDriveFS' -ErrorAction SilentlyContinue
    if ($existing) {
        Write-Log 'WARN' "GoogleDriveFS.exe alive but unhealthy — killing wedged instance (pids=$($existing.Id -join ',')) before relaunch"
        try {
            $existing | Stop-Process -Force -ErrorAction Stop
        } catch {
            Write-Log 'WARN' "Stop-Process reported: $($_.Exception.Message) — continuing with relaunch"
        }
        Start-Sleep -Seconds 3
    }
    Write-Log 'WARN' "Relaunching GoogleDriveFS.exe (user context, --startup_mode)"
    try {
        Start-Process -FilePath $BinaryPath -ArgumentList '--startup_mode' -ErrorAction Stop
        $script:repairs += 'gdrivefs-relaunch'
        # Mount init takes far longer than a bounded probe on slow hosts (measured
        # ~11-20 min on ai-01, 2026-09-05, #3466). We do NOT wait for it here: the
        # caller defers the verdict to the startup-grace window (StartupGraceSeconds),
        # so a relaunch still in init is never declared failed or re-killed by the
        # next poll. A bounded probe runs immediately for fast-success feedback.
        Write-Log 'INFO' "Start-Process issued for $BinaryPath — verdict deferred to startup grace window ($StartupGraceSeconds s) pending core_controller init"
        $script:probeAfterLaunch = Test-GDriveFSMountLive -Path $MountPath -TimeoutSeconds $MountProbeTimeoutSeconds
    } catch {
        Write-Log 'ERROR' "Start-Process failed: $($_.Exception.Message)"
        $script:alerts += "relaunch-failed: $($_.Exception.Message)"
    }
}

# ---------- main ----------
Write-Log 'INFO' "GDriveFS watchdog start (mode=$Mode, host=$env:COMPUTERNAME, user=$env:USERNAME, mount=$MountPath, mountProbeTimeoutSec=$MountProbeTimeoutSeconds)"

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

        # C1: positive mount liveness probe (only if process is alive)
        $mountProbe = Test-GDriveFSMountLive -Path $MountPath -TimeoutSeconds $MountProbeTimeoutSeconds
        if (-not $mountProbe.Live) {
            $needsRelaunch = $true
            $reason        = "hung: $($mountProbe.Reason)"
            Write-Log 'FAIL' "GoogleDriveFS.exe alive but mount '$MountPath' is unresponsive ($($mountProbe.Reason)) — triggering relaunch"
        } else {
            Write-Log 'OK' "GoogleDriveFS.exe healthy (C1 verdict: $($mountProbe.Reason), mount=$MountPath)"
        }
    }

    if ($needsRelaunch) {
        # C2: cooldown gate — if we're in cooldown, log + alert, skip relaunch
        if (Test-CooldownActive -State $state) {
            $msg = "Cooldown active until $($state.cooldown_until) — SKIPPING relaunch (reason=$reason). Manual intervention or next AtLogOn trigger required."
            Write-Log 'WARN' $msg
            $script:alerts += "cooldown-skip: $reason"
        } else {
            # A0.1 (#3466): never kill an instance younger than the observed init
            # time. A C1-hung instance still inside its startup-grace window is a
            # relaunch mid-init (core_controller), not a genuine hang — leave it
            # alone. (C0, process absent, has nothing to protect, so grace skips.)
            $existingProcs = if ($live.Alive) { Get-Process -Name 'GoogleDriveFS' -ErrorAction SilentlyContinue } else { $null }
            $inGrace = $false
            if ($live.Alive) {
                $inGrace = Test-IsInStartupGrace -Now (Get-Date) -Processes $existingProcs -LastRelaunchAttempt $state.last_relaunch_attempt -GraceSeconds $StartupGraceSeconds
            }

            if ($inGrace) {
                Write-Log 'INFO' "Suppressing relaunch — GDriveFS instance younger than startup grace (${StartupGraceSeconds}s), likely still initializing (reason=$reason). No kill, no failed-cycle count."
            } else {
                # A0.2 (#3466): a relaunch cycle is judged by the measured grace
                # window, never a 90s constant. If the prior relaunch's grace already
                # elapsed and the instance is still missing/hung, THIS cycle failed —
                # count it (C2). Otherwise the verdict is deferred below.
                $cycleFailed = $false
                if ($state.last_relaunch_attempt) {
                    try { $lastAt = [datetime]::Parse([string]$state.last_relaunch_attempt) } catch { $lastAt = $null }
                    if ($lastAt -and ((Get-Date) - $lastAt).TotalSeconds -ge $StartupGraceSeconds) {
                        $cycleFailed = $true
                    }
                }
                if ($Mode -ne 'dry-run' -and $cycleFailed) {
                    $state.consecutive_relaunch_failures = $state.consecutive_relaunch_failures + 1
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

                $state.last_relaunch_attempt = (Get-Date).ToString('o')
                if ($Mode -ne 'dry-run') { Save-WatchdogState -State $state }

                Invoke-RelaunchGDriveFS -BinaryPath $binary

                # Immediate process + liveness check (bounded). If not yet healthy,
                # defer the verdict to the grace window — the mount may still be in init.
                $after = Test-GDriveFSAlive
                $afterProbe = if ($after.Alive) {
                    Test-GDriveFSMountLive -Path $MountPath -TimeoutSeconds $MountProbeTimeoutSeconds
                } else {
                    @{ Live = $false; Reason = 'process-absent-after-relaunch' }
                }
                if ($after.Alive -and $afterProbe.Live) {
                    Write-Log 'OK' "GoogleDriveFS.exe recovered after relaunch (pids=$($after.Pids), C1=$($afterProbe.Reason))"
                    # C2: success → reset failure counter
                    if ($Mode -ne 'dry-run') {
                        $state.consecutive_relaunch_failures = 0
                        $state.cooldown_until                = $null
                        Save-WatchdogState -State $state
                    }
                } else {
                    # A0.2 (#3466): deferred verdict — a relaunch inside the grace
                    # window is not a failure yet. The next poll that sees it still
                    # hung AFTER grace elapses counts the cycle as failed (above).
                    Write-Log 'INFO' "Relaunch issued but instance not yet healthy (processAlive=$($after.Alive), C1=$($afterProbe.Reason)). Deferring verdict until startup grace (${StartupGraceSeconds}s) elapses — possible core_controller init."
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

# Exit code: 0 if GDriveFS is alive and its mount responds at end (or dry-run, or
# still inside its startup-grace window — an in-init instance is not a failure),
# 1 otherwise.
$final = Test-GDriveFSAlive
$finalProbe = if ($final.Alive) {
    Test-GDriveFSMountLive -Path $MountPath -TimeoutSeconds $MountProbeTimeoutSeconds
} else {
    @{ Live = $false }
}
$finalGrace = $false
if ($final.Alive) {
    $finalProcs = Get-Process -Name 'GoogleDriveFS' -ErrorAction SilentlyContinue
    $finalGrace = Test-IsInStartupGrace -Now (Get-Date) -Processes $finalProcs -LastRelaunchAttempt $state.last_relaunch_attempt -GraceSeconds $StartupGraceSeconds
}
if ($Mode -eq 'dry-run' -or ($final.Alive -and $finalProbe.Live) -or $finalGrace) { exit 0 } else { exit 1 }
