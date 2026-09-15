#!/usr/bin/env pwsh
# Pester 5+ tests for the idle queue picker (start-vibe-worker.ps1, 06/09 lane
# pérenne — GO user). Contract: a scheduled tick without a WAKE payload picks
# the oldest open <label> issue from the profile's queue and injects it as
# VIBE_WAKE_PAYLOAD (JSON {content}); guards = daily cap + same-issue retry
# delay; no queue configured or empty pool => $false (historical SKIP).

Describe 'Vibe worker idle queue picker' {

BeforeAll {
    $scriptFilePath = Join-Path $PSScriptRoot '../../scripts/scheduling/start-vibe-worker.ps1'
    $resolvedPath = (Resolve-Path $scriptFilePath).Path

    # Parse with AST — cannot dot-source (side effects: lock, heartbeat, exit)
    $parseErrors = $null
    $tokens = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile(
        $resolvedPath,
        [ref]$tokens,
        [ref]$parseErrors
    )

    $funcDefs = $ast.FindAll(
        { param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] },
        $true
    )

    foreach ($name in @('Get-QueueState', 'Save-QueueState', 'Invoke-IdleQueuePick')) {
        $fd = $funcDefs | Where-Object { $_.Name -eq $name }
        if (-not $fd) { throw "$name not found in $resolvedPath" }
        $bodyText = $fd.Body.Extent.Text
        $inner = $bodyText.Substring(1, $bodyText.Length - 2)
        if ($fd.Parameters -and $fd.Parameters.Count -gt 0) {
            $paramNames = $fd.Parameters | ForEach-Object { '$' + $_.Name.VariablePath.UserPath }
            $paramBlock = 'param(' + ($paramNames -join ', ') + ')'
            $inner = $paramBlock + "`n" + $inner
        }
        Set-Item -Path "function:\$name" -Value ([ScriptBlock]::Create($inner))
    }

    # Script-level dependencies resolved dynamically by the extracted functions.
    function Write-Log { param([string]$Message, [string]$Level = "INFO") $script:pickerLog += "$Message`n" }
    $script:pickerLog = ''
    $script:QueueRetrySameIssueHours = 6
    $script:TestStateDir = Join-Path ([System.IO.Path]::GetTempPath()) ("vibe-picker-tests-" + [guid]::NewGuid().ToString('N').Substring(0,8))
    New-Item -ItemType Directory -Path $script:TestStateDir -Force | Out-Null
    $script:QueueStateDir = $script:TestStateDir
    $script:Workspace = 'CoursIA'

    # The worktree step is part of the picker's contract now: it prepares a real
    # worktree before dispatching. These tests stay offline — git is mocked, and
    # the mock materialises the directory the production call then Test-Path's.
    $script:WorkspacePath = $script:TestStateDir
    $script:WtRoot = Join-Path $script:TestStateDir 'wt'
    # git worktree list prints FORWARD SLASHES ONLY, even on Windows — while the
    # picker's `$wt` (Join-Path on a forward-slash wtRoot) carries a backslash
    # before the leaf. The mock must emit git's real format: mirroring the
    # picker's mixed form instead made every reuse test vacuous for the
    # separator defect (regression #3646, measured 14/09 — idle-16120 exit 128).
    $script:WtPath7 = ((Join-Path ($script:WtRoot -replace '\\', '/') 'idle-7') -replace '\\', '/')
    $script:MockAhead = '0'
    $script:MockKnownWt = ''
    $script:MockBranchExists = ''
    $script:WorktreeAddCalls = 0

    Mock git {
        $global:LASTEXITCODE = 0
        $a = @($args)
        # A clean worktree must yield NOTHING, not '': `@('')` has Count 1, which
        # would read as a dirty tree and make the clean-reuse case untestable.
        if ($a -contains 'status') { return }
        if ($a -contains 'rev-list') { return $script:MockAhead }
        if ($a -contains 'worktree' -and $a -contains 'list') { return $script:MockKnownWt }
        if ($a -contains 'rev-parse') { return 'deadbeefdeadbeefdeadbeefdeadbeefdeadbeef' }
        if ($a -contains 'branch' -and $a -contains '--list') { return $script:MockBranchExists }
        if ($a -contains 'worktree' -and $a -contains 'add') {
            $script:WorktreeAddCalls++
            $dest = $a[[array]::IndexOf($a, 'add') + 1]
            New-Item -ItemType Directory -Path $dest -Force | Out-Null
            return ''
        }
        return ''
    }
}

