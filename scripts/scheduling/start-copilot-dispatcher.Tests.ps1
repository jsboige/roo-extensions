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
        # no-production sets idle (multi-line branch since #4806 fix 2 —
        # length-bounded: the branch body contains $(...) subexpression braces).
        $script:src | Should -Match "(?s)'no-production' \{.{0,1200}?\`$status = 'idle'"
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

Describe 'start-copilot-dispatcher.ps1 — 17/11 #4806: a delivered grain is never paid twice' {
    # Measured 16/11 21:28 tir: #4766 already delivered by MERGED PR #4783 was
    # picked again and paid 18.98 premium for nothing. Three fixes: skip with a
    # distinct already-delivered reason before ANY paid call (zero premium),
    # retire copilot-target after a no-production run, and the Phase C prompt
    # mandates 'Closes #N' (not a bare mention) so merges close the grain.
    BeforeAll {
        foreach ($fn in 'Select-DeliveredPr', 'Test-GrainAlreadyDelivered', 'Invoke-CopilotGhMutation', 'Invoke-CopilotIssueComment', 'Remove-CopilotTargetLabel', 'Get-WorkPrompt', 'Get-TargetSkipMessage') {
            $m = [regex]::Match($script:src, "(?s)(function $fn \{.*?\r?\n\})")
            if (-not $m.Success) { throw "$fn not found in start-copilot-dispatcher.ps1" }
            Invoke-Expression $m.Groups[1].Value
        }
        # Test-only stub: Test-GrainAlreadyDelivered delegates to the shared
        # REST helper (scripts/common/gh-pull-requests.ps1), which this file
        # never loads — the mock in the fail-closed test needs a command to
        # replace in THIS session state.
        function Get-PullRequestSummary { param([string]$Repo, [string]$State, [string]$Head, [switch]$IncludeBody, [int]$MaxCount) throw 'stub: mock me' }
    }

    It 'fix 1 (behavioral): Select-DeliveredPr matches a MERGED PR referencing the grain with a word boundary' {
        function New-DeliveredPr {
            param([int]$Number = 4783, [string]$State = 'MERGED', [string]$Title = 'test(scheduling,#4766): realign fixture', [string]$Body = 'Refs #4766', [string]$Url = 'https://example.test/pr/4783')
            [pscustomobject]@{ Number = $Number; State = $State; Title = $Title; Body = $Body; Url = $Url }
        }
        # body reference
        $hit = Select-DeliveredPr -Items @(New-DeliveredPr) -IssueNumber 4766
        $hit | Should -Not -BeNullOrEmpty
        $hit.Number | Should -Be 4783
        # title-only reference also counts (word boundary on '#4766' in title)
        $hit = Select-DeliveredPr -Items @(New-DeliveredPr -Body 'no ref here' -Title 'fix: thing (#4766)') -IssueNumber 4766
        $hit | Should -Not -BeNullOrEmpty
        # WORD BOUNDARY: '#476' must NOT deliver grain 4766, and '#47661' must not either
        Select-DeliveredPr -Items @(New-DeliveredPr -Body 'Refs #4766') -IssueNumber 476 | Should -BeNullOrEmpty
        Select-DeliveredPr -Items @(New-DeliveredPr -Body 'Refs #4766') -IssueNumber 47661 | Should -BeNullOrEmpty
        # OPEN or CLOSED-unmerged PRs do not deliver
        Select-DeliveredPr -Items @(New-DeliveredPr -State 'OPEN') -IssueNumber 4766 | Should -BeNullOrEmpty
        Select-DeliveredPr -Items @(New-DeliveredPr -State 'CLOSED') -IssueNumber 4766 | Should -BeNullOrEmpty
    }

    It 'fix 1 (behavioral): Test-GrainAlreadyDelivered fails closed on a PR-query failure' {
        Mock Get-PullRequestSummary { [pscustomobject]@{ Ok = $false; Items = @(); Error = 'gh api exit 1' } }
        $r = Test-GrainAlreadyDelivered -RepoSlug 'o/r' -IssueNumber 4766
        $r.Ok | Should -BeFalse
        $r.Pr | Should -BeNullOrEmpty
        # and succeeds to a delivered PR when the query is healthy
        Mock Get-PullRequestSummary { [pscustomobject]@{ Ok = $true; Items = @([pscustomobject]@{ Number = 4783; State = 'MERGED'; Title = 't #4766'; Body = ''; Url = 'u' }); Error = $null } }
        $r2 = Test-GrainAlreadyDelivered -RepoSlug 'o/r' -IssueNumber 4766
        $r2.Ok | Should -BeTrue
        $r2.Pr.Number | Should -Be 4783
    }

    It 'fix 1 (wiring): the delivered gate sits between the geometry guard and the paid call, skips at zero premium, and comments the PR URL' {
        # The check runs AFTER #4669's geometry guard (no wasted REST call on paths that already skip)
        # and BEFORE Invoke-PhaseCDispatch (the paid call).
        $lines = $script:src -split '\r?\n'
        $guardIdx = [array]::IndexOf(($lines | ForEach-Object { [bool]($_ -match 'no delivery geometry') }), $true)
        $checkIdx = [array]::IndexOf(($lines | ForEach-Object { [bool]($_ -match 'Test-GrainAlreadyDelivered -RepoSlug') }), $true)
        $paidIdx = [array]::IndexOf(($lines | ForEach-Object { [bool]($_ -match '\$dispatch = Invoke-PhaseCDispatch') }), $true)
        $checkIdx | Should -BeGreaterThan $guardIdx
        $paidIdx | Should -BeGreaterThan $checkIdx
        # Both skip shapes carry premium 0.0 (never an implicit paid default).
        $script:src | Should -Match "(?s)Test-GrainAlreadyDelivered.*?already-delivered.*?premiumRequests = 0\.0"
        # The issue comment carries the delivered PR's URL for coordinator triage.
        $script:src | Should -Match 'Invoke-CopilotIssueComment -RepoSlug \$queueSlug'
        $script:src | Should -Match '\$deliveredCheck\.Pr\.Url'
        # A failed delivered-check is its own fail-closed skip reason, distinct from already-delivered.
        $script:src | Should -Match "Get-TargetSkipMessage -Reason 'delivered-check-failed'"
        # Empty queue slug (local mode) never reaches the PR query: Get-PullRequestSummary
        # rejects an empty -Repo with a binding exception (measured: the #4669 positive
        # control crashed the child before this guard was added).
        $script:src | Should -Match '\$null -eq \$dispatch -and -not \[string\]::IsNullOrWhiteSpace\(\$queueSlug\)'
    }

    It 'fix 2 (behavioral): Remove-CopilotTargetLabel DELETEs the label and comments the reason, never throws on gh failure' {
        $script:SeenCalls = @()
        Mock gh {
            $script:SeenCalls += , @($args)
            $global:LASTEXITCODE = 0
            return
        }
        $r = Remove-CopilotTargetLabel -RepoSlug 'o/r' -IssueNumber 4766 -Reason 'HEAD unchanged since before the run'
        $r.Ok | Should -BeTrue
        $delete = @($script:SeenCalls | Where-Object { $_ -contains 'DELETE' })
        $delete | Should -HaveCount 1
        ($delete[0] -join ' ') | Should -Match 'repos/o/r/issues/4766/labels/copilot-target'
        $comment = @($script:SeenCalls | Where-Object { $_ -contains 'POST' })
        $comment | Should -HaveCount 1
        ($comment[0] -join ' ') | Should -Match 'repos/o/r/issues/4766/comments'
        # gh failure (exit 1) degrades to Ok=false, no exception
        Mock gh { $global:LASTEXITCODE = 1; return }
        $r2 = Remove-CopilotTargetLabel -RepoSlug 'o/r' -IssueNumber 4766 -Reason 'x'
        $r2.Ok | Should -BeFalse
    }

    It 'fix 2 (wiring): the no-production branch retires copilot-target' {
        $np = @($script:src -split '\r?\n' | Where-Object { $_ -match "^\s+'no-production' \{" })
        $np | Should -HaveCount 1
        # within the switch branch (next few lines) the label retirement is invoked
        $lines = $script:src -split '\r?\n'
        $i = [array]::IndexOf($lines, $np[0])
        ($lines[$i..($i + 8)] -join "`n") | Should -Match 'Remove-CopilotTargetLabel -RepoSlug \$queueSlug'
    }

    It 'fix 3 (behavioral): the delivery-mandate prompt demands Closes #N, not a bare reference' {
        $prompt = Get-WorkPrompt -Profile 'standard' -State @{ lastStatus = 'none' } -RepositoryRoot 'x' -TargetIssue ([pscustomobject]@{ number = 4766; title = 'T' }) -CanDeliver $true
        $prompt | Should -Match 'Closes #4766'
        $prompt | Should -Not -Match 'Refs #4766'
        # idle mandate unchanged: no delivery instructions without geometry
        $idlePrompt = Get-WorkPrompt -Profile 'standard' -State @{ lastStatus = 'none' } -RepositoryRoot 'x' -TargetIssue ([pscustomobject]@{ number = 4766; title = 'T' }) -CanDeliver $false
        $idlePrompt | Should -Match 'Do not run mutating GitHub commands'
    }

    It 'skip message: already-delivered and delivered-check-failed are distinct, greppable reasons' {
        $msg = Get-TargetSkipMessage -Reason 'already-delivered:#4766:PR#4783'
        $msg | Should -Match 'already-delivered'
        $msg | Should -Match 'PR#4783'
        $msg | Should -Match 'zero premium'
        $msg2 = Get-TargetSkipMessage -Reason 'delivered-check-failed'
        $msg2 | Should -Match 'delivered-check-failed'
        $msg2 | Should -Not -Match 'already-delivered'
    }
}

