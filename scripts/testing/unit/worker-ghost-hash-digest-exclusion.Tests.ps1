# Unit tests - a quoted digest is not a commit claim (#4524, #1489)
#
# Run of 2026-11-03 (#4334, po-2024 worker): the report carried
# "⚠️ WARNING: Ghost commit hashes detected ... 261e2567" over an output that claimed
# NO commit — « identical `settings.json` sha256 (`261e2567…`) » quoted the digest as
# PROOF that a dry-run wrote nothing. The detector turned a proof of non-writing into
# an alarm, and repeated false alarms train the reader to ignore the warning.
#
# Behavioural: the matcher is extracted from the worker by AST and run on the exact
# shapes #4524 lists. Pure string matching — platform-neutral, no git, no cmd.exe.
#
# Negative witness: the pre-fix pattern (kept verbatim below, from the inline
# Select-String it replaces) must still MATCH the incident line — proving the new
# assertions discriminate, i.e. reverting the fix turns them red.
#
# Usage:
#   pwsh -NoProfile -Command "Invoke-Pester -Path ./scripts/testing/unit/worker-ghost-hash-digest-exclusion.Tests.ps1 -Output Detailed"

BeforeAll {
    $script:workerScript = (Resolve-Path -Path "$PSScriptRoot/../../scheduling/start-claude-worker.ps1").Path
    $tokens = $null
    $script:parseErrors = $null
    $script:ast = [System.Management.Automation.Language.Parser]::ParseFile($script:workerScript, [ref]$tokens, [ref]$script:parseErrors)

    $script:fnMatcher = $script:ast.FindAll({
        param($node)
        $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'Get-ClaimedCommitHashTokens'
    }, $true) | Select-Object -First 1
    if ($script:fnMatcher) { Invoke-Expression $script:fnMatcher.Extent.Text }

    $script:fnReport = $script:ast.FindAll({
        param($node)
        $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'Report-Results'
    }, $true) | Select-Object -First 1

    # The pattern exactly as it was BEFORE the fix (inline in Report-Results, git 57766396
    # and earlier). The negative witness: on the incident line this one still fires.
    $script:prefixPattern = '(?<![0-9a-fx-])[0-9a-f]{8}(?:[0-9a-f]{32})?(?![0-9a-f-])'

    # The incident line, verbatim shape from the 03/11 worker report for #4334.
    $script:incidentLine = 'identical `settings.json` sha256 (`261e2567…`)'

    # The leading comma defeats pipeline unrolling at the function boundary: without it a
    # single-token result reaches the caller as a bare String and $t[0] would index the
    # first CHARACTER, not the first token (that is exactly how the first run went red).
    function Get-Tokens([string]$Output) { ,@(Get-ClaimedCommitHashTokens -Output $Output) }
    function Get-PreFixTokens([string]$Output) {
        ,@([regex]::Matches($Output, $script:prefixPattern) | ForEach-Object { $_.Value } | Select-Object -Unique)
    }
}

Describe "Worker ghost-hash detector - a quoted digest is not a commit claim (#4524)" {

    Context "Extraction" {

        It "parses the worker without syntax errors" {
            $script:parseErrors.Count | Should -Be 0
        }

        It "defines Get-ClaimedCommitHashTokens" {
            $script:fnMatcher | Should -Not -BeNullOrEmpty
        }

        It "Report-Results calls the matcher, no inline pattern left behind" {
            $script:fnReport.Extent.Text | Should -Match 'Get-ClaimedCommitHashTokens -Output \$Result\.output'
            $script:fnReport.Extent.Text | Should -Not -Match '\[0-9a-f\]\{8\}'
        }
    }

    Context "Digests quoted as proof are not claims (the #4334 incident)" {

        It "the incident line 'sha256 (`261e2567…`)' yields 0 tokens" {
            (Get-Tokens $script:incidentLine).Count | Should -Be 0
        }

        It "'md5 abcdef12' yields 0 tokens" {
            (Get-Tokens 'md5 abcdef12').Count | Should -Be 0
        }

        It "'sha-256: 261e2567' yields 0 tokens" {
            (Get-Tokens 'sha-256: 261e2567').Count | Should -Be 0
        }

        It "Get-FileHash style uppercase label 'SHA256 (`261e2567…`)' yields 0 tokens" {
            (Get-Tokens 'SHA256 (`261e2567…`)').Count | Should -Be 0
        }

        It "'digest 261e2567' yields 0 tokens" {
            (Get-Tokens 'digest 261e2567').Count | Should -Be 0
        }

        It "a token cut with the typographic ellipsis is excluded even without a keyword" {
            (Get-Tokens 'blob `1dbcd09a…` (truncated)').Count | Should -Be 0
        }
    }

    Context "The exclusion window is bounded and line-local" {

        It "a keyword more than 20 characters away does not exempt the token" {
            (Get-Tokens ('sha256 ' + ('x' * 25) + ' 261e2567')).Count | Should -Be 1
        }

        It "a keyword on the previous line does not exempt the token" {
            (Get-Tokens "sha256 digest follows:`ncommit 261e2567 pushed").Count | Should -Be 1
        }
    }

    Context "Fabricated commit SHAs stay detected (non-regressions)" {

        It "'commit 261e2567 pushed' still yields the token" {
            $t = Get-Tokens 'commit 261e2567 pushed'
            $t.Count | Should -Be 1
            $t[0] | Should -Be '261e2567'
        }

        It "a full 40-char SHA still yields the token" {
            $t = Get-Tokens 'merged 0123456789abcdef0123456789abcdef01234567 today'
            $t.Count | Should -Be 1
            $t[0] | Should -Be '0123456789abcdef0123456789abcdef01234567'
        }

        It "a UUID yields 0 tokens (non-regression of the dash guards)" {
            (Get-Tokens 'session 261e2567-1234-4abc-9def-0123456789ab').Count | Should -Be 0
        }

        It "ASCII '...' after a token stays a claim - only U+2026 is a cut marker" {
            (Get-Tokens 'commits abc12345... and more').Count | Should -Be 1
        }

        It "an HRESULT and uppercase hex still yield 0 tokens (non-regression)" {
            (Get-Tokens 'failed with 0x800710E0 and DEADBEEF').Count | Should -Be 0
        }

        It "empty and null output yield 0 tokens" {
            (Get-Tokens '').Count | Should -Be 0
            (Get-Tokens $null).Count | Should -Be 0
        }
    }

    Context "Negative witness - the case discriminates" {

        It "the pre-fix pattern still matches the incident line (reverting turns the suite red)" {
            (Get-PreFixTokens $script:incidentLine).Count | Should -Be 1
        }

        It "the pre-fix pattern still matches 'md5 abcdef12'" {
            (Get-PreFixTokens 'md5 abcdef12').Count | Should -Be 1
        }
    }
}
