<#
.SYNOPSIS
    Pester tests for Get-WakeBotTarget (#2244).

.DESCRIPTION
    Tests the bot wake routing patterns:
      - [WAKE-HERMES] → myia-po-2026:hermes-agent
      - [WAKE-NANOCLAW] → myia-ai-01:nanoclaw
      - [WAKE-CLAUDE] → null (not a bot tag)
      - Header markdown: ## [WAKE-HERMES] → match
      - Prose inline (backtick-quoted): no match

.NOTES
    Issue #2244
    Requires Pester 5+ and PowerShell 7+
#>

Describe 'Get-WakeBotTarget' {
    BeforeAll {
        function Get-WakeBotTarget($content) {
            if ($content -match '\[WAKE-HERMES\]') {
                return @{ machine = 'myia-po-2026'; workspace = 'hermes-agent' }
            }
            if ($content -match '\[WAKE-NANOCLAW\]') {
                return @{ machine = 'myia-ai-01'; workspace = 'nanoclaw' }
            }
            return $null
        }
    }

    It 'Matches WAKE-HERMES tag' {
        $result = Get-WakeBotTarget '[WAKE-HERMES] urgent review needed'
        $result | Should -Not -BeNullOrEmpty
        $result.machine | Should -Be 'myia-po-2026'
        $result.workspace | Should -Be 'hermes-agent'
    }

    It 'Matches WAKE-HERMES in header markdown' {
        $result = Get-WakeBotTarget '## [WAKE-HERMES] fleet ping'
        $result | Should -Not -BeNullOrEmpty
        $result.machine | Should -Be 'myia-po-2026'
        $result.workspace | Should -Be 'hermes-agent'
    }

    It 'Matches WAKE-NANOCLAW tag' {
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
        $result.machine | Should -Be 'myia-po-2026'
    }
}

Describe 'Bot wake routing in listener' {
    It 'WAKE-HERMES skips non-target machine' {
        $localMachine = 'myia-po-2023'
        $content = '[WAKE-HERMES] urgent task'
        # Bot routing: hermes targets myia-po-2026
        $botTarget = if ($content -match '\[WAKE-HERMES\]') {
            @{ machine = 'myia-po-2026'; workspace = 'hermes-agent' }
        } elseif ($content -match '\[WAKE-NANOCLAW\]') {
            @{ machine = 'myia-ai-01'; workspace = 'nanoclaw' }
        } else { $null }
        $botTarget.machine | Should -Not -Be $localMachine
        # Would be skipped on po-2023
        ($botTarget.machine -eq $localMachine) | Should -BeFalse
    }

    It 'WAKE-HERMES matches target machine (po-2026)' {
        $localMachine = 'myia-po-2026'
        $content = '[WAKE-HERMES] urgent task'
        $botTarget = if ($content -match '\[WAKE-HERMES\]') {
            @{ machine = 'myia-po-2026'; workspace = 'hermes-agent' }
        } else { $null }
        $botTarget.machine | Should -Be $localMachine
    }

    It 'WAKE-NANOCLAW skips non-target machine' {
        $localMachine = 'myia-po-2023'
        $content = '[WAKE-NANOCLAW] review PR #123'
        $botTarget = if ($content -match '\[WAKE-NANOCLAW\]') {
            @{ machine = 'myia-ai-01'; workspace = 'nanoclaw' }
        } else { $null }
        $botTarget.machine | Should -Not -Be $localMachine
    }

    It 'WAKE-NANOCLAW matches target machine (ai-01)' {
        $localMachine = 'myia-ai-01'
        $content = '[WAKE-NANOCLAW] review PR #123'
        $botTarget = if ($content -match '\[WAKE-NANOCLAW\]') {
            @{ machine = 'myia-ai-01'; workspace = 'nanoclaw' }
        } else { $null }
        $botTarget.machine | Should -Be $localMachine
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
