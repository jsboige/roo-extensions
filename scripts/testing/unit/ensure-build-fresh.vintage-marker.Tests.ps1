<#
.SYNOPSIS
    Guard test: a build-current marker the guard cannot use must be SAID, not silently skipped (#3713 W3).

.DESCRIPTION
    The vintage naming pattern (^build-[0-9a-f]{16}$) is duplicated between this guard and the
    submodule's publish-build.mjs. Before W3, a marker whose content failed the regex -- or named
    a vintage whose index.js was gone -- fell through to the legacy mtime path WITHOUT a word,
    reading as "no vintages on this machine" and hiding the drift (dispatch ai-01 2026-09-18).

    This is a STRUCTURAL guard (AST + content), same family as ensure-build-fresh.arm-guard:
    the unit CI must not run the script for real. It asserts:
      - the script parses,
      - unrecognized marker content emits a WARN naming the divergence, in CODE (token-level,
        not a comment),
      - a marker naming a missing vintage sets vintageMode+vintageStale (republish recovery,
        which arms nothing) instead of falling to the legacy path that ARMs live hosts.

.NOTES
    Issue #3713 follow-up W3. Requires Pester 5+.
#>

Describe 'ensure-build-fresh vintage marker handling (#3713 W3)' {

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

    It 'Says it when the marker content is unrecognized — no silent mtime fallthrough' {
        # Token-level (a comment quoting the wording would make a raw -Match green for prose).
        # Kind -like 'String*': the WARN is double-quoted (StringExpandable), single-quoted
        # literals are StringLiteral — both are code, comments are not.
        $warnToken = $tokens |
            Where-Object { $_.Kind -like 'String*' -and $_.Text -like '*marker content unrecognized*pattern divergence*' } |
            Select-Object -First 1
        $warnToken | Should -Not -BeNullOrEmpty
    }

    It 'Repairs a marker naming a missing vintage via republish (vintageMode+vintageStale), not a legacy ARM' {
        # The missing-index.js branch must set BOTH flags inside the marker block and before
        # the Decision section: vintageMode suppresses the ARM guard (a republish arms
        # nothing, #3713) and vintageStale forces the rebuild that repairs the marker.
        $missingIdx = $content.IndexOf('its index.js is missing')
        $missingIdx | Should -BeGreaterThan 0

        $markerIfIdx = $content.IndexOf('if (Test-Path $markerFile)')
        $decisionIdx = $content.IndexOf('# --- Decision ---')

        $modeIdx  = $content.LastIndexOf('$vintageMode = $true',  $missingIdx)
        $staleIdx = $content.LastIndexOf('$vintageStale = $true', $missingIdx)

        # Both assignments sit inside the marker block, before the Decision section.
        $modeIdx  | Should -BeGreaterThan $markerIfIdx
        $staleIdx | Should -BeGreaterThan $markerIfIdx
        $modeIdx  | Should -BeLessThan $decisionIdx
        $staleIdx | Should -BeLessThan $decisionIdx

        # And the missing-vintage WARN itself is a string literal in CODE, not prose.
        $missingToken = $tokens |
            Where-Object { $_.Kind -like 'String*' -and $_.Text -like '*index.js is missing*republishing to repair*' } |
            Select-Object -First 1
        $missingToken | Should -Not -BeNullOrEmpty
    }
}
