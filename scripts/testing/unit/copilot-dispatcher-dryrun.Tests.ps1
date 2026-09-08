# Pester 5 tests: -DryRun of start-copilot-dispatcher.ps1 must invoke NO CLI
# and write NO run state/report (#622, Copilot lane).
#
# Defect these tests pin (qualified 08/09 by the coordinator, dispatched to an
# isolated worker): the script's only DryRun guard sat at the very END, AFTER
# Invoke-PhaseCDispatch (the real `copilot -p --allow-all-tools --no-ask-user`
# paid call) and Save-State -- a -DryRun run burned a premium request and
# rewrote the run state, then logged "DryRun mode: no external actions".
#
# Design notes (what makes the assertions discriminating):
# * The dispatcher runs as a CHILD PROCESS of the same engine that runs this
#   suite (pwsh on the CI ubuntu runner, Windows PowerShell 5.1 locally),
#   against a TEMPORARY copy of the repo layout: the production script text,
#   its state dir and a git-initialized root all live under a per-test temp
#   dir. The production checkout is never executed nor touched.
# * `copilot` and `gh` are faked by PREPENDING a temp bin dir to PATH. The
#   fakes RECORD the invocation as their FIRST statement, before any output
#   or exit -- so "CLI invoked then failed" still leaves a record, while "no
#   invocation" leaves none. The assertions check for the RECORD, not for
#   the success of the call: that is the required discriminator between
#   absence of invocation and invocation that failed.
# * Anti-fallback: the spawn helper THROWS unless BOTH names resolve inside
#   the fake bin dir -- checked immediately before every child spawn, so a
#   red standalone It can never leave the mutation control running against
#   a real copilot/gh from the host (review of #3542). A separate It also
#   asserts the resolution so the failure reads as a clean test result.
# * Env isolation (review of #3542, second round): env vars read by the
#   script are enumerated per role. Only COPILOT_DISPATCHER_LOG_DIR has an
#   EXTERNAL effect -- it is the log target dir, and production may point it
#   outside repoRoot (script lines 31-35); a host value would write logs
#   outside the temp sandbox and break the local-trace test, so it is pinned
#   to the harness LogDir (and saved/restored). $env:APPDATA is pinned to the
#   harness (config-candidate fixture determinism). COPILOT_PREMIUM_USAGE_
#   PERCENT (read-only usage hint, only shifts $effectiveProfile, never
#   reached by the fixed path, no effect on the zero-burn/state/report
#   contract) and $HOME (read-only config-candidate fallback, never consulted
#   because the APPDATA fixture always wins) are deliberately NOT isolated.
# * Positive control (last test): runs a MUTATED copy of the script with the
#   early DryRun exit stripped -- i.e. the defect itself -- and asserts the
#   violation signals DO appear (paid `-p` call recorded, gh called, state
#   rewritten, report written). If the fakes or fixtures ever break, this
#   control goes red instead of the invariants above passing vacuously.

