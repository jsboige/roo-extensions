#!/usr/bin/env pwsh
# Pester 5+ tests for the known-bad CLI burn guard (start-copilot-dispatcher.ps1)
# Context: 06/09 lane-perenne proposal — gh-copilot CLI 1.0.83 refuses all mutations
# on work-prompt sessions server-side; every scheduled run burned ~15 premium
# credits and ended idle. The guard parks the dispatcher fail-closed on known-bad
# versions (list lives in $Script:KnownBadCopilotCliVersions).

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
    function Write-Log { param([string]$Message) $script:guardLog += "$Message`n" }
    $script:guardLog = ''
    $Script:KnownBadCopilotCliVersions = @('1.0.83')
}

BeforeEach {
    $script:guardLog = ''
    $env:VIBE_TEST_GUARD = $null
}

It 'Parses the version from gh copilot --version output' {
    Mock gh { 'GitHub Copilot CLI 1.0.83.' }
    Get-CopilotCliVersion | Should -Be '1.0.83'
}

It 'Parses a v-prefixed version with trailing advice line' {
    Mock gh { @('GitHub Copilot CLI v1.0.84.', "Run 'copilot update' to check for updates.") }
    Get-CopilotCliVersion | Should -Be '1.0.84'
}

It 'Returns empty string on unparseable output' {
    Mock gh { 'copilot not found' }
    Get-CopilotCliVersion | Should -Be ''
}

It 'Returns empty string when gh throws' {
    Mock gh { throw 'boom' }
    Get-CopilotCliVersion | Should -Be ''
}

It 'Blocks a known-bad version (fail-closed park)' {
    Mock gh { 'GitHub Copilot CLI 1.0.83.' }
    Test-CopilotCliBlocked | Should -Be $true
    $script:guardLog | Should -Match 'known-bad'
}

It 'Passes a known-good version' {
    Mock gh { 'GitHub Copilot CLI 1.0.78.' }
    Test-CopilotCliBlocked | Should -Be $false
}

It 'Proceeds (does NOT park) when the version is unparseable — a broken probe must not silently stall the lane' {
    Mock gh { '' }
    Test-CopilotCliBlocked | Should -Be $false
    $script:guardLog | Should -Match 'unparseable'
}

It 'A newer version not in the list passes without touching the list' {
    Mock gh { 'GitHub Copilot CLI 1.1.0.' }
    Test-CopilotCliBlocked | Should -Be $false
    $Script:KnownBadCopilotCliVersions | Should -Be @('1.0.83')
}
}
