# Unit tests: filter for non-essential paths before the worker auto-commit
#
# Test-WorktreeHasChanges auto-commits whatever remains in the worktree at the end of a session,
# after filtering $NonEssentialPatterns. Measured on 30/09 (PR #3969, worker po-2025): a scratch
# script written with `$TEMP/...` in PowerShell (where only `$env:TEMP` expands) created a
# literal `$TEMP/` directory at the root of the worktree, which the auto-commit turned into a PR.
#
# The tests evaluate the REAL pattern list extracted from the worker, not a copy of it.
# Pester v5 syntax, run in CI by the `unit-pester` job.

BeforeAll {
    $projectRoot = (Resolve-Path -Path "$PSScriptRoot/../../..").Path
    $content = Get-Content (Join-Path $projectRoot "scripts/scheduling/start-claude-worker.ps1") -Raw

    $fnPos = $content.IndexOf('function Test-WorktreeHasChanges')
    $fnBody = $content.Substring($fnPos)
    $start = $fnBody.IndexOf('$NonEssentialPatterns = @(')
    $end = $fnBody.IndexOf("`n            )", $start)
    $literal = $fnBody.Substring($start + '$NonEssentialPatterns = '.Length, $end - $start - '$NonEssentialPatterns = '.Length + "`n            )".Length)
    $script:patterns = @(& ([ScriptBlock]::Create($literal)))

    function script:Test-NonEssential([string]$line) {
        foreach ($pat in $script:patterns) { if ($line -match $pat) { return $true } }
        return $false
    }
}

Describe "Worker - non-essential paths before the auto-commit" {

    It "Extracts a non-empty pattern list" {
        $script:patterns.Count | Should -BeGreaterThan 5
    }

    It "Filters an untracked directory named after an unexpanded variable (#3969)" {
        Test-NonEssential '?? $TEMP/' | Should -Be $true
        Test-NonEssential '?? $TEMP/inspect-backups.ps1' | Should -Be $true
        Test-NonEssential '?? "${env:TMP}/x.ps1"' | Should -Be $true
    }

    It "Does not filter a legitimate path" {
        Test-NonEssential '?? scripts/scheduling/new-feature.ps1' | Should -Be $false
        Test-NonEssential ' M docs/harness/reference/INDEX.md' | Should -Be $false
    }

    It "Does not filter a '$' in the middle of a path" {
        Test-NonEssential '?? docs/price-$5.md' | Should -Be $false
    }
}
