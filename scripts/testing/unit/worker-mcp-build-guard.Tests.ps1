<#
.SYNOPSIS
    Guard test: Sync-McpSubmoduleBuild (start-claude-worker.ps1) must never rebuild the MCP
    build/ inline, unguarded (#3489).

.DESCRIPTION
    The worker is a SCHEDULED process: it cannot restart VS Code. Rebuilding build/ under live
    RSM hosts replaces the ESM modules those hosts already imported -> assertSharedStoreAccessible
    on their next dynamic import -> inbox unreadable, with nobody able to close the armed window
    (measured po-2024, 2026-09-07 02:08Z).

    Until the 2026-09-08 arbitration this function ran `Remove-Item build/ -Recurse` + `npm.cmd run
    build` with NO host probe of any kind, while ensure-build-fresh.ps1 -- the guarded path --
    refused on the INTERACTIVE caller that *could* restart. This test pins the corrected shape.

    Structural (AST): the unit CI must never spawn a build or touch live processes.

    Assertions run against CODE ONLY (comment tokens stripped). The first draft of this file
    asserted on the raw function extent and went red on its own explanatory comments -- a test
    that reads prose tests intention, not behaviour.

.NOTES
    Issue #3489
    Requires Pester 5+
#>

Describe 'Worker MCP build guard (#3489)' {
    BeforeAll {
        $scriptPath = Join-Path $PSScriptRoot '..\..\..\scripts\scheduling\start-claude-worker.ps1'
        $errors = $null
        $tokens = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($scriptPath, [ref]$tokens, [ref]$errors)

        # Scope every assertion to the FUNCTION BODY. The file is ~4700 lines and embeds
        # "npm run build" inside Claude prompt strings elsewhere (maintenance task prompt) --
        # asserting on the whole file would match those and prove nothing.
        $fn = $ast.FindAll({
            param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
                      $n.Name -eq 'Sync-McpSubmoduleBuild'
        }, $true) | Select-Object -First 1

        # CODE ONLY: drop comment tokens, so the negative assertions below cannot be satisfied
        # (or defeated) by the comments that explain what was removed.
        $fnCode = ''
        if ($fn) {
            $s = $fn.Extent.StartOffset
            $e = $fn.Extent.EndOffset
            $fnCode = ($tokens |
                Where-Object { $_.Extent.StartOffset -ge $s -and $_.Extent.EndOffset -le $e -and
                               $_.Kind -ne [System.Management.Automation.Language.TokenKind]::Comment } |
                ForEach-Object { $_.Text }) -join ' '
        }
    }

    It 'Parses the worker script without syntax errors' {
        $errors.Count | Should -Be 0
    }

    It 'Still defines Sync-McpSubmoduleBuild' {
        $fn | Should -Not -BeNullOrEmpty
        $fnCode | Should -Not -BeNullOrEmpty
    }

    It 'Does NOT rebuild inline: no npm build and no build/ deletion in the CODE' {
        # The pre-arbitration shape, in the one place on the fleet that cannot restart VS Code.
        $fnCode | Should -Not -Match 'npm(\.cmd)?\s+run\s+build'
        $fnCode | Should -Not -Match 'Remove-Item'

        # Positive control: the predicates DO bite the shape they are meant to catch.
        $pre = 'Remove-Item (Join-Path $McpServerPath "build") -Recurse -Force ; & npm.cmd run build'
        $pre | Should -Match 'Remove-Item'
        $pre | Should -Match 'npm(\.cmd)?\s+run\s+build'
    }

    It 'Invokes the guarded helper with the repo root AND -Headless' {
        # Asserts the invocation SHAPE, not the presence of the words somewhere in the function.
        $fnCode | Should -Match 'ensure-build-fresh\.ps1'
        $fnCode | Should -Match '-File\s+\$ensureScript\s+-RepoRoot\s+\$Path\s+-Headless'
    }

    It 'Invokes via powershell, not pwsh (PS7 absent on some fleet machines, #2368)' {
        $fnCode | Should -Match '&\s*powershell\s'
        $fnCode | Should -Not -Match '&\s*pwsh\s'
    }

    It 'Treats a missing helper as SKIP, never as licence to rebuild unguarded' {
        # If ensure-build-fresh.ps1 is absent the function must do nothing -- falling back to an
        # inline rebuild would restore exactly the hazard this guard removes.
        $fnCode | Should -Match 'Test-Path\s+\$ensureScript'
        $fnCode | Should -Match 'SKIPPED'
    }

    It 'Surfaces a deferral at WARN instead of swallowing it' {
        # A silent persistent deferral is indistinguishable from inaction (po-2026, #3489).
        $fnCode | Should -Match "ARMED-DEFER"
        $fnCode | Should -Match "ARMED-DEFER'[\s\S]{0,900}?`"WARN`""
    }
}
