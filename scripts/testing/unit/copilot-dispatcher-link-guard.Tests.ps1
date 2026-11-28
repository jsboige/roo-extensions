# Pester tests: the Copilot dispatcher must PARK on a billed or unclassifiable
# link BEFORE any external call (28/11, po-2027).
#
# Defect these tests pin: the 12 h tick started whatever the link was. One
# Copilot run is unbounded in volume (shim download, git work, pushes), and the
# 2026-10-26 leak measured what a scheduled task that relaunches heavy work on a
# metered link does. The guard reads scripts/monitoring/test-link-billed.ps1 and
# parks on anything but UNBILLED, writing no run state (a parked lane is not an
# idle streak).
#
# Design notes (same doctrine as copilot-dispatcher-dryrun.Tests.ps1):
# * The dispatcher runs as a CHILD PROCESS of the same engine that runs this
#   suite, against a TEMPORARY copy of the repo layout. The production checkout
#   is never executed nor touched.
# * `copilot` and `gh` are faked by PREPENDING a temp bin dir to PATH. The fakes
#   RECORD the invocation FIRST, so "no record" proves absence of the
#   invocation, not absence of its success.
# * The link probe is a SANDBOX STUB with a pinned verdict: the real probe reads
#   the HOST's live link, so the outcome of this suite would otherwise depend on
#   the network of the machine running it.
# * Positive control: with the park stripped, the SAME billed fixture reaches the
#   paid `copilot -p` call -- so the park, and not a fixture accident, is what
#   the first test measures.
#
# Run:  powershell -File scripts/testing/run-pester-tests.ps1 -Path scripts/testing/unit/copilot-dispatcher-link-guard.Tests.ps1

