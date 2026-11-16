# Pester tests for start-copilot-dispatcher.ps1 — #3641 §3 (gh issue -R repo pin).
#
# The defect: the dispatcher's scheduled task runs with -WorkingDirectory = the
# roo-extensions clone, so bare `gh issue view/list` queries roo-extensions
# regardless of the lane's target repo — a copilot-target label on the real
# queue repo (e.g. CoursIA) was inert. The fix: derive the owner/name slug from
# the TARGET repo's own origin remote and pass `-R <slug>` explicitly
# (mirrors start-vibe-worker.ps1:212).
#
# Pattern (start-claude-worker suite): the decision core (Get-RepoSlug) is
# extracted from the SHIPPED source, never re-typed, and driven with mocked
# `git remote get-url origin` output. The wiring (the slug passed as -Repo to
# both REST issue queries, #4641) is asserted on the raw source.
#
# Run:  powershell -File scripts/testing/run-pester-tests.ps1 -Path scripts/scheduling/start-copilot-dispatcher.Tests.ps1

BeforeAll {
    $target = Join-Path $PSScriptRoot 'start-copilot-dispatcher.ps1'
    $script:src = Get-Content -LiteralPath $target -Raw
}

Describe 'start-copilot-dispatcher.ps1 — Get-RepoSlug decision core (behavioral)' {
    BeforeAll {
        # Extract the SHIPPED function (first column-0 closing brace = its own end).
        $m = [regex]::Match($script:src, '(?s)(function Get-RepoSlug \{.*?\r?\n\})')
        if (-not $m.Success) { throw 'Get-RepoSlug not found in start-copilot-dispatcher.ps1' }
        Invoke-Expression $m.Groups[1].Value
    }

    It 'https remote with .git suffix → owner/repo' {
        Mock git { 'https://github.com/jsboige/CoursIA.git' }
        Get-RepoSlug -RepositoryRoot 'D:\Dev\CoursIA' | Should -Be 'jsboige/CoursIA'
    }

    It 'https remote without .git suffix → owner/repo' {
        Mock git { 'https://github.com/jsboige/CoursIA' }
        Get-RepoSlug -RepositoryRoot 'D:\Dev\CoursIA' | Should -Be 'jsboige/CoursIA'
    }

    It 'ssh remote (git@github.com:owner/repo.git) → owner/repo' {
        Mock git { 'git@github.com:jsboige/CoursIA.git' }
        Get-RepoSlug -RepositoryRoot 'D:\Dev\CoursIA' | Should -Be 'jsboige/CoursIA'
    }

    It 'non-github remote → $null (caller falls back to cwd resolution, previous behavior)' {
        Mock git { 'https://gitlab.com/jsboige/CoursIA.git' }
        Get-RepoSlug -RepositoryRoot 'D:\Dev\CoursIA' | Should -BeNullOrEmpty
    }

    It 'empty remote output → $null' {
        Mock git { '' }
        Get-RepoSlug -RepositoryRoot 'D:\Dev\CoursIA' | Should -BeNullOrEmpty
    }
}

Describe 'start-copilot-dispatcher.ps1 — #3641 §3 wiring (the target slug reaches both issue queries)' {
    # Since #4150 lot 7a (#4641) the two queries go through the REST helpers of
    # scripts/common/gh-issues.ps1 (-Repo <slug>) instead of `gh issue ... -R`.
    # The pin is the same contract: the slug derived from the TARGET repo, never
    # the scheduler's cwd.
    It 'derives $repoSlug from the target repo inside Get-TargetIssue' {
        $script:src | Should -Match '\$repoSlug = Get-RepoSlug -RepositoryRoot \$RepositoryRoot'
    }

    It 'seed-issue lookup carries the target slug' {
        $script:src | Should -Match 'Get-IssueDetail -Repo \$repoSlug -Number \$PreferredIssueNumber'
    }

    It 'copilot-target pool query carries the target slug' {
        $script:src | Should -Match "Get-IssueSummary -Repo \`$repoSlug -Labels @\('copilot-target'\)"
    }

    It 'every issue query is pinned and no bare gh issue call remains (denominator)' {
        # Code lines only: comments quote `gh issue list` in prose and must NOT count.
        $code = @($script:src -split '\r?\n' | Where-Object { $_ -notmatch '^\s*#' })
        @($code | Where-Object { $_ -match '\bgh issue (view|list)\b' }) | Should -BeNullOrEmpty
        $callLines = @($code | Where-Object { $_ -match '\bGet-Issue(Detail|Summary)\b' })
        $callLines | Should -HaveCount 2
        @($callLines | Where-Object { $_ -notmatch '-Repo \$repoSlug\b' }) | Should -BeNullOrEmpty
    }
}

