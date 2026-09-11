<#
.SYNOPSIS
    Guards the OAuth expiry detection wired into the executor pre-flight (#3169, option b).

.DESCRIPTION
    Text-guards on scripts/claude/executor-preflight.ps1 plus a behavioral check of the
    discriminator regex extracted from the production script: a real API error line
    (isApiErrorMessage":true + the OAuth message) must match, a quoted dashboard
    citation of the same message must not (measured 2026-08-27: 28 raw hits on web1
    were 26 citations + 2 real errors — a naive grep overcounts 10x).
#>

Describe 'Executor pre-flight OAuth expiry detection (#3169)' {
    BeforeAll {
        $preflightPath = Join-Path $PSScriptRoot '..\..\..\scripts\claude\executor-preflight.ps1'
        $preflight = Get-Content $preflightPath -Raw

        $errors = $null
        [System.Management.Automation.Language.Parser]::ParseFile($preflightPath, [ref]$null, [ref]$errors)

        # Extract the discriminator regex from the production script so the test
        # drifts with the code instead of re-declaring it.
        $patternMatch = [regex]::Match($preflight, "\`$script:oauthExpiryPattern = '([^']+)'")
        $extractedPattern = $patternMatch.Groups[1].Value

        # Line shapes taken from real web1 traces (session 1356264f, 2026-08-26):
        # the error text sits in content[].text, isApiErrorMessage":true flags the
        # line further along; a citation quotes the message inside a tool_result.
        $realErrorLine = '{"type":"assistant","message":{"id":"d556768b","role":"assistant","content":[{"type":"text","text":"Failed to authenticate: OAuth session expired and could not be refreshed"}]},"isApiErrorMessage":true,"userType":"external","timestamp":"2026-08-26T15:19:25.075Z"}'
        $citationLine = '{"type":"user","message":{"role":"user","content":[{"type":"tool_result","content":"[web1 — recensement frais] grep OAuth session expired sur tous les *.jsonl"}]},"timestamp":"2026-08-27T04:20:52Z"}'
    }

    It 'parses executor-preflight.ps1 under PowerShell' {
        $errors.Count | Should -Be 0
    }

    It 'declares the discriminator pattern' {
        $extractedPattern | Should -Not -BeNullOrEmpty
        $extractedPattern | Should -Match ([regex]::Escape('isApiErrorMessage":true'))
        $extractedPattern | Should -Match ([regex]::Escape('OAuth session expired'))
    }

    It 'matches a real OAuth API error line in both field orders' {
        $realErrorLine | Should -Match $extractedPattern
        $reversed = '{"isApiErrorMessage":true,"message":{"content":[{"text":"Failed to authenticate: OAuth session expired and could not be refreshed"}]}}'
        $reversed | Should -Match $extractedPattern
    }

    It 'does not match a quoted dashboard citation of the same message' {
        $citationLine | Should -Not -Match $extractedPattern
    }

    It 'scans only recent traces through Find-OAuthExpirySignal' {
        $preflight | Should -Match 'function Find-OAuthExpirySignal'
        $preflight | Should -Match 'MaxAgeHours = 48'
        $preflight | Should -Match ([regex]::Escape('Join-Path $HOME ''.claude\projects'''))
        $preflight | Should -Match 'LastWriteTime -gt \$cutoff'
    }

    It 'emits a non-blocking warning on hits — the cycle keeps exit 0' {
        $preflight | Should -Match '\[executor-preflight\]\[OAUTH-EXPIRED\]'
        $preflight | Should -Match 'Write-Warning'
        $oauthBlock = [regex]::Match($preflight, '(?s)oauthExpiredSessions.Count -gt 0.*?exit 0')
        $oauthBlock.Success | Should -BeTrue
        $oauthBlock.Value | Should -Not -Match 'exit [1-9]'
    }
}
