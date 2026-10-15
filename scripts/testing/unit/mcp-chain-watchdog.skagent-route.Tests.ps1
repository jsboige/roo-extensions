<#
.SYNOPSIS
    Behavioural test: the watchdog repairs a missing sk-agent route (TBXark boot race,
    11/10) with a TBXark-only restart, only when sk-agent itself answers.

.DESCRIPTION
    TBXark (compose project 'docker') and sk-agent (compose project 'sk-agent', :8100)
    are two compose projects, so nothing orders them at boot. On 11/10 TBXark came up
    first, skipped the sk-agent backend and never retried: /sk-agent/mcp answered 404
    for good while sk-agent was healthy, and the NanoClaw bot crash-looped ~11 h. The
    watchdog's probes only exercised the RSM route, and the RSM chain was healthy.

    Invoke-SkAgentRouteCheck and Get-McpInitializeStatus are EXTRACTED from the script
    under test (a copy pasted here could diverge) and driven against scripted
    collaborators:

      - Get-McpInitializeStatus -> scripted HTTP status per URL (route list consumed
                                   one per probe, last entry repeats)
      - Get-RunSecondsLeft      -> scripted run budget, one entry per call
      - docker                  -> records the command line, restarts nothing
      - Start-Sleep, Write-Log  -> record, wait nothing, write nothing

    The state file is a real file under TestDrive, read back with the script's own
    main-flow line, so the shared cooldown is exercised end to end.

.NOTES
    Requires Pester 5+. Runs under Windows PowerShell 5.1 and pwsh 7.
#>