Describe 'start-copilot-dispatcher.ps1 — #4766 skip reason distinguishes the pool causes (behavioral)' {
    BeforeAll {
        foreach ($fn in 'Test-IsActionableIssue', 'Get-TargetSkipMessage', 'Get-TargetIssue') {
            $m = [regex]::Match($script:src, "(?s)(function $fn \{.*?\r?\n\})")
            if (-not $m.Success) { throw "$fn not found in start-copilot-dispatcher.ps1" }
            Invoke-Expression $m.Groups[1].Value
        }
        function Get-IssueSummary { param($Repo, $Labels, $ExcludeLabels, $MaxCount) $global:PoolResult }
    }

    BeforeEach { $script:TargetSkipReason = $null }

    It 'pool-query-failed: query error is distinguishable' {
        $global:PoolResult = @{ Ok = $false; Items = @() }
        Get-TargetIssue -RepositoryRoot 'x' -RepoSlug 'o/r' | Should -BeNullOrEmpty
        $msg = Get-TargetSkipMessage -Reason $script:TargetSkipReason
        $msg | Should -Match 'pool-query-failed'
        $msg | Should -Not -Match 'pool-empty|none-actionable'
    }

    It 'pool-empty: says 0 open issues labeled copilot-target and coordinator provisioning' {
        $global:PoolResult = @{ Ok = $true; Items = @() }
        Get-TargetIssue -RepositoryRoot 'x' -RepoSlug 'o/r' | Should -BeNullOrEmpty
        $msg = Get-TargetSkipMessage -Reason $script:TargetSkipReason
        $msg | Should -Match '0 open issues labeled copilot-target'
        $msg | Should -Match 'coordinator'
    }

    It 'none-actionable: says N in pool, 0 actionable' {
        $global:PoolResult = @{ Ok = $true; Items = @(@{ number = 1; title = 'heartbeat listener'; labels = @() }, @{ number = 2; title = 'triage meta'; labels = @() }) }
        Get-TargetIssue -RepositoryRoot 'x' -RepoSlug 'o/r' | Should -BeNullOrEmpty
        Get-TargetSkipMessage -Reason $script:TargetSkipReason | Should -Match '2 in pool, 0 actionable'
    }

    It 'skip stays fail-closed: idle, zero premium, reason wired into the skip log' {
        $script:src | Should -Match 'Write-Log \(Get-TargetSkipMessage -Reason \$script:TargetSkipReason\)'
        $script:src | Should -Match "(?s)Get-TargetSkipMessage -Reason.*?\`$status = 'idle'.*?premiumRequests = 0\.0"
    }
}

