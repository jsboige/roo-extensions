<#
    Pester v5 unit tests for migrate-zoo-globalstate-settings.ps1 (#2678).
    Covers the PURE functions: allowlist, extraction filter, validation/safety invariants.
    The I/O orchestrator (Invoke-ZooGlobalStateMigration) is exercised headlessly on real
    state.vscdb blobs, not mocked here.
#>
BeforeAll {
    $projectRoot = (Resolve-Path "$PSScriptRoot\..\..\..").Path
    $modulePath = Join-Path $projectRoot 'scripts\zoo-scheduler\migrate-zoo-globalstate-settings.ps1'
    Import-Module $modulePath -Force -ErrorAction SilentlyContinue
}

Describe 'Get-ZooGlobalSettingsAllowlist' {
    It 'Returns a non-empty allowlist' {
        $allow = Get-ZooGlobalSettingsAllowlist
        $allow.Count | Should -BeGreaterThan 0
    }
    It 'Includes the safety-critical command keys' {
        $allow = Get-ZooGlobalSettingsAllowlist
        $allow | Should -Contain 'allowedCommands'
        $allow | Should -Contain 'deniedCommands'
        $allow | Should -Contain 'autoApprovalEnabled'
        $allow | Should -Contain 'alwaysAllowExecute'
    }
    It 'EXCLUDES the secrets, provider-adjacent refs, modes, and id/taskHistory' {
        $allow = Get-ZooGlobalSettingsAllowlist
        # secrets
        $allow | Should -Not -Contain 'openRouterImageApiKey'
        $allow | Should -Not -Contain 'openAiApiKey'
        # provider blob
        $allow | Should -Not -Contain 'apiProvider'
        $allow | Should -Not -Contain 'currentApiConfigName'
        $allow | Should -Not -Contain 'listApiConfigMeta'
        $allow | Should -Not -Contain 'modeApiConfigs'
        $allow | Should -Not -Contain 'pinnedApiConfigs'
        $allow | Should -Not -Contain 'enhancementApiConfigId'
        $allow | Should -Not -Contain 'profileThresholds'
        # modes (file-based migration is #2379)
        $allow | Should -Not -Contain 'customModes'
        $allow | Should -Not -Contain 'customModePrompts'
        $allow | Should -Not -Contain 'customSupportPrompts'
        # explicit excludes
        $allow | Should -Not -Contain 'id'
        $allow | Should -Not -Contain 'taskHistory'
        # risky version-specific / credential-adjacent
        $allow | Should -Not -Contain 'experiments'
        $allow | Should -Not -Contain 'codebaseIndexConfig'
    }
}

Describe 'ConvertTo-ZooGlobalSettings' {
    It 'Keeps only allowlisted keys present in the source blob' {
        $roo = [PSCustomObject]@{
            autoApprovalEnabled = $true
            deniedCommands      = @('git reset --hard', 'taskkill')
            allowedCommands     = @('git status')
            # these must be dropped:
            id                  = 'install-uuid'
            taskHistory         = @(@{ ts = 1 })
            apiProvider         = 'openai'
            openAiApiKey        = 'sk-leak'
            currentApiConfigName = 'default'
            customModes         = @(@{ slug = 'x' })
            experiments         = @{ foo = $true }
            unknownKey          = 'junk'
        }
        $out = ConvertTo-ZooGlobalSettings -RooState $roo
        $out.ContainsKey('autoApprovalEnabled') | Should -BeTrue
        $out.ContainsKey('deniedCommands')      | Should -BeTrue
        $out.ContainsKey('allowedCommands')     | Should -BeTrue
        # dropped:
        $out.ContainsKey('id')                  | Should -BeFalse
        $out.ContainsKey('taskHistory')         | Should -BeFalse
        $out.ContainsKey('apiProvider')         | Should -BeFalse
        $out.ContainsKey('openAiApiKey')        | Should -BeFalse
        $out.ContainsKey('currentApiConfigName')| Should -BeFalse
        $out.ContainsKey('customModes')         | Should -BeFalse
        $out.ContainsKey('experiments')         | Should -BeFalse
        $out.ContainsKey('unknownKey')          | Should -BeFalse
    }
    It 'Preserves list values (the command arrays are the point)' {
        $roo = [PSCustomObject]@{
            deniedCommands  = @('git reset --hard', 'taskkill', 'Stop-Process')
            allowedCommands = @('git status', 'ls')
        }
        $out = ConvertTo-ZooGlobalSettings -RooState $roo
        @($out['deniedCommands']).Count  | Should -Be 3
        @($out['allowedCommands']).Count | Should -Be 2
        $out['deniedCommands'] | Should -Contain 'git reset --hard'
    }
    It 'Accepts a hashtable input (not just PSCustomObject)' {
        $roo = @{ autoApprovalEnabled = $true; deniedCommands = @('rm') }
        $out = ConvertTo-ZooGlobalSettings -RooState $roo
        $out.ContainsKey('autoApprovalEnabled') | Should -BeTrue
        $out.ContainsKey('deniedCommands')      | Should -BeTrue
    }
    It 'Returns empty hashtable when source has no allowlisted keys' {
        $roo = [PSCustomObject]@{ id = 'x'; taskHistory = @(); apiProvider = 'p' }
        $out = ConvertTo-ZooGlobalSettings -RooState $roo
        $out.Count | Should -Be 0
    }
}

Describe 'Test-GlobalSettingsBlob' {
    It 'Is valid when keys are allowlisted + JSON-serializable' {
        $s = @{ autoApprovalEnabled = $true; deniedCommands = @('rm'); allowedCommands = @('ls') }
        $r = Test-GlobalSettingsBlob -Settings $s
        $r.Valid | Should -BeTrue
        $r.Errors.Count | Should -Be 0
    }
    It 'Is INVALID when a key is outside the allowlist' {
        $s = @{ autoApprovalEnabled = $true; apiProvider = 'should-not-be-here' }
        $r = Test-GlobalSettingsBlob -Settings $s
        $r.Valid | Should -BeFalse
        ($r.Errors | Where-Object { $_ -match 'apiProvider' }).Count | Should -BeGreaterThan 0
    }
    It 'Flags a WARNING when deniedCommands is absent (safety regression)' {
        $s = @{ autoApprovalEnabled = $true; allowedCommands = @('ls') }
        $r = Test-GlobalSettingsBlob -Settings $s
        $r.Valid | Should -BeTrue   # warning, not error
        ($r.Warnings | Where-Object { $_ -match 'deniedCommands absent' }).Count | Should -BeGreaterThan 0
    }
    It 'Flags a WARNING when deniedCommands is present but empty' {
        $s = @{ deniedCommands = @(); allowedCommands = @('ls') }
        $r = Test-GlobalSettingsBlob -Settings $s
        ($r.Warnings | Where-Object { $_ -match 'deniedCommands is empty' }).Count | Should -BeGreaterThan 0
    }
    It 'Flags a WARNING when allowedCommands is absent or empty' {
        $r1 = (Test-GlobalSettingsBlob -Settings @{ deniedCommands = @('rm') }).Warnings
        ($r1 | Where-Object { $_ -match 'allowedCommands absent' }).Count | Should -BeGreaterThan 0

        $r2 = (Test-GlobalSettingsBlob -Settings @{ deniedCommands = @('rm'); allowedCommands = @() }).Warnings
        ($r2 | Where-Object { $_ -match 'allowedCommands is empty' }).Count | Should -BeGreaterThan 0
    }
}
