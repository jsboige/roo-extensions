<#
.SYNOPSIS
    Guard test: ensure-build-fresh.ps1 must keep its #3489 contracts (ARM guard, -Arm escape, defer-before-build).

.DESCRIPTION
    ensure-build-fresh.ps1 is the interactive pre-flight helper that rebuilds the roo-state-manager
    build/ dir when stale (#2822). Rebuilding while live RSM host processes run produces mixed ESM
    graphs and the assertSharedStoreAccessible crash that makes inbox unreadable until VS Code
    restart (#3489).

    This is a STRUCTURAL guard (AST + content): the unit CI must not trigger a rebuild or touch live
    processes. It asserts:
      - the script parses,
      - the ARM guard probes live RSM hosts (Get-CimInstance + roo-state-manager build/index.js|mcp-wrapper.cjs regex),
      - defer is the default (ARMED-DEFER emitted before the build invocation when live hosts exist),
      - the -Arm escape hatch is declared as a named switch and warns that a restart is required,
      - the crash signature it protects against (#3489 / assertSharedStoreAccessible) is named,
      - the existing FRESH no-op path is preserved.

.NOTES
    Issue #3489
    Requires Pester 5+
#>

Describe 'ensure-build-fresh ARM guard (#3489)' {
    BeforeAll {
        $scriptPath = Join-Path $PSScriptRoot '..\..\..\scripts\claude\ensure-build-fresh.ps1'
        $content = Get-Content $scriptPath -Raw
        $tokens = $null
        $errors = $null
        [System.Management.Automation.Language.Parser]::ParseFile($scriptPath, [ref]$tokens, [ref]$errors)
    }

    It 'Parses the script without syntax errors' {
        $errors.Count | Should -Be 0
    }

    It 'Probes live RSM host processes via Get-CimInstance Win32_Process' {
        $content | Should -Match 'Get-CimInstance Win32_Process'
        $content | Should -Match 'roo-state-manager'
        $content | Should -Match 'CommandLine'
        $content | Should -Match 'mcp-wrapper'
        $content | Should -Match '\.cjs'
    }

    It 'Refuses to rebuild by default when live hosts exist (ARMED-DEFER decided before the build)' {
        $content | Should -Match 'ARMED-DEFER'
        $deferIdx = $content.IndexOf('ARMED-DEFER')
        $buildIdx = $content.IndexOf('& npm.cmd run build')
        $deferIdx | Should -BeGreaterThan 0
        $buildIdx | Should -BeGreaterThan $deferIdx
    }

    It 'Declares the named -Arm escape hatch switch' {
        $content | Should -Match '\[switch\]\$Arm'
    }

    It 'The -Arm override warns that a VS Code restart is required' {
        $content | Should -Match 'ARM'
        $content | Should -Match 'VS Code restart'
    }

    It 'Names the crash signature it protects against (#3489 / assertSharedStoreAccessible)' {
        $content | Should -Match 'assertSharedStoreAccessible'
        $content | Should -Match '#3489'
    }

    It 'Preserves the FRESH no-op path' {
        $content | Should -Match 'build/ is up to date'
    }
}
