<#
.SYNOPSIS
    G-C step 2 (#4131): the four dashboard I/O sites route PG-first through the
    submodule CLIs, file paths kept as fail-open fallbacks.

.DESCRIPTION
    Sites recabled in dashboard-listener.ps1 (PR #4203):
      1. Resolve-Workspaces      -> rsm-dashboard-intercom.mjs --discover
      2. Read-DashboardMessages  -> --workspace <ws>
      3. poll change test        -> --max-created (batch, via Update-PollMaxCreatedCache)
      4. Write-MachineDashboardMessage (escalation) -> rsm-dashboard-append.mjs

    Contract under test (the pilot 21/10 relies on it): EVERY CLI failure mode
    (unresolved RSM root, missing CLIs, non-zero exit, broken JSON) leaves the
    listener on its previous file-based behaviour.

    The site-2 tests also pin the TIMESTAMP NORMALIZATION (review c.556,
    measured): under pwsh 7 — the production runtime, Claude-DashboardListener.vbs
    launches pwsh.exe — ConvertFrom-Json deserializes ISO-8601 to [DateTime],
    while the file path yields STRING ISO. Without normalization, l.~900's
    [DateTime]::Parse stringifies to invariant "10/14/2026 18:00:00", which
    throws under fr-FR — silently swallowed, bypassing the lastAck filter
    (stale WAKE re-fires). The PG path must yield the SAME shape as the file
    path on BOTH runtimes.

    Method: AST function extraction (the listener runs a single-instance mutex
    and a main loop, so it cannot be dot-sourced) — same pattern as
    dashboard-listener-definitive-skip.Tests.ps1. The CLIs are faked with tiny
    node one-liners under a temp RSM root (exercising the REAL invocation path:
    node + script path + args + exit code), wired through $env:RSM_SERVER_ROOT.

    Excluded from CI? No — unit suite, pure temp-dir effects.
#>

Describe 'Listener PG-path recabling (G-C step 2, #4203)' {
    BeforeAll {
        $repoRoot = (Resolve-Path "$PSScriptRoot\..\..\..").Path
        $listenerPath = Join-Path $repoRoot 'scripts/dashboard-scheduler/dashboard-listener.ps1'

        $parseErrors = $null
        $tokens = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseFile(
            $listenerPath, [ref]$tokens, [ref]$parseErrors)
        @($parseErrors) | Should -BeNullOrEmpty

        $defs = $ast.FindAll(
            { param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] },
            $true)
        foreach ($name in @('Invoke-RsmCliJson', 'Get-RsmScriptsDir', 'Read-DashboardMessages',
                            'Resolve-Workspaces', 'Write-MachineDashboardMessage')) {
            $d = $defs | Where-Object Name -EQ $name | Select-Object -First 1
            if (-not $d) { throw "$name not found in $listenerPath" }
            Invoke-Expression $d.Extent.Text
        }

        # Dependencies of the extracted functions, in this scope.
        function Write-Log { param($level, $msg) }

        # Fake RSM root (env override — first candidate of Get-RsmScriptsDir):
        # scripts/ holds CLI stand-ins the helpers will really execute.
        $script:TmpRsm = Join-Path ([System.IO.Path]::GetTempPath()) ("gc2cli-" + [guid]::NewGuid().ToString('N').Substring(0, 8))
        New-Item -ItemType Directory -Path (Join-Path $script:TmpRsm 'scripts') -Force | Out-Null

        # SharedPath for the FILE fallbacks exercised below.
        $script:TmpShared = Join-Path ([System.IO.Path]::GetTempPath()) ("gc2sh-" + [guid]::NewGuid().ToString('N').Substring(0, 8))
        New-Item -ItemType Directory -Path (Join-Path $script:TmpShared 'dashboards') -Force | Out-Null

        # Env save/restore: RSM_SERVER_ROOT routes Get-RsmScriptsDir to the
        # fake root; DASHBOARD_WATCHER_WORKSPACES must not short-circuit
        # Resolve-Workspaces.
        $script:SavedRsmRoot = $env:RSM_SERVER_ROOT
        $script:SavedWatcherWs = $env:DASHBOARD_WATCHER_WORKSPACES

        function Set-FakeCli([string]$Name, [string]$JsCode) {
            [System.IO.File]::WriteAllText((Join-Path $script:TmpRsm "scripts/$Name"), $JsCode, [System.Text.UTF8Encoding]::new($false))
        }
    }
    AfterAll {
        $env:RSM_SERVER_ROOT = $script:SavedRsmRoot
        $env:DASHBOARD_WATCHER_WORKSPACES = $script:SavedWatcherWs
        foreach ($d in @($script:TmpRsm, $script:TmpShared)) {
            if ($d -and (Test-Path $d)) { Remove-Item $d -Recurse -Force -ErrorAction SilentlyContinue }
        }
    }
    BeforeEach {
        $env:DASHBOARD_WATCHER_WORKSPACES = $null
        $SharedPath = $script:TmpShared      # file-fallback root
        # NB: the tests wire $script:RsmScriptsDirCache DIRECTLY instead of
        # exercising Get-RsmScriptsDir's resolution — under Invoke-Expression
        # $PSScriptRoot is empty, so the sibling-candidate Join-Path throws
        # before the env candidate is ever read (production has a real
        # $PSScriptRoot; the harness does not). The cache is the seam.
        $script:RsmScriptsDirCache = Join-Path $script:TmpRsm 'scripts'
        # wipe file-fallback state between tests (unique ws names per test too)
        Get-ChildItem (Join-Path $script:TmpShared 'dashboards') -File -ErrorAction SilentlyContinue |
            Remove-Item -Force -ErrorAction SilentlyContinue
    }

    Context 'site 2 - Read-DashboardMessages via PG (happy path + normalization)' {
        It 'returns listener-shaped rows with STRING ISO timestamps (pwsh 7 deserializes DateTime — review c.556)' {
            Set-FakeCli 'rsm-dashboard-intercom.mjs' ('process.stdout.write(JSON.stringify(' + '{"mode":"messages","workspace":"wsx","count":1,"messages":[{"timestamp":"2026-10-14T18:00:00.123Z","content":"[WAKE-CLAUDE] m:w","author":{"machineId":"m","workspace":"w"}}]}' + '));')
            $msgs = Read-DashboardMessages 'wsx'
            @($msgs).Count | Should -Be 1
            $msgs[0].timestamp | Should -BeOfType [string]
            $msgs[0].timestamp | Should -Be '2026-10-14T18:00:00.123Z'
            $msgs[0].content | Should -Be '[WAKE-CLAUDE] m:w'
            $msgs[0].author.machineId | Should -Be 'm'
            $msgs[0].author.workspace | Should -Be 'w'
        }
        It 'treats an empty journal answer (count 0) as valid — no fallback to the file that HAS a message' {
            # Bootstrap a real dashboard file via the file writer itself
            # (cache="" forces its legacy path), then prove the PG answer wins.
            $script:RsmScriptsDirCache = ""
            $f = Join-Path $script:TmpShared 'dashboards/workspace-wsemb.md'
            Write-MachineDashboardMessage $f 'myia-po-2023' '[WARN] seed message for fallback' | Out-Null
            $script:RsmScriptsDirCache = Join-Path $script:TmpRsm 'scripts'
            Set-FakeCli 'rsm-dashboard-intercom.mjs' 'process.stdout.write(JSON.stringify({"mode":"messages","workspace":"wsemb","count":0,"messages":[]}));'
            $msgs = Read-DashboardMessages 'wsemb'
            @($msgs).Count | Should -Be 0
        }
        It 'fail-open: unresolved RSM root falls back to the file path (string ISO, pre-existing behaviour)' {
            $script:RsmScriptsDirCache = ""
            $f = Join-Path $script:TmpShared 'dashboards/workspace-wsfile.md'
            Write-MachineDashboardMessage $f 'myia-po-2023' '[WAKE-CLAUDE] myia-po-2023:roo-extensions file wake' | Out-Null
            $msgs = Read-DashboardMessages 'wsfile'
            @($msgs).Count | Should -BeGreaterThan 0
            $msgs[0].timestamp | Should -BeOfType [string]
            $msgs[0].content | Should -Be '[WAKE-CLAUDE] myia-po-2023:roo-extensions file wake'
        }
    }

    Context 'Invoke-RsmCliJson - fail-open contract (every failure yields $null)' {
        It 'non-zero exit (PG-UNREACHABLE or usage) returns $null' {
            Set-FakeCli 'rsm-dashboard-intercom.mjs' 'process.exit(2);'
            Invoke-RsmCliJson 'rsm-dashboard-intercom.mjs' @('--discover') | Should -BeNullOrEmpty
        }
        It 'broken JSON returns $null' {
            Set-FakeCli 'rsm-dashboard-intercom.mjs' "process.stdout.write('not json');"
            Invoke-RsmCliJson 'rsm-dashboard-intercom.mjs' @('--discover') | Should -BeNullOrEmpty
        }
        It 'missing CLI script returns $null (node exit non-zero, no crash leaks)' {
            Remove-Item (Join-Path $script:TmpRsm 'scripts/rsm-dashboard-intercom.mjs') -Force -ErrorAction SilentlyContinue
            Invoke-RsmCliJson 'rsm-dashboard-intercom.mjs' @('--discover') | Should -BeNullOrEmpty
        }
    }

    Context 'site 1 - Resolve-Workspaces via PG discover' {
        It 'returns the journal workspaces (empty entries filtered), skipping file enumeration' {
            Set-FakeCli 'rsm-dashboard-intercom.mjs' 'process.stdout.write(JSON.stringify({"mode":"discover","workspaces":["ws-a","","ws-b"]}));'
            $ws = Resolve-Workspaces
            @($ws) | Should -Be @('ws-a', 'ws-b')
        }
        It 'fail-open: unresolved RSM root falls back to workspace-*.md enumeration' {
            $script:RsmScriptsDirCache = ""
            'seed header' | Set-Content (Join-Path $script:TmpShared 'dashboards/workspace-fromfile.md')
            $ws = Resolve-Workspaces
            @($ws) | Should -Be @('fromfile')
        }
    }

    Context 'site 4 - Write-MachineDashboardMessage escalation append' {
        It 'CLI ok: returns the journal messageId, writes NO local file' {
            Set-FakeCli 'rsm-dashboard-append.mjs' 'process.stdout.write(JSON.stringify({"ok":true,"key":"machine-myia-po-2023","messageId":"myia-po-2023:listener:ic-fake","pgSynced":true}));'
            $f = Join-Path $script:TmpShared 'dashboards/machine-myia-po-2023.md'
            $id = Write-MachineDashboardMessage $f 'myia-po-2023' '[WARN][LISTENER][#3761] test escalation'
            $id | Should -Be 'myia-po-2023:listener:ic-fake'
            Test-Path $f | Should -BeFalse
        }
        It 'CLI exit 1 (file-write failure inside the CLI): falls back to the legacy file write' {
            Set-FakeCli 'rsm-dashboard-append.mjs' 'process.exit(1);'
            $f = Join-Path $script:TmpShared 'dashboards/machine-myia-po-2023.md'
            $id = Write-MachineDashboardMessage $f 'myia-po-2023' '[WARN][LISTENER][#3761] test escalation'
            $id | Should -BeLike 'myia-po-2023:listener:ic-*'
            Test-Path $f | Should -BeTrue
        }
        It 'CLI broken JSON: falls back to the legacy file write' {
            Set-FakeCli 'rsm-dashboard-append.mjs' "process.stdout.write('not json');"
            $f = Join-Path $script:TmpShared 'dashboards/machine-myia-po-2023.md'
            Write-MachineDashboardMessage $f 'myia-po-2023' '[WARN] broken json fallback' | Out-Null
            Test-Path $f | Should -BeTrue
        }
    }

    Context 'drift-guards - wiring pinned in the listener source' {
        BeforeAll {
            $script:Text = [System.IO.File]::ReadAllText($listenerPath)
        }
        It 'site 2 normalizes DateTime timestamps to ISO strings (review c.556 fix)' {
            $script:Text | Should -Match '\$_\.timestamp -is \[datetime\]'
            $script:Text | Should -Match "yyyy-MM-dd'T'HH:mm:ss\.fff'Z'"
        }
        It 'the four sites consult the CLIs with the file fallbacks retained' {
            $script:Text | Should -Match 'Invoke-RsmCliJson "rsm-dashboard-intercom\.mjs" @\(''--discover''\)'
            $script:Text | Should -Match 'Invoke-RsmCliJson "rsm-dashboard-intercom\.mjs" @\(''--workspace'', \$ws\)'
            $script:Text | Should -Match "Invoke-RsmCliJson `"rsm-dashboard-intercom\.mjs`" @\('--max-created'"
            $script:Text | Should -Match 'Invoke-RsmCliJson "rsm-dashboard-append\.mjs"'
            $script:Text | Should -Match 'Get-ChildItem -Path \$dbDir'
            $script:Text | Should -Match 'Get-DashboardFileLWT \$dashboardDir \$ws'
        }
        It 'the definitive-skip harness extracts the CLI helpers (review Hermes 18:16Z — CI red at first head)' {
            $harness = [System.IO.File]::ReadAllText((Join-Path $repoRoot 'scripts/testing/unit/dashboard-listener-definitive-skip.Tests.ps1'))
            $harness | Should -Match "'Invoke-RsmCliJson', 'Get-RsmScriptsDir'"
            $harness | Should -Match 'RsmScriptsDirCache = ""'
        }
    }
}
