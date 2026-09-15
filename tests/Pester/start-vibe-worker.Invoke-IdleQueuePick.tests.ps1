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

    foreach ($name in @('Get-QueueState', 'Save-QueueState', 'Get-QueueOpenPrs', 'Test-QueueIssueClaimed', 'Invoke-IdleQueuePick')) {
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
    $script:QueueClaimHours = 72
    # Real bodies kept aside: BeforeEach mocks these names by default, so the
    # direct function-level tests below invoke the SAVED scriptblock to test
    # the real code (calling by name would hit the mock — vacuous, #3646 lesson).
    $script:RealTestQueueIssueClaimed = ${function:Test-QueueIssueClaimed}
    $script:RealGetQueueOpenPrs = ${function:Get-QueueOpenPrs}
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
    # Anti-collision guards default to "nothing blocks" so pre-existing tests
    # stay about the hammer/cap/worktree contract. Collision tests re-mock these.
    Mock Get-QueueOpenPrs { ,@() }
    Mock Test-QueueIssueClaimed { $false }
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

It 'Skips an issue covered by an OPEN PR (title #N, word boundary) and picks the next free one' {
    # The 14/09 collision: the picker never looked at open PRs, so a delivered
    # issue whose label never changed was re-pickable ($2.02 duplicate run).
    Mock Get-QueueOpenPrs { ,@([pscustomobject]@{ number = 55; title = 'fix(SemanticWeb): relabel for #7 in flight'; headRefName = 'feature/x' }) }
    Mock gh { '[{"number":7,"title":"T7","body":"B","updatedAt":"2026-09-01T10:00:00Z"},{"number":9,"title":"T9","body":"B","updatedAt":"2026-09-02T10:00:00Z"}]' }
    Invoke-IdleQueuePick | Should -Be $true
    ($env:VIBE_WAKE_PAYLOAD | ConvertFrom-Json).content | Should -Match 'Issue #9'
    $script:pickerLog | Should -Match 'PR ouverte #55 la couvre deja'
}

It 'Skips an issue whose number is only in the PR HEAD BRANCH, not the title (measured #16136/#16120)' {
    Mock Get-QueueOpenPrs { ,@([pscustomobject]@{ number = 16136; title = 'relabel 4 worked-examples + add 3 real exercises'; headRefName = 'feature/16120-sw14-exercises' }) }
    Mock gh { '[{"number":16120,"title":"SW-14","body":"B","updatedAt":"2026-09-01T10:00:00Z"},{"number":16121,"title":"T","body":"B","updatedAt":"2026-09-02T10:00:00Z"}]' }
    Invoke-IdleQueuePick | Should -Be $true
    ($env:VIBE_WAKE_PAYLOAD | ConvertFrom-Json).content | Should -Match 'Issue #16121'
    $script:pickerLog | Should -Match '#16120 ecartee'
}

It 'Does NOT skip #1612 when the PR head contains 16120 (word boundary holds)' {
    Mock Get-QueueOpenPrs { ,@([pscustomobject]@{ number = 16136; title = 'x'; headRefName = 'feature/16120-sw14' }) }
    Mock gh { '[{"number":1612,"title":"T","body":"B","updatedAt":"2026-09-01T10:00:00Z"}]' }
    Invoke-IdleQueuePick | Should -Be $true
    ($env:VIBE_WAKE_PAYLOAD | ConvertFrom-Json).content | Should -Match 'Issue #1612'
}

It 'Quiet SKIP (noop) when the whole pool is covered by open PRs' {
    Mock Get-QueueOpenPrs { ,@([pscustomobject]@{ number = 1; title = 'for #7'; headRefName = 'x' }) }
    Mock gh { '[{"number":7,"title":"T","body":"B","updatedAt":"2026-09-01T10:00:00Z"}]' }
    Invoke-IdleQueuePick | Should -Be $false
    $script:IdlePickOutcome | Should -Be 'noop'
    $script:pickerLog | Should -Match 'couvert par des PRs ouvertes'
}

It 'Skips a freshly [CLAIMED] issue and falls through to the next candidate' {
    Mock Test-QueueIssueClaimed { param($Repo, $Number) $Number -eq 7 }
    Mock gh { '[{"number":7,"title":"T7","body":"B","updatedAt":"2026-09-01T10:00:00Z"},{"number":9,"title":"T9","body":"B","updatedAt":"2026-09-02T10:00:00Z"}]' }
    Invoke-IdleQueuePick | Should -Be $true
    ($env:VIBE_WAKE_PAYLOAD | ConvertFrom-Json).content | Should -Match 'Issue #9'
    $script:pickerLog | Should -Match '\[CLAIMED\] recent'
}

It 'Quiet SKIP (noop) when every remaining candidate carries a fresh [CLAIMED]' {
    Mock Test-QueueIssueClaimed { $true }
    Mock gh { '[{"number":7,"title":"T","body":"B","updatedAt":"2026-09-01T10:00:00Z"}]' }
    Invoke-IdleQueuePick | Should -Be $false
    $script:IdlePickOutcome | Should -Be 'noop'
    $script:pickerLog | Should -Match 'porte un \[CLAIMED\] recent'
}

It 'REFUSES the pick (infrastructure) when the open-PR list cannot be verified (fail-closed)' {
    Mock Get-QueueOpenPrs { throw 'gh pr list: sortie vide ou non-JSON' }
    Mock gh { '[{"number":7,"title":"T","body":"B","updatedAt":"2026-09-01T10:00:00Z"}]' }
    Invoke-IdleQueuePick | Should -Be $false
    $script:IdlePickOutcome | Should -Be 'infrastructure'
    $script:pickerLog | Should -Match 'REFUSE \(fail-closed anti-collision'
}

It 'REFUSES the pick (infrastructure) when the claim state of a candidate cannot be verified' {
    Mock Test-QueueIssueClaimed { throw 'gh issue view #7 a echoue' }
    Mock gh { '[{"number":7,"title":"T","body":"B","updatedAt":"2026-09-01T10:00:00Z"}]' }
    Invoke-IdleQueuePick | Should -Be $false
    $script:IdlePickOutcome | Should -Be 'infrastructure'
    $script:pickerLog | Should -Match 'REFUSE \(fail-closed anti-collision'
}

It 'Test-QueueIssueClaimed: fresh claim matches, stale claim (>72h) does not' {
    $fresh = (Get-Date).ToUniversalTime().AddHours(-3).ToString('o')
    $stale = (Get-Date).ToUniversalTime().AddHours(-100).ToString('o')
    Mock gh { '{"comments":[{"createdAt":"' + $fresh + '","body":"[CLAIMED] lane myia-po-2027:CoursIA-2"}]}' }
    & $script:RealTestQueueIssueClaimed -Repo 'jsboige/CoursIA' -Number 7 | Should -Be $true
    Mock gh { '{"comments":[{"createdAt":"' + $stale + '","body":"[CLAIMED] lane myia-po-2027:CoursIA-2"}]}' }
    & $script:RealTestQueueIssueClaimed -Repo 'jsboige/CoursIA' -Number 7 | Should -Be $false
    # A comment without the marker never claims, however fresh.
    Mock gh { '{"comments":[{"createdAt":"' + $fresh + '","body":"just a note"}]}' }
    & $script:RealTestQueueIssueClaimed -Repo 'jsboige/CoursIA' -Number 7 | Should -Be $false
}

It 'Get-QueueOpenPrs (real body): parses gh JSON, throws on empty/non-JSON output' {
    Mock gh { '[{"number":1,"title":"t","headRefName":"h"},{"number":2,"title":"u","headRefName":"k"}]' }
    # The function comma-wraps its return (0/1-element arrays must survive as
    # arrays), so &-invocation emits ONE object: the array itself. Capture
    # first, then count - @(& ...) would count 1 wrapper, not the elements.
    $prs = & $script:RealGetQueueOpenPrs -Repo 'r'
    @($prs).Count | Should -Be 2
    Mock gh { '' }
    { & $script:RealGetQueueOpenPrs -Repo 'r' } | Should -Throw
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
    # Contract amend #3665 (user 15/09): the refusal ECARTE the candidate and the
    # scan continues — it is no longer a tick-killing 'infrastructure' refusal.
    $script:MockBranchExists = 'wt/vibe-idle-7'
    $script:MockAhead = '3'
    Mock gh { '[{"number":7,"title":"T","body":"B","updatedAt":"2026-09-01T10:00:00Z"}]' }
    Invoke-IdleQueuePick | Should -Be $false
    $script:IdlePickOutcome | Should -Be 'noop'
    $script:pickerLog | Should -Match 'refus de la rattacher'
    $script:pickerLog | Should -Match 'Contenu PRESERVE'
    $env:VIBE_WAKE_PAYLOAD | Should -BeNullOrEmpty
}

It 'Refuses to reuse an in-place worktree that carries content' {
    $script:MockKnownWt = $script:WtPath7
    $script:MockAhead = '2'
    Mock gh { '[{"number":7,"title":"T","body":"B","updatedAt":"2026-09-01T10:00:00Z"}]' }
    Invoke-IdleQueuePick | Should -Be $false
    $script:IdlePickOutcome | Should -Be 'noop'
    $script:pickerLog | Should -Match 'refus de le reutiliser'
    $script:pickerLog | Should -Match 'Contenu PRESERVE'
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

# ============================================================================
# Amend #3665 (arbitrage user 15/09) — Garde 3: a content-bearing worktree
# ECARTE its candidate and the scan CONTINUES. Measured 15/09: #16120 emitted
# one [ERROR] per hour from 00:40Z to 07:40Z and no other candidate was ever
# examined, because the refusal was classified 'infrastructure' (tick-fatal).
# Three discriminating cases: (1) occupied-then-free selects the second;
# (2) all occupied => quiet noop; (3) a real worktree-add failure stays fatal.
# ============================================================================

It 'Skips a content-bearing candidate and PICKS THE NEXT free one' {
    # idle-7 is registered AND ahead by 1; idle-9 is untouched. The mock reads
    # the `-C` path so "ahead" is per-candidate, as git makes it.
    $script:MockKnownWt = $script:WtPath7
    Mock git {
        $global:LASTEXITCODE = 0
        $a = @($args)
        $i = [array]::IndexOf($a, '-C')
        $leaf = if ($i -ge 0) { Split-Path $a[$i + 1] -Leaf } else { '' }
        if ($a -contains 'status') { return }
        if ($a -contains 'rev-list') { if ($leaf -eq 'idle-7') { return '1' } ; return '0' }
        if ($a -contains 'worktree' -and $a -contains 'list') { return $script:MockKnownWt }
        if ($a -contains 'rev-parse') { return 'deadbeefdeadbeefdeadbeefdeadbeefdeadbeef' }
        if ($a -contains 'branch' -and $a -contains '--list') { return '' }
        if ($a -contains 'worktree' -and $a -contains 'add') {
            $script:WorktreeAddCalls++
            New-Item -ItemType Directory -Path $a[[array]::IndexOf($a, 'add') + 1] -Force | Out-Null
            return ''
        }
        return ''
    }
    Mock gh { '[{"number":7,"title":"Occupied","body":"B","updatedAt":"2026-09-01T10:00:00Z"},{"number":9,"title":"Next free","body":"B","updatedAt":"2026-09-02T10:00:00Z"}]' }
    Invoke-IdleQueuePick | Should -Be $true
    $script:pickerLog | Should -Match '\[SKIP\] idle-picker: #7 ecartee'
    $script:pickerLog | Should -Match 'Contenu PRESERVE'
    $script:pickerLog | Should -Not -Match '\[ERROR\]'
    ($env:VIBE_WAKE_PAYLOAD | ConvertFrom-Json).content | Should -Match 'Issue #9: Next free'
}

It 'Quiet noop (not infrastructure) when EVERY free candidate carries content' {
    # Every candidate has an existing branch ahead by 3 -> refused for content.
    # The tick must report a no-op, with one SKIP per candidate and no [ERROR].
    $script:MockBranchExists = 'wt/vibe-idle-7'
    Mock git {
        $global:LASTEXITCODE = 0
        $a = @($args)
        $i = [array]::IndexOf($a, '-C')
        $leaf = if ($i -ge 0) { Split-Path $a[$i + 1] -Leaf } else { '' }
        if ($a -contains 'status') { return }
        # rev-list is called on the WORKSPACE for the branch check, on a worktree
        # path for the dirty/ahead check: only the former must report commits.
        if ($a -contains 'rev-list') { if ($leaf -like 'idle-*') { return '0' } ; return '3' }
        if ($a -contains 'worktree' -and $a -contains 'list') { return '' }
        if ($a -contains 'rev-parse') { return 'deadbeefdeadbeefdeadbeefdeadbeefdeadbeef' }
        if ($a -contains 'branch' -and $a -contains '--list') { return $script:MockBranchExists }
        return ''
    }
    Mock gh { '[{"number":7,"title":"A","body":"B","updatedAt":"2026-09-01T10:00:00Z"},{"number":9,"title":"C","body":"B","updatedAt":"2026-09-02T10:00:00Z"}]' }
    Invoke-IdleQueuePick | Should -Be $false
    $script:IdlePickOutcome | Should -Be 'noop'
    $script:pickerLog | Should -Match 'occupe localement'
    $script:pickerLog | Should -Not -Match '\[ERROR\]'
    ([regex]::Matches($script:pickerLog, 'Contenu PRESERVE')).Count | Should -Be 2
}

It 'Keeps infrastructure FATAL for a real worktree-add failure' {
    # The distinction the amend exists for: only genuine git failures may kill
    # the tick. Here `worktree add` fails -> infrastructure, and no SKIP.
    Mock git {
        $global:LASTEXITCODE = 0
        $a = @($args)
        if ($a -contains 'status') { return }
        if ($a -contains 'rev-list') { return '0' }
        if ($a -contains 'worktree' -and $a -contains 'list') { return '' }
        if ($a -contains 'rev-parse') { return 'deadbeefdeadbeefdeadbeefdeadbeefdeadbeef' }
        if ($a -contains 'branch' -and $a -contains '--list') { return '' }
        if ($a -contains 'worktree' -and $a -contains 'add') { $global:LASTEXITCODE = 1 ; return '' }
        return ''
    }
    Mock gh { '[{"number":7,"title":"T","body":"B","updatedAt":"2026-09-01T10:00:00Z"}]' }
    Invoke-IdleQueuePick | Should -Be $false
    $script:IdlePickOutcome | Should -Be 'infrastructure'
    $script:pickerLog | Should -Match 'worktree add a echoue'
    $script:pickerLog | Should -Not -Match 'Contenu PRESERVE'
}

It 'Test-QueueIssueClaimed: the 72h boundary holds at 71h/73h, not only at 3h/100h' {
    # Boundary discrimination for the window itself. The Kind normalization
    # (`[DateTime]` on a `...Z` yields Kind=Local, and PowerShell compares Ticks,
    # so a raw value compares local wall-clock against a UTC cutoff) is enforced
    # statically in scripts/testing/unit/vibe-worker-noop-guard.Tests.ps1 — on a
    # UTC CI runner the two readings coincide, so a behavioural case alone could
    # not discriminate them here.
    $justInside = (Get-Date).ToUniversalTime().AddHours(-71).ToString('o')
    $justOutside = (Get-Date).ToUniversalTime().AddHours(-73).ToString('o')
    Mock gh { '{"comments":[{"createdAt":"' + $justInside + '","body":"[CLAIMED] lane myia-po-2027:CoursIA-2"}]}' }
    & $script:RealTestQueueIssueClaimed -Repo 'jsboige/CoursIA' -Number 7 | Should -Be $true
    Mock gh { '{"comments":[{"createdAt":"' + $justOutside + '","body":"[CLAIMED] lane myia-po-2027:CoursIA-2"}]}' }
    & $script:RealTestQueueIssueClaimed -Repo 'jsboige/CoursIA' -Number 7 | Should -Be $false
}

It 'Test-QueueIssueClaimed: an offset-carrying timestamp cannot revive a 72h+ claim' {
    # The KIND discriminator (ai-01 review, correction 1). The 71h/73h and 3h/100h
    # cases above pin the width of the window; they are green under BOTH readings,
    # so none of them can distinguish the defect.
    #
    # Measured 15/09 under pwsh 7.6.6, because the shape decides everything:
    #   '...Z'        -> Kind=Utc        (the raw cast is already right)
    #   '...+02:00'   -> Kind=Local      (the raw cast is WRONG)
    #   '...'         -> Kind=Unspecified
    # gh emits the `Z` form, so today's nominal input is unaffected — this case
    # therefore feeds the OFFSET form on purpose, which is the shape the raw cast
    # mishandles: PowerShell compares DateTimes by Ticks without regard to Kind,
    # so a Local value weighs WALL CLOCK against a UTC cutoff. The age is chosen
    # from the runner's offset sign so the raw reading lands on the wrong side in
    # both hemispheres: east of Greenwich a 73h claim looks fresh, west of it a
    # 71h claim looks stale. On a UTC runner the two readings coincide and this
    # case stays a control — the static pin in
    # scripts/testing/unit/vibe-worker-noop-guard.Tests.ps1 is what holds there.
    $nowUtc = (Get-Date).ToUniversalTime()
    $offsetHours = [int][Math]::Round([TimeZoneInfo]::Local.GetUtcOffset($nowUtc).TotalHours)
    $cutoffUtc = $nowUtc.AddHours(-72)
    # East (>=0): 73h must read stale; West (<0): 71h must read fresh.
    $ageHours = if ($offsetHours -ge 0) { 73 } else { 71 }
    $expected = if ($offsetHours -ge 0) { $false } else { $true }
    $claimLiteral = $nowUtc.AddHours(-1 * $ageHours).ToLocalTime().ToString('o')

    if ($offsetHours -ne 0) {
        # Premise of the discrimination, ASSERTED so this case cannot quietly decay
        # into another control: on this host the raw reading really does land on the
        # opposite side from the UTC-correct verdict. If it ever stops doing so, the
        # case is no longer proving anything and should fail loudly rather than pass
        # for the wrong reason.
        $naiveVerdict = ([DateTime]$claimLiteral -ge $cutoffUtc)
        $naiveVerdict | Should -Not -Be $expected -Because "at UTC+$($offsetHours.ToString('0;-0')) the raw cast reads ${ageHours}h as the wrong freshness"
    }

    Mock gh { '{"comments":[{"createdAt":"' + $claimLiteral + '","body":"[CLAIMED] lane myia-po-2027:CoursIA-2"}]}' }
    & $script:RealTestQueueIssueClaimed -Repo 'jsboige/CoursIA' -Number 7 | Should -Be $expected -Because "${ageHours}h is ${expected} the 72h window in UTC, whatever the timestamp shape"
}
}
