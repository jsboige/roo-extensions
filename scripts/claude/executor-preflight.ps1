<#
.SYNOPSIS
    Synchronizes the executor checkout and guarantees a fresh RSM build before work starts.

.DESCRIPTION
    Runs the parent pull, materializes the mcps/internal gitlink, verifies the submodule identity,
    then invokes the freshly pulled ensure-build-fresh.ps1 in strict mode. Exit 10 means live RSM
    hosts predate the fresh on-disk build, so VS Code must restart before the executor continues.

    After the build checks, scans recent local Claude Code traces for real OAuth expiry API
    errors (#3169, user arbitration 2026-08-20 option b). A hit emits a non-blocking warning:
    OAuth expiry silently kills the executor cadence, and the pre-flight is where that signal
    becomes visible.
#>
[CmdletBinding()]
param(
    [string]$RepoRoot
)

$ErrorActionPreference = 'Stop'

if (-not $RepoRoot) {
    $RepoRoot = (& git rev-parse --show-toplevel 2>$null)
}
if (-not $RepoRoot -or -not (Test-Path (Join-Path $RepoRoot '.git'))) {
    Write-Error '[executor-preflight] Repository root not found.'
    exit 1
}

function Invoke-GitChecked {
    param([string[]]$Arguments)
    & git -C $RepoRoot @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "git $($Arguments -join ' ') failed with exit $LASTEXITCODE"
    }
}

# #3169: a real API auth error carries isApiErrorMessage":true on the same JSONL
# line as the OAuth message; dashboard quotes of the string do not (measured
# 2026-08-27: 28 raw hits = 26 citations + 2 real errors). Both orders covered.
$script:oauthExpiryPattern = 'OAuth session expired.*isApiErrorMessage":true|isApiErrorMessage":true.*OAuth session expired'

function Find-OAuthExpirySignal {
    param([int]$MaxAgeHours = 48)

    $projectsRoot = Join-Path $HOME '.claude\projects'
    if (-not (Test-Path $projectsRoot)) {
        return @()
    }

    $cutoff = (Get-Date).AddHours(-$MaxAgeHours)
    $recentSessions = Get-ChildItem -Path $projectsRoot -Recurse -Filter '*.jsonl' -File -ErrorAction SilentlyContinue |
        Where-Object { $_.LastWriteTime -gt $cutoff }

    $hits = @()
    foreach ($session in $recentSessions) {
        $match = Select-String -Path $session.FullName -Pattern $script:oauthExpiryPattern -List -ErrorAction SilentlyContinue
        if ($match) {
            $hits += $session.BaseName
        }
    }
    return $hits
}

# #3605: absorbing-form streak state (machine-local, outside the repo).
. (Join-Path $PSScriptRoot '..\common\executor-blockage-state.ps1')

