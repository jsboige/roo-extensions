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
        finding, and abnormal latency with a FRESH heartbeat also stays healthy. The
        spec's bar has a second half (no dashboard append from any lane): a recent
        append clears the corroborator, an UNMEASURED one never corroborates.
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

        It 'reaches the verdict through corroboration when latency is abnormal AND BOTH liveness halves are silent' {
            $payload = @(
                [PSCustomObject]@{ atUtc = '2026-10-24T01:00:00Z'; machine = 'myia-po-2028'; openPorts = @(5985, 22, 445); drivingChannelAnswered = $true; drivingStatusCode = 401; drivingLatencyMs = 4; latencySamplesMs = @(12000, 11000, 9000); heartbeatAgeSeconds = 2400; dashboardAppendAgeSeconds = 2500 }
            )
            $path = Write-ReplayFile -Name 'slow-stale.json' -Payload $payload
            $res = Invoke-Classifier -Arguments @('-ReplayFile', $path, '-Json', '-NoAlert')
            $json = $res.Output | ConvertFrom-Json

            $json.machines[0].verdict | Should -Be 'reachable-but-unusable'
            @($json.machines[0].findings) | Should -Contain 'driving-channel-slow'
            @($json.machines[0].findings) | Should -Contain 'listener-stale'
            @($json.machines[0].findings) | Should -Contain 'no-recent-dashboard-append'
            $res.ExitCode | Should -Be 2
        }

        It 'clears the corroborator when ANY lane of the machine posted recently, heartbeat notwithstanding' {
            # The spec's bar is an AND (ai-01:Maintenance 24/10, section 2). A lane that
            # appended 2 min ago proves the machine can run work, so stale heartbeat +
            # abnormal latency must NOT manufacture a wedge - this is the separating
            # control for the second half, exactly as AC3 is for the first.
            $payload = @(
                [PSCustomObject]@{ atUtc = '2026-10-24T01:00:00Z'; machine = 'myia-po-2028'; openPorts = @(5985, 22, 445); drivingChannelAnswered = $true; drivingStatusCode = 401; drivingLatencyMs = 4; latencySamplesMs = @(12000, 11000, 9000); heartbeatAgeSeconds = 2400; dashboardAppendAgeSeconds = 120 }
            )
            $path = Write-ReplayFile -Name 'slow-stale-append-fresh.json' -Payload $payload
            $res = Invoke-Classifier -Arguments @('-ReplayFile', $path, '-Json', '-NoAlert')
            $json = $res.Output | ConvertFrom-Json

            $json.machines[0].verdict | Should -Be 'healthy'
            @($json.machines[0].findings) | Should -Contain 'listener-stale'
            @($json.machines[0].findings) | Should -Contain 'driving-channel-slow'
            @($json.machines[0].findings) | Should -Not -Contain 'no-recent-dashboard-append'
            $res.ExitCode | Should -Be 0
        }

        It 'does not corroborate on an UNMEASURED append age: a missing input is named, never assumed silent' {
            $payload = @(
                [PSCustomObject]@{ atUtc = '2026-10-24T01:00:00Z'; machine = 'myia-po-2028'; openPorts = @(5985, 22, 445); drivingChannelAnswered = $true; drivingStatusCode = 401; drivingLatencyMs = 4; latencySamplesMs = @(12000, 11000, 9000); heartbeatAgeSeconds = 2400 }
            )
            $path = Write-ReplayFile -Name 'slow-stale-append-unknown.json' -Payload $payload
            $res = Invoke-Classifier -Arguments @('-ReplayFile', $path, '-Json', '-NoAlert')
            $json = $res.Output | ConvertFrom-Json

            $json.machines[0].verdict | Should -Be 'healthy' -Because 'the spec requires evidence of silence, not absence of an instrument'
            @($json.machines[0].findings) | Should -Contain 'dashboard-append-unknown'
            $res.ExitCode | Should -Be 0
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

        It 'treats an absent heartbeat as missing evidence, not as death - and stays exit 0 on purpose' {
            # This pins the coordinator's residual review on #4329 (24/10): either fold
            # `heartbeat-unknown` into the exit-3 guard or declare it deliberate. It is
            # deliberate, and the counter-example is measured: myia-po-2028 carried NO
            # heartbeat file on 25/10 while posting [DONE] c.24 at 16:32Z and opening
            # PR #4359. Exit 3 would have flagged a working machine on every sweep.
            $payload = @(
                [PSCustomObject]@{ atUtc = '2026-10-24T01:00:00Z'; machine = 'myia-po-2027'; openPorts = @(5985, 445); drivingChannelAnswered = $true; drivingStatusCode = 401; drivingLatencyMs = 9000; latencySamplesMs = @(9000, 8000, 7000); heartbeatAgeSeconds = $null; dashboardAppendAgeSeconds = 5400 }
            )
            $path = Write-ReplayFile -Name 'no-heartbeat.json' -Payload $payload
            $res = Invoke-Classifier -Arguments @('-ReplayFile', $path, '-Json', '-NoAlert')
            $json = $res.Output | ConvertFrom-Json

            $json.machines[0].verdict | Should -Be 'healthy'
            @($json.machines[0].findings) | Should -Contain 'heartbeat-unknown'
            $res.ExitCode | Should -Be 0 -Because 'absence of the FILE is a measurement of the input, unlike a missing instrument'
        }

        It 'exits 3 when the INSTRUMENT is missing, instead of printing all clear' {
            $payload = @(
                [PSCustomObject]@{ atUtc = '2026-10-24T01:00:00Z'; machine = 'myia-po-2027'; openPorts = @(5985, 445); drivingChannelAnswered = $true; drivingStatusCode = 401; drivingLatencyMs = 85; latencySamplesMs = @(85, 90, 88); heartbeatInstrumentPresent = $false }
            )
            $path = Write-ReplayFile -Name 'no-instrument.json' -Payload $payload
            $res = Invoke-Classifier -Arguments @('-ReplayFile', $path, '-Json', '-NoAlert')
            $json = $res.Output | ConvertFrom-Json

            @($json.machines[0].findings) | Should -Contain 'no-instrument'
            @($json.machines[0].findings) | Should -Not -Contain 'dashboard-append-unknown' -Because 'one missing instrument is named once, not twice'
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
            $res.Output | Should -Match 'dashboard append from any lane of the machine: unknown \(not measured this sweep\)'
            $res.Output | Should -Match 'same threshold 1800 s; both liveness halves must be silent'
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

    Context 'Dashboard-append liveness half - the reader' {
        BeforeAll {
            $env:CLASSIFIER_LIB_ONLY = '1'
            try { . $script:ClassifierPath } finally { Remove-Item Env:CLASSIFIER_LIB_ONLY -ErrorAction SilentlyContinue }
        }

        It 'takes the newest REAL lane header per machine and skips the synthetic authors' {
            # Author ids in the wild are not canonical (measured on the shared
            # dashboards, 25/10): `po-2026`/`po-2025` legacy short ids, `MYIA-PO-2025`
            # in upper case, `myia-po-2025-win32-x64` platform-suffixed. And the two
            # synthetic writers would break the rule in opposite directions: the
            # condenser touches every dashboard, and this classifier's own alert lands
            # as `<target>|listener` through the RSM CLI - ignore both, or a wedge
            # corroborates itself on the next sweep.
            $shared = Join-Path $script:Tmp ("shared-" + [guid]::NewGuid().ToString('N').Substring(0, 6))
            $dir = Join-Path $shared 'dashboards'
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
            $now = [DateTimeOffset]::Parse('2026-10-25T12:00:00Z').UtcDateTime
            $body = [string]::Join("`r`n", @(
                '### [2026-10-25T11:58:00.000Z] myia-po-2028|roo-extensions'
                '[msg: a]'
                ''
                '### [2026-10-25T11:00:00.000Z] myia-po-2028|listener'
                '[msg: b]'
                ''
                '### [2026-10-25T11:59:30.000Z] system|system'
                '[msg: c]'
                ''
                '### [2026-10-25T11:30:00.000Z] po-2026|Maintenance'
                '[msg: d]'
                ''
                '### [2026-10-25T11:45:00.000Z] MYIA-PO-2025|roo-extensions'
                '[msg: e]'
            ))
            [System.IO.File]::WriteAllText((Join-Path $dir 'workspace-roo-extensions.md'), $body)
            $other = [string]::Join("`r`n", @(
                '### [2026-10-25T11:10:00.000Z] myia-po-2025-win32-x64|CoursIA'
                '[msg: f]'
            ))
            [System.IO.File]::WriteAllText((Join-Path $dir 'workspace-CoursIA.md'), $other)

            $roster = @('myia-po-2025', 'myia-po-2026', 'myia-po-2028', 'myia-ai-01')
            $state = Get-DashboardAppendAges -SharedPath $shared -Machines $roster -Now $now

            $state.available | Should -BeTrue
            $state.filesRead | Should -Be 2
            $state.agesByMachine['myia-po-2028'] | Should -Be 120 -Because 'the listener message (1 h) and the condenser (30 s) must not count'
            $state.agesByMachine['myia-po-2026'] | Should -Be 1800 -Because 'the legacy short author id belongs to myia-po-2026'
            $state.agesByMachine['myia-po-2025'] | Should -Be 900 -Because 'the newest of the upper-case and platform-suffixed ids wins'
            $state.agesByMachine.ContainsKey('myia-ai-01') | Should -BeFalse -Because 'no header at all is unknown, not zero'
        }

        It 'reports the scan as unavailable when there is no dashboards directory' {
            $shared = Join-Path $script:Tmp ("empty-" + [guid]::NewGuid().ToString('N').Substring(0, 6))
            New-Item -ItemType Directory -Path $shared -Force | Out-Null
            $state = Get-DashboardAppendAges -SharedPath $shared -Machines @('myia-po-2028')
            $state.available | Should -BeFalse
            $state.agesByMachine.Count | Should -Be 0
        }
    }

    Context 'Scheduled fire (RX122) - one alert per incident' {
        It 'derives the SAME incident id across two fires on the same boot, and a NEW id for a new boot' {
            # The 5-minute cadence must not repost: two fires that read the same
            # last boot are the SAME incident. Executed end to end (subprocess,
            # replay mode): the id is read back from the JSON payload, and the
            # content line that carries it is checked to match - that line is
            # what the primary-post guard reads back from the dashboard file.
            $fixture = Join-Path $script:FixtureDir 'po2028-20261023.json'
            $fireA = (Invoke-Classifier -Arguments @('-ReplayFile', $fixture, '-Json', '-NoAlert')).Output | ConvertFrom-Json
            $fireB = (Invoke-Classifier -Arguments @('-ReplayFile', $fixture, '-Json', '-NoAlert')).Output | ConvertFrom-Json

            $fireA.alerts.Count | Should -BeGreaterThan 0
            $idA1 = $fireA.alerts[0].messageId
            $idA2 = $fireB.alerts[0].messageId
            $idA1 | Should -Be 'classifier-4327-myia-po-2028-unusable-20261023T0745-20261023T0748' -Because 'machine + verdict + last boot + the measured burst minute'
            $idA1 | Should -Be $idA2 -Because 'two fires on the same incident are the same incident'
            # The pattern goes through a VARIABLE: `[regex]::Escape($x)` in pipeline
            # argument position is mis-parsed by 5.1 (the call splits into the method
            # name as a string plus a stray positional argument - measured, Pester
            # then received the literal text '[regex]::Escape' as the pattern).
            $idPattern = [regex]::Escape($idA1)
            $fireA.alerts[0].content | Should -Match $idPattern -Because 'the id travels in the content: the primary-post guard reads it back from the file'

            # A new boot is a NEW incident: same machine, later boot, later burst.
            $boot = '2026-10-23T08:30:00Z'
            $events = @([PSCustomObject]@{ utc = $boot; id = 12; message = 'OS start' }) +
                @(1..6 | ForEach-Object {
                    [PSCustomObject]@{ utc = '2026-10-23T08:34:00Z'; id = 7031; message = "Le service Service utilisateur de notifications Push Windows_ab668 s'est termine de maniere inattendue." }
                })
            $payload = [PSCustomObject]@{
                lastBootUtc = $boot
                events = $events
                samples = @([PSCustomObject]@{
                    atUtc = '2026-10-23T08:40:00Z'; machine = 'myia-po-2028'; openPorts = @(5985, 22, 445)
                    drivingChannelAnswered = $true; drivingStatusCode = 401; drivingLatencyMs = 4
                    latencySamplesMs = @(391, 412, 445); heartbeatAgeSeconds = 90
                })
            }
            $path = Write-ReplayFile -Name 'new-boot.json' -Payload $payload
            $fireC = (Invoke-Classifier -Arguments @('-ReplayFile', $path, '-Json', '-NoAlert')).Output | ConvertFrom-Json
            $idC = $fireC.alerts[0].messageId
            $idC | Should -Be 'classifier-4327-myia-po-2028-unusable-20261023T0830-20261023T0834'
            $idC | Should -Not -Be $idA1 -Because 'a new boot (and a new burst) is a new incident: the next wedge gets a fresh alert'
        }

        It 'exits 3 on a MISSING credential file, loudly, before any probe' {
            $missing = Join-Path $script:Tmp 'no-such-cred.xml'
            $fixture = Join-Path $script:FixtureDir 'po2028-20261023.json'
            $res = Invoke-Classifier -Arguments @('-ReplayFile', $fixture, '-CredentialFile', $missing, '-NoAlert', '-Json')
            $res.ExitCode | Should -Be 3 -Because 'a classifier told to run with a credential it cannot load must not fall back to running without one'
            $res.Output | Should -Match 'CredentialFile not found'
        }

        It 'exits 3 on a credential file that is not a PSCredential' {
            $bad = Join-Path $script:Tmp 'not-a-credential.xml'
            'just a string' | Export-Clixml -Path $bad
            $fixture = Join-Path $script:FixtureDir 'po2028-20261023.json'
            $res = Invoke-Classifier -Arguments @('-ReplayFile', $fixture, '-CredentialFile', $bad, '-NoAlert', '-Json')
            $res.ExitCode | Should -Be 3
            $res.Output | Should -Match 'does not contain a PSCredential'
        }
    }

    Context 'RX122 review - etat local d incident, un post par incident, cross-post toujours' {
        # Ces tests n observent pas la FORME du code : ils appellent la voie
        # d alerte reelle avec un CLI RSM factice (le meme procede que
        # embeddings-alert.Tests.ps1) et regardent ce qui PART.
        BeforeAll {
            $env:CLASSIFIER_LIB_ONLY = '1'
            try { . $script:ClassifierPath } finally { Remove-Item Env:CLASSIFIER_LIB_ONLY -ErrorAction SilentlyContinue }

            # --- CLI RSM factice ------------------------------------------------
            # Get-RsmScriptsDir resout le repertoire du CLI par $env:RSM_SERVER_ROOT
            # puis y cherche "scripts\rsm-dashboard-append.mjs". Sous pwsh/linux le
            # backslash n est PAS un separateur : le fichier doit alors porter
            # LUI-MEME un backslash dans son nom (exactement le chemin que voit la
            # fonction). Les deux formes sont donc ecrites.
            $script:IsWin = ([System.Environment]::OSVersion.Platform -eq [System.PlatformID]::Win32NT)
            $script:FakeRsmRoot = Join-Path $script:Tmp 'fake-rsm'
            $script:FakeCliDir = Join-Path $script:FakeRsmRoot 'scripts'
            New-Item -ItemType Directory -Path $script:FakeCliDir -Force | Out-Null
            $script:CliLog = Join-Path $script:Tmp 'cli-argv.log'
            $env:CLASSIFIER_TEST_CLI_LOG = $script:CliLog
            $cliBody = @(
                'import { appendFileSync, existsSync, writeFileSync } from "fs";',
                'const argv = process.argv.slice(2);',
                'appendFileSync(process.env.CLASSIFIER_TEST_CLI_LOG, JSON.stringify(argv) + "\n");',
                'const once = process.env.CLASSIFIER_TEST_FAIL_ONCE_FILE;',
                'if (once && argv.indexOf("workspace:Maintenance") >= 0 && !existsSync(once)) {',
                '  writeFileSync(once, "failed-once");',
                '  process.exit(1);',
                '}',
                'process.stdout.write(JSON.stringify({ ok: true, key: "machine-fake", messageId: "stub", pgSynced: false }));'
            ) -join "`n"
            [System.IO.File]::WriteAllText((Join-Path $script:FakeCliDir 'rsm-dashboard-append.mjs'), $cliBody, (New-Object System.Text.UTF8Encoding($false)))
            if (-not $script:IsWin) {
                [System.IO.File]::WriteAllText((Join-Path $script:FakeRsmRoot 'scripts\rsm-dashboard-append.mjs'), $cliBody, (New-Object System.Text.UTF8Encoding($false)))
            }
            $env:RSM_SERVER_ROOT = $script:FakeRsmRoot

            # Repertoire partage factice : le repli fichier de l alerte ecrit
            # dedans, jamais sur un vrai dashboard.
            $script:FakeShared = Join-Path $script:Tmp 'fake-shared'
            New-Item -ItemType Directory -Path (Join-Path $script:FakeShared 'dashboards') -Force | Out-Null

            $script:RepoRoot = (Resolve-Path "$PSScriptRoot\..\..\..").Path
            $script:PrevShared = $env:ROOSYNC_SHARED_PATH
            $script:PrevRsmRoot = $env:RSM_SERVER_ROOT
            $script:PrevStateDir = $env:CLASSIFIER_STATE_DIR
            $env:ROOSYNC_SHARED_PATH = $script:FakeShared

            # Trace des appels au CLI : le post primaire (--machine) et le
            # cross-post (--dashboard workspace:Maintenance) sont distingues.
            function Get-CliTrace {
                $primary = @()
                $cross = @()
                if (Test-Path -LiteralPath $script:CliLog) {
                    foreach ($line in @(Get-Content -LiteralPath $script:CliLog)) {
                        if ([string]::IsNullOrWhiteSpace($line)) { continue }
                        $argv = @()
                        # PS 5.1 ne dereference pas un tableau JSON de premier
                        # niveau a l affectation : on enumere explicitement.
                        foreach ($a in (ConvertFrom-Json $line)) { $argv += $a }
                        if ($argv -contains '--machine') { $primary += ,$argv }
                        elseif ($argv -contains '--dashboard') { $cross += ,$argv }
                    }
                }
                return [PSCustomObject]@{ Primary = $primary; Cross = $cross }
            }
        }

        AfterAll {
            if ($null -eq $script:PrevShared) { Remove-Item Env:ROOSYNC_SHARED_PATH -ErrorAction SilentlyContinue } else { $env:ROOSYNC_SHARED_PATH = $script:PrevShared }
            if ($null -eq $script:PrevRsmRoot) { Remove-Item Env:RSM_SERVER_ROOT -ErrorAction SilentlyContinue } else { $env:RSM_SERVER_ROOT = $script:PrevRsmRoot }
            if ($null -eq $script:PrevStateDir) { Remove-Item Env:CLASSIFIER_STATE_DIR -ErrorAction SilentlyContinue } else { $env:CLASSIFIER_STATE_DIR = $script:PrevStateDir }
            Remove-Item Env:CLASSIFIER_TEST_CLI_LOG -ErrorAction SilentlyContinue
            Remove-Item Env:CLASSIFIER_TEST_FAIL_ONCE_FILE -ErrorAction SilentlyContinue
        }

        BeforeEach {
            if (Test-Path -LiteralPath $script:CliLog) { Remove-Item -LiteralPath $script:CliLog -Force }
            Remove-Item Env:CLASSIFIER_TEST_FAIL_ONCE_FILE -ErrorAction SilentlyContinue
            $script:StateDir = Join-Path $script:Tmp ('state-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
            New-Item -ItemType Directory -Path $script:StateDir -Force | Out-Null
            $env:CLASSIFIER_STATE_DIR = $script:StateDir
        }

        It 'ne poste qu UN primary sur deux tirs du meme incident, et cross-poste sur les DEUX' {
            $id = 'classifier-4327-myia-po-2028-unusable-20261023T0745-20261023T0748'
            $content = '[FLEET-ALERT] [CRITICAL] myia-po-2028 - reachable-but-unusable'
            $null = Write-MachineDashboardAlert -TargetMachine 'myia-po-2028' -Content $content -MessageId $id
            $null = Write-MachineDashboardAlert -TargetMachine 'myia-po-2028' -Content $content -MessageId $id

            $trace = Get-CliTrace
            $trace.Primary.Count | Should -Be 1 -Because 'un incident = un seul post sur le dashboard de la machine'
            $trace.Cross.Count | Should -Be 2 -Because 'le cross-post part a CHAQUE tir, il est dedupe par le CLI sur --message-id'

            $crossIds = @()
            foreach ($argv in $trace.Cross) {
                $i = [array]::IndexOf($argv, '--message-id')
                $crossIds += $argv[$i + 1]
            }
            $crossIds[0] | Should -Be "$id-maint"
            $crossIds[1] | Should -Be "$id-maint" -Because 'le meme id porte les deux tentatives : la ligne existe une fois sur le dashboard'

            $statePath = Join-Path $script:StateDir 'classifier-incidents.json'
            Test-Path -LiteralPath $statePath | Should -BeTrue -Because 'l incident annonce est memorise localement'
            (Get-Content -LiteralPath $statePath -Raw) | Should -Match ([regex]::Escape($id))
        }

        It 'repose apres un verdict healthy, et repose sur un NOUVEAU burst (nouvel id)' {
            $id1 = 'classifier-4327-myia-po-2028-unusable-20261023T0745-20261023T0748'
            $id2 = 'classifier-4327-myia-po-2028-unusable-20261023T0745-20261023T0955'
            $null = Write-MachineDashboardAlert -TargetMachine 'myia-po-2028' -Content 'c1' -MessageId $id1
            (Get-CliTrace).Primary.Count | Should -Be 1

            # Le verdict redevient healthy : l entree d incident est droppee
            # (l etat dit "cet incident a ete annonce", pas "l historique de la flotte").
            Update-ClassifierHealthyState -Results @([PSCustomObject]@{ machine = 'myia-po-2028'; verdict = 'healthy' })
            $statePath = Join-Path $script:StateDir 'classifier-incidents.json'
            (Get-Content -LiteralPath $statePath -Raw) | Should -Not -Match ([regex]::Escape($id1))

            # MEME incident : il doit repartir, l etat ne dit plus rien.
            $null = Write-MachineDashboardAlert -TargetMachine 'myia-po-2028' -Content 'c1b' -MessageId $id1
            (Get-CliTrace).Primary.Count | Should -Be 2 -Because 'un wedge apres un retour a la sante est un incident a reannoncer'

            # Nouvel incident (nouveau burst) : un post de plus.
            $null = Write-MachineDashboardAlert -TargetMachine 'myia-po-2028' -Content 'c2' -MessageId $id2
            (Get-CliTrace).Primary.Count | Should -Be 3 -Because 'un nouveau burst sur le meme boot est un nouvel incident'
        }

        It 'retente un cross-post qui a echoue (le meme id -maint repart au tir suivant)' {
            $env:CLASSIFIER_TEST_FAIL_ONCE_FILE = Join-Path $script:Tmp 'cross-failed-once.marker'
            $id = 'classifier-4327-myia-po-2028-unusable-20261023T0745-20261023T0748'
            $first = Write-MachineDashboardAlert -TargetMachine 'myia-po-2028' -Content 'c' -MessageId $id
            $second = Write-MachineDashboardAlert -TargetMachine 'myia-po-2028' -Content 'c' -MessageId $id

            ($first -join "`n") | Should -Match 'Cross-post to workspace:Maintenance not written'
            ($second -join "`n") | Should -Match 'Cross-posted to workspace:Maintenance'

            $trace = Get-CliTrace
            $trace.Cross.Count | Should -Be 2 -Because 'un cross-post rate est RETENTE au tir suivant : le skip l aurait perdu pour tout le wedge'
            $trace.Primary.Count | Should -Be 1 -Because 'le cross-post ne touche pas au dedup du primary'
        }

        It 'poste malgre un etat d incident CORROMPU (jamais silencieux)' {
            $statePath = Join-Path $script:StateDir 'classifier-incidents.json'
            [System.IO.File]::WriteAllText($statePath, '{ ceci n est pas du json', (New-Object System.Text.UTF8Encoding($false)))
            $out = Write-MachineDashboardAlert -TargetMachine 'myia-po-2028' -Content 'c' -MessageId 'classifier-4327-myia-po-2028-unusable-1'

            ($out -join "`n") | Should -Match 'posting anyway' -Because 'un etat illisible est un fait sur l INSTRUMENT, pas sur la flotte'
            (Get-CliTrace).Primary.Count | Should -Be 1 -Because 'le silence serait le pire des deux echecs'
        }

        It 'ne leve pas quand l ecriture de l etat echoue (le post reste, l etat est perdu)' {
            # Le "repertoire" d etat est un FICHIEL : l ecriture atomique echoue.
            $notADir = Join-Path $script:Tmp 'state-is-a-file'
            [System.IO.File]::WriteAllText($notADir, 'x', (New-Object System.Text.UTF8Encoding($false)))
            $env:CLASSIFIER_STATE_DIR = $notADir
            $id = 'classifier-4327-myia-po-2028-unusable-20261023T0745'

            $script:AlertOut = $null
            { $script:AlertOut = Write-MachineDashboardAlert -TargetMachine 'myia-po-2028' -Content 'c' -MessageId $id } |
                Should -Not -Throw
            ($script:AlertOut -join "`n") | Should -Match 'state not saved' -Because 'l incident est perdu, pas le post'
            (Get-CliTrace).Primary.Count | Should -Be 1 -Because 'le post part meme si l etat ne peut pas etre ecrit'
        }

        It 'refuse d installer quand le lanceur est resolu sous .claude\worktrees' {
            # Le chemin du lanceur est derive de l emplacement DU SCRIPT : on copie
            # l installeur dans une arborescence de worktree pour exercer le garde
            # partout (le checkout principal n en est pas un).
            $wtScripts = Join-Path $script:Tmp 'wtprobe\.claude\worktrees\wt-fake\scripts\scheduling'
            New-Item -ItemType Directory -Path $wtScripts -Force | Out-Null
            $installer = Join-Path $wtScripts 'install-usability-classifier-task.ps1'
            Copy-Item -LiteralPath (Join-Path $script:RepoRoot 'scripts\scheduling\install-usability-classifier-task.ps1') -Destination $installer -Force

            $out = & $script:PsExe @script:PsBase -File $installer -DryRun 2>&1
            $code = $LASTEXITCODE
            $text = ($out -join "`n")

            $code | Should -Be 1 -Because 'un VBS pointant dans un worktree effaceable est pire que pas de tache du tout'
            $text | Should -Match 'REFUS'
            $text | Should -Match 'worktree'
            $text | Should -Match 'Relancer l''installation depuis le checkout principal' -Because 'un refus qui ne dit pas ou installer est un refus a moitié fait'
        }

        It 'refuse aussi depuis le checkout courant quand il EST lui-meme un worktree' {
            if ($script:RepoRoot -notmatch '[\\/]\.claude[\\/]worktrees[\\/]') {
                Set-ItResult -Skipped -Because 'le checkout courant n est pas un worktree : le garde est exerce par le cas copie'
                return
            }
            $installer = Join-Path $script:RepoRoot 'scripts\scheduling\install-usability-classifier-task.ps1'
            $out = & $script:PsExe @script:PsBase -File $installer -DryRun 2>&1
            $code = $LASTEXITCODE
            $text = ($out -join "`n")

            $code | Should -Be 1
            $text | Should -Match 'REFUS: le lanceur resolu vit dans un worktree git'
        }
    }
}
