<#
.SYNOPSIS
    Coverage for the persistent-UNVERIFIED warning of check-all-listeners.ps1
    (#4503 point 1 — coordinator decision 13/11).

.DESCRIPTION
    Decision under test: a machine that stays UNVERIFIED across consecutive
    passes gets AT MOST ONE warning per day, and the warning NEVER wakes an
    agent. The pass-to-pass state lives in
    listener-heartbeats/.unverified-warn-state-<detector>.json (per-detector
    file, no cross-seat race); the warning posts on the DETECTOR's machine
    dashboard (listeners only scan workspace dashboards for [WAKE-*] tags) via
    the same write path as [FLEET-ALERT] (Add-MachineDashboardMessage).

    Covered:
      - Pass 1 (no prior state): NO warning — "two consecutive passes" is a
        precondition; the state file is written with lastStatus=UNKNOWN.
      - Pass 2: exactly ONE warning naming the machine; no [WAKE-*] tag in the
        content; no workspace-*.md written (the wake surface is untouched).
      - Pass 3 same UTC day: still ONE warning (per-day cap), state carries
        lastWarnDayUtc=today.
      - Day rollover: a new warning is allowed (the cap is per day, not a
        permanent suppressor).
      - ALIVE resets the streak: a fresh heartbeat turns lastStatus to ALIVE
        and a later disappearance needs TWO passes again before warning.
      - -NoAlert leaves the state file untouched (a diagnostic pass does not
        consume the warning cadence).
      - Two mutants (témoins de mutation): the real script refuses where each
        mutant posts, proving the suite kills both regressions.

    Harness: same technique as check-all-listeners-fleet-alert-bump.Tests.ps1 —
    real script in a subprocess with controlled env (ROOSYNC_SHARED_PATH,
    FLEET_SHARED_ROOTS, ROOSYNC_MACHINE_ID) and a fake RSM root in 'fail' mode
    so the file fallback writes a locally countable machine dashboard.

    Excluded from CI? No - unit suite, temp-dir file effects + Windows-guarded
    subprocess calls.
#>

Describe 'Persistent-UNVERIFIED warning (#4503 point 1, decision 13/11)' {
    BeforeAll {
        $repoRoot = (Resolve-Path "$PSScriptRoot\..\..\..").Path
        $script:FleetPath = Join-Path $repoRoot 'scripts/dashboard-scheduler/check-all-listeners.ps1'

        $script:Tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("t4503uw-" + [guid]::NewGuid().ToString('N').Substring(0, 8))
        New-Item -ItemType Directory -Path $script:Tmp -Force | Out-Null

        # Pester v5 : les helpers doivent vivre dans BeforeAll pour être visibles des It.
        function Invoke-FleetCheck($fleetPath, $tmpShared, $fakeRsmRoot, $machines, [switch]$NoAlert) {
            $prevShared = $env:ROOSYNC_SHARED_PATH
            $prevRsmRoot = $env:RSM_SERVER_ROOT
            $prevMachineId = $env:ROOSYNC_MACHINE_ID
            $prevFleetRoots = $env:FLEET_SHARED_ROOTS
            $env:ROOSYNC_SHARED_PATH = $tmpShared
            $env:RSM_SERVER_ROOT = $fakeRsmRoot
            $env:ROOSYNC_MACHINE_ID = 'machine-det'
            $env:FLEET_SHARED_ROOTS = $tmpShared
            try {
                $cliArgs = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $fleetPath, '-Machines', $machines, '-NoRepair')
                if ($NoAlert) { $cliArgs += '-NoAlert' }
                $out = & powershell.exe @cliArgs 2>$null
                return ($out -join "`n")
            } finally {
                $env:ROOSYNC_SHARED_PATH = $prevShared
                $env:RSM_SERVER_ROOT = $prevRsmRoot
                $env:ROOSYNC_MACHINE_ID = $prevMachineId
                $env:FLEET_SHARED_ROOTS = $prevFleetRoots
            }
        }

        # Fake RSM root in 'fail' mode: the CLI stub exits 1 -> the PS file
        # fallback writes the machine dashboard locally (countable assertions).
        function New-FakeRsmRoot($name) {
            $root = Join-Path $script:Tmp $name
            $scripts = Join-Path $root 'scripts'
            New-Item -ItemType Directory -Path $scripts -Force | Out-Null
            $body = 'process.stderr.write("ERREUR: ecriture GDrive impossible"); process.exit(1);'
            [System.IO.File]::WriteAllText((Join-Path $scripts 'rsm-dashboard-append.mjs'), $body, [System.Text.UTF8Encoding]::new($false))
            return $root
        }

        function Get-StateFile($tmpShared) {
            Join-Path $tmpShared 'listener-heartbeats/.unverified-warn-state-machine-det.json'
        }

        function Get-MachineDashboard($tmpShared) {
            Join-Path $tmpShared 'dashboards/machine-machine-det.md'
        }

        function Get-WarnCount($tmpShared) {
            $dash = Get-MachineDashboard $tmpShared
            if (-not (Test-Path $dash)) { return 0 }
            return ([regex]::Matches([System.IO.File]::ReadAllText($dash), '\[FLEET-UNVERIFIED\]')).Count
        }

        function New-FreshHeartbeat($tmpShared, $machine) {
            $hbDir = Join-Path $tmpShared 'listener-heartbeats'
            New-Item -ItemType Directory -Path $hbDir -Force | Out-Null
            $fresh = (Get-Date).ToUniversalTime().AddMinutes(-1).ToString('yyyy-MM-ddTHH:mm:ssZ')
            [System.IO.File]::WriteAllText((Join-Path $hbDir "$machine.heartbeat"), $fresh, [System.Text.UTF8Encoding]::new($false))
        }

        # Mutant factory: copy the real script and break ONE condition.
        #  - 'no-cap'      : removes the per-day gate (-not $warnedToday)
        #  - 'no-consecutive': removes the two-passes precondition ($wasUnknown)
        function New-Mutant($name, $kind) {
            $mut = Join-Path $script:Tmp "$name.ps1"
            $raw = [System.IO.File]::ReadAllText($script:FleetPath)
            $orig = "if (`$r.heartbeat -eq 'UNKNOWN' -and `$wasUnknown -and -not `$warnedToday) {"
            if ($kind -eq 'no-cap') {
                $broken = "if (`$r.heartbeat -eq 'UNKNOWN' -and `$wasUnknown) {"
            } else {
                $broken = "if (`$r.heartbeat -eq 'UNKNOWN' -and -not `$warnedToday) {"
            }
            if (-not $raw.Contains($orig)) { throw "mutant anchor not found in source" }
            [System.IO.File]::WriteAllText($mut, $raw.Replace($orig, $broken), [System.Text.UTF8Encoding]::new($true))
            return $mut
        }
    }
    AfterAll {
        if (Test-Path $script:Tmp) { Remove-Item $script:Tmp -Recurse -Force -ErrorAction SilentlyContinue }
    }

    Context 'Pass cadence - two consecutive passes, then at most one warning per day' {
        It 'pass 1 does NOT warn (no prior state) but records lastStatus=UNKNOWN' -Skip:($env:OS -ne 'Windows_NT') {
            $tmpShared = Join-Path $script:Tmp 'cadence'
            New-Item -ItemType Directory -Path $tmpShared -Force | Out-Null   # no heartbeat inside -> UNKNOWN
            $fake = New-FakeRsmRoot 'rsm-cadence'

            $null = Invoke-FleetCheck $script:FleetPath $tmpShared $fake 'machine-uw'

            (Get-WarnCount $tmpShared) | Should -Be 0 -Because 'a machine UNVERIFIED on its FIRST observed pass has not been UNVERIFIED "across consecutive passes"'
            $state = Get-Content (Get-StateFile $tmpShared) -Raw -Encoding UTF8 | ConvertFrom-Json
            $state.machines.'machine-uw'.lastStatus | Should -Be 'UNKNOWN' -Because 'the state must record this pass so the next one can detect the streak'
            $state.machines.'machine-uw'.lastWarnDayUtc | Should -Be '' -Because 'nothing was warned yet'
        }

        It 'pass 2 warns exactly once, names the machine, posts NO wake tag and NO workspace dashboard' -Skip:($env:OS -ne 'Windows_NT') {
            $tmpShared = Join-Path $script:Tmp 'warn'
            New-Item -ItemType Directory -Path $tmpShared -Force | Out-Null
            $fake = New-FakeRsmRoot 'rsm-warn'

            $null = Invoke-FleetCheck $script:FleetPath $tmpShared $fake 'machine-uw'   # pass 1
            $null = Invoke-FleetCheck $script:FleetPath $tmpShared $fake 'machine-uw'   # pass 2

            (Get-WarnCount $tmpShared) | Should -Be 1 -Because 'the second consecutive UNVERIFIED pass must warn, exactly once'
            $dash = Get-MachineDashboard $tmpShared
            $raw = [System.IO.File]::ReadAllText($dash)
            $raw | Should -Match 'machine-uw' -Because 'the warning must name the unverified machine'
            $raw | Should -Not -Match '\[WAKE-[A-Z]+\]' -Because 'the warning must never carry a wake tag (#4503 decision 13/11: no agent wake)'
            $raw | Should -Match 'type: machine' -Because 'the warning lives on the MACHINE dashboard of the detector'
            # The wake surface is the workspace dashboard: nothing may be written there.
            (Get-ChildItem $tmpShared -Recurse -Filter 'workspace-*.md') | Should -BeNullOrEmpty -Because 'no workspace dashboard write = structurally no agent wake'
        }

        It 'pass 3 same UTC day: no second warning (per-day cap), state carries lastWarnDayUtc' -Skip:($env:OS -ne 'Windows_NT') {
            $tmpShared = Join-Path $script:Tmp 'cap'
            New-Item -ItemType Directory -Path $tmpShared -Force | Out-Null
            $fake = New-FakeRsmRoot 'rsm-cap'

            $null = Invoke-FleetCheck $script:FleetPath $tmpShared $fake 'machine-uw'   # pass 1
            $null = Invoke-FleetCheck $script:FleetPath $tmpShared $fake 'machine-uw'   # pass 2 -> warns
            $null = Invoke-FleetCheck $script:FleetPath $tmpShared $fake 'machine-uw'   # pass 3 -> capped

            (Get-WarnCount $tmpShared) | Should -Be 1 -Because 'the warning is capped at one per UTC day per machine'
            $state = Get-Content (Get-StateFile $tmpShared) -Raw -Encoding UTF8 | ConvertFrom-Json
            $today = (Get-Date).ToUniversalTime().ToString('yyyy-MM-dd')
            $state.machines.'machine-uw'.lastWarnDayUtc | Should -Be $today -Because 'the cap is materialized in the state file'
        }

        It 'day rollover allows a new warning (the cap is per day, not permanent)' -Skip:($env:OS -ne 'Windows_NT') {
            $tmpShared = Join-Path $script:Tmp 'rollover'
            New-Item -ItemType Directory -Path $tmpShared -Force | Out-Null
            $fake = New-FakeRsmRoot 'rsm-rollover'

            $null = Invoke-FleetCheck $script:FleetPath $tmpShared $fake 'machine-uw'   # pass 1
            $null = Invoke-FleetCheck $script:FleetPath $tmpShared $fake 'machine-uw'   # pass 2 -> warns

            # Simulate the next day: lastWarnDayUtc -> yesterday, streak intact.
            $sf = Get-StateFile $tmpShared
            $state = Get-Content $sf -Raw -Encoding UTF8 | ConvertFrom-Json
            $yesterday = (Get-Date).ToUniversalTime().AddDays(-1).ToString('yyyy-MM-dd')
            $state.machines.'machine-uw'.lastWarnDayUtc = $yesterday
            $state | ConvertTo-Json -Depth 4 | ForEach-Object { [System.IO.File]::WriteAllText($sf, $_, [System.Text.UTF8Encoding]::new($false)) }

            $null = Invoke-FleetCheck $script:FleetPath $tmpShared $fake 'machine-uw'   # next day, still UNKNOWN

            (Get-WarnCount $tmpShared) | Should -Be 2 -Because 'a new UTC day re-arms the warning for a still-unverified machine'
        }
    }

    Context 'Streak semantics - ALIVE resets, -NoAlert is inert' {
        It 'a fresh heartbeat flips lastStatus to ALIVE and no warning fires even with prior UNKNOWN state' -Skip:($env:OS -ne 'Windows_NT') {
            $tmpShared = Join-Path $script:Tmp 'alive-reset'
            New-Item -ItemType Directory -Path $tmpShared -Force | Out-Null
            $fake = New-FakeRsmRoot 'rsm-alive'

            $null = Invoke-FleetCheck $script:FleetPath $tmpShared $fake 'machine-uw'   # pass 1: UNKNOWN recorded
            New-FreshHeartbeat $tmpShared 'machine-uw'                                   # seat comes back
            $null = Invoke-FleetCheck $script:FleetPath $tmpShared $fake 'machine-uw'   # pass 2: ALIVE

            (Get-WarnCount $tmpShared) | Should -Be 0 -Because 'a machine that publishes again is not warned'
            $state = Get-Content (Get-StateFile $tmpShared) -Raw -Encoding UTF8 | ConvertFrom-Json
            $state.machines.'machine-uw'.lastStatus | Should -Be 'ALIVE' -Because 'the streak was broken by a verified pass'
        }

        It 'after a reset, the machine needs TWO unknown passes again before warning' -Skip:($env:OS -ne 'Windows_NT') {
            $tmpShared = Join-Path $script:Tmp 're-streak'
            New-Item -ItemType Directory -Path $tmpShared -Force | Out-Null
            $fake = New-FakeRsmRoot 'rsm-restreak'

            $null = Invoke-FleetCheck $script:FleetPath $tmpShared $fake 'machine-uw'   # pass 1: UNKNOWN
            New-FreshHeartbeat $tmpShared 'machine-uw'
            $null = Invoke-FleetCheck $script:FleetPath $tmpShared $fake 'machine-uw'   # pass 2: ALIVE (reset)
            Remove-Item (Join-Path $tmpShared 'listener-heartbeats/machine-uw.heartbeat') -Force
            $null = Invoke-FleetCheck $script:FleetPath $tmpShared $fake 'machine-uw'   # pass 3: first UNKNOWN after reset
            (Get-WarnCount $tmpShared) | Should -Be 0 -Because 'one unknown pass after a reset is not "two consecutive passes"'
            $null = Invoke-FleetCheck $script:FleetPath $tmpShared $fake 'machine-uw'   # pass 4: second consecutive UNKNOWN
            (Get-WarnCount $tmpShared) | Should -Be 1 -Because 'two consecutive unknown passes after the reset must warn again'
        }

        It '-NoAlert does not read or write the warning state' -Skip:($env:OS -ne 'Windows_NT') {
            $tmpShared = Join-Path $script:Tmp 'noalert'
            New-Item -ItemType Directory -Path $tmpShared -Force | Out-Null
            $fake = New-FakeRsmRoot 'rsm-noalert'

            $null = Invoke-FleetCheck $script:FleetPath $tmpShared $fake 'machine-uw'   # pass 1 (alerting): state created
            $sf = Get-StateFile $tmpShared
            $before = [System.IO.File]::ReadAllText($sf)

            $null = Invoke-FleetCheck $script:FleetPath $tmpShared $fake 'machine-uw' -NoAlert   # diagnostic pass

            [System.IO.File]::ReadAllText($sf) | Should -Be $before -Because 'a -NoAlert pass must not consume the warning cadence nor mutate the streak state'
        }
    }

    Context 'Mutants (témoins de mutation) - the suite must kill both regressions' {
        It 'mutant "no-cap" (per-day gate removed) posts twice the same day where the real script refuses' -Skip:($env:OS -ne 'Windows_NT') {
            $mut = New-Mutant 'mutant-nocap' 'no-cap'
            $tmpShared = Join-Path $script:Tmp 'mut-nocap'
            New-Item -ItemType Directory -Path $tmpShared -Force | Out-Null
            $fake = New-FakeRsmRoot 'rsm-mut-nocap'

            $null = Invoke-FleetCheck $mut $tmpShared $fake 'machine-uw'   # pass 1
            $null = Invoke-FleetCheck $mut $tmpShared $fake 'machine-uw'   # pass 2 -> warns
            $null = Invoke-FleetCheck $mut $tmpShared $fake 'machine-uw'   # pass 3 -> mutant warns AGAIN

            (Get-WarnCount $tmpShared) | Should -Be 2 -Because 'the mutant must exhibit the uncapped spam the real script prevents (the cap test kills it)'
        }

        It 'mutant "no-consecutive" (streak precondition removed) warns on the FIRST pass where the real script refuses' -Skip:($env:OS -ne 'Windows_NT') {
            $mut = New-Mutant 'mutant-noconsecutive' 'no-consecutive'
            $tmpShared = Join-Path $script:Tmp 'mut-nocons'
            New-Item -ItemType Directory -Path $tmpShared -Force | Out-Null
            $fake = New-FakeRsmRoot 'rsm-mut-nocons'

            $null = Invoke-FleetCheck $mut $tmpShared $fake 'machine-uw'   # single pass

            (Get-WarnCount $tmpShared) | Should -Be 1 -Because 'the mutant must warn without a streak (the pass-1 test kills it)'
        }
    }

    Context 'Overflow beyond 10 named machines (#4503 follow-up) - the 11th must not be silently consumed' {
        It 'with 11 UNVERIFIED seats: pass 2 names at most 10 and leaves the 11th un-stamped; pass 3 names it' -Skip:($env:OS -ne 'Windows_NT') {
            $tmpShared = Join-Path $script:Tmp 'overflow'
            New-Item -ItemType Directory -Path $tmpShared -Force | Out-Null   # no heartbeat inside -> every machine is UNKNOWN
            $fake = New-FakeRsmRoot 'rsm-overflow'
            $eleven = (1..11 | ForEach-Object { "m$_" }) -join ','

            $null = Invoke-FleetCheck $script:FleetPath $tmpShared $fake $eleven   # pass 1: streak recorded, no warning
            $null = Invoke-FleetCheck $script:FleetPath $tmpShared $fake $eleven   # pass 2: warning, at most 10 named

            (Get-WarnCount $tmpShared) | Should -Be 1 -Because 'the overflow must not multiply the posting, only the naming'
            $state = Get-Content (Get-StateFile $tmpShared) -Raw -Encoding UTF8 | ConvertFrom-Json
            $today = (Get-Date).ToUniversalTime().ToString('yyyy-MM-dd')
            foreach ($i in 1..10) {
                $name = "m$i"
                $state.machines.$name.lastWarnDayUtc | Should -Be $today -Because "$name is NAMED in the message, so its daily cap is legitimately consumed"
            }
            # The 11th was NOT named by the message. The base script stamped every
            # $toWarn member anyway (named or not): its daily cap is consumed
            # without a word, and since -First 10 over a deterministic order always
            # returns the same seats, m11 is silenced permanently - not for a day.
            $state.machines.m11.lastWarnDayUtc | Should -Be '' -Because 'm11 was not named in any message; stamping it would silence it forever, not for a day'

            $null = Invoke-FleetCheck $script:FleetPath $tmpShared $fake $eleven   # pass 3 same day: the leftover is named

            (Get-WarnCount $tmpShared) | Should -Be 2 -Because 'the machine left out of the first message must be warned on the next pass, not suppressed for the whole day'
            $raw = [System.IO.File]::ReadAllText((Get-MachineDashboard $tmpShared))
            $raw | Should -Match 'm11' -Because 'the second warning must name the overflow machine'
        }
    }
}
