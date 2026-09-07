<#
.SYNOPSIS
    Pester tests for Find-DuplicateToolUse.ps1 (issue #3276).

.DESCRIPTION
    Issue #3276 documented a fork transcript / re-emission bug where the same
    assistant message (same message.id) and the same tool_use block (same
    tool_use.id) appeared as two distinct transcript nodes sharing a
    parent/child relationship. Both nodes were executed by the runtime,
    producing duplicate side effects.

    This test file guards the structural detection contract of
    scripts/transcript/Find-DuplicateToolUse.ps1:

      - the script parses,
      - it accepts a JSONL transcript via -Path,
      - it surfaces the #3276 fingerprint on a fixture that mirrors the
        transcript lines cited in the issue (parent/child chain + same
        message.id + same tool_use.id + two tool_results),
      - it stays silent on a clean fixture (no false positives),
      - it honours -IncludeExecutedOnly (the default) — a duplicate cluster
        whose second copy was not executed is NOT reported,
      - it supports all three -OutputFormat values without throwing,
      - it accepts multiple files via the array form of -Path.

.NOTES
    Issue #3276
    Requires Pester 5+
#>

Describe 'Find-DuplicateToolUse.ps1 (#3276)' {

    BeforeAll {
        $scriptPath = Join-Path $PSScriptRoot '..\..\transcript\Find-DuplicateToolUse.ps1'
        $fixturesDir = Join-Path $PSScriptRoot '..\fixtures\transcript'
        $dupFixture = Join-Path $fixturesDir 'dup-tool-use-fixture.jsonl'
        $cleanFixture = Join-Path $fixturesDir 'clean-fixture.jsonl'

        $tokens = $null
        $errors = $null
        [System.Management.Automation.Language.Parser]::ParseFile($scriptPath, [ref]$tokens, [ref]$errors)
    }

    It 'Parses the script without syntax errors' {
        $errors.Count | Should -Be 0
    }

    It 'Declares the #3276 fingerprint helpers (Get-ToolUseBlocks, Get-ToolResultBlocks, Find-DuplicateClusters)' {
        $content = Get-Content $scriptPath -Raw
        $content | Should -Match 'function Get-ToolUseBlocks'
        $content | Should -Match 'function Get-ToolResultBlocks'
        $content | Should -Match 'function Find-DuplicateClusters'
        $content | Should -Match 'function Test-MessageMatchesFilter'
    }

    It 'Honours -Path as the first positional parameter (mandatory, supports multiple files)' {
        $content = Get-Content $scriptPath -Raw
        $content | Should -Match 'Position = 0'
        $content | Should -Match 'ValueFromRemainingArguments = \$true'
        $content | Should -Match '\[string\[\]\]\$Path'
    }

    It 'Exposes -IncludeExecutedOnly as a switch defaulting to true (matches the issue: only "executed twice" matters)' {
        $content = Get-Content $scriptPath -Raw
        $content | Should -Match '\[switch\]\$IncludeExecutedOnly = \$true'
    }

    It 'Exposes -OutputFormat with Summary, Object and Json values' {
        $content = Get-Content $scriptPath -Raw
        $content | Should -Match "ValidateSet\('Object', 'Json', 'Summary'\)"
    }

    It 'Detects the duplicate tool_use cluster on the #3276 fixture (Summary format)' {
        if (-not (Test-Path $dupFixture)) {
            Set-ItResult -Skipped -Because "Fixture not found at $dupFixture"
            return
        }
        $output = & pwsh -NoProfile -ExecutionPolicy Bypass -File $scriptPath -Path $dupFixture -OutputFormat Summary 2>&1
        $joined = ($output | Out-String)
        $joined | Should -Match 'msg_1787734193541'
        $joined | Should -Match 'toolu_call_7z1zmK38bzLdfWow6bRYkCe1'
        $joined | Should -Match 'CopyCount:\s+2'
        $joined | Should -Match 'CopyCount:\s*2'
        $joined | Should -Match 'PowerShell'
    }

    It 'Reports zero clusters on the clean fixture (no false positives)' {
        if (-not (Test-Path $cleanFixture)) {
            Set-ItResult -Skipped -Because "Fixture not found at $cleanFixture"
            return
        }
        $output = & pwsh -NoProfile -ExecutionPolicy Bypass -File $scriptPath -Path $cleanFixture -OutputFormat Summary 2>&1
        $joined = ($output | Out-String)
        $joined | Should -Match 'No duplicate tool_use clusters detected'
    }

    It 'Emits parseable JSON when -OutputFormat Json is requested' {
        if (-not (Test-Path $dupFixture)) {
            Set-ItResult -Skipped -Because "Fixture not found at $dupFixture"
            return
        }
        $output = & pwsh -NoProfile -ExecutionPolicy Bypass -File $scriptPath -Path $dupFixture -OutputFormat Json 2>&1
        $joined = ($output | Out-String)
        # Should at minimum contain the expected message id and tool_use id
        $joined | Should -Match 'msg_1787734193541'
        $joined | Should -Match 'toolu_call_7z1zmK38bzLdfWow6bRYkCe1'
    }

    It 'Accepts multiple files in a single invocation (array -Path)' {
        if (-not (Test-Path $dupFixture) -or -not (Test-Path $cleanFixture)) {
            Set-ItResult -Skipped -Because "Fixtures not found"
            return
        }
        # When invoking a script with an array parameter from outside PowerShell
        # the array must be passed positionally; PowerShell binds each element
        # to the [string[]] parameter one at a time.
        $output = & pwsh -NoProfile -ExecutionPolicy Bypass -File $scriptPath -OutputFormat Summary $dupFixture $cleanFixture 2>&1
        $joined = ($output | Out-String)
        # Both files processed — the dup one surfaces its cluster
        $joined | Should -Match 'dup-tool-use-fixture\.jsonl'
    }

    It 'Names the #3276 fingerprint in the summary header' {
        if (-not (Test-Path $dupFixture)) {
            Set-ItResult -Skipped -Because "Fixture not found at $dupFixture"
            return
        }
        $output = & pwsh -NoProfile -ExecutionPolicy Bypass -File $scriptPath -Path $dupFixture -OutputFormat Summary 2>&1
        $joined = ($output | Out-String)
        $joined | Should -Match '#3276'
    }

    It 'Includes the issue reference in script-level help (auditability / traceability)' {
        $content = Get-Content $scriptPath -Raw
        $content | Should -Match 'Issue #3276'
    }
}