try {
    # #3605-incident: when the cwd persists in a submodule (CWD inheritance from
    # a previous Bash session) `git rev-parse --show-toplevel` at line 22-23
    # silently auto-detects the submodule, then `git branch --show-current`
    # returns an empty string for detached HEAD. Calling `.Trim()` on null
    # throws a NullReferenceException with no actionable context. Guard
    # explicitly: a missing current branch means the RepoRoot resolution was
    # wrong, not that the user is on a non-main branch.
    # Merge stderr at the cmd.exe layer (#3731 class): a PS-level `2>&1` under
    # EAP=Stop (global here) lets PS 5.1 mint ErrorRecords from any git stderr
    # chatter (warnings, config advice) and promote it to a terminating
    # NativeCommandError on a call that succeeded — intermittent by nature.
    # cmd does the merge, PS only sees strings, and cmd propagates git's exit
    # code to $LASTEXITCODE.
    $branchRaw = & cmd /c "git -C ""$RepoRoot"" branch --show-current 2>&1"
    if ($LASTEXITCODE -ne 0) {
        throw "Could not read current branch from $RepoRoot (git exit $LASTEXITCODE): $branchRaw"
    }
    $branch = ($branchRaw | Out-String).Trim()
    if ([string]::IsNullOrEmpty($branch)) {
        throw ("Empty current branch at $RepoRoot — likely a detached HEAD, or " +
               "git rev-parse --show-toplevel resolved to a submodule. Pass " +
               "-RepoRoot explicitly when calling the pre-flight.")
    }
    if ($branch -ne 'main') {
        throw "Executor pre-flight must run from main, not '$branch'."
    }

    # #3900: disk gate BEFORE any pull/build write (fleet rule, po-203:Maintenance
    # 27/09 14:21Z: <5% = stop + [WARN]; <15% = clean own artifacts). The check
    # is measure-only and never deletes. Absent script = older checkout: skip
    # silently -- the pull below brings it, the gate arms from the next cycle.
    # Scope (#3900 review, ai-01): measure ONLY the drives this cycle writes to
    # (SystemDrive, RepoRoot, TEMP) -- a nearly-full data drive the worker never
    # touches must not stop the lane (measured F: 3.4% of 7.4 TB on ai-01).
    # -File cannot pass arrays: comma-joined list, split inside the target.
    $diskCheck = Join-Path $RepoRoot 'scripts/infra/check-disk-free.ps1'
    if (Test-Path $diskCheck) {
        $writeDrives = @($env:SystemDrive, (Split-Path -Qualifier $RepoRoot), (Split-Path -Qualifier $env:TEMP)) |
            ForEach-Object { $_.Trim().TrimEnd('\').ToUpper() } | Sort-Object -Unique
        $diskOutput = @(& cmd /c "powershell.exe -NoProfile -ExecutionPolicy Bypass -File ""$diskCheck"" -Drive ""$($writeDrives -join ',')"" 2>&1" | ForEach-Object { "$_" })
        foreach ($line in $diskOutput) { Write-Host $line }
        $diskExit = $LASTEXITCODE
        if ($diskExit -eq 3) {
            Write-Host '[executor-preflight][DISK-BLOCK] A fixed drive is under 5% free - STOP per fleet rule (IISManagement 27/09). Post [WARN] on the workspace dashboard and clean own artifacts; free space before re-running. Nothing to repair on the build side.'
            exit 1
        } elseif ($diskExit -ne 0) {
            Write-Host "[executor-preflight][DISK-WARN] disk check exit $diskExit (a drive under 15%, or measurement failure) - relay [WARN] on the workspace dashboard and clean own artifacts this cycle. Continuing."
        }
    }

    # No submodule recursion on the all-branch fetch: with the default
    # on-demand mode, a parent branch whose gitlink was never pushed to the
    # submodule remote makes git fetch that SHA and fail ("upload-pack: not our
    # ref"), which aborted the whole pre-flight. Measured 03/10 on po-2024 and
    # web1, after two old recovery branches were pushed at 01:51Z. The
    # submodule update below fetches the one SHA main actually needs.
    Invoke-GitChecked @('fetch', '--recurse-submodules=no', 'origin')
    Invoke-GitChecked @('pull', 'origin', 'main', '--no-rebase', '--autostash')

    # `--autostash` ne fait PAS echouer le pull quand la remise de la remise
    # conflicte : mesure du 11/09 (git 2.50.1, depot jetable, edit local divergent
    # de l'upstream) -> exit **0**, arbre laisse en `UU`, marqueurs `<<<<<<< Updated
    # upstream` dans les fichiers, `stash@{0}: autostash` residuel. `Invoke-GitChecked`
    # ne lit que `$LASTEXITCODE` : sans cette garde le preflight enchaine et le build
    # tourne sur un arbre porteur de marqueurs de conflit. Les edits ne sont pas
    # perdus — ils sont dans la remise — mais rien ne le SIGNALE.
    # Un arbre simplement sale apres remise reussie est normal (c'est le but
    # d'`--autostash`) : seul un chemin NON FUSIONNE est un STOP.
    $unmerged = @(& git -C $RepoRoot status --porcelain) | Where-Object { $_ -match '^(DD|AU|UD|UA|DU|AA|UU)' }
    if ($unmerged) {
        $residual = @(& git -C $RepoRoot stash list) | Where-Object { $_ -match 'autostash' }
        throw ("Autostash conflict after pull: {0} unmerged path(s) -> {1}. " -f $unmerged.Count, ($unmerged -join '; ')) +
              ("Your edits are safe in the stash ({0} autostash entry/entries); resolve them, then re-run the pre-flight." -f $residual.Count)
    }
    Invoke-GitChecked @('submodule', 'update', '--init', 'mcps/internal')

    $parentTop = (& git -C $RepoRoot rev-parse --show-toplevel).Trim()
    $submodulePath = Join-Path $RepoRoot 'mcps/internal'
    $submoduleTop = (& git -C $submodulePath rev-parse --show-toplevel).Trim()
    if ($LASTEXITCODE -ne 0 -or $submoduleTop -eq $parentTop) {
        throw 'mcps/internal is not a populated submodule; git -C resolved to the parent repository.'
    }

    $gitlink = ((& git -C $RepoRoot ls-tree HEAD mcps/internal) -split '\s+')[2]
    $submoduleHead = (& git -C $submodulePath rev-parse HEAD).Trim()
    if ($gitlink -ne $submoduleHead) {
        throw "mcps/internal HEAD $submoduleHead does not match parent gitlink $gitlink."
    }

    $helper = Join-Path $RepoRoot 'scripts/claude/ensure-build-fresh.ps1'
    if (-not (Test-Path $helper)) {
        throw "Freshness helper missing after pull: $helper"
    }

    # Output captured (then re-emitted) so the #3605 discriminant can read the
    # helper's status lines: [REBUILT] presence and the stale-hosts count.
    # Merge stderr at the cmd.exe layer (#3731 class, lot 2): the helper's
    # child (npm) can emit stderr on a successful build, and a PS-level `2>&1`
    # let PS 5.1 wrap it in ErrorRecords — the EAP-relax previously kept here
    # only suppressed the promotion instead of removing the ErrorRecords.
    # With cmd doing the merge, PS only ever sees strings under any EAP, so
    # the relax block is gone; cmd propagates the helper's exit code (incl.
    # the 10 discriminated below) to $LASTEXITCODE.
    $helperOutput = @(& cmd /c "powershell.exe -ExecutionPolicy Bypass -File ""$helper"" -RepoRoot ""$RepoRoot"" -RequireFresh 2>&1" | ForEach-Object { "$_" })
    foreach ($line in $helperOutput) { Write-Host $line }
    $freshExit = $LASTEXITCODE
    if ($freshExit -eq 10) {
        # #3605 (user-approved 2026-09-13): escalate after N=3 repetitions of the
        # ABSORBING form -- live hosts predate a build this run did NOT rebuild.
        # A [REBUILT] run changed the state, so it is a different signature, not
        # a repetition. No kill, no auto-retry: the escalation asks for the
        # interactive restart, the following cycles run short.
        $rebuiltThisRun = [bool](@($helperOutput) | Where-Object { $_ -match '\[ensure-build-fresh\]\[REBUILT\]' })
        $staleCount = 0
        $armLine = @($helperOutput) | Where-Object { $_ -match '\[ensure-build-fresh\]\[ARM\]' -and $_ -match 'predating build/index\.js' } | Select-Object -First 1
        if ($armLine -match '(\d+) predating build/index\.js') { $staleCount = [int]$Matches[1] }
        $signature = Get-BlockageSignature -ProcessPrecedesBuild ($staleCount -gt 0) -StaleCount $staleCount -RebuiltThisRun $rebuiltThisRun
        $blockage = $null
        if ($signature) { $blockage = Update-BlockageState -Signature $signature -StatePath (Get-BlockageStatePath) }
        if ($blockage -and $blockage.Escalate) {
            Write-Host ("[executor-preflight][ESCALATE] Absorbing exit-10 repeated {0} time(s) (signature '{1}'): identical interactive blockage. Post ONE [ASK] to the user (full-quit VS Code restart), then run short cycles -- 1-line report, no Phase-1 collection, no new [ASK] -- until this pre-flight returns 0. No kill, no auto-retry (#3605)." -f $blockage.Streak, $signature) -ForegroundColor Magenta
        } elseif ($blockage -and $blockage.ShortCycle) {
            Write-Host ("[executor-preflight][SHORT-CYCLE] Absorbing exit-10 already escalated (streak {0}, signature '{1}'): 1-line report only, no full re-scan, no new [ASK] (#3605)." -f $blockage.Streak, $signature) -ForegroundColor Yellow
        } else {
            Write-Host '[executor-preflight][RESTART-REQUIRED] Build is fresh on disk, but live RSM hosts predate it. Restart VS Code now; do not continue this executor cycle.' -ForegroundColor Red
        }
        exit 10
    }
    # Any non-10 outcome means the absorbing form is not currently observed: the
    # streak and the short-cycle flag reset with it (#3605).
    Clear-BlockageState -StatePath (Get-BlockageStatePath)
    if ($freshExit -ne 0) {
        throw "ensure-build-fresh.ps1 could not guarantee freshness (exit $freshExit)."
    }

    # #3169 option (b): WARN, never a blocking exit — the executor cycle continues,
    # the silent cadence killer just becomes visible at every pre-flight.
    $oauthExpiredSessions = @(Find-OAuthExpirySignal)
    if ($oauthExpiredSessions.Count -gt 0) {
        $firstSessions = ($oauthExpiredSessions | Select-Object -First 3) -join ', '
        Write-Warning ("[executor-preflight][OAUTH-EXPIRED] {0} local session(s) hit 'OAuth session expired' API errors in the last 48h: {1}. Executor cadence can die silently while the session looks alive — re-auth via /login is INTERACTIVE-ONLY (#3169)." -f $oauthExpiredSessions.Count, $firstSessions)
    }

    # #4340: deny-sans-repli probe (handshake, never flags). Same WARN-never-block
    # posture as #3169 above: a finding means the affected CAPABILITY (notebook
    # editing on a NotebookEdit-deny seat) is impossible and must never be worked
    # around — the cycle itself continues, the standing signal stays visible at
    # every pre-flight until the workspace decides to provision the fallback
    # (per-workspace arbitration 24/10, #4340 point 4 — no blind fleet deploy).
    # Absent script = older checkout: skip silently, the pull above brings it.
    $denyProbe = Join-Path $RepoRoot 'scripts/diagnostic/check-deny-fallback.py'
    if (Test-Path $denyProbe) {
        # Merge stderr at the cmd.exe layer (#3731 class): the probe writes its
        # findings to stdout but python can chatter on stderr on a clean run.
        $probeOutput = @(& cmd /c "python ""$denyProbe"" --workspace ""$RepoRoot"" 2>&1" | ForEach-Object { "$_" })
        foreach ($line in $probeOutput) { Write-Host $line }
        $probeExit = $LASTEXITCODE
        if ($probeExit -eq 2) {
            Write-Warning ("[executor-preflight][DENY-FALLBACK] deny-sans-repli finding above: a denied tool's designated fallback does not answer on this seat. The capability is BLOCKED — never work around it (no .ipynb JSON bytesplice, no NotebookEdit). Relay [WARN]+[ASK] on the workspace dashboard; provisioning is a per-workspace user decision (#4340). The cycle continues.")
        } elseif ($probeExit -ne 0) {
            Write-Warning ("[executor-preflight][DENY-FALLBACK] probe instrument error (exit $probeExit) — the deny-fallback state is UNKNOWN this cycle. Relay [WARN] on the workspace dashboard.")
        }
    }

    # #4336: fleet-manifest drift check (read-only, measured 0.117 s median over
    # 5 runs on ai-01). The MCP state a seat carries cannot be read from inside
    # the session it affects: location 3 disables are indexed by the ABSOLUTE
    # workspace path, so a relocated workspace silently re-enables a server
    # (#4195) and nothing in the session says so. Same WARN-never-block posture
    # as #3169/#4340 above — the pre-flight never fails on drift.
    # Absent script = older checkout: skip silently, the pull above brings it.
    $manifestCheck = Join-Path $RepoRoot 'scripts/diagnostic/verify-fleet-manifest.py'
    if (Test-Path $manifestCheck) {
        $manifestOutput = @(& cmd /c "python ""$manifestCheck"" --workspace ""$RepoRoot"" 2>&1" | ForEach-Object { "$_" })
        foreach ($line in $manifestOutput) { Write-Host $line }
        $manifestExit = $LASTEXITCODE
        if ($manifestExit -eq 2) {
            Write-Warning '[executor-preflight][MANIFEST-DRIFT] live MCP config deviates from .claude/configs/fleet-manifest.json (finding above). Relay [WARN] on the workspace dashboard: a required server missing or disabled means this seat cannot do its job. Repair the config, or record an explicit override in the manifest — never work around a missing required server, and never re-enable a workspace disable blind.'
        } elseif ($manifestExit -ne 0) {
            Write-Warning ("[executor-preflight][MANIFEST-DRIFT] verifier instrument error (exit $manifestExit) — declared-vs-live MCP state is UNKNOWN this cycle. Relay [WARN] on the workspace dashboard.")
        }
    }

    # #4289 grain h-RSM: a seat whose RSM is suffering cannot report it through RSM, so
    # the coordinator reads silence as health (user, 27/10: "quand RSM est en souffrance,
    # tu ne vois rien"). This is the seat's own voice, printed at every pre-flight: host
    # count, max AND total private memory, free RAM, (cloud-only?) and connection-timeout
    # events today, median [dashboard-pg] latency. Same WARN-never-block posture as
    # #3169/#4340/#4336 above: exit 2 is relayed as a Write-Warning and the cycle
    # continues.
    # #4388 review: on WARN or instrument error the pre-flight posts the line ITSELF,
    # with no agent in the loop -- a relay "through RSM" is a relay through the very
    # component that is suffering, and it depends on an agent reading its own log.
    # Post through the #4385 dashboard CLI (machine escalation surface, WARN-class),
    # one stable message id per machine per UTC day so a re-fire cannot multiply
    # posts. If THAT post fails, the failure is itself the signal: fall back to
    # `gh issue comment 4289`, which depends on neither RSM nor GDrive. An OK seat
    # makes no noise.
    # Absent script = older checkout: skip silently, the pull above brings it.
    $rsmHealth = Join-Path $RepoRoot 'scripts/diagnostic/measure-rsm-health.ps1'
    if (Test-Path $rsmHealth) {
        # Merge stderr at the cmd.exe layer (#3731 class): on a WARN verdict the
        # instrument writes through Write-Warning, i.e. on stderr, and a PS-level 2>&1
        # under EAP=Stop would mint a terminating NativeCommandError from a clean run.
        $rsmHealthOutput = @(& cmd /c "powershell.exe -NoProfile -ExecutionPolicy Bypass -File ""$rsmHealth"" 2>&1" | ForEach-Object { "$_" })
        foreach ($line in $rsmHealthOutput) { Write-Host $line }
        $rsmHealthExit = $LASTEXITCODE
        if ($rsmHealthExit -eq 2) {
            Write-Warning '[executor-preflight][RSM-HEALTH] the [RSM-HEALTH] line above is a WARN: this seat''s RSM is under strain (reasons in the line). The pre-flight posts it below, no agent in the loop. The cycle continues: this never blocks.'
        } elseif ($rsmHealthExit -ne 0) {
            Write-Warning ("[executor-preflight][RSM-HEALTH] instrument error (exit $rsmHealthExit) -- this seat's RSM health is UNKNOWN this cycle. The pre-flight posts that below. The cycle continues.")
        }
        if ($rsmHealthExit -ne 0) {
            $kind = if ($rsmHealthExit -eq 2) { 'warn' } else { 'instrument-error' }
            $healthLine = @($rsmHealthOutput | Where-Object { $_ -match '^\[RSM-HEALTH\]' }) | Select-Object -First 1
            if (-not $healthLine) {
                $healthLine = ('[RSM-HEALTH] no line emitted (instrument error, exit {0})' -f $rsmHealthExit)
            }
            $machineId = ($env:COMPUTERNAME).ToLowerInvariant()
            $msgId = '{0}:rsm-health:{1}' -f $machineId, (Get-Date).ToUniversalTime().ToString('yyyyMMdd')
            $content = ('[WARN] {0} -- RSM-HEALTH {1}, posted by the pre-flight (no agent in the loop): {2}' -f $machineId, $kind, $healthLine)

            $posted = $false
            $nodeCmd = Get-Command node -ErrorAction SilentlyContinue
            $dashboardCli = Join-Path $RepoRoot 'mcps\internal\servers\roo-state-manager\scripts\rsm-dashboard-append.mjs'
            if ($nodeCmd -and (Test-Path $dashboardCli)) {
                & $nodeCmd.Source $dashboardCli --machine $machineId --message-id $msgId --content $content | Out-Null
                if ($LASTEXITCODE -eq 0) { $posted = $true }
            }
            if ($posted) {
                Write-Warning ('[executor-preflight][RSM-HEALTH] WARN posted by the pre-flight itself to the machine dashboard (messageId {0}). The cycle continues.' -f $msgId)
            } else {
                # The dashboard post failing is itself a signal: GitHub depends on
                # neither RSM nor GDrive. #2368 applies to agents; a pre-flight has no
                # interactive identity to guard, gh posts as the machine account.
                Write-Warning '[executor-preflight][RSM-HEALTH] dashboard post failed -- falling back to a comment on issue 4289.'
                $ghCmd = Get-Command gh -ErrorAction SilentlyContinue
                if ($ghCmd) {
                    $bodyFile = Join-Path ([System.IO.Path]::GetTempPath()) ('rsm-health-{0}-{1}.md' -f $machineId, (Get-Date).ToUniversalTime().ToString('yyyyMMddHHmmss'))
                    try {
                        [System.IO.File]::WriteAllText($bodyFile, $content, (New-Object System.Text.UTF8Encoding($false)))
                        & $ghCmd.Source issue comment 4289 --repo jsboige/roo-extensions --body-file $bodyFile | Out-Null
                        if ($LASTEXITCODE -eq 0) {
                            Write-Warning '[executor-preflight][RSM-HEALTH] WARN posted as a fallback comment on issue 4289. The cycle continues.'
                        } else {
                            Write-Warning '[executor-preflight][RSM-HEALTH] gh fallback failed too (exit code above) -- the WARN lives only in this log. The cycle continues.'
                        }
                    } finally {
                        Remove-Item -LiteralPath $bodyFile -ErrorAction SilentlyContinue
                    }
                } else {
                    Write-Warning '[executor-preflight][RSM-HEALTH] gh not found -- the WARN lives only in this log. The cycle continues.'
                }
            }
        }
    }

    Write-Host '[executor-preflight][READY] Parent, submodule, and RSM build are synchronized.' -ForegroundColor Green
    exit 0
} catch {
    # A failed pre-flight does not observe the absorbing form either: reset the
    # streak rather than escalate on memory (#3605).
    Clear-BlockageState -StatePath (Get-BlockageStatePath)
    # #3605-incident: when the failing statement throws a non-Exception ErrorRecord
    # (NativeCommandError from the ensure-build-fresh helper, for instance), `$_.Exception`
    # is `$null`. `$_.Exception.Message` then throws another NullReferenceException
    # that masks the original error — the user sees "[BLOCKED] " with no actionable
    # content. `$_.ToString()` is safe in every case (ErrorRecord and Exception
    # both implement it) and includes the CategoryInfo / FullyQualifiedErrorId for
    # native errors.
    $detail = if ($_.Exception) { $_.Exception.Message } else { $_.ToString() }
    if ([string]::IsNullOrWhiteSpace($detail)) { $detail = $_.ToString() }
    Write-Error "[executor-preflight][BLOCKED] $detail"
    exit 1
}
