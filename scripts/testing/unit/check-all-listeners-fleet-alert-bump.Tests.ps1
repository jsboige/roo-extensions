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

    Age is read from the ISO timestamp INSIDE the file (the listener writes it),
    falling back to the file's LastWriteTimeUtc only when the content is empty or
    unparseable (#4503 main subject: a stale DriveFS mtime must not make a live
    machine read STALE). The stale setups below write a backdated timestamp into
    the CONTENT and also backdate the file mtime, so they stay STALE under the
    content-first rule.

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
            $prevFleetRoots = $env:FLEET_SHARED_ROOTS
            $env:ROOSYNC_SHARED_PATH = $tmpShared
            $env:RSM_SERVER_ROOT = $fakeRsmRoot
            $env:ROOSYNC_MACHINE_ID = 'machine-det'
            $env:FLEET_CLI_LOG = $cliLog
            # Isolation : la surcharge FLEET_SHARED_ROOTS REMPLACE la decouverte.
            # Sans elle, le script enumererait les vrais miroirs DriveFS de la
            # machine de test — la lecture serait realiste mais non deterministe
            # (et le verdict dependrait de ce que la flotte publie a l'instant).
            $env:FLEET_SHARED_ROOTS = $tmpShared
            try {
                $out = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $script:FleetPath -Machines $machines -NoRepair 2>$null
                return ($out -join "`n")
            } finally {
                $env:ROOSYNC_SHARED_PATH = $prevShared
                $env:RSM_SERVER_ROOT = $prevRsmRoot
                $env:ROOSYNC_MACHINE_ID = $prevMachineId
                $env:FLEET_CLI_LOG = $prevCliLog
                $env:FLEET_SHARED_ROOTS = $prevFleetRoots
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

        # Heartbeat frais (contenu ISO) dans une racine donnee.
        function New-FreshHeartbeat($root, $machine, $minutesAgo = 1) {
            $hbDir = Join-Path $root 'listener-heartbeats'
            New-Item -ItemType Directory -Path $hbDir -Force | Out-Null
            $fresh = (Get-Date).ToUniversalTime().AddMinutes(-$minutesAgo).ToString('yyyy-MM-ddTHH:mm:ssZ')
            [System.IO.File]::WriteAllText((Join-Path $hbDir "$machine.heartbeat"), $fresh, [System.Text.UTF8Encoding]::new($false))
        }

        # Heartbeat vieux (contenu ISO) dans une racine donnee.
        function New-AgedHeartbeat($root, $machine, $daysAgo = 3) {
            $hbDir = Join-Path $root 'listener-heartbeats'
            New-Item -ItemType Directory -Path $hbDir -Force | Out-Null
            $old = (Get-Date).ToUniversalTime().AddDays(-$daysAgo).ToString('yyyy-MM-ddTHH:mm:ssZ')
            $hbf = Join-Path $hbDir "$machine.heartbeat"
            [System.IO.File]::WriteAllText($hbf, $old, [System.Text.UTF8Encoding]::new($false))
            (Get-Item $hbf).LastWriteTimeUtc = (Get-Date).ToUniversalTime().AddDays(-$daysAgo)
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

    Context '#4503 - a missing heartbeat is UNVERIFIED, never counted healthy or dead' {
        It 'reports an absent heartbeat as UNVERIFIED, not STALE and not healthy' -Skip:($env:OS -ne 'Windows_NT') {
            $tmpShared = Join-Path $script:Tmp 'unknown'
            New-Item -ItemType Directory -Path $tmpShared -Force | Out-Null   # shared path exists, no heartbeat inside
            $fake = New-FakeRsmRoot 'rsm-unknown' 'ok'
            $cliLog = Join-Path $script:Tmp 'unknown-cli.log'

            $out = Invoke-FleetCheck $tmpShared $fake 'machine-ux' $cliLog

            $out | Should -Match '1 UNVERIFIED' -Because 'the absent heartbeat must be surfaced as UNVERIFIED, not folded into a clean green'
            $out | Should -Match 'no heartbeat readable' -Because 'the note must state the run verified nothing for that machine'
            $out | Should -Not -Match 'FLEET-ALERT' -Because 'UNKNOWN must never arm the STALE alert (that is the false-positive the issue targets)'
        }

        It 'JSON output carries totalUnknown=1 and totalDead=0 for a missing heartbeat' -Skip:($env:OS -ne 'Windows_NT') {
            $tmpShared = Join-Path $script:Tmp 'unknown-json'
            New-Item -ItemType Directory -Path $tmpShared -Force | Out-Null
            $prevShared = $env:ROOSYNC_SHARED_PATH
            $prevRsmRoot = $env:RSM_SERVER_ROOT
            $prevFleetRoots = $env:FLEET_SHARED_ROOTS
            $env:ROOSYNC_SHARED_PATH = $tmpShared
            $env:RSM_SERVER_ROOT = ''
            $env:FLEET_SHARED_ROOTS = $tmpShared
            try {
                $jsonOut = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $script:FleetPath -Machines 'machine-ux' -NoRepair -Json 2>$null
            } finally {
                $env:ROOSYNC_SHARED_PATH = $prevShared
                $env:RSM_SERVER_ROOT = $prevRsmRoot
                $env:FLEET_SHARED_ROOTS = $prevFleetRoots
            }
            $j = ($jsonOut -join "`n") | ConvertFrom-Json
            $j.totalUnknown | Should -Be 1 -Because 'the absent heartbeat is counted as unknown, not dead'
            $j.totalDead | Should -Be 0 -Because 'an unreadable heartbeat is not evidence of death'
            $j.machines[0].heartbeat | Should -Be 'UNKNOWN'
        }
    }

    Context '#4503 (sujet principal) - the ALIVE/STALE verdict reads the embedded ISO content, mtime is only the fallback' {
        # Fresh content + stale mtime -> ALIVE. A live machine must not read STALE
        # just because DriveFS propagated a stale mtime in the reader's G: view:
        # the embedded timestamp is the authority (this is the false-positive the
        # issue targets).
        It 'reports ALIVE when the content timestamp is fresh even though the file mtime is stale' -Skip:($env:OS -ne 'Windows_NT') {
            $tmpShared = Join-Path $script:Tmp 'content-alive'
            $hbDir = Join-Path $tmpShared 'listener-heartbeats'
            New-Item -ItemType Directory -Path $hbDir -Force | Out-Null
            $hbf = Join-Path $hbDir 'machine-ca.heartbeat'
            $fresh = (Get-Date).ToUniversalTime().AddMinutes(-1).ToString('yyyy-MM-ddTHH:mm:ssZ')
            [System.IO.File]::WriteAllText($hbf, $fresh, [System.Text.UTF8Encoding]::new($false))
            (Get-Item $hbf).LastWriteTimeUtc = (Get-Date).ToUniversalTime().AddHours(-3)   # stale mtime, must not win
            $fake = New-FakeRsmRoot 'rsm-content-alive' 'ok'
            $cliLog = Join-Path $script:Tmp 'content-alive-cli.log'

            $out = Invoke-FleetCheck $tmpShared $fake 'machine-ca' $cliLog

            $out | Should -Match 'machine-ca'
            $out | Should -Match 'ALIVE' -Because 'the embedded fresh timestamp must win over the stale mtime'
            $out | Should -Not -Match 'FLEET-ALERT' -Because 'a live machine must not arm the STALE alert'
        }

        # Stale content + fresh mtime -> STALE. The content is authoritative in the
        # other direction too: a heartbeat whose own data is 3h old is stale even
        # if the file was re-synced recently and its mtime is fresh.
        It 'reports STALE when the content timestamp is old even though the file mtime is fresh' -Skip:($env:OS -ne 'Windows_NT') {
            $tmpShared = Join-Path $script:Tmp 'content-stale'
            $hbDir = Join-Path $tmpShared 'listener-heartbeats'
            New-Item -ItemType Directory -Path $hbDir -Force | Out-Null
            $hbf = Join-Path $hbDir 'machine-cs.heartbeat'
            $stale = (Get-Date).ToUniversalTime().AddHours(-3).ToString('yyyy-MM-ddTHH:mm:ssZ')
            [System.IO.File]::WriteAllText($hbf, $stale, [System.Text.UTF8Encoding]::new($false))
            # mtime left fresh (just written) - must NOT rescue a stale content
            $fake = New-FakeRsmRoot 'rsm-content-stale' 'ok'
            $cliLog = Join-Path $script:Tmp 'content-stale-cli.log'

            $out = Invoke-FleetCheck $tmpShared $fake 'machine-cs' $cliLog

            $out | Should -Match 'STALE' -Because 'the embedded old timestamp must make the machine stale'
            $out | Should -Match 'FLEET-ALERT' -Because 'a genuinely stale heartbeat must arm the alert'
        }
    }

    Context '#4503 (cause racine) - the verdict reads the FRESHEST proof across the shared-state mirrors' {
        # Le symptome de #4503 : deux miroirs DriveFS de l'etat partage
        # (« Synchronisation » et « Synchronisation (1) ») divergent. Un siege
        # publie dans le miroir (1) ; un lecteur qui ne lit QUE la racine
        # canonique ne le voit pas et le declare mort, ou absent. Le correctif
        # lit l'UNION des miroirs et retient la preuve la plus recente.

        It 'reads ALIVE a machine that publishes ONLY in the divergent mirror' -Skip:($env:OS -ne 'Windows_NT') {
            $rootA = Join-Path $script:Tmp 'mirror-a'
            $rootB = Join-Path $script:Tmp 'mirror-b'
            New-Item -ItemType Directory -Path $rootA -Force | Out-Null
            New-Item -ItemType Directory -Path $rootB -Force | Out-Null
            # Le siege vit dans le miroir B, absent du miroir A.
            New-FreshHeartbeat $rootB 'machine-split'

            $prevFleetRoots = $env:FLEET_SHARED_ROOTS
            $env:FLEET_SHARED_ROOTS = "$rootA;$rootB"
            try {
                $out = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $script:FleetPath -Machines 'machine-split' -NoRepair -NoAlert 2>$null
            } finally {
                $env:FLEET_SHARED_ROOTS = $prevFleetRoots
            }
            $text = ($out -join "`n")

            $text | Should -Match 'machine-split'
            $text | Should -Match 'ALIVE' -Because 'a machine publishing in the divergent mirror must not read STALE, nor UNKNOWN'
            $text | Should -Not -Match 'FLEET-ALERT' -Because 'a live machine must not arm the STALE alert'
        }

        It 'keeps ALIVE a machine that is STALE in one mirror and fresh in another' -Skip:($env:OS -ne 'Windows_NT') {
            $rootA = Join-Path $script:Tmp 'mirror-stale-a'
            $rootB = Join-Path $script:Tmp 'mirror-fresh-b'
            New-Item -ItemType Directory -Path $rootA -Force | Out-Null
            New-Item -ItemType Directory -Path $rootB -Force | Out-Null
            New-AgedHeartbeat $rootA 'machine-both' 3
            New-FreshHeartbeat $rootB 'machine-both' 1

            $prevFleetRoots = $env:FLEET_SHARED_ROOTS
            $env:FLEET_SHARED_ROOTS = "$rootA;$rootB"
            try {
                $out = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $script:FleetPath -Machines 'machine-both' -NoRepair -NoAlert 2>$null
            } finally {
                $env:FLEET_SHARED_ROOTS = $prevFleetRoots
            }
            $text = ($out -join "`n")

            $text | Should -Match 'ALIVE' -Because 'the freshest proof wins across mirrors'
            $text | Should -Not -Match 'FLEET-ALERT' -Because 'a stale copy must not outvote a fresh publication'
        }

        It 'names the mirror that supplied the verdict (issue piste 3)' -Skip:($env:OS -ne 'Windows_NT') {
            $rootA = Join-Path $script:Tmp 'mirror-named-a'
            $rootB = Join-Path $script:Tmp 'mirror-named-b'
            New-Item -ItemType Directory -Path $rootA -Force | Out-Null
            New-Item -ItemType Directory -Path $rootB -Force | Out-Null
            New-FreshHeartbeat $rootB 'machine-src'

            $prevFleetRoots = $env:FLEET_SHARED_ROOTS
            $env:FLEET_SHARED_ROOTS = "$rootA;$rootB"
            try {
                $out = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $script:FleetPath -Machines 'machine-src' -NoRepair -NoAlert -Json 2>$null
            } finally {
                $env:FLEET_SHARED_ROOTS = $prevFleetRoots
            }
            $j = (($out -join "`n")) | ConvertFrom-Json

            $j.machines[0].sourceRoot | Should -Be $rootB -Because 'the verdict must name the root it was read from'
            $j.machines[0].sourceKind | Should -Be 'content' -Because 'the embedded ISO timestamp is the authority'
            $j.sharedRoots.Count | Should -Be 2 -Because 'both mirrors must be reported to the reader'
        }

        It 'marks a seat silent for more than 7 days RETIRED, and does not alert on it' -Skip:($env:OS -ne 'Windows_NT') {
            $rootA = Join-Path $script:Tmp 'mirror-retired'
            New-Item -ItemType Directory -Path $rootA -Force | Out-Null
            New-AgedHeartbeat $rootA 'machine-gone' 30

            $prevFleetRoots = $env:FLEET_SHARED_ROOTS
            $env:FLEET_SHARED_ROOTS = $rootA
            try {
                $out = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $script:FleetPath -Machines 'machine-gone' -NoRepair -NoAlert 2>$null
            } finally {
                $env:FLEET_SHARED_ROOTS = $prevFleetRoots
            }
            $text = ($out -join "`n")

            $text | Should -Match 'RETIRED' -Because 'a seat silent for a month is out of scope, not a dead listener'
            $text | Should -Not -Match 'FLEET-ALERT' -Because 'a permanent alert on a retired seat is exactly the noise #4503 targets'
        }
    }

    Context '#4503 (exit instrument) - a run that verified nothing is not a green run' {
        It 'exits 2 when no heartbeat is readable anywhere' -Skip:($env:OS -ne 'Windows_NT') {
            $rootA = Join-Path $script:Tmp 'exit-empty'
            New-Item -ItemType Directory -Path $rootA -Force | Out-Null

            $prevFleetRoots = $env:FLEET_SHARED_ROOTS
            $env:FLEET_SHARED_ROOTS = $rootA
            try {
                & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $script:FleetPath -Machines 'machine-none' -NoRepair -NoAlert 2>$null | Out-Null
                $code = $LASTEXITCODE
            } finally {
                $env:FLEET_SHARED_ROOTS = $prevFleetRoots
            }

            $code | Should -Be 2 -Because 'a pass that read nothing must not report success to a scheduler'
        }

        It 'exits 0 when at least one seat is verified' -Skip:($env:OS -ne 'Windows_NT') {
            $rootA = Join-Path $script:Tmp 'exit-ok'
            New-Item -ItemType Directory -Path $rootA -Force | Out-Null
            New-FreshHeartbeat $rootA 'machine-ok'

            $prevFleetRoots = $env:FLEET_SHARED_ROOTS
            $env:FLEET_SHARED_ROOTS = $rootA
            try {
                & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $script:FleetPath -Machines 'machine-ok' -NoRepair -NoAlert 2>$null | Out-Null
                $code = $LASTEXITCODE
            } finally {
                $env:FLEET_SHARED_ROOTS = $prevFleetRoots
            }

            $code | Should -Be 0 -Because 'a verified fleet is a green run'
        }
    }

    Context '#4503 (roster) - the machine list comes from the declarative manifest' {
        It 'checks the 9 seats of fleet-manifest.json, not a hardcoded list of 6' -Skip:($env:OS -ne 'Windows_NT') {
            $rootA = Join-Path $script:Tmp 'roster'
            New-Item -ItemType Directory -Path $rootA -Force | Out-Null

            $prevFleetRoots = $env:FLEET_SHARED_ROOTS
            $env:FLEET_SHARED_ROOTS = $rootA
            try {
                $out = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $script:FleetPath -NoRepair -NoAlert -Json 2>$null
            } finally {
                $env:FLEET_SHARED_ROOTS = $prevFleetRoots
            }
            $j = (($out -join "`n")) | ConvertFrom-Json
            $ids = @($j.machines | ForEach-Object { $_.machineId })

            $ids | Should -Contain 'myia-po-2027' -Because 'the manifest seat publishes a heartbeat and was never checked'
            $ids | Should -Contain 'myia-po-2028' -Because 'the manifest seat publishes a heartbeat and was never checked'
            $ids | Should -Contain 'myia-web2' -Because 'the manifest seat publishes a heartbeat and was never checked'
            $ids.Count | Should -Be 9 -Because 'the manifest declares 9 seats'
        }
    }
}