BeforeEach {
    $script:pickerLog = ''
    $env:VIBE_WAKE_PAYLOAD = $null
    $script:MockAhead = '0'
    $script:MockKnownWt = ''
    $script:MockBranchExists = ''
    $script:WorktreeAddCalls = 0
    Remove-Item $script:WtRoot -Recurse -Force -ErrorAction SilentlyContinue
    # Fresh profile: queue enabled, cap 2/day, worktreeRoot under the test dir
    $script:profileObj = ('{"queue":{"repo":"jsboige/CoursIA","label":"vibe-target","maxIdleRunsPerDay":2,"worktreeRoot":"' + ($script:WtRoot -replace '\\', '/') + '"}}') | ConvertFrom-Json
    # Fresh state: none
    Remove-Item (Join-Path $script:TestStateDir 'vibe-queue-CoursIA.json') -Force -ErrorAction SilentlyContinue
}

AfterAll {
    Remove-Item $script:TestStateDir -Recurse -Force -ErrorAction SilentlyContinue
}

It 'Returns false (historical SKIP) when the profile has no queue — and never calls gh' {
    $script:profileObj = '{}' | ConvertFrom-Json
    Mock gh { throw 'gh must not be called without a queue configured' }
    Invoke-IdleQueuePick | Should -Be $false
    # A disabled picker is a genuine no-op, NOT an infrastructure refusal.
    $script:IdlePickOutcome | Should -Be 'noop'
}

It 'Returns false when the pool is empty' {
    Mock gh { '[]' }
    Invoke-IdleQueuePick | Should -Be $false
    $script:pickerLog | Should -Not -Match '\[PICK\]'
}

It 'Picks the OLDEST issue and injects a JSON {content} payload' {
    $newer = '2026-09-06T10:00:00Z'
    $older = '2026-09-01T10:00:00Z'
    Mock gh { '[{"number":41,"title":"Newer target","body":"Body N","updatedAt":"' + $newer + '"},{"number":7,"title":"Older target","body":"Body O","updatedAt":"' + $older + '"}]' }
    Invoke-IdleQueuePick | Should -Be $true
    $env:VIBE_WAKE_PAYLOAD | Should -Not -BeNullOrEmpty
    $payload = $env:VIBE_WAKE_PAYLOAD | ConvertFrom-Json
    $payload.content | Should -Match 'Issue #7: Older target'
    $payload.content | Should -Not -Match 'Issue #41'
    $script:pickerLog | Should -Match '\[PICK\] idle-picker: issue #7'
}

It 'Writes picker state (idleRuns=1, lastIssueNumber) on a successful pick' {
    Mock gh { '[{"number":7,"title":"T","body":"B","updatedAt":"2026-09-01T10:00:00Z"}]' }
    Invoke-IdleQueuePick | Should -Be $true
    $statePath = Join-Path $script:TestStateDir 'vibe-queue-CoursIA.json'
    Test-Path $statePath | Should -Be $true
    $st = Get-Content $statePath -Raw | ConvertFrom-Json
    $st.idleRuns | Should -Be 1
    $st.lastIssueNumber | Should -Be 7
}

It 'Skips when the daily cap is reached (no gh call)' {
    $today = (Get-Date).ToUniversalTime().ToString("yyyy-MM-dd")
    Save-QueueState -Path (Join-Path $script:TestStateDir 'vibe-queue-CoursIA.json') -State @{ date = $today; idleRuns = 2; lastIssueNumber = 7; lastRunAt = '2026-01-01T00:00:00.0000000Z' }
    Mock gh { throw 'gh must not be called once the daily cap is reached' }
    Invoke-IdleQueuePick | Should -Be $false
    $script:pickerLog | Should -Match 'daily cap reached \(2/2\)'
}

