<#
.SYNOPSIS
    Regression coverage for #3761 remedies 2+3 (definitive-skip escalation + skip tally).

.DESCRIPTION
    Decision coordinator 07/10 11:21Z, five conditions. These tests cover the
    behavioural half (conditions 1, 2, 4) on the extracted primitives, plus
    static composition guards on the listener branch wiring, plus the fleet
    health read side (check-all-listeners.ps1).

    Extraction pattern: dashboard-listener-wake-routing.Tests.ps1 (AST function
    extraction — the script itself runs a single-instance mutex + main loop and
    cannot be dot-sourced).

    Excluded from CI? No — unit suite, pure temp-dir file effects + one
    Windows-guarded subprocess call.
#>

Describe 'Listener definitive-skip escalation (#3761 remedies 2+3)' {
    BeforeAll {
        $repoRoot = (Resolve-Path "$PSScriptRoot\..\..\..").Path
        $listenerPath = Join-Path $repoRoot 'scripts/dashboard-scheduler/dashboard-listener.ps1'
        $fleetPath = Join-Path $repoRoot 'scripts/dashboard-scheduler/check-all-listeners.ps1'

        $parseErrors = $null
        $tokens = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseFile(
            $listenerPath, [ref]$tokens, [ref]$parseErrors)
        @($parseErrors) | Should -BeNullOrEmpty

        $listenerText = [System.IO.File]::ReadAllText($listenerPath)

        foreach ($name in @('New-EscalationEntry', 'Test-Escalated', 'Add-EscalatedKey',
                            'Write-MachineDashboardMessage', 'Update-DailySkipCount')) {
            $definition = $ast.FindAll(
                { param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] },
                $true
            ) | Where-Object Name -EQ $name | Select-Object -First 1
            if (-not $definition) { throw "$name not found in $listenerPath" }
            Invoke-Expression $definition.Extent.Text
        }

        $script:Tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("t3761-" + [guid]::NewGuid().ToString('N').Substring(0, 8))
        New-Item -ItemType Directory -Path $script:Tmp -Force | Out-Null
    }
    AfterAll {
        if (Test-Path $script:Tmp) { Remove-Item $script:Tmp -Recurse -Force -ErrorAction SilentlyContinue }
    }

    Context 'Dedupe key — condition 1: one escalation per (machine, workspace, wake message)' {
        It 'entry identity is machine|workspace|timestamp|author' {
            $entry = New-EscalationEntry 'myia-po-2023' 'CoursIA' '2026-10-07T19:00:00.000Z' 'myia-ai-01'
            $entry | Should -Be 'myia-po-2023|CoursIA|2026-10-07T19:00:00.000Z|myia-ai-01'
        }

        It 'Test-Escalated is false when the key file is absent (first poll)' {
            $f = Join-Path $script:Tmp 'absent.escalated'
            Test-Escalated $f 'k1' | Should -BeFalse
        }

        It 'round-trip: Add-EscalatedKey then Test-Escalated is true (key persisted on disk)' {
            $f = Join-Path $script:Tmp 'rt.escalated'
            Add-EscalatedKey $f 'k1' 7
            Test-Escalated $f 'k1' | Should -BeTrue
            Test-Escalated $f 'k2' | Should -BeFalse
        }

        It 'second poll on the same wake message finds the key — no new message will be posted' {
            $f = Join-Path $script:Tmp 'second.escalated'
            $key = New-EscalationEntry 'm' 'ws' '2026-10-07T19:00:00.000Z' 'a'
            Add-EscalatedKey $f $key 7
            Test-Escalated $f $key | Should -BeTrue
        }

        It 'Add-EscalatedKey prunes entries older than keepDays' {
            $f = Join-Path $script:Tmp 'prune.escalated'
            $oldTs = [DateTime]::UtcNow.AddDays(-30).ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
            $freshTs = [DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
            Add-EscalatedKey $f ("old|m|$oldTs|x") 7
            Add-EscalatedKey $f ("fresh|m|$freshTs|x") 7
            Test-Escalated $f "old|m|$oldTs|x" | Should -BeFalse
            Test-Escalated $f "fresh|m|$freshTs|x" | Should -BeTrue
        }

        It 'Add-EscalatedKey never wipes unparseable-timestamp lines (conservative prune)' {
            $f = Join-Path $script:Tmp 'prune-conservative.escalated'
            $weird = 'm|ws|not-a-timestamp|x'
            Add-EscalatedKey $f $weird 7
            Test-Escalated $f $weird | Should -BeTrue
        }
    }

    Context 'Machine dashboard message — condition 1: WARN on the machine dashboard, never global' {
        It 'creates a canonical machine dashboard file with one Intercom message (plural seed, MCP convention)' {
            $f = Join-Path $script:Tmp 'machine-testx.md'
            Write-MachineDashboardMessage $f 'testx' '[WARN][LISTENER][#3761] content-un' | Out-Null
            $f | Should -Exist
            $raw = [System.IO.File]::ReadAllText($f)
            $raw | Should -Match '\[msg: testx:listener:ic-'
            $raw | Should -Match '### \[.+\] testx\|listener'
            $raw | Should -Match '## Intercom \(1 messages\)'
            $raw | Should -Match '\[WARN\]\[LISTENER\]\[#3761\] content-un'
        }

        It 'a second append bumps the Intercom count and keeps both messages' {
            $f = Join-Path $script:Tmp 'machine-count.md'
            Write-MachineDashboardMessage $f 'testx' 'msg-alpha' | Out-Null
            Write-MachineDashboardMessage $f 'testx' 'msg-beta' | Out-Null
            $raw = [System.IO.File]::ReadAllText($f)
            $raw | Should -Match '## Intercom \(2 messages\)'
            $raw | Should -Match 'msg-alpha'
            $raw | Should -Match 'msg-beta'
        }

        It 'writes UTF-8 without BOM (fleet-readable, no UTF-16LE trap)' {
            $f = Join-Path $script:Tmp 'machine-bom.md'
            Write-MachineDashboardMessage $f 'testx' 'bom-check' | Out-Null
            $bytes = [System.IO.File]::ReadAllBytes($f)
            $bytes[0] | Should -Not -Be 0xEF
        }
    }

    Context 'Skip tally — condition 4: daily count per workspace, next to the heartbeat' {
        It 'first skip creates date|workspace|1' {
            $f = Join-Path $script:Tmp 'skips.txt'
            Update-DailySkipCount $f 'CoursIA' '2026-10-07'
            ([System.IO.File]::ReadAllLines($f) -contains '2026-10-07|CoursIA|1') | Should -BeTrue
        }

        It 'same day same workspace increments; another workspace gets its own line' {
            $f = Join-Path $script:Tmp 'skips-multi.txt'
            Update-DailySkipCount $f 'CoursIA' '2026-10-07'
            Update-DailySkipCount $f 'CoursIA' '2026-10-07'
            Update-DailySkipCount $f 'claudish' '2026-10-07'
            $lines = [System.IO.File]::ReadAllLines($f)
            ($lines -contains '2026-10-07|CoursIA|2') | Should -BeTrue
            ($lines -contains '2026-10-07|claudish|1') | Should -BeTrue
        }

        It 'keeps today and yesterday, prunes older dates' {
            $f = Join-Path $script:Tmp 'skips-prune.txt'
            Update-DailySkipCount $f 'CoursIA' '2026-10-05'
            Update-DailySkipCount $f 'CoursIA' '2026-10-07'
            $lines = [System.IO.File]::ReadAllLines($f)
            ($lines -match '^2026-10-05\|').Count | Should -Be 0
            ($lines -match '^2026-10-07\|').Count | Should -Be 1
        }

        It 'a corrupt count line is skipped without throwing (Set-LastAck must not be aborted)' {
            $f = Join-Path $script:Tmp 'skips-corrupt.txt'
            [System.IO.File]::WriteAllText($f, "2026-10-07|CoursIA|not-a-number`n", [System.Text.UTF8Encoding]::new($false))
            { Update-DailySkipCount $f 'CoursIA' '2026-10-07' } | Should -Not -Throw
            $lines = [System.IO.File]::ReadAllLines($f)
            ($lines -contains '2026-10-07|CoursIA|1') | Should -BeTrue
        }
    }

    Context 'Composition — condition 2: escalation once, then lastAck advances; transient unchanged' {
        It 'definitive-skip branch escalades only when the dedupe key is absent' {
            $listenerText | Should -Match 'if \(-not \(Test-Escalated \$escKeyFile \$escKey\)\)'
        }

        It 'definitive-skip branch advances lastAck to the FIFO-head trigger timestamp' {
            $listenerText | Should -Match 'Set-LastAck \$ws \$triggerSkipMsg\.timestamp'
        }

        It 'escalation is posted BEFORE lastAck advances (the wake id rides the message)' {
            $iGuard = $listenerText.IndexOf('Test-Escalated $escKeyFile $escKey')
            $iPost = $listenerText.IndexOf('Write-MachineDashboardMessage $MachineDashboardFile')
            $iAck = $listenerText.IndexOf('Set-LastAck $ws $triggerSkipMsg.timestamp')
            $iGuard | Should -BeGreaterThan 0
            $iPost | Should -BeGreaterThan $iGuard
            $iAck | Should -BeGreaterThan $iPost
        }

        It 'escalation targets the MACHINE dashboard (machine- prefix), never global' {
            $listenerText | Should -Match '\$MachineDashboardFile = Join-Path \(Join-Path \$SharedPath "dashboards"\) "machine-\$HeartbeatMachineId\.md"'
        }

        It 'transient failure (spawn exited) keeps lastAck NOT advanced — unchanged' {
            $listenerText | Should -Match 'Spawn exited with code \$exitCode\. lastAck NOT advanced\.'
        }

        It 'heartbeat mirrors the skip tally next to the shared heartbeat' {
            $listenerText | Should -Match '\.skips"\) -Force'
            $listenerText | Should -Match 'Copy-Item \$ListenerSkipsFile'
        }

        It 'DryRun logs the escalation instead of writing it (no side effects)' {
            $listenerText | Should -Match 'Would escalate on machine dashboard'
            $listenerText | Should -Match 'Already escalated \(dedupe key present\) — no new message'
        }
    }

    Context 'Fleet health reads the tally — condition 4 wiring' {
        It 'check-all-listeners counts today entries per machine' -Skip:($env:OS -ne 'Windows_NT') {
            $tmpShared = Join-Path $script:Tmp 'shared'
            $hbDir = Join-Path $tmpShared 'listener-heartbeats'
            New-Item -ItemType Directory -Path $hbDir -Force | Out-Null
            # Fresh heartbeat → ALIVE → exit 0
            [System.IO.File]::WriteAllText((Join-Path $hbDir 'machine-t9.heartbeat'), (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ'), [System.Text.UTF8Encoding]::new($false))
            $today = (Get-Date).ToUniversalTime().ToString('yyyy-MM-dd')
            $skips = "$today|CoursIA|4`n$today|claudish|3`n2020-01-01|stale|99`n"
            [System.IO.File]::WriteAllText((Join-Path $hbDir 'machine-t9.skips'), $skips, [System.Text.UTF8Encoding]::new($false))

            $prev = $env:ROOSYNC_SHARED_PATH
            $env:ROOSYNC_SHARED_PATH = $tmpShared
            try {
                $json = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $fleetPath -Machines 'machine-t9' -NoRepair -NoAlert -Json 2>$null | Out-String
                $obj = $json | ConvertFrom-Json
                $obj.machines[0].skipsToday | Should -Be 7
                $obj.machines[0].heartbeat | Should -Be 'ALIVE'
            } finally {
                $env:ROOSYNC_SHARED_PATH = $prev
            }
        }
    }
}
