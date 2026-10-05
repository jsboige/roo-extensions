<#
.SYNOPSIS
    Guard test: Hide-SecretLikeArgs masks every secret-bearing MCP arg form before publication (#2307).

.DESCRIPTION
    Get-MachineInventory.ps1 publishes each MCP server's `command` + `args` into the shared
    state inventory. `args` are nameless values -- an arg can carry a token verbatim
    (--api-key=X, --api-key X, -H "Authorization: Bearer X", https://user:pass@host).
    Hide-SecretLikeArgs masks them before write; this suite pins the three forms demanded
    by the ai-01 review of #4064 plus the two anti-regression cases:
      - flag naming a secret WITHOUT '=' must mask the FOLLOWING argument too
        (the review blocker: v1 masked the flag and let the token through in clear),
      - benign args must pass untouched (over-masking is a drift-detection regression),
      - a trailing secret flag must not crash or double-mask.
    The target script is a 1200-line collector: dot-sourcing it would RUN the collection,
    so the function is extracted from source (same technique as the reviewed smoke) and the
    extraction itself is a structural guard -- renaming the function fails this suite.
    Also asserts the whole target still PARSES (PS 5.1 grammar).

.NOTES
    Issue #2307 hardening follow-up (ai-01 dispatch 2026-10-05, "harnais Pester du masquage
    #4064"). Lives in scripts/testing/unit/ so the unit-pester CI job discovers it by
    directory -- no ci.yml step or path-filter edit needed. Requires Pester 5+.
#>

Describe 'Get-MachineInventory Hide-SecretLikeArgs (#2307)' {

    BeforeAll {
        $script:Target = Join-Path $PSScriptRoot '../../inventory/Get-MachineInventory.ps1'
        $source = Get-Content -Raw -Encoding UTF8 $script:Target

        # Structural guard: the function must exist under this exact name.
        if (-not ($source -match '(?s)(function Hide-SecretLikeArgs \{.*?\r?\n\})')) {
            throw "Hide-SecretLikeArgs introuvable dans $script:Target -- le masquage a ete renomme ou retire (#2307)."
        }
        Invoke-Expression $Matches[1]
    }

    It 'the target script parses under PS 5.1 grammar (0 errors)' {
        $errs = $null
        $null = [System.Management.Automation.Language.Parser]::ParseFile($script:Target, [ref]$null, [ref]$errs)
        $errs.Count | Should -Be 0
    }

    It 'masks a single-arg secret flag with equals form' {
        $got = @(Hide-SecretLikeArgs @('--api-key=sk-abc123'))
        $got | Should -Be @('<redacted>')
    }

    It 'masks the FOLLOWING argument when the flag names a secret without equals (review #4064 blocker)' {
        $got = @(Hide-SecretLikeArgs @('--api-key', 'sk-abc123'))
        $got | Should -Be @('<redacted>', '<redacted>')
    }

    It 'masks the following argument for short secret flags too' {
        $got = @(Hide-SecretLikeArgs @('-token', 'tok99'))
        $got | Should -Be @('<redacted>', '<redacted>')
    }

    It 'masks a Bearer authorization header value while keeping the -H flag' {
        $got = @(Hide-SecretLikeArgs @('-H', 'Authorization: Bearer X9'))
        $got | Should -Be @('-H', '<redacted>')
    }

    It 'masks URL userinfo credentials' {
        $got = @(Hide-SecretLikeArgs @('https://user:pass@host/path'))
        $got | Should -Be @('<redacted>')
    }

    It 'leaves benign arguments untouched (no over-masking)' {
        $got = @(Hide-SecretLikeArgs @('-y', '@simonb97/some-mcp', '--port', '3914'))
        $got | Should -Be @('-y', '@simonb97/some-mcp', '--port', '3914')
    }

    It 'a trailing secret flag is masked once and does not crash' {
        $got = @(Hide-SecretLikeArgs @('run', '--api-key'))
        $got | Should -Be @('run', '<redacted>')
    }

    It 'an empty arg list returns an empty array' {
        $got = @(Hide-SecretLikeArgs @())
        $got.Count | Should -Be 0
    }
}
