# Pester 5 tests: the two automatic-commit producers must carry the Lane:
# trailer (#4827, review ai-01 20/11 point 3b).
#
# Defect these tests pin: start-claude-worker.ps1 auto-committed uncommitted
# worker changes with only Co-Authored-By, and start-copilot-dispatcher.ps1
# told Copilot to commit without any Lane: trailer — after ENFORCED_SINCE,
# every such commit reddens its own PR (lane-signature.yml).
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
    }

    It 'worker auto-commit: the cmd commit line carries a Lane: trailer flag' {
        # The line is found by its fixed subject; it must contain -m ""Lane: <value>
        $workerSrc | Should -Match 'git commit -m ""chore: Auto-commit uncommitted worker changes""[^\r\n]*-m ""Lane: \$workerLane""'
    }

    It 'worker auto-commit: $workerLane is computed by the script from COMPUTERNAME + workspace leaf' {
        $workerSrc | Should -Match '\$workerLane\s*=\s*"\$env:COMPUTERNAME:\$\(Split-Path \$WorktreeRoot -Leaf\)"'
    }

    It 'copilot commit mandate: the instruction line carries the Lane: trailer with the computed id' {
        $copilotSrc | Should -Match 'The commit MUST carry the trailer: Lane: \$laneId'
    }

    It 'copilot commit mandate: $laneId is computed from COMPUTERNAME + RepositoryRoot leaf (the TARGET repo)' {
        $copilotSrc | Should -Match '\$laneId\s*=\s*"\$env:COMPUTERNAME:\$\(Split-Path \$RepositoryRoot -Leaf\)"'
    }

    It 'positive control: stripping the worker trailer line makes the worker pin fail' {
        $mutant = $workerSrc -replace ' -m ""Lane: \$workerLane""', ''
        $mutant | Should -Not -Match 'git commit -m ""chore: Auto-commit uncommitted worker changes""[^\r\n]*-m ""Lane: \$workerLane""'
        $mutant = $mutant -replace '\$workerLane\s*=\s*"\$env:COMPUTERNAME[^\r\n]*', ''
        $mutant | Should -Not -Match '\$workerLane\s*=\s*"\$env:COMPUTERNAME'
    }

    It 'positive control: stripping the copilot trailer makes the copilot pin fail' {
        $mutant = $copilotSrc -replace ' The commit MUST carry the trailer: Lane: \$laneId \(as a separate -m flag or final body line\)\.', ''
        $mutant | Should -Not -Match 'The commit MUST carry the trailer: Lane: \$laneId'
    }
}
