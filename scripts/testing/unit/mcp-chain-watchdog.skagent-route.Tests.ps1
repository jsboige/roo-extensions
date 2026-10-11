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
                [string]$Mode = 'poll',
                [datetime]$LastRouteRepairAt = [datetime]::MinValue,
                [double[]]$RunSecondsLeft = @(250),
                [int]$VerifyCapSec = -1,
                [string[]]$PriorRepairs = @(),
                [string]$RouteUrl = $script:paramDefaults['SkAgentRouteUrl'],
                [string]$BackendUrl = $script:paramDefaults['SkAgentBackendUrl'],
                [string]$StateFile = (Join-Path $TestDrive 'route-repair-state.json')
            )
            $state = [pscustomobject]@{
                RouteProbes = 0; BackendProbes = 0; RouteBearer = $null; BackendBearer = '<never probed>'
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

    Context 'no restart' {

        It 'route 404 but sk-agent does not answer on :8100 -> alert, no restart' {
            $r = Invoke-Check -RouteAnswers @(404) -BackendAnswer 0

            $r.Verdict      | Should -Be 'backend-down'
            $r.Docker.Count | Should -BeExactly 0 -Because 'a restarted TBXark would skip the closed backend again'
            $r.StateWritten | Should -BeFalse
            $r.Alerts       | Should -Contain 'skagent-route-missing-backend-down: sk-agent itself does not answer, TBXark not restarted'
            ($r.Logs -join "`n") | Should -Match '^WARN '
        }

        It 'route OK -> no backend probe, no action, no log line' {
            $r = Invoke-Check -RouteAnswers @(200)

            $r.Verdict       | Should -Be 'ok'
            $r.BackendProbes | Should -BeExactly 0
            $r.Docker.Count  | Should -BeExactly 0
            $r.Alerts.Count  | Should -BeExactly 0
            $r.Logs.Count    | Should -BeExactly 0 -Because 'a healthy tick stays at one log line'
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
    }
}
