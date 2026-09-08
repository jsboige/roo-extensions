<#
.SYNOPSIS
    Guards the transactional executor pre-flight introduced after the po-2025 stale-build reboot incident.
#>

Describe 'Executor transactional build pre-flight' {
    BeforeAll {
        $preflightPath = Join-Path $PSScriptRoot '..\..\..\scripts\claude\executor-preflight.ps1'
        $freshPath = Join-Path $PSScriptRoot '..\..\..\scripts\claude\ensure-build-fresh.ps1'
        $skillPath = Join-Path $PSScriptRoot '..\..\..\.claude\skills\executor\SKILL.md'
        $commandPath = Join-Path $PSScriptRoot '..\..\..\.claude\commands\executor.md'

        $preflight = Get-Content $preflightPath -Raw
        $fresh = Get-Content $freshPath -Raw
        $skill = Get-Content $skillPath -Raw
        $command = Get-Content $commandPath -Raw

        $errors = $null
        [System.Management.Automation.Language.Parser]::ParseFile($preflightPath, [ref]$null, [ref]$errors)
    }

    It 'parses executor-preflight.ps1 under PowerShell' {
        $errors.Count | Should -Be 0
    }

    It 'requires the live main checkout before synchronizing or rebuilding' {
        $preflight | Should -Match '\$branch\s+-ne\s+''main'''
        $preflight | Should -Match 'must run from main'
    }

    It 'orders pull, submodule materialization, then the strict freshness helper' {
        $pull = $preflight.IndexOf("@('pull', 'origin', 'main', '--no-rebase')")
        $submodule = $preflight.IndexOf("@('submodule', 'update', '--init', 'mcps/internal')")
        $helper = $preflight.IndexOf('-RequireFresh')
        $pull | Should -BeGreaterThan -1
        $submodule | Should -BeGreaterThan $pull
        $helper | Should -BeGreaterThan $submodule
    }

    It 'rejects a submodule path that resolves to the parent repository' {
        $preflight | Should -Match '\$submoduleTop\s+-eq\s+\$parentTop'
        $preflight | Should -Match 'does not match parent gitlink'
    }

    It 'blocks continuation when a rebuild owes a restart' {
        $preflight | Should -Match '\$freshExit\s+-eq\s+10'
        $preflight | Should -Match 'do not continue this executor cycle'
        $preflight | Should -Match 'exit 10'
    }

    It 'keeps legacy helper callers non-blocking unless RequireFresh is explicit' {
        $fresh | Should -Match '\[switch\]\$RequireFresh'
        $fresh | Should -Match 'if \(\$RequireFresh\) \{ exit 1 \}'
        $fresh | Should -Match '\$RequireFresh -and \$restartRequired'
    }

    It 'routes both executor entry points through the transactional pre-flight' {
        $skill | Should -Match 'executor-preflight\.ps1'
        $command | Should -Match 'executor-preflight\.ps1'
        $skill | Should -Match 'Exit `10`'
        $command | Should -Match '\$LASTEXITCODE -eq 10'
        $command | Should -Match 'Restart VS Code requis'
    }

    It 'keeps a missing MCP path non-blocking for legacy helper callers' {
        $hostExe = (Get-Process -Id $PID).Path
        $output = & $hostExe -NoProfile -ExecutionPolicy Bypass -File $freshPath -RepoRoot $TestDrive 2>&1
        $LASTEXITCODE | Should -Be 0
        ($output | Out-String) | Should -Match '\[SKIP\].*MCP server path not found'
    }

    It 'blocks a missing MCP path for strict executor callers' {
        $hostExe = (Get-Process -Id $PID).Path
        $output = & $hostExe -NoProfile -ExecutionPolicy Bypass -File $freshPath -RepoRoot $TestDrive -RequireFresh 2>&1
        $LASTEXITCODE | Should -Be 1
        ($output | Out-String) | Should -Match '\[SKIP\].*MCP server path not found'
    }
}
