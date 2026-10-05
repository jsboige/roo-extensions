# Pester tests for start-claude-worker.ps1 — #3905 (claude_code_version_too_old surfacing).
#
# The worker is a 5000-line monolith with network side effects: not drivable from a
# bench. What IS provable without executing it:
#   - the DETECTION regex actually shipped in the file (extracted, not re-typed — a
#     bench that matches its own prose proves nothing) runs against the incident's
#     real emission form and REJECTS the prose false-positive class;
#   - the WIRING: flag flows into the $Result hashtable and the worker report
#     template, and the run log carries the CLI version line (demand 1, already in
#     place via Test-ClaudeCLI).
#
# Run:  pwsh -File scripts/testing/run-pester-tests.ps1 -Path scripts/scheduling/start-claude-worker.Tests.ps1

BeforeAll {
    $target = Join-Path $PSScriptRoot 'start-claude-worker.ps1'
    $script:src = Get-Content -LiteralPath $target -Raw

    # Extract the SHIPPED regex: '$ClaudeCodeVersionTooOld = $JoinedIterationOutput -match '<pat>''
    $m = [regex]::Match($script:src, "\`$ClaudeCodeVersionTooOld = \`$JoinedIterationOutput -match '([^']+)'")
    $script:versionPattern = if ($m.Success) { $m.Groups[1].Value } else { $null }
}

Describe 'start-claude-worker.ps1 — #3905 claude_code_version_too_old detection' {
    It 'the detection regex is present and extractable from the source (denominator)' {
        $script:versionPattern | Should -Not -BeNullOrEmpty
        $script:versionPattern | Should -Match 'claude_code_version_too_old'
        $script:versionPattern | Should -Match 'API Error'
    }

    It 'matches the incident emission (API Error 400 … version_too_old on one line)' {
        $sample = @(
            'Some prior worker output line.'
            'API Error 400 … claude_code_version_too_old ("Claude Code 2.1.17 does not support this model; version 2.1.280 or newer is required")'
            'Following output line.'
        ) -join "`n"
        $sample | Should -Match $script:versionPattern
    }

    It 'matches the emission with an [ERROR] log prefix' {
        $sample = "[ERROR] API Error 400 claude_code_version_too_old (`"2.1.41 does not support this model`")"
        $sample | Should -Match $script:versionPattern
    }

    It 'REJECTS prose quoting the token (issue title / task body — not an emission)' {
        $sample = @(
            '## Issue Description'
            'Echecs opus silencieux sur CLI < 2.1.280 (claude_code_version_too_old) — rendre la cause visible dans le rapport worker'
            'The worker should surface claude_code_version_too_old when it appears.'
        ) -join "`n"
        $sample | Should -Not -Match $script:versionPattern
    }

    It 'REJECTS an API Error emission WITHOUT the version token (stays #2968-generic)' {
        $sample = 'API Error 429: rate limit exceeded, retry after 60s'
        $sample | Should -Not -Match $script:versionPattern
    }
}

Describe 'start-claude-worker.ps1 — #3905 wiring (flag reaches log, result, report)' {
    It 'flag is assigned into the returned $Result hashtable' {
        $script:src | Should -Match 'claudeCodeVersionTooOld = \$ClaudeCodeVersionTooOld'
    }

    It 'worker report template carries a dedicated CLI-too-old line keyed on the flag' {
        $script:src | Should -Match '\$Result\.claudeCodeVersionTooOld'
        $script:src | Should -Match 'CLI trop ancien'
    }

    It 'demand 1: the run log records the CLI version (Test-ClaudeCLI, called from main pre-flight)' {
        $script:src | Should -Match 'Write-Log "Claude CLI: \$Version"'
        $script:src | Should -Match 'if \(-not \(Test-ClaudeCLI\)\)'
    }
}

