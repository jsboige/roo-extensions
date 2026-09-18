<#
.SYNOPSIS
    Behavioural test: zombie cleanup must locate v5 vintage hosts as well as legacy ones (#3713 W2).

.DESCRIPTION
    v5 wrappers spawn the server from an immutable build-<sha16>/ vintage, not the frozen legacy
    build/. The zombie-cleanup process pattern predates v5: `build[\/]+index.js` does NOT match
    `build-6bb7292cbd7b3fcb\index.js`, so on an upgraded machine every v5 host is unlocatable —
    live-PID detection exits 2 and older-cluster zombies are never cleaned (dispatch ai-01
    2026-09-18, follow-up W2).

    The pattern is EXTRACTED from the script under test (a copy pasted here could diverge), then
    exercised against representative command lines.

.NOTES
    Issue #3713 follow-up W2. Requires Pester 5+.
#>

Describe 'cleanup-mcp-zombies vintage-aware process pattern (#3713 W2)' {

    BeforeAll {
        $scriptPath = Join-Path $PSScriptRoot '..\..\..\scripts\mcp\cleanup-mcp-zombies.ps1'
        $content = Get-Content $scriptPath -Raw

        # Extract the Pattern value paired with the build/index.js role (the stable Name key).
        $match = [regex]::Match($content, 'Name = "build/index\.js";\s*Pattern = "([^"]+)"')
        if (-not $match.Success) { throw 'build/index.js pattern entry not found in cleanup-mcp-zombies.ps1' }
        $script:pattern = $match.Groups[1].Value
    }

    It 'Extracts a pattern from the script (fixture sanity)' {
        $script:pattern | Should -Not -BeNullOrEmpty
    }

    It 'Matches a legacy v4 host command line' {
        'node D:\Dev\roo-extensions\mcps\internal\servers\roo-state-manager\build\index.js' |
            Should -Match $script:pattern
    }

    It 'Matches a v5 vintage host command line (build-<sha16>)' {
        'node D:\Dev\roo-extensions\mcps\internal\servers\roo-state-manager\build-6bb7292cbd7b3fcb\index.js' |
            Should -Match $script:pattern
    }

    It 'Still excludes the build-out scratch dir and the wrapper' {
        # build-out/ is tsc scratch, never a live host; the wrapper is matched by its own
        # pattern entry and must not be caught by the server-entry one (double counting
        # would let a wrapper be mistaken for a server proc in cluster analysis).
        'node D:\Dev\roo-extensions\mcps\internal\servers\roo-state-manager\build-out\index.js' |
            Should -Not -Match $script:pattern
        'node D:\Dev\roo-extensions\mcps\internal\servers\roo-state-manager\mcp-wrapper.cjs' |
            Should -Not -Match $script:pattern
    }
}
