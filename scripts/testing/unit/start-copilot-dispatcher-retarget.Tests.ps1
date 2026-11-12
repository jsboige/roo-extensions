# Pester 5 tests: the Copilot dispatcher's foreign-repo re-targeting (#622
# harness-change, directive user 05/11 — the three items named by po-2025's
# 05/11 report on the issue).
#
# What these tests pin:
#   1. -TargetRepoSlug moves the issue POOL to the target repo (the gh call
#      carries -R <slug>) instead of deriving the slug from roo-extensions.
#   2. Work on a foreign repo lands in an isolated per-issue worktree
#      (.claude/worktrees/wt-copilot-<issue>, branch wt/copilot-*), reused
#      across runs on the same issue — never in the target's main checkout.
#   3. The commit/PR ban is LIFTED in the work-tree prompt only: the default
#      prompt keeps the prohibition, the isolated one mandates branch+PR and
#      forbids touching a default branch.
#   4. A slug without a usable -TargetRepoPath blocks BEFORE any Copilot call
#      (fail-closed, zero premium burn) — asserted as wiring, since running
#      the whole script in a test would issue a real dispatch.
#
# Design notes (same doctrine as start-copilot-dispatcher-payload.Tests.ps1):
# * Shipped functions are extracted from the source text, never re-typed.
# * Initialize-CopilotWorktree logs via Write-Log; a stub is defined BEFORE
#   extraction so the extracted function resolves the stub at call time.
# * gh is stubbed as a FUNCTION: `& gh ...` resolves functions, so the pool
#   query can be captured without touching the network.
#
# Run:  powershell -File scripts/testing/run-pester-tests.ps1 -Path scripts/testing/unit/start-copilot-dispatcher-retarget.Tests.ps1

BeforeAll {
    $script:productionScript = Join-Path $PSScriptRoot '../../scheduling/start-copilot-dispatcher.ps1'
    $script:src = Get-Content -LiteralPath $script:productionScript -Raw

    # Stub the dispatcher's logger before extracting functions that call it.
    $script:logLines = @()
    function Write-Log {
        param([string]$Message)
        $script:logLines += $Message
    }

    foreach ($name in @('Get-WorkPrompt', 'Initialize-CopilotWorktree', 'Get-TargetIssue', 'Get-RepoSlug', 'Invoke-PhaseCDispatch', 'Write-CopilotPromptFile', 'ConvertTo-NativeArg', 'Get-DispatchArgv', 'Convert-JsonWorkReport', 'Get-SanitizedReport')) {
        $m = [regex]::Match($script:src, "(?s)(function $name \{.*?\r?\n\})")
        if (-not $m.Success) { throw "$name not found in start-copilot-dispatcher.ps1" }
        Invoke-Expression $m.Groups[1].Value
    }

    # gh stub: `& gh ...` resolves this function; capture argv, serve one
    # actionable candidate (label-free title, updatedAt present).
    $script:ghCalls = @()
    function gh {
        param([Parameter(ValueFromRemainingArguments = $true)][object[]]$Arguments)
        $script:ghCalls += , @($Arguments)
        return '[{"number":7,"title":"T fix wording","labels":[],"updatedAt":"2026-11-10T00:00:00Z","url":"https://example.invalid/7"}]'
    }

    # Lot 7a (#4150): Get-TargetIssue's discovery legs live in the REST module
    # (gh-issues.ps1) — dot-source the REAL module so the extracted function
    # exercises the production path over the stubbed gh (same philosophy as
    # the extraction above: stub the gh boundary, not the module contract).
    . (Join-Path $PSScriptRoot '../../common/gh-issues.ps1')
}

Describe 'start-copilot-dispatcher.ps1 — #622 re-targeting: issue pool follows -TargetRepoSlug' {

    It 'passes the explicit slug into the REST pool query (pool moves to the target repo)' {
        # Lot 7a (#4150): the pool leg is `gh api repos/{slug}/issues?...&labels=copilot-target`
        # (module gh-issues.ps1) — the slug lives in the URL, no `-R` flag anymore.
        $null = Get-TargetIssue -RepositoryRoot $TestDrive -PreferredIssueNumber 0 -RepoSlug 'jsboige/CoursIA'
        $poolCall = $script:ghCalls | Where-Object { ($_ -join ' ') -match 'repos/jsboige/CoursIA/issues\?' } | Select-Object -First 1
        $poolCall | Should -Not -BeNullOrEmpty
        # Pool semantics ride along: the server-side label filter is part of the query.
        ($poolCall -join ' ') | Should -Match 'labels=copilot-target'
    }

    It 'without -RepoSlug and none derivable, gh is never called (fail-closed at the module binding)' {
        $script:ghCalls = @()
        $null = Get-TargetIssue -RepositoryRoot $TestDrive -PreferredIssueNumber 0
        # Stronger than the pre-lot-7a "no -R" pin: with an empty slug the
        # module's Mandatory -Repo binding refuses BEFORE any gh invocation.
        @($script:ghCalls).Count | Should -Be 0
    }
}

