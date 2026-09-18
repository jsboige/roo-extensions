<#
.SYNOPSIS
    Install or uninstall the GDriveFS-Watchdog scheduled task (#2875).

.DESCRIPTION
    GoogleDriveFS.exe dies silently with no auto-restart (HKCU Run = logon-only).
    This task runs gdrivefs-watchdog.ps1 as a short poll every 15 min: if the
    process is absent, it relaunches it in the user context (same launch command
    as the HKCU Run entry). Cuts the recurrence of the #2875 comm blackouts from
    hours/days down to ~15 min.

    Mirrors the dashboard-listener installer's self-healing shape (user principal,
    AtLogOn + AtStartup + repetition, IgnoreNew) — but the body is a short-lived
    poll, NOT a long-running wrapper, so ExecutionTimeLimit is bounded (5 min)
    rather than Zero.

    GDriveFS binds to the user account token, so the task MUST run as the user
    (NOT SYSTEM) — a SYSTEM-context relaunch cannot associate the core_controller.

.PARAMETER Uninstall
    Remove the scheduled tasks (main + fast-poll companion) instead of creating them.

.PARAMETER DryRun
    Print the exact task actions/settings that would be applied (or the tasks
    that would be removed with -Uninstall) WITHOUT touching the schedule —
    no elevation required. Use this to preview the UAC deployment before the
    elevated window (#3690).

.PARAMETER FastPollRepeatMinutes
    #3678 — repeat interval of the companion fast-poll task (registered
    DISABLED; the watchdog body arms it on C2 escalation and disarms it at
    window expiry / recovery). Default: 1.

.EXAMPLE
    .\install-gdrivefs-watchdog-schtask.ps1 -DryRun
    .\install-gdrivefs-watchdog-schtask.ps1 -DryRun -Uninstall
    .\install-gdrivefs-watchdog-schtask.ps1
    .\install-gdrivefs-watchdog-schtask.ps1 -Uninstall

.NOTES
    Requires admin elevation (RunLevel Highest) for schtasks registration.
    Run from an elevated PowerShell:
    pwsh -ExecutionPolicy Bypass -File .\install-gdrivefs-watchdog-schtask.ps1
#>

param(
    [switch]$Uninstall,
    [switch]$DryRun,
    [int]$RepeatMinutes = 15,
    [int]$StartupDelayMinutes = 2,
    [int]$FastPollRepeatMinutes = 1,
    [string]$MountPath = 'G:\',
    [ValidateRange(0, 60)]
    [int]$MountProbeTimeoutSeconds = 5
)

$scriptDir   = Split-Path $MyInvocation.MyCommand.Path -Parent
$watchdogPs1 = Join-Path $scriptDir "gdrivefs-watchdog.ps1"
$taskName    = "GDriveFS-Watchdog"
$fastTaskName = "GDriveFS-Watchdog-FastPoll"

if ($Uninstall) {
    foreach ($t in @($taskName, $fastTaskName)) {
        $existing = Get-ScheduledTask -TaskName $t -ErrorAction SilentlyContinue
        if ($existing) {
            if ($DryRun) {
                Write-Host "DRY-RUN: would unregister task '$t' (state=$(if ($existing.State) { $existing.State } else { 'unknown' }))"
            } else {
                Unregister-ScheduledTask -TaskName $t -Confirm:$false
                Write-Host "Removed scheduled task: $t"
            }
        } else {
            Write-Host "Task not found: $t"
        }
    }
    if ($DryRun) { Write-Host "DRY-RUN: no mutation executed. Re-run without -DryRun (elevated) to apply." }
    exit 0
}

if (-not (Test-Path $watchdogPs1)) {
    Write-Host "ERROR: Watchdog body not found: $watchdogPs1"
    exit 1
}

