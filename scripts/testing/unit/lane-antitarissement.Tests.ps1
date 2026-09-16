<#
.SYNOPSIS
    Guards the anti-tarissement lane tooling (#3675, ADR 016) as reworked in
    PR #3681 after the ai-01 CHANGES_REQUESTED and the po-2027 measured
    review: fail-closed gh instrumentation, UTF-8 subprocess decoding,
    removed --machine flag, ADR renumbered 016 (014: #3680, 015: #3684).
#>

Describe 'Anti-tarissement lane tooling (#3675, ADR 016)' {
    BeforeAll {
        $root = Join-Path $PSScriptRoot '..\..\..'
        $pickerPath = Join-Path $root 'scripts\scheduling\pick_idle_grain.py'
        $testPath = Join-Path $root 'scripts\scheduling\test_cycle_end.py'
        $adr016Path = Join-Path $root 'docs\harness\adr\016-lane-anti-tarissement-convergence-coursia.md'
        $adr014Path = Join-Path $root 'docs\harness\adr\014-lane-anti-tarissement-convergence-coursia.md'
        $skillPath = Join-Path $root '.claude\skills\executor\SKILL.md'
        $commandPath = Join-Path $root '.claude\commands\executor.md'
        $pyTestsPath = Join-Path $root 'scripts\testing\python\test_lane_antitarissement.py'

        $picker = Get-Content $pickerPath -Raw
        $tce = Get-Content $testPath -Raw
        $skill = Get-Content $skillPath -Raw
        $command = Get-Content $commandPath -Raw

        # Behavioural harness needs python (preinstalled on ubuntu-latest CI;
        # optional locally — the content guards below still run everywhere).
        # Windows first: 'python3' may resolve to the inert WindowsApps Store
        # alias even when a real interpreter is installed (measured po-2025).
        $script:Python = $null
        $candidates = if ($env:OS -eq 'Windows_NT') { @('python', 'py') } else { @('python3', 'python') }
        foreach ($candidate in $candidates) {
            $cmd = Get-Command $candidate -ErrorAction SilentlyContinue
            if ($cmd) { $script:Python = $cmd.Source; break }
        }
    }

    Context 'Fail-closed instrumentation (review #3681, bloquant 2)' {
        It 'picker converts no gh failure into a pool verdict: ERROR class + exit 2' {
            $picker | Should -Match 'GhCommandError'
            $picker | Should -Match 'verdict": "ERROR"'
            $picker | Should -Match 'return 2'
            # fail-closed collects errors across BOTH repos before any verdict
            $picker | Should -Match 'errors\.append\(e\)'
        }

        It 'cycle-end test converts no gh failure into PASS: ERROR + exit 2' {
            $tce | Should -Match 'GhCommandError'
            $tce | Should -Match '"verdict": "ERROR"'
            $tce | Should -Match 'return 2'
        }

        It 'both scripts decode gh stdout as UTF-8 with replacement (cp1252 crash, bloquant 1)' {
            foreach ($src in @($picker, $tce)) {
                $src | Should -Match 'encoding="utf-8"'
                $src | Should -Match 'errors="replace"'
            }
        }
    }

    Context '--machine removed, not half-implemented (CR point 2/3)' {
        It 'picker has no machine flag nor dead filter' {
            $picker | Should -Not -Match '--machine'
            $picker | Should -Not -Match 'filter_by_machine'
        }

        It 'cycle-end test has no machine flag' {
            $tce | Should -Not -Match '--machine'
        }

        It 'SKILL.md and executor.md no longer advertise a machine-filtered variant' {
            foreach ($doc in @($skill, $command)) {
                $doc | Should -Not -Match 'pick_idle_grain\.py --machine'
            }
        }

        It 'cycle-end test names its fleet-wide scope in its output fields' {
            $tce | Should -Match 'prs_delivered_fleet'
            $tce | Should -Match 'backlog_grain'
        }
    }

    Context 'ADR numbering (collision with #3680 resolved)' {
        It 'lane ADR lives at 016, not 014 or 015' {
            (Test-Path $adr016Path) | Should -BeTrue
            (Test-Path $adr014Path) | Should -BeFalse
            (Get-Content $adr016Path -Raw) | Should -Match 'ADR 016'
        }

        It 'SKILL.md and executor.md reference ADR 016' {
            $skill | Should -Match 'ADR 016'
            $command | Should -Match 'ADR 016'
        }

        It 'ADR implementation table no longer cites an undelivered rules file' {
            (Get-Content $adr016Path -Raw) | Should -Not -Match 'rules/validation\.md'
        }
    }

    Context 'Behavioural harness (unittest, mocked subprocess)' {
        BeforeAll {
            # Skip message, not failure, when python is absent: CI ubuntu-latest
            # ships python3; a dev box without python still gets the guards above.
            if (-not $script:Python) {
                Write-Host "python not found - behavioural unittest skipped (content guards above still active)"
            }
        }

        It 'runs the unittest suite covering gh failures, UTF-8, verdicts and exit codes' {
            if (-not $script:Python) { Set-ItResult -Skipped -Because 'python not available' }
            else {
                # System.Diagnostics.Process, pas '& ... 2>&1' : sous PS 5.1,
                # stderr natif fusionne via 2>&1 devient des ErrorRecords et
                # fait echouer le test sur les simples points de progression
                # unittest (mesure po-2025 16/09).
                $psi = New-Object System.Diagnostics.ProcessStartInfo
                $psi.FileName = $script:Python
                $psi.Arguments = '"' + $pyTestsPath + '"'
                $psi.RedirectStandardOutput = $true
                $psi.RedirectStandardError = $true
                $psi.UseShellExecute = $false
                $proc = [System.Diagnostics.Process]::Start($psi)
                $stdout = $proc.StandardOutput.ReadToEnd()
                $stderr = $proc.StandardError.ReadToEnd()
                $proc.WaitForExit()
                $proc.ExitCode | Should -Be 0 -Because "unittest output: $stdout $stderr"
            }
        }
    }
}
