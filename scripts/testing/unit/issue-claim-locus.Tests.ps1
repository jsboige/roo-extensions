<#
.SYNOPSIS
    Guards the issue-claim locus tooling (#3676, ADR 017) as reworked in
    PR #3680 after the ai-01 CHANGES_REQUESTED: RESULT closes a claim
    (false 24h block on live stock #3626), ADR renumbered 014 -> 017,
    .roo/rules/26 mirror synchronized, HARNESS-OVERVIEW retaught.

    The 32-test unittest suite (scripts/github/tests) had no CI runner of
    its own -- same gap as the anti-tarissement suite before #3681, same
    fix: this Pester file is discovered by the unit-pester job
    (run-pester-tests.ps1 -Path scripts/testing/unit) and invokes the
    python suite behaviourally.
#>

Describe 'Issue-claim locus tooling (#3676, ADR 017)' {
    BeforeAll {
        $root = Join-Path $PSScriptRoot '..\..\..'
        $organPath = Join-Path $root 'scripts\github\check_issue_claim.py'
        $adr017Path = Join-Path $root 'docs\harness\adr\017-issue-claim-locus.md'
        $adr014Path = Join-Path $root 'docs\harness\adr\014-issue-claim-locus.md'
        $claudeRulePath = Join-Path $root '.claude\rules\agent-claim-discipline.md'
        $rooRulePath = Join-Path $root '.roo\rules\26-agent-claim-discipline.md'
        $overviewPath = Join-Path $root 'docs\harness\HARNESS-OVERVIEW.md'
        $pyTestsPath = Join-Path $root 'scripts\github\tests\test_check_issue_claim.py'

        $organ = Get-Content $organPath -Raw
        $claudeRule = Get-Content $claudeRulePath -Raw
        $rooRule = Get-Content $rooRulePath -Raw
        $overview = Get-Content $overviewPath -Raw

        # Behavioural harness needs python (preinstalled on ubuntu-latest CI;
        # optional locally -- the content guards below still run everywhere).
        # Windows first: 'python3' may resolve to the inert WindowsApps Store
        # alias even when a real interpreter is installed (measured po-2025).
        $script:Python = $null
        $candidates = if ($env:OS -eq 'Windows_NT') { @('python', 'py') } else { @('python3', 'python') }
        foreach ($candidate in $candidates) {
            $cmd = Get-Command $candidate -ErrorAction SilentlyContinue
            if ($cmd) { $script:Python = $cmd.Source; break }
        }
    }

    Context 'RESULT releases a claim (review #3680, bloquant 1)' {
        It 'RESULT is scanned as an event AND closes the claim' {
            $organ | Should -Match 'CLAIMED\|RELEASED\|RESULT\|DONE'
            $organ | Should -Match 'CLOSE_MARKERS = \{"RELEASED", "RESULT"'
        }

        It 'reducer test proving [CLAIMED] -> [RESULT] releases that machine exists' {
            $tests = Get-Content $pyTestsPath -Raw
            $tests | Should -Match 'test_result_releases_claim'
            $tests | Should -Match 'test_result_releases_only_own_machine'
            $tests | Should -Match 'test_result_releases_block_end_to_end'
        }
    }

    Context 'ADR numbering (collision resolved: 017, not 014)' {
        It 'claim ADR lives at 017, the 014 file is gone' {
            (Test-Path $adr017Path) | Should -BeTrue
            (Test-Path $adr014Path) | Should -BeFalse
            (Get-Content $adr017Path -Raw) | Should -Match 'ADR 017'
        }

        It 'rules and docs cite 017, not the dead 014 path' {
            foreach ($doc in @($organ, $claudeRule)) {
                $doc | Should -Not -Match 'ADR 014'
                $doc | Should -Not -Match 'adr/014-issue-claim-locus'
            }
            $claudeRule | Should -Match 'ADR 017'
        }
    }

    Context 'Roo mirror synchronized (review #3680, bloquant 2)' {
        It '.roo/rules/26 teaches the issue locus, not the dashboard lock' {
            $rooRule | Should -Match 'check_issue_claim\.py'
            $rooRule | Should -Match 'ADR 017'
            $rooRule | Should -Match 'Frontiere de mot'
        }

        It 'mirror no longer declares the dashboard as the claim registry' {
            $rooRule | Should -Not -Match 'poster `\[CLAIMED\]` sur le dashboard avec numero issue'
        }
    }

    Context 'HARNESS-OVERVIEW retaught (review #3680, bloquant 5)' {
        It 'overview names the issue as the lock registry and the release markers' {
            $overview | Should -Match 'check_issue_claim\.py'
            $overview | Should -Match 'ADR 017'
            $overview | Should -Match 'registre de verrous'
        }
    }

    Context 'Behavioural harness (unittest, mocked gh)' {
        BeforeAll {
            # Skip message, not failure, when python is absent: CI ubuntu-latest
            # ships python3; a dev box without python still gets the guards above.
            if (-not $script:Python) {
                Write-Host "python not found - behavioural unittest skipped (content guards above still active)"
            }
        }

        It 'runs the unittest suite covering markers, reducer, classify and main' {
            if (-not $script:Python) { Set-ItResult -Skipped -Because 'python not available' }
            else {
                # System.Diagnostics.Process, pas '& ... 2>&1' : sous PS 5.1,
                # stderr natif fusionne via 2>&1 devient des ErrorRecords et
                # fait echouer le test sur les simples points de progression
                # unittest (mesure po-2025 16/09).
                $psi = New-Object System.Diagnostics.ProcessStartInfo
                $psi.FileName = $script:Python
                $psi.Arguments = '-m unittest test_check_issue_claim'
                $psi.WorkingDirectory = Join-Path $root 'scripts\github\tests'
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
