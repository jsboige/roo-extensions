Describe 'Claudish proxy-only onboarding' {
    BeforeAll {
        $configRoot = Join-Path $PSScriptRoot '..\..\..\.claude\configs'
        $proxyPath = Join-Path $configRoot 'provider.claudish-proxy.template.json'
        $hybridPath = Join-Path $configRoot 'provider.claudish.template.json'
        $proxy = Get-Content $proxyPath -Raw | ConvertFrom-Json
        $hybrid = Get-Content $hybridPath -Raw | ConvertFrom-Json
        $switcherPath = Join-Path $PSScriptRoot '..\..\claude\Switch-Provider.ps1'
        $deployerPath = Join-Path $PSScriptRoot '..\..\claude\Deploy-ProviderSwitcher.ps1'
        $switcher = Get-Content $switcherPath -Raw
        $deployer = Get-Content $deployerPath -Raw
    }

    It 'uses console authentication without requiring a Claude account' {
        $proxy.forceLoginMethod | Should -Be 'console'
        $proxy.disableClaudeAiConnectors | Should -BeTrue
        $proxy.env.ANTHROPIC_API_KEY | Should -Match '^sk-ant-api03-placeholder-not-used-'
        $proxy.env.ANTHROPIC_AUTH_TOKEN | Should -Be 'placeholder-token-not-used-proxy-handles-auth'
    }

    It 'keeps hub authentication separate from onboarding placeholders' {
        $proxy.env.ANTHROPIC_CUSTOM_HEADERS | Should -Match '(?m)^x-proxy-key: CLAUDISH_PROXY_KEY_PLACEHOLDER$'
        $proxy.env.ANTHROPIC_AUTH_TOKEN | Should -Not -Match 'CLAUDISH_PROXY_KEY'
    }

    It 'advertises no native Anthropic role in proxy-only mode' {
        $proxy.env.ANTHROPIC_DEFAULT_OPUS_MODEL | Should -Not -Match '^claude-'
        $proxy.env.ANTHROPIC_DEFAULT_SONNET_MODEL | Should -Not -Match '^claude-'
        $proxy.env.ANTHROPIC_DEFAULT_HAIKU_MODEL | Should -Not -Match '^claude-'
    }

    It 'leaves hybrid pass-through free of onboarding placeholders and forced console login' {
        $hybrid.PSObject.Properties.Name | Should -Not -Contain 'forceLoginMethod'
        $hybrid.env.PSObject.Properties.Name | Should -Not -Contain 'ANTHROPIC_API_KEY'
        $hybrid.env.PSObject.Properties.Name | Should -Not -Contain 'ANTHROPIC_AUTH_TOKEN'
    }

    It 'registers the distinct provider in deployer and switcher' {
        $switcher | Should -Match '"claudish-proxy"'
        $deployer | Should -Match 'provider\.claudish-proxy\.template\.json'
        $deployer | Should -Match 'provider\.claudish-proxy\.json'
    }

    It 'places the real proxy key only in the custom header' {
        $deployer | Should -Match 'x-proxy-key: \$proxyKey'
        $deployer | Should -Not -Match 'ANTHROPIC_AUTH_TOKEN\s*=\s*\$proxyKey'
    }

    It 'resolves deployer sources from their real repository locations' {
        $deployer | Should -Match '\$configSourceRoot\s*=\s*Join-Path \$repoRoot "\.claude\\configs"'
        $deployer | Should -Match '\$commandSourcePath\s*=\s*Join-Path \$repoRoot "\.claude\\commands\\switch-provider\.md"'
        $deployer | Should -Match '\$switcherSourcePath\s*=\s*Join-Path \$PSScriptRoot "Switch-Provider\.ps1"'
    }

    It 'refreshes both Claudish profiles during credential-preserving updates' {
        $deployer | Should -Match 'Preserving existing credentials while refreshing Claudish profiles'
        $deployer | Should -Match '\$claudishTemplate\.env\.ANTHROPIC_CUSTOM_HEADERS\s*=\s*\$existingHeaders'
        $deployer | Should -Match '\$claudishProxyTemplate\.env\.ANTHROPIC_CUSTOM_HEADERS\s*=\s*\$existingHeaders'
        $deployer | Should -Not -Match 'Configs preserved \(use fresh install to update API keys\)'
    }

    It 'can add proxy-only during update of a legacy three-profile installation' {
        $deployer | Should -Match '\$Update\s+-and\s+\(Test-Path \$anthropicConfigPath\)\s+-and\s+\(Test-Path \$zaiConfigPath\)\s+-and\s*\r?\n\s*\(Test-Path \$claudishConfigPath\)\)'
        $deployer | Should -Match '\$existingProxy\s*=\s*if \(Test-Path \$claudishProxyConfigPath\)'
    }

    It 'backs up existing configs before replacing them' {
        $deployer | Should -Match 'function Backup-IfExists'
        $deployer | Should -Match 'Backup-IfExists \$claudishConfigPath'
        $deployer | Should -Match 'Backup-IfExists \$claudishProxyConfigPath'
    }

    It 'round-trips proxy-only to hybrid without losing machine settings' {
        $originalProfile = $env:USERPROFILE
        try {
            $env:USERPROFILE = $TestDrive
            $claudeRoot = Join-Path $TestDrive '.claude'
            $configs = Join-Path $claudeRoot 'configs'
            New-Item -ItemType Directory -Path $configs -Force | Out-Null
            Copy-Item $proxyPath (Join-Path $configs 'provider.claudish-proxy.json')
            Copy-Item $hybridPath (Join-Path $configs 'provider.claudish.json')

            $settingsPath = Join-Path $claudeRoot 'settings.json'
            $initial = [ordered]@{
                effortLevel = 'high'
                cleanupPeriodDays = 42
                env = [ordered]@{
                    ANTHROPIC_API_KEY = 'stale-client-value'
                    ANTHROPIC_AUTH_TOKEN = 'stale-client-value'
                    MACHINE_ONLY_SETTING = 'keep-me'
                    CLAUDE_CODE_AUTO_COMPACT_WINDOW = '280000'
                    CLAUDE_AUTOCOMPACT_PCT_OVERRIDE = '95'
                }
                model = 'legacy-model'
            }
            [System.IO.File]::WriteAllText(
                $settingsPath,
                ($initial | ConvertTo-Json -Depth 10),
                [System.Text.UTF8Encoding]::new($false)
            )

            & $switcherPath -Provider claudish-proxy *> $null
            $activeProxy = Get-Content $settingsPath -Raw | ConvertFrom-Json
            $activeProxy.forceLoginMethod | Should -Be 'console'
            $activeProxy.disableClaudeAiConnectors | Should -BeTrue
            $activeProxy.env.ANTHROPIC_API_KEY | Should -Match '^sk-ant-api03-placeholder-not-used-'
            $activeProxy.env.ANTHROPIC_AUTH_TOKEN | Should -Be 'placeholder-token-not-used-proxy-handles-auth'
            $activeProxy.env.CLAUDE_CODE_AUTO_COMPACT_WINDOW | Should -Be '280000'
            $activeProxy.env.CLAUDE_AUTOCOMPACT_PCT_OVERRIDE | Should -Be '95'

            & $switcherPath -Provider claudish *> $null
            $activeHybrid = Get-Content $settingsPath -Raw | ConvertFrom-Json
            $activeHybrid.PSObject.Properties.Name | Should -Not -Contain 'forceLoginMethod'
            $activeHybrid.PSObject.Properties.Name | Should -Not -Contain 'disableClaudeAiConnectors'
            $activeHybrid.env.PSObject.Properties.Name | Should -Not -Contain 'ANTHROPIC_API_KEY'
            $activeHybrid.env.PSObject.Properties.Name | Should -Not -Contain 'ANTHROPIC_AUTH_TOKEN'
            $activeHybrid.effortLevel | Should -Be 'high'
            $activeHybrid.cleanupPeriodDays | Should -Be 42
            $activeHybrid.env.MACHINE_ONLY_SETTING | Should -Be 'keep-me'
            $activeHybrid.env.CLAUDE_CODE_AUTO_COMPACT_WINDOW | Should -Be '280000'
            $activeHybrid.env.CLAUDE_AUTOCOMPACT_PCT_OVERRIDE | Should -Be '95'
        } finally {
            $env:USERPROFILE = $originalProfile
        }
    }
}