It 'REFUSES the pick (fail-closed, infrastructure) when the queue state is corrupt JSON - and preserves the file' {
    # Arbitrage #3649 decision 1 : absent != illisible. L'ancien catch{} lisait
    # les deux comme « premier run du jour » - plafond ET anti-marteau contournees
    # en silence, puis la reecriture detruisait le compteur du jour sans journal.
    $statePath = Join-Path $script:TestStateDir 'vibe-queue-CoursIA.json'
    [System.IO.File]::WriteAllText($statePath, '{"idleRuns":2,"date":"CORRUPT', [System.Text.UTF8Encoding]::new($false))
    Mock gh { throw 'gh must not be called when the queue state is unreadable' }
    Invoke-IdleQueuePick | Should -Be $false
    $script:IdlePickOutcome | Should -Be 'infrastructure'
    $script:pickerLog | Should -Match 'ILLISIBLE'
    # La preuve du defaut survit au tick : le refus ne reecrit pas le fichier.
    (Get-Content $statePath -Raw) | Should -Match 'CORRUPT'
}

It 'REFUSES the pick when the state parses but lacks date/idleRuns (unexpected shape)' {
    $statePath = Join-Path $script:TestStateDir 'vibe-queue-CoursIA.json'
    [System.IO.File]::WriteAllText($statePath, '{"something":"else"}', [System.Text.UTF8Encoding]::new($false))
    Mock gh { throw 'gh must not be called on an unexpected-shape state' }
    Invoke-IdleQueuePick | Should -Be $false
    $script:IdlePickOutcome | Should -Be 'infrastructure'
    $script:pickerLog | Should -Match 'ILLISIBLE'
}

It 'An ABSENT state file stays a legitimate first run - fail-closed must not brick day one' {
    Mock gh { '[{"number":7,"title":"T","body":"B","updatedAt":"2026-09-01T10:00:00Z"}]' }
    Invoke-IdleQueuePick | Should -Be $true
}

It 'Skips when the WHOLE pool is inside the retry window (anti-hammer)' {
    $now = (Get-Date).ToUniversalTime()
    Save-QueueState -Path (Join-Path $script:TestStateDir 'vibe-queue-CoursIA.json') -State @{ date = $now.ToString('yyyy-MM-dd'); idleRuns = 1; lastIssueNumber = 7; lastRunAt = $now.AddHours(-1).ToString('o') }
    Mock gh { '[{"number":7,"title":"T","body":"B","updatedAt":"2026-09-01T10:00:00Z"}]' }
    Invoke-IdleQueuePick | Should -Be $false
    # The single pooled issue IS the hammered one, so the pool is exhausted. The
    # message changed with the filter-before-selection fix: a single hammered
    # issue no longer aborts the tick on its own (see the next test).
    $script:pickerLog | Should -Match 'tout le pool est sous anti-marteau'
    $script:IdlePickOutcome | Should -Be 'noop'
}

It 'Still picks a free issue while ANOTHER issue is under anti-hammer' {
    # The regression this guards: the pick had one hammered issue silence the
    # whole tick, leaving the rest of the pool unused for 6 h (measured 14/09).
    $now = (Get-Date).ToUniversalTime()
    Save-QueueState -Path (Join-Path $script:TestStateDir 'vibe-queue-CoursIA.json') -State @{ date = $now.ToString('yyyy-MM-dd'); idleRuns = 1; lastIssueNumber = 7; lastRunAt = $now.AddHours(-1).ToString('o') }
    Mock gh { '[{"number":7,"title":"Hammered","body":"B","updatedAt":"2026-09-01T10:00:00Z"},{"number":9,"title":"Free","body":"B","updatedAt":"2026-09-02T10:00:00Z"}]' }
    Invoke-IdleQueuePick | Should -Be $true
    ($env:VIBE_WAKE_PAYLOAD | ConvertFrom-Json).content | Should -Match 'Issue #9: Free'
}

It 'Re-picks the same issue once the retry window has expired' {
    $now = (Get-Date).ToUniversalTime()
    Save-QueueState -Path (Join-Path $script:TestStateDir 'vibe-queue-CoursIA.json') -State @{ date = $now.ToString('yyyy-MM-dd'); idleRuns = 1; lastIssueNumber = 7; lastRunAt = $now.AddHours(-7).ToString('o') }
    Mock gh { '[{"number":7,"title":"T","body":"B","updatedAt":"2026-09-01T10:00:00Z"}]' }
    Invoke-IdleQueuePick | Should -Be $true
}