Describe 'mcp-chain-watchdog sk-agent route repair (3d, boot race 11/10)' {

    BeforeAll {
        $scriptPath = Join-Path $PSScriptRoot '..\..\..\scripts\mcp-watchdog\mcp-chain-watchdog.ps1'
        $script:content = Get-Content $scriptPath -Raw

        function Get-FunctionSource {
            param([string]$Name)
            $m = [regex]::Match($script:content, "(?s)function $Name \{.*?\n\}")
            if (-not $m.Success) { throw "$Name not found in mcp-chain-watchdog.ps1" }
            $m.Value
        }
        $script:checkSource  = Get-FunctionSource 'Invoke-SkAgentRouteCheck'
        $script:statusSource = Get-FunctionSource 'Get-McpInitializeStatus'
        $script:realCallSource = Get-FunctionSource 'Invoke-SkAgentRouteRealCall'

        function Get-DeclaredConst {
            param([string]$Name)
            $m = [regex]::Match($script:content, "\`$$Name = (\d+)")
            if (-not $m.Success) { throw "`$$Name not found in mcp-chain-watchdog.ps1" }
            [int]$m.Groups[1].Value
        }
        $script:declaredRouteCooldownMin   = Get-DeclaredConst 'RouteRepairCooldownMin'
        $script:declaredRouteWorstCaseSec  = Get-DeclaredConst 'RouteRepairWorstCaseSec'
        $script:declaredProbeSec           = Get-DeclaredConst 'SkAgentProbeTimeoutSec'
        $script:declaredVerifyCapSec       = Get-DeclaredConst 'SkAgentVerifyCapSec'
        $script:declaredVerifyIntervalSec  = Get-DeclaredConst 'SkAgentVerifyIntervalSec'
        $script:declaredRealCallThreshold  = Get-DeclaredConst 'SkAgentRealCallFailThreshold'
        $script:declaredOkLogPeriodMin     = Get-DeclaredConst 'SkAgentOkLogPeriodMin'

        # The main-flow line that reads the shared cooldown, verbatim.
        $m = [regex]::Match($script:content, '(?m)^[ \t]*try \{ \$lastRouteRepairAt = [^\r\n]+')
        if (-not $m.Success) { throw 'route-repair-state read line not found in mcp-chain-watchdog.ps1' }
        $script:stateReadSource = $m.Value

        # Default parameter values, read from the param() block AST.
        $ast = [System.Management.Automation.Language.Parser]::ParseInput($script:content, [ref]$null, [ref]$null)
        $script:ast = $ast
        $script:paramDefaults = @{}
        foreach ($p in $ast.ParamBlock.Parameters) {
            if ($p.DefaultValue) { $script:paramDefaults[$p.Name.VariablePath.UserPath] = $p.DefaultValue.SafeGetValue() }
        }

        # Drives the extracted check. Returns its verdict plus what the scripted
        # collaborators observed. The stubs resolve their inputs dynamically, so
        # no parameter here may share a name with a local of the function under
        # test (case-insensitive: a $RouteStatus here is shadowed by its
        # $routeStatus, and the stub then replays the first answer forever).
        function Invoke-Check {
            param(
                [int[]]$RouteAnswers = @(200),
                [int]$BackendAnswer = 401,
                [object[]]$RealCall = @(@{ Ok = $true; InitStatus = 200; CallStatus = 200; Detail = 'healthy' }),
                [int]$RealCallFailures = 0,
                [datetime]$RealCallLastOkLogAt = [datetime]::MinValue,
                [string]$Mode = 'poll',
                [datetime]$LastRouteRepairAt = [datetime]::MinValue,
                [double[]]$RunSecondsLeft = @(250),
                [int]$VerifyCapSec = -1,
                [string[]]$PriorRepairs = @(),
                [string]$RouteUrl = $script:paramDefaults['SkAgentRouteUrl'],
                [string]$BackendUrl = $script:paramDefaults['SkAgentBackendUrl'],
                [string]$StateFile = (Join-Path $TestDrive 'route-repair-state.json'),
                [string]$RealCallStateFile = (Join-Path $TestDrive 'skagent-realcall-state.json')
            )
            $state = [pscustomobject]@{
                RouteProbes = 0; BackendProbes = 0; RouteBearer = $null; BackendBearer = '<never probed>'
                RealCalls = 0; RealCallBearer = $null
                Docker = @(); SleptSec = 0; Logs = @(); BudgetCalls = 0
            }
            $script:repairs = @($PriorRepairs)
            $script:alerts = @()
            $script:deferredVerifications = @()

            # Script-scope inputs of the function, resolved from this scope.
            $SkAgentRouteUrl          = $RouteUrl
            $SkAgentBackendUrl        = $BackendUrl
            $bearer                   = 'test-bearer-value'
            $lastRouteRepairAt        = $LastRouteRepairAt
            $routeRepairStateFile     = $StateFile
            $RouteRepairCooldownMin   = $script:declaredRouteCooldownMin
            $RouteRepairWorstCaseSec  = $script:declaredRouteWorstCaseSec
            $SkAgentProbeTimeoutSec   = $script:declaredProbeSec
            $SkAgentVerifyCapSec      = if ($VerifyCapSec -lt 0) { $script:declaredVerifyCapSec } else { $VerifyCapSec }
            $SkAgentVerifyIntervalSec = $script:declaredVerifyIntervalSec
            $SkAgentRealCallFailThreshold = $script:declaredRealCallThreshold
            $SkAgentOkLogPeriodMin    = $script:declaredOkLogPeriodMin
            $skAgentRealCallFailures    = $RealCallFailures
            $skAgentRealCallLastOkLogAt = $RealCallLastOkLogAt
            $skAgentRealCallStateFile   = $RealCallStateFile

            function Write-Log { param($Level, $Message) $state.Logs += "$Level $Message" }
            function Start-Sleep { param([int]$Seconds) $state.SleptSec += $Seconds }
            function docker { $state.Docker += ($args -join ' ') }
            function Get-RunSecondsLeft {
                $i = [Math]::Min($state.BudgetCalls, $RunSecondsLeft.Count - 1); $state.BudgetCalls += 1
                $RunSecondsLeft[$i]
            }
            function Get-McpInitializeStatus {
                param([string]$Url, [string]$Bearer, [int]$TimeoutSec)
                if ($Url -eq $SkAgentRouteUrl) {
                    $i = [Math]::Min($state.RouteProbes, $RouteAnswers.Count - 1); $state.RouteProbes += 1
                    $state.RouteBearer = $Bearer
                    return $RouteAnswers[$i]
                }
                if ($Url -eq $SkAgentBackendUrl) {
                    $state.BackendProbes += 1; $state.BackendBearer = $Bearer
                    return $BackendAnswer
                }
                throw "unexpected probe URL $Url"
            }
            function Invoke-SkAgentRouteRealCall {
                param([string]$Url, [string]$Bearer, [int]$TimeoutSec)
                $i = [Math]::Min($state.RealCalls, $RealCall.Count - 1); $state.RealCalls += 1
                $state.RealCallBearer = $Bearer
                $RealCall[$i]
            }

            # Dot-sourced so the function lands in THIS scope, where the stubs above
            # shadow the real collaborators.
            . ([scriptblock]::Create($script:checkSource))
            $verdict = Invoke-SkAgentRouteCheck

            [pscustomobject]@{
                Verdict       = $verdict
                RouteProbes   = $state.RouteProbes
                BackendProbes = $state.BackendProbes
                RouteBearer   = $state.RouteBearer
                BackendBearer = $state.BackendBearer
                RealCalls     = $state.RealCalls
                RealCallBearer = $state.RealCallBearer
                RealCallState = $(if (Test-Path $RealCallStateFile) { Get-Content $RealCallStateFile -Raw | ConvertFrom-Json } else { $null })
                Docker        = @($state.Docker)
                SleptSec      = $state.SleptSec
                Logs          = @($state.Logs)
                Repairs       = @($script:repairs)
                Alerts        = @($script:alerts)
                Deferred      = @($script:deferredVerifications)
                StateWritten  = (Test-Path $StateFile)
            }
        }
    }

    BeforeEach {
        Remove-Item (Join-Path $TestDrive 'route-repair-state.json') -ErrorAction SilentlyContinue
        Remove-Item (Join-Path $TestDrive 'skagent-realcall-state.json') -ErrorAction SilentlyContinue
    }

    Context 'the 11/10 case: route 404, sk-agent answers on :8100' {

        It 'restarts TBXark once, records a distinct repair, arms the shared cooldown, confirms the route' {
            # 404 at the first probe, 0 while TBXark restarts, then registered.
            $r = Invoke-Check -RouteAnswers @(404, 0, 200) -BackendAnswer 401

            $r.Verdict      | Should -Be 'recovered'
            $r.Docker.Count | Should -BeExactly 1
            $r.Docker[0]    | Should -Be 'restart myia-mcp-proxy' -Because 'TBXark only, never sparfenyuk or sk-agent'
            $r.Repairs      | Should -Contain 'tbxark-restart(skagent-route-missing)'
            $r.StateWritten | Should -BeTrue -Because 'the restart arms the cooldown 3b shares'
            $r.Alerts.Count | Should -BeExactly 0
            $r.RouteProbes  | Should -BeExactly 3 -Because 'a 0 or a 404 right after the restart is TBXark still starting'
        }

        It 'dry-run restarts nothing and writes nothing' {
            $r = Invoke-Check -RouteAnswers @(404) -BackendAnswer 401 -Mode 'dry-run'

            $r.Verdict       | Should -Be 'dry-run'
            $r.Docker.Count  | Should -BeExactly 0
            $r.Repairs.Count | Should -BeExactly 0
            $r.StateWritten  | Should -BeFalse
            ($r.Logs -join "`n") | Should -Match 'DRY-RUN: would docker restart myia-mcp-proxy'
        }

        It 'an open seat answering 200 on :8100 counts as up too' {
            $r = Invoke-Check -RouteAnswers @(404, 200) -BackendAnswer 200

            $r.Verdict      | Should -Be 'recovered'
            $r.Docker.Count | Should -BeExactly 1
        }
    }

    Context 'the 11-12/10 case: initialize 200, tools/call fails (#4197)' {

        It 'below the threshold: no restart, the failure is counted and persisted' {
            $r = Invoke-Check -RouteAnswers @(200) -RealCall @(@{ Ok = $false; InitStatus = 200; CallStatus = 400; Detail = 'tools/call failed: http-400 Missing session ID' })

            $r.Verdict      | Should -Be 'realcall-failing'
            $r.Docker.Count | Should -BeExactly 0
            $r.BackendProbes | Should -BeExactly 1
            ($r.Logs -join "`n") | Should -Match "failure 1/$($script:declaredRealCallThreshold)"
            $r.RealCallState.consecutiveFailures | Should -BeExactly 1
        }

        It 'third consecutive failure while sk-agent answers -> TBXark-only restart, verified on the REAL call' {
            # Failure 3/3 repairs; the verification loop needs the real call to
            # answer OK — an initialize-200 verify would confirm nothing (#4197).
            $r = Invoke-Check -RouteAnswers @(200) -RealCallFailures 2 -RealCall @(
                @{ Ok = $false; InitStatus = 200; CallStatus = 400; Detail = 'tools/call failed: http-400 Missing session ID' },
                @{ Ok = $true;  InitStatus = 200; CallStatus = 200; Detail = 'healthy' }
            )

            $r.Verdict      | Should -Be 'recovered'
            $r.Docker.Count | Should -BeExactly 1
            $r.Docker[0]    | Should -Be 'restart myia-mcp-proxy'
            $r.Repairs      | Should -Contain 'tbxark-restart(skagent-real-call-failing)'
            $r.StateWritten | Should -BeTrue -Because 'the restart arms the cooldown 3b shares'
            $r.RealCallState.consecutiveFailures | Should -BeExactly 0 -Because 'the repair consumed the count'
            $r.RealCalls    | Should -BeExactly 2 -Because 'probe tick + one verification call'
            $r.Alerts.Count | Should -BeExactly 0
        }

        It 'the counter survives ticks: the next tick reads what the first wrote' {
            $first = Invoke-Check -RouteAnswers @(200) -RealCall @(@{ Ok = $false; InitStatus = 200; CallStatus = 400; Detail = 'x' })
            $first.Verdict | Should -Be 'realcall-failing'

            # The script's own main-flow read of skagent-realcall-state.json.
            $skAgentRealCallStateFile = Join-Path $TestDrive 'skagent-realcall-state.json'
            $rcState = Get-Content $skAgentRealCallStateFile -Raw | ConvertFrom-Json
            $rcState.consecutiveFailures | Should -BeExactly 1

            $second = Invoke-Check -RouteAnswers @(200) -RealCallFailures ([int]$rcState.consecutiveFailures) -RealCall @(@{ Ok = $false; InitStatus = 200; CallStatus = 400; Detail = 'x' })
            $second.Verdict | Should -Be 'realcall-failing'
            $second.RealCallState.consecutiveFailures | Should -BeExactly 2
        }

        It 'real call fails but sk-agent does not answer on :8100 -> alert, no restart' {
            $r = Invoke-Check -RouteAnswers @(200) -BackendAnswer 0 -RealCallFailures 2 -RealCall @(@{ Ok = $false; InitStatus = 200; CallStatus = 0; Detail = 'tools/call failed: http-0' })

            $r.Verdict      | Should -Be 'backend-down'
            $r.Docker.Count | Should -BeExactly 0 -Because 'a restarted TBXark would skip the closed backend again'
            $r.Alerts       | Should -Contain 'skagent-realcall-failing-backend-down: sk-agent itself does not answer, TBXark not restarted'
            $r.RealCallState.consecutiveFailures | Should -BeExactly 3 -Because 'the failure is counted even when no repair can follow'
        }

        It 'the shared cooldown holds: TBXark restarted 3 min ago (by 3b or 3d) -> wait' {
            $r = Invoke-Check -RouteAnswers @(200) -RealCallFailures 2 -LastRouteRepairAt (Get-Date).AddMinutes(-3) -RealCall @(@{ Ok = $false; InitStatus = 200; CallStatus = 400; Detail = 'x' })

            $r.Verdict      | Should -Be 'cooldown'
            $r.Docker.Count | Should -BeExactly 0
            $r.Alerts       | Should -Contain 'skagent-realcall-failing-restart-on-cooldown'
        }

        It 'dry-run restarts nothing and writes neither state file' {
            $r = Invoke-Check -RouteAnswers @(200) -RealCallFailures 2 -Mode 'dry-run' -RealCall @(@{ Ok = $false; InitStatus = 200; CallStatus = 400; Detail = 'x' })

            $r.Verdict       | Should -Be 'dry-run'
            $r.Docker.Count  | Should -BeExactly 0
            $r.StateWritten  | Should -BeFalse
            ($r.Logs -join "`n") | Should -Match 'DRY-RUN: would docker restart myia-mcp-proxy'
            $r.RealCallState.consecutiveFailures | Should -BeExactly 3 -Because 'dry-run must not consume the count'
        }

        It 'a recovery resets the count: real call healthy after 2 failures -> state back to 0' {
            $r = Invoke-Check -RouteAnswers @(200) -RealCallFailures 2 -RealCall @(@{ Ok = $true; InitStatus = 200; CallStatus = 200; Detail = 'healthy' })

            $r.Verdict      | Should -Be 'ok'
            $r.Docker.Count | Should -BeExactly 0
            $r.RealCallState.consecutiveFailures | Should -BeExactly 0
        }

        It 'run budget ends before the real call answers -> deferred verification, no alert, cooldown armed' {
            # Entry guard 250, restart guard 250, then 15 s: no verification call fits.
            $r = Invoke-Check -RouteAnswers @(200) -RealCallFailures 2 -RunSecondsLeft @(250, 250, 15) -RealCall @(@{ Ok = $false; InitStatus = 200; CallStatus = 400; Detail = 'x' })

            $r.Verdict        | Should -Be 'unverified'
            $r.Docker.Count   | Should -BeExactly 1
            $r.StateWritten   | Should -BeTrue
            $r.Deferred.Count | Should -BeExactly 1
            $r.Alerts.Count   | Should -BeExactly 0
        }

        It 'real call still failing at the verification ceiling -> distinct alert' {
            $r = Invoke-Check -RouteAnswers @(200) -RealCallFailures 2 -VerifyCapSec 0 -RealCall @(@{ Ok = $false; InitStatus = 200; CallStatus = 400; Detail = 'x' })

            $r.Verdict      | Should -Be 'still-failing'
            $r.Docker.Count | Should -BeExactly 1
            $r.Alerts       | Should -Contain 'skagent-realcall-still-failing-after-tbxark-restart: init-200-call-400'
        }
    }

    Context 'no restart' {

        It 'route 404 but sk-agent does not answer on :8100 -> alert, no restart' {
            $r = Invoke-Check -RouteAnswers @(404) -BackendAnswer 0

            $r.Verdict      | Should -Be 'backend-down'
            $r.Docker.Count | Should -BeExactly 0 -Because 'a restarted TBXark would skip the closed backend again'
            $r.StateWritten | Should -BeFalse
            $r.Alerts       | Should -Contain 'skagent-route-missing-backend-down: sk-agent itself does not answer, TBXark not restarted'
            ($r.Logs -join "`n") | Should -Match '^WARN '
        }

        It 'route OK + real call healthy -> verdict ok, hourly OK log on the first tick, no backend probe' {
            $r = Invoke-Check -RouteAnswers @(200)

            $r.Verdict       | Should -Be 'ok'
            $r.RealCalls     | Should -BeExactly 1 -Because 'initialize 200 continues to the real tools/call (#4197)'
            $r.BackendProbes | Should -BeExactly 0
            $r.Docker.Count  | Should -BeExactly 0
            $r.Alerts.Count  | Should -BeExactly 0
            $r.Logs.Count    | Should -BeExactly 1
            $r.Logs[0]       | Should -Match '^OK .*real call healthy'
            $r.RealCallState.consecutiveFailures | Should -BeExactly 0
        }

        It 'route OK within the hourly log period -> no log line, no state write' {
            $r = Invoke-Check -RouteAnswers @(200) -RealCallLastOkLogAt (Get-Date).AddMinutes(-5)

            $r.Verdict       | Should -Be 'ok'
            $r.Logs.Count    | Should -BeExactly 0 -Because 'a healthy tick within the period stays silent'
            $r.RealCallState | Should -BeNullOrEmpty -Because 'nothing changed, nothing is written'
        }

        It 'route answers something other than 200 or 404 -> not a missing route, nothing repaired' {
            $r = Invoke-Check -RouteAnswers @(0)

            $r.Verdict       | Should -Be 'not-404'
            $r.BackendProbes | Should -BeExactly 0
            $r.Docker.Count  | Should -BeExactly 0
        }

        It 'the shared cooldown holds: a TBXark restart 3 min ago (by 3b or 3d) -> wait' {
            $r = Invoke-Check -RouteAnswers @(404) -BackendAnswer 401 -LastRouteRepairAt (Get-Date).AddMinutes(-3)

            $r.Verdict      | Should -Be 'cooldown'
            $r.Docker.Count | Should -BeExactly 0
            $r.Alerts       | Should -Contain 'skagent-route-missing-restart-on-cooldown'
        }

        It 'the next tick reads the state the repair wrote and stays on cooldown' {
            $first = Invoke-Check -RouteAnswers @(404, 200) -BackendAnswer 401
            $first.Docker.Count | Should -BeExactly 1

            # The script's own main-flow read of route-repair-state.json.
            $routeRepairStateFile = Join-Path $TestDrive 'route-repair-state.json'
            $lastRouteRepairAt = [datetime]::MinValue
            . ([scriptblock]::Create($script:stateReadSource))
            $lastRouteRepairAt | Should -BeGreaterThan (Get-Date).AddMinutes(-1)

            $second = Invoke-Check -RouteAnswers @(404) -BackendAnswer 401 -LastRouteRepairAt $lastRouteRepairAt
            $second.Verdict      | Should -Be 'cooldown'
            $second.Docker.Count | Should -BeExactly 0
        }

        It 'TBXark already restarted earlier in this run -> skipped, nothing probed' {
            $r = Invoke-Check -RouteAnswers @(404) -PriorRepairs @('sparfenyuk-restart(port-was-down)', 'tbxark-restart')

            $r.Verdict      | Should -Be 'skipped'
            $r.RouteProbes  | Should -BeExactly 0
            $r.Docker.Count | Should -BeExactly 0
        }

        It 'a restart that does not fit in the run budget is deferred' {
            # 250 s at the probe guard, then 20 s (< RouteRepairWorstCaseSec) at the restart guard.
            $r = Invoke-Check -RouteAnswers @(404) -BackendAnswer 401 -RunSecondsLeft @(250, 20)

            $r.Verdict      | Should -Be 'deferred'
            $r.Docker.Count | Should -BeExactly 0
            $r.Alerts       | Should -Contain 'skagent-route-missing-restart-deferred: not enough run time left'
        }

        It 'empty SkAgentRouteUrl or SkAgentBackendUrl disables the check' {
            (Invoke-Check -RouteAnswers @(404) -RouteUrl '').Verdict   | Should -Be 'disabled'
            (Invoke-Check -RouteAnswers @(404) -BackendUrl '').Verdict | Should -Be 'disabled'
        }
    }

    Context 'after the restart' {

        It 'route still 404 at the verification ceiling -> alert' {
            # Ceiling injected to 0: the branch compares the REAL stopwatch, which a
            # scripted clock cannot advance.
            $r = Invoke-Check -RouteAnswers @(404) -BackendAnswer 401 -VerifyCapSec 0

            $r.Verdict      | Should -Be 'still-missing'
            $r.Docker.Count | Should -BeExactly 1
            $r.Alerts       | Should -Contain 'skagent-route-still-missing-after-tbxark-restart: http-404'
        }

        It 'run budget ends before the route answers -> deferred verification, no alert, cooldown armed' {
            # Probe guard 250, restart guard 250, then 15 s: no verification probe fits.
            $r = Invoke-Check -RouteAnswers @(404) -BackendAnswer 401 -RunSecondsLeft @(250, 250, 15)

            $r.Verdict        | Should -Be 'unverified'
            $r.Docker.Count   | Should -BeExactly 1
            $r.StateWritten   | Should -BeTrue -Because 'the state is written before the wait'
            $r.Deferred.Count | Should -BeExactly 1
            $r.Alerts.Count   | Should -BeExactly 0 -Because 'a repair not yet confirmed is not a repair that failed'
        }
    }

    Context 'credentials' {

        It 'the TBXark bearer goes to the route probe only, never to sk-agent, never to the log' {
            $r = Invoke-Check -RouteAnswers @(404, 200) -BackendAnswer 401

            $r.RouteBearer   | Should -Be 'test-bearer-value'
            $r.BackendBearer | Should -BeNullOrEmpty -Because 'the TBXark token is not sk-agent''s'
            ($r.Logs -join "`n") | Should -Not -Match 'test-bearer-value'
        }

        It 'the real call carries the TBXark bearer (proxy token, not the container key)' {
            $r = Invoke-Check -RouteAnswers @(200)

            $r.RealCallBearer | Should -Be 'test-bearer-value'
            ($r.Logs -join "`n") | Should -Not -Match 'test-bearer-value'
        }
    }

    Context 'Get-McpInitializeStatus' {

        BeforeAll {
            function Invoke-Status {
                param($Behaviour)
                $script:lastHeaders = $null
                function Invoke-WebRequest {
                    param($Uri, $Method, $Headers, $Body, [switch]$UseBasicParsing, $TimeoutSec, $ErrorAction)
                    $script:lastHeaders = $Headers
                    & $Behaviour
                }
                . ([scriptblock]::Create($script:statusSource))
                Get-McpInitializeStatus -Url 'http://127.0.0.1:9/mcp' -Bearer $args[0] -TimeoutSec 1
            }
        }

        It 'returns 200 on success' {
            Invoke-Status { [pscustomobject]@{ StatusCode = 200 } } | Should -BeExactly 200
        }

        It 'returns the HTTP status of an error response (404)' {
            Invoke-Status {
                $ex = [System.Exception]::new('Not Found')
                Add-Member -InputObject $ex -NotePropertyName Response -NotePropertyValue ([pscustomobject]@{ StatusCode = 404 })
                throw $ex
            } | Should -BeExactly 404
        }

        It 'returns 0 when nothing answers' {
            Invoke-Status { throw [System.Net.WebException]::new('refused') } | Should -BeExactly 0
        }

        It 'sends Authorization only when a bearer is given' {
            $null = Invoke-Status { [pscustomobject]@{ StatusCode = 200 } }
            $script:lastHeaders.ContainsKey('Authorization') | Should -BeFalse
            $null = Invoke-Status { [pscustomobject]@{ StatusCode = 200 } } 'b'
            $script:lastHeaders['Authorization'] | Should -Be 'Bearer b'
        }
    }

    Context 'declared defaults and call-site wiring (static guards)' {

        It 'the route goes through TBXark :9090, the backend is sk-agent :8100' {
            $script:paramDefaults['SkAgentRouteUrl']   | Should -Be 'http://127.0.0.1:9090/sk-agent/mcp'
            $script:paramDefaults['SkAgentBackendUrl'] | Should -Be 'http://127.0.0.1:8100/mcp'
        }

        It 'is called once, at top level -- outside every RSM branch, so a healthy RSM chain still runs it' {
            $calls = @($script:ast.FindAll({ param($n)
                $n -is [System.Management.Automation.Language.CommandAst] -and $n.GetCommandName() -eq 'Invoke-SkAgentRouteCheck'
            }, $true))
            $calls.Count | Should -BeExactly 1
            $node = $calls[0].Parent
            while ($node) {
                $node | Should -Not -BeOfType ([System.Management.Automation.Language.IfStatementAst])
                $node | Should -Not -BeOfType ([System.Management.Automation.Language.FunctionDefinitionAst])
                $node = $node.Parent
            }
        }

        It 'runs after the RSM repair paths and before the summary that reports its repairs' {
            $iCall    = $script:content.IndexOf('$null = Invoke-SkAgentRouteCheck')
            $iFull    = $script:content.IndexOf('running full repair sequence')
            $iSummary = $script:content.IndexOf('# ---------- summary + event log ----------')
            $iCall | Should -BeGreaterThan $iFull
            $iCall | Should -BeLessThan $iSummary
        }

        It 'shares 3b''s cooldown and state file, and writes the state before the wait' {
            $script:checkSource | Should -Match '\$lastRouteRepairAt'
            $script:checkSource | Should -Match '-lt \$RouteRepairCooldownMin'
            $script:checkSource | Should -Match '\(Get-RunSecondsLeft\) -lt \$RouteRepairWorstCaseSec'
            $script:checkSource | Should -Match '(?s)&[ \t]+docker[ \t]+restart[ \t]+myia-mcp-proxy.*?Set-Content[^\r\n]*\$routeRepairStateFile.*?while \(\$true\)'
            $script:checkSource | Should -Not -Match 'Stop-ScheduledTask|Start-ScheduledTask|\$repairStateFile\b'
        }

        It 'the real-call probe is a top-level function the check calls, defined per the #4197 design' {
            $script:realCallSource | Should -Match 'notifications/initialized'
            $script:realCallSource | Should -Match 'tools/call'
            $script:realCallSource | Should -Match 'list_agents'
            $script:realCallSource | Should -Match "mcp-session-id"
            $def = $script:ast.FindAll({ param($n)
                $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq 'Invoke-SkAgentRouteRealCall'
            }, $true)
            @($def).Count | Should -BeExactly 1 -Because 'extracted source and AST must agree there is exactly one definition'
        }

        It 'the real-call repair is verified on the real call, never on initialize alone' {
            # tick probe + verify probe: the check source calls the real-call
            # probe at least twice, and the verify loop sits after its docker
            # restart, not after Get-McpInitializeStatus.
            ([regex]::Matches($script:checkSource, 'Invoke-SkAgentRouteRealCall')).Count | Should -BeGreaterOrEqual 2
            $iRestart = $script:checkSource.IndexOf('tbxark-restart(skagent-real-call-failing)')
            $iRestart | Should -BeGreaterThan 0
            $script:checkSource.Substring($iRestart) | Should -Match '(?s)while \(\$true\).*?Invoke-SkAgentRouteRealCall'
        }

        It 'the #4197 constants match the design: N=3 consecutive failures, ok logged once per hour' {
            $script:declaredRealCallThreshold | Should -BeExactly 3
            $script:declaredOkLogPeriodMin     | Should -BeExactly 60
            $script:checkSource | Should -Match '\$SkAgentRealCallFailThreshold'
            $script:checkSource | Should -Match '\$SkAgentOkLogPeriodMin'
        }

        It 'the real-call counter lives in its own state file, not in the shared cooldown file' {
            $script:content | Should -Match 'skagent-realcall-state\.json'
            $script:checkSource | Should -Match '\$skAgentRealCallStateFile'
            # The shared cooldown file is written exactly once per repair path
            # (404-missing and real-call-failing), always lastRouteRepairAt
            # only -- the counter must not leak into it.
            ([regex]::Matches($script:checkSource, 'Set-Content -Path \$routeRepairStateFile')).Count | Should -BeExactly 2
            ([regex]::Matches($script:checkSource, '& docker restart myia-mcp-proxy')).Count | Should -BeExactly 2
        }
    }
}