Describe 'Copilot dispatcher DryRun invariants' {

    BeforeAll {
        $script:productionScript = Join-Path $PSScriptRoot '../../scheduling/start-copilot-dispatcher.ps1'
        $script:fixedText = Get-Content -LiteralPath $script:productionScript -Raw
        $script:utf8Bom = [System.Text.UTF8Encoding]::new($true)

        $script:origPath = $env:PATH
        $script:origAppData = $env:APPDATA
        $script:origFakeLog = $env:COPILOT_FAKE_INVOCATION_LOG
        # COPILOT_DISPATCHER_LOG_DIR has an EXTERNAL effect (it is the log target
        # dir; production may externalize it outside repoRoot -- see the script
        # lines 31-35). A host value would write logs outside the temp sandbox
        # an, on the "local init trace" test, make it fail. Save/restore it.
        $script:origLogDir = $env:COPILOT_DISPATCHER_LOG_DIR
        $script:harnessRoots = @()

        # Engine that runs the dispatcher child: the SAME binary running this
        # suite (pwsh on CI; powershell.exe when the suite runs under 5.1).
        if ($PSVersionTable.PSVersion.Major -ge 6) {
            $script:engine = Join-Path $PSHOME 'pwsh'
        } else {
            $script:engine = Join-Path $PSHOME 'powershell.exe'
        }

        function New-DryRunHarness {
            param([string]$ScriptText)

            $root = Join-Path ([System.IO.Path]::GetTempPath()) ("copilot-dryrun-" + [guid]::NewGuid().ToString('N'))
            $script:harnessRoots += $root

            $repo = Join-Path $root 'repo'
            $scriptDir = Join-Path (Join-Path $repo 'scripts') 'scheduling'
            New-Item -ItemType Directory -Path $scriptDir -Force | Out-Null
            $scriptCopy = Join-Path $scriptDir 'start-copilot-dispatcher.ps1'
            [System.IO.File]::WriteAllText($scriptCopy, $ScriptText, $script:utf8Bom)

            # State fixture at the exact path the script computes
            # (Join-Path $repoRoot ".claude\scheduler"): on Linux the literal
            # backslash yields a single oddly-named directory -- mirroring the
            # script's own path math keeps the fixture portable both ways.
            $stateDir = Join-Path $repo '.claude\scheduler'
            New-Item -ItemType Directory -Path $stateDir -Force | Out-Null
            $stateFile = Join-Path $stateDir 'copilot-dispatcher-state.json'
            [System.IO.File]::WriteAllText($stateFile, $script:fixtureState, $script:utf8Bom)

            # git repo so the defective (mutated) run's git probes succeed
            # deterministically instead of relying on stderr suppression.
            & git -C $repo init -q
            if ($LASTEXITCODE -ne 0) { throw "git init failed in harness at $repo" }

            # Copilot MCP config candidate -- same expression as the script
            # (Join-Path $env:APPDATA "Code\User\mcp.json"). APPDATA points at
            # the harness so the config check passes deterministically and the
            # defective path can advance all the way to the dispatch.
            $appData = Join-Path $root 'appdata'
            $mcpConfig = Join-Path $appData 'Code\User\mcp.json'
            $mcpDir = Split-Path -Parent $mcpConfig
            New-Item -ItemType Directory -Path $mcpDir -Force | Out-Null
            [System.IO.File]::WriteAllText($mcpConfig, '{}', $script:utf8Bom)

            # Fake CLIs -- record-first (see file header).
            $bin = Join-Path $root 'bin'
            New-Item -ItemType Directory -Path $bin -Force | Out-Null
            $invocationLog = Join-Path $root 'cli-invocations.log'

            $copilotFake = @'
if ($env:COPILOT_FAKE_INVOCATION_LOG) {
    Add-Content -Path $env:COPILOT_FAKE_INVOCATION_LOG -Value ('copilot :: ' + (@($args) -join ' '))
}
if (@($args) -contains '--version') {
    'GitHub Copilot CLI 9.9.9-fake.'
    exit 0
}
if (@($args) -contains '--simulate-failure') {
    exit 42
}
'fake copilot reply -- dryrun harness'
exit 0
'@
            [System.IO.File]::WriteAllText((Join-Path $bin 'copilot.ps1'), $copilotFake, $script:utf8Bom)

            $ghFake = @'
if ($env:COPILOT_FAKE_INVOCATION_LOG) {
    Add-Content -Path $env:COPILOT_FAKE_INVOCATION_LOG -Value ('gh :: ' + (@($args) -join ' '))
}
if (@($args) -contains 'view') {
    '{"number":4242,"title":"Fix export widget parsing in build module","state":"OPEN","url":"https://example.invalid/issue/4242","labels":[]}'
    exit 0
}
'[]'
exit 0
'@
            [System.IO.File]::WriteAllText((Join-Path $bin 'gh.ps1'), $ghFake, $script:utf8Bom)

            # Default path math mirrored from the script (used by assertions).
            $logDir = Join-Path $repo 'outputs\scheduling\logs'
            $reportDir = Join-Path $repo 'outputs\scheduling\reports'

            return @{
                Root = $root
                Repo = $repo
                Script = $scriptCopy
                StateFile = $stateFile
                # SHA-256 of the fixture BYTES as written: the untouched-state
                # contract is byte-identical, and text comparison would equate
                # different byte sequences that decode to the same string
                # (review of #3542: ReadAllText compares text, not bytes).
                StateSha256 = (Get-FileSha256Hex -Path $stateFile)
                AppData = $appData
                Bin = $bin
                InvocationLog = $invocationLog
                LogDir = $logDir
                ReportDir = $reportDir
            }
        }

        function Set-HarnessEnv {
            param([hashtable]$Harness)
            $env:PATH = $Harness.Bin + [System.IO.Path]::PathSeparator + $script:origPath
            $env:APPDATA = $Harness.AppData
            $env:COPILOT_FAKE_INVOCATION_LOG = $Harness.InvocationLog
            # Pin the log dir INSIDE the sandbox: production honors this
            # override (script line 31), so the child logs to the temp dir
            # regardless of any host value. Prevents a host-configured
            # external log path from swallowing the sandbox log.
            $env:COPILOT_DISPATCHER_LOG_DIR = $Harness.LogDir
        }

        function Get-FileSha256Hex {
            param([string]$Path)
            $bytes = [System.IO.File]::ReadAllBytes($Path)
            $sha = [System.Security.Cryptography.SHA256]::Create()
            try {
                $hash = $sha.ComputeHash($bytes)
            } finally {
                $sha.Dispose()
            }
            return ([System.BitConverter]::ToString($hash) -replace '-', '')
        }

        function Invoke-DispatcherDryRun {
            param([hashtable]$Harness)

            # Anti-fallback gate -- RAISING, checked before EVERY child spawn,
            # inside the helper (review of #3542: a standalone It does not
            # gate anything; if it fails, Pester would still run the mutation
            # control against a possibly-real CLI). Both exact names must
            # resolve inside the fake bin dir or we refuse to spawn at all.
            foreach ($name in @('copilot', 'gh')) {
                $resolved = Get-Command $name -ErrorAction SilentlyContinue
                if (-not $resolved) {
                    throw ("Anti-fallback gate: '{0}' does not resolve on PATH at all -- refusing to spawn the dispatcher child" -f $name)
                }
                if (-not ($resolved.Source.StartsWith($Harness.Bin, [System.StringComparison]::OrdinalIgnoreCase))) {
                    throw ("Anti-fallback gate: '{0}' resolves to '{1}' outside the fake bin dir '{2}' -- refusing to spawn the dispatcher child against a real executable" -f $name, $resolved.Source, $Harness.Bin)
                }
            }

            $engineArgs = @('-NoProfile')
            if ($env:OS -eq 'Windows_NT') {
                $engineArgs += @('-ExecutionPolicy', 'Bypass')
            }
            $engineArgs += @('-File', $Harness.Script, '-DryRun', '-IssueNumber', '4242')

            # EAP scoped to Continue around the child call (same pattern as the
            # production script): on pwsh 7.2+ a child stderr line captured via
            # 2>&1 under EAP Stop would throw in the TEST process instead of
            # being captured as diagnostic output.
            $prevEap = $ErrorActionPreference
            $ErrorActionPreference = 'Continue'
            try {
                $output = & $script:engine @engineArgs 2>&1
                $exitCode = $LASTEXITCODE
            } finally {
                $ErrorActionPreference = $prevEap
            }
            return @{
                ExitCode = $exitCode
                Output = ((@($output) | ForEach-Object { [string]$_ }) -join "`n")
            }
        }

        # Fixture written by the harness; also the exact bytes the untouched
        # state file must still show after a DryRun run.
        $script:fixtureState = '{"consecutiveBlocked":0,"consecutiveIdle":0,"lastStatus":"none","lastEscalation":"none","lastEscalationAt":"","escalationWindowStart":"","escalationsInWindow":0,"dryrunFixtureSentinel":"untouched"}'
    }

    BeforeEach {
        $script:harness = New-DryRunHarness -ScriptText $script:fixedText
        Set-HarnessEnv -Harness $script:harness
    }

    AfterEach {
        if ($script:harness -and (Test-Path -LiteralPath $script:harness.Root)) {
            Remove-Item -LiteralPath $script:harness.Root -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    AfterAll {
        $env:PATH = $script:origPath
        $env:APPDATA = $script:origAppData
        $env:COPILOT_FAKE_INVOCATION_LOG = $script:origFakeLog
        $env:COPILOT_DISPATCHER_LOG_DIR = $script:origLogDir
        foreach ($root in $script:harnessRoots) {
            if ($root -and (Test-Path -LiteralPath $root)) {
                Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }

    It 'Anti-fallback: copilot and gh resolve to the fakes, not the host executables' {
        $copilot = Get-Command copilot -ErrorAction SilentlyContinue
        $copilot | Should -Not -BeNullOrEmpty
        $copilot.Source | Should -BeLike ($script:harness.Bin + '*')

        $gh = Get-Command gh -ErrorAction SilentlyContinue
        $gh | Should -Not -BeNullOrEmpty
        $gh.Source | Should -BeLike ($script:harness.Bin + '*')
    }

    It '-DryRun exits 0 and invokes NO CLI (no invocation record at all)' {
        $result = Invoke-DispatcherDryRun -Harness $script:harness

        $result.ExitCode | Should -Be 0
        # The fakes record BEFORE anything else: an invoked-then-failed CLI
        # would leave a record. Absence of the file therefore proves absence
        # of the invocation, not absence of its success.
        $script:harness.InvocationLog | Should -Not -Exist
    }

    It '-DryRun leaves the run state file byte-identical (SHA-256 of the bytes)' {
        $result = Invoke-DispatcherDryRun -Harness $script:harness

        $result.ExitCode | Should -Be 0
        Get-FileSha256Hex -Path $script:harness.StateFile | Should -Be $script:harness.StateSha256
    }

    It '-DryRun writes no work report' {
        $result = Invoke-DispatcherDryRun -Harness $script:harness

        $result.ExitCode | Should -Be 0
        $reports = @(Get-ChildItem -LiteralPath $script:harness.ReportDir -Filter 'copilot-dispatcher-*.md' -ErrorAction SilentlyContinue)
        $reports.Count | Should -Be 0
    }

    It '-DryRun still produces the local init trace (guard reached, not crashed)' {
        $result = Invoke-DispatcherDryRun -Harness $script:harness

        # Zero CLI calls would also be true of a child that crashed at parse
        # time. The log lines prove the script actually ran to the early exit:
        # startup trace + the DryRun announcement written by the guard itself.
        $result.ExitCode | Should -Be 0
        $logFiles = @(Get-ChildItem -LiteralPath $script:harness.LogDir -Filter 'copilot-dispatcher-*.log' -ErrorAction SilentlyContinue)
        $logFiles.Count | Should -BeGreaterThan 0
        $newest = $logFiles | Sort-Object LastWriteTime -Descending | Select-Object -First 1
        $content = Get-Content -LiteralPath $newest.FullName -Raw
        $content | Should -Match 'Copilot dispatcher started'
        $content | Should -Match 'DryRun mode: exiting before any CLI call'
    }

    It 'NON-REGRESSION: COPILOT_DISPATCHER_LOG_DIR override is honored, but pinned inside the sandbox' {
        # Production externalizes the log dir when the env var is set (script
        # line 31). This control proves the override is honored WITHOUT writing
        # to any real location: the override points at a path INSIDE the
        # sandbox, and the default harness LogDir must stay empty.
        $altLogDir = Join-Path $script:harness.Root 'alt-logs'
        $env:COPILOT_DISPATCHER_LOG_DIR = $altLogDir
        try {
            $result = Invoke-DispatcherDryRun -Harness $script:harness

            $result.ExitCode | Should -Be 0
            $altLogs = @(Get-ChildItem -LiteralPath $altLogDir -Filter 'copilot-dispatcher-*.log' -ErrorAction SilentlyContinue)
            $altLogs.Count | Should -BeGreaterThan 0
            # The default (non-overridden) location must NOT have received logs:
            @(Get-ChildItem -LiteralPath $script:harness.LogDir -Filter 'copilot-dispatcher-*.log' -ErrorAction SilentlyContinue).Count | Should -Be 0
        } finally {
            $env:COPILOT_DISPATCHER_LOG_DIR = $script:harness.LogDir
        }
    }

    It 'Record-first discriminator: a fake invocation that FAILS still leaves a record' {
        # Pins the property the "no invocation" assertion rests on: the fakes
        # log the invocation before doing anything. If someone moves the
        # Add-Content below the work, "no record" could start meaning "called
        # and failed to log" -- and this test would go red first.
        & (Join-Path $script:harness.Bin 'copilot.ps1') -p probe --simulate-failure

        $LASTEXITCODE | Should -Be 42
        $script:harness.InvocationLog | Should -Exist
        (Get-Content -LiteralPath $script:harness.InvocationLog -Raw) | Should -Match ([regex]::Escape('copilot :: -p probe --simulate-failure'))
    }

    It 'POSITIVE CONTROL: with the early DryRun exit stripped (the defect), the harness DOES detect the paid call, the state rewrite and the report' {
        # Mutate a copy of the FIXED script: remove the early-exit block. The
        # resulting file reproduces the original defect for every observable
        # asserted below (guard placement was the only difference).
        $pattern = '(?s)# DryRun MUST terminate here.*?if \(\$DryRun\) \{.*?\r?\n\}'
        $mutated = $script:fixedText -replace $pattern, ''

        # Mutation validity: if the anchor text drifts (rename, refactor),
        # FAIL LOUDLY here rather than shipping a control that proves nothing.
        $mutated | Should -Not -Be $script:fixedText
        $mutated | Should -Not -Match 'exiting before any CLI call'

        [System.IO.File]::WriteAllText($script:harness.Script, $mutated, $script:utf8Bom)

        $result = Invoke-DispatcherDryRun -Harness $script:harness

        $result.ExitCode | Should -Be 0

        $records = Get-Content -LiteralPath $script:harness.InvocationLog -Raw
        # The paid dispatch itself was invoked (this is what -DryRun must
        # never do), and the version probe before it:
        $records | Should -Match ([regex]::Escape('copilot :: --version'))
        # (?s): the work prompt is one multi-line argument, so the recorded
        # invocation spans several physical lines before the flags.
        $records | Should -Match '(?s)copilot :: -p .*--allow-all-tools --no-ask-user'
        # gh was called for target discovery:
        $records | Should -Match ([regex]::Escape('gh :: issue view'))
        # The state file was rewritten (bytes differ from the fixture):
        Get-FileSha256Hex -Path $script:harness.StateFile | Should -Not -Be $script:harness.StateSha256
        # A work report was written:
        $reports = @(Get-ChildItem -LiteralPath $script:harness.ReportDir -Filter 'copilot-dispatcher-*.md' -ErrorAction SilentlyContinue)
        $reports.Count | Should -BeGreaterThan 0
    }
}
