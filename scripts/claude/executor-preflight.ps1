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
    $branchRaw = & git -C $RepoRoot branch --show-current 2>&1
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

    Invoke-GitChecked @('fetch', 'origin')
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
    # PS 5.1 wraps redirected child-stderr in ErrorRecords and EAP=Stop turns
    # the first one into a terminating NativeCommandError (measured 14/09):
    # relax around the call, restore right after.
    $savedEap = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $helperOutput = @(& powershell.exe -ExecutionPolicy Bypass -File $helper -RepoRoot $RepoRoot -RequireFresh 2>&1 | ForEach-Object { "$_" })
    $ErrorActionPreference = $savedEap
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