Describe 'start-copilot-dispatcher.ps1 — 28/11 billed-link park (behavioral decision core)' {
    # The 26/10 leak measured what an unguarded scheduled task does on a metered
    # link, and the dispatcher had no link guard at all (grep metered|billed|link-
    # = 0). ConvertTo-LinkVerdict is the pure core: the probe's first word and its
    # exit code are two signals, and the STRICTER one wins — so a disagreement can
    # only park a tick, never spend on an unclassified link.
    BeforeAll {
        foreach ($fn in 'ConvertTo-LinkVerdict', 'Get-LinkGuardVerdict') {
            $m = [regex]::Match($script:src, "(?s)(function $fn \{.*?\r?\n\})")
            if (-not $m.Success) { throw "$fn not found in start-copilot-dispatcher.ps1" }
            Invoke-Expression $m.Groups[1].Value
        }
    }

    It 'UNBILLED line + exit 0 → UNBILLED, and the detail keeps the probe payload' {
        $v = ConvertTo-LinkVerdict -ProbeLine 'UNBILLED profile=Jesse_Wifi adapter=Ethernet cost=Unrestricted' -ProbeExitCode 0
        $v.Verdict | Should -Be 'UNBILLED'
        $v.Detail | Should -Match 'profile=Jesse_Wifi'
    }

    It 'BILLED line + exit 3 → BILLED' {
        $v = ConvertTo-LinkVerdict -ProbeLine 'BILLED reason=tether adapter=Ethernet 3 cost=Fixed' -ProbeExitCode 3
        $v.Verdict | Should -Be 'BILLED'
    }

    It 'UNKNOWN line + exit 4 → UNKNOWN' {
        $v = ConvertTo-LinkVerdict -ProbeLine 'UNKNOWN reason=helper-missing' -ProbeExitCode 4
        $v.Verdict | Should -Be 'UNKNOWN'
    }

    It 'disagreement resolves STRICTER: exit 0 but a BILLED line still parks' {
        $v = ConvertTo-LinkVerdict -ProbeLine 'BILLED reason=metered-profile' -ProbeExitCode 0
        $v.Verdict | Should -Be 'BILLED'
    }

    It 'disagreement resolves STRICTER: exit 3 but an UNBILLED line still parks' {
        $v = ConvertTo-LinkVerdict -ProbeLine 'UNBILLED profile=x adapter=y cost=Unrestricted' -ProbeExitCode 3
        $v.Verdict | Should -Be 'BILLED'
    }

    It 'exit 0 with no output at all is NOT a go (UNKNOWN, fail-closed)' {
        $v = ConvertTo-LinkVerdict -ProbeLine '' -ProbeExitCode 0
        $v.Verdict | Should -Be 'UNKNOWN'
        $v.Detail | Should -Be 'probe-exit=0'
    }

    It 'an unparseable first word folds to UNKNOWN and never relaxes the verdict' {
        $v = ConvertTo-LinkVerdict -ProbeLine 'something else entirely' -ProbeExitCode 0
        $v.Verdict | Should -Be 'UNKNOWN'
        $v = ConvertTo-LinkVerdict -ProbeLine 'garbage' -ProbeExitCode 3
        $v.Verdict | Should -Be 'BILLED'
    }

    It 'lowercase and padded verdict words are normalised' {
        $v = ConvertTo-LinkVerdict -ProbeLine '  unbilled profile=a' -ProbeExitCode 0
        $v.Verdict | Should -Be 'UNBILLED'
    }

    It 'behavioral: a missing probe path is UNKNOWN probe-missing (no child spawn, never a go)' {
        $v = Get-LinkGuardVerdict -ProbePath 'C:\definitely\not\here\test-link-billed.ps1'
        $v.Verdict | Should -Be 'UNKNOWN'
        $v.Detail | Should -Be 'probe-missing'
    }
}

