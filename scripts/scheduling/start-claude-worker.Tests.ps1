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