# Validate / auto-detect the DriveFS mount path (#2875 follow-up, web1 c.202
# firsthand). The default 'G:\' is correct for most machines, but hosts whose
# Google Drive mounts under a folder (web1 = 'C:\Drive\', different GDrive
# account) would otherwise install a watchdog probing a non-existent drive:
# the process is alive but the probe fails -> false "hung-process" verdict ->
# relaunch no-op counted as failure -> 3 failures -> perpetual cooldown lock.
# Net effect: false ALERTs every poll AND zero protection of a real outage.
$mountExplicit = $PSBoundParameters.ContainsKey('MountPath')
if (-not (Test-Path $MountPath)) {
    if ($mountExplicit) {
        Write-Host "WARN: -MountPath '$MountPath' does not resolve on this host. Proceeding (explicit override) — the watchdog will ALERT until the mount appears."
    } else {
        # Known fleet DriveFS mount points (drive-letter default + web1 folder mount).
        $candidates = @('G:\', 'C:\Drive\')
        $detected = $candidates | Where-Object { Test-Path $_ } | Select-Object -First 1
        if ($detected) {
            Write-Host "INFO: default mount 'G:\' not found on this host — auto-detected DriveFS mount at '$detected'."
            $MountPath = $detected
        } else {
            Write-Host "ERROR: no DriveFS mount found at default 'G:\' or fallback 'C:\Drive\'. This host's Google Drive mount path is unknown — pass -MountPath explicitly. A watchdog probing a non-existent mount generates false ALERTs and never protects a real outage (#2875)."
            exit 1
        }
    }
}

# pwsh path resolution and task definition build read-only objects: they run
# first so the -DryRun preview below can print the exact plan with zero
# mutations (non-elevated, #3690).
$pwshPath = (Get-Command pwsh -ErrorAction SilentlyContinue).Source
if (-not $pwshPath) {
    Write-Host "ERROR: pwsh not found in PATH."
    exit 1
}

$escapedWatchdogPath = $watchdogPs1.Replace('"', '`"')
# A run of backslashes immediately before the closing quote escapes it (Windows argv
# convention), so the default `-MountPath "G:\"` reached the body as the single token
# `G:" -MountProbeTimeoutSeconds 5`. Test-Path then failed on EVERY poll and the
# watchdog relaunched a perfectly healthy GDriveFS every 15 min. Doubling the trailing
# run lets the quote close and yields the literal path.
$escapedMountPath = $MountPath.Replace('"', '`"') -replace '(\\+)$', '$1$1'
$actionArguments = "-ExecutionPolicy Bypass -NoProfile -WindowStyle Hidden -File `"$escapedWatchdogPath`" -MountPath `"$escapedMountPath`" -MountProbeTimeoutSeconds $MountProbeTimeoutSeconds"
$action = New-ScheduledTaskAction -Execute $pwshPath -Argument $actionArguments

# Self-healing triggers, mirroring install-dashboard-listener-schtask.ps1 (#2431).
# - AtLogOn: covers the normal interactive-session start (matches the old HKCU Run).
# - AtStartup (+delay): covers a boot without an interactive logon yet.
# - Repeat every N min: resurrects a dead GDriveFS within the interval. IgnoreNew
#   makes this a no-op while the previous poll is still running.
$trigLogon   = New-ScheduledTaskTrigger -AtLogOn
$trigStartup = New-ScheduledTaskTrigger -AtStartup
$trigStartup.Delay = "PT${StartupDelayMinutes}M"
$trigRepeat  = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1) -RepetitionInterval (New-TimeSpan -Minutes $RepeatMinutes)
# Explicit null-out (#3711, fleet finding #967): under Windows PowerShell 5.1
# (Server 2019), -RepetitionInterval alone leaves Duration at a 1-day default,
# silently stopping the self-healing repeat one day after install. Null
# Duration = no <Duration> element in the task XML = repeat indefinitely.
$trigRepeat.Repetition.Duration = $null

# USER principal (NOT SYSTEM): GDriveFS binds its core_controller to the user
# account token; a SYSTEM-context relaunch cannot restore the account association.
$principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -RunLevel Highest -LogonType Interactive

