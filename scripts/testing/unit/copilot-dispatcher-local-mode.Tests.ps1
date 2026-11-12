# Pester 5 tests: the Copilot dispatcher must FAIL CLOSED in local mode (#4669).
#
# Defect these tests pin: without the retarget pair (-TargetRepoSlug/
# -TargetRepoPath), the queue repo is the repo holding the script itself, so
# $workRoot = $repoRoot (the MAIN CHECKOUT of the host lane) and $canDeliver
# = $false -- and the Copilot call STILL ran. Measured on po-2025 (12/11):
# uncommitted edits left in the lane's main checkout (the $copilotWt
# assertion behind autostash conflict b0383b6c, then an edit for #4666),
# ~20 premium requests per run, zero PR. User mandate: Copilot work must end
# in a PR. The main checkout of the host lane is never a Copilot work root.
#
# Design notes (same doctrine as copilot-dispatcher-dryrun.Tests.ps1):
# * The dispatcher runs as a CHILD PROCESS of the same engine that runs this
#   suite, against a TEMPORARY copy of the repo layout. The production
#   checkout is never executed nor touched.
# * `copilot` and `gh` are faked by PREPENDING a temp bin dir to PATH. The
#   fakes RECORD the invocation FIRST, so "no record" proves absence of the
#   invocation, not absence of its success. The version probe (`copilot
#   --version`, free) may run; the PAID leg is `copilot -p` -- that is what
#   the zero-burn assertion pins.
# * The gh fake serves the REST pool leg (`gh api repos/<slug>/issues?...`)
#   with ONE actionable issue, so the run passes the no-target gate and
#   reaches the geometry decision the guard lives at -- a skip on "no issue
#   found" would pass vacuously (idle, zero premium, no geometry guard hit).
# * Positive control: a MUTATED copy with the #4669 guard stripped -- the
#   defect itself -- must show the paid `-p` record. If the fakes or
#   fixtures ever break, this control goes red instead of the invariants
#   above passing vacuously.
#
# Run:  powershell -File scripts/testing/run-pester-tests.ps1 -Path scripts/testing/unit/copilot-dispatcher-local-mode.Tests.ps1

