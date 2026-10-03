<#
.SYNOPSIS
    Drift-guard for the all-branch fetch in scripts/claude/executor-preflight.ps1.

    With git's default on-demand submodule recursion, `git fetch origin` also
    fetches every submodule SHA referenced by newly fetched parent branches. A
    branch whose gitlink was never pushed to the submodule remote then fails
    the fetch ("upload-pack: not our ref"), and Invoke-GitChecked aborts the
    whole pre-flight. Measured 03/10 on po-2024 and web1 after two old recovery
    branches were pushed. The fetch must not recurse; the explicit
    `submodule update --init mcps/internal` fetches the one SHA main needs.
#>

Describe 'Executor pre-flight all-branch fetch does not recurse into submodules' {
    BeforeAll {
        $preflightPath = Join-Path $PSScriptRoot '..\..\..\scripts\claude\executor-preflight.ps1'
        $preflight = Get-Content $preflightPath -Raw

        $errors = $null
        [System.Management.Automation.Language.Parser]::ParseFile($preflightPath, [ref]$null, [ref]$errors)
        $preflightParseErrors = @($errors).Count
    }

    It 'parses cleanly' {
        $preflightParseErrors | Should -Be 0
    }

    It 'fetches origin with --recurse-submodules=no' {
        $preflight | Should -Match "Invoke-GitChecked @\('fetch', '--recurse-submodules=no', 'origin'\)"
    }

    It 'keeps no recursive all-branch fetch' {
        $preflight | Should -Not -Match "Invoke-GitChecked @\('fetch', 'origin'\)"
    }

    It 'still materializes the mcps/internal gitlink after the pull' {
        $iFetch = $preflight.IndexOf("'fetch', '--recurse-submodules=no', 'origin'")
        $iUpdate = $preflight.IndexOf("@('submodule', 'update', '--init', 'mcps/internal')")
        $iFetch | Should -BeGreaterThan -1
        $iUpdate | Should -BeGreaterThan $iFetch
    }
}