# --- Re-request review after CHANGES_REQUESTED fixes (dispatch ai-01 2026-10-05) ---
#
# The rule: « une review plus ancienne que le dernier commit est la dette du
# reviewer ». The decision core (Get-StaleReviewers) is pure — extracted from
# the SHIPPED source like claim-lock/Hide-SecretLikeArgs suites, never
# re-typed — and driven here with gh-shaped review JSON. The I/O wrapper
# (Request-StaleReview) and its hook in the #2157 re-push branch are asserted
# on the raw source.

Describe 'start-claude-worker.ps1 — Get-StaleReviewers decision core (behavioral)' {
    BeforeAll {
        # Extract the SHIPPED function (first column-0 closing brace = its own end).
        $m = [regex]::Match($script:src, '(?s)(function Get-StaleReviewers \{.*?\r?\n\})')
        if (-not $m.Success) { throw 'Get-StaleReviewers not found in start-claude-worker.ps1' }
        Invoke-Expression $m.Groups[1].Value
    }

    It 'CHANGES_REQUESTED older than head commit → reviewer re-requested (the debt case)' {
        $json = '[{"state":"CHANGES_REQUESTED","submitted_at":"2026-10-05T10:00:00Z","user":{"login":"reviewer-a"}}]'
        $r = Get-StaleReviewers -ReviewsJson $json -HeadCommitDate '2026-10-05T12:00:00Z' -SelfLogin 'worker'
        @($r) | Should -Be @('reviewer-a')
    }

    It 'APPROVED newer than head commit → excluded (verdict describes the head, no debt)' {
        $json = '[{"state":"APPROVED","submitted_at":"2026-10-05T13:00:00Z","user":{"login":"reviewer-a"}}]'
        $r = Get-StaleReviewers -ReviewsJson $json -HeadCommitDate '2026-10-05T12:00:00Z' -SelfLogin 'worker'
        @($r) | Should -Be @()
    }

    It 'APPROVED older than head commit → included (stale verdict re-opens the debt on ANY state)' {
        $json = '[{"state":"APPROVED","submitted_at":"2026-10-05T10:00:00Z","user":{"login":"reviewer-a"}}]'
        $r = Get-StaleReviewers -ReviewsJson $json -HeadCommitDate '2026-10-05T12:00:00Z' -SelfLogin 'worker'
        @($r) | Should -Be @('reviewer-a')
    }

    It 'latest verdict wins per login — fresh APPROVED supersedes an older CHANGES_REQUESTED from the same reviewer' {
        $json = '[{"state":"CHANGES_REQUESTED","submitted_at":"2026-10-05T08:00:00Z","user":{"login":"reviewer-a"}},{"state":"APPROVED","submitted_at":"2026-10-05T13:00:00Z","user":{"login":"reviewer-a"}}]'
        $r = Get-StaleReviewers -ReviewsJson $json -HeadCommitDate '2026-10-05T12:00:00Z' -SelfLogin 'worker'
        @($r) | Should -Be @()
    }

    It 'excludes the self login (re-requesting the login that pushed is a no-op)' {
        $json = '[{"state":"CHANGES_REQUESTED","submitted_at":"2026-10-05T10:00:00Z","user":{"login":"worker"}}]'
        $r = Get-StaleReviewers -ReviewsJson $json -HeadCommitDate '2026-10-05T12:00:00Z' -SelfLogin 'worker'
        @($r) | Should -Be @()
    }

    It 'COMMENTED-only login excluded (a comment carries no verdict)' {
        $json = '[{"state":"COMMENTED","submitted_at":"2026-10-05T10:00:00Z","user":{"login":"reviewer-a"}}]'
        $r = Get-StaleReviewers -ReviewsJson $json -HeadCommitDate '2026-10-05T12:00:00Z' -SelfLogin 'worker'
        @($r) | Should -Be @()
    }

    It 'mixed fleet: only stale, non-self, verdict-carrying logins returned' {
        $json = @(
            '[{"state":"CHANGES_REQUESTED","submitted_at":"2026-10-05T10:00:00Z","user":{"login":"stale-one"}}'
            ',{"state":"APPROVED","submitted_at":"2026-10-05T13:00:00Z","user":{"login":"fresh-one"}}'
            ',{"state":"CHANGES_REQUESTED","submitted_at":"2026-10-05T09:00:00Z","user":{"login":"worker"}}'
            ',{"state":"COMMENTED","submitted_at":"2026-10-05T09:30:00Z","user":{"login":"commenter"}}'
            ',{"state":"CHANGES_REQUESTED","submitted_at":"2026-10-05T09:00:00Z","user":{"login":"stale-two"}}]'
        ) -join ''
        $r = @(Get-StaleReviewers -ReviewsJson $json -HeadCommitDate '2026-10-05T12:00:00Z' -SelfLogin 'worker')
        $r.Count | Should -Be 2
        $r | Should -Contain 'stale-one'
        $r | Should -Contain 'stale-two'
    }

    It 'unparseable head date → fail-open @() (a bad date never triggers a re-request)' {
        $json = '[{"state":"CHANGES_REQUESTED","submitted_at":"2026-10-05T10:00:00Z","user":{"login":"reviewer-a"}}]'
        $r = Get-StaleReviewers -ReviewsJson $json -HeadCommitDate 'not-a-date' -SelfLogin 'worker'
        @($r) | Should -Be @()
    }

    It 'unparseable review date → that review skipped, other reviewers still served' {
        $json = '[{"state":"CHANGES_REQUESTED","submitted_at":"garbage","user":{"login":"broken-date"}},{"state":"CHANGES_REQUESTED","submitted_at":"2026-10-05T10:00:00Z","user":{"login":"reviewer-a"}}]'
        $r = @(Get-StaleReviewers -ReviewsJson $json -HeadCommitDate '2026-10-05T12:00:00Z' -SelfLogin 'worker')
        $r | Should -Be @('reviewer-a')
    }

    It 'empty reviews json → @()' {
        $r = Get-StaleReviewers -ReviewsJson '' -HeadCommitDate '2026-10-05T12:00:00Z' -SelfLogin 'worker'
        @($r) | Should -Be @()
    }

    It 'malformed json → @() (catch = fail-open, never throws)' {
        $r = Get-StaleReviewers -ReviewsJson 'not-json-at-all' -HeadCommitDate '2026-10-05T12:00:00Z' -SelfLogin 'worker'
        @($r) | Should -Be @()
    }
}

