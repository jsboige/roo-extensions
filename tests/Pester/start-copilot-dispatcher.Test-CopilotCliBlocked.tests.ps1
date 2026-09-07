#!/usr/bin/env pwsh
# Pester 5+ tests for the known-bad CLI burn guard (start-copilot-dispatcher.ps1)
# Context: 06/09 lane-perenne proposal — CLI 1.0.83 was reported to refuse all
# mutations on work-prompt sessions server-side; every scheduled run burned ~15
# premium credits and ended idle. The guard parks the dispatcher fail-closed on
# known-bad versions (list lives in $Script:KnownBadCopilotCliVersions).
#
# 07/09: that datum was measured through the `gh copilot` EXTENSION; the script
# now invokes the standalone `copilot` binary, on which 1.0.83 mutates fine
# (firsthand, work-prompt session with edits + git commit). The SHIPPED list is
# therefore empty. These tests pin the MECHANISM, not the policy: BeforeAll sets
# its own stub list so they stay meaningful whatever ships.

Describe 'Copilot dispatcher known-bad CLI guard' {

BeforeAll {
    $scriptFilePath = Join-Path $PSScriptRoot '../../scripts/scheduling/start-copilot-dispatcher.ps1'
    $resolvedPath = (Resolve-Path $scriptFilePath).Path

    # Parse with AST — cannot dot-source (side effects: logging, state, exit)
    $parseErrors = $null
    $tokens = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile(
        $resolvedPath,
        [ref]$tokens,
        [ref]$parseErrors
    )

    $funcDefs = $ast.FindAll(
        { param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] },
        $true
    )

    foreach ($name in @('Get-CopilotCliVersion', 'Test-CopilotCliBlocked')) {
        $fd = $funcDefs | Where-Object { $_.Name -eq $name }
        if (-not $fd) { throw "$name not found in $resolvedPath" }
        $bodyText = $fd.Body.Extent.Text
        $inner = $bodyText.Substring(1, $bodyText.Length - 2)
        if ($fd.Parameters -and $fd.Parameters.Count -gt 0) {
            $paramNames = $fd.Parameters | ForEach-Object { '$' + $_.Name.VariablePath.UserPath }
            $paramBlock = 'param(' + ($paramNames -join ', ') + ')'
            $inner = $paramBlock + "`n" + $inner
        }
        Set-Item -Path "function:\$name" -Value ([ScriptBlock]::Create($inner))
    }

    # Stub the script-level dependencies the extracted functions resolve dynamically.
    # `copilot` is stubbed as a FUNCTION so Mock resolves it on machines where the
    # standalone CLI is not installed (Mock needs Get-Command to find the name).
    function copilot { }
    function Write-Log { param([string]$Message) $script:guardLog += "$Message`n" }
    $script:guardLog = ''
    $Script:KnownBadCopilotCliVersions = @('1.0.83')
}

BeforeEach {
    $script:guardLog = ''
    $env:VIBE_TEST_GUARD = $null
}

It 'Parses the version from copilot --version output' {
    Mock copilot { 'GitHub Copilot CLI 1.0.83.' }
    Get-CopilotCliVersion | Should -Be '1.0.83'
}

It 'Parses a v-prefixed version with trailing advice line' {
    Mock copilot { @('GitHub Copilot CLI v1.0.84.', "Run 'copilot update' to check for updates.") }
    Get-CopilotCliVersion | Should -Be '1.0.84'
}

It 'Returns empty string on unparseable output' {
    Mock copilot { 'copilot not found' }
    Get-CopilotCliVersion | Should -Be ''
}

It 'Returns empty string when copilot throws' {
    Mock copilot { throw 'boom' }
    Get-CopilotCliVersion | Should -Be ''
}

It 'Blocks a known-bad version (fail-closed park)' {
    Mock copilot { 'GitHub Copilot CLI 1.0.83.' }
    Test-CopilotCliBlocked | Should -Be $true
    $script:guardLog | Should -Match 'known-bad'
}

It 'Passes a known-good version' {
    Mock copilot { 'GitHub Copilot CLI 1.0.78.' }
    Test-CopilotCliBlocked | Should -Be $false
}

It 'Proceeds (does NOT park) when the version is unparseable — a broken probe must not silently stall the lane' {
    Mock copilot { '' }
    Test-CopilotCliBlocked | Should -Be $false
    $script:guardLog | Should -Match 'unparseable'
}

It 'A newer version not in the list passes without touching the list' {
    Mock copilot { 'GitHub Copilot CLI 1.1.0.' }
    Test-CopilotCliBlocked | Should -Be $false
    $Script:KnownBadCopilotCliVersions | Should -Be @('1.0.83')
}
}