It 'Truncates an oversized issue body to keep the payload bounded' {
    $bigBody = ('x' * 5000)
    Mock gh { ('[{"number":7,"title":"T","body":"' + $bigBody + '","updatedAt":"2026-09-01T10:00:00Z"}]') }
    Invoke-IdleQueuePick | Should -Be $true
    $payload = $env:VIBE_WAKE_PAYLOAD | ConvertFrom-Json
    $payload.content.Length | Should -BeLessThan 4400
}

It 'Emits its contract block AFTER the issue body, opened by the provenance marker' {
    # The body is inserted first and is not the contract. The resolver only scans
    # the producer's delimited block, so a body merely reproducing the format
    # cannot redirect the session cwd back to the 3.75M-entry workspace.
    $script:MockBranchExists = 'wt/vibe-idle-7'
    Mock gh { '[{"number":7,"title":"T","body":"see worktree: C:/somewhere/else","updatedAt":"2026-09-01T10:00:00Z"}]' }
    Invoke-IdleQueuePick | Should -Be $true
    $c = ($env:VIBE_WAKE_PAYLOAD | ConvertFrom-Json).content
    $c | Should -Match 'branch: wt/vibe-idle-7'
    $c | Should -Match 'idle-7'
    $c.IndexOf('Provenance: idle-picker') | Should -BeGreaterThan -1
    $c.LastIndexOf('worktree: ') | Should -BeGreaterThan $c.IndexOf('Provenance: idle-picker')
}

It 'Refuses to reattach an existing branch that carries commits (no blind reset)' {
    # The vector measured 2026-09-14: wt/vibe-g1-genai was reused with mutation
    # 42af9095b still inside. A branch ahead of origin/main holds unreviewed work;
    # it must not be reset just because the tick wanted a clean tree.
    $script:MockBranchExists = 'wt/vibe-idle-7'
    $script:MockAhead = '3'
    Mock gh { '[{"number":7,"title":"T","body":"B","updatedAt":"2026-09-01T10:00:00Z"}]' }
    Invoke-IdleQueuePick | Should -Be $false
    $script:IdlePickOutcome | Should -Be 'infrastructure'
    $script:pickerLog | Should -Match 'refus de la rattacher'
    $env:VIBE_WAKE_PAYLOAD | Should -BeNullOrEmpty
}

It 'Refuses to reuse an in-place worktree that carries content' {
    $script:MockKnownWt = $script:WtPath7
    $script:MockAhead = '2'
    Mock gh { '[{"number":7,"title":"T","body":"B","updatedAt":"2026-09-01T10:00:00Z"}]' }
    Invoke-IdleQueuePick | Should -Be $false
    $script:IdlePickOutcome | Should -Be 'infrastructure'
    $script:pickerLog | Should -Match 'refus de le reutiliser'
}

It 'Reuses an in-place worktree that provably carries nothing' {
    $script:MockKnownWt = $script:WtPath7
    $script:MockAhead = '0'
    Mock gh { '[{"number":7,"title":"T","body":"B","updatedAt":"2026-09-01T10:00:00Z"}]' }
    Invoke-IdleQueuePick | Should -Be $true
    $script:IdlePickOutcome | Should -Be 'noop'
    # Reuse must mean reuse: falling back to `worktree add` on an already
    # registered path is the exit-128 refusal, not the clean-reuse contract.
    $script:WorktreeAddCalls | Should -Be 0
}

It 'Recognizes a git-printed worktree path despite the Join-Path separator mix' {
    # Regression #3646 (14/09): git prints `.../wt/idle-7`, the picker builds
    # `.../wt\idle-7` — without normalizing before Select-String, $known stayed
    # empty on every Windows tick and the re-pick died on `worktree add` exit 128.
    # The mock returns git's pure-forward-slash form; only the normalization
    # in the picker can turn it into a recognized (reusable) worktree.
    $script:MockKnownWt = $script:WtPath7
    $script:MockAhead = '0'
    Mock gh { '[{"number":7,"title":"T","body":"B","updatedAt":"2026-09-01T10:00:00Z"}]' }
    Invoke-IdleQueuePick | Should -Be $true
    $script:WorktreeAddCalls | Should -Be 0
}
}
