<#
.SYNOPSIS
    #4897 (a)+(c): the sk-agent real-call failure window replaces the per-tick
    alert with ONE [DEGRADED] per episode, and the hourly health report reads it.

.DESCRIPTION
    Decision (ai-01, 23/11):
      (a) 3 backend-down / real-call failures inside 2 h -> one [DEGRADED] per
          episode, closed by [REPAIRED] after two healthy real calls more than
          5 min apart. An [OK] tick in between does NOT reset the window.
      (b) REJECTED: no automatic restart of the sk-agent container.
      (c) the hourly health report reads the watchdog's real-call result:
          no GREEN while the window holds a failure.

    Update-SkAgentFailureWindow (watchdog) and ConvertTo-WindowUtc,
    Get-SkAgentWindowLayer (healthcheck) are EXTRACTED from the scripts under
    test -- a copy pasted here would diverge.

    The integration test drives the REAL Invoke-SkAgentRouteCheck (probes stubbed)
    followed by the REAL window, including the script's own main-flow read of
    skagent-realcall-state.json -- because the defect this design closes is a
    whole-file rewrite done by the CALLER, invisible to a test that drives the
    window function alone. A mutation test pins it: pointing the window at the
    check's own counter file turns the flapping assertion RED.

    For (c) the WHOLE report is run, not a re-derivation of it: the real
    healthcheck is invoked with its four probe layers replaced by healthy stubs,
    so the status it computes is the one this window produces.

    All instants are explicit UTC strings. [datetime]'...Z' converts to LOCAL on
    both engines (measured 24/11 on 5.1 and 7.6), so nothing here relies on the
    machine's timezone.

.NOTES
    Requires Pester 5+. Runs under Windows PowerShell 5.1 and pwsh 7.
    Nothing in this suite posts to a real dashboard: publishing is stubbed.
#>

