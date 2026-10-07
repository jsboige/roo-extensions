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

# --- Defauts A et B, issue #4118 (synthetic action objects, no real task touched) -----------
# The eligibility and ownership-guard logic lives in harden-hidden-tasks.lib.ps1 so it
# can be exercised with SYNTHETIC task objects -- registering nothing, touching nothing.

Describe 'harden-hidden-tasks eligibility (defect A, #4118)' {
    BeforeAll {
        . (Join-Path $PSScriptRoot 'harden-hidden-tasks.lib.ps1')
        function New-SyntheticTask {
            param([string]$Execute, [string]$Arguments = '', [string]$WorkingDirectory = '',
                  [string]$LogonType = 'Interactive')
            [PSCustomObject]@{
                TaskName = 'SYN-Test'
                State    = 'Ready'
                Actions  = @([PSCustomObject]@{
                    Execute = $Execute; Arguments = $Arguments; WorkingDirectory = $WorkingDirectory })
                Principal = [PSCustomObject]@{ LogonType = $LogonType; RunLevel = 'Limited' }
            }
        }
        $ps51 = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    }

    It 'bare name pwsh is eligible (subsystem if installed, name-list fallback if not)' {
        $d = Get-HardenDecision -Task (New-SyntheticTask -Execute 'pwsh')
        $d.Decision | Should -Be 'plan'
    }

    It 'quoted full path powershell.exe is eligible via the PE subsystem (trailing quote was the bug)' {
        $d = Get-HardenDecision -Task (New-SyntheticTask -Execute ('"{0}"' -f $ps51))
        $d.Decision | Should -Be 'plan'
        $d.Method | Should -Be 'subsystem'
        $d.Unresolved | Should -BeFalse
    }

    It '%SystemRoot% environment variable expands and resolves' {
        $d = Get-HardenDecision -Task (New-SyntheticTask -Execute '%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe')
        $d.Decision | Should -Be 'plan'
        $d.Method | Should -Be 'subsystem'
    }

    It 'a resolvable python.exe is eligible (console subsystem, outside the old 3-name list)' {
        $py = Get-Command python -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
        if (-not $py) { Set-ItResult -Skipped -Because 'python.exe not on PATH on this machine'; return }
        $d = Get-HardenDecision -Task (New-SyntheticTask -Execute ('"{0}"' -f $py.Source))
        if ((Test-ConsoleSubsystem -Path $py.Source) -ne $null) {
            # Real PE file (ai-01: C:\Python314\python.exe) -> console subsystem, eligible.
            $d.Decision | Should -Be 'plan'
            $d.Method | Should -Be 'subsystem'
        } else {
            # WindowsApps execution alias (po-2025: 0-byte reparse stub, PE unreadable)
            # -> unclassifiable, so REPORTED unresolved, never silently dropped.
            $d.Decision | Should -Be 'no-console'
            $d.Unresolved | Should -BeTrue
        }
    }

    It 'a console program outside the old 3-name list is eligible (where.exe)' {
        $exe = Join-Path $env:SystemRoot 'System32\where.exe'
        (Test-ConsoleSubsystem -Path $exe) | Should -BeTrue
        $d = Get-HardenDecision -Task (New-SyntheticTask -Execute ('"{0}"' -f $exe))
        $d.Decision | Should -Be 'plan'
        $d.Method | Should -Be 'subsystem'
    }

    It 'wscript.exe is NOT console (GUI subsystem)' {
        $v = Test-ConsoleExecute -Execute (Join-Path $env:SystemRoot 'System32\wscript.exe')
        $v.Console | Should -BeFalse
        $v.Method | Should -Be 'subsystem'
        $v.Resolved | Should -BeTrue
    }

    It 'a GUI-subsystem exe (notepad) is not console' {
        $exe = Join-Path $env:SystemRoot 'System32\notepad.exe'
        if (-not (Test-Path $exe)) { Set-ItResult -Skipped -Because 'notepad.exe not present'; return }
        (Test-ConsoleSubsystem -Path $exe) | Should -BeFalse
    }

    It 'an unresolvable path is REPORTED (Unresolved), not silently dropped' {
        $d = Get-HardenDecision -Task (New-SyntheticTask -Execute 'C:\Nowhere\Definitely\Missing\tool.exe')
        $d.Decision | Should -Be 'no-console'
        $d.Unresolved | Should -BeTrue
    }

    It 'an unresolvable path whose normalized leaf is in the fallback list is planned AND flagged unresolved' {
        $d = Get-HardenDecision -Task (New-SyntheticTask -Execute '"C:\gone\pwsh.exe"')
        $d.Decision | Should -Be 'plan'
        $d.Unresolved | Should -BeTrue
        $d.Method | Should -Be 'name-list'
    }

    It 'a non-Interactive principal is not eligible (session 0 -> already invisible)' {
        $d = Get-HardenDecision -Task (New-SyntheticTask -Execute $ps51 -LogonType 'S4U')
        $d.Decision | Should -Be 'non-interactive'
    }

    It 'an already-hardened action is detected through its normalized leaf (quoted wscript path)' {
        Test-AlreadyHardenedAction -Action ([PSCustomObject]@{
            Execute = ('"{0}"' -f (Join-Path $env:SystemRoot 'System32\wscript.exe')) }) | Should -BeTrue
    }
}

Describe 'harden-hidden-tasks lane guard (defect B, #4118)' {
    BeforeAll {
        . (Join-Path $PSScriptRoot 'harden-hidden-tasks.lib.ps1')
        function New-SyntheticTask {
            param([string]$Execute, [string]$Arguments = '', [string]$WorkingDirectory = '')
            [PSCustomObject]@{
                TaskName = 'SYN-Test'
                State    = 'Ready'
                Actions  = @([PSCustomObject]@{
                    Execute = $Execute; Arguments = $Arguments; WorkingDirectory = $WorkingDirectory })
                Principal = [PSCustomObject]@{ LogonType = 'Interactive'; RunLevel = 'Limited' }
            }
        }
    }

    It 'default lane (roo-extensions) keeps the maint-scripts exclusion (byte-compatible)' {
        $d = Get-HardenDecision -Task (New-SyntheticTask -Execute 'powershell.exe' -Arguments '-File C:\ProgramData\maint-scripts\foo.ps1')
        $d.Decision | Should -Be 'foreign'
    }

    It 'under -Lane Maintenance, a maint-scripts task is OWN (eligible)' {
        $d = Get-HardenDecision -Task (New-SyntheticTask -Execute 'powershell.exe' -Arguments '-File C:\ProgramData\maint-scripts\foo.ps1') -Lane 'Maintenance'
        $d.Decision | Should -Be 'plan'
    }

    It 'under -Lane Maintenance, a roo-extensions task is foreign (excluded)' {
        $d = Get-HardenDecision -Task (New-SyntheticTask -Execute 'powershell.exe' -Arguments '-File D:\dev\roo-extensions\scripts\scheduling\x.ps1') -Lane 'Maintenance'
        $d.Decision | Should -Be 'foreign'
    }

    It 'an already-hardened task NEVER appears excluded, even on the foreign side (hardened before ownership)' {
        # maint-scripts task already routed via wscript: decision must be hardened, not foreign.
        $d = Get-HardenDecision -Task (New-SyntheticTask -Execute 'wscript.exe' -Arguments '//B //Nologo "C:\ProgramData\maint-hidden-launchers\x.vbs"')
        $d.Decision | Should -Be 'hardened'
    }

    It '-TaskName bypasses the ownership guard (explicit opt-in, unchanged behaviour)' {
        $d = Get-HardenDecision -Task (New-SyntheticTask -Execute 'powershell.exe' -Arguments '-File C:\ProgramData\maint-scripts\foo.ps1') -TaskNameFilter @('SYN-Test')
        $d.Decision | Should -Be 'plan'
    }
}
