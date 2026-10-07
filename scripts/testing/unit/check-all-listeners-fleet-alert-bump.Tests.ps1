<#
.SYNOPSIS
    Regression coverage for #3761 residue (c): the FLEET-ALERT header bump.

.DESCRIPTION
    check-all-listeners.ps1 writes its alert straight into the shared workspace
    dashboard file. Two preexisting defects, same class as the ones fixed for
    Write-MachineDashboardMessage in #4124:

      - the seed wrote "## Intercom (1 message)" - SINGULAR, while the MCP
        always renders the plural (dashboard.ts:1936) and the listener parser
        requires it (l.564);
      - the append bumped the DIGIT only, so a file seeded singular (by this
        writer or any legacy one) became "(2 message)" - a header no reader
        reconciles.

    Both paths now mirror #4124: plural seed, digit bump anchored on
    messages?, then singular normalization.

    The posting block is inline in the script body (no function to extract),
    so this test drives the real script via a subprocess with a fake
    ROOSYNC_SHARED_PATH - the same pattern as the fleet-health read test in
    dashboard-listener-definitive-skip.Tests.ps1. A STALE heartbeat (>2h)
    makes the machine dead, which is what arms the alert path. -NoRepair keeps
    the auto-repair branch out of the test.

    Age is the file's LastWriteTimeUtc (l.79), not the timestamp inside it:
    the stale setups below backdate the FILE after writing it.

    Excluded from CI? No - unit suite, temp-dir file effects + one
    Windows-guarded subprocess call.
#>

Describe 'FLEET-ALERT dashboard header bump (#3761 residue c)' {
    BeforeAll {
        $repoRoot = (Resolve-Path "$PSScriptRoot\..\..\..").Path
        $script:FleetPath = Join-Path $repoRoot 'scripts/dashboard-scheduler/check-all-listeners.ps1'

        $script:Tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("t3761c-" + [guid]::NewGuid().ToString('N').Substring(0, 8))
        New-Item -ItemType Directory -Path $script:Tmp -Force | Out-Null
    }
    AfterAll {
        if (Test-Path $script:Tmp) { Remove-Item $script:Tmp -Recurse -Force -ErrorAction SilentlyContinue }
    }

    Context 'Seed path - fresh file is born plural' {
        It 'creates the dashboard with "(1 messages)", never "(1 message)"' -Skip:($env:OS -ne 'Windows_NT') {
            $tmpShared = Join-Path $script:Tmp 'seed'
            $hbDir = Join-Path $tmpShared 'listener-heartbeats'
            New-Item -ItemType Directory -Path $hbDir -Force | Out-Null
            # Stale heartbeat (>2h threshold) => machine dead => alert path armed.
            # Age = file LastWriteTimeUtc (l.79), so backdate the FILE itself.
            $stale = (Get-Date).ToUniversalTime().AddHours(-3).ToString('yyyy-MM-ddTHH:mm:ssZ')
            $hbf = Join-Path $hbDir 'machine-tc1.heartbeat'
            [System.IO.File]::WriteAllText($hbf, $stale, [System.Text.UTF8Encoding]::new($false))
            (Get-Item $hbf).LastWriteTimeUtc = (Get-Date).ToUniversalTime().AddHours(-3)

            $prev = $env:ROOSYNC_SHARED_PATH
            $env:ROOSYNC_SHARED_PATH = $tmpShared
            try {
                $null = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $script:FleetPath -Machines 'machine-tc1' -NoRepair 2>$null
            } finally {
                $env:ROOSYNC_SHARED_PATH = $prev
            }

            $dash = Get-ChildItem $tmpShared -Recurse -Filter 'workspace-*.md' | Select-Object -First 1
            $dash | Should -Not -BeNullOrEmpty -Because 'the alert must have created the dashboard file'
            $raw = [System.IO.File]::ReadAllText($dash.FullName)
            $raw | Should -Match '## Intercom \(1 messages\)'
            $raw | Should -Not -Match '## Intercom \(1 message\)'
            $raw | Should -Match '\[FLEET-ALERT\]'
        }
    }

    Context 'Append path - a file seeded SINGULAR is bumped AND normalized' {
        It 'turns "(1 message)" into "(2 messages)" and keeps both messages' -Skip:($env:OS -ne 'Windows_NT') {
            $tmpShared = Join-Path $script:Tmp 'append'
            $hbDir = Join-Path $tmpShared 'listener-heartbeats'
            $dashDir = Join-Path $tmpShared 'dashboards'
            New-Item -ItemType Directory -Path $hbDir -Force | Out-Null
            New-Item -ItemType Directory -Path $dashDir -Force | Out-Null

            $stale = (Get-Date).ToUniversalTime().AddHours(-3).ToString('yyyy-MM-ddTHH:mm:ssZ')
            $hbf2 = Join-Path $hbDir 'machine-tc2.heartbeat'
            [System.IO.File]::WriteAllText($hbf2, $stale, [System.Text.UTF8Encoding]::new($false))
            (Get-Item $hbf2).LastWriteTimeUtc = (Get-Date).ToUniversalTime().AddHours(-3)

            # Pre-fix shape: singular header + an old alert about a DIFFERENT
            # machine (no cooldown overlap; also >6h old). The digit-only bump
            # of the pre-fix code left this header at "(2 message)".
            $dashFile = Join-Path $dashDir 'workspace-roo-extensions.md'
            $seed = "---`r`ntype: workspace`r`nlastModified: '2026-10-07T00:00:00.000Z'`r`nlastModifiedBy:`r`n  machineId: other`r`n  workspace: roo-extensions`r`ntotalMessages: 1`r`n---`r`n`r`n## Status`r`n`r`n## Intercom (1 message)`r`n`r`n### [2026-10-07T00:00:00.000Z] other|roo-extensions`r`n[msg: other:roo-extensions:ic-20261007T0000-aaaa]`r`n`r`n[FLEET-ALERT] [WARN] Fleet listener check: 1 of 1 machines have STALE/DEAD wake-listeners (threshold >2h). Machines affected: machine-tc2b.`r`n"
            [System.IO.File]::WriteAllText($dashFile, $seed, [System.Text.UTF8Encoding]::new($false))

            $prev = $env:ROOSYNC_SHARED_PATH
            $env:ROOSYNC_SHARED_PATH = $tmpShared
            try {
                $null = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $script:FleetPath -Machines 'machine-tc2' -NoRepair 2>$null
            } finally {
                $env:ROOSYNC_SHARED_PATH = $prev
            }

            $raw = [System.IO.File]::ReadAllText($dashFile)
            $raw | Should -Match '## Intercom \(2 messages\)' -Because 'the count must bump AND the word must be plural'
            $raw | Should -Not -Match '\(\d+ message\)'
            $raw | Should -Match 'machine-tc2b\.' -Because 'the preexisting alert must survive the append'
            # the NEW alert names the newly dead machine
            $raw | Should -Match 'Machines affected: machine-tc2\.'
        }
    }
}
