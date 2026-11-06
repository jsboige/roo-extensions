<#
.SYNOPSIS
    re#4569 witness (#4131 G-DASH): a CLI that dies on STDERR still yields the
    file-based behaviour, under the SAME ErrorActionPreference the production
    script sets.

.DESCRIPTION
    Review re#4569 (ai-01, mesuré 23:54Z + repro po-204 5.1.26100.9711):
    poll-dashboard.ps1:101 sets EAP "Stop"; Invoke-RsmCliJson runs
    `& node ... 2>$null`; under PS 5.1 the redirected stderr of a native
    command becomes a TERMINATING ErrorRecord (RemoteException), so the
    `$LASTEXITCODE` branch is never reached and Resolve-Workspaces — called
    outside any try — aborts the whole poll instead of falling back to the
    file. pwsh 7 (7.6.9 measured) reaches the branch: the two runtimes
    diverge on this exact gesture.

    Witness contract: `rsm-dashboard-intercom.mjs --discover` failing on
    stderr + exit 1 (= PG-UNREACHABLE, the case the fallback exists for)
    must return the workspace-*.md discovery, and the per-workspace read
    must parse the file — with EAP "Stop" active, mirroring l.101.

    Method: AST function extraction (the poller runs a main loop, it cannot
    be dot-sourced) — same pattern as dashboard-listener-pg-path.Tests.ps1.
    The CLI is faked with a real node one-liner under a temp RSM root.

    Excluded from CI? No — unit suite, pure temp-dir effects. NB: on pwsh 7
    the stderr case passes with or without the guard (that engine makes
    native stderr non-terminating); the 5.1 kill is measured at review time
    — the drift-guard Context keeps the guard pinned engine-independently.
#>

