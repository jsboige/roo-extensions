<#
.SYNOPSIS
    Drift-guard for the #3731 stderr class, lot 2 family `submit-pr` in
    scripts/worktrees/submit-pr.ps1 (4 adjacent `2>$null` sites under the
    file-global EAP=Stop).

    A PS-level `2>$null` on a native still lets PS 5.1 mint ErrorRecords from
    stderr before discarding them; under EAP=Stop the first one terminates the
    script on a call that succeeded. The sites now discard stderr at the cmd.exe
    layer (`2>nul` inside `& cmd /c "..."`): no ErrorRecord ever exists, under
    any EAP, and the PS guards on empty output keep their meaning.
#>

Describe 'submit-pr stderr class, lot 2 family (#3731)' {
    BeforeAll {
        $scriptPath = Join-Path $PSScriptRoot '..\..\..\scripts\worktrees\submit-pr.ps1'
        $script:src = Get-Content $scriptPath -Raw

        $errors = $null
        [System.Management.Automation.Language.Parser]::ParseFile($scriptPath, [ref]$null, [ref]$errors)
        $script:parseErrors = @($errors).Count
    }

    It 'parses cleanly' {
        $script:parseErrors | Should -Be 0
    }

    It 'reads the branch, commit count and log via cmd-layer stderr discard' {
        $script:src | Should -Match 'cmd /c "git branch --show-current 2>nul"'
        $script:src | Should -Match 'cmd /c "git rev-list --count origin/main\.\.\$currentBranch 2>nul"'
        $script:src | Should -Match 'cmd /c "git log --oneline origin/main\.\.\$currentBranch 2>nul"'
        # The bare PS-level redirects on those three calls are gone.
        $script:src | Should -Not -Match 'git branch --show-current 2>\$null'
        $script:src | Should -Not -Match 'git rev-list --count "origin/main\.\.\$currentBranch" 2>\$null'
        $script:src | Should -Not -Match 'git log --oneline "origin/main\.\.\$currentBranch" 2>\$null'
    }

    It 'reads the issue title through cmd with the empty-fallback try/catch intact' {
        $script:src | Should -Match 'cmd /c "gh issue view \$IssueNumber --repo jsboige/roo-extensions --json title 2>nul"'
        $script:src | Should -Not -Match 'gh issue view \$IssueNumber --repo jsboige/roo-extensions --json title 2>\$null'
        # The downstream fallback when the issue cannot be read survives.
        $script:src | Should -Match 'Feature #\$IssueNumber'
    }
}