Describe 'start-copilot-dispatcher.ps1 — #622 re-targeting: isolated per-issue worktree' {

    BeforeAll {
        # A real throwaway git repo: init + one seed commit on a default
        # branch. The identity is set REPO-LOCALLY: CI runners (ubuntu) have
        # no global git user, and without it the seed commit dies silently
        # under 2>$null, leaving an unborn HEAD that makes every
        # `git worktree add` fail — measured on the first CI run of this
        # suite (3 reds, $wt = $null).
        $script:tmpRepo = Join-Path $TestDrive 'repo'
        New-Item -ItemType Directory -Path $script:tmpRepo | Out-Null
        & git -C $script:tmpRepo init -q -b main 2>$null
        if ($LASTEXITCODE -ne 0) {
            # Pre-2.28 git has no -b: plain init, the branch name is
            # irrelevant to what these tests exercise.
            & git -C $script:tmpRepo init -q 2>$null
        }
        & git -C $script:tmpRepo config user.name 'copilot-dispatcher-test'
        & git -C $script:tmpRepo config user.email 'copilot-test@example.invalid'
        & git -C $script:tmpRepo commit -q --allow-empty -m 'seed'
        if ($LASTEXITCODE -ne 0) {
            # An unborn-HEAD repo cannot host worktrees; a silent seed
            # failure makes every test in this block fail opaquely.
            throw 'seed commit failed in the temporary test repo (git identity?)'
        }
    }

    # NIT 3 (ai-01): the name said `wt-copilot-<issue>`, which reads as Pester
    # data-driven interpolation (`<param>` with -TestCases) — it is a literal.
    # Named with the concrete issue number the test actually uses instead.
    It 'creates .claude/worktrees/wt-copilot-42 on a wt/copilot-* branch' {
        $wt = Initialize-CopilotWorktree -RepositoryRoot $script:tmpRepo -IssueNumber 42
        $wt | Should -Not -BeNullOrEmpty
        $wt.Path | Should -Be "$script:tmpRepo/.claude/worktrees/wt-copilot-42"
        (Test-Path $wt.Path) | Should -BeTrue
        $wt.Branch | Should -Match '^wt/copilot-42-\d{8}-\d{6}$'
    }

    It 'reuses the existing worktree on a second dispatch for the same issue (continuity, not a second copy)' {
        $first = Initialize-CopilotWorktree -RepositoryRoot $script:tmpRepo -IssueNumber 42
        $second = Initialize-CopilotWorktree -RepositoryRoot $script:tmpRepo -IssueNumber 42
        $second.Reused | Should -BeTrue
        $second.Path | Should -Be $first.Path
        $second.Branch | Should -Be ($first.Branch)
    }

    It 'a distinct issue gets its own worktree (no cross-issue reuse)' {
        $wt43 = Initialize-CopilotWorktree -RepositoryRoot $script:tmpRepo -IssueNumber 43
        $wt43.Path | Should -Be "$script:tmpRepo/.claude/worktrees/wt-copilot-43"
        (Test-Path "$script:tmpRepo/.claude/worktrees/wt-copilot-43") | Should -BeTrue
    }

    It 'survives git stderr under ErrorActionPreference=Stop (PS 5.1 native trap)' {
        # The production script runs under EAP=Stop (line 37). `git worktree
        # add` writes "Preparing worktree (...)" to stderr on a SUCCESSFUL run;
        # in PS 5.1 that is a TERMINATING NativeCommandError even with
        # `2>$null` (measured 11/11 on the first retargeted dispatch: worktree
        # branched, script dead before any Copilot call).
        #
        # HONEST LIMIT: the behavioral half only discriminates on a PS 5.1
        # host. CI's unit-pester job runs pwsh on ubuntu, where native stderr
        # never terminates — the pre-fix code passes it too (measured). The
        # source pin below is what reddens in CI; the true pre-fix
        # discriminator was a manual PS 5.1 run (PR body of the fix).
        $prevEap = $ErrorActionPreference
        $ErrorActionPreference = 'Stop'
        try {
            $wt = Initialize-CopilotWorktree -RepositoryRoot $script:tmpRepo -IssueNumber 77
        } finally {
            $ErrorActionPreference = $prevEap
        }
        $wt | Should -Not -BeNullOrEmpty
        $wt.Path | Should -Be "$script:tmpRepo/.claude/worktrees/wt-copilot-77"
        (Test-Path $wt.Path) | Should -BeTrue

        # Source pin (host-independent): the worktree-add call site must stay
        # EAP-scoped — guard before it, restore after it.
        $fnPos = $script:src.IndexOf('function Initialize-CopilotWorktree')
        $guardPos = $script:src.IndexOf("`$ErrorActionPreference = 'Continue'", $fnPos)
        $addPos = $script:src.IndexOf('worktree add $worktreeDir', $fnPos)
        $restorePos = $script:src.IndexOf('$ErrorActionPreference = $prevEap', $addPos)
        ($fnPos -ge 0 -and $guardPos -gt $fnPos -and $guardPos -lt $addPos) | Should -BeTrue
        ($restorePos -gt $addPos) | Should -BeTrue
    }
}