Describe 'start-copilot-dispatcher.ps1 — 28/11 billed-link park (wiring: parked before any external call)' {
    # Same contract as the known-bad CLI park: exit BEFORE any external call and
    # write no run state (a parked lane is not an idle streak, so it must not feed
    # the escalation counter).
    BeforeAll {
        $script:lines = $script:src -split '\r?\n'
        function Get-LineIndex([string]$Pattern) {
            [array]::IndexOf(@($script:lines | ForEach-Object { [bool]($_ -match $Pattern) }), $true)
        }
    }

    It 'the guard runs AFTER the DryRun exit and BEFORE the first external call (Test-CopilotCliBlocked)' {
        $dryRunIdx = Get-LineIndex 'if \(\$DryRun\) \{'
        $guardIdx = Get-LineIndex '\$linkVerdict = Get-LinkGuardVerdict -ProbePath \$linkProbePath'
        $cliIdx = Get-LineIndex 'if \(Test-CopilotCliBlocked\) \{'
        $dryRunIdx | Should -BeGreaterOrEqual 0
        $guardIdx | Should -BeGreaterThan $dryRunIdx
        $cliIdx | Should -BeGreaterThan $guardIdx
    }

    It 'the probe path is derived from $scriptDir (scripts/monitoring), never from the cwd' {
        # Two-step Join-Path: a literal backslash child is one odd FILENAME on
        # Linux, where the child-executing harnesses run (CI ubuntu / pwsh).
        $script:src | Should -Match '\$linkProbePath = Join-Path \(Join-Path \(Split-Path -Parent \$scriptDir\) ''monitoring''\)'
        $script:src | Should -Match "'test-link-billed\.ps1'"
    }

    It 'the probe host is resolved, never assumed: powershell.exe if present, else the runner pwsh' {
        # The probe's proven engine is 5.1 (WinRT casts); on the ubuntu runner
        # powershell.exe does not exist and -ExecutionPolicy is not a pwsh arg.
        $script:src | Should -Match 'Get-Command powershell\.exe -ErrorAction SilentlyContinue'
        $script:src | Should -Match "Join-Path \`$PSHOME 'pwsh'"
        $script:src | Should -Match "if \(\`$env:OS -eq 'Windows_NT'\) \{ \`$hostArgs \+= @\('-ExecutionPolicy', 'Bypass'\) \}"
        $script:src | Should -Not -Match '& powershell\.exe '
    }

    It 'park is fail-closed on anything but UNBILLED, logs the verdict, exits 0 without touching run state' {
        $script:src | Should -Match "if \(\`$linkVerdict\.Verdict -ne 'UNBILLED'\) \{"
        $script:src | Should -Match 'Dispatcher parked this tick - link \$\(\$linkVerdict\.Verdict\)'
        $m = [regex]::Match($script:src, "(?s)if \(\`$linkVerdict\.Verdict -ne 'UNBILLED'\) \{(.*?)\r?\n\}")
        $m.Success | Should -BeTrue
        $m.Groups[1].Value | Should -Match 'Write-Log'
        $m.Groups[1].Value | Should -Match 'exit 0'
        $m.Groups[1].Value | Should -Not -Match 'Set-Content|ConvertTo-Json|Save-'
    }

    It 'positive control: deleting the guard call makes the ordering pin fail' {
        $mutant = $script:src -replace '(?m)^\s*\$linkVerdict = Get-LinkGuardVerdict[^\r\n]*\r?\n', ''
        $mutant | Should -Not -Match '\$linkVerdict = Get-LinkGuardVerdict'
    }
}