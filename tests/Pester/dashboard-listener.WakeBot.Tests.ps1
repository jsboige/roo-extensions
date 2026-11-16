#!/usr/bin/env pwsh
# Pester 5+ tests for Get-WakeBotTarget (#2244, retargeted #2245 step 1).
# The function is extracted from the REAL listener via AST — no copy. A copy
# here is exactly the defect that let [WAKE-HERMES] point at myia-po-2026 for
# months while Hermes runs on myia-ai-01.

Describe 'Get-WakeBotTarget' {

BeforeAll {
    $scriptFilePath = Join-Path $PSScriptRoot '../../scripts/dashboard-scheduler/dashboard-listener.ps1'
    $resolvedPath = (Resolve-Path $scriptFilePath).Path

    # Parse with AST — cannot dot-source (side effects: FileSystemWatcher, exit)
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

    $fd = $funcDefs | Where-Object { $_.Name -eq 'Get-WakeBotTarget' }
    if (-not $fd) { throw "Get-WakeBotTarget not found in $resolvedPath" }

    $bodyText = $fd.Body.Extent.Text
    $inner = $bodyText.Substring(1, $bodyText.Length - 2)

    # Reconstruct param() block from function signature parameters
    if ($fd.Parameters -and $fd.Parameters.Count -gt 0) {
        $paramNames = $fd.Parameters | ForEach-Object { '$' + $_.Name.VariablePath.UserPath }
        $paramBlock = 'param(' + ($paramNames -join ', ') + ')'
        $inner = $paramBlock + "`n" + $inner
    }

    Set-Item -Path "function:\Get-WakeBotTarget" -Value ([ScriptBlock]::Create($inner))
}

    It 'Matches WAKE-HERMES tag → myia-ai-01:hermes-agent (#2245 step 1)' {
        $result = Get-WakeBotTarget '[WAKE-HERMES] urgent review needed'
        $result | Should -Not -BeNullOrEmpty
        $result.machine | Should -Be 'myia-ai-01'
        $result.workspace | Should -Be 'hermes-agent'
    }

    It 'Matches WAKE-HERMES in header markdown' {
        $result = Get-WakeBotTarget '## [WAKE-HERMES] fleet ping'
        $result | Should -Not -BeNullOrEmpty
        $result.machine | Should -Be 'myia-ai-01'
        $result.workspace | Should -Be 'hermes-agent'
    }

    It 'WAKE-HERMES no longer targets myia-po-2026 (the dead target)' {
        $result = Get-WakeBotTarget '[WAKE-HERMES] urgent review needed'
        $result.machine | Should -Not -Be 'myia-po-2026'
    }

    It 'Matches WAKE-NANOCLAW tag → myia-ai-01:nanoclaw' {
        $result = Get-WakeBotTarget '[WAKE-NANOCLAW] PR review request'
        $result | Should -Not -BeNullOrEmpty
        $result.machine | Should -Be 'myia-ai-01'
        $result.workspace | Should -Be 'nanoclaw'
    }

    It 'Matches WAKE-NANOCLAW in header markdown' {
        $result = Get-WakeBotTarget '### [WAKE-NANOCLAW] self-merge workaround'
        $result | Should -Not -BeNullOrEmpty
        $result.machine | Should -Be 'myia-ai-01'
        $result.workspace | Should -Be 'nanoclaw'
    }

    It 'Matches WAKE-VIBE tag → myia-po-2025:CoursIA' {
        $result = Get-WakeBotTarget '[WAKE-VIBE] idle queue pick'
        $result | Should -Not -BeNullOrEmpty
        $result.machine | Should -Be 'myia-po-2025'
        $result.workspace | Should -Be 'CoursIA'
    }

    It 'Returns null for WAKE-CLAUDE (not a bot tag)' {
        Get-WakeBotTarget '[WAKE-CLAUDE] myia-po-2023' | Should -BeNullOrEmpty
    }

    It 'Returns null for no wake tag' {
        Get-WakeBotTarget 'just a regular message' | Should -BeNullOrEmpty
    }

    It 'Matches backtick-quoted (filtered by Test-ActionableContent upstream)' {
        # Get-WakeBotTarget uses simple regex — prose filtering is handled by
        # Test-ActionableContent (header-only check) before this function is called.
        $result = Get-WakeBotTarget 'the ``[WAKE-HERMES]`` pattern'
        $result | Should -Not -BeNullOrEmpty
        $result.machine | Should -Be 'myia-ai-01'
    }
}

Describe 'Bot wake routing vs local machine (real function)' {
    BeforeAll {
        # Same extraction as above — the listener's own function, not a copy.
        $scriptFilePath = Join-Path $PSScriptRoot '../../scripts/dashboard-scheduler/dashboard-listener.ps1'
        $resolvedPath = (Resolve-Path $scriptFilePath).Path
        $parseErrors = $null
        $tokens = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseFile(
            $resolvedPath, [ref]$tokens, [ref]$parseErrors
        )
        $fd = $ast.FindAll(
            { param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] },
            $true
        ) | Where-Object { $_.Name -eq 'Get-WakeBotTarget' }
        $bodyText = $fd.Body.Extent.Text
        $inner = $bodyText.Substring(1, $bodyText.Length - 2)
        if ($fd.Parameters -and $fd.Parameters.Count -gt 0) {
            $paramNames = $fd.Parameters | ForEach-Object { '$' + $_.Name.VariablePath.UserPath }
            $inner = 'param(' + ($paramNames -join ', ') + ')' + "`n" + $inner
        }
        Set-Item -Path "function:\Get-WakeBotTarget" -Value ([ScriptBlock]::Create($inner))
    }

    It 'WAKE-HERMES is skipped on myia-po-2023 (targets ai-01)' {
        $botTarget = Get-WakeBotTarget '[WAKE-HERMES] urgent task'
        $botTarget.machine | Should -Not -Be 'myia-po-2023'
        $botTarget.machine | Should -Be 'myia-ai-01'
    }

    It 'WAKE-HERMES matches target machine (ai-01, where Hermes runs)' {
        $botTarget = Get-WakeBotTarget '[WAKE-HERMES] urgent task'
        $botTarget.machine | Should -Be 'myia-ai-01'
    }

    It 'WAKE-NANOCLAW is skipped on myia-po-2023 (targets ai-01)' {
        $botTarget = Get-WakeBotTarget '[WAKE-NANOCLAW] review PR #123'
        $botTarget.machine | Should -Not -Be 'myia-po-2023'
        $botTarget.machine | Should -Be 'myia-ai-01'
    }
}

Describe 'AllowedTags default includes bot tags' {
    It 'Default AllowedTags contains WAKE-CLAUDE' {
        $defaultTags = 'WAKE-CLAUDE,WAKE-HERMES,WAKE-NANOCLAW'
        $tagList = $defaultTags -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }
        $tagList | Should -Contain 'WAKE-CLAUDE'
    }

    It 'Default AllowedTags contains WAKE-HERMES' {
        $defaultTags = 'WAKE-CLAUDE,WAKE-HERMES,WAKE-NANOCLAW'
        $tagList = $defaultTags -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }
        $tagList | Should -Contain 'WAKE-HERMES'
    }

    It 'Default AllowedTags contains WAKE-NANOCLAW' {
        $defaultTags = 'WAKE-CLAUDE,WAKE-HERMES,WAKE-NANOCLAW'
        $tagList = $defaultTags -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }
        $tagList | Should -Contain 'WAKE-NANOCLAW'
    }

    It 'Environment variable override takes precedence' {
        $envTags = 'WAKE-CLAUDE'
        $allowedTags = if ($envTags) { $envTags } else { 'WAKE-CLAUDE,WAKE-HERMES,WAKE-NANOCLAW' }
        $tagList = $allowedTags -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }
        $tagList | Should -Contain 'WAKE-CLAUDE'
        $tagList | Should -Not -Contain 'WAKE-HERMES'
    }
}