Describe 'start-copilot-dispatcher.ps1 — #622 re-targeting: delivery mandate in the prompt' {

    BeforeAll {
        $script:state = @{ lastStatus = 'none'; lastObservedPremiumRequests = 'unknown' }
        $script:issue = @{ number = 42; title = 'T fix wording' }
    }

    It 'default prompt keeps the commit/PR prohibition (blast radius unchanged on the home checkout)' {
        $p = Get-WorkPrompt -Profile 'balanced' -State $script:state -RepositoryRoot $TestDrive -TargetIssue $script:issue -CanDeliver:$false
        $p | Should -Match 'Do not create commits or pull requests'
        $p | Should -Not -Match 'gh pr create'
    }

    It 'isolated-worktree prompt mandates branch commit + PR and forbids default-branch mutation' {
        $p = Get-WorkPrompt -Profile 'balanced' -State $script:state -RepositoryRoot $TestDrive -TargetIssue $script:issue -CanDeliver:$true
        $p | Should -Match 'gh pr create'
        $p | Should -Match 'commit it on the CURRENT branch'
        $p | Should -Match 'Never push to, rebase onto, or mutate a default branch'
        $p | Should -Not -Match 'Do not create commits or pull requests'
    }
}

Describe 'start-copilot-dispatcher.ps1 — #622 wiring (fail-closed + bookkeeping)' {

    It 'a -TargetRepoSlug without a usable -TargetRepoPath blocks before any Copilot call' {
        $script:src | Should -Match 'given without a usable -TargetRepoPath'
        # The guard must assign blocked BEFORE the dispatch branch, i.e. above the target-issue lookup.
        $guardPos = $script:src.IndexOf('given without a usable -TargetRepoPath')
        $dispatchPos = $script:src.IndexOf('Invoke-PhaseCDispatch -Profile')
        ($guardPos -ge 0 -and $guardPos -lt $dispatchPos) | Should -BeTrue
    }

    It 'a -TargetRepoPath without -TargetRepoSlug blocks too (the pair is required together — review point 2)' {
        $script:src | Should -Match "given without -TargetRepoSlug - blocking before any Copilot call"
        $guardPos = $script:src.IndexOf('given without -TargetRepoSlug')
        $dispatchPos = $script:src.IndexOf('Invoke-PhaseCDispatch -Profile')
        ($guardPos -ge 0 -and $guardPos -lt $dispatchPos) | Should -BeTrue
        # Symmetry: BOTH guard branches assign blocked (neither half of the pair
        # may fall back silently to roo-extensions).
        $slugGuard = $script:src -split '\r?\n' | Where-Object { $_ -match 'given without a usable -TargetRepoPath' }
        @($slugGuard).Count | Should -BeGreaterThan 0
    }

    It 'the prompt file lives in the WORK root — Copilot sandbox cannot read outside its working directory' {
        # Measured 18:37Z on the first retargeted dispatch post-#4652 (#4649):
        # the pointer written under the dispatcher repo was refused ("path is
        # outside the working directory ... Permission denied, no one to
        # approve"), 17 premium requests for zero work. The call site passes NO
        # -PromptRepositoryRoot, so Phase C defaults the prompt root to
        # $workRoot — inside Copilot's working directory.
        $script:src | Should -Not -Match 'Invoke-PhaseCDispatch [^\r\n]*-PromptRepositoryRoot \$repoRoot'
        $script:src | Should -Match 'Invoke-PhaseCDispatch -Profile \$effectiveProfile -RepositoryRoot \$workRoot -Prompt \$workPrompt -DetectHeadMoves:\$canDeliver'
    }

    It 'delivery mode arms HEAD-move detection (review point 1 wiring)' {
        $script:src | Should -Match 'Invoke-PhaseCDispatch -Profile \$effectiveProfile -RepositoryRoot \$workRoot -Prompt \$workPrompt -DetectHeadMoves:\$canDeliver'
    }

    It 'foreign-repo work only ever runs through Initialize-CopilotWorktree (never the target main checkout)' {
        $script:src | Should -Match 'Initialize-CopilotWorktree -RepositoryRoot \$queueRepoRoot -IssueNumber'
    }

    It 'the run state records where work landed (host lane can find the worktree and branch)' {
        $script:src | Should -Match '\$state\.lastWorktreePath = \$workRoot'
        $script:src | Should -Match '\$state\.lastWorkBranch = \$copilotWt\.Branch'
        $script:src | Should -Match '\$state\.lastTargetRepoSlug = \$queueSlug'
        # NIT 2 pin: $workRoot/$copilotWt are initialized BEFORE the guard so the
        # bookkeeping above never reads an undefined variable on an early
        # blocked path (ai-01 approve review).
        $initPos = $script:src.IndexOf('$workRoot = $null')
        $guardPos = $script:src.IndexOf('if (-not [string]::IsNullOrWhiteSpace($TargetRepoSlug)) {')
        ($initPos -ge 0 -and $guardPos -ge 0 -and $initPos -lt $guardPos) | Should -BeTrue
    }
}