# Body is a short poll (~25s incl. the 20s init wait), NOT a long-running wrapper:
# bound ExecutionTimeLimit (5 min) is enough headroom without leaving a stray proc.
$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -RestartCount 3 `
    -RestartInterval (New-TimeSpan -Minutes 1) `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 5) `
    -MultipleInstances IgnoreNew

# ---------- companion fast-poll task (#3678) ----------
# Registered DISABLED: the watchdog body arms it (Enable-ScheduledTask) when C2
# escalates, for a FastPollWindowMinutes window, and disarms it at expiry or
# recovery. Dynamic arm/disarm keeps the nominal cost at zero — no second
# permanently-running trigger. The body receives -FastPoll so its early-exit
# guard can no-op (and re-attempt the disarm) once the window has closed.
# Indefinite repetition is intentional: the body's early-exit guard is the
# bound, so a missed disable degrades to one cheap invocation per minute
# instead of a stuck task. Duration is nulled explicitly rather than passing
# -RepetitionDuration ([TimeSpan]::MaxValue): Server 2019 rejects that value
# with 0x80041318 — and the error is non-terminating, so the pre-#3711 script
# printed "Installed" and exited 0 on a trigger that never landed. Null
# Duration = indefinite repetition (same path as setup-scheduler.ps1, #967).
$fastActionArguments = "-ExecutionPolicy Bypass -NoProfile -WindowStyle Hidden -File `"$escapedWatchdogPath`" -MountPath `"$escapedMountPath`" -MountProbeTimeoutSeconds $MountProbeTimeoutSeconds -FastPoll"
$fastAction = New-ScheduledTaskAction -Execute $pwshPath -Argument $fastActionArguments
$fastTrigRepeat = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1) -RepetitionInterval (New-TimeSpan -Minutes $FastPollRepeatMinutes)
$fastTrigRepeat.Repetition.Duration = $null
$fastTrigRepeat.Repetition.StopAtDurationEnd = $false

$taskDescription = "GDriveFS silent-exit watchdog #2875 — relaunch GoogleDriveFS.exe (user context) when absent, every $RepeatMinutes min"
$fastDescription = "GDriveFS watchdog fast-poll #3678 — 1-min companion task, armed by the watchdog body on C2 escalation for a short window; stays disabled otherwise"

if ($DryRun) {
    Write-Host "DRY-RUN — install plan (#3690). No mutation executed; elevation not required to print this."
    foreach ($t in @($taskName, $fastTaskName)) {
        $existing = Get-ScheduledTask -TaskName $t -ErrorAction SilentlyContinue
        if ($existing) {
            Write-Host "  [unregister] existing '$t' (state=$(if ($existing.State) { $existing.State } else { 'unknown' })) — idempotent reinstall"
        } else {
            Write-Host "  [unregister] none ('$t' not present)"
        }
    }
    Write-Host "  [register] $taskName"
    Write-Host "    Action : $pwshPath $actionArguments"
    Write-Host "    Trigger: AtLogOn; AtStartup +${StartupDelayMinutes}m; once-in-1m then repeat every ${RepeatMinutes}m (MultipleInstances IgnoreNew)"
    Write-Host "    Principal: $env:USERNAME (RunLevel Highest, LogonType Interactive)"
    Write-Host "    Settings: ExecutionTimeLimit 5m | RestartCount 3 (1m) | StartWhenAvailable | allow on batteries"
    Write-Host "    Description: $taskDescription"
    Write-Host "  [register] $fastTaskName, then [disable] (armed by the body on C2 escalation only)"
    Write-Host "    Action : $pwshPath $fastActionArguments"
    Write-Host "    Trigger: once-in-1m then repeat every ${FastPollRepeatMinutes}m, indefinite duration"
    Write-Host "    Description: $fastDescription"
    Write-Host ""
    Write-Host "DRY-RUN — nothing registered/unregistered/disabled. Re-run without -DryRun from an elevated PowerShell to apply."
    exit 0
}

# ---------- fail-loud guards (#3711) ----------
# A silent install failure is only discovered at the first missed run.
# Register-ScheduledTask errors are NON-terminating by default: on Server 2019
# the 0x80041318 rejection printed red while this installer carried on to
# "Installed" and exited 0 — a false success confirmation (reported web1
# c.471, verified firsthand po-203). Two guards close every silent hole:
#   1. -ErrorAction Stop + try/catch on each registration -> visible exit 1.
#   2. Post-registration readback: the repetition must be ON THE REGISTERED
#      task (read back from the scheduler), not merely in the in-memory
#      objects built above — and the readback runs BEFORE any success output.

function Get-TaskRepetitionTotalMinutes {
    # ISO 8601 duration (PT15M, PT1H, P1DT2H30M...) -> total minutes, or $null
    # when unparseable. The scheduler normalizes intervals across units, so the
    # guard must compare minutes, not literal strings ("PT60M" vs "PT1H").
    param([string]$IsoDuration)
    if (-not $IsoDuration) { return $null }
    if ($IsoDuration -notmatch '^P(?:(\d+)D)?(?:T(?:(\d+)H)?(?:(\d+)M)?(?:([0-9]+(?:\.[0-9]+)?)S)?)?$') { return $null }
    $total = 0.0
    if ($Matches[1]) { $total += 1440.0 * [double]$Matches[1] }
    if ($Matches[2]) { $total += 60.0 * [double]$Matches[2] }
    if ($Matches[3]) { $total += [double]$Matches[3] }
    if ($Matches[4]) { $total += [double]$Matches[4] / 60.0 }
    return $total
}

