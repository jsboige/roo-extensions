<#
.SYNOPSIS
    Lock-window logic for GitHub issue claims — shared by start-claude-worker.ps1
    and its Pester fixture (scripts/scheduling/claim-lock.Tests.ps1).

.DESCRIPTION
    Detects whether a COMPETING machine holds an active claim on an issue, for
    the post-claim double-check of Claim-GitHubIssue (step 4).

    A claim counts as active only if ALL of:
      - it is a [CLAIMED] comment NOT from the local machine,
      - it was posted within the lock window (30 min, same as
        Test-GitHubIssueLock, start-claude-worker.ps1),
      - it is not followed by a [RELEASED] or [DONE] comment.

    Fix #2428 (claim -> yield loop): the pre-fix step 4 counted every [CLAIMED]
    from another machine among the last 5 comments, however old and already
    released, so each worker yielded to a phantom competitor forever
    (5 claim -> yield cycles in 48 h on #2428, from 2026-09-21 to 09-23).
    The window + released-tracking breaks that loop while still catching a TRUE
    race: two machines claiming within 30 min, neither released, one yields.

    A claim whose createdAt is undatable ($null) is treated as held (fail-safe:
    a false yield wastes one worker turn; a false keep risks duplicate work).
#>
function Test-ConcurrentClaimActive {
    param(
        [Parameter(Mandatory = $true)]
        [object[]]$Comments,   # objects with .body (string) and .createdAt (DateTime or $null, UTC)
        [Parameter(Mandatory = $true)]
        [string]$MachineId,
        [datetime]$Now = (Get-Date).ToUniversalTime()
    )

    $LockWindowMinutes = 30

    foreach ($C in $Comments) {
        if ($null -eq $C -or $null -eq $C.body) { continue }
        if ($C.body -notmatch "\[CLAIMED\]") { continue }
        if ($C.body -match [regex]::Escape($MachineId)) { continue }   # our own claim is not competition
        if ($null -eq $C.createdAt) { return $true }                   # undatable claim => assume held

        if (($Now - $C.createdAt).TotalMinutes -ge $LockWindowMinutes) { continue }  # outside the lock window

        $ReleasedAfter = $false
        foreach ($R in $Comments) {
            if ($null -eq $R -or $null -eq $R.body) { continue }
            if ($R.body -notmatch "\[RELEASED\]" -and $R.body -notmatch "\[DONE\]") { continue }
            if ($null -ne $R.createdAt -and $R.createdAt -gt $C.createdAt) { $ReleasedAfter = $true; break }
        }

        if (-not $ReleasedAfter) { return $true }   # fresh claim, still unreleased => real competitor
    }

    return $false
}