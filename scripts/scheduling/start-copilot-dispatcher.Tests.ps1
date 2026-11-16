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
# `git remote get-url origin` output. The wiring ($repoArgs splatted into both
# gh calls) is asserted on the raw source.
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

Describe 'start-copilot-dispatcher.ps1 — #3641 §3 wiring (-R reaches both gh calls)' {
    It 'derives $repoArgs from the target repo slug inside Get-TargetIssue' {
        $script:src | Should -Match '\$repoSlug = Get-RepoSlug -RepositoryRoot \$RepositoryRoot'
        $script:src | Should -Match '\$repoArgs = @\(.-R., \$repoSlug\)'
    }

    It 'pinned `gh issue view` carries @repoArgs (seed-issue path)' {
        $script:src | Should -Match 'gh issue view \$PreferredIssueNumber @repoArgs --json'
    }

    It 'pinned `gh issue list` carries @repoArgs (copilot-target pool path)' {
        $script:src | Should -Match 'gh issue list @repoArgs --state open --search'
    }

    It 'no bare gh issue call remains (denominator: every call site pinned)' {
        # Call sites carry the `& gh` invocation prefix; the pool-semantics comment
        # quotes `gh issue list` in prose and must NOT count as a call site.
        $callLines = @($script:src -split '\r?\n' | Where-Object { $_ -match '& gh issue (view|list)' })
        $callLines | Should -HaveCount 2
        @($callLines | Where-Object { $_ -notmatch '@repoArgs' }) | Should -BeNullOrEmpty
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