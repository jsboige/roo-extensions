<#
.SYNOPSIS
    Drift guard: the four remaining W2 sites + the rebuild label stay vintage-aware (#3713).

.DESCRIPTION
    Dispatch ai-01 2026-09-18 23:04Z: four sites still hardcoded build/index.js after #3725.
    Post-#3713 the published artifact is a build-<sha16>/ vintage behind the build-current
    marker; the legacy build/ is frozen (never rewritten, absent from a fresh clone). A site
    resolving the legacy path only either breaks on a fresh clone or serves the frozen
    vintage forever. These assertions pin the marker resolution so a refactor cannot
    silently drop it.
#>

Describe 'W2 remaining sites are vintage-aware (#3713)' {

    BeforeAll {
        $root = Join-Path $PSScriptRoot '..\..\..'
        $script:diag = Get-Content (Join-Path $root 'scripts\diagnostic\diag-mcps-global.ps1') -Raw
        $script:install = Get-Content (Join-Path $root 'scripts\deployment\install-mcps.ps1') -Raw
        $script:init = Get-Content (Join-Path $root 'scripts\claude\init-claude-code.ps1') -Raw
        $script:bench = Get-Content (Join-Path $root 'scripts\benchmarks\benchmark-get-task-tree.js') -Raw
        $script:rebuild = Get-Content (Join-Path $root 'scripts\mcp\rebuild-roo-state-manager.ps1') -Raw
    }

    It 'diag-mcps-global resolves the build-current marker after npm run build' {
        $script:diag | Should -Match 'build-current'
        $script:diag | Should -Match 'build-\[0-9a-f\]\{16\}'
        # legacy fallback preserved (pre-#3713 checkout)
        $script:diag | Should -Match '"build/index\.js"'
    }

    It 'install-mcps watchPaths target the build-current marker (what changes on republish)' {
        $script:install | Should -Match '\$watchPaths'
        $script:install | Should -Match 'build-current'
        # the dead watch — a single hardcoded legacy path in the config ENTRY — must not
        # come back (line-start form only: the mid-line "nothing built" fallback keeps it).
        $script:install | Should -Not -Match '\r?\n\s+watchPaths\s+= @\(\$buildIndexPath\)'
    }

    It 'init-claude-code checks the published vintage before declaring "needs to be built"' {
        $script:init | Should -Match 'build-current'
        $script:init | Should -Match 'build-\[0-9a-f\]\{16\}'
    }

    It 'benchmark-get-task-tree resolves the server via resolve-build-dir.mjs' {
        $script:bench | Should -Match 'resolve-build-dir\.mjs'
        $script:bench | Should -Match 'resolveBuildDir'
        $script:bench | Should -Not -Match 'SERVER_PATH = path\.resolve\(__dirname[^;]*build/index\.js'
    }

    It 'rebuild-roo-state-manager reports the resolved entry, not the legacy label' {
        $script:rebuild | Should -Not -Match 'Build OK - build/index\.js'
    }
}