Describe 'start-claude-worker.ps1 — Request-StaleReview wiring (re-push branch)' {
    It 'both functions are defined before New-WorkerPR' {
        $script:src | Should -Match '(?s)function Get-StaleReviewers \{.*?function Request-StaleReview \{.*?function New-WorkerPR \{'
    }

    It 'hook: the #2157 existing-PR branch calls Request-StaleReview before returning the PR url' {
        $script:src | Should -Match '(?s)PR already exists for branch.*?Request-StaleReview -PrUrl "\$ExistingPR"\.Trim\(\).*?return "\$ExistingPR"\.Trim\(\)'
    }

    It 're-request goes through the requested_reviewers endpoint (POST)' {
        $script:src | Should -Match 'requested_reviewers'
        $script:src | Should -Match '-X POST'
    }

    It 'never stacks a second nudge: skips when reviewRequests already pending' {
        $script:src | Should -Match 'reviewRequests'
        $script:src | Should -Match 'Re-review skip'
    }

    It 'never fatal: wrapper failure logs WARN, not throw' {
        $script:src | Should -Match '(?s)function Request-StaleReview \{.*?Write-Log "Request-StaleReview non-fatal failure.*?"WARN"'
    }

    It 'policy doc carries the rule: une review plus ancienne que le dernier commit est la dette du reviewer' {
        $policy = Join-Path $PSScriptRoot '..\..\docs\harness\coordinator-specific\pr-review-policy.md'
        (Get-Content -LiteralPath $policy -Raw) | Should -Match 'dette du reviewer'
    }
}