Describe 'Copilot dispatcher billed-link park (28/11)' {

    BeforeAll {
        $script:productionScript = Join-Path $PSScriptRoot '../../scheduling/start-copilot-dispatcher.ps1'
        $script:fixedText = Get-Content -LiteralPath $script:productionScript -Raw
        $script:utf8Bom = [System.Text.UTF8Encoding]::new($true)

        $script:origPath = $env:PATH
        $script:origAppData = $env:APPDATA
        $script:origFakeLog = $env:COPILOT_FAKE_INVOCATION_LOG
        $script:origLogDir = $env:COPILOT_DISPATCHER_LOG_DIR
        $script:harnessRoots = @()

        # Stub link probes: one line whose FIRST WORD is the verdict, then the
        # exit code of the shipped contract (0 UNBILLED / 3 BILLED). ASCII only --
        # they run as a child of either engine. The line goes through
        # Write-Output exactly like the real probe: a BARE line would be parsed
        # as a command and its text would land on stderr, leaving the guard with
        # no verdict word (measured: that read as `probe-exit=3` only).
        $script:stubUnbilled = "Write-Output 'UNBILLED profile=harness adapter=none cost=Unrestricted'`nexit 0`n"
        $script:stubBilled = "Write-Output 'BILLED reason=harness-metered cost=Fixed'`nexit 3`n"

        # Engine that runs the dispatcher child: the SAME binary running this
        # suite (pwsh on CI; powershell.exe when the suite runs under 5.1).
        if ($PSVersionTable.PSVersion.Major -ge 6) {
            $script:engine = Join-Path $PSHOME 'pwsh'
        } else {
            $script:engine = Join-Path $PSHOME 'powershell.exe'
        }

        function New-LinkHarness {
            param(
                [string]$ScriptText,
                # UNBILLED | BILLED | MISSING (no probe file in the sandbox)
                [string]$Probe = 'UNBILLED'
            )

            $root = Join-Path ([System.IO.Path]::GetTempPath()) ("copilot-linkguard-" + [guid]::NewGuid().ToString('N'))
            $script:harnessRoots += $root

            $repo = Join-Path $root 'repo'
            $scriptDir = Join-Path (Join-Path $repo 'scripts') 'scheduling'
            New-Item -ItemType Directory -Path $scriptDir -Force | Out-Null
            $scriptCopy = Join-Path $scriptDir 'start-copilot-dispatcher.ps1'
            [System.IO.File]::WriteAllText($scriptCopy, $ScriptText, $script:utf8Bom)

            # The dispatcher dot-sources ..\common\gh-issues.ps1 and
            # ..\common\gh-pull-requests.ps1: mirror the script's own path math
            # (same comment as the dryrun suite).
            foreach ($moduleName in @('gh-issues.ps1', 'gh-pull-requests.ps1')) {
                $moduleSrc = Join-Path $PSScriptRoot "../../common/$moduleName"
                $moduleDst = Join-Path $scriptDir "..\common\$moduleName"
                New-Item -ItemType Directory -Path (Split-Path -Parent $moduleDst) -Force | Out-Null
                Copy-Item -LiteralPath $moduleSrc -Destination $moduleDst -Force
            }

            # Link probe stub, at the path the guard derives (two-step Join-Path,
            # so it resolves on Windows and on Linux alike).
            if ($Probe -ne 'MISSING') {
                $probeDir = Join-Path (Join-Path $repo 'scripts') 'monitoring'
                New-Item -ItemType Directory -Path $probeDir -Force | Out-Null
                $stubText = if ($Probe -eq 'BILLED') { $script:stubBilled } else { $script:stubUnbilled }
                [System.IO.File]::WriteAllText((Join-Path $probeDir 'test-link-billed.ps1'), $stubText, $script:utf8Bom)
            }

            # State fixture at the exact path the script computes, with a
            # sentinel the untouched/rewritten distinction can lean on.
            $stateDir = Join-Path $repo '.claude\scheduler'
            New-Item -ItemType Directory -Path $stateDir -Force | Out-Null
            $stateFile = Join-Path $stateDir 'copilot-dispatcher-state.json'
            [System.IO.File]::WriteAllText($stateFile, '{"consecutiveBlocked":0,"consecutiveIdle":0,"lastStatus":"none","lastEscalation":"none","lastEscalationAt":"","escalationWindowStart":"","escalationsInWindow":0,"linkGuardSentinel":"untouched"}', $script:utf8Bom)

            # git repo with an origin: the queue slug is derived from it.
            & git -C $repo init -q
            if ($LASTEXITCODE -ne 0) { throw "git init failed in harness at $repo" }
            & git -C $repo remote add origin https://github.com/jsboige/sandbox-fixture.git
            if ($LASTEXITCODE -ne 0) { throw "git remote add failed in harness at $repo" }

            # Copilot MCP config candidate under a pinned APPDATA.
            $appData = Join-Path $root 'appdata'
            $mcpConfig = Join-Path $appData 'Code\User\mcp.json'
            New-Item -ItemType Directory -Path (Split-Path -Parent $mcpConfig) -Force | Out-Null
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
'fake copilot reply -- linkguard harness'
exit 0
'@
            [System.IO.File]::WriteAllText((Join-Path $bin 'copilot.ps1'), $copilotFake, $script:utf8Bom)

            # gh fake: REST legs only. Pool leg serves ONE actionable issue; the
            # detail leg serves the same issue; everything else is an empty list.
            $ghFake = @'
if ($env:COPILOT_FAKE_INVOCATION_LOG) {
    Add-Content -Path $env:COPILOT_FAKE_INVOCATION_LOG -Value ('gh :: ' + (@($args) -join ' '))
}
$joined = @($args) -join ' '
if ($joined -match '/issues\?') {
    '{"number":4242,"title":"Fix export widget parsing in build module","body":"","state":"OPEN","url":"https://example.invalid/issue/4242","updatedAt":"2026-11-10T00:00:00Z","labels":[],"assignees":[],"is_pr":false}'
    exit 0
}
if ($joined -match '/issues/\d+') {
    '{"number":4242,"title":"Fix export widget parsing in build module","body":"","state":"OPEN","url":"https://example.invalid/issue/4242","updatedAt":"2026-11-10T00:00:00Z","labels":[],"assignees":[],"is_pr":false}'
    exit 0
}
'[]'
exit 0
'@
            [System.IO.File]::WriteAllText((Join-Path $bin 'gh.ps1'), $ghFake, $script:utf8Bom)

            # Target clone for the retarget pair: a real git repo with a seed
            # commit, repo-local identity (CI ubuntu runners carry no global git
            # user -- same lesson as the retarget suite).
            $targetClone = Join-Path $root 'target-clone'
            New-Item -ItemType Directory -Path $targetClone | Out-Null
            & git -C $targetClone init -q -b main 2>$null
            if ($LASTEXITCODE -ne 0) { & git -C $targetClone init -q 2>$null }
            & git -C $targetClone config user.name 'copilot-dispatcher-test'
            & git -C $targetClone config user.email 'copilot-test@example.invalid'
            & git -C $targetClone commit -q --allow-empty -m 'seed'
            if ($LASTEXITCODE -ne 0) { throw 'seed commit failed in the link-guard harness target clone (git identity?)' }

            return @{
                Root = $root
                Repo = $repo
                Script = $scriptCopy
                StateFile = $stateFile
                TargetClone = $targetClone
                StateSha256 = (Get-FileSha256Hex -Path $stateFile)
                AppData = $appData
                Bin = $bin
                InvocationLog = $invocationLog
                LogDir = (Join-Path $repo 'outputs\scheduling\logs')
            }
        }

        function Set-HarnessEnv {
            param([hashtable]$Harness)
            $env:PATH = $Harness.Bin + [System.IO.Path]::PathSeparator + $script:origPath
            $env:APPDATA = $Harness.AppData
            $env:COPILOT_FAKE_INVOCATION_LOG = $Harness.InvocationLog
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

        function Get-NewestDispatcherLog {
            param([hashtable]$Harness)
            $logFiles = @(Get-ChildItem -LiteralPath $Harness.LogDir -Filter 'copilot-dispatcher-*.log' -ErrorAction SilentlyContinue)
            if ($logFiles.Count -eq 0) { return $null }
            $newest = $logFiles | Sort-Object LastWriteTime -Descending | Select-Object -First 1
            return (Get-Content -LiteralPath $newest.FullName -Raw)
        }

        function Invoke-DispatcherChild {
            param([hashtable]$Harness)

            # Anti-fallback gate: both names must resolve inside the fake bin
            # dir or we refuse to spawn the child against a real executable.
            foreach ($name in @('copilot', 'gh')) {
                $resolved = Get-Command $name -ErrorAction SilentlyContinue
                if (-not $resolved) {
                    throw ("Anti-fallback gate: '{0}' does not resolve on PATH at all -- refusing to spawn the dispatcher child" -f $name)
                }
                if (-not ($resolved.Source.StartsWith($Harness.Bin, [System.StringComparison]::OrdinalIgnoreCase))) {
                    throw ("Anti-fallback gate: '{0}' resolves to '{1}' outside the fake bin dir '{2}' -- refusing to spawn the dispatcher child against a real executable" -f $name, $resolved.Source, $Harness.Bin)
                }
            }

            # Retargeted geometry BY CONSTRUCTION and no -DryRun: the guard
            # under test sits past the DryRun exit, and only the retarget pair
            # lets a run reach the paid call (the #4669 local-mode guard).
            $engineArgs = @('-NoProfile')
            if ($env:OS -eq 'Windows_NT') {
                $engineArgs += @('-ExecutionPolicy', 'Bypass')
            }
            $engineArgs += @(
                '-File', $Harness.Script,
                '-TargetRepoSlug', 'jsboige/sandbox-target',
                '-TargetRepoPath', $Harness.TargetClone
            )

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
    }

    AfterEach {
        foreach ($root in $script:harnessRoots) {
            if ($root -and (Test-Path -LiteralPath $root)) {
                Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
        $script:harnessRoots = @()
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

    It 'BILLED: the tick parks - exit 0, no CLI invocation at all, byte-identical state, no report, park line logged' {
        $h = New-LinkHarness -ScriptText $script:fixedText -Probe 'BILLED'
        Set-HarnessEnv -Harness $h

        $result = Invoke-DispatcherChild -Harness $h
        $result.ExitCode | Should -Be 0

        # Before the first external call: not even the FREE version probe ran.
        $h.InvocationLog | Should -Not -Exist

        # A parked lane is not an idle streak: the run state is not rewritten.
        Get-FileSha256Hex -Path $h.StateFile | Should -Be $h.StateSha256

        # No work report anywhere under the sandbox outputs.
        $reports = @(Get-ChildItem -LiteralPath (Join-Path $h.Repo 'outputs') -Recurse -Filter 'copilot-dispatcher-*.md' -ErrorAction SilentlyContinue)
        $reports.Count | Should -Be 0

        # The child ran to the guard (a crash would leave no log) and the park
        # line names the verdict. The geometry guard never fired: the park is
        # what stopped the run.
        $log = Get-NewestDispatcherLog -Harness $h
        $log | Should -Not -BeNullOrEmpty
        $log | Should -Match 'Copilot dispatcher started'
        $log | Should -Match ([regex]::Escape('Dispatcher parked this tick - link BILLED'))
        $log | Should -Match ([regex]::Escape('reason=harness-metered cost=Fixed'))
        $log | Should -Not -Match 'no delivery geometry'
    }

    It 'probe missing: parks too (UNKNOWN probe-missing) - fail-closed on an absent probe, zero CLI invocation' {
        $h = New-LinkHarness -ScriptText $script:fixedText -Probe 'MISSING'
        Set-HarnessEnv -Harness $h

        $result = Invoke-DispatcherChild -Harness $h
        $result.ExitCode | Should -Be 0
        $h.InvocationLog | Should -Not -Exist
        Get-FileSha256Hex -Path $h.StateFile | Should -Be $h.StateSha256

        $log = Get-NewestDispatcherLog -Harness $h
        $log | Should -Not -BeNullOrEmpty
        $log | Should -Match ([regex]::Escape('Dispatcher parked this tick - link UNKNOWN (probe-missing)'))
    }

    It 'UNBILLED control: with an unmetered link the SAME fixture runs past the guard (the probe stub, not a dead child)' {
        # Without this, the two parks above would also pass on a child that
        # cannot get past the guard at all (a broken path, a dead probe host).
        $h = New-LinkHarness -ScriptText $script:fixedText -Probe 'UNBILLED'
        Set-HarnessEnv -Harness $h

        $result = Invoke-DispatcherChild -Harness $h
        $result.ExitCode | Should -Be 0

        $log = Get-NewestDispatcherLog -Harness $h
        $log | Should -Not -BeNullOrEmpty
        $log | Should -Match ([regex]::Escape('Link guard: UNBILLED'))
        $log | Should -Not -Match 'Dispatcher parked this tick'
        $records = Get-Content -LiteralPath $h.InvocationLog -Raw -ErrorAction SilentlyContinue
        $records | Should -Match ([regex]::Escape('copilot :: --version'))
    }

    It 'POSITIVE CONTROL: with the park stripped, the SAME BILLED fixture reaches the paid call' {
        # Mutate a copy of the FIXED script: remove the whole park block
        # (comment, probe call, park branch, UNBILLED trace). The resulting
        # file reproduces the pre-28/11 defect for the observable asserted
        # below: a paid dispatch on a billed link.
        $pattern = '(?ms)^# Billed-link park \(28/11, po-2027\).*?^Write-Log "Link guard: UNBILLED[^\r\n]*\r?\n'
        $mutated = $script:fixedText -replace $pattern, ''

        # Mutation validity: if the anchor text drifts, FAIL LOUDLY here rather
        # than shipping a control that proves nothing.
        $mutated | Should -Not -Be $script:fixedText
        $mutated | Should -Not -Match 'Dispatcher parked this tick - link'
        $mutated | Should -Not -Match 'Link guard: UNBILLED'

        $h = New-LinkHarness -ScriptText $mutated -Probe 'BILLED'
        Set-HarnessEnv -Harness $h

        $result = Invoke-DispatcherChild -Harness $h
        $result.ExitCode | Should -Be 0

        $records = Get-Content -LiteralPath $h.InvocationLog -Raw
        $records | Should -Match '(?s)copilot :: -p .*--allow-all-tools --no-ask-user'
    }
}
