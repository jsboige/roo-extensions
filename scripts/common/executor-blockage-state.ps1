# executor-blockage-state.ps1 - Streak state for the absorbing exit-10 form (#3605)
#
# Spec (user-approved 2026-09-13, relayed by ai-01 on #3605): escalate after N=3
# repetitions of the ABSORBING form, not a plain exit-10 counter. The discriminant
# must identify `processPrecedesBuild && staleCount > 0` and distinguish the
# presence/absence of `[REBUILT]` -- a run that rebuilt the build changed the
# state, so it is not a repetition of the same form.
#
# Pure state math + persistence only: no git, no process probes, no console
# policy beyond the data model. The pre-flight owns the messaging; the skill owns
# the conduct. Dot-source this file, do not execute it directly.

function Get-BlockageSignature {
    # Returns the signature of an exit-10 form, or $null when the exit-10 is not
    # the stale-hosts form at all (e.g. a freshness failure that is not ARM).
    param(
        [bool]$ProcessPrecedesBuild,
        [int]$StaleCount,
        [bool]$RebuiltThisRun
    )
    if (-not $ProcessPrecedesBuild -or $StaleCount -le 0) { return $null }
    if ($RebuiltThisRun) { return 'arm-post-rebuild' }
    return 'arm-absorbing'
}

function Get-BlockageStatePath {
    param([string]$ExplicitPath)
    if ($ExplicitPath) { return $ExplicitPath }
    # Machine-local, OUTSIDE any repo and outside ~/.claude (sanctuary rule): the
    # streak must survive checkouts and must never show up as repo litter.
    return (Join-Path $env:LOCALAPPDATA 'claude-executor\preflight-blockage.json')
}

function Update-BlockageState {
    # Records one blocking occurrence of $Signature and reports what the caller
    # should do. Returns a hashtable:
    #   Streak     occurrences of the SAME signature in a row (this one included)
    #   Escalate   $true exactly once, on the first run where Streak >= EscalateAt
    #   ShortCycle $true when escalation already happened on an earlier run
    param(
        [Parameter(Mandatory = $true)][string]$Signature,
        [Parameter(Mandatory = $true)][string]$StatePath,
        [int]$EscalateAt = 3
    )

    $now = (Get-Date).ToUniversalTime().ToString('o')
    $state = $null
    if (Test-Path -LiteralPath $StatePath) {
        # A corrupt state file must never block the pre-flight: treat it as absent.
        try { $state = Get-Content -LiteralPath $StatePath -Raw | ConvertFrom-Json } catch { $state = $null }
    }

    $streak = 1
    $firstSeen = $now
    $wasEscalated = $false
    if ($state -and $state.signature -eq $Signature) {
        $streak = [int]$state.streak + 1
        $firstSeen = [string]$state.firstSeen
        $wasEscalated = [bool]$state.escalated
    }

    $escalate = ($streak -ge $EscalateAt) -and (-not $wasEscalated)
    $escalated = $wasEscalated -or ($streak -ge $EscalateAt)

    $parent = Split-Path -Parent $StatePath
    if ($parent -and -not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    @{ signature = $Signature; streak = $streak; escalated = $escalated; firstSeen = $firstSeen; lastSeen = $now } |
        ConvertTo-Json -Compress | Set-Content -LiteralPath $StatePath -Encoding UTF8

    return @{
        Streak     = $streak
        Escalate   = $escalate
        ShortCycle = ($wasEscalated -and -not $escalate)
    }
}

function Clear-BlockageState {
    # Called on every non-10 pre-flight outcome: the absorbing form disappeared
    # (or never was), so the streak and the short-cycle flag reset with it.
    param([Parameter(Mandatory = $true)][string]$StatePath)
    if (Test-Path -LiteralPath $StatePath) {
        Remove-Item -LiteralPath $StatePath -Force -ErrorAction SilentlyContinue
    }
}
