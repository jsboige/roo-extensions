<#
.SYNOPSIS
    Report scheduled tasks whose last run actually failed, with the benign
    result codes filtered out.
.DESCRIPTION
    Nothing on this fleet reads LastTaskResult. Measured on myia-ai-01 on
    2026-08-15: five of our own tasks were sitting on a failing exit code, the
    oldest since 2026-08-01, and not one of those failures had reached a human
    or an agent. The most expensive of them -- Qdrant-Snapshot-Daily returning 1
    -- had left the day's 28 GB snapshot orphaned in %TEMP% and an empty day
    directory offsite. It was found by hand, twelve hours late, while chasing an
    unrelated question.

    Producing a trace is not the hard part; Windows already records the exit
    code of every run. The hard part is that a raw "LastTaskResult -ne 0" sweep
    is unusable, because most non-zero codes mean nothing is wrong. On the same
    machine, 22 of 223 tasks were non-zero and only 5 were real failures. A
    sweep that reports the other 17 every cycle gets ignored within a week, and
    an ignored monitor is worse than none: it launders silence into
    reassurance.

    So the whole value of this script is the exclusion list below, and every
    entry in it was measured rather than assumed.
.PARAMETER IncludeSystem
    Also report tasks outside the root TaskPath. Off by default: the OS and OEM
    trees (\Microsoft\Windows\*, \ASUS\*, the per-SID OneDrive updater) supplied
    17 of the 22 non-zero codes on ai-01 and none of them is ours to fix.
.PARAMETER Markdown
    Emit a dashboard-ready markdown block instead of a console table. The point
    of this script is that a human or an agent reads the result, so it has to be
    cheap to paste into the channel the fleet actually reads.
.EXAMPLE
    pwsh -File scripts/maintenance/report-failed-scheduled-tasks.ps1
.EXAMPLE
    pwsh -File scripts/maintenance/report-failed-scheduled-tasks.ps1 -Markdown
.NOTES
    Exit code is always 0, including when failures are found.

    That is deliberate. If this script is ever scheduled itself -- the obvious
    next step -- then returning non-zero on findings would make it report itself
    as a failed task on the following run, and a monitor that flags itself is
    indistinguishable from a monitor that is broken. The findings live in the
    output, which is the thing a consumer reads anyway.
#>
[CmdletBinding()]
param(
    [switch]$IncludeSystem,
    [switch]$Markdown
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Result codes that are NOT failures. Each was verified on myia-ai-01 on
# 2026-08-15 against the live state of the task that produces it.
#
#   0                       success.
#
#   267009 (0x00041301)     SCHED_S_TASK_RUNNING. The task is running right now,
#                           so there is no result yet. Reading this as failure
#                           is a standing trap on this fleet: it is already
#                           recorded in machine memory after a previous sweep
#                           mistook two running tasks for two broken ones.
#
#   267011 (0x00041303)     SCHED_S_TASK_HAS_NOT_RUN. Registered, never fired.
#                           A task that has not run has not failed.
#
#   2147946720 (0x800710E0) "The operator or administrator has refused the
#                           request" -- which, from the scheduler, means an
#                           instance was already running and the task's
#                           MultipleInstances policy refused to start a second
#                           one. This is the signature of a healthy long-lived
#                           task on a short trigger, not of a broken one.
#
#                           Claude-DashboardListener is exactly that: it holds
#                           this code permanently while being State=Running,
#                           with a 15-minute trigger that is refused every time
#                           precisely because the listener is alive. Its
#                           heartbeat was 3 minutes old when this was measured,
#                           and all six fleet listeners were reporting within 4
#                           minutes of each other. Without this exclusion the
#                           sweep denounces the healthiest task on the machine
#                           four times an hour -- and it is the WAKE listener,
#                           so the false alarm would land on the one mechanism
#                           the fleet uses to summon help.
$BenignTaskResults = @(0, 267009, 267011, 2147946720)

function Test-BenignTaskResult {
    <#
    .SYNOPSIS
        True when a LastTaskResult does not indicate a failed run.
    .DESCRIPTION
        Pure: no scheduler access, no I/O. Kept separate so the exclusion list
        -- the only part of this script that carries knowledge -- is covered by
        scripts/testing/harness/test-schtask-result-filter.ps1, which runs in
        CI. Inlining the comparison would leave that knowledge untested, and it
        is exactly the kind of list a later simplification quietly shortens.
    #>
    param([Parameter(Mandatory)][AllowNull()][object]$ResultCode)

    if ($null -eq $ResultCode) { return $true }
    return ([int64]$ResultCode) -in $script:BenignTaskResults
}

# Third-party tasks that register at the ROOT path alongside ours, so the path
# test alone does not exclude them. Kept as an explicit, short list rather than a
# clever heuristic: each entry is a task observed failing on a fleet machine, and
# a heuristic broad enough to catch them would eventually swallow one of ours.
#
#   OneDrive*Update Task*                         RC 0x8004EE04, ai-01, daily.
#       Registered at '\' with a per-SID suffix, so it survives the path guard.
#       Microsoft's updater failing is not ours to fix, and it fires every day.
#
#       The wildcard sits in the MIDDLE for a measured reason. The first version
#       of this list read 'OneDrive Standalone Update Task*', which matched the
#       name on ai-01 and nothing else: po-2023 reviewed this PR and reported
#       'OneDrive Per-Machine Standalone Update Task' (RC 0x8004EE04), where the
#       vendor inserts two words before "Standalone". A prefix taken from one
#       machine's spelling is not the family it was meant to name -- and the
#       report on that machine would have carried the same noise row forever.
#
#   NahimicTask*                                  RC 0xC0000005 (Task64, po-2023) and
#                                                 RC 0x40010004 (Task32, po-204), NextRun=never.
#       Access violation in an audio-driver task, registered at the root. Reported
#       by po-2023 (Task64) and po-204 (Task32) on this PR. The first version
#       excluded only the literal 'NahimicTask64' -- the spelling seen on po-2023 --
#       and po-204's Task32 twin went straight through, same lesson as the OneDrive
#       prefix above: a name taken from one machine is not the family. Both are
#       frozen (no next run), so each would reappear in every single report.
$ForeignRootTaskPatterns = @(
    'OneDrive*Update Task*',
    'NahimicTask*'
)

function Test-OwnedTask {
    <#
    .SYNOPSIS
        True when a task is ours rather than the OS's or a vendor's.
    .DESCRIPTION
        Two conditions, because one is not enough. Our tasks are registered at
        the root path, which excludes the \Microsoft\Windows\* and \ASUS\* trees
        (17 of the 22 non-zero codes on ai-01). But the path test alone still
        lets OneDrive's per-SID updater through, because it also registers at the
        root -- measured, not predicted: the first run of this script reported it
        alongside our five real failures.
    #>
    param(
        [Parameter(Mandatory)][AllowEmptyString()][string]$TaskPath,
        [Parameter(Mandatory)][AllowEmptyString()][string]$TaskName
    )

    if ($TaskPath -ne '\') { return $false }
    foreach ($pattern in $script:ForeignRootTaskPatterns) {
        if ($TaskName -like $pattern) { return $false }
    }
    return $true
}

# A Disabled task's LastTaskResult is a fossil. It cannot change, because the
# task will not run again -- so it would surface in every single report, forever.
# That is precisely the static background this script exists to cut through, and
# it matters more, not less, once the script is scheduled: a report that always
# carries the same two rows trains its reader to skim past the row that is new.
#
# Measured by web1 on 2026-08-15, reviewing this PR: two of its three findings
# were Disabled tasks holding a frozen code -- Qdrant-Snapshot-Daily (disabled
# the day before on user GO, no local Qdrant after the ai-01 move) and
# Claude-DashboardWatcher (legacy, disabled since 2026-05-05).
#
# ai-01 has no Disabled task with a non-zero code, so this exclusion is NOT
# exercised on the machine writing it. It rests on web1's measurement plus the
# harness below, not on a local observation -- said plainly rather than implied.
function Test-FrozenTaskState {
    <#
    .SYNOPSIS
        True when a task's last result can never change again.
    .DESCRIPTION
        Pure, like Test-BenignTaskResult, and for the same reason: this is the
        second piece of knowledge in the script, so it belongs on the tested
        path rather than inlined in the loop.
    #>
    param([Parameter(Mandatory)][AllowEmptyString()][string]$State)

    return $State -eq 'Disabled'
}

$failures = @()
$frozen   = @()

foreach ($task in Get-ScheduledTask) {
    if (-not $IncludeSystem -and -not (Test-OwnedTask -TaskPath $task.TaskPath -TaskName $task.TaskName)) { continue }

    # A task can vanish or refuse inspection between enumeration and query.
    # Skipping it is right: this script reports failures, and "I could not ask"
    # is not evidence of one.
    $info = $null
    try { $info = $task | Get-ScheduledTaskInfo -ErrorAction Stop } catch { continue }

    if (Test-BenignTaskResult -ResultCode $info.LastTaskResult) { continue }

    # Checked AFTER the benign filter on purpose, so the count below means
    # "disabled tasks that WOULD have been reported" rather than "disabled
    # tasks", which is the number a reader can act on.
    if (Test-FrozenTaskState -State ([string]$task.State)) {
        $frozen += $task.TaskName
        continue
    }

    $failures += [pscustomobject]@{
        Name    = $task.TaskName
        Path    = $task.TaskPath
        State   = [string]$task.State
        Result  = $info.LastTaskResult
        Hex     = '0x{0:X8}' -f [int64]$info.LastTaskResult
        LastRun = $info.LastRunTime
        NextRun = $info.NextRunTime
    }
}

$failures = @($failures | Sort-Object LastRun -Descending)

# Dates are rendered ISO on purpose. The machines in this fleet run mixed
# locales, and dd/MM vs MM/dd silently turns 2026-08-01 into 2026-01-08 in a
# report meant to be read across all six.
function Format-Stamp {
    param([AllowNull()][object]$Value)
    if ($null -eq $Value) { return 'never' }
    try { return ([datetime]$Value).ToString('yyyy-MM-dd HH:mm') } catch { return 'never' }
}

if ($Markdown) {
    if ($failures.Count -eq 0) {
        "**Tâches planifiées** : aucune en échec (hors codes bénins) sur $env:COMPUTERNAME."
    } else {
        "**Tâches planifiées en échec sur $env:COMPUTERNAME** : $($failures.Count)"
        ''
        '| Tâche | RC | Dernier tir | Prochain tir |'
        '|---|---|---|---|'
        foreach ($f in $failures) {
            '| {0} | {1} ({2}) | {3} | {4} |' -f `
                $f.Name, $f.Result, $f.Hex, (Format-Stamp $f.LastRun), (Format-Stamp $f.NextRun)
        }
    }
    # Reported, not silently dropped. A sweep that hides how much it discarded
    # reads as "nothing to see" when it isn't -- and a task disabled by accident
    # is a real problem, merely not a FAILURE one.
    if ($frozen.Count -gt 0) {
        ''
        "_Exclu : $($frozen.Count) tâche(s) désactivée(s) au code figé — $($frozen -join ', ')._"
    }
} else {
    if ($failures.Count -eq 0) {
        Write-Host "No failed scheduled tasks on $env:COMPUTERNAME (benign codes excluded)." -ForegroundColor Green
    } else {
        Write-Host "Failed scheduled tasks on ${env:COMPUTERNAME}: $($failures.Count)" -ForegroundColor Yellow
        $failures |
            Select-Object Name,
                          @{ n = 'RC';      e = { '{0} ({1})' -f $_.Result, $_.Hex } },
                          State,
                          @{ n = 'LastRun'; e = { Format-Stamp $_.LastRun } },
                          @{ n = 'NextRun'; e = { Format-Stamp $_.NextRun } } |
            Format-Table -AutoSize
    }
    if ($frozen.Count -gt 0) {
        Write-Host "Excluded: $($frozen.Count) disabled task(s) with a frozen result — $($frozen -join ', ')" -ForegroundColor DarkGray
    }
}

exit 0
