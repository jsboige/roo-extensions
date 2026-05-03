# Tests unitaires pour les guards anti-PR-triviale du worker script (#1949)
# Regression guards + validation logique
# Syntaxe Pester v3 (Windows PowerShell 5.1)
#
# Usage: Invoke-Pester .\scripts\testing\unit\worker-pr-guards.Tests.ps1

Describe "Worker PR Guards - #1949 Anti-Trivial-PR" {

    $projectRoot = (Resolve-Path -Path "$PSScriptRoot\..\..\..").Path
    $workerScript = Join-Path $projectRoot "scripts\scheduling\start-claude-worker.ps1"
    $content = Get-Content $workerScript -Raw

    Context "Guard #1949 - Submodule pointer dedup" {

        It "Must contain submodule dedup guard" {
            ($content -match 'DEDUP PR BLOCKED \(#1949\)') | Should Be $true
        }

        It "Must check origin/main for existing submodule pointer" {
            ($content -match 'git ls-tree origin/main') | Should Be $true
        }

        It "Must compare NewPointer with MainPointer" {
            ($content -match 'MainPointer -eq \$NewPointer') | Should Be $true
        }

        It "Must clean up remote branch on dedup block" {
            $pattern = 'Remove-RemoteBranch.*dedup submodule pointer \(#1949\)'
            ($content -match $pattern) | Should Be $true
        }
    }

    Context "Guard #1949 - Trivial change detection" {

        It "Must contain trivial PR guard" {
            ($content -match 'TRIVIAL PR BLOCKED \(#1949\)') | Should Be $true
        }

        It "Must use --numstat for effective line counting" {
            ($content -match 'git diff main\.\.HEAD --numstat') | Should Be $true
        }

        It "Must exclude submodule paths from line count" {
            ($content -match ':!mcps') | Should Be $true
        }

        It "Must have threshold of 2 effective lines" {
            ($content -match 'EffectiveLines -lt 2') | Should Be $true
        }

        It "Must allow override for typo/docs-fix tasks" {
            ($content -match 'IsTrivialOverride') | Should Be $true
            ($content -match 'typo\b.*docs\?-fix\b.*documentation') | Should Be $true
        }

        It "Must require both submodule files and low effective lines" {
            ($content -match 'SubmoduleFiles\.Count -gt 0.*-not \$IsTrivialOverride') | Should Be $true
        }

        It "Must clean up remote branch on trivial block" {
            $pattern = 'Remove-RemoteBranch.*trivial change guard \(#1949\)'
            ($content -match $pattern) | Should Be $true
        }
    }

    Context "Guard interaction - existing guards preserved" {

        It "Guard #1156 (phantom auto-commits) still present" {
            ($content -match 'PHANTOM PR BLOCKED \(#1156\)') | Should Be $true
        }

        It "Guard #1156 v2 (phantom submodule) still present" {
            ($content -match 'PHANTOM PR BLOCKED \(#1156 v2\)') | Should Be $true
        }

        It "Guard #1404 (empty diff) still present" {
            ($content -match 'EMPTY PR BLOCKED \(#1404\)') | Should Be $true
        }

        It "New guards run AFTER #1156 checks (order matters)" {
            $phantomPos = $content.IndexOf('PHANTOM PR BLOCKED (#1156):')
            $dedupPos = $content.IndexOf('DEDUP PR BLOCKED (#1949)')
            $phantomPos | Should BeGreaterThan 0
            $dedupPos | Should BeGreaterThan 0
            $dedupPos | Should BeGreaterThan $phantomPos
        }
    }
}