Describe 'start-copilot-dispatcher.ps1 — 16/11 delivery verification (exit 0 is not a delivery)' {
    # Mandate user 16/11: every paid call carries a verifiable terminal state —
    # a PR (URL + state) or an explicit non-delivery with a cause. The negative
    # cases below are the point: exit 0 / PROMPT_OK must never read as success
    # when no PR carries the work.
    BeforeAll {
        foreach ($fn in 'Invoke-GitCapture', 'Select-DeliveryPr', 'Resolve-CopilotDelivery') {
            $m = [regex]::Match($script:src, "(?s)(function $fn \{.*?\r?\n\})")
            if (-not $m.Success) { throw "$fn not found in start-copilot-dispatcher.ps1" }
            Invoke-Expression $m.Groups[1].Value
        }
        function New-DeliveryLocal {
            param([string]$Head = 'aaa', [int]$Commits = 0, [bool]$Dirty = $false, [bool]$Ok = $true)
            @{ Ok = $Ok; HeadSha = $Head; CommitCount = $Commits; Dirty = $Dirty; Error = $(if ($Ok) { '' } else { 'boom' }) }
        }
        function New-DeliveryPrResult {
            param([bool]$Ok = $true, [object[]]$Items = @(), [string]$Error = '')
            [pscustomobject]@{ Ok = $Ok; Items = $Items; Error = $Error }
        }
        function New-DeliveryPr {
            param([int]$Number = 12, [string]$State = 'OPEN', [string]$HeadSha = 'aaa', [string]$Url = 'https://example.test/pr/12')
            [pscustomobject]@{ Number = $Number; State = $State; Url = $Url; HeadSha = $HeadSha }
        }
    }

    BeforeEach {
        # Containment probe default: instrument blind (exit 1). Cases that need
        # a count override this mock.
        Mock Invoke-GitCapture { @{ ExitCode = 1; Output = '' } }
    }

    It 'delivered: PR head equals local HEAD' {
        $pr = New-DeliveryPrResult -Items @(New-DeliveryPr -State 'MERGED' -HeadSha 'aaa')
        $d = Resolve-CopilotDelivery -PrResult $pr -Local (New-DeliveryLocal -Commits 1) -WorkRoot 'x'
        $d.Outcome | Should -Be 'delivered'
        $d.PrNumber | Should -Be 12
        $d.PrUrl | Should -Be 'https://example.test/pr/12'
        $d.PrState | Should -Be 'MERGED'
    }

    It 'pr-closed: a closed unmerged PR is NOT a delivery' {
        $pr = New-DeliveryPrResult -Items @(New-DeliveryPr -State 'CLOSED' -HeadSha 'aaa')
        $d = Resolve-CopilotDelivery -PrResult $pr -Local (New-DeliveryLocal -Commits 1) -WorkRoot 'x'
        $d.Outcome | Should -Be 'pr-closed'
        $d.Reason | Should -Match 'closed without merge'
    }

    It 'commits-without-pr: commits on the branch and no PR' {
        $d = Resolve-CopilotDelivery -PrResult (New-DeliveryPrResult) -Local (New-DeliveryLocal -Commits 2) -WorkRoot 'x'
        $d.Outcome | Should -Be 'commits-without-pr'
        $d.Reason | Should -Match '2 commit'
    }

    It 'dirty-without-commit: uncommitted work and no PR' {
        $d = Resolve-CopilotDelivery -PrResult (New-DeliveryPrResult) -Local (New-DeliveryLocal -Commits 0 -Dirty $true) -WorkRoot 'x'
        $d.Outcome | Should -Be 'dirty-without-commit'
    }

    It 'no-production: clean worktree, zero commits, no PR' {
        $d = Resolve-CopilotDelivery -PrResult (New-DeliveryPrResult) -Local (New-DeliveryLocal -Commits 0) -WorkRoot 'x'
        $d.Outcome | Should -Be 'no-production'
    }

    It 'commits-without-pr: PR exists but local HEAD carries commits the PR does not contain' {
        Mock Invoke-GitCapture { @{ ExitCode = 0; Output = '2' } }
        $pr = New-DeliveryPrResult -Items @(New-DeliveryPr -State 'OPEN' -HeadSha 'bbb')
        $d = Resolve-CopilotDelivery -PrResult $pr -Local (New-DeliveryLocal -Head 'aaa' -Commits 3) -WorkRoot 'x'
        $d.Outcome | Should -Be 'commits-without-pr'
        $d.CommitsAheadOfPr | Should -Be 2
        $d.Reason | Should -Match 'not contained in PR #12'
    }

    It 'unverified: a failed PR query is never reported as delivered' {
        $pr = New-DeliveryPrResult -Ok $false -Error 'gh api exit 1'
        $d = Resolve-CopilotDelivery -PrResult $pr -Local (New-DeliveryLocal -Commits 1) -WorkRoot 'x'
        $d.Outcome | Should -Be 'unverified'
        $d.Reason | Should -Match 'PR query failed'
    }

    It 'unverified: local work evidence failure blocks, never delivers' {
        $pr = New-DeliveryPrResult -Items @(New-DeliveryPr -State 'OPEN' -HeadSha 'aaa')
        $d = Resolve-CopilotDelivery -PrResult $pr -Local (New-DeliveryLocal -Ok $false) -WorkRoot 'x'
        $d.Outcome | Should -Be 'unverified'
        $d.Reason | Should -Match 'local work evidence unavailable'
    }

    It 'unverified: a PR whose containment cannot be proven is not a delivery' {
        $pr = New-DeliveryPrResult -Items @(New-DeliveryPr -State 'OPEN' -HeadSha 'bbb')
        $d = Resolve-CopilotDelivery -PrResult $pr -Local (New-DeliveryLocal -Head 'aaa' -Commits 1) -WorkRoot 'x'
        $d.Outcome | Should -Be 'unverified'
        $d.Reason | Should -Match 'cannot prove'
    }

    It 'delivered: PR contains HEAD and the pre-dispatch witness shows the run moved it (no HeadBefore = witness off, same verdict)' {
        $pr = New-DeliveryPrResult -Items @(New-DeliveryPr -State 'OPEN' -HeadSha 'aaa')
        $d = Resolve-CopilotDelivery -PrResult $pr -Local (New-DeliveryLocal -Head 'aaa' -Commits 1) -WorkRoot 'x' -HeadBefore '000'
        $d.Outcome | Should -Be 'delivered'
        $d = Resolve-CopilotDelivery -PrResult $pr -Local (New-DeliveryLocal -Head 'aaa' -Commits 1) -WorkRoot 'x'
        $d.Outcome | Should -Be 'delivered'
    }

    It 'dirty-without-commit: a PR that carries the commits does NOT carry uncommitted edits (review #4791 R1)' {
        $pr = New-DeliveryPrResult -Items @(New-DeliveryPr -State 'OPEN' -HeadSha 'aaa')
        $d = Resolve-CopilotDelivery -PrResult $pr -Local (New-DeliveryLocal -Head 'aaa' -Commits 1 -Dirty $true) -WorkRoot 'x' -HeadBefore '000'
        $d.Outcome | Should -Be 'dirty-without-commit'
        $d.PrNumber | Should -Be 12
        $d.Reason | Should -Match 'uncommitted changes remain alongside PR #12'
    }

    It 'no-production relic: reused branch, PR from an earlier run, HEAD unmoved by this call (review #4791 R2)' {
        $pr = New-DeliveryPrResult -Items @(New-DeliveryPr -State 'OPEN' -HeadSha 'aaa')
        $d = Resolve-CopilotDelivery -PrResult $pr -Local (New-DeliveryLocal -Head 'aaa' -Commits 1) -WorkRoot 'x' -HeadBefore 'aaa'
        $d.Outcome | Should -Be 'no-production'
        $d.Reason | Should -Match 'earlier pass on this reused branch'
    }

    It 'dirty beats relic: unmoved HEAD but a dirtied tree is unrelayed work, never no-production (R1 precedence over R2)' {
        $pr = New-DeliveryPrResult -Items @(New-DeliveryPr -State 'MERGED' -HeadSha 'aaa')
        $d = Resolve-CopilotDelivery -PrResult $pr -Local (New-DeliveryLocal -Head 'aaa' -Commits 1 -Dirty $true) -WorkRoot 'x' -HeadBefore 'aaa'
        $d.Outcome | Should -Be 'dirty-without-commit'
    }

    It 'wiring: the verification is decoupled from the $isIdleLike heuristic and the outcome can RAISE the status (review #4791, ai-01)' {
        # The guard keys on geometry + branch ONLY — no $dispatch.status gate.
        $script:src | Should -Match 'Get-CopilotDeliveryState -RepositorySlug \$queueSlug -WorkRoot \$workRoot -Branch'
        $callSite = @($script:src -split '\r?\n' | Where-Object { $_ -match 'Get-CopilotDeliveryState -RepositorySlug' })
        @($callSite | Where-Object { $_ -match 'dispatch\.status' }) | Should -BeNullOrEmpty
        # The pre-dispatch witness reaches the resolver.
        $script:src | Should -Match '-HeadBefore \(\[string\]\$dispatch\.headBefore\)'
        # delivered sets active EXPLICITLY (an idle-like text must not cap it).
        $script:src | Should -Match "'delivered' \{ \`$status = 'active' \}"
        $script:src | Should -Match "'no-production' \{ \`$status = 'idle' \}"
        $script:src | Should -Match "default \{ \`$status = 'blocked' \}"
        # The contradictory legacy reason is gone.
        $script:src | Should -Not -Match 'exit 0 without repository change'
        # Phase C exposes the witnesses the relic check leans on.
        $script:src | Should -Match '\$result\.headBefore = \$beforeHead'
        $script:src | Should -Match '\$result\.headAfter = \$afterHead'
        $stateBlock = @($script:src -split '\r?\n' | Where-Object { $_ -match '\$state\.lastDeliveryPrUrl = \[string\]\$delivery\.PrUrl' })
        $stateBlock | Should -HaveCount 1
        $script:src | Should -Match "\`$state\.lastDeliveryOutcome = 'phase-c-failed'"
        $script:src | Should -Match "\`$state\.lastDeliveryOutcome = 'not-attempted'"
    }

    It 'wiring: the scheduled call arms the head witness exactly when delivery is verifiable (-DetectHeadMoves:$canDeliver) (post-merge follow-up, ai-01)' {
        # The relic check (no-production on a reused branch whose HEAD the run
        # did not move) is only sound when the pre-dispatch HEAD witness
        # exists. Invoke-PhaseCDispatch populates headBefore/headAfter under
        # -DetectHeadMoves; the scheduled call must arm it exactly when
        # $canDeliver (geometry allows a delivery) — dropping the switch would
        # silently degrade every relic verdict to "witness unavailable: skip".
        $script:src | Should -Match '-DetectHeadMoves:\$canDeliver'
        # The switch is a declared parameter of the dispatch function.
        $script:src | Should -Match '\[switch\]\$DetectHeadMoves'
        # Exactly ONE scheduled call site, and it carries the switch.
        $allCalls = @($script:src -split '\r?\n' | Where-Object { $_ -match '\$dispatch = Invoke-PhaseCDispatch' })
        $allCalls | Should -HaveCount 1
        @($allCalls | Where-Object { $_ -match '-DetectHeadMoves:\$canDeliver' }) | Should -HaveCount 1
    }
}