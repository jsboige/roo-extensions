# Pester 5 tests: the two automatic-commit producers must carry the Lane:
# trailer (#4827, review ai-01 20/11 point 3b; r2 CHANGES 12:17Z).
#
# Defect these tests pin: start-claude-worker.ps1 auto-committed uncommitted
# worker changes with only Co-Authored-By, and start-copilot-dispatcher.ps1
# told Copilot to commit without any Lane: trailer — after ENFORCED_SINCE,
# every such commit reddens its own PR (lane-signature.yml).
#
# r2 additions (review ai-01 12:17Z): $env:COMPUTERNAME is UPPERCASE while
# check_lane_signature.py LANE_RE is case-sensitive, and the workspace leaf
# must come from the MAIN checkout ($RepoRoot / $queueRepoRoot), never from a
# worktree leaf (wt-* / wt-copilot-*). The behavioral test builds the real
# string from an uppercase machine sample and validates it against the SAME
# regex as the guard — it goes red on the pre-r2 uppercase form.
#
# Pattern: setup-copilot-dispatcher.Tests.ps1 — SOURCE PINS + positive control
# (mutant: stripping the trailer line makes the corresponding test go red).
# Pure string comparisons on the production sources; no git, no network, no
# schtask ever runs.
#
# Run:  powershell -File scripts/testing/run-pester-tests.ps1 -Path scripts/testing/unit/lane-signature-autocommit.Tests.ps1

Describe 'Automatic-commit producers carry the Lane: trailer (#4827 3b)' {

    BeforeAll {
        $script:workerSrc = Get-Content -LiteralPath (Join-Path $PSScriptRoot '../../scheduling/start-claude-worker.ps1') -Raw
        $script:copilotSrc = Get-Content -LiteralPath (Join-Path $PSScriptRoot '../../scheduling/start-copilot-dispatcher.ps1') -Raw
        $script:guardSrc = Get-Content -LiteralPath (Join-Path $PSScriptRoot '../../git/check_lane_signature.py') -Raw
        # Same regex as the guard (LANE_RE). The exact-line pin below makes any
        # drift of the guard's regex visible here, instead of silently forking.
        $script:lanePattern = '^myia-[a-z0-9-]+(?::[A-Za-z0-9._-]+)?$'
    }

    It 'worker auto-commit: the cmd commit line carries a Lane: trailer flag' {
        # The line is found by its fixed subject; it must contain -m ""Lane: <value>
        $workerSrc | Should -Match 'git commit -m ""chore: Auto-commit uncommitted worker changes""[^\r\n]*-m ""Lane: \$workerLane""'
    }

    It 'worker auto-commit: machine is lowercased and workspace is the MAIN checkout leaf ($RepoRoot), and $WorktreeRoot no longer exists' {
        $workerSrc | Should -Match '\$workerMachine\s*=\s*"\$\{env:COMPUTERNAME\}"\.ToLower\(\)'
        $workerSrc | Should -Match '\$workerLane\s*=\s*"\$\{workerMachine\}:\$\(Split-Path \$RepoRoot -Leaf\)"'
        $workerSrc | Should -Not -Match '\$WorktreeRoot'
    }

    It 'copilot commit mandate: the instruction line carries the Lane: trailer with the computed id' {
        $copilotSrc | Should -Match 'The commit MUST carry the trailer: Lane: \$laneId'
    }

    It 'copilot commit mandate: machine is lowercased and workspace comes from the MAIN checkout ($MainRepositoryRoot <- $queueRepoRoot), not the worktree leaf' {
        $copilotSrc | Should -Match '\$laneWorkspaceRoot\s*=\s*if \(-not \[string\]::IsNullOrWhiteSpace\(\$MainRepositoryRoot\)\) \{ \$MainRepositoryRoot \} else \{ \$RepositoryRoot \}'
        $copilotSrc | Should -Match '\$laneMachine\s*=\s*"\$\{env:COMPUTERNAME\}"\.ToLower\(\)'
        $copilotSrc | Should -Match '\$laneId\s*=\s*"\$\{laneMachine\}:\$\(Split-Path \$laneWorkspaceRoot -Leaf\)"'
        $copilotSrc | Should -Match 'Get-WorkPrompt [^\r\n]*-MainRepositoryRoot \$queueRepoRoot'
    }

    It 'behavioral: the built lane value from an UPPERCASE machine sample passes the guard regex — and the un-lowered form does not' {
        # The guard's regex is pinned first: this test validates against the SAME
        # pattern LANE_RE declares, not against a forked copy.
        $expectedGuardLine = [regex]::Escape('LANE_RE = re.compile(r"^myia-[a-z0-9-]+(?::[A-Za-z0-9._-]+)?$")')
        ($guardSrc -split '\r?\n' | Where-Object { $_ -match '^LANE_RE = ' }) -join '' |
            Should -Match $expectedGuardLine
        $sampleMachine = 'MYIA-PO-2024'
        $builtLane = "$($sampleMachine.ToLower()):roo-extensions"
        $builtLane | Should -Be 'myia-po-2024:roo-extensions'
        [regex]::IsMatch($builtLane, $lanePattern) | Should -BeTrue
        # Pre-r2 form (uppercase machine): must be rejected by the same regex —
        # this is the red the source pins alone could not see.
        $unLoweredLane = "${sampleMachine}:roo-extensions"
        [regex]::IsMatch($unLoweredLane, $lanePattern) | Should -BeFalse
    }

    It 'positive control: stripping the worker trailer line makes the worker pins fail' {
        $mutant = $workerSrc -replace ' -m ""Lane: \$workerLane""', ''
        $mutant | Should -Not -Match 'git commit -m ""chore: Auto-commit uncommitted worker changes""[^\r\n]*-m ""Lane: \$workerLane""'
        $mutant = $mutant -replace '(?m)^\s*\$workerMachine\s*=[^\r\n]*\r?\n\s*\$workerLane\s*=[^\r\n]*', ''
        $mutant | Should -Not -Match '\$workerLane\s*=\s*"\$\{workerMachine\}'
    }

    It 'positive control: stripping the copilot trailer makes the copilot pins fail' {
        $mutant = $copilotSrc -replace ' The commit MUST carry the trailer: Lane: \$laneId \(as a separate -m flag or final body line\)\.', ''
        $mutant | Should -Not -Match 'The commit MUST carry the trailer: Lane: \$laneId'
        $mutant = $mutant -replace '\$laneId\s*=\s*"[^\r\n]*', ''
        $mutant | Should -Not -Match '\$laneId\s*=\s*"\$\{laneMachine\}'
    }
}
