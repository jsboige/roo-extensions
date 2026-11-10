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

    foreach ($name in @('Get-WorkPrompt', 'Initialize-CopilotWorktree', 'Get-TargetIssue', 'Get-RepoSlug')) {
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
}

Describe 'start-copilot-dispatcher.ps1 — #622 re-targeting: issue pool follows -TargetRepoSlug' {

    It 'passes the explicit slug to gh as -R (pool moves to the target repo)' {
        $null = Get-TargetIssue -RepositoryRoot $TestDrive -PreferredIssueNumber 0 -RepoSlug 'jsboige/CoursIA'
        $poolCall = $script:ghCalls | Where-Object { $_ -contains 'list' } | Select-Object -First 1
        $poolCall | Should -Not -BeNullOrEmpty
        $idx = [array]::IndexOf($poolCall, '-R')
        $idx | Should -BeGreaterOrEqual 0
        $poolCall[$idx + 1] | Should -Be 'jsboige/CoursIA'
    }

    It 'without -RepoSlug, derives the slug from the repository root as before (no -R when none derivable)' {
        $script:ghCalls = @()
        $null = Get-TargetIssue -RepositoryRoot $TestDrive -PreferredIssueNumber 0
        $poolCall = $script:ghCalls | Where-Object { $_ -contains 'list' } | Select-Object -First 1
        if ($null -ne $poolCall) {
            ($poolCall -contains '-R') | Should -BeFalse
        }
    }
}

Describe 'start-copilot-dispatcher.ps1 — #622 re-targeting: isolated per-issue worktree' {

    BeforeAll {
        # A real throwaway git repo: init + one commit on a default branch.
        $script:tmpRepo = Join-Path $TestDrive 'repo'
        New-Item -ItemType Directory -Path $script:tmpRepo | Out-Null
        & git -C $script:tmpRepo init -q -b main 2>$null
        & git -C $script:tmpRepo -C $script:tmpRepo commit -q --allow-empty -m 'seed' 2>$null
        if ($LASTEXITCODE -ne 0) {
            & git -C $script:tmpRepo checkout -q -b main 2>$null
            & git -C $script:tmpRepo commit -q --allow-empty -m 'seed' 2>$null
        }
    }

    It 'creates .claude/worktrees/wt-copilot-<issue> on a wt/copilot-* branch' {
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

    It 'the dispatch hands the CLI the work root but keeps the prompt file in the dispatcher repo' {
        $script:src | Should -Match 'Invoke-PhaseCDispatch -Profile \$effectiveProfile -RepositoryRoot \$workRoot -Prompt \$workPrompt -PromptRepositoryRoot \$repoRoot'
    }

    It 'foreign-repo work only ever runs through Initialize-CopilotWorktree (never the target main checkout)' {
        $script:src | Should -Match 'Initialize-CopilotWorktree -RepositoryRoot \$queueRepoRoot -IssueNumber'
    }

    It 'the run state records where work landed (host lane can find the worktree and branch)' {
        $script:src | Should -Match '\$state\.lastWorktreePath = \$workRoot'
        $script:src | Should -Match '\$state\.lastWorkBranch = \$copilotWt\.Branch'
        $script:src | Should -Match '\$state\.lastTargetRepoSlug = \$queueSlug'
    }
}
