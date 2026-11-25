<#
.SYNOPSIS
    Scheduled-task logic of the metered-link watch. Pure: no scheduled-task
    cmdlet is called here, so the Pester suite can pin it on a runner without
    a Task Scheduler.

.DESCRIPTION
    Defect measured on myia-po-2027 on 2026-11-25 (DM from myia-po-2027:Maintenance):
    the install recipe documented in metered-link-watch.ps1 was a bare
    `schtasks /create`, which leaves Task Scheduler's defaults in place --
    DisallowStartIfOnBatteries=True, StopIfGoingOnBatteries=True,
    StartWhenAvailable=False. The watch exists to catch a billed phone hotspot,
    which is what a seat runs on when it is away from mains power, so at those
    defaults it is blind exactly when it matters.

    Two halves, kept together because they fail separately:
      - the settings REQUESTED when the task is created (a recipe with no
        switch gets the defaults);
      - the settings REPAIRED on a task that already exists (an older install
        keeps its values until something changes them).

.NOTES
    Dot-sourced by install-metered-link-watch-schtask.ps1 and by
    scripts/testing/unit/metered-link-watch-install.Tests.ps1.
#>

$script:MeteredWatchTaskName = 'RooMeteredLinkWatch'
$script:MeteredWatchRepetitionMinutes = 15

# One row per settings field: the name Get-ScheduledTask exposes on a task's
# settings object, the New-ScheduledTaskSettingsSet switch that sets it at
# creation, and the value the watch needs.
$script:MeteredWatchBatteryFields = @(
    [pscustomobject]@{ Property = 'DisallowStartIfOnBatteries'; Switch = 'AllowStartIfOnBatteries';    Wanted = $false },
    [pscustomobject]@{ Property = 'StopIfGoingOnBatteries';     Switch = 'DontStopIfGoingOnBatteries'; Wanted = $false },
    [pscustomobject]@{ Property = 'StartWhenAvailable';         Switch = 'StartWhenAvailable';         Wanted = $true }
)

function Get-MeteredWatchBatteryFields {
    # The three rows. Copies, so a caller cannot edit the table by accident.
    [CmdletBinding()]
    param()

    foreach ($field in $script:MeteredWatchBatteryFields) {
        [pscustomobject]@{ Property = $field.Property; Switch = $field.Switch; Wanted = $field.Wanted }
    }
}

function Get-MeteredWatchBatteryPlan {
    <#
    .SYNOPSIS
        The settings fields to change on an existing task: only those that differ.
    .DESCRIPTION
        One object per field whose current value is not the wanted one, carrying
        Before and After. Nothing is returned when the task is already correct --
        the caller must then write nothing. Accepts any object exposing the three
        properties (a real settings object, a PSCustomObject, a hashtable).
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)] $Current)

    foreach ($field in $script:MeteredWatchBatteryFields) {
        $before = [bool]$Current.($field.Property)
        if ($before -ne [bool]$field.Wanted) {
            [pscustomobject]@{
                Property = $field.Property
                Before   = $before
                After    = [bool]$field.Wanted
            }
        }
    }
}

function Get-MeteredWatchCreateSettingsSwitches {
    <#
    .SYNOPSIS
        The switches New-ScheduledTaskSettingsSet must receive when the task is
        created, as a splat table.
    .DESCRIPTION
        Built from the table above, so creation and repair cannot disagree on
        which flags the watch needs. Kept as data so the suite can assert it on
        a runner that has no PSScheduledTask module.
    #>
    [CmdletBinding()]
    param()

    $splat = @{}
    foreach ($field in $script:MeteredWatchBatteryFields) { $splat[$field.Switch] = $true }
    return $splat
}
