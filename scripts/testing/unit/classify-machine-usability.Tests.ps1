<#
.SYNOPSIS
    Coverage for scripts/diagnostic/classify-machine-usability.ps1 (#4327).

.DESCRIPTION
    The classifier answers one question per machine — can it run work? — with three
    verdicts: healthy / unreachable / reachable-but-unusable. The third is what the
    issue adds; the four acceptance criteria that bite are covered here:

      AC2 (#4327) — replaying the po-2028 timeline of 23/10 yields
        reachable-but-unusable, and the detection delay is MEASURED (N minutes),
        not asserted as a constant: the test pins where the verdict flips for a
        given heartbeat threshold, and shows N shrinks when the threshold does.
      AC3 — a healthy machine whose listener alone is dead is `healthy` with a
        `listener-stale` finding, never reachable-but-unusable. This is the
        positive control that separates the classifier from the 2 h listener check.
      AC4 — a machine with no answering port is `unreachable`.
      AC5 — the alert names every input and its value, so the Maintenance lane can
        decide on the hard lever without a second measurement.

    The script runs as a subprocess with a controlled env, like
    check-all-listeners-fleet-alert-bump.Tests.ps1: replay mode needs no network and
    no dashboard (alerts are printed to stdout, the dashboard write is skipped for
    replays by construction). One live smoke test hits 127.0.0.1 and only asserts
    the output SHAPE and that the exit code is in the documented set — loopback
    ports are not part of any acceptance criterion.

    The fixture mirrors the facts reported for po-2028 on 23/10: boot at 11:52Z,
    logon dies ~5 min later, WinRM keeps answering at ~10 s, no session can start.
    It will be replaced by the Maintenance lane's own measurements when they land
    on the issue (the spec is still pending); the shape is what the replay mode eats.
#>

Describe 'classify-machine-usability (#4327)' {
    BeforeAll {
        $repoRoot = (Resolve-Path "$PSScriptRoot\..\..\..").Path
        $script:ClassifierPath = Join-Path $repoRoot 'scripts/diagnostic/classify-machine-usability.ps1'

        $script:Tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("t4327-" + [guid]::NewGuid().ToString('N').Substring(0, 8))
        New-Item -ItemType Directory -Path $script:Tmp -Force | Out-Null

        # Runs the real script in a subprocess; returns stdout, stderr and exit code.
        function Invoke-Classifier {
            param([string[]]$Arguments = @())
            $out = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $script:ClassifierPath @Arguments 2>&1
            $code = $LASTEXITCODE
            return [PSCustomObject]@{ Output = ($out -join "`n"); ExitCode = $code }
        }

        function Write-ReplayFile {
            param([string]$Name, [object]$Payload)
            $path = Join-Path $script:Tmp $Name
            $Payload | ConvertTo-Json -Depth 6 | Set-Content -Path $path -Encoding UTF8
            return $path
        }
    }

    AfterAll {
        if (Test-Path $script:Tmp) { Remove-Item $script:Tmp -Recurse -Force -ErrorAction SilentlyContinue }
    }

    Context 'AC2 — the po-2028 timeline of 23/10 replays as reachable-but-unusable' {
        It 'flips to reachable-but-unusable only once BOTH signals agree, and reports the delay' {
            # 11:52Z clean boot and logon death; the listener heartbeat stops with the
            # logon, so it crosses the 1800 s threshold around 12:22Z. WinRM answers
            # ~10 s from the death on (Maintenance's measurement).
            $payload = [PSCustomObject]@{
                logonDeathUtc = '2026-10-23T11:52:00Z'
                samples = @(
                    [PSCustomObject]@{ atUtc = '2026-10-23T11:51:00Z'; machine = 'myia-po-2028'; openPorts = @(5985, 22, 445); drivingChannelAnswered = $true; drivingLatencyMs = 120; heartbeatAgeSeconds = 10 },
                    [PSCustomObject]@{ atUtc = '2026-10-23T12:02:00Z'; machine = 'myia-po-2028'; openPorts = @(5985, 22, 445); drivingChannelAnswered = $true; drivingLatencyMs = 10240; heartbeatAgeSeconds = 600 },
                    [PSCustomObject]@{ atUtc = '2026-10-23T12:25:00Z'; machine = 'myia-po-2028'; openPorts = @(5985, 22, 445); drivingChannelAnswered = $true; drivingLatencyMs = 10500; heartbeatAgeSeconds = 1980 }
                )
            }
            $path = Write-ReplayFile -Name 'po2028.json' -Payload $payload
            $res = Invoke-Classifier -Arguments @('-ReplayFile', $path, '-Json')

            $res.ExitCode | Should -Be 2 -Because 'at least one sample is reachable-but-unusable'
            $json = $res.Output | ConvertFrom-Json
            $json.machines.Count | Should -Be 3
            $json.machines[0].verdict | Should -Be 'healthy'      # before the death
            $json.machines[1].verdict | Should -Be 'healthy'      # reachable + slow, but heartbeat still fresh
            $json.machines[1].findings | Should -Contain 'driving-channel-slow'
            $json.machines[2].verdict | Should -Be 'reachable-but-unusable'
            $json.machines[2].findings | Should -Contain 'listener-stale'
            # 12:25Z is 33 min after the 11:52Z death — measured, not assumed.
            $json.detectedAfterMinutes | Should -Be 33
        }

        It 'N follows the heartbeat threshold instead of being a constant' {
            $payload = [PSCustomObject]@{
                logonDeathUtc = '2026-10-23T11:52:00Z'
                samples = @(
                    [PSCustomObject]@{ atUtc = '2026-10-23T12:02:00Z'; machine = 'myia-po-2028'; openPorts = @(5985, 22, 445); drivingChannelAnswered = $true; drivingLatencyMs = 10240; heartbeatAgeSeconds = 600 }
                )
            }
            $path = Write-ReplayFile -Name 'po2028-short.json' -Payload $payload
            $res = Invoke-Classifier -Arguments @('-ReplayFile', $path, '-Json', '-HeartbeatStaleSeconds', '300')

            $json = $res.Output | ConvertFrom-Json
            $json.machines[0].verdict | Should -Be 'reachable-but-unusable'
            $json.detectedAfterMinutes | Should -Be 10
        }
    }

    Context 'AC3 — a dead listener on a healthy machine stays healthy' {
        It 'reports healthy with a listener-stale finding, not reachable-but-unusable' {
            $payload = @(
                [PSCustomObject]@{ atUtc = '2026-10-24T01:00:00Z'; machine = 'myia-po-2025'; openPorts = @(5985, 22, 445); drivingChannelAnswered = $true; drivingLatencyMs = 85; heartbeatAgeSeconds = 10800 }
            )
            $path = Write-ReplayFile -Name 'listener-dead.json' -Payload $payload
            $res = Invoke-Classifier -Arguments @('-ReplayFile', $path, '-Json')

            $json = $res.Output | ConvertFrom-Json
            $json.machines[0].verdict | Should -Be 'healthy'
            $json.machines[0].findings | Should -Contain 'listener-stale'
            ($json.machines[0].findings -contains 'driving-channel-slow') | Should -BeFalse
            $res.ExitCode | Should -Be 0
        }

        It 'treats an absent heartbeat as missing evidence, not as death' {
            $payload = @(
                [PSCustomObject]@{ atUtc = '2026-10-24T01:00:00Z'; machine = 'myia-po-2027'; openPorts = @(5985, 445); drivingChannelAnswered = $true; drivingLatencyMs = 9000; heartbeatAgeSeconds = $null }
            )
            $path = Write-ReplayFile -Name 'no-heartbeat.json' -Payload $payload
            $json = (Invoke-Classifier -Arguments @('-ReplayFile', $path, '-Json')).Output | ConvertFrom-Json

            $json.machines[0].verdict | Should -Be 'healthy'
            $json.machines[0].findings | Should -Contain 'no-heartbeat'
            $json.machines[0].findings | Should -Contain 'unusable-suspect'
        }
    }

    Context 'AC4 — no port answers means unreachable' {
        It 'classifies a machine with every probed port closed as unreachable' {
            $payload = @(
                [PSCustomObject]@{ atUtc = '2026-10-24T01:00:00Z'; machine = 'myia-po-2026'; openPorts = @(); drivingChannelAnswered = $false; drivingLatencyMs = $null; heartbeatAgeSeconds = $null }
            )
            $path = Write-ReplayFile -Name 'unreachable.json' -Payload $payload
            $res = Invoke-Classifier -Arguments @('-ReplayFile', $path, '-Json')

            $json = $res.Output | ConvertFrom-Json
            $json.machines[0].verdict | Should -Be 'unreachable'
            $json.machines[0].findings | Should -Contain 'no-port-answers'
            $res.ExitCode | Should -Be 1
        }
    }

    Context 'AC5 — the alert names the inputs and their values' {
        It 'carries ports, channel latency, heartbeat age and the thresholds in the printed alert' {
            $payload = @(
                [PSCustomObject]@{ atUtc = '2026-10-24T01:00:00Z'; machine = 'myia-po-2028'; openPorts = @(5985, 445); drivingChannelAnswered = $true; drivingLatencyMs = 10240; heartbeatAgeSeconds = 2400 }
            )
            $path = Write-ReplayFile -Name 'alert.json' -Payload $payload
            $res = Invoke-Classifier -Arguments @('-ReplayFile', $path)

            $res.Output | Should -Match '\[FLEET-ALERT\] \[CRITICAL\] myia-po-2028 — reachable-but-unusable'
            $res.Output | Should -Match 'ports answering: 5985, 445'
            $res.Output | Should -Match 'answered=True, 10240 ms'
            $res.Output | Should -Match 'slow threshold 5000 ms'
            $res.Output | Should -Match 'listener heartbeat: 2400 s'
            $res.Output | Should -Match 'dead threshold 1800 s'
            $res.Output | Should -Match 'NOT fired by this script'
        }
    }

    Context 'Instrument discipline' {
        It 'exits 3 on a missing replay file instead of pretending a verdict' {
            $missing = Join-Path $script:Tmp 'does-not-exist.json'
            $res = Invoke-Classifier -Arguments @('-ReplayFile', $missing)
            $res.ExitCode | Should -Be 3
        }

        It 'produces a well-formed verdict for a live loopback probe (smoke, shape only)' {
            $res = Invoke-Classifier -Arguments @('-Machines', '127.0.0.1', '-NoAlert', '-Json', '-ProbeTimeoutMs', '1000')
            $json = $res.Output | ConvertFrom-Json
            @('healthy', 'unreachable', 'reachable-but-unusable') | Should -Contain $json.machines[0].verdict
            $json.thresholds.slowChannelMs | Should -Be 5000
            @(0, 1, 2) | Should -Contain $res.ExitCode
        }
    }
}