Describe 'mcp-chain-watchdog sk-agent failure window (#4897 a+c)' {

    BeforeAll {
        $script:repoRoot = (Resolve-Path -Path "$PSScriptRoot/../../..").Path
        $script:watchdogPath = Join-Path $script:repoRoot 'scripts\mcp-watchdog\mcp-chain-watchdog.ps1'
        $script:healthcheckPath = Join-Path $script:repoRoot 'scripts\mcp-watchdog\mcp-chain-healthcheck.ps1'
        $script:content = Get-Content $script:watchdogPath -Raw
        $script:hcContent = Get-Content $script:healthcheckPath -Raw

        # The window names the seat in its episode id ($env:COMPUTERNAME.ToLower())
        # and the note key interpolates it. A Linux CI host has no COMPUTERNAME at
        # all: on ubuntu-latest 19 tests threw "You cannot call a method on a
        # null-valued expression" there (measured 24/11) while this very file was
        # green on 5.1 and 7 on Windows. The watchdog is a Windows scheduled task
        # and that production line is not touched for a host it never runs on:
        # as in worker-own-claim-prompt.Tests.ps1, the harness supplies the host
        # name a seat always has. Restored in AfterAll, so no later suite in the
        # same process inherits a fake host.
        $script:savedComputerName = $env:COMPUTERNAME
        if (-not $env:COMPUTERNAME) { $env:COMPUTERNAME = 'pester-seat' }
        # Necessity of this line was measured by mutation on 24/11: re-unsetting
        # the variable here turns 20 tests RED (19 x .ToLower() on a null host
        # name, 1 x the note-key shape), where with it the suite is 44/44.

        function Get-FunctionSource {
            param([string]$Name, [string]$From = $script:content)
            $m = [regex]::Match($From, "(?s)function $Name \{.*?\n\}")
            if (-not $m.Success) { throw "$Name not found" }
            $m.Value
        }
        function Get-DeclaredConst {
            param([string]$Name)
            $m = [regex]::Match($script:content, "\`$$Name = (\d+)")
            if (-not $m.Success) { throw "`$$Name not found in mcp-chain-watchdog.ps1" }
            [int]$m.Groups[1].Value
        }
        function Get-Utc {
            param([string]$Text)
            [datetime]::Parse($Text, [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::RoundtripKind)
        }
        function Add-MinutesUtc {
            param([string]$Text, [double]$Minutes)
            (Get-Utc $Text).AddMinutes($Minutes).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
        }

        $script:declaredWindowMinutes = Get-DeclaredConst 'SkAgentWindowMinutes'
        $script:declaredThreshold     = Get-DeclaredConst 'SkAgentWindowThreshold'
        $script:declaredRepairGapMin  = Get-DeclaredConst 'SkAgentRepairMinGapMinutes'
        $script:declaredPublishReserveSec = Get-DeclaredConst 'SkAgentPublishReserveSec'
        $script:windowSource = Get-FunctionSource 'Update-SkAgentFailureWindow'
        $script:checkSource  = Get-FunctionSource 'Invoke-SkAgentRouteCheck'

        # AST of the whole watchdog: param() defaults (never a copied literal).
        $script:ast = [System.Management.Automation.Language.Parser]::ParseInput($script:content, [ref]$null, [ref]$null)
        $script:paramDefaults = @{}
        foreach ($p in $script:ast.ParamBlock.Parameters) {
            if ($p.DefaultValue) { $script:paramDefaults[$p.Name.VariablePath.UserPath] = $p.DefaultValue.SafeGetValue() }
        }
        # Main-flow lines, verbatim from the script: the #4197 counter's own file,
        # the #4897 window's own file, and the read of the counter that precedes
        # the check. Driving these is what makes the clobbage reproducible.
        $m = [regex]::Match($script:content, '(?m)^\$skAgentRealCallStateFile = .+$')
        if (-not $m.Success) { throw 'real-call state path line not found' }
        $script:realCallPathLine = $m.Value
        $m = [regex]::Match($script:content, '(?m)^\$skAgentWindowStateFile = .+$')
        if (-not $m.Success) { throw 'window state path line not found' }
        $script:windowPathLine = $m.Value
        $m = [regex]::Match($script:content, '(?m)^        \$rcState = .+$')
        if (-not $m.Success) { throw 'real-call state read line not found' }
        $script:realCallReadLine = $m.Value

        . ([scriptblock]::Create((Get-FunctionSource 'Get-SkAgentUtcInstant')))
        . ([scriptblock]::Create((Get-FunctionSource 'ConvertTo-SkAgentUtcText')))
        . ([scriptblock]::Create($script:windowSource))
        . ([scriptblock]::Create((Get-FunctionSource 'Get-FleetNoteAcknowledgement')))

        # Sets the state-file paths and the constants the window reads. All at
        # SCRIPT scope: the function under test resolves them through its CALL
        # chain, and a variable set in this helper's own scope would be gone by
        # the time the window runs.
        function Set-WindowEnv {
            # The captured lines are ASSIGNMENTS: `Invoke-Expression <line>`
            # creates the variable in ITS OWN scope and emits nothing, so
            # `$script:x = Invoke-Expression ...` would assign $null. Evaluate the
            # RHS only, by dot-sourcing a block with the LogDir the test wants.
            function Resolve-WatchdogPathLine {
                param([string]$Line)
                $rhs = $Line.Substring($Line.IndexOf('=') + 1).Trim()
                . ([scriptblock]::Create("`$LogDir = `$TestDrive" + [Environment]::NewLine + $rhs))
            }
            $script:skAgentRealCallStateFile = Resolve-WatchdogPathLine $script:realCallPathLine
            $script:skAgentWindowStateFile = Resolve-WatchdogPathLine $script:windowPathLine
            $script:SkAgentWindowMinutes = $script:declaredWindowMinutes
            $script:SkAgentWindowThreshold = $script:declaredThreshold
            $script:SkAgentRepairMinGapMinutes = $script:declaredRepairGapMin
            $script:SkAgentPublishReserveSec = $script:declaredPublishReserveSec
        }

        function Read-WindowState {
            Get-Content $script:skAgentWindowStateFile -Raw | ConvertFrom-Json
        }

        # Drives ONE tick of the real window. Publishes are recorded, never sent.
        # -OnPublish is an OBSERVER: a scriptblock run by the publish stub at the
        # very moment the window tries to post (a stub redefined by the test
        # itself would be shadowed by this one, which lives one scope closer to
        # the function under test).
        function Invoke-Window {
            param(
                [Parameter(Mandatory)][string]$Kind,
                [string]$At = '2026-11-24T10:00:00Z',
                [double]$RunSecondsLeft = 250,
                [bool]$PublishOk = $true,
                [scriptblock]$OnPublish
            )
            Set-WindowEnv
            $script:publishCalls = @()
            $script:logLines = @()
            function Write-Log { param($Level, $Message) $script:logLines += "$Level $Message" }
            function Get-RunSecondsLeft { $RunSecondsLeft }
            function Publish-FleetNote {
                param($Level, $Text, $Type, $Workspace)
                if ($OnPublish) { & $OnPublish $Level $Text }
                $script:publishCalls += [pscustomobject]@{
                    Level = $Level; Text = $Text; Type = $Type; Workspace = $Workspace
                    MessageId = $(if ($Text -match '(?m)^id: (\S+)\s*$') { $Matches[1] } else { $null })
                    # Whole marker VALUE (hour + id): the organ reads everything
                    # after 'scope:' on that line (SCOPE_MARKER_RE), not one token.
                    Scope     = $(if ($Text -match '(?m)^scope: (.+?)\s*$') { $Matches[1] } else { $null })
                }
                return $PublishOk
            }
            $verdict = Update-SkAgentFailureWindow -Kind $Kind -At (Get-Utc $At)
            [pscustomobject]@{
                Verdict  = $verdict
                State    = (Read-WindowState)
                Posts    = @($script:publishCalls)
                LogLines = @($script:logLines)
            }
        }

        # Opens an episode with three real backend-down ticks, so a test about the
        # CLOSE starts from a genuinely open escalation whose open was published.
        function Open-Episode {
            param([string]$StartAt = '2026-11-24T08:00:00Z')
            $null = Invoke-Window -Kind 'backend-down' -At $StartAt
            $null = Invoke-Window -Kind 'backend-down' -At (Add-MinutesUtc $StartAt 2)
            $opened = Invoke-Window -Kind 'backend-down' -At (Add-MinutesUtc $StartAt 4)
            $opened
        }
    }

    BeforeEach {
        Remove-Item (Join-Path $TestDrive 'skagent-window-state.json') -ErrorAction SilentlyContinue
        Remove-Item (Join-Path $TestDrive 'skagent-realcall-state.json') -ErrorAction SilentlyContinue
    }

    AfterAll {
        # Assigning $null removes the variable: a host that had none gets none back.
        $env:COMPUTERNAME = $script:savedComputerName
    }

    Context '(a) one escalation per episode, flapping tolerated' {

        It 'flapping fail/OK/fail/OK/fail inside 2 h opens exactly ONE escalation' {
            $r1 = Invoke-Window -Kind 'realcall-failing' -At '2026-11-24T10:00:00Z'
            $r2 = Invoke-Window -Kind 'ok'               -At '2026-11-24T10:02:00Z'
            $r3 = Invoke-Window -Kind 'realcall-failing' -At '2026-11-24T10:04:00Z'
            $r4 = Invoke-Window -Kind 'ok'               -At '2026-11-24T10:06:00Z'
            $r5 = Invoke-Window -Kind 'realcall-failing' -At '2026-11-24T10:08:00Z'

            @($r1, $r2, $r3, $r4) | ForEach-Object { $_.Verdict | Should -Not -Be 'degraded-open' }
            $r5.Verdict | Should -Be 'degraded-open'
            @((Read-WindowState).windowFailures).Count | Should -BeExactly 3 -Because 'an OK tick must NOT reset the failure window'
            (Read-WindowState).escalationOpen | Should -BeTrue
            @($r5.Posts).Count | Should -BeExactly 1
            $r5.Posts[0].Level | Should -Be 'DEGRADED'
            @($r5.Posts[0].Text -split "`n")[0] | Should -Match '^\[DEGRADED\] ' -Because 'the organ only counts a declaration as the FIRST token of the body'
            $r5.Posts[0].Type | Should -Be 'workspace' -Because 'the degraded-escalation organ reads the WORKSPACE dashboards'
            $r5.Posts[0].MessageId | Should -Be (Read-WindowState).escalationId

            # More failing ticks in the SAME episode: no second declaration.
            $r6 = Invoke-Window -Kind 'backend-down' -At '2026-11-24T10:10:00Z'
            $r6.Verdict | Should -Be 'degraded-open-already'
            @($r6.Posts).Count | Should -BeExactly 0
            ((Read-WindowState).escalationId) | Should -Be $r5.Posts[0].MessageId
        }

        It 'a failure OLDER than 2 h does not arm the window' {
            $t = '2026-11-24T10:00:00Z'
            $null = Invoke-Window -Kind 'realcall-failing' -At $t
            $null = Invoke-Window -Kind 'realcall-failing' -At (Add-MinutesUtc $t 2)
            # A neutral tick 125 min after the first failure: the horizon reaches
            # back to 10:05, so BOTH failures (10:00 and 10:02) have slid out.
            $null = Invoke-Window -Kind 'skipped' -At (Add-MinutesUtc $t 125)
            @((Read-WindowState).windowFailures).Count | Should -BeExactly 0 -Because 'both failures are older than the 120 min horizon'
            # One new failure now: only this one is in the window, no escalation.
            $r = Invoke-Window -Kind 'realcall-failing' -At (Add-MinutesUtc $t 126)
            $r.Verdict | Should -Not -Be 'degraded-open'
            @((Read-WindowState).windowFailures).Count | Should -BeExactly 1
            (Read-WindowState).escalationOpen | Should -BeFalse
        }

        It 'the horizon is exactly 120 min: a failure that old still counts, one second older does not' {
            # Third failure EXACTLY 120 min after the first: its cut is 10:00:00,
            # so all three are inside and the episode opens.
            $null = Invoke-Window -Kind 'realcall-failing' -At '2026-11-24T10:00:00Z'
            $null = Invoke-Window -Kind 'realcall-failing' -At '2026-11-24T10:00:30Z'
            $edge = Invoke-Window -Kind 'realcall-failing' -At '2026-11-24T12:00:00Z'
            $edge.Verdict | Should -Be 'degraded-open'
            Remove-Item (Join-Path $TestDrive 'skagent-window-state.json') -ErrorAction SilentlyContinue
            # One second later the first failure slides out: only two remain.
            $null = Invoke-Window -Kind 'realcall-failing' -At '2026-11-24T10:00:00Z'
            $null = Invoke-Window -Kind 'realcall-failing' -At '2026-11-24T10:00:30Z'
            $past = Invoke-Window -Kind 'realcall-failing' -At '2026-11-24T12:00:01Z'
            $past.Verdict | Should -Not -Be 'degraded-open'
            @((Read-WindowState).windowFailures).Count | Should -BeExactly 2
        }

        It 'classifies the route verdicts: every unusable-route verdict arms it' {
            foreach ($kind in @('backend-down', 'realcall-failing', 'cooldown', 'deferred', 'still-failing', 'still-missing', 'unverified')) {
                # One kind per isolated window: the assertions below are about the
                # classification of a single tick, not about accumulation.
                Remove-Item (Join-Path $TestDrive 'skagent-window-state.json') -ErrorAction SilentlyContinue
                $r = Invoke-Window -Kind $kind -At '2026-11-24T10:00:00Z'
                @($r.State.windowFailures).Count | Should -BeExactly 1 -Because "$kind means the route is not usable"
            }
        }

        It 'dry-run, not-404, recovered, skipped and disabled do NOT arm the window' {
            foreach ($kind in @('dry-run', 'not-404', 'recovered', 'skipped', 'disabled')) {
                $r = Invoke-Window -Kind $kind -At '2026-11-24T10:00:00Z'
                @($r.State.windowFailures).Count | Should -BeExactly 0 -Because "$kind proves nothing about a failing real call"
                $r.State.escalationOpen | Should -BeFalse
            }
        }
    }

    Context '(a) the close: two healthy real calls more than 5 min apart' {

        It 'one healthy call does not close it; a second one > 5 min later does, with the right scope and id' {
            $opened = Open-Episode
            $episodeId = $opened.Posts[0].MessageId

            $h1 = Invoke-Window -Kind 'ok' -At '2026-11-24T08:10:00Z'
            $h1.Verdict | Should -Be 'ok-one-healthy-call'
            (Read-WindowState).escalationOpen | Should -BeTrue

            $h2 = Invoke-Window -Kind 'ok' -At '2026-11-24T08:12:00Z'
            $h2.Verdict | Should -Be 'ok-one-healthy-call' -Because '2 min after the first healthy call is not > 5 min'
            (Read-WindowState).escalationOpen | Should -BeTrue

            $h3 = Invoke-Window -Kind 'ok' -At '2026-11-24T08:20:00Z'
            $h3.Verdict | Should -Be 'repaired'
            (Read-WindowState).escalationOpen | Should -BeFalse
            @((Read-WindowState).windowFailures).Count | Should -BeExactly 0
            @($h3.Posts).Count | Should -BeExactly 1
            $h3.Posts[0].Level | Should -Be 'REPAIRED'
            @($h3.Posts[0].Text -split "`n")[0] | Should -Match '^\[REPAIRED\] '
            # Scope = the OPEN's posting hour. Open-Episode opens at 08:04Z, so
            # the close must name 08:04Z. A messageId-only scope stops closing
            # once the dashboard is condensed (the archive serves freshly formed
            # ids, reported by ai-01 24/11); the posting hour is the entry's own
            # header and survives it. The id stays in the marker line as the
            # human-readable name, but the HOUR is what must be there.
            $h3.Posts[0].Scope | Should -Be "08:04Z $episodeId" -Because 'the close names the open posting hour (condensation-proof) plus the episode id'
            $h3.Posts[0].Scope | Should -Not -Match '#4897' -Because 'an issue ref in the marker would close every escalation citing that issue'
            $h3.Posts[0].Text | Should -Not -Match '#4897' -Because 'the organ also matches a close on an issue ref present in the OPEN body: keep it out'
            $h3.Posts[0].MessageId | Should -Be "$episodeId-repaired" -Because 'reusing the open id would make the server dedup the close against the open'
            $h3.Posts[0].MessageId | Should -Not -Be $episodeId
            @((Read-WindowState).pendingPosts).Count | Should -BeExactly 0
        }

        It 'the close still names the posting hour when the state came from a legacy file without escalationOpenedAt' {
            $null = Open-Episode
            $state = Read-WindowState
            $state.PSObject.Properties.Remove('escalationOpenedAt')
            [System.IO.File]::WriteAllText($script:skAgentWindowStateFile, ($state | ConvertTo-Json -Depth 5), (New-Object System.Text.UTF8Encoding($false)))
            $null = Invoke-Window -Kind 'ok' -At '2026-11-24T08:10:00Z'
            $h3 = Invoke-Window -Kind 'ok' -At '2026-11-24T08:20:00Z'
            $h3.Verdict | Should -Be 'repaired'
            $h3.Posts[0].Scope | Should -Match '^08:04Z ' -Because 'the opening instant is recovered from the episode id, never degraded to a lane-wide close'
        }

        It 'two closes in the SAME minute do not collapse to a lane-wide close: the id stays in the marker' {
            # Two episodes opened inside one minute would share an HH:MMZ hour.
            # The marker therefore ALSO carries the episode id, so while both
            # opens are readable the close names exactly one. This test pins the
            # marker shape; the residual same-minute ambiguity of an archived
            # open is a known limit of the organ, documented in the PR.
            $null = Open-Episode
            $null = Invoke-Window -Kind 'ok' -At '2026-11-24T08:10:00Z'
            $h3 = Invoke-Window -Kind 'ok' -At '2026-11-24T08:20:00Z'
            $markerLine = @(($h3.Posts[0].Text -split "`n") | Where-Object { $_ -match '^scope: ' })
            $markerLine.Count | Should -BeExactly 1 -Because 'exactly one scope marker line'
            $markerLine[0] | Should -Match '^scope: \d{2}:\d{2}Z watchdog-skagent-4897-'
        }

        It 'two healthy calls less than 5 min apart keep it open' {
            $null = Open-Episode
            $null = Invoke-Window -Kind 'ok' -At '2026-11-24T08:10:00Z'
            $h2 = Invoke-Window -Kind 'ok' -At '2026-11-24T08:14:00Z'
            $h2.Verdict | Should -Be 'ok-one-healthy-call'
            (Read-WindowState).escalationOpen | Should -BeTrue
        }

        It 'EXACTLY 5 min apart is not "more than 5 min": the episode stays open' {
            $null = Open-Episode
            $null = Invoke-Window -Kind 'ok' -At '2026-11-24T08:10:00Z'
            $edge = Invoke-Window -Kind 'ok' -At '2026-11-24T08:15:00Z'
            $edge.Verdict | Should -Be 'ok-one-healthy-call'
            (Read-WindowState).escalationOpen | Should -BeTrue
            # One second past the gap closes it.
            $past = Invoke-Window -Kind 'ok' -At '2026-11-24T08:15:01Z'
            $past.Verdict | Should -Be 'repaired'
        }

        It 'healthy ticks at the REAL cadence (every 2 min) close it at the first tick more than 5 min after the first healthy one' {
            # The test above spaces its ticks by hand. In production the task
            # fires every 2 min, so consecutive healthy ticks are ALWAYS ~2 min
            # apart: an anchor that moved to the latest healthy tick would never
            # see a gap above 5 min and the episode would stay open forever.
            # Only the gap measured from the FIRST healthy tick closes it.
            $null = Open-Episode
            $verdicts = @()
            foreach ($min in 10, 12, 14, 16, 18) {
                $verdicts += (Invoke-Window -Kind 'ok' -At "2026-11-24T08:$min`:00Z").Verdict
            }
            # 08:16 is the first healthy tick more than 5 min after 08:10.
            ($verdicts -join ',') | Should -Be 'ok-one-healthy-call,ok-one-healthy-call,ok-one-healthy-call,repaired,ok' -Because 'healthy, healthy, healthy, then the first tick > 5 min after the first healthy one closes; the next tick is a plain ok'
            (Read-WindowState).escalationOpen | Should -BeFalse
        }

        It 'a failure between the two healthy calls restarts the repair sequence, not the window' {
            $null = Open-Episode
            $null = Invoke-Window -Kind 'ok' -At '2026-11-24T08:10:00Z'
            $null = Invoke-Window -Kind 'realcall-failing' -At '2026-11-24T08:12:00Z'
            $h2 = Invoke-Window -Kind 'ok' -At '2026-11-24T08:20:00Z'
            $h2.Verdict | Should -Be 'ok-one-healthy-call' -Because 'the failure in between restarts the healthy sequence'
            (Read-WindowState).escalationOpen | Should -BeTrue
        }
    }

    Context 'the declaration queue: one attempt per tick, nothing lost, stable ids' {

        It 'an unposted open stays queued and is retried with the SAME messageId' {
            # The dashboard is down from the FIRST tick: the OPEN itself is what
            # fails to post (Open-Episode would already have posted it).
            $null = Invoke-Window -Kind 'backend-down' -At '2026-11-24T08:00:00Z' -PublishOk $false
            $null = Invoke-Window -Kind 'backend-down' -At '2026-11-24T08:02:00Z' -PublishOk $false
            $opened = Invoke-Window -Kind 'backend-down' -At '2026-11-24T08:04:00Z' -PublishOk $false
            $opened.Verdict | Should -Be 'degraded-open-unposted'
            $episodeId = $opened.Posts[0].MessageId
            $episodeId | Should -Not -BeNullOrEmpty
            @((Read-WindowState).pendingPosts).Count | Should -BeExactly 1

            $f1 = Invoke-Window -Kind 'backend-down' -At '2026-11-24T08:06:00Z' -PublishOk $false
            $f1.Verdict | Should -Be 'degraded-open-already' -Because 'still failing inside the same episode, open still owed'
            @((Read-WindowState).pendingPosts).Count | Should -BeExactly 1

            # A NEUTRAL tick with a full queue is the case the generic retry
            # verdict names: no new failure, just the owed declaration retried.
            $neutral = Invoke-Window -Kind 'skipped' -At '2026-11-24T08:07:00Z' -PublishOk $false
            $neutral.Verdict | Should -Be 'pending-post-retry'
            @($neutral.Posts).Count | Should -BeExactly 1
            $neutral.Posts[0].MessageId | Should -Be $episodeId

            $f2 = Invoke-Window -Kind 'backend-down' -At '2026-11-24T08:08:00Z' -PublishOk $false
            @((Read-WindowState).pendingPosts).Count | Should -BeExactly 1 -Because 'no new declaration is created while one is owed'
            @($f2.Posts).Count | Should -BeExactly 1
            $f2.Posts[0].MessageId | Should -Be $episodeId

            $f3 = Invoke-Window -Kind 'backend-down' -At '2026-11-24T08:10:00Z'
            @($f3.Posts).Count | Should -BeExactly 1
            $f3.Posts[0].MessageId | Should -Be $episodeId -Because 'the retry is idempotent (messageId, #3276)'
            @((Read-WindowState).pendingPosts).Count | Should -BeExactly 0
        }

        It 'the run-budget guard defers the publish and keeps the declaration owed' {
            $null = Invoke-Window -Kind 'backend-down' -At '2026-11-24T08:00:00Z'
            $null = Invoke-Window -Kind 'backend-down' -At '2026-11-24T08:02:00Z'
            $lowBudget = $script:declaredPublishReserveSec - 10
            $r = Invoke-Window -Kind 'backend-down' -At '2026-11-24T08:04:00Z' -RunSecondsLeft $lowBudget
            $r.Verdict | Should -Be 'degraded-open-unposted'
            @($r.Posts).Count | Should -BeExactly 0 -Because 'a note that cannot fit in the run budget is not started'
            @((Read-WindowState).pendingPosts).Count | Should -BeExactly 1
            @((Read-WindowState).pendingPosts)[0].Level | Should -Be 'DEGRADED'
            ($r.LogLines -join "`n") | Should -Match 'still queued'
        }

        It 'an unposted close and a NEW episode are BOTH owed, in order -- never overwritten' {
            # Episode 1 was DECLARED (its open went out). Its close cannot be
            # posted, so the close is owed; episode 2 then opens while the
            # dashboard is still down: BOTH declarations are owed, in order.
            $opened = Open-Episode
            $episode1 = $opened.Posts[0].MessageId
            $null = Invoke-Window -Kind 'ok' -At '2026-11-24T08:10:00Z'
            $closed = Invoke-Window -Kind 'ok' -At '2026-11-24T08:20:00Z' -PublishOk $false
            $closed.Verdict | Should -Be 'repaired-unposted'
            @((Read-WindowState).pendingPosts).Count | Should -BeExactly 1
            @((Read-WindowState).pendingPosts)[0].Level | Should -Be 'REPAIRED'

            $null = Invoke-Window -Kind 'backend-down' -At '2026-11-24T08:22:00Z' -PublishOk $false
            $null = Invoke-Window -Kind 'backend-down' -At '2026-11-24T08:24:00Z' -PublishOk $false
            $null = Invoke-Window -Kind 'backend-down' -At '2026-11-24T08:26:00Z' -PublishOk $false
            $queued = @((Read-WindowState).pendingPosts)
            $queued.Count | Should -BeExactly 2 -Because 'a single pendingPost slot would drop one of the two'
            $queued[0].Level | Should -Be 'REPAIRED'
            $queued[1].Level | Should -Be 'DEGRADED'
            $queued[1].EpisodeId | Should -Not -Be $episode1

            # One attempt per tick, in order: the close goes out before the open.
            $drain1 = Invoke-Window -Kind 'skipped' -At '2026-11-24T08:28:00Z'
            @($drain1.Posts).Count | Should -BeExactly 1
            $drain1.Posts[0].Level | Should -Be 'REPAIRED'
            $drain1.Posts[0].MessageId | Should -Be "$episode1-repaired"
            $drain2 = Invoke-Window -Kind 'skipped' -At '2026-11-24T08:30:00Z'
            @($drain2.Posts).Count | Should -BeExactly 1
            $drain2.Posts[0].Level | Should -Be 'DEGRADED'
            @((Read-WindowState).pendingPosts).Count | Should -BeExactly 0
        }

        It 'an episode closed before its open could be posted leaves neither declaration' {
            # The dashboard is down from the first tick: episode 1's open never
            # went out, so its close must erase BOTH -- an orphan [REPAIRED] would
            # close an escalation nobody ever read.
            $null = Invoke-Window -Kind 'backend-down' -At '2026-11-24T08:00:00Z' -PublishOk $false
            $null = Invoke-Window -Kind 'backend-down' -At '2026-11-24T08:02:00Z' -PublishOk $false
            $opened = Invoke-Window -Kind 'backend-down' -At '2026-11-24T08:04:00Z' -PublishOk $false
            $episode1 = $opened.Posts[0].MessageId
            $null = Invoke-Window -Kind 'ok' -At '2026-11-24T08:10:00Z' -PublishOk $false
            $closed = Invoke-Window -Kind 'ok' -At '2026-11-24T08:20:00Z' -PublishOk $false
            $closed.Verdict | Should -Be 'repaired' -Because 'the episode is closed locally; nothing of it remains to post, so the verdict is not the unposted form'
            @((Read-WindowState).pendingPosts).Count | Should -BeExactly 0 -Because "episode $episode1 was never declared"
            (Read-WindowState).escalationOpen | Should -BeFalse
        }

        It 'an episode whose open was never posted produces neither a stale open nor an orphan close' {
            $opened = Open-Episode
            $episode1 = $opened.Posts[0].MessageId
            $null = Invoke-Window -Kind 'ok' -At '2026-11-24T08:10:00Z'
            $null = Invoke-Window -Kind 'ok' -At '2026-11-24T08:20:00Z' -PublishOk $false
            @((Read-WindowState).pendingPosts).Count | Should -BeExactly 1

            # Episode 2 opens while the dashboard is down: its open is owed.
            $null = Invoke-Window -Kind 'backend-down' -At '2026-11-24T08:22:00Z' -PublishOk $false
            $null = Invoke-Window -Kind 'backend-down' -At '2026-11-24T08:24:00Z' -PublishOk $false
            $null = Invoke-Window -Kind 'backend-down' -At '2026-11-24T08:26:00Z' -PublishOk $false
            $episode2 = @((Read-WindowState).pendingPosts | Where-Object Level -eq 'DEGRADED')[0].EpisodeId
            # ...and it closes before anything could be posted.
            $null = Invoke-Window -Kind 'ok' -At '2026-11-24T08:30:00Z' -PublishOk $false
            $null = Invoke-Window -Kind 'ok' -At '2026-11-24T08:40:00Z' -PublishOk $false
            $queued = @((Read-WindowState).pendingPosts)
            @($queued | Where-Object { $_.EpisodeId -eq $episode2 }).Count | Should -BeExactly 0 -Because 'a close of an undeclared episode would be an orphan [REPAIRED] closing an escalation nobody read'
            @($queued | Where-Object { $_.Level -eq 'REPAIRED' -and $_.EpisodeId -eq $episode1 }).Count | Should -BeExactly 1 -Because 'the close of episode 1, whose open WAS posted, is still owed'
        }

        It 'the state file is persisted BEFORE the publish attempt' {
            # The observer reads the queue AS IT EXISTS IN THE FILE at the moment
            # the window tries to publish. Reading the file after the tick would
            # prove nothing (a failed publish leaves the declaration owed anyway).
            $null = Invoke-Window -Kind 'backend-down' -At '2026-11-24T08:00:00Z'
            $null = Invoke-Window -Kind 'backend-down' -At '2026-11-24T08:02:00Z'
            $script:queueAtPublish = $null
            $r = Invoke-Window -Kind 'backend-down' -At '2026-11-24T08:04:00Z' -PublishOk $false -OnPublish {
                $script:queueAtPublish = @((Get-Content $script:skAgentWindowStateFile -Raw | ConvertFrom-Json).pendingPosts)
            }
            $r.Verdict | Should -Be 'degraded-open-unposted'
            $script:queueAtPublish | Should -Not -BeNullOrEmpty -Because 'the observer must have run, inside the publish attempt'
            $script:queueAtPublish.Count | Should -BeExactly 1 -Because 'a run cut after the write, before the post, still owes the declaration'
            $script:queueAtPublish[0].Level | Should -Be 'DEGRADED'
            @($r.Posts).Count | Should -BeExactly 1
            @((Read-WindowState).pendingPosts).Count | Should -BeExactly 1
        }

        It 'a single queued declaration is removed cleanly on a successful publish' {
            $null = Invoke-Window -Kind 'backend-down' -At '2026-11-24T08:00:00Z'
            $null = Invoke-Window -Kind 'backend-down' -At '2026-11-24T08:02:00Z'
            $r = Invoke-Window -Kind 'backend-down' -At '2026-11-24T08:04:00Z'
            @($r.Posts).Count | Should -BeExactly 1
            # The former $pending[1..0] form re-inserted the head on a 1-item queue.
            @((Read-WindowState).pendingPosts).Count | Should -BeExactly 0
        }

        It 'two owed declarations go out one per tick, in order (close before the next open)' {
            # The close of a DECLARED episode 1 fails to post, then episode 2 opens:
            # both are owed, and one attempt per tick must not let the open outrun
            # the close (a single pendingPost slot would have dropped one).
            $opened = Open-Episode
            $episode1 = $opened.Posts[0].MessageId
            $null = Invoke-Window -Kind 'ok' -At '2026-11-24T08:10:00Z'
            $closed = Invoke-Window -Kind 'ok' -At '2026-11-24T08:20:00Z' -PublishOk $false
            $closed.Verdict | Should -Be 'repaired-unposted'
            @((Read-WindowState).pendingPosts).Count | Should -BeExactly 1

            $null = Invoke-Window -Kind 'backend-down' -At '2026-11-24T08:22:00Z' -PublishOk $false
            $null = Invoke-Window -Kind 'backend-down' -At '2026-11-24T08:24:00Z' -PublishOk $false
            $null = Invoke-Window -Kind 'backend-down' -At '2026-11-24T08:26:00Z' -PublishOk $false
            $queued = @((Read-WindowState).pendingPosts)
            $queued.Count | Should -BeExactly 2
            $queued[0].Level | Should -Be 'REPAIRED'
            $queued[1].Level | Should -Be 'DEGRADED'
            $queued[1].EpisodeId | Should -Not -Be $episode1

            $drain1 = Invoke-Window -Kind 'skipped' -At '2026-11-24T08:28:00Z'
            @($drain1.Posts).Count | Should -BeExactly 1
            $drain1.Posts[0].Level | Should -Be 'REPAIRED'
            $drain1.Posts[0].MessageId | Should -Be "$episode1-repaired"
            $drain2 = Invoke-Window -Kind 'skipped' -At '2026-11-24T08:30:00Z'
            @($drain2.Posts).Count | Should -BeExactly 1
            $drain2.Posts[0].Level | Should -Be 'DEGRADED'
            @((Read-WindowState).pendingPosts).Count | Should -BeExactly 0
        }
    }

    Context 'integration: the REAL check, then the REAL window (the clobbage the design closes)' {

        BeforeAll {
            # Drives one full tick: the main-flow read of the #4197 counter, the
            # real Invoke-SkAgentRouteCheck with scripted probes, then the real
            # window. Returns the window verdict.
            function Invoke-RealTick {
                param(
                    [Parameter(Mandatory)][bool]$RealCallOk,
                    [string]$At = '2026-11-24T10:00:00Z'
                )
                Set-WindowEnv
                # Optional mutation hook (script scope, reset by every test): the
                # window shares the check's counter file instead of its own.
                if ($script:shareWindowFile) { $skAgentWindowStateFile = $script:skAgentRealCallStateFile }
                $skAgentRealCallFailures = 0
                $skAgentRealCallLastOkLogAt = [datetime]::MinValue
                if (Test-Path $script:skAgentRealCallStateFile) {
                    try {
                        Invoke-Expression $script:realCallReadLine
                        $skAgentRealCallFailures = [int]$rcState.consecutiveFailures
                        $skAgentRealCallLastOkLogAt = [datetime]$rcState.lastOkLogAt
                    } catch { }
                }
                $SkAgentRouteUrl = $script:paramDefaults['SkAgentRouteUrl']
                $SkAgentBackendUrl = $script:paramDefaults['SkAgentBackendUrl']
                $bearer = 'test-bearer'
                $lastRouteRepairAt = [datetime]::MinValue
                $routeRepairStateFile = Join-Path $TestDrive 'route-repair-state.json'
                $RouteRepairCooldownMin = 10
                $RouteRepairWorstCaseSec = 30
                $SkAgentProbeTimeoutSec = 8
                $SkAgentVerifyCapSec = 30
                $SkAgentVerifyIntervalSec = 2
                $SkAgentRealCallFailThreshold = 3
                $SkAgentOkLogPeriodMin = 60
                $Mode = 'poll'
                $script:repairs = @()
                $script:alerts = @()
                $script:deferredVerifications = @()
                $script:publishCalls = @()
                $script:logLines = @()
                function Write-Log { param($Level, $Message) $script:logLines += "$Level $Message" }
                function Start-Sleep { param([int]$Seconds) }
                function docker { }
                function Get-RunSecondsLeft { 250 }
                function Get-McpInitializeStatus {
                    param([string]$Url, [string]$Bearer, [int]$TimeoutSec)
                    if ($Url -eq $SkAgentBackendUrl) { return 0 } # backend DOWN: no TBXark restart
                    return 200
                }
                function Invoke-SkAgentRouteRealCall {
                    param([string]$Url, [string]$Bearer, [int]$TimeoutSec)
                    if ($RealCallOk) { return @{ Ok = $true; InitStatus = 200; CallStatus = 200; Detail = 'healthy' } }
                    return @{ Ok = $false; InitStatus = 200; CallStatus = 0; Detail = 'tools/call failed: http-0' }
                }
                function Publish-FleetNote {
                    param($Level, $Text, $Type, $Workspace)
                    $script:publishCalls += [pscustomobject]@{
                        Level = $Level; Text = $Text
                        MessageId = $(if ($Text -match '(?m)^id: (\S+)\s*$') { $Matches[1] } else { $null })
                    }
                    return $true
                }
                . ([scriptblock]::Create($script:checkSource))
                $verdict = Invoke-SkAgentRouteCheck
                $wVerdict = Update-SkAgentFailureWindow -Kind $verdict -At (Get-Utc $At)
                [pscustomobject]@{
                    Check  = $verdict
                    Window = $wVerdict
                    Posts  = @($script:publishCalls)
                }
            }
            $script:shareWindowFile = $false
        }

        It 'fail/OK/fail/OK/fail with the real check opens exactly one escalation' {
            $script:shareWindowFile = $false
            $seq = @($false, $true, $false, $true, $false)
            $verdicts = @()
            for ($i = 0; $i -lt $seq.Count; $i++) {
                $r = Invoke-RealTick -RealCallOk $seq[$i] -At (Add-MinutesUtc '2026-11-24T10:00:00Z' (2 * $i))
                $r.Check | Should -Be $(if ($seq[$i]) { 'ok' } else { 'backend-down' })
                $verdicts += $r.Window
            }
            $verdicts[0] | Should -Not -Be 'degraded-open'
            $verdicts[1] | Should -Not -Be 'degraded-open' -Because 'an OK tick must not reset the window'
            $verdicts[4] | Should -Be 'degraded-open'
            @($verdicts | Where-Object { $_ -eq 'degraded-open' }).Count | Should -BeExactly 1
        }

        It 'three backend-down ticks open the episode (no TBXark restart, no per-tick alert)' {
            $script:shareWindowFile = $false
            $verdicts = @()
            for ($i = 0; $i -lt 3; $i++) {
                $r = Invoke-RealTick -RealCallOk $false -At (Add-MinutesUtc '2026-11-24T10:00:00Z' (2 * $i))
                $r.Check | Should -Be 'backend-down'
                @($script:repairs).Count | Should -BeExactly 0 -Because '(b) rejected: no automatic container restart'
                @($script:alerts).Count | Should -BeExactly 0 -Because 'the per-tick alert is replaced by the escalation'
                $verdicts += $r.Window
            }
            $verdicts[2] | Should -Be 'degraded-open'
            @($r.Posts).Count | Should -BeExactly 1
            $r.Posts[0].Level | Should -Be 'DEGRADED'
        }

        It 'MUTATION: sharing the check counter file would erase the window before each read' {
            # This is the defect the separate file closes. The REAL check rewrites
            # skagent-realcall-state.json wholesale on every failing tick and on
            # every repair, and a healthy tick resets its counter -- so a window
            # kept there would be clobbered before each read and the flapping
            # pattern would never reach 3. Green here would mean the separate file
            # buys nothing; it must be RED on the shared file.
            $script:shareWindowFile = $true
            Remove-Item (Join-Path $TestDrive 'skagent-window-state.json') -ErrorAction SilentlyContinue
            Remove-Item (Join-Path $TestDrive 'skagent-realcall-state.json') -ErrorAction SilentlyContinue
            $seq = @($false, $true, $false, $true, $false)
            $verdicts = @()
            for ($i = 0; $i -lt $seq.Count; $i++) {
                $r = Invoke-RealTick -RealCallOk $seq[$i] -At (Add-MinutesUtc '2026-11-24T10:00:00Z' (2 * $i))
                $verdicts += $r.Window
            }
            @($verdicts | Where-Object { $_ -eq 'degraded-open' }).Count | Should -BeExactly 0 -Because 'on the shared file the window is clobbered by the check before each read: the episode stays invisible'
            $script:shareWindowFile = $false
        }
    }

    Context 'publishing: routing and idempotency of Publish-FleetNote' {

        BeforeAll {
            $script:publishSource = Get-FunctionSource 'Publish-FleetNote'
        }

        It 'declarations go to the WORKSPACE dashboard; other notes stay on the machine dashboard' {
            $script:publishSource | Should -Match "param\(\[string\]\`$Level, \[string\]\`$Text, \[string\]\`$Type = 'machine', \[string\]\`$Workspace = 'roo-extensions'\)"
            $script:publishSource | Should -Match "if \(\`$Type -eq 'workspace'\) \{ \`$arguments\.workspace = \`$Workspace \}"
            $script:windowSource | Should -Match "Publish-FleetNote -Level \`$head\.Level -Type 'workspace' -Text \`$head\.Text"
        }

        It 'the id: line of a declaration becomes the messageId actually SENT (behaviour, not source shape)' {
            # The REAL Publish-FleetNote with the REAL acknowledgement parser; only
            # the HTTP transport is replaced, by a capture that never opens a
            # socket. A test that only matched the source text passed while the
            # same function broke the #4030 single-definition guard in CI.
            . ([scriptblock]::Create($script:publishSource))
            function Write-Log { param($Level, $Message) $script:capturedLog += "$Level $Message" }
            $script:capturedLog = @()
            $script:sentPayloads = @()
            $ackText = '{"success":true,"action":"append","messageId":"x"}'
            $ackBody = '{"jsonrpc":"2.0","id":3,"result":{"content":[{"type":"text","text":' + (ConvertTo-Json $ackText) + '}]}}'
            function Invoke-WebRequest {
                param($Uri, $Method, $Headers, $Body, [switch]$UseBasicParsing, $TimeoutSec, [Parameter(ValueFromPipeline)]$Pipe)
                if ("$Body" -match '"method":"initialize"') { return [pscustomobject]@{ Content = '{}'; Headers = @{} } }
                $script:sentPayloads += ,("$Body" | ConvertFrom-Json)
                return [pscustomobject]@{ Content = $ackBody; Headers = @{} }
            }
            $script:e2eUrl = 'http://capture.invalid/mcp'
            $script:lanUrl = 'http://capture2.invalid/mcp'
            $script:bearer = 'test-bearer-not-a-secret'
            $script:FleetNoteTimeoutSec = 5

            $posted = Publish-FleetNote -Level 'DEGRADED' -Type 'workspace' -Text ("[DEGRADED] body" + [char]10 + "id: watchdog-skagent-4897-HOST-20261124T080422Z")
            $posted | Should -BeTrue -Because 'the capture acknowledges the append'
            @($script:sentPayloads).Count | Should -Be 1 -Because 'an acknowledged first route must not fall through to the second'
            $script:sentPayloads[0].params.arguments.messageId | Should -BeExactly 'watchdog-skagent-4897-HOST-20261124T080422Z'
            $script:sentPayloads[0].params.arguments.workspace | Should -Be 'roo-extensions'
            $script:sentPayloads[0].params.arguments.type | Should -Be 'workspace'
        }

        It 'a note WITHOUT an id: line gets the computed key (host + level + digest + 15 min bucket)' {
            . ([scriptblock]::Create($script:publishSource))
            function Write-Log { param($Level, $Message) }
            $script:sentPayloads = @()
            $ackText = '{"success":true,"action":"append"}'
            $ackBody = '{"jsonrpc":"2.0","id":3,"result":{"content":[{"type":"text","text":' + (ConvertTo-Json $ackText) + '}]}}'
            function Invoke-WebRequest {
                param($Uri, $Method, $Headers, $Body, [switch]$UseBasicParsing, $TimeoutSec, [Parameter(ValueFromPipeline)]$Pipe)
                if ("$Body" -match '"method":"initialize"') { return [pscustomobject]@{ Content = '{}'; Headers = @{} } }
                $script:sentPayloads += ,("$Body" | ConvertFrom-Json)
                return [pscustomobject]@{ Content = $ackBody; Headers = @{} }
            }
            $script:e2eUrl = 'http://capture.invalid/mcp'
            $script:lanUrl = 'http://capture2.invalid/mcp'
            $script:bearer = 'test-bearer-not-a-secret'
            $script:FleetNoteTimeoutSec = 5

            $null = Publish-FleetNote -Level 'WARN' -Text 'plain note, no declaration id'
            $null = Publish-FleetNote -Level 'WARN' -Text 'plain note, no declaration id'
            @($script:sentPayloads).Count | Should -Be 2
            $ids = @($script:sentPayloads | ForEach-Object { $_.params.arguments.messageId })
            # Same note inside one 15 min bucket -> SAME key: the server
            # deduplicates the second attempt (#3276).
            $ids[0] | Should -BeExactly $ids[1]
            # Shape as BUILT, not as guessed: the BitConverter digest is
            # UPPERCASE hex and a host name may carry dashes (MYIA-PO-2023).
            $ids[0] | Should -Match '^watchdog-[A-Za-z0-9-]+-WARN-[0-9A-F]{12}-\d+$'
        }

        It 'the idempotence key is assigned ONCE in Publish-FleetNote (the #4030 single-definition guard, pinned where the change lives)' {
            # scripts/testing/harness/test-watchdog-slow-vs-dead.ps1 counts
            # `$fleetNoteId =` over the whole script and demands exactly 1. This
            # branch tripped it in CI (3 assignments) while every Pester suite
            # was green: the Pester suites never looked at that invariant.
            ([regex]::Matches($script:publishSource, '\$fleetNoteId[ \t]*=')).Count | Should -BeExactly 1
        }

        It 'HTTP 200 is NOT an acknowledgement: JSON-RPC error, isError, success:false and unknown shapes are refused' {
            function New-Resp { param([string]$Body) [pscustomobject]@{ Content = $Body } }
            $okText = '{"success":true,"action":"append","messageId":"watchdog-x"}'
            $ok = '{"jsonrpc":"2.0","id":3,"result":{"content":[{"type":"text","text":' + (ConvertTo-Json $okText) + '}]}}'
            (Get-FleetNoteAcknowledgement -Response (New-Resp $ok)).Ok | Should -BeTrue

            $dedupText = '{"success":true,"action":"append","deduplicated":true}'
            $dedup = '{"jsonrpc":"2.0","id":3,"result":{"content":[{"type":"text","text":' + (ConvertTo-Json $dedupText) + '}]}}'
            (Get-FleetNoteAcknowledgement -Response (New-Resp $dedup)).Ok | Should -BeTrue -Because 'a deduplicated append means the earlier attempt landed'

            # SSE envelope of the same success.
            $sse = "event: message`ndata: $ok`n`n"
            (Get-FleetNoteAcknowledgement -Response (New-Resp $sse)).Ok | Should -BeTrue

            (Get-FleetNoteAcknowledgement -Response (New-Resp '{"jsonrpc":"2.0","id":3,"error":{"code":-32602,"message":"Unknown tool"}}')).Ok | Should -BeFalse -Because 'measured: unknown tool = HTTP 200 + JSON-RPC error'
            (Get-FleetNoteAcknowledgement -Response (New-Resp '{"jsonrpc":"2.0","id":3,"result":{"isError":true,"content":[{"type":"text","text":"Invalid arguments"}]}}')).Ok | Should -BeFalse -Because 'measured: invalid arguments = HTTP 200 + result.isError'
            (Get-FleetNoteAcknowledgement -Response (New-Resp '{"jsonrpc":"2.0","id":3,"result":{"content":[{"type":"text","text":"{\"success\":false,\"error\":\"no such dashboard\"}"}]}}')).Ok | Should -BeFalse -Because 'measured: business refusal = HTTP 200 + success:false'
            (Get-FleetNoteAcknowledgement -Response (New-Resp '{"jsonrpc":"2.0","id":3,"result":{"content":[{"type":"text","text":"not json at all"}]}}')).Ok | Should -BeFalse
            (Get-FleetNoteAcknowledgement -Response (New-Resp '{"jsonrpc":"2.0","id":3,"result":{}}')).Ok | Should -BeFalse
            (Get-FleetNoteAcknowledgement -Response (New-Resp 'not-json')).Ok | Should -BeFalse
            (Get-FleetNoteAcknowledgement -Response (New-Resp '')).Ok | Should -BeFalse
        }

        It '#4921: a success text carrying the server footers is still an acknowledgement' {
            # Measured 24/11 on the proxy transport: roo-state-manager appends
            # "\n\n[<stopwatch> roosync_dashboard NNms]" (injectDuration) and may
            # add "[NOTIF] ..." lines to content[0].text. A parser that wants
            # pure JSON read 326 real appends as unacknowledged on ai-01 and
            # dropped the [REPAIRED] of a [DEGRADED] that had landed.
            function New-Resp { param([string]$Body) [pscustomobject]@{ Content = $Body } }
            $stopwatch = [string][char]0x23F1
            $json = "{`n  `"success`": true,`n  `"action`": `"append`",`n  `"messageId`": `"watchdog-x`"`n}"
            $footer = "`n`n[$stopwatch roosync_dashboard 57ms]"
            $notif = "`n[NOTIF] 2 message(s) non lu(s) en inbox (1 HIGH)`n[NOTIF] 3 nouveau(x) sur global depuis ta derniere lecture`n        (1 ASK, 2 BLOCKED).`n        Lire : roosync_dashboard action:`"read`" type:`"global`""
            # A future footer carrying braces must not hide the object either.
            $bracedFooter = "`n[NOTIF] x } {y} {`"k`":1}" + $footer
            foreach ($text in @(($json + $footer), ($json + $notif + $footer), ($json + $bracedFooter))) {
                $body = '{"jsonrpc":"2.0","id":3,"result":{"content":[{"type":"text","text":' + (ConvertTo-Json $text) + '}]}}'
                $ack = Get-FleetNoteAcknowledgement -Response (New-Resp $body)
                $ack.Ok | Should -BeTrue -Because "a landed append followed by server footers is acknowledged (reason seen: $($ack.Reason))"
            }

            # The tolerance does not widen what counts as success.
            $refusal = '{"success":false,"error":"no such dashboard"}' + $footer
            $body = '{"jsonrpc":"2.0","id":3,"result":{"content":[{"type":"text","text":' + (ConvertTo-Json $refusal) + '}]}}'
            (Get-FleetNoteAcknowledgement -Response (New-Resp $body)).Ok | Should -BeFalse -Because 'a refusal stays a refusal with a footer'
            $prose = 'Message ajoute {"success":true,"action":"append"}' + $footer
            $body = '{"jsonrpc":"2.0","id":3,"result":{"content":[{"type":"text","text":' + (ConvertTo-Json $prose) + '}]}}'
            (Get-FleetNoteAcknowledgement -Response (New-Resp $body)).Ok | Should -BeFalse -Because 'a text that does not open on JSON is not parsed out of its prose'
        }
    }

    Context '(c) the health report reads the window -- no GREEN while it is red' {

        BeforeAll {
            # The WHOLE report, not a re-derivation: the real healthcheck is run
            # with its probe layers replaced by healthy stubs and its publication
            # function REPLACED WHOLE. The copy lives OUTSIDE the repo
            # ($TestDrive), with its own outputs dir beside it, so no test tick
            # writes into the source tree -- and no tick can post a real note:
            # redefining one call site would re-arm the real spawner if that call
            # site were ever renamed, so the function itself is substituted and
            # the copy carries no 'node ... mcp-wrapper.cjs' spawn left.
            $stubbed = $script:hcContent
            $stubbed = $stubbed -replace "Get-ScheduledTask -TaskName 'MCP-Proxy-RSM' -ErrorAction SilentlyContinue", '$null'
            $stubbed = $stubbed -replace 'Test = \{ Test-LocalWrapper \}', 'Test = { @{ Ok = $true; Detail = ''stub: wrapper ok'' } }'
            $stubbed = $stubbed -replace 'Test = \{ Test-E2E -Path \$BotEnvFile \}', 'Test = { @{ Ok = $true; Detail = ''stub: e2e ok'' } }'
            if ($stubbed -eq $script:hcContent) { throw 'healthcheck stubbing replaced nothing -- the probe layer table changed' }
            $publishMatch = [regex]::Match($stubbed, '(?ms)^function Publish-HealthNote \{.*?^\}')
            if (-not $publishMatch.Success) { throw 'Publish-HealthNote not found: the publication path would stay real' }
            $stubbed = $stubbed.Remove($publishMatch.Index, $publishMatch.Length).Insert($publishMatch.Index, @'
function Publish-HealthNote {
    param([string]$Level, [string]$Text, [int]$TimeoutSec = 200)
    # The note is recorded beside the state file (its DIRECTORY), never posted.
    Add-Content -Path (Join-Path (Split-Path $script:StateFile -Parent) "$Level.notes") -Value $Text -Encoding utf8
    return $true
}
'@)
            if ($stubbed -match '(?ms)^function Publish-HealthNote \{.*?^\}' -and $stubbed -match '\[System\.Diagnostics\.Process\]::Start') { throw 'the stubbed report still contains the process spawner' }
            $script:stubbedDir = Join-Path $TestDrive 'hc-script'
            New-Item -ItemType Directory -Path $script:stubbedDir -Force | Out-Null
            $script:stubbedPath = Join-Path $script:stubbedDir 'healthcheck-stubbed-4897-test.ps1'
            [System.IO.File]::WriteAllText($script:stubbedPath, $stubbed, (New-Object System.Text.UTF8Encoding($false)))

            function Invoke-Healthcheck {
                param(
                    [hashtable]$WindowSeed,
                    # A state file to seed BEFORE the ticks: lets a test pose an
                    # already-established GREEN report with an old heartbeat, so
                    # the next tick's publication reason is observable.
                    [hashtable]$PrevState,
                    [int]$Ticks = 2
                )
                $stateDir = Join-Path $TestDrive 'hc'
                New-Item -ItemType Directory -Path $stateDir -Force | Out-Null
                $wFile = Join-Path $stateDir 'skagent-window-state.json'
                Remove-Item $wFile -ErrorAction SilentlyContinue
                if ($WindowSeed) { $WindowSeed | ConvertTo-Json -Depth 5 | Set-Content -Path $wFile -Encoding utf8 }
                $hFile = Join-Path $stateDir 'healthcheck-state.json'
                Remove-Item $hFile -ErrorAction SilentlyContinue
                Remove-Item (Join-Path $stateDir '*.notes') -ErrorAction SilentlyContinue
                if ($PrevState) { $PrevState | ConvertTo-Json -Depth 5 | Set-Content -Path $hFile -Encoding utf8 }
                $script:hcExit = 0
                # Two ticks: the first establishes prevStatus, the second is the
                # one we judge -- otherwise "RED on the very first run" and "RED on
                # a transition" are indistinguishable.
                1..$Ticks | ForEach-Object {
                    & $script:stubbedPath -Scheduled -SkipE2E `
                        -StateFile $hFile -WatchdogStateFile $wFile -WatchdogStateNowUtc '2026-11-24T10:30:00Z'
                    $script:hcExit = $LASTEXITCODE
                }
                $script:hcState = Get-Content $hFile -Raw | ConvertFrom-Json
                $script:hcNotes = @(Get-ChildItem -Path (Join-Path $stateDir '*.notes') -ErrorAction SilentlyContinue | ForEach-Object { $_.Name })
            }
        }

        AfterAll {
            Remove-Item $script:stubbedPath -ErrorAction SilentlyContinue
        }

        It 'the report under test cannot post anything: the whole publisher is replaced' {
            $script:hcContent | Should -Match '\[System\.Diagnostics\.Process\]::Start' -Because 'the real publisher spawns the local server'
            $stubbedText = Get-Content $script:stubbedPath -Raw
            $stubbedText | Should -Not -Match '\[System\.Diagnostics\.Process\]::Start' -Because 'a leftover spawner in the test copy could post a real note'
            $stubbedText | Should -Match 'Add-Content -Path \(Join-Path \(Split-Path \$script:StateFile -Parent\)'
        }

        It 'a heartbeat due on a healthy window is the GREEN beat (the control for the red case above)' {
            Invoke-Healthcheck -WindowSeed @{
                schema = 2; windowFailures = @(); escalationOpen = $false; windowMinutes = 120
            } -PrevState @{ firstRunDone = $true; naReported = $false; lastNoteTs = 0; prevStatus = 'GREEN' } -Ticks 1
            $script:hcState.status | Should -Be 'GREEN'
            ($script:hcNotes -join ',') | Should -Match 'INFO'
            ($script:hcNotes -join ',') | Should -Not -Match 'WARN'
        }

        It 'a red window (3 failures inside 2 h, escalation open) makes the report RED even with every layer OK' {
            Invoke-Healthcheck -WindowSeed @{
                schema = 2
                windowFailures = @('2026-11-24T10:00:00Z', '2026-11-24T10:05:00Z', '2026-11-24T10:10:00Z')
                escalationOpen = $true; escalationId = 'watchdog-x'; escalationOpenedAt = '2026-11-24T10:10:00Z'
                windowMinutes = 120
            }
            $script:hcState.status | Should -Be 'RED'
            $script:hcExit | Should -BeExactly 1
            ($script:hcState.layers | ForEach-Object { $_.layer }) -join ',' | Should -Match 'sk-agent'
        }

        It 'a window holding ONE recent failure is not GREEN either (no GREEN while the window holds a failure)' {
            Invoke-Healthcheck -WindowSeed @{
                schema = 2
                windowFailures = @('2026-11-24T10:25:00Z')
                escalationOpen = $false
                windowMinutes = 120
            }
            $script:hcState.status | Should -Not -Be 'GREEN'
        }

        It 'a tick that owes a heartbeat while the window is red publishes RED, never the GREEN beat' {
            # (c) is about the HOURLY REPORT, not only about the status field: a
            # red tick whose heartbeat is due must reach the 'ongoing red' branch,
            # not the GREEN beat. lastNoteTs=0 makes the heartbeat due.
            Invoke-Healthcheck -WindowSeed @{
                schema = 2; windowFailures = @('2026-11-24T10:25:00Z'); escalationOpen = $false; windowMinutes = 120
            } -PrevState @{ firstRunDone = $true; naReported = $false; lastNoteTs = 0; prevStatus = 'RED' } -Ticks 1
            $script:hcState.status | Should -Be 'RED'
            ($script:hcNotes -join ',') | Should -Match 'WARN' -Because 'the red tick publishes a WARN'
            ($script:hcNotes -join ',') | Should -Not -Match 'INFO' -Because 'the INFO note is the GREEN beat'
            $warnFile = @($script:hcNotes | Where-Object { $_ -like 'WARN*' })[0]
            (Get-Content (Join-Path (Join-Path $TestDrive 'hc') $warnFile) -Raw) | Should -Match 'toujours RED'
        }

        It 'an empty window leaves the report GREEN (the stub layers really are healthy)' {
            Invoke-Healthcheck -WindowSeed @{
                schema = 2; windowFailures = @(); escalationOpen = $false; windowMinutes = 120
            }
            $layerSummary = ($script:hcState.layers | ForEach-Object { $_.layer + '=' + $_.status }) -join ' | '
            $script:hcState.status | Should -Be 'GREEN' -Because "layers=$layerSummary"
        }

        It 'an absent watchdog state file degrades to the old behaviour, never to a false RED' {
            Invoke-Healthcheck -WindowSeed $null
            $script:hcState.status | Should -Be 'GREEN'
        }

        It 'the healthcheck still contains no repair path (arbitrage #3495 is not weakened)' {
            $script:hcContent | Should -Not -Match '(?m)^\s*(Start-ScheduledTask|Stop-ScheduledTask|docker\s|&\s+docker)\b'
        }

        It 'Get-SkAgentWindowLayer is called by the report and its layer joins the failures' {
            $script:hcContent | Should -Match '\$skAgentWindowLayer = Get-SkAgentWindowLayer -Path \$WatchdogStateFile'
            $script:hcContent | Should -Match '\$failures \+= \$skAgentWindowLayer\.Layer'
        }

        It 'the horizon is read from the watchdog file, not from a copied literal' {
            $m = [regex]::Match($script:hcContent, '\$SkAgentWindowFallbackMinutes = (\d+)')
            $SkAgentWindowFallbackMinutes = [int]$m.Groups[1].Value
            . ([scriptblock]::Create((Get-FunctionSource 'ConvertTo-WindowUtc' -From $script:hcContent)))
            . ([scriptblock]::Create((Get-FunctionSource 'Get-SkAgentWindowLayer' -From $script:hcContent)))
            $wFile = Join-Path $TestDrive 'horizon.json'
            @{ windowFailures = @('2026-11-24T09:00:00Z'); escalationOpen = $false; windowMinutes = 30 } |
                ConvertTo-Json -Depth 5 | Set-Content -Path $wFile -Encoding utf8
            Get-SkAgentWindowLayer -Path $wFile -Now (Get-Utc '2026-11-24T10:30:00Z') | Should -BeNullOrEmpty -Because 'the watchdog armed a 30 min horizon, not 120'
        }

        It 'the default window path is derived from the WATCHDOG declared -LogDir, not a hardcoded copy' {
            $logDirDefault = ($script:ast.ParamBlock.Parameters | Where-Object { $_.Name.VariablePath.UserPath -eq 'LogDir' }).DefaultValue
            $logDirDefault | Should -Not -BeNullOrEmpty -Because 'installed with -File only, the watchdog runs on ITS default -LogDir: there must be one for the report to read'
            $m = [regex]::Match($script:hcContent, '(?ms)^if \(\[string\]::IsNullOrEmpty\(\$WatchdogStateFile\)\) \{.*?^\}')
            $m.Success | Should -BeTrue -Because 'the default-resolution block must be found'
            $block = $m.Value
            # $PSScriptRoot is automatic and read-only, and inside
            # Invoke-Expression it is EMPTY (measured) -- so the block under test
            # must be run from a FILE in the sandbox, with the sibling watchdog
            # source copied beside it. That is also the shape in which the health
            # report is installed on the host (-File, next to the watchdog).
            $sandbox = Join-Path $TestDrive 'hc-sandbox'
            New-Item -ItemType Directory -Path $sandbox -Force | Out-Null
            # The watchdog's real default is a Windows drive path, and Join-Path
            # resolves the DRIVE of what it is given: on a host without that drive
            # (ubuntu-latest, measured 24/11) the block under test throws
            # DriveNotFoundException before there is anything to compare. What is
            # pinned here is the DERIVATION -- the report reads the default from
            # the watchdog instead of copying a literal -- so the sandbox copy
            # declares a default that exists on every host. ONLY the literal is
            # replaced, at the AST extent of the real one: the param block keeps
            # its production shape, which the report's own regex must still match.
            $sandboxLogDir = Join-Path $sandbox 'watchdog-logs'
            $extent = $logDirDefault.Extent
            $copy = $script:content.Substring(0, $extent.StartOffset) + "'" + $sandboxLogDir + "'" + $script:content.Substring($extent.EndOffset)
            # Same BOM as the source: the copy differs from it by the literal only.
            $sourceBytes = [System.IO.File]::ReadAllBytes($script:watchdogPath)
            $hasBom = $sourceBytes.Length -ge 3 -and $sourceBytes[0] -eq 0xEF -and $sourceBytes[1] -eq 0xBB -and $sourceBytes[2] -eq 0xBF
            $wdCopy = Join-Path $sandbox 'mcp-chain-watchdog.ps1'
            [System.IO.File]::WriteAllText($wdCopy, $copy, (New-Object System.Text.UTF8Encoding($hasBom)))
            $driver = Join-Path $sandbox 'drive-default-path.ps1'
            $harness = @(
                "param([bool]`$StateFileGiven, [string]`$StateFile)",
                "`$WatchdogStateFile = ''",
                "function Write-TickLog { param(`$Level, `$Text) }",
                "`$declaredLogDir = $null",
                "",
                "# The block under test, verbatim, on its own lines -- the block",
                "# contains COMMENTS, so it must not be inlined on a param line.",
                ""
            ) -join [Environment]::NewLine
            [System.IO.File]::WriteAllText($driver, $harness + $block + [Environment]::NewLine + '$WatchdogStateFile', (New-Object System.Text.UTF8Encoding($false)))
            $out = & $driver -StateFileGiven $false -StateFile (Join-Path $TestDrive 'healthcheck-state.json')
            $out | Should -Be (Join-Path $sandboxLogDir 'skagent-window-state.json')

            # With an explicit -StateFile the window is looked up beside it.
            # One segment per Join-Path: a 'sub\file' child is not 'sub/file' on
            # every host.
            $subStateDir = Join-Path $TestDrive 'sub'
            $out2 = & $driver -StateFileGiven $true -StateFile (Join-Path $subStateDir 'healthcheck-state.json')
            $out2 | Should -Be (Join-Path $subStateDir 'skagent-window-state.json')
        }
    }

    Context 'static wiring of the watchdog (#4897)' {

        It 'the window lives in its OWN state file, never the #4197 counter file' {
            $script:content | Should -Match "skagent-window-state\.json"
            $script:windowSource | Should -Match '\$skAgentWindowStateFile'
            $script:checkSource | Should -Not -Match 'skagent-window-state' -Because 'the check must never write the window file'
            $script:windowSource | Should -Not -Match '\$skAgentRealCallStateFile'
            # Guard the ASSIGNMENT too, not just the function body: a mutant that
            # points $skAgentWindowStateFile at the #4197 counter file leaves the
            # four assertions above GREEN (measured by mutation). The captured
            # main-flow line is the declaration itself, so this discriminates.
            $script:windowPathLine | Should -Not -Match 'skagent-realcall-state' -Because 'the window must not persist where the route check rewrites wholesale'
            $script:windowPathLine | Should -Match "Join-Path \`$LogDir 'skagent-window-state\.json'"
        }

        It 'the window is updated at top level, AFTER the check, with its verdict' {
            $iCall   = $script:content.IndexOf('$skAgentCheckVerdict = Invoke-SkAgentRouteCheck')
            $iWindow = $script:content.IndexOf('Update-SkAgentFailureWindow -Kind $skAgentCheckVerdict')
            $iCall   | Should -BeGreaterThan 0
            $iWindow | Should -BeGreaterThan $iCall -Because 'the repair paths rewrite the counter file wholesale: the window update must come after them'
        }

        It 'the declared constants match the decision: 120 min, 3 failures, > 5 min repair gap' {
            $script:declaredWindowMinutes | Should -BeExactly 120
            $script:declaredThreshold     | Should -BeExactly 3
            $script:declaredRepairGapMin  | Should -BeExactly 5
        }

        It 'no automatic restart of the sk-agent container anywhere in the window path' {
            $script:windowSource | Should -Not -Match 'docker restart'
            $script:windowSource | Should -Match 'no automatic restart|no sk-agent container restart'
        }

        It 'the repair scope names the open posting hour plus the episode id, never the issue ref' {
            # The organ (check-degraded-escalations repair_names, #4746) matches a
            # scoped close on messageId, issue ref or posting hour. An id alone
            # stops matching after condensation (archive ids are formed at read
            # time, reported by ai-01 24/11), so the marker leads with the hour.
            $script:windowSource | Should -Match '"scope: \$scopeHour \$closedEpisodeId"'
            $script:windowSource | Should -Not -Match 'scope: \$closedEpisodeId"'
            # An issue ref in the OPEN body is a match key too: #4897 must not
            # appear in the open's text, or any scoped close citing it elsewhere
            # on this seat would close this escalation.
            $openText = [regex]::Match($script:windowSource, "(?s)Level     = 'DEGRADED'.*?Text      = (.*?)\n").Groups[1].Value
            $openText | Should -Not -Match '#4897' -Because 'an issue ref in the open body lets an unrelated scoped close name this escalation'
        }
    }
}