Describe 'start-copilot-dispatcher.ps1 — #622 delivery detection (a delivered commit is work, not idle)' {

    # Review point 1 (ai-01, 10/11): the delivery mandate is edit-then-commit,
    # and a fresh worktree goes clean -> clean. The porcelain diff alone reads
    # a successful delivery as "no repository change" -> status idle -> the
    # pilot counts successes as no-ops and the idle streak escalates cadence.
    # These tests simulate the CLI with a `copilot` FUNCTION (same resolution
    # trick as the gh stub) whose only action is an empty commit in the work
    # root — clean before, clean after, HEAD moved.

    BeforeAll {
        $script:tmpRepo2 = Join-Path $TestDrive 'repo-delivery'
        New-Item -ItemType Directory -Path $script:tmpRepo2 | Out-Null
        & git -C $script:tmpRepo2 init -q -b main 2>$null
        if ($LASTEXITCODE -ne 0) { & git -C $script:tmpRepo2 init -q 2>$null }
        # CI runners carry no global git identity (measured 10/11): repo-local
        # identity or the seed commit dies silently.
        & git -C $script:tmpRepo2 config user.name 'copilot-dispatcher-test'
        & git -C $script:tmpRepo2 config user.email 'copilot-test@example.invalid'
        & git -C $script:tmpRepo2 commit -q --allow-empty -m 'seed'
        if ($LASTEXITCODE -ne 0) { throw 'seed commit failed in the delivery test repo' }

        # Bookkeeping root OUTSIDE the repo under test: the prompt file is
        # untracked-visible in porcelain, and leaving it inside would make the
        # no-detection direction of the pair pass for the wrong reason.
        $script:promptRoot = Join-Path $TestDrive 'bookkeeping'

        # The stub MUST declare an explicit -p parameter: with a function,
        # PowerShell binds -p to the COMMON parameter -PipelineVariable
        # (abbreviation match) and rejects the prompt text as "not a valid
        # variable name" — a native binary would just take -p as its own flag.
        function copilot {
            param(
                [string]$p,
                [Parameter(ValueFromRemainingArguments = $true)][object[]]$Arguments
            )
            & git commit -q --allow-empty -m 'simulated copilot delivery'
            return 'work_summary: simulated delivery commit'
        }
    }

    It 'with -DetectHeadMoves, a clean->clean commit counts as work (status active)' {
        $r = Invoke-PhaseCDispatch -Profile 'balanced' -RepositoryRoot $script:tmpRepo2 -Prompt 'go' -PromptRepositoryRoot $script:promptRoot -DetectHeadMoves
        $r.exitCode | Should -Be 0
        $r.repositoryChanges | Should -BeTrue
        $r.status | Should -Be 'active'
    }

    It 'without -DetectHeadMoves, the same commit is invisible to porcelain (the pre-fix behavior, pinned)' {
        $r = Invoke-PhaseCDispatch -Profile 'balanced' -RepositoryRoot $script:tmpRepo2 -Prompt 'go' -PromptRepositoryRoot $script:promptRoot
        $r.exitCode | Should -Be 0
        $r.repositoryChanges | Should -BeFalse
        $r.status | Should -Be 'idle'
    }
}
