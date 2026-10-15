<#
.SYNOPSIS
    Coverage for the FLEET-ALERT write path of check-all-listeners.ps1
    (G-C #4131 étape 3 — arbitrage ai-01 14/10, option a).

.DESCRIPTION
    Étape 3 moved the [FLEET-ALERT] from the shared workspace dashboard to the
    MACHINE dashboard of the detector, CLI-first (rsm-dashboard-append.mjs:
    dual-write journal PG + file, append lock, format at the store), direct
    file write as fallback. This file covers:

      - Seed path (fallback): a fresh machine file is born plural "(1 messages)",
        frontmatter type: machine, author <det>|listener (#3761 residue c fix,
        same class as #4124).
      - Append path (fallback): a file seeded SINGULAR is bumped AND normalized
        to "(2 messages)"; the preexisting alert survives.
      - Cooldown: a recent (<6h) prior alert with an overlapping machine on the
        DETECTOR's machine file suppresses the new post (the workspace file is
        no longer scanned — alerts don't land there anymore).
      - Primary path: the CLI posts (ok:true) and the PS does NOT hand-write
        the file; the CLI receives --machine <detector> and the [FLEET-ALERT]
        content.

    CLI availability is controlled with the fake-RSM-root technique of
    dashboard-listener-pg-path.Tests.ps1: $env:RSM_SERVER_ROOT (first candidate
    of Get-RsmScriptsDir) points at a fake scripts/ dir whose
    rsm-dashboard-append.mjs is a stub logging its argv and exiting 0, or
    exiting 1 to force the file fallback.

    The posting block is inline in the script body (no function to extract),
    so each test drives the real script via a subprocess with a fake
    ROOSYNC_SHARED_PATH + ROOSYNC_MACHINE_ID (predictable machine-<det>.md).
    A STALE heartbeat (>2h) makes the machine dead, which is what arms the
    alert path. -NoRepair keeps the auto-repair branch out of the test.

    Age is the file's LastWriteTimeUtc, not the timestamp inside it:
    the stale setups below backdate the FILE after writing it.

    Excluded from CI? No - unit suite, temp-dir file effects +
    Windows-guarded subprocess calls.
#>

Describe 'FLEET-ALERT write path (#4131 G-C étape 3, option a)' {
    BeforeAll {
        $repoRoot = (Resolve-Path "$PSScriptRoot\..\..\..").Path
        $script:FleetPath = Join-Path $repoRoot 'scripts/dashboard-scheduler/check-all-listeners.ps1'

        $script:Tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("t4131gc3-" + [guid]::NewGuid().ToString('N').Substring(0, 8))
        New-Item -ItemType Directory -Path $script:Tmp -Force | Out-Null

        # Pester v5 : les helpers doivent vivre dans BeforeAll pour être visibles des It.
        # Runs the real script in a subprocess with a controlled env; returns stdout.
        function Invoke-FleetCheck($tmpShared, $fakeRsmRoot, $machines, $cliLog) {
            $prevShared = $env:ROOSYNC_SHARED_PATH
            $prevRsmRoot = $env:RSM_SERVER_ROOT
            $prevMachineId = $env:ROOSYNC_MACHINE_ID
            $prevCliLog = $env:FLEET_CLI_LOG
            $env:ROOSYNC_SHARED_PATH = $tmpShared
            $env:RSM_SERVER_ROOT = $fakeRsmRoot
            $env:ROOSYNC_MACHINE_ID = 'machine-det'
            $env:FLEET_CLI_LOG = $cliLog
            try {
                $out = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $script:FleetPath -Machines $machines -NoRepair 2>$null
                return ($out -join "`n")
            } finally {
                $env:ROOSYNC_SHARED_PATH = $prevShared
                $env:RSM_SERVER_ROOT = $prevRsmRoot
                $env:ROOSYNC_MACHINE_ID = $prevMachineId
                $env:FLEET_CLI_LOG = $prevCliLog
            }
        }

        # Fake RSM root: scripts/rsm-dashboard-append.mjs stub. Mode 'ok' logs argv
        # to $env:FLEET_CLI_LOG and emits the CLI success JSON; mode 'fail' exits 1
        # (file write failed) to force the PS file fallback.
        function New-FakeRsmRoot($name, $mode) {
            $root = Join-Path $script:Tmp $name
            $scripts = Join-Path $root 'scripts'
            New-Item -ItemType Directory -Path $scripts -Force | Out-Null
            # Le stub est un .mjs : ESM strict — `require()` y est une
            # ReferenceError (node exit 1, silencieux sous 2>$null). Import
            # statique obligatoire.
            $body = if ($mode -eq 'ok') {
                'import { appendFileSync } from "fs";' +
                'appendFileSync(process.env.FLEET_CLI_LOG, JSON.stringify(process.argv.slice(2)) + "\n");' +
                'process.stdout.write(JSON.stringify({ok:true,key:"machine-machine-det",base:"file",unserialized:false,messageId:"machine-det:listener:ic-20261015T120000-ab12",totalMessages:2,pgSynced:true}));'
            } else {
                'process.stderr.write("ERREUR: ecriture GDrive impossible"); process.exit(1);'
            }
            [System.IO.File]::WriteAllText((Join-Path $scripts 'rsm-dashboard-append.mjs'), $body, [System.Text.UTF8Encoding]::new($false))
            return $root
        }

        function New-StaleHeartbeat($tmpShared, $machine) {
            $hbDir = Join-Path $tmpShared 'listener-heartbeats'
            New-Item -ItemType Directory -Path $hbDir -Force | Out-Null
            $stale = (Get-Date).ToUniversalTime().AddHours(-3).ToString('yyyy-MM-ddTHH:mm:ssZ')
            $hbf = Join-Path $hbDir "$machine.heartbeat"
            [System.IO.File]::WriteAllText($hbf, $stale, [System.Text.UTF8Encoding]::new($false))
            (Get-Item $hbf).LastWriteTimeUtc = (Get-Date).ToUniversalTime().AddHours(-3)
        }
    }
    AfterAll {
        if (Test-Path $script:Tmp) { Remove-Item $script:Tmp -Recurse -Force -ErrorAction SilentlyContinue }
    }

    Context 'Seed path (file fallback) - fresh machine file is born plural, machine conventions' {
        It 'creates machine-machine-det.md with "(1 messages)", type: machine, author machine-det|listener' -Skip:($env:OS -ne 'Windows_NT') {
            $tmpShared = Join-Path $script:Tmp 'seed'
            New-StaleHeartbeat $tmpShared 'machine-tc1'
            $fake = New-FakeRsmRoot 'rsm-seed' 'fail'   # CLI fails -> file fallback
            $cliLog = Join-Path $script:Tmp 'seed-cli.log'

            $null = Invoke-FleetCheck $tmpShared $fake 'machine-tc1' $cliLog

            $dash = Join-Path $tmpShared 'dashboards/machine-machine-det.md'
            $dash | Should -Exist -Because 'the fallback must have created the MACHINE dashboard file'
            $raw = [System.IO.File]::ReadAllText($dash)
            $raw | Should -Match '## Intercom \(1 messages\)'
            $raw | Should -Not -Match '## Intercom \(1 message\)'
            $raw | Should -Match 'type: machine'
            $raw | Should -Match 'machine-det\|listener'
            $raw | Should -Match '\[FLEET-ALERT\]'
            # The workspace dashboard must NOT be written anymore (option a).
            (Get-ChildItem $tmpShared -Recurse -Filter 'workspace-*.md') | Should -BeNullOrEmpty
        }
    }

    Context 'Append path (file fallback) - a file seeded SINGULAR is bumped AND normalized' {
        It 'turns "(1 message)" into "(2 messages)" and keeps both messages' -Skip:($env:OS -ne 'Windows_NT') {
            $tmpShared = Join-Path $script:Tmp 'append'
            New-StaleHeartbeat $tmpShared 'machine-tc2'
            $dashDir = Join-Path $tmpShared 'dashboards'
            New-Item -ItemType Directory -Path $dashDir -Force | Out-Null
            $fake = New-FakeRsmRoot 'rsm-append' 'fail'
            $cliLog = Join-Path $script:Tmp 'append-cli.log'

            # Pre-fix shape: singular header + an old alert about a DIFFERENT
            # machine (no cooldown overlap; also >6h old). The digit-only bump
            # of the pre-fix code left this header at "(2 message)".
            $dashFile = Join-Path $dashDir 'machine-machine-det.md'
            $seed = "---`r`ntype: machine`r`nlastModified: '2026-10-07T00:00:00.000Z'`r`nlastModifiedBy:`r`n  machineId: machine-det`r`n  workspace: listener`r`ntotalMessages: 1`r`n---`r`n`r`n## Status`r`n`r`n## Intercom (1 message)`r`n`r`n### [2026-10-07T00:00:00.000Z] machine-det|listener`r`n[msg: machine-det:listener:ic-20261007T0000-aaaa]`r`n`r`n[FLEET-ALERT] [WARN] Fleet listener check: 1 of 1 machines have STALE/DEAD wake-listeners (threshold >2h). Machines affected: machine-tc2b.`r`n"
            [System.IO.File]::WriteAllText($dashFile, $seed, [System.Text.UTF8Encoding]::new($false))

            $null = Invoke-FleetCheck $tmpShared $fake 'machine-tc2' $cliLog

            $raw = [System.IO.File]::ReadAllText($dashFile)
            $raw | Should -Match '## Intercom \(2 messages\)' -Because 'the count must bump AND the word must be plural'
            $raw | Should -Not -Match '\(\d+ message\)'
            $raw | Should -Match 'machine-tc2b\.' -Because 'the preexisting alert must survive the append'
            # the NEW alert names the newly dead machine
            $raw | Should -Match 'Machines affected: machine-tc2\.'
        }
    }

    Context 'Cooldown - recent overlapping alert on the DETECTOR machine file suppresses' {
        It 'skips the post when a recent alert under 6h covers the same dead machine' -Skip:($env:OS -ne 'Windows_NT') {
            $tmpShared = Join-Path $script:Tmp 'cooldown'
            New-StaleHeartbeat $tmpShared 'machine-tc3'
            $dashDir = Join-Path $tmpShared 'dashboards'
            New-Item -ItemType Directory -Path $dashDir -Force | Out-Null
            $fake = New-FakeRsmRoot 'rsm-cool' 'ok'    # would succeed - must NOT be called
            $cliLog = Join-Path $script:Tmp 'cool-cli.log'

            # Recent (<6h) prior alert naming the SAME dead machine -> overlap.
            $recent = (Get-Date).ToUniversalTime().AddHours(-1).ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
            $dashFile = Join-Path $dashDir 'machine-machine-det.md'
            $seed = "---`r`ntype: machine`r`nlastModified: '$recent'`r`nlastModifiedBy:`r`n  machineId: machine-det`r`n  workspace: listener`r`ntotalMessages: 1`r`n---`r`n`r`n## Status`r`n`r`n## Intercom (1 messages)`r`n`r`n### [$recent] machine-det|listener`r`n[msg: machine-det:listener:ic-20261015T1100-cccc]`r`n`r`n[FLEET-ALERT] [WARN] Fleet listener check: 1 of 1 machines have STALE/DEAD wake-listeners (threshold >2h). Machines affected: machine-tc3.`r`n"
            [System.IO.File]::WriteAllText($dashFile, $seed, [System.Text.UTF8Encoding]::new($false))

            $out = Invoke-FleetCheck $tmpShared $fake 'machine-tc3' $cliLog

            $out | Should -Match 'Cooldown' -Because 'the overlap must suppress the new post'
            $raw = [System.IO.File]::ReadAllText($dashFile)
            $raw | Should -Match '## Intercom \(1 messages\)' -Because 'nothing was appended'
            # The suppression happens BEFORE the CLI: the stub must not run.
            (Test-Path $cliLog) | Should -BeFalse -Because 'cooldown precedes the CLI call'
        }
    }

    Context 'Primary path - CLI posts, the PS does not hand-write the file' {
        It 'invokes rsm-dashboard-append.mjs with --machine detector-id and the alert content' -Skip:($env:OS -ne 'Windows_NT') {
            $tmpShared = Join-Path $script:Tmp 'cli'
            New-StaleHeartbeat $tmpShared 'machine-tc4'
            $fake = New-FakeRsmRoot 'rsm-cli' 'ok'
            $cliLog = Join-Path $script:Tmp 'cli-invocations.log'

            $out = Invoke-FleetCheck $tmpShared $fake 'machine-tc4' $cliLog

            $out | Should -Match 'via RSM CLI'
            $cliLog | Should -Exist -Because 'the stub must have been invoked'
            $argv = [System.IO.File]::ReadAllText($cliLog)
            $argv | Should -Match '--machine'
            $argv | Should -Match 'machine-det'
            $argv | Should -Match 'FLEET-ALERT'
            # The PS must not hand-write the machine file when the CLI posted.
            (Join-Path $tmpShared 'dashboards/machine-machine-det.md') | Should -Not -Exist
        }
    }
}
