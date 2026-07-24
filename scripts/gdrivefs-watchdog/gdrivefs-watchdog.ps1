<#
.SYNOPSIS
    Watchdog for GoogleDriveFS.exe (silent-exit recurrence #2875).

.DESCRIPTION
    GoogleDriveFS.exe dies silently with NO auto-restart: the HKCU Run entry
    fires only at interactive logon, not after a crash. When it dies, the host
    loses 2-way comm with the RooSync fleet (dashboard reads/writes hit local
    disk only, MCP roosync_dashboard returns "success" while nothing syncs),
    and the fleet reports the host "dead/non-responsive" for hours/days.

    This watchdog polls: is GoogleDriveFS.exe running? If not → relaunch it in
    the user context (same launch command as the HKCU Run entry) and log it.
    Designed to run as a short-lived scheduled task every ~15 min.

    Limitation: if the account token was dropped (not just the process), a clean
    relaunch may require a one-time interactive re-auth (WebView2 prompt). The
    watchdog restores the process; the common case (process dead, token still
    cached) restores comm. Persistent auth loss still needs the user.

.PARAMETER Mode
    'poll' (default): run one shot and exit (relaunches if dead).
    'dry-run': probe only, never relaunch.

.PARAMETER LogDir
    Directory for logs. Default: <repo-root>\outputs\gdrivefs-watchdog

.PARAMETER LogRetentionDays
    Log files older than this are pruned each run. Default: 14.

.EXAMPLE
    .\gdrivefs-watchdog.ps1
    .\gdrivefs-watchdog.ps1 -Mode dry-run
#>

param(
    [ValidateSet('poll','dry-run')]
    [string]$Mode = 'poll',
    [string]$LogDir,
    [int]$LogRetentionDays = 14
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
$logFile = Join-Path $LogDir ("watchdog-{0}.log" -f (Get-Date -Format 'yyyyMMdd'))

# ---------- logging ----------
function Write-Log {
    param([string]$Level, [string]$Message)
    $ts = Get-Date -Format 'yyyy-MM-ddTHH:mm:sszzz'
    $line = "{0} [{1,-5}] {2}" -f $ts, $Level, $Message
    Add-Content -Path $logFile -Value $line -Encoding utf8
    Write-Host $line
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
Write-Log 'INFO' "GDriveFS watchdog start (mode=$Mode, host=$env:COMPUTERNAME, user=$env:USERNAME)"

$binary = Resolve-GDriveFSPath
if (-not $binary -or -not (Test-Path $binary)) {
    Write-Log 'ERROR' "GDriveFS binary not found (HKCU Run + Program Files glob both empty). Cannot relaunch."
    $script:alerts += 'binary-not-found'
} else {
    $state = Test-GDriveFSAlive
    if ($state.Alive) {
        Write-Log 'OK' "GoogleDriveFS.exe alive (pids=$($state.Pids)) — no action"
    } else {
        Write-Log 'FAIL' "GoogleDriveFS.exe NOT running — triggering relaunch"
        Invoke-RelaunchGDriveFS -BinaryPath $binary

        # Re-check after the wait.
        $after = Test-GDriveFSAlive
        if ($after.Alive) {
            Write-Log 'OK' "GoogleDriveFS.exe recovered after relaunch (pids=$($after.Pids))"
        } else {
            Write-Log 'WARN' "GoogleDriveFS.exe still absent 20s after relaunch — may need one-time interactive re-auth (WebView2), or binary failed to init. See GDriveFS logs."
            $script:alerts += 'still-absent-after-relaunch'
        }
    }
}

# ---------- summary + event log ----------
if ($script:repairs.Count -gt 0) {
    $summary = "GDriveFS watchdog repaired: $($script:repairs -join ', ')"
    Write-Log 'INFO' $summary
    try {
        $src = 'GDriveFS-Watchdog'
        if (-not [System.Diagnostics.EventLog]::SourceExists($src)) {
            New-EventLog -LogName Application -Source $src -ErrorAction SilentlyContinue
        }
        Write-EventLog -LogName Application -Source $src -EventId 1000 -EntryType Information -Message $summary -ErrorAction SilentlyContinue
    } catch {}
}

if ($script:alerts.Count -gt 0) {
    $alertMsg = "GDriveFS watchdog ALERT: $($script:alerts -join '; ')"
    Write-Log 'ALERT' $alertMsg
    try {
        $src = 'GDriveFS-Watchdog'
        if (-not [System.Diagnostics.EventLog]::SourceExists($src)) {
            New-EventLog -LogName Application -Source $src -ErrorAction SilentlyContinue
        }
        Write-EventLog -LogName Application -Source $src -EventId 2000 -EntryType Error -Message $alertMsg -ErrorAction SilentlyContinue
    } catch {}
}

# ---------- log rotation ----------
try {
    Get-ChildItem -Path $LogDir -Filter 'watchdog-*.log' -ErrorAction SilentlyContinue |
        Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-$LogRetentionDays) } |
        Remove-Item -Force -ErrorAction SilentlyContinue
} catch {}

# Exit code: 0 if GDriveFS is alive at end (or dry-run), 1 if still dead.
$final = Test-GDriveFSAlive
if ($Mode -eq 'dry-run' -or $final.Alive) { exit 0 } else { exit 1 }