Describe 'Copilot dispatcher local-mode fail-closed (#4669)' {

    BeforeAll {
        $script:productionScript = Join-Path $PSScriptRoot '../../scheduling/start-copilot-dispatcher.ps1'
        $script:fixedText = Get-Content -LiteralPath $script:productionScript -Raw
        $script:utf8Bom = [System.Text.UTF8Encoding]::new($true)

        $script:origPath = $env:PATH
        $script:origAppData = $env:APPDATA
        $script:origFakeLog = $env:COPILOT_FAKE_INVOCATION_LOG
        $script:origLogDir = $env:COPILOT_DISPATCHER_LOG_DIR
        $script:harnessRoots = @()

        if ($PSVersionTable.PSVersion.Major -ge 6) {
            $script:engine = Join-Path $PSHOME 'pwsh'
        } else {
            $script:engine = Join-Path $PSHOME 'powershell.exe'
        }

        function New-LocalModeHarness {
            param([string]$ScriptText)

            $root = Join-Path ([System.IO.Path]::GetTempPath()) ("copilot-localmode-" + [guid]::NewGuid().ToString('N'))
            $script:harnessRoots += $root

            $repo = Join-Path $root 'repo'
            $scriptDir = Join-Path (Join-Path $repo 'scripts') 'scheduling'
            New-Item -ItemType Directory -Path $scriptDir -Force | Out-Null
            $scriptCopy = Join-Path $scriptDir 'start-copilot-dispatcher.ps1'
            [System.IO.File]::WriteAllText($scriptCopy, $ScriptText, $script:utf8Bom)

            # The dispatcher dot-sources ..\common\gh-issues.ps1 (lot 7a, #4150):
            # mirror the script's own path math so the module resolves on every
            # host (same comment as the dryrun suite).
            $moduleSrc = Join-Path $PSScriptRoot '../../common/gh-issues.ps1'
            $moduleDst = Join-Path $scriptDir '..\common\gh-issues.ps1'
            New-Item -ItemType Directory -Path (Split-Path -Parent $moduleDst) -Force | Out-Null
            Copy-Item -LiteralPath $moduleSrc -Destination $moduleDst -Force

            # State fixture at the exact path the script computes, with a
            # sentinel the untouched/rewritten distinction can lean on.
            $stateDir = Join-Path $repo '.claude\scheduler'
            New-Item -ItemType Directory -Path $stateDir -Force | Out-Null
            $stateFile = Join-Path $stateDir 'copilot-dispatcher-state.json'
            [System.IO.File]::WriteAllText($stateFile, '{"consecutiveBlocked":0,"consecutiveIdle":0,"lastStatus":"none","lastEscalation":"none","lastEscalationAt":"","escalationWindowStart":"","escalationsInWindow":0}', $script:utf8Bom)

            # git repo with an origin: local mode derives the queue slug from
            # it (Get-RepoSlug), so the REST pool query targets a deterministic
            # fake slug instead of short-circuiting at the module binding.
            & git -C $repo init -q
            if ($LASTEXITCODE -ne 0) { throw "git init failed in harness at $repo" }
            & git -C $repo remote add origin https://github.com/jsboige/sandbox-fixture.git
            if ($LASTEXITCODE -ne 0) { throw "git remote add failed in harness at $repo" }

            # Copilot MCP config candidate under a pinned APPDATA (same
            # expression as the script: Join-Path $env:APPDATA "Code\User\mcp.json").
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
'fake copilot reply -- localmode harness'
exit 0
'@
            [System.IO.File]::WriteAllText((Join-Path $bin 'copilot.ps1'), $copilotFake, $script:utf8Bom)

            # gh fake: REST legs only (doctrine #4604 -- the dispatcher never
            # uses `gh issue view` anymore). Pool leg serves ONE actionable
            # issue (jq-shaped, one object per line, exactly what --jq emits);
            # detail leg (/issues/<n> without '?') serves the same issue.
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

            $logDir = Join-Path $repo 'outputs\scheduling\logs'

            return @{
                Root = $root
                Repo = $repo
                Script = $scriptCopy
                StateFile = $stateFile
                AppData = $appData
                Bin = $bin
                InvocationLog = $invocationLog
                LogDir = $logDir
            }
        }

        function Set-HarnessEnv {
            param([hashtable]$Harness)
            $env:PATH = $Harness.Bin + [System.IO.Path]::PathSeparator + $script:origPath
            $env:APPDATA = $Harness.AppData
            $env:COPILOT_FAKE_INVOCATION_LOG = $Harness.InvocationLog
            $env:COPILOT_DISPATCHER_LOG_DIR = $Harness.LogDir
        }

        function Invoke-DispatcherChild {
            param([hashtable]$Harness)

            # Anti-fallback gate (same doctrine as the dryrun suite): both
            # names must resolve inside the fake bin dir or we refuse to spawn.
            foreach ($name in @('copilot', 'gh')) {
                $resolved = Get-Command $name -ErrorAction SilentlyContinue
                if (-not $resolved) {
                    throw ("Anti-fallback gate: '{0}' does not resolve on PATH at all -- refusing to spawn the dispatcher child" -f $name)
                }
                if (-not ($resolved.Source.StartsWith($Harness.Bin, [System.StringComparison]::OrdinalIgnoreCase))) {
                    throw ("Anti-fallback gate: '{0}' resolves to '{1}' outside the fake bin dir '{2}' -- refusing to spawn the dispatcher child against a real executable" -f $name, $resolved.Source, $Harness.Bin)
                }
            }

            # Local mode BY CONSTRUCTION: no -TargetRepoSlug, no
            # -TargetRepoPath, no -IssueNumber (the pool leg picks 4242), no
            # -DryRun (the guard under test sits past the DryRun exit).
            $engineArgs = @('-NoProfile')
            if ($env:OS -eq 'Windows_NT') {
                $engineArgs += @('-ExecutionPolicy', 'Bypass')
            }
            $engineArgs += @('-File', $Harness.Script)

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

        function Get-NewestDispatcherLog {
            param([hashtable]$Harness)
            $logFiles = @(Get-ChildItem -LiteralPath $Harness.LogDir -Filter 'copilot-dispatcher-*.log' -ErrorAction SilentlyContinue)
            if ($logFiles.Count -eq 0) { return $null }
            $newest = $logFiles | Sort-Object LastWriteTime -Descending | Select-Object -First 1
            return (Get-Content -LiteralPath $newest.FullName -Raw)
        }
    }

    BeforeEach {
        $script:harness = New-LocalModeHarness -ScriptText $script:fixedText
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

    It 'local mode (no retarget pair) makes ZERO paid Copilot calls and logs the skip line' {
        $result = Invoke-DispatcherChild -Harness $script:harness

        $result.ExitCode | Should -Be 0

        # The run reached the pool gate and the geometry decision (not a
        # crash, not the DryRun exit): the pool leg was served and an
        # actionable target issue existed.
        $records = Get-Content -LiteralPath $script:harness.InvocationLog -Raw -ErrorAction SilentlyContinue
        $records | Should -Match 'gh\s::\sapi\s"?repos/[\w.-]+/[\w.-]+/issues'

        # ZERO premium burn: the version probe may run (free), the PAID
        # `-p` dispatch must NOT.
        $records | Should -Not -Match '(?s)copilot :: -p '

        # The explicit skip line names the missing geometry.
        $log = Get-NewestDispatcherLog -Harness $script:harness
        $log | Should -Not -BeNullOrEmpty
        $log | Should -Match ([regex]::Escape('Skipped: no delivery geometry (set -TargetRepoSlug/-TargetRepoPath)'))

        # The run state records the misconfiguration as blocked (the
        # consecutive-blocked streak is what escalates it to the lane).
        $state = Get-Content -LiteralPath $script:harness.StateFile -Raw | ConvertFrom-Json
        $state.lastStatus | Should -Be 'blocked'
    }

    It 'wiring: the fail-closed guard sits BEFORE the Phase C dispatch call site' {
        $guardPos = $script:fixedText.IndexOf('Skipped: no delivery geometry')
        $guardPos | Should -BeGreaterThan -1
        $dispatchPos = $script:fixedText.IndexOf('Invoke-PhaseCDispatch -Profile')
        ($guardPos -lt $dispatchPos) | Should -BeTrue
        # The guard keys on the delivery flag, not on the retarget params
        # directly -- a degenerate self-retarget (pair pointing at the host
        # checkout) is caught by the same invariant.
        $script:fixedText | Should -Match 'if \(-not \$canDeliver -and \$status -ne .blocked.\)'
    }

    It 'POSITIVE CONTROL: with the #4669 guard stripped (the defect), the harness DOES detect the paid call' {
        # Mutate a copy of the FIXED script: remove the fail-closed block
        # (comment + guard). The resulting file reproduces the original
        # defect for every observable asserted below. The closing brace of
        # the guard is the first 8-space-indented `}` after the comment.
        $pattern = '(?s)# #4669: Copilot never runs without a delivery geometry\..*?\r?\n        \}'
        $mutated = $script:fixedText -replace $pattern, ''

        # Mutation validity: if the anchor text drifts, FAIL LOUDLY here
        # rather than shipping a control that proves nothing.
        $mutated | Should -Not -Be $script:fixedText
        $mutated | Should -Not -Match 'no delivery geometry'

        [System.IO.File]::WriteAllText($script:harness.Script, $mutated, $script:utf8Bom)

        $result = Invoke-DispatcherChild -Harness $script:harness

        $result.ExitCode | Should -Be 0

        # The paid dispatch ran against the main checkout of the sandbox
        # (workRoot = repoRoot): exactly the #4669 pathology.
        $records = Get-Content -LiteralPath $script:harness.InvocationLog -Raw
        $records | Should -Match '(?s)copilot :: -p .*--allow-all-tools --no-ask-user'

        # And the skip line never appears (the guard is what writes it).
        $log = Get-NewestDispatcherLog -Harness $script:harness
        $log | Should -Not -Match 'no delivery geometry'
    }
}