Describe 'Poll-dashboard PG-path fail-open (re#4569 witness, #4131 G-DASH)' {
    BeforeAll {
        $repoRoot = (Resolve-Path "$PSScriptRoot\..\..\..").Path
        $script:PollPath = Join-Path $repoRoot 'scripts/dashboard-scheduler/poll-dashboard.ps1'

        $parseErrors = $null
        $tokens = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseFile(
            $script:PollPath, [ref]$tokens, [ref]$parseErrors)
        @($parseErrors) | Should -BeNullOrEmpty

        $defs = $ast.FindAll(
            { param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] },
            $true)
        foreach ($name in @('Write-Log', 'Get-RsmScriptsDir', 'Invoke-RsmCliJson',
                            'Resolve-Workspaces', 'Invoke-DashboardRead')) {
            $d = $defs | Where-Object Name -EQ $name | Select-Object -First 1
            if (-not $d) { throw "$name not found in $($script:PollPath)" }
            Invoke-Expression $d.Extent.Text
        }

        # Fake RSM root (the cache is wired directly — same seam note as the
        # listener suite: under Invoke-Expression $PSScriptRoot is empty, so
        # Get-RsmScriptsDir's sibling candidate cannot resolve; production has
        # a real $PSScriptRoot).
        $script:TmpRsm = Join-Path ([System.IO.Path]::GetTempPath()) ("gdpoll-" + [guid]::NewGuid().ToString('N').Substring(0, 8))
        New-Item -ItemType Directory -Path (Join-Path $script:TmpRsm 'scripts') -Force | Out-Null

        # SharedPath for the FILE fallbacks (poll-dashboard reads the env var).
        $script:TmpShared = Join-Path ([System.IO.Path]::GetTempPath()) ("gdpolls-" + [guid]::NewGuid().ToString('N').Substring(0, 8))
        New-Item -ItemType Directory -Path (Join-Path $script:TmpShared 'dashboards') -Force | Out-Null

        $script:SavedRsmRoot = $env:RSM_SERVER_ROOT
        $script:SavedWatcherWs = $env:DASHBOARD_WATCHER_WORKSPACES
        $script:SavedShared = $env:ROOSYNC_SHARED_PATH

        function Set-FakeCli([string]$JsCode) {
            [System.IO.File]::WriteAllText(
                (Join-Path $script:TmpRsm 'scripts/rsm-dashboard-intercom.mjs'),
                $JsCode, [System.Text.UTF8Encoding]::new($false))
        }
    }
    AfterAll {
        $env:RSM_SERVER_ROOT = $script:SavedRsmRoot
        $env:DASHBOARD_WATCHER_WORKSPACES = $script:SavedWatcherWs
        $env:ROOSYNC_SHARED_PATH = $script:SavedShared
        foreach ($d in @($script:TmpRsm, $script:TmpShared)) {
            if ($d -and (Test-Path $d)) { Remove-Item $d -Recurse -Force -ErrorAction SilentlyContinue }
        }
    }
    BeforeEach {
        $env:DASHBOARD_WATCHER_WORKSPACES = $null
        $env:ROOSYNC_SHARED_PATH = $script:TmpShared
        $script:RsmScriptsDirCache = Join-Path $script:TmpRsm 'scripts'
        Get-ChildItem (Join-Path $script:TmpShared 'dashboards') -File -ErrorAction SilentlyContinue |
            Remove-Item -Force -ErrorAction SilentlyContinue
    }

    Context 'witness - CLI dies on stderr + exit 1, EAP Stop active (l.101 mirrored)' {
        It 'discovery falls back to workspace-*.md instead of aborting the poll' {
            $ErrorActionPreference = 'Stop'   # poll-dashboard.ps1:101
            Set-FakeCli "process.stderr.write('PG-UNREACHABLE simulated`n'); process.exit(1);"
            'seed header' | Set-Content (Join-Path $script:TmpShared 'dashboards/workspace-fromfile.md')
            { $ws = Resolve-Workspaces } | Should -Not -Throw
            $ws = Resolve-Workspaces
            @($ws) | Should -Be @('fromfile')
        }
        It 'per-workspace read parses the FILE (PG stderr must not skip the workspace)' {
            $ErrorActionPreference = 'Stop'   # poll-dashboard.ps1:101
            Set-FakeCli "process.stderr.write('PG-UNREACHABLE simulated`n'); process.exit(1);"
            $seed = @(
                '# Dashboard workspace-wsfile',
                '',
                '## Intercom (1 messages)',
                '',
                '### [2026-11-06T00:00:00.000Z] myia-po-2023|roo-extensions',
                '',
                '[WAKE-CLAUDE] myia-po-2023:roo-extensions file wake',
                '---'
            ) -join "`r`n"
            [System.IO.File]::WriteAllText((Join-Path $script:TmpShared 'dashboards/workspace-wsfile.md'), $seed, [System.Text.UTF8Encoding]::new($false))
            $r = Invoke-DashboardRead 'wsfile'
            @($r.data.intercom.messages).Count | Should -Be 1
            $r.data.intercom.messages[0].content | Should -Be '[WAKE-CLAUDE] myia-po-2023:roo-extensions file wake'
        }
        It 'a HEALTHY CLI answer still wins over the file (the guard must not disable PG)' {
            $ErrorActionPreference = 'Stop'
            Set-FakeCli 'process.stdout.write(JSON.stringify({"mode":"discover","workspaces":["ws-a","ws-b"]}));'
            $ws = Resolve-Workspaces
            @($ws) | Should -Be @('ws-a', 'ws-b')
        }
    }

    Context 'drift-guards - the guard is pinned in the source' {
        BeforeAll {
            $script:Text = [System.IO.File]::ReadAllText($script:PollPath)
        }
        It 'the native CLI call is wrapped non-terminating (try/catch around & node ... 2>$null)' {
            $script:Text | Should -Match 'try \{\s*\$out = & \$node\.Source \(Join-Path \$dir \$scriptName\) @cliArgs 2>\$null\s*\} catch'
        }
        It 'production EAP is Stop (the condition the witness mirrors)' {
            $script:Text | Should -Match '(?m)^\$ErrorActionPreference = "Stop"'
        }
    }
}
