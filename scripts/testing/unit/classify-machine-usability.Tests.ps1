<#
.SYNOPSIS
    Coverage for scripts/diagnostic/classify-machine-usability.ps1 (#4327).

.DESCRIPTION
    The classifier answers one question per machine - can it run work? - with three
    verdicts: healthy / unreachable / reachable-but-unusable. The third is what the
    issue adds. What bites, and what is covered here:

      Review item (blocking, ai-01 24/10) - a healthy WinRM endpoint answers HTTP 401
        to an unauthenticated WS-Identify. The probe must read ANY HTTP response as an
        answer and only a timeout/connection error as silence; otherwise a machine
        whose listener alone died is misclassified as a wedge. Pinned against a real
        local HTTP server that answers 401, not by reading the code.
      AC2 - replaying the po-2028 timeline of 23/10 (the Maintenance lane's own 44-row
        extract, converted to JSON by fixtures/build-po2028-fixtures.py, NOT hand-typed)
        yields reachable-but-unusable on the burst ALONE, and the detection delay is
        MEASURED against the 10 min target rather than asserted as a constant.
        The negative-control boot of the same day stays healthy.
      AC3 - heartbeat staleness is corroboration, never a verdict on its own: a dead
        listener on a healthy, fast machine stays `healthy` with a `listener-stale`
        finding, and abnormal latency with a FRESH heartbeat also stays healthy.
      AC4 - a machine with no interactive port answering is `unreachable`.
      AC5 - the alert names the affected machine on its first line and carries every
        input and its threshold, so Maintenance decides without a second measurement.

    The script runs as a subprocess with a controlled env, like
    check-all-listeners-fleet-alert-bump.Tests.ps1: replay mode needs no network and
    no dashboard (alerts are printed to stdout, the dashboard write is skipped for
    replays by construction). The subprocess helper drives whichever PowerShell is
    present - powershell.exe 5.1 on the seats, pwsh in CI - so the guarded script is
    exercised on both engines instead of being skipped where it cannot spawn 5.1.
    Probe-level cases dot-source the same file with CLASSIFIER_LIB_ONLY=1, which
    defines the functions without running a classification.
#>

Describe 'classify-machine-usability (#4327)' {
    BeforeAll {
        $repoRoot = (Resolve-Path "$PSScriptRoot\..\..\..").Path
        $script:ClassifierPath = Join-Path $repoRoot 'scripts/diagnostic/classify-machine-usability.ps1'
        $script:FixtureDir = Join-Path $repoRoot 'scripts/diagnostic/fixtures'

        $script:Tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("t4327-" + [guid]::NewGuid().ToString('N').Substring(0, 8))
        New-Item -ItemType Directory -Path $script:Tmp -Force | Out-Null

        # Engine choice: the production seats are Windows (5.1 via powershell.exe),
        # but CI runs this suite on ubuntu under pwsh - where `powershell.exe`
        # simply does not exist (measured: CommandNotFoundException on run
        # 40039072379, all 8 cases red). Skipping on non-Windows would leave the
        # guarded script unexercised, so the helper drives whichever engine is
        # present: coverage over a green tick that asserts nothing.
        # CLASSIFIER_PS_EXE forces an engine (used to reproduce CI locally).
        $script:PsExe = if (-not [string]::IsNullOrEmpty($env:CLASSIFIER_PS_EXE)) {
            $env:CLASSIFIER_PS_EXE
        } elseif (Get-Command powershell.exe -ErrorAction SilentlyContinue) {
            'powershell.exe'
        } else {
            'pwsh'
        }
        # -ExecutionPolicy is a Windows-only concern; pwsh on Linux has no such
        # policy layer, so the flag is only passed to the 5.1 host.
        $script:PsBase = @('-NoProfile')
        if ([System.IO.Path]::GetFileNameWithoutExtension($script:PsExe) -eq 'powershell') {
            $script:PsBase += @('-ExecutionPolicy', 'Bypass')
        }

        # Runs the real script in a subprocess; returns stdout, stderr and exit code.
        function Invoke-Classifier {
            param([string[]]$Arguments = @(), [hashtable]$Environment = @{})
            $saved = @{}
            foreach ($k in $Environment.Keys) {
                $saved[$k] = [System.Environment]::GetEnvironmentVariable($k)
                [System.Environment]::SetEnvironmentVariable($k, $Environment[$k])
            }
            try {
                $out = & $script:PsExe @script:PsBase -File $script:ClassifierPath @Arguments 2>&1
                $code = $LASTEXITCODE
                return [PSCustomObject]@{ Output = ($out -join "`n"); ExitCode = $code }
            } finally {
                foreach ($k in $Environment.Keys) {
                    [System.Environment]::SetEnvironmentVariable($k, $saved[$k])
                }
            }
        }

        function Write-ReplayFile {
            param([string]$Name, [object]$Payload)
            $path = Join-Path $script:Tmp $Name
            $Payload | ConvertTo-Json -Depth 6 | Set-Content -Path $path -Encoding UTF8
            return $path
        }

        # pwsh 7's ConvertFrom-Json re-materializes ANY ISO-8601 string into a
        # [DateTime] while 5.1 leaves it a [string] - the reader-side twin of the trap
        # the script itself documents (lesson-pwsh7-json-datetime-deserialization).
        # The producer is right either way; assertions normalize instead of pinning
        # one engine's rendering.
        function Format-UtcText {
            param($Value)
            if ($null -eq $Value) { return $null }
            if ($Value -is [datetime]) { return $Value.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ') }
            return ([DateTimeOffset]::Parse([string]$Value, [System.Globalization.CultureInfo]::InvariantCulture)).UtcDateTime.ToString('yyyy-MM-ddTHH:mm:ssZ')
        }

        # A real local HTTP endpoint, so the 401 rule is MEASURED, not read. The
        # listener lives in this process (an in-process runspace can hold the live
        # object), which is why this is not a Start-Job.
        function Start-FakeHttpEndpoint {
            param([string]$StatusLine = 'HTTP/1.1 401 Unauthorized')
            $listener = New-Object System.Net.Sockets.TcpListener([System.Net.IPAddress]::Loopback, 0)
            $listener.Start()
            $port = ([System.Net.IPEndPoint]$listener.LocalEndpoint).Port
            $ps = [powershell]::Create()
            $null = $ps.AddScript({
                param($listener, $statusLine)
                try {
                    $client = $listener.AcceptTcpClient()
                    $stream = $client.GetStream()
                    $buf = New-Object byte[] 8192
                    $read = 0
                    try { $read = $stream.Read($buf, 0, $buf.Length) } catch { }
                    $body = [System.Text.Encoding]::ASCII.GetBytes("$statusLine`r`nContent-Length: 0`r`nConnection: close`r`n`r`n")
                    $stream.Write($body, 0, $body.Length)
                    $stream.Flush()
                    $client.Close()
                } catch {
                }
            }).AddArgument($listener).AddArgument($StatusLine)
            $handle = $ps.BeginInvoke()
            return [PSCustomObject]@{ Port = $port; Listener = $listener; Shell = $ps; Handle = $handle }
        }

        function Stop-FakeHttpEndpoint {
            param($Endpoint)
            if ($null -eq $Endpoint) { return }
            try { $Endpoint.Listener.Stop() } catch { }
            try { $Endpoint.Shell.Dispose() } catch { }
        }

        # A port that is certainly closed: bind it, read it, release it.
        function Get-ClosedPort {
            $l = New-Object System.Net.Sockets.TcpListener([System.Net.IPAddress]::Loopback, 0)
            $l.Start()
            $p = ([System.Net.IPEndPoint]$l.LocalEndpoint).Port
            $l.Stop()
            return $p
        }
    }

    AfterAll {
        if (Test-Path $script:Tmp) { Remove-Item $script:Tmp -Recurse -Force -ErrorAction SilentlyContinue }
    }

    Context 'Blocking review item - an HTTP 401 is an ANSWER, not silence' {
        # Dot-sourced HERE, not through a helper: `. $path` inside a function defines
        # the functions in the FUNCTION's scope, so the tests would not see them
        # (measured: CommandNotFoundException on all three probe cases).
        BeforeAll {
            $env:CLASSIFIER_LIB_ONLY = '1'
            try {
                . $script:ClassifierPath
            } finally {
                Remove-Item Env:CLASSIFIER_LIB_ONLY -ErrorAction SilentlyContinue
            }
        }

        It 'reads a 401 from a live endpoint as an answered channel and keeps the status code' {
            $fake = Start-FakeHttpEndpoint -StatusLine 'HTTP/1.1 401 Unauthorized'
            try {
                $r = Measure-DrivingChannel -ComputerName '127.0.0.1' -Port $fake.Port -TimeoutMs 3000 -WinRm
                $r.answered | Should -BeTrue -Because 'the WinRM stack answered; 401 only means the SOAP call was unauthenticated'
                $r.statusCode | Should -Be 401
                $r.latencyMs | Should -Not -BeNullOrEmpty
            } finally { Stop-FakeHttpEndpoint -Endpoint $fake }
        }

        It 'reads a 200 as an answer too (the rule is "any response", not "any non-401")' {
            $fake = Start-FakeHttpEndpoint -StatusLine 'HTTP/1.1 200 OK'
            try {
                $r = Measure-DrivingChannel -ComputerName '127.0.0.1' -Port $fake.Port -TimeoutMs 3000 -WinRm
                $r.answered | Should -BeTrue
                $r.statusCode | Should -Be 200
            } finally { Stop-FakeHttpEndpoint -Endpoint $fake }
        }

        It 'still reads a connection failure as silence' {
            $closed = Get-ClosedPort
            $r = Measure-DrivingChannel -ComputerName '127.0.0.1' -Port $closed -TimeoutMs 1000 -WinRm
            $r.answered | Should -BeFalse -Because 'nothing is listening: that is the ONLY shape of silence'
            $r.latencyMs | Should -BeNullOrEmpty
        }
    }

    Context 'AC2 - the po-2028 timeline of 23/10 replays as reachable-but-unusable' {
        It 'turns the burst alone into a wedge verdict, and measures the delay against the 10 min target' {
            $fixture = Join-Path $script:FixtureDir 'po2028-20261023.json'
            Test-Path $fixture | Should -BeTrue -Because 'the fixture is committed and generated from the Maintenance CSV'
            $res = Invoke-Classifier -Arguments @('-ReplayFile', $fixture, '-Json', '-NoAlert')

            $res.ExitCode | Should -Be 2 -Because 'two samples are reachable-but-unusable'
            $json = $res.Output | ConvertFrom-Json

            # The burst the detector found, from the real rows: 07:48:41Z, x6, _ab668,
            # T+3.5 min after the 07:45:13Z boot.
            $json.burst.utcText | ForEach-Object { Format-UtcText $_ } | Should -Be '2026-10-23T07:48:41Z'
            $json.burst.count | Should -Be 6
            $json.burst.suffix | Should -Be '_ab668'
            $json.burst.minutesAfterBoot | Should -Be 3.5

            $json.machines.Count | Should -Be 3
            $json.machines[0].verdict | Should -Be 'healthy'                # 07:47Z, before the burst
            $json.machines[1].verdict | Should -Be 'reachable-but-unusable' # 07:50Z, after it
            $json.machines[2].verdict | Should -Be 'reachable-but-unusable'

            # The proof that the burst is SUFFICIENT ON ITS OWN: the deciding sample
            # has a fresh heartbeat and healthy latency, so nothing else could have
            # produced the verdict.
            $json.machines[1].heartbeatAgeSeconds | Should -Be 79
            @($json.machines[1].findings) | Should -Contain 'logon-death-burst'
            @($json.machines[1].findings) | Should -Not -Contain 'listener-stale'
            @($json.machines[1].findings) | Should -Not -Contain 'driving-channel-slow'

            # AC2: the delay is measured, and it respects the spec's target.
            $json.detectedAfterMinutes | Should -Be 1.3
            $json.detectedAfterMinutes | Should -BeLessOrEqual $json.thresholds.verdictDeadlineMinutes
        }

        It 'keeps the negative-control boot of the same day healthy (no burst in the window)' {
            $fixture = Join-Path $script:FixtureDir 'po2028-20261023-control.json'
            $res = Invoke-Classifier -Arguments @('-ReplayFile', $fixture, '-Json', '-NoAlert')
            $json = $res.Output | ConvertFrom-Json

            $json.burst | Should -BeNullOrEmpty
            $json.machines[0].verdict | Should -Be 'healthy'
            @($json.machines[0].findings) | Should -Not -Contain 'logon-death-burst'
            $res.ExitCode | Should -Be 0
        }

        It 'reports a delay that moves with WHEN the detector ran, not a constant' {
            $events = @(
                [PSCustomObject]@{ utc = '2026-10-23T07:45:13Z'; id = 12; message = 'OS start' }
            ) + @(1..6 | ForEach-Object {
                [PSCustomObject]@{ utc = '2026-10-23T07:48:41Z'; id = 7031; message = "Le service Service utilisateur de notifications Push Windows_ab668 s'est termine de maniere inattendue." }
            })
            $probe = {
                param($at)
                [PSCustomObject]@{
                    atUtc = $at; machine = 'myia-po-2028'; openPorts = @(5985, 22, 445)
                    drivingChannelAnswered = $true; drivingStatusCode = 401; drivingLatencyMs = 4
                    latencySamplesMs = @(391, 412, 445); heartbeatAgeSeconds = 90
                }
            }
            $early = Write-ReplayFile -Name 'n-early.json' -Payload ([PSCustomObject]@{
                lastBootUtc = '2026-10-23T07:45:13Z'; events = $events; samples = @((& $probe '2026-10-23T07:56:41Z'))
            })
            $late = Write-ReplayFile -Name 'n-late.json' -Payload ([PSCustomObject]@{
                lastBootUtc = '2026-10-23T07:45:13Z'; events = $events; samples = @((& $probe '2026-10-23T08:00:41Z'))
            })

            $a = (Invoke-Classifier -Arguments @('-ReplayFile', $early, '-Json', '-NoAlert')).Output | ConvertFrom-Json
            $b = (Invoke-Classifier -Arguments @('-ReplayFile', $late, '-Json', '-NoAlert')).Output | ConvertFrom-Json

            $a.detectedAfterMinutes | Should -Be 8
            $b.detectedAfterMinutes | Should -Be 12 -Because 'a detector that ran later reports a later delay: the number is derived, not pinned'
            $a.machines[0].verdict | Should -Be 'reachable-but-unusable'
            $b.machines[0].verdict | Should -Be 'reachable-but-unusable'
        }

        It 'ignores a burst that falls outside [boot+2 min, boot+20 min]' {
            # Same shape, but the burst is 25 min after the boot: the window is what
            # makes the signal specific, so it must not fire.
            $events = @(
                [PSCustomObject]@{ utc = '2026-10-23T07:45:13Z'; id = 12; message = 'OS start' }
            ) + @(1..6 | ForEach-Object {
                [PSCustomObject]@{ utc = '2026-10-23T08:10:13Z'; id = 7031; message = 'service_ab668 s est termine de maniere inattendue.' }
            })
            $payload = [PSCustomObject]@{
                lastBootUtc = '2026-10-23T07:45:13Z'
                events = $events
                samples = @([PSCustomObject]@{
                    atUtc = '2026-10-23T08:20:00Z'; machine = 'myia-po-2028'; openPorts = @(5985, 22, 445)
                    drivingChannelAnswered = $true; drivingStatusCode = 401; drivingLatencyMs = 4
                    latencySamplesMs = @(391, 412, 445); heartbeatAgeSeconds = 90
                })
            }
            $path = Write-ReplayFile -Name 'burst-out-of-window.json' -Payload $payload
            $json = (Invoke-Classifier -Arguments @('-ReplayFile', $path, '-Json', '-NoAlert')).Output | ConvertFrom-Json

            $json.burst | Should -BeNullOrEmpty
            $json.machines[0].verdict | Should -Be 'healthy'
        }
    }

    Context 'AC3 - the heartbeat corroborates, it never decides alone' {
        It 'keeps a healthy fast machine with a dead listener as healthy + listener-stale' {
            $payload = @(
                [PSCustomObject]@{ atUtc = '2026-10-24T01:00:00Z'; machine = 'myia-po-2025'; openPorts = @(5985, 22, 445); drivingChannelAnswered = $true; drivingStatusCode = 401; drivingLatencyMs = 85; latencySamplesMs = @(85, 91, 88); heartbeatAgeSeconds = 10800 }
            )
            $path = Write-ReplayFile -Name 'listener-dead.json' -Payload $payload
            $res = Invoke-Classifier -Arguments @('-ReplayFile', $path, '-Json', '-NoAlert')
            $json = $res.Output | ConvertFrom-Json

            $json.machines[0].verdict | Should -Be 'healthy'
            @($json.machines[0].findings) | Should -Contain 'listener-stale'
            @($json.machines[0].findings) | Should -Not -Contain 'driving-channel-slow'
            $res.ExitCode | Should -Be 0
        }

        It 'keeps abnormal latency with a FRESH heartbeat as healthy (the heartbeat gates the lever)' {
            $payload = @(
                [PSCustomObject]@{ atUtc = '2026-10-24T01:00:00Z'; machine = 'myia-po-2028'; openPorts = @(5985, 22, 445); drivingChannelAnswered = $true; drivingStatusCode = 401; drivingLatencyMs = 4; latencySamplesMs = @(12000, 11000, 9000); heartbeatAgeSeconds = 120 }
            )
            $path = Write-ReplayFile -Name 'slow-fresh.json' -Payload $payload
            $json = (Invoke-Classifier -Arguments @('-ReplayFile', $path, '-Json', '-NoAlert')).Output | ConvertFrom-Json

            $json.machines[0].verdict | Should -Be 'healthy'
            @($json.machines[0].findings) | Should -Contain 'driving-channel-slow'
        }

        It 'reaches the verdict through corroboration when latency is abnormal AND the heartbeat is stale' {
            $payload = @(
                [PSCustomObject]@{ atUtc = '2026-10-24T01:00:00Z'; machine = 'myia-po-2028'; openPorts = @(5985, 22, 445); drivingChannelAnswered = $true; drivingStatusCode = 401; drivingLatencyMs = 4; latencySamplesMs = @(12000, 11000, 9000); heartbeatAgeSeconds = 2400 }
            )
            $path = Write-ReplayFile -Name 'slow-stale.json' -Payload $payload
            $res = Invoke-Classifier -Arguments @('-ReplayFile', $path, '-Json', '-NoAlert')
            $json = $res.Output | ConvertFrom-Json

            $json.machines[0].verdict | Should -Be 'reachable-but-unusable'
            @($json.machines[0].findings) | Should -Contain 'driving-channel-slow'
            @($json.machines[0].findings) | Should -Contain 'listener-stale'
            $res.ExitCode | Should -Be 2
        }

        It 'needs 2 of 3 probes over the threshold, not one' {
            $payload = @(
                [PSCustomObject]@{ atUtc = '2026-10-24T01:00:00Z'; machine = 'myia-po-2028'; openPorts = @(5985, 22, 445); drivingChannelAnswered = $true; drivingStatusCode = 401; drivingLatencyMs = 4; latencySamplesMs = @(12000, 400, 380); heartbeatAgeSeconds = 2400 }
            )
            $path = Write-ReplayFile -Name 'slow-one-of-three.json' -Payload $payload
            $json = (Invoke-Classifier -Arguments @('-ReplayFile', $path, '-Json', '-NoAlert')).Output | ConvertFrom-Json

            $json.machines[0].verdict | Should -Be 'healthy' -Because 'one slow probe out of three is not the spec signal'
            @($json.machines[0].findings) | Should -Not -Contain 'driving-channel-slow'
        }

        It 'treats an absent heartbeat as missing evidence, not as death' {
            $payload = @(
                [PSCustomObject]@{ atUtc = '2026-10-24T01:00:00Z'; machine = 'myia-po-2027'; openPorts = @(5985, 445); drivingChannelAnswered = $true; drivingStatusCode = 401; drivingLatencyMs = 9000; latencySamplesMs = @(9000, 8000, 7000); heartbeatAgeSeconds = $null }
            )
            $path = Write-ReplayFile -Name 'no-heartbeat.json' -Payload $payload
            $json = (Invoke-Classifier -Arguments @('-ReplayFile', $path, '-Json', '-NoAlert')).Output | ConvertFrom-Json

            $json.machines[0].verdict | Should -Be 'healthy'
            @($json.machines[0].findings) | Should -Contain 'heartbeat-unknown'
        }

        It 'exits 3 when the INSTRUMENT is missing, instead of printing all clear' {
            $payload = @(
                [PSCustomObject]@{ atUtc = '2026-10-24T01:00:00Z'; machine = 'myia-po-2027'; openPorts = @(5985, 445); drivingChannelAnswered = $true; drivingStatusCode = 401; drivingLatencyMs = 85; latencySamplesMs = @(85, 90, 88); heartbeatInstrumentPresent = $false }
            )
            $path = Write-ReplayFile -Name 'no-instrument.json' -Payload $payload
            $res = Invoke-Classifier -Arguments @('-ReplayFile', $path, '-Json', '-NoAlert')
            $json = $res.Output | ConvertFrom-Json

            @($json.machines[0].findings) | Should -Contain 'no-instrument'
            $json.machines[0].verdict | Should -Be 'healthy' -Because 'absence of the instrument is not a measurement of the machine'
            $res.ExitCode | Should -Be 3 -Because 'the sweep is incomplete and must not read as clean'
        }
    }

    Context 'AC4 - no interactive port answers means unreachable' {
        It 'classifies a machine with every probed port closed as unreachable' {
            $payload = @(
                [PSCustomObject]@{ atUtc = '2026-10-24T01:00:00Z'; machine = 'myia-po-2026'; openPorts = @(); drivingChannelAnswered = $false; drivingLatencyMs = $null; latencySamplesMs = @(); heartbeatAgeSeconds = $null }
            )
            $path = Write-ReplayFile -Name 'unreachable.json' -Payload $payload
            $res = Invoke-Classifier -Arguments @('-ReplayFile', $path, '-Json', '-NoAlert')
            $json = $res.Output | ConvertFrom-Json

            $json.machines[0].verdict | Should -Be 'unreachable'
            @($json.machines[0].findings) | Should -Contain 'no-port-answers'
            $res.ExitCode | Should -Be 1
        }

        It 'still treats a Windows seat as reachable when only RDP answers (5985 AND 3389 closed is the rule)' {
            $payload = @(
                [PSCustomObject]@{ atUtc = '2026-10-24T01:00:00Z'; machine = 'myia-po-2026'; openPorts = @(3389); drivingChannelAnswered = $false; drivingLatencyMs = $null; latencySamplesMs = @(); heartbeatAgeSeconds = $null }
            )
            $path = Write-ReplayFile -Name 'rdp-only.json' -Payload $payload
            $json = (Invoke-Classifier -Arguments @('-ReplayFile', $path, '-Json', '-NoAlert')).Output | ConvertFrom-Json

            $json.machines[0].verdict | Should -Not -Be 'unreachable'
        }

        It 'treats a Linux seat as unreachable when SSH is closed, even if SMB answers' {
            $payload = @(
                [PSCustomObject]@{ atUtc = '2026-10-24T01:00:00Z'; machine = 'myia-web1'; openPorts = @(445); drivingChannelAnswered = $false; drivingLatencyMs = $null; latencySamplesMs = @(); heartbeatAgeSeconds = $null }
            )
            $path = Write-ReplayFile -Name 'linux-unreachable.json' -Payload $payload
            $json = (Invoke-Classifier -Arguments @('-ReplayFile', $path, '-Json', '-NoAlert')).Output | ConvertFrom-Json

            $json.machines[0].verdict | Should -Be 'unreachable'
        }
    }

    Context 'AC5 - the alert names the machine and every input' {
        It 'leads with the affected machine and carries boot, burst, latency, heartbeat and thresholds' {
            $fixture = Join-Path $script:FixtureDir 'po2028-20261023.json'
            $res = Invoke-Classifier -Arguments @('-ReplayFile', $fixture)

            $res.Output | Should -Match '\[FLEET-ALERT\] \[CRITICAL\] myia-po-2028 - reachable-but-unusable'
            $res.Output | Should -Match 'Affected machine: \*\*myia-po-2028\*\*'
            $res.Output | Should -Match 'last boot \(System log, event 12\): 2026-10-23T07:45:13Z'
            $res.Output | Should -Match '2026-10-23T07:48:41Z x6 suffix _ab668'
            $res.Output | Should -Match '391, 412, 445 ms \(threshold 3000 ms\)'
            $res.Output | Should -Match 'status 401'
            $res.Output | Should -Match 'corroborating threshold 1800 s'
            $res.Output | Should -Match 'external 4624 logons in the window'
            $res.Output | Should -Match 'within 10 min of the logon death'
            $res.Output | Should -Match 'NOT fired by this script'
        }
    }

    Context 'Instrument discipline' {
        It 'exits 3 on a missing replay file instead of pretending a verdict' {
            $missing = Join-Path $script:Tmp 'does-not-exist.json'
            $res = Invoke-Classifier -Arguments @('-ReplayFile', $missing)
            $res.ExitCode | Should -Be 3
        }

        It 'rejects a timestamp without an offset instead of reading it in the seat timezone' {
            $payload = [PSCustomObject]@{
                lastBootUtc = '2026-10-23T07:45:13'
                events = @()
                samples = @([PSCustomObject]@{ atUtc = '2026-10-23T07:50:00'; machine = 'myia-po-2028'; openPorts = @(5985); drivingChannelAnswered = $true; latencySamplesMs = @(400, 410, 420); heartbeatAgeSeconds = 90 })
            }
            $path = Write-ReplayFile -Name 'offsetless.json' -Payload $payload
            $res = Invoke-Classifier -Arguments @('-ReplayFile', $path, '-NoAlert', '-Json')
            $res.ExitCode | Should -Be 3
        }

        It 'splits a comma-separated -Machines value instead of inventing one bogus machine' {
            # `-Machines a,b` under `powershell -File` arrives as ONE string (measured:
            # false `unreachable`, exit 1). Two loopback entries must yield two rows.
            $res = Invoke-Classifier -Arguments @('-Machines', '127.0.0.1,127.0.0.1', '-NoAlert', '-Json', '-ProbeTimeoutMs', '400')
            # A live probe that prints nothing is not a "split" bug and not a pass: name
            # the child's own words instead of letting ConvertFrom-Json fail on a blank
            # line (the CI log otherwise says only "position 0").
            $res.Output | Should -Not -BeNullOrEmpty -Because "the child produced no output at all (exit $($res.ExitCode))"
            $json = $res.Output | ConvertFrom-Json
            $json.machines.Count | Should -Be 2
            $json.machines[0].machine | Should -Be '127.0.0.1'
        }

        It 'produces a well-formed verdict for a live loopback probe (smoke, shape only)' {
            $res = Invoke-Classifier -Arguments @('-Machines', '127.0.0.1', '-NoAlert', '-Json', '-ProbeTimeoutMs', '400')
            $res.Output | Should -Not -BeNullOrEmpty -Because "the child produced no output at all (exit $($res.ExitCode))"
            $json = $res.Output | ConvertFrom-Json
            @('healthy', 'unreachable', 'reachable-but-unusable') | Should -Contain $json.machines[0].verdict
            $json.thresholds.slowChannelMs | Should -Be 3000
            $json.thresholds.verdictDeadlineMinutes | Should -Be 10
            @(0, 1, 2, 3) | Should -Contain $res.ExitCode
        }

        It 'exits 3 when the System log of a WINDOWS seat could not be read' {
            # Found by running the live sweep against this very seat: Invoke-Command to
            # itself fails there, the decisive input is unreadable, and the first
            # version still printed `healthy` and exited 0 - the exact "silent green"
            # the review objected to, one layer lower than the review looked.
            $payload = @(
                [PSCustomObject]@{ atUtc = '2026-10-24T01:00:00Z'; machine = 'myia-po-2023'; openPorts = @(5985, 3389, 445); drivingChannelAnswered = $true; drivingStatusCode = 401; drivingLatencyMs = 4; latencySamplesMs = @(250, 260, 255); heartbeatAgeSeconds = 250; systemLogAvailable = $false }
            )
            $path = Write-ReplayFile -Name 'log-unavailable-windows.json' -Payload $payload
            $res = Invoke-Classifier -Arguments @('-ReplayFile', $path, '-Json', '-NoAlert')
            $json = $res.Output | ConvertFrom-Json

            @($json.machines[0].findings) | Should -Contain 'system-log-unavailable'
            $json.machines[0].verdict | Should -Be 'healthy' -Because 'an unreadable log is missing evidence, not a wedge'
            $res.ExitCode | Should -Be 3 -Because 'the decisive input was never read, so the sweep is incomplete'
        }

        It 'stays quiet about the System log on a LINUX seat, which has no such log to read' {
            # web1/web2 drive over SSH (port 22): there is no Windows System log and no
            # logon-death burst concept. Reporting it missing would be permanent noise
            # on a seat that can never produce it.
            $payload = @(
                [PSCustomObject]@{ atUtc = '2026-10-24T01:00:00Z'; machine = 'myia-web1'; openPorts = @(22, 445); drivingChannelAnswered = $true; drivingLatencyMs = 12; latencySamplesMs = @(12, 14, 11); heartbeatAgeSeconds = 300; systemLogAvailable = $false }
            )
            $path = Write-ReplayFile -Name 'log-unavailable-linux.json' -Payload $payload
            $res = Invoke-Classifier -Arguments @('-ReplayFile', $path, '-Json', '-NoAlert')
            $json = $res.Output | ConvertFrom-Json

            @($json.machines[0].findings) | Should -Not -Contain 'system-log-unavailable'
            $res.ExitCode | Should -Be 0
        }
    }
}
