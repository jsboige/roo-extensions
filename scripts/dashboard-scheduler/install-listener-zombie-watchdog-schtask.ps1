<#
.SYNOPSIS
    Install or uninstall the Claude-ListenerZombieWatchdog scheduled task (#3687).

.DESCRIPTION
    Creates a Windows scheduled task that runs listener-zombie-watchdog.ps1 every
    15 minutes on THIS machine. The watchdog detects the zombie class observed in
    #3686 (task State=Running + no wrapper process + stale heartbeat, while
    MultipleInstances IgnoreNew refuses every re-trigger) and applies the proven
    remediation: Stop-ScheduledTask (purge zombie) + Start-ScheduledTask.

    Design (mirrors install-check-all-listeners-schtask.ps1):
      - Per-machine, idempotent: identical schtask on each fleet machine; each
        watchdog only supervises its OWN machine's listener (stop/start is a
        local operation — there is no cross-machine remediation).
      - Short one-shot run (~1-5s). Not a long-running service -> no
        self-healing repeat trigger needed beyond the 15-min schedule itself.
      - Non-elevated remediation: Stop/Start-ScheduledTask are allowed for the
        task owner. Registration of THIS watchdog task is what requires
        elevation ([INTERACTIVE-ONLY], same as the listener install).
      - -StartWhenAvailable: a missed fire (machine off) runs on wake.
      - MultipleInstances IgnoreNew on the watchdog itself: a hung previous run
        never stacks.

    Rollout: install on every machine that has Claude-DashboardListener deployed
    in pwsh-direct mode (#3656). One-time elevated action per machine, then the
    zombie class self-heals within ~15-30 min instead of ~26h of human latency.

.PARAMETER Uninstall
    Remove the scheduled task instead of creating it.

.PARAMETER DryRun
    Print the exact schtask configuration that would be registered, without
    registering (no elevation required).

.PARAMETER IntervalMinutes
    Repetition interval in minutes (default 15 — matches the listener's own
    re-trigger cadence; tighter is pointless, larger re-opens the latency hole).

.PARAMETER StaleSeconds
    Passed through to the watchdog (default 900 = 15 min = 3 missed 5-min pings).

.EXAMPLE
    .\install-listener-zombie-watchdog-schtask.ps1 -DryRun
    # Preview the schtask config without registering.

.EXAMPLE
    .\install-listener-zombie-watchdog-schtask.ps1
    # Register the 15-min watchdog (requires elevation).

.EXAMPLE
    .\install-listener-zombie-watchdog-schtask.ps1 -Uninstall

.NOTES
    Requires admin elevation (RunLevel Highest) for schtasks registration.
    Run from an elevated PowerShell:
    powershell -ExecutionPolicy Bypass -File .\install-listener-zombie-watchdog-schtask.ps1

    Related: #3687 (this watchdog), #3686 (po-2026 zombie, ~26h human latency),
    #2431 (listener durability), #2928 (fleet detection gap).
#>

param(
    [switch]$Uninstall,
    [switch]$DryRun,
    [int]$IntervalMinutes = 15,
    [int]$StaleSeconds = 900
)

$ErrorActionPreference = 'Stop'
$scriptDir = Split-Path $MyInvocation.MyCommand.Path -Parent
$watchdogScript = Join-Path $scriptDir "listener-zombie-watchdog.ps1"
$taskName = "Claude-ListenerZombieWatchdog"

# ========================================
# UNINSTALL PATH
# ========================================
if ($Uninstall) {
    if ($DryRun) {
        Write-Host "[DryRun] Would unregister task: $taskName" -ForegroundColor Cyan
        exit 0
    }
    $existing = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
    if ($existing) {
        Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
        Write-Host "Removed scheduled task: $taskName" -ForegroundColor Green
    } else {
        Write-Host "Task not found: $taskName" -ForegroundColor Yellow
    }
    exit 0
}

# ========================================
# PRE-FLIGHT CHECKS
# ========================================
if (-not (Test-Path $watchdogScript)) {
    Write-Host "ERROR: watchdog script not found: $watchdogScript" -ForegroundColor Red
    exit 1
}

if ($IntervalMinutes -lt 5) {
    Write-Host "ERROR: -IntervalMinutes must be >= 5 (listener heartbeat cadence is 5 min;" -ForegroundColor Red
    Write-Host "       the watchdog must see at least one missed ping before acting)."
    exit 1
}

# #2368 — pwsh (PS7) absent on some machines: fallback to powershell 5.1.
$pwshPath = (Get-Command pwsh -ErrorAction SilentlyContinue).Source
if (-not $pwshPath) {
    $pwshPath = (Get-Command powershell -ErrorAction SilentlyContinue).Source
    if ($pwshPath) { Write-Host "pwsh absent — fallback powershell 5.1: $pwshPath" }
}
if (-not $pwshPath) {
    Write-Host "ERROR: neither pwsh nor powershell found in PATH." -ForegroundColor Red
    exit 1
}

# The watchdog is only useful where the listener is installed. Warn, don't fail —
# the watchdog exits 0 cleanly on NOT_INSTALLED, so registering ahead of the
# listener rollout (#3656) is harmless.
$listenerTask = Get-ScheduledTask -TaskName "Claude-DashboardListener" -ErrorAction SilentlyContinue
$listenerWarning = if (-not $listenerTask) {
    "WARNING: Claude-DashboardListener is not installed on this machine. The watchdog will no-op (NOT_INSTALLED) until it is."
} else {
    "Claude-DashboardListener present (State=$($listenerTask.State))."
}

# ========================================
# BUILD SCHTASK COMPONENTS
# ========================================
$action = New-ScheduledTaskAction -Execute $pwshPath `
    -Argument "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$watchdogScript`" -StaleSeconds $StaleSeconds"

$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1) `
    -RepetitionInterval (New-TimeSpan -Minutes $IntervalMinutes)

# Same principal as Claude-DashboardListener: the remediation (Stop/Start on
# that task) is permitted to the task owner without elevation at runtime.
$principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -RunLevel Highest -LogonType Interactive

# Bounded execution (5 min cap if GDrive hangs on the shared-heartbeat read) +
# best-effort retry. IgnoreNew: a hung previous run never stacks.
$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
    -StartWhenAvailable -RestartCount 2 -RestartInterval (New-TimeSpan -Minutes 5) `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 5) `
    -MultipleInstances IgnoreNew

$description = "Listener zombie watchdog (#3687) -- runs listener-zombie-watchdog.ps1 every $IntervalMinutes min. Detects Claude-DashboardListener State=Running with no live wrapper process and stale heartbeat (the IgnoreNew zombie class of #3686), captures forensics, then Stop+Start the task. Non-elevated remediation; closes the ~26h human-latency hole."

# ========================================
# DRY RUN (validate without elevation)
# ========================================
if ($DryRun) {
    Write-Host "========== DRY RUN -- schtask preview (not registered) ==========" -ForegroundColor Cyan
    Write-Host "TaskName      : $taskName"
    Write-Host "Action        : $($action.Execute) $($action.Arguments)"
    Write-Host "Trigger       : Every $IntervalMinutes min (-Once + RepetitionInterval)"
    Write-Host "Principal     : $($principal.UserId) (RunLevel: $($principal.RunLevel), LogonType: $($principal.LogonType))"
    Write-Host "ExecLimit     : 5 min | MultipleInstances: IgnoreNew | Restart: 2x /5min"
    Write-Host "Description   : $description"
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Watchdog script exists: $((Test-Path $watchdogScript)) | shell: $pwshPath"
    Write-Host $listenerWarning
    Write-Host ""
    Write-Host "To register (elevated): re-run without -DryRun"
    Write-Host "To test watchdog now  : pwsh -File `"$watchdogScript`" -DryRun"
    exit 0
}

# ========================================
# REGISTER (elevated)
# ========================================
$existing = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
if ($existing) {
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
    Write-Host "Removed existing task: $taskName" -ForegroundColor Gray
}

Register-ScheduledTask -TaskName $taskName `
    -Action $action -Trigger $trigger -Principal $principal `
    -Settings $settings -Description $description | Out-Null

Write-Host "Installed scheduled task: $taskName" -ForegroundColor Green
Write-Host "  Trigger      : Every $IntervalMinutes min | Principal: $env:USERNAME (Highest)"
Write-Host "  Watchdog     : $watchdogScript (StaleSeconds=$StaleSeconds)"
Write-Host "  Remediation  : Stop+Start Claude-DashboardListener on zombie detection"
Write-Host ""
Write-Host $listenerWarning -ForegroundColor $(if ($listenerTask) { 'Gray' } else { 'Yellow' })
Write-Host ""
Write-Host "To run immediately: schtasks /run /tn `"$taskName`""
Write-Host "To verify        : (Get-ScheduledTask $taskName).Triggers"
