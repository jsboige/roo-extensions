<#
.SYNOPSIS
    Installs, or repairs in place, the user scheduled task that runs metered-link-watch.ps1.

.DESCRIPTION
    One entry point, two paths:
      - Task missing: registers it. Every -RepetitionMinutes (15 by default) it runs
        THIS checkout's metered-link-watch.ps1 under Windows PowerShell 5.1 (the
        watch exits 2 under pwsh 7: the WinRT connection-cost API is 5.1-only).
      - Task present: changes ONLY the settings fields returned by
        Get-MeteredWatchBatteryPlan, nothing else. Action, trigger and principal are
        not re-registered, so a launcher hardened locally (a hidden VBS, for
        instance) survives the repair.

    Why this installer exists (measured on myia-po-2027 on 2026-11-25, from a DM of
    myia-po-2027:Maintenance): the recipe formerly documented in
    metered-link-watch.ps1 was a bare `schtasks /create`, which leaves Task
    Scheduler's defaults in place -- DisallowStartIfOnBatteries=True,
    StopIfGoingOnBatteries=True, StartWhenAvailable=False. A witness task created
    that way came out with exactly those three values, and so had the seat's own
    watch. That seat saw 38 AC-to-battery transitions in 7 days: there the watch is
    not allowed to start exactly when a billed phone hotspot is most likely, a run
    cut by the switch is stopped, and a missed run is never caught up.

    Re-running the installer IS the repair: idempotent, and it prints what it will
    change before changing it.

    User task, RunLevel Limited: no elevation anywhere. `-WhatIf` is not offered
    because Set-ScheduledTask does not expose it (measured under Windows PowerShell
    5.1 and pwsh 7.7); -DryRun is the equivalent.

.PARAMETER TaskName
    Name of the scheduled task. Default: RooMeteredLinkWatch.

.PARAMETER RepetitionMinutes
    Interval between two runs of a task this installer creates. Ignored on repair.

.PARAMETER RepairOnly
    Never create: fail when the task is missing. For a seat whose task was
    installed and hardened by another lane.

.PARAMETER DryRun
    Print the plan, write nothing.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File scripts\monitoring\install-metered-link-watch-schtask.ps1 -DryRun

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File scripts\monitoring\install-metered-link-watch-schtask.ps1 -RepairOnly

.NOTES
    Rollback of a repair: the plan prints each field's value before the change;
    set them back with Set-ScheduledTask -Settings on the same task.
#>
param(
    [string]$TaskName = 'RooMeteredLinkWatch',
    [int]$RepetitionMinutes = 15,
    [switch]$RepairOnly,
    [switch]$DryRun
)
$ErrorActionPreference = 'Stop'

$watch = Join-Path $PSScriptRoot 'metered-link-watch.ps1'
if (-not (Test-Path -LiteralPath $watch)) { throw "watch not found next to this installer: $watch" }
. (Join-Path $PSScriptRoot 'metered-link-watch-task.lib.ps1')
$switches = Get-MeteredWatchCreateSettingsSwitches

$existing = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
if ($existing) {
    $plan = @(Get-MeteredWatchBatteryPlan -Current $existing.Settings)
    "task     : $TaskName (exists, state $($existing.State))"
    'mode     : repair settings only -- action, trigger and principal untouched'
    "action   : $(($existing.Actions | ForEach-Object { $_.Execute }) -join ',')"
    if ($plan.Count -eq 0) {
        'plan     : already correct -- nothing to change'
        return
    }
    foreach ($change in $plan) {
        "plan     : $($change.Property) $($change.Before) -> $($change.After)"
    }
    if ($DryRun) { 'DRY-RUN: nothing written'; return }

    # Only the planned fields are assigned, on the task's own settings object:
    # the 20 other fields travel unchanged.
    $settings = $existing.Settings
    foreach ($change in $plan) { $settings.($change.Property) = $change.After }
    Set-ScheduledTask -TaskName $TaskName -Settings $settings | Out-Null

    $after = (Get-ScheduledTask -TaskName $TaskName).Settings
    foreach ($change in $plan) {
        if ([bool]$after.($change.Property) -ne $change.After) {
            throw "repair did not take: $($change.Property) is $($after.($change.Property)), wanted $($change.After)"
        }
    }
    "REPAIRED : " + (($plan | ForEach-Object { "$($_.Property)=$($after.($_.Property))" }) -join ' ')
    return
}

if ($RepairOnly) { throw "task $TaskName not found -- nothing to repair (drop -RepairOnly to install it)" }
if ($RepetitionMinutes -lt 1) { throw "-RepetitionMinutes must be at least 1 (got $RepetitionMinutes)" }

$action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$watch`""
$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1) -RepetitionInterval (New-TimeSpan -Minutes $RepetitionMinutes)
$settings = New-ScheduledTaskSettingsSet @switches -ExecutionTimeLimit (New-TimeSpan -Minutes 10) -MultipleInstances IgnoreNew
$principal = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -LogonType Interactive -RunLevel Limited
$task = New-ScheduledTask -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Description 'Metered-link watch: [WARN] on the global dashboard when a metered link carries more than the threshold between two runs.'

"task     : $TaskName (missing -- will be registered)"
"action   : $($action.Execute) $($action.Arguments)"
"trigger  : once, repeat every $RepetitionMinutes minutes, indefinitely"
"settings : " + ((Get-MeteredWatchBatteryFields | ForEach-Object { "$($_.Property)=$($settings.($_.Property))" }) -join ' ')
"principal: runlevel $($principal.RunLevel), logon $($principal.LogonType)"
if ($DryRun) { 'DRY-RUN: nothing written'; return }

Register-ScheduledTask -TaskName $TaskName -InputObject $task -Force | Out-Null
"REGISTERED: state=$((Get-ScheduledTask -TaskName $TaskName).State) next=$((Get-ScheduledTaskInfo -TaskName $TaskName).NextRunTime)"