function Assert-RegisteredRepetition {
    param(
        [string]$Name,
        [double]$ExpectedMinutes
    )
    $task = Get-ScheduledTask -TaskName $Name -ErrorAction SilentlyContinue
    if (-not $task) {
        Write-Host "ERROR (#3711): task '$Name' is ABSENT after Register-ScheduledTask returned -- the registration failed silently. NOT reporting success."
        exit 1
    }
    $repetitions = @($task.Triggers | Where-Object { $_.Repetition -and $_.Repetition.Interval })
    $landed = @($repetitions | Where-Object {
        $actual = Get-TaskRepetitionTotalMinutes $_.Repetition.Interval
        ($null -ne $actual) -and ([Math]::Abs($actual - $ExpectedMinutes) -lt 0.5) -and (-not $_.Repetition.Duration)
    })
    if ($landed.Count -eq 0) {
        $observed = if ($repetitions.Count) {
            ($repetitions | ForEach-Object { "Interval=$($_.Repetition.Interval) Duration=$($_.Repetition.Duration)" }) -join '; '
        } else {
            'no repetition trigger at all'
        }
        Write-Host "ERROR (#3711): task '$Name' registered but its every-${ExpectedMinutes}-min repetition trigger did NOT land (indefinite Duration expected). Observed: $observed. NOT reporting success."
        exit 1
    }
}

# Remove old tasks if they exist (idempotent reinstall).
foreach ($t in @($taskName, $fastTaskName)) {
    $existing = Get-ScheduledTask -TaskName $t -ErrorAction SilentlyContinue
    if ($existing) {
        Unregister-ScheduledTask -TaskName $t -Confirm:$false
        Write-Host "Removed existing task: $t"
    }
}

try {
    Register-ScheduledTask -TaskName $taskName -Action $action -Trigger @($trigLogon, $trigStartup, $trigRepeat) -Principal $principal -Settings $settings -Description $taskDescription -ErrorAction Stop | Out-Null
} catch {
    Write-Host "ERROR (#3711): registration of '$taskName' failed: $($_.Exception.Message)"
    exit 1
}

try {
    Register-ScheduledTask -TaskName $fastTaskName -Action $fastAction -Trigger $fastTrigRepeat -Principal $principal -Settings $settings -Description $fastDescription -ErrorAction Stop | Out-Null
    Disable-ScheduledTask -TaskName $fastTaskName -ErrorAction Stop | Out-Null
} catch {
    Write-Host "ERROR (#3711): registration/disarm of '$fastTaskName' failed: $($_.Exception.Message)"
    exit 1
}

# Readback guards run BEFORE the success output below: a repetition that did
# not land must never coexist with an "Installed" line (#3711).
Assert-RegisteredRepetition -Name $taskName -ExpectedMinutes $RepeatMinutes
Assert-RegisteredRepetition -Name $fastTaskName -ExpectedMinutes $FastPollRepeatMinutes

Write-Host "Installed scheduled task: $taskName"
Write-Host "  Triggers: AtLogOn + AtStartup(+${StartupDelayMinutes}m) + repeat every ${RepeatMinutes}m | Principal: $env:USERNAME (Highest, Interactive)"
Write-Host "  ExecutionTimeLimit: 5 min | MultipleInstances: IgnoreNew"
Write-Host "  C1 positive probe: mount=$MountPath, timeout=${MountProbeTimeoutSeconds}s"
Write-Host "  Body: $watchdogPs1"
Write-Host "Installed companion task (DISABLED until the body arms it): $fastTaskName"
Write-Host "  Trigger: repeat every ${FastPollRepeatMinutes}m (indefinite; bounded by the body's fast-poll window + early-exit guard)"
Write-Host ""
Write-Host "Prerequisite for the #3678 survivor channel (once per repo):"
Write-Host "  gh label create gdrivefs-watchdog-alert --repo jsboige/roo-extensions --color D93F0B"
Write-Host ""
Write-Host "To start immediately: schtasks /run /tn `"$taskName`""
Write-Host "To test the body standalone (no install): pwsh -File `"$watchdogPs1`" -Mode dry-run"
Write-Host "To preview this install (no elevation, no mutation): .\install-gdrivefs-watchdog-schtask.ps1 -DryRun"
