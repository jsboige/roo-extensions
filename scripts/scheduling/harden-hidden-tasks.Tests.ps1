# Pester 5 tests for harden-hidden-tasks.ps1 -TaskName comma-list handling.
#
# Bug (found by po-2023, dispatch ai-01 27/09 08:39Z): under `powershell.exe -File`,
# `-TaskName 'A','B','C'` arrives as ONE string "A,B,C" (no expression parsing in -File
# mode, unlike -Command), so `$_.TaskName -in $TaskName` silently matched nothing.
#
# The TARGET always runs as a child `powershell.exe` (5.1) process -- the engine the
# fleet invokes this script with -- in BOTH forms:
#   -File (comma form = the bug) and -Command (native array = regression guard).
# The test HOST is pwsh 7 (Pester 5 is not shipped with Windows PowerShell 5.1).
#
# Machine prerequisite: registering a user-level Interactive scheduled task must be
# allowed (standard user, RunLevel Limited). If registration fails, tests are SKIPPED
# with the reason -- not failed: this file runs on fleet Windows machines, not CI.
#
# Run:  pwsh -File scripts/testing/run-pester-tests.ps1 -Path scripts/scheduling/harden-hidden-tasks.Tests.ps1

BeforeAll {
    $target = Join-Path $PSScriptRoot 'harden-hidden-tasks.ps1'
    $names = @('HHN-ArrayFile-A', 'HHN-ArrayFile-B', 'HHN-ArrayFile-C')
    $script:registered = $true

    $action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument '-NoProfile -Command "exit 0"'
    $principal = New-ScheduledTaskPrincipal -UserId ("{0}\{1}" -f [Environment]::UserDomainName, [Environment]::UserName) -LogonType Interactive
    foreach ($n in $names) {
        try {
            Register-ScheduledTask -TaskName $n -Action $action -Principal $principal -ErrorAction Stop | Out-Null
        } catch {
            $script:registered = $false
            $script:registerError = $_.Exception.Message
            break
        }
    }
}

AfterAll {
    foreach ($n in $names) {
        try { Unregister-ScheduledTask -TaskName $n -Confirm:$false -ErrorAction Stop } catch { }
    }
}

Describe 'harden-hidden-tasks.ps1 -TaskName comma form' {
    It '-File with comma-joined names plans ALL named tasks (was: silent 0 match)' {
        if (-not $script:registered) { Set-ItResult -Skipped -Because "task registration failed: $($script:registerError)"; return }
        $out = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $target -DryRun -TaskName ($names -join ',') 2>&1 | Out-String
        foreach ($n in $names) {
            $out | Should -Match ("\[DRY\] {0}" -f [regex]::Escape($n))
        }
        ([regex]::Matches($out, '\[DRY\]')).Count | Should -Be 3
    }

    It '-Command with a native array still plans ALL named tasks (regression guard)' {
        if (-not $script:registered) { Set-ItResult -Skipped -Because "task registration failed"; return }
        $cmdString = "& '{0}' -DryRun -TaskName '{1}','{2}','{3}'" -f $target, $names[0], $names[1], $names[2]
        $out = & powershell.exe -NoProfile -ExecutionPolicy Bypass -Command $cmdString 2>&1 | Out-String
        foreach ($n in $names) {
            $out | Should -Match ("\[DRY\] {0}" -f [regex]::Escape($n))
        }
        ([regex]::Matches($out, '\[DRY\]')).Count | Should -Be 3
    }

    It '-File with a single comma-free name plans exactly that task (no over-split)' {
        if (-not $script:registered) { Set-ItResult -Skipped -Because "task registration failed"; return }
        $out = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $target -DryRun -TaskName $names[0] 2>&1 | Out-String
        $out | Should -Match ("\[DRY\] {0}" -f [regex]::Escape($names[0]))
        ([regex]::Matches($out, '\[DRY\]')).Count | Should -Be 1
    }

    It '-File with the pwsh-quoted comma form (residual single quotes) still plans ALL named tasks' {
        if (-not $script:registered) { Set-ItResult -Skipped -Because "task registration failed"; return }
        # From pwsh 7, -File delivers `-TaskName 'A','B','C'` as ONE string KEEPING the
        # single quotes (probe 27/09 po-203: COUNT=1, arg="'A','B','C'"). #3892 split the
        # commas but left quoted names -- 0 match, again silent.
        $quoted = "'" + ($names -join "','") + "'"
        $out = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $target -DryRun -TaskName $quoted 2>&1 | Out-String
        foreach ($n in $names) {
            $out | Should -Match ("\[DRY\] {0}" -f [regex]::Escape($n))
        }
        ([regex]::Matches($out, '\[DRY\]')).Count | Should -Be 3
    }

    It '-TaskName matching NOTHING emits a warning instead of a silent empty plan' {
        if (-not $script:registered) { Set-ItResult -Skipped -Because "task registration failed"; return }
        $out = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $target -DryRun -TaskName 'HHN-NoSuchTask' 2>&1 | Out-String
        $out | Should -Match 'Aucune tache planifiee ne matche TaskName'
        $out | Should -Not -Match '\[DRY\]'
    }
}
