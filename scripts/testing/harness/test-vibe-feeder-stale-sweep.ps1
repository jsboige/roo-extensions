<#
.SYNOPSIS
    Behavioral guard for the all-SKIP-stale self-healing sweep in vibe-feeder.ps1 (deadlock 03/10).
.DESCRIPTION
    Measured deadlock (03/10, c.148): Update-StaleGrainBase refuses recalage on
    a worktree with own commits (fail-safe) or a non-ancestor base -> the whole
    queue SKIPs -> the feeder NOOPs every tick until a MANUAL sweep (preserve
    branches + reset + refresh + kick). The fix adds a pass 3: when a full
    measure pass ends with zero dispatch and at least one recalage refusal, the
    feeder sweeps ITSELF -- preserve (local branch vibe-preserve/<id>-<ts>,
    pushed best-effort; stash --include-untracked if dirty), reset --hard
    origin/main, recale baseSha/wtHead -- then retries in the same tick.

    This guard EXECUTES the real feeder (NOT -DryRun: the sweep is gated on
    -not $DryRun) against a staged copy with:
      - a self-origin runtime repo (no network),
      - a stub refresh-vibe-queue.py (rc 0, queue untouched -- reproduces the
        deadlock where re-measure does not unblock anything),
      - a stub start-vibe-worker.ps1 (exit 0 -- the dispatch path is exercised
        end-to-end without spawning any Mistral work).

    Scenario:
      g-S: worktree at base0 + ONE own commit + one dirty file, wtHead == HEAD
           (no eviction), baseSha = base0 (stale, ancestor)  -> refused l.240
           class -> SWEEP: branch preserved, dirty stashed, worktree reset
      g-T: no worktree, baseSha = an orphan (non-ancestor of main) -> refused
           l.206 class -> SWEEP: direct recale, nothing to preserve
      g-L: clean worktree at base0 + ONE own commit (sweep-target shape) but
           a HELD per-grain lock simulates a LIVE worker -> the sweep must
           REFUSE: no preservation branch, no reset, grain stays queued for
           the next tick. Zero dispatch + refusals is the COMMON state while
           workers run (live budget = zero new dispatch); without the guard
           the sweep stash+resets worktrees under live workers' feet.
      g-X (review c.5972480466, path 1 -- git status FAILS): worktree at
           base0 + ONE own commit, but its INDEX is unreadable (held
           FileShare.None on Windows / chmod 000 on Unix -- same dual idiom
           as the g-L lock). rev-list still works, so the own commit IS
           preserved on its branch FIRST; then status exits non-zero with
           empty output -- the PRE-fix code read that as "clean worktree",
           stashed nothing and reset anyway. The sweep must REFUSE at the
           status gate: tip intact, no stash, grain stays queued.
      g-Y (review c.5972480466, path 2 -- rev-list FAILS): detached
           worktree whose HEAD commit OBJECT was deleted from the object
           store (rev-parse still resolves the detached sha; rev-list
           cannot walk). $ahead comes back non-numeric -- the PRE-fix code
           treated it as zero, skipped preservation and reset anyway. The
           sweep must REFUSE at the rev-list gate: no branch, tip intact,
           grain stays queued.

    Asserts on the feeder's own LOG FILE, the resulting queue FILE, the git
    state of the runtime repo (preservation branch, stash, reset HEAD) and the
    anti-loop stamp. A pre-fix feeder fails this guard: it logs SKIP for both
    grains in pass 2 and NOOPs -- no SWEEP lines, no preservation branch, no
    reset, no dispatch.

    Static half pins the wiring: pass 3 exists, is gated on $dispatched -eq 0
    AND non-empty $staleRefused AND -not $DryRun, the sweep never runs when
    something was dispatched, and the stamp anti-loop (6 h) is consulted.
#>

$ErrorActionPreference = 'Stop'

$TestsPassed = 0
$TestsFailed = 0

function Assert-Equal {
    param([string]$TestName, $Expected, $Actual)
    if ("$Expected" -eq "$Actual") {
        Write-Host "  PASS: $TestName (expected=$Expected, got=$Actual)" -ForegroundColor Green
        $script:TestsPassed++
    } else {
        Write-Host "  FAIL: $TestName (expected=$Expected, got=$Actual)" -ForegroundColor Red
        $script:TestsFailed++
    }
}

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
$srcPath = Join-Path $repoRoot 'scripts/scheduling/vibe-feeder.ps1'
$src = Get-Content $srcPath -Raw

# ============================================================================
# Test 1: static wiring of pass 3 / Invoke-StaleSweep
# ============================================================================
Write-Host "`n=== Test 1: sweep wiring (static) ===" -ForegroundColor Cyan

Assert-Equal 'pass 3 exists (for loop bound 3)'      $true ($src -match '\$pass\s*-le\s*3')
Assert-Equal 'sweep function defined'                $true ($src -match 'function Invoke-StaleSweep')
Assert-Equal 'refus tracked into staleRefused'       $true ($src -match '\$staleRefused\s*\+=\s*\$g')
# The sweep ONLY runs when nothing was dispatched and the last pass measured
# real refusals: a dispatched tick must never sweep (fail-safe unchanged).
Assert-Equal 'sweep gated on zero dispatch'          $true ($src -match '\$dispatched\s*-gt\s*0\s*-or\s*\$staleRefused\.Count\s*-eq\s*0')
# DryRun gate inside the pass-3 block: extract the block, assert the break.
$pass3Idx = $src.IndexOf("if (`$pass -eq 3)")
$pass3Block = ''
if ($pass3Idx -ge 0) { $pass3Block = $src.Substring($pass3Idx, [Math]::Min(900, $src.Length - $pass3Idx)) }
Assert-Equal 'sweep never runs in DryRun'            $true ($pass3Block -match '\$DryRun.*break' -and $pass3Block -match 'Invoke-StaleSweep')
Assert-Equal 'anti-loop stamp consulted (6 h)'       $true ($src -match 'stale-sweep\.stamp' -and $src -match 'TotalHours\s*-lt\s*6')
Assert-Equal 'preservation before reset (branch first)' $true ($src.IndexOf('vibe-preserve/') -gt 0 -and $src.IndexOf('reset --hard $OriginMain', $src.IndexOf('function Invoke-StaleSweep')) -gt $src.IndexOf('vibe-preserve/'))
Assert-Equal 'refused preservation => grain untouched' $true ($src -match 'branche de preservation.*impossible.*reset REFUSE' -or $src -match 'SWEEP.*impossible.*REFUSE')
# The sweep must refuse to touch a worktree a LIVE worker holds (per-grain
# lock, #17636/#3942 idiom) -- correctness hole found in review of the first
# head: a live worker makes its lock unreadable; without this guard the sweep
# stash+resets the worktree while the worker is editing it.
Assert-Equal 'live-worker guard defined'              $true ($src -match 'function Test-GrainWorkerLive')
Assert-Equal 'sweep consults the live-worker guard'   $true ($src -match 'if \(Test-GrainWorkerLive -Grain \$g\)')
# Fail-closed guards of review c.5972480466: NEITHER git call may fail open
# into the reset. The behavioral half below proves each path end-to-end.
Assert-Equal 'status exit code checked before reset'  $true ($src -match '\$rcStatus\s*=\s*\$LASTEXITCODE' -and $src -match 'git status exit .*reset REFUSE')
Assert-Equal 'non-numeric ahead refused before reset' $true ($src -match "rev-list illisible .*reset REFUSE" -and $src -match 'SWEEP .*: rev-list illisible')

# ============================================================================
# Test 2: behavioral -- the real feeder, real mode, staged stubs
# ============================================================================
Write-Host "`n=== Test 2: the real feeder executes the sweep end-to-end ===" -ForegroundColor Cyan

$savedEap = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
$root = Join-Path ([System.IO.Path]::GetTempPath()) ("vibe-sweep-" + [guid]::NewGuid().ToString('N').Substring(0,8))
$lockStream = $null
try {
    New-Item -ItemType Directory -Path $root -Force | Out-Null

    # Stage the feeder under its own scripts tree: the feeder derives repoRoot
    # from its own path, so every repoRoot-relative artifact (stamp, refresh
    # organ, worker script, logs) lives in the staging area.
    $stage = Join-Path $root 'stage'
    New-Item -ItemType Directory -Path (Join-Path $stage 'scripts/scheduling') -Force | Out-Null
    Copy-Item $srcPath (Join-Path $stage 'scripts/scheduling/vibe-feeder.ps1') -Force
    # Stub refresh organ: rc 0, queue untouched (the deadlock condition -- the
    # organ re-measures but does not unblock the stale refusals).
    Set-Content -Path (Join-Path $stage 'scripts/scheduling/refresh-vibe-queue.py') -Value "import sys`nsys.exit(0)`n"
    # Stub worker: the dispatch path runs Start-Process on this file; it must
    # exit immediately (no Mistral work, no payload side effects).
    Set-Content -Path (Join-Path $stage 'scripts/scheduling/start-vibe-worker.ps1') -Value "exit 0`n"

    # Self-origin runtime repo: base0 -> g2 work -> base1 on main; g2 lives on
    # a side branch so it stays a non-ancestor orphan for g-T.
    $rt = Join-Path $root 'rt'
    & git init -q --initial-branch=main $rt
    & git -C $rt config user.email 't@t'
    & git -C $rt config user.name 't'
    Set-Content -Path (Join-Path $rt 'f.txt') -Value 'base0'
    & git -C $rt add f.txt
    & git -C $rt commit -qm base0
    $base0 = (& git -C $rt rev-parse HEAD).Trim()
    # Orphan lineage for g-T: a commit whose SHA is NOT an ancestor of main.
    & git -C $rt checkout -q -b side
    Set-Content -Path (Join-Path $rt 'f.txt') -Value 'side'
    & git -C $rt commit -qam side-work
    $orphan = (& git -C $rt rev-parse HEAD).Trim()
    & git -C $rt checkout -q main
    Set-Content -Path (Join-Path $rt 'f.txt') -Value 'base1'
    & git -C $rt commit -qam base1
    $base1 = (& git -C $rt rev-parse HEAD).Trim()
    & git -C $rt remote add origin $rt
    & git -C $rt fetch -q origin main

    # g-S worktree at base0 with ONE own commit and one dirty file.
    $wtS = (Join-Path $root 'wtS') -replace '\\', '/'
    & git -C $rt worktree add $wtS $base0 2>$null | Out-Null
    Set-Content -Path (Join-Path $wtS 'f.txt') -Value 'gS-own-work'
    & git -C $wtS commit -qam 'gS own commit'
    $gSHead = (& git -C $wtS rev-parse HEAD).Trim()
    Set-Content -Path (Join-Path $wtS 'dirty.txt') -Value 'uncommitted'

    # g-L worktree: clean + ONE own commit (sweep-target shape) but the held
    # per-grain lock simulates a LIVE worker (#17636/#3942: a live holder
    # opens the lock with FileShare None -> unreadable). The sweep must
    # refuse this grain: no branch, no reset, untouched.
    $wtL = (Join-Path $root 'wtL') -replace '\\', '/'
    & git -C $rt worktree add $wtL $base0 2>$null | Out-Null
    Set-Content -Path (Join-Path $wtL 'f.txt') -Value 'gL-own-work'
    & git -C $wtL commit -qam 'gL own commit'
    $gLHead = (& git -C $wtL rev-parse HEAD).Trim()
    New-Item -ItemType Directory -Path (Join-Path $stage 'outputs/scheduling/logs') -Force | Out-Null
    $gLockPath = Join-Path $stage 'outputs/scheduling/logs/vibe-worker-wtL.lock'
    if ($env:OS -eq 'Windows_NT') {
        # Windows (= production): the real mechanism -- a live holder opens
        # the lock with FileShare None; a concurrent read throws a sharing
        # violation, which the guard reads as "live".
        $lockStream = [IO.File]::Open($gLockPath, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    } else {
        # Unix (CI): FileShare is NOT enforced across processes (documented
        # dotnet behavior) -- a held stream stays readable and the simulated
        # worker would look dead. Produce the same CONTRACT another way: an
        # unreadable file (chmod 000). The guard treats ANY failed read as a
        # live holder -- same idiom as Get-LiveWorkerCount -- so the scenario
        # stays faithful to the invariant on both platforms.
        Set-Content -Path $gLockPath -Value '{"pid":0,"machine":"test"}'
        & chmod 000 $gLockPath
    }

    # g-X worktree (review path 1 -- status FAILS, rev-list fine): branch at
    # base0 + one own commit. Its INDEX is made unreadable for the whole
    # child run: held FileShare.None on Windows (git exits 128 with empty
    # stdout), chmod 000 on Unix -- the same dual idiom as the g-L lock.
    # rev-list never opens the index, so the own commit is PRESERVED on its
    # branch before the status gate refuses.
    $wtX = (Join-Path $root 'wtX') -replace '\\', '/'
    & git -C $rt worktree add $wtX $base0 2>$null | Out-Null
    Set-Content -Path (Join-Path $wtX 'f.txt') -Value 'gX-own-work'
    & git -C $wtX commit -qam 'gX own commit'
    $gXHead = (& git -C $wtX rev-parse HEAD).Trim()
    $gXIdx = ((& git -C $wtX rev-parse --git-dir).Trim()) + '/index'
    if ($env:OS -eq 'Windows_NT') {
        $script:idxStream = [IO.File]::Open($gXIdx, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::None)
    } else {
        & chmod 000 $gXIdx
    }

    # g-Y worktree (review path 2 -- rev-list FAILS): DETACHED at side2,
    # then side2's commit OBJECT is deleted from the store. rev-parse HEAD
    # still resolves the detached sha (ref-only); rev-list cannot walk it.
    & git -C $rt checkout -q -b side2
    Set-Content -Path (Join-Path $rt 'f.txt') -Value 'side2'
    & git -C $rt commit -qam side2-work
    $side2 = (& git -C $rt rev-parse HEAD).Trim()
    & git -C $rt checkout -q main
    $wtY = (Join-Path $root 'wtY') -replace '\\', '/'
    & git -C $rt worktree add --detach $wtY $side2 2>$null | Out-Null
    $gYHead = (& git -C $wtY rev-parse HEAD).Trim()
    $objDir = Join-Path $rt ('.git/objects/' + $side2.Substring(0, 2))
    Remove-Item -LiteralPath (Join-Path $objDir $side2.Substring(2)) -Force

    $queuePath = Join-Path $root 'queue.json'
    $queue = [ordered]@{
        _comment = 'stale-sweep behavioral stage'
        grains = @(
            # g-S FIRST: it is the grain the sweep must unblock and the single
            # budget slot dispatches after the sweep.
            [ordered]@{ id = 'g-S'; issue = 1; baseSha = $base0; branch = 'wt/vibe-gS'; worktree = $wtS; wtHead = $gSHead; payload = 'payload S' }
            [ordered]@{ id = 'g-T'; issue = 2; baseSha = $orphan; branch = 'wt/vibe-gT'; worktree = ((Join-Path $root 'wtT') -replace '\\', '/'); wtHead = $orphan; payload = 'payload T' }
            [ordered]@{ id = 'g-L'; issue = 3; baseSha = $base0; branch = 'wt/vibe-gL'; worktree = $wtL; wtHead = $gLHead; payload = 'payload L' }
            [ordered]@{ id = 'g-X'; issue = 4; baseSha = $base0; branch = 'wt/vibe-gX'; worktree = $wtX; wtHead = $gXHead; payload = 'payload X' }
            [ordered]@{ id = 'g-Y'; issue = 5; baseSha = $base0; branch = 'wt/vibe-gY'; worktree = $wtY; wtHead = $gYHead; payload = 'payload Y' }
        )
    }
    [System.IO.File]::WriteAllText($queuePath, ($queue | ConvertTo-Json -Depth 8), (New-Object Text.UTF8Encoding $false))

    $childPs = (Get-Command pwsh -ErrorAction SilentlyContinue).Source
    if (-not $childPs) { $childPs = 'powershell' }
    $stagedFeeder = Join-Path $stage 'scripts/scheduling/vibe-feeder.ps1'
    # MaxParallel 2: the held g-L lock makes Get-LiveWorkerCount see ONE live
    # worker, so the dispatch budget is MaxParallel - vivants. With the
    # production default of 1 the budget would be 0 and g-S could never be
    # dispatched after the sweep.
    $null = & $childPs -NoProfile -ExecutionPolicy Bypass -File $stagedFeeder -QueuePath $queuePath -RuntimeDir $rt -MaxParallel 2 2>&1
    $rc = $LASTEXITCODE

    $logFile = Join-Path $stage ("outputs/scheduling/logs/vibe-feeder-{0}.log" -f (Get-Date -Format yyyyMMdd))
    $log = ''
    if (Test-Path $logFile) { $log = Get-Content $logFile -Raw -Encoding utf8 }

    Assert-Equal 'feeder child exits 0'                       0     $rc
    Assert-Equal 'log written'                                $true ($null -ne $log -and $log.Length -gt 0)
    # Pre-fix feeder stops here: SKIP + NOOP, no SWEEP lines at all.
    Assert-Equal 'g-S refused (own commits class)'           $true ($log -match 'SKIP g-S: baseSha perime')
    Assert-Equal 'g-T refused (non-ancestor class)'          $true ($log -match 'SKIP g-T: baseSha perime')
    Assert-Equal 'g-S own commits preserved (branch)'        $true ($log -match 'SWEEP g-S: 1 commit\(s\) preserve\(s\)')
    Assert-Equal 'g-S dirty worktree stashed'                $true ($log -match 'SWEEP g-S: worktree sale')
    Assert-Equal 'g-S worktree recalé on origin/main'        $true ($log -match 'SWEEP g-S: worktree recale sur origin/main')
    Assert-Equal 'sweep count logged'                        $true ($log -match 'SWEEP: [0-9]+ grain\(s\) recale\(s\)')
    Assert-Equal 'g-S dispatched after the sweep'            $true ($log -match 'worker local DETACHE lance sur grain g-S')

    # Git state: the own commit SURVIVES on a preservation branch, the worktree
    # sits on origin/main, the stash holds the dirty file.
    $preserveBranch = (& git -C $rt branch --list 'vibe-preserve/g-S-*') 2>$null
    Assert-Equal 'preservation branch exists'                $true ($null -ne $preserveBranch -and "$preserveBranch".Trim().Length -gt 0)
    if ($preserveBranch) {
        $preservedSha = (& git -C $rt rev-parse ("$preserveBranch".Trim())) 2>$null
        Assert-Equal 'preserved sha == pre-sweep HEAD'       $gSHead ("$preservedSha".Trim())
    }
    Assert-Equal 'g-S worktree reset to origin/main'         $base1 ((& git -C $wtS rev-parse HEAD).Trim())
    Assert-Equal 'dirty file gone from worktree (stashed)'   $false (Test-Path (Join-Path $wtS 'dirty.txt'))
    Assert-Equal 'stash holds the sweep entry'               $true ((& git -C $rt stash list) -match 'vibe-stale-sweep g-S')

    # g-L: live worker (held lock) -> the sweep must have refused EVERYTHING
    # on this grain: no preservation branch, worktree tip intact, still queued.
    Assert-Equal 'g-L sweep refused (worker vivant)'         $true ($log -match 'SWEEP g-L: worker vivant')
    Assert-Equal 'g-L never preserved (live worker)'         $false ($log -match 'SWEEP g-L: \d+ commit\(s\) preserve')
    $presL = (& git -C $rt branch --list 'vibe-preserve/g-L-*') 2>$null
    Assert-Equal 'g-L: no preservation branch'               $true ($null -eq $presL -or "$presL".Trim().Length -eq 0)
    Assert-Equal 'g-L worktree untouched (tip intact)'       $gLHead ((& git -C $wtL rev-parse HEAD).Trim())

    # g-X (status fails, rev-list fine): the own commit IS preserved on its
    # branch first, THEN the status gate refuses -- tip intact, nothing
    # stashed (status could not even be read), grain still queued. The
    # pre-fix feeder would have read the worktree as clean and reset it.
    Assert-Equal 'g-X sweep refused (git status exit)'      $true ($log -match 'SWEEP g-X: git status exit \d+')
    Assert-Equal 'g-X preserved BEFORE the status refusal'  $true ($log -match 'SWEEP g-X: 1 commit\(s\) preserve\(s\)')
    $presX = (& git -C $rt branch --list 'vibe-preserve/g-X-*') 2>$null
    Assert-Equal 'g-X preservation branch exists'          $true ($null -ne $presX -and "$presX".Trim().Length -gt 0)
    Assert-Equal 'g-X worktree NOT reset (tip intact)'     $gXHead ((& git -C $wtX rev-parse HEAD).Trim())
    Assert-Equal 'g-X nothing stashed (status unreadable)' $false ((& git -C $rt stash list) -match 'vibe-stale-sweep g-X')

    # g-Y (rev-list fails): refused at the rev-list gate, BEFORE any
    # preservation attempt -- no branch, tip intact, grain still queued.
    # The pre-fix feeder would have treated the empty $ahead as zero and
    # reset the worktree without preserving anything.
    Assert-Equal 'g-Y sweep refused (rev-list illisible)'   $true ($log -match 'SWEEP g-Y: rev-list illisible')
    Assert-Equal 'g-Y never preserved'                      $false ($log -match 'SWEEP g-Y: \d+ commit\(s\) preserve')
    $presY = (& git -C $rt branch --list 'vibe-preserve/g-Y-*') 2>$null
    Assert-Equal 'g-Y: no preservation branch'              $true ($null -eq $presY -or "$presY".Trim().Length -eq 0)
    Assert-Equal 'g-Y worktree untouched (tip intact)'      $gYHead ((& git -C $wtY rev-parse HEAD).Trim())

    # Queue: g-S consumed by the dispatch; g-T still there, recalé by the
    # sweep (non-ancestor refusal -> direct recale, nothing to preserve);
    # g-L, g-X, g-Y still there untouched (refused -> next tick).
    $q2 = Get-Content $queuePath -Raw -Encoding utf8 | ConvertFrom-Json
    $ids = (@($q2.grains) | ForEach-Object { $_.id }) -join ','
    Assert-Equal 'queue after tick: g-T/g-L/g-X/g-Y remain' 'g-T,g-L,g-X,g-Y' $ids
    $gT2 = @($q2.grains | Where-Object { $_.id -eq 'g-T' })[0]
    Assert-Equal 'g-T baseSha recalé to origin/main'         $base1 $gT2.baseSha
    Assert-Equal 'g-T wtHead recalé to origin/main'          $base1 $gT2.wtHead

    # Anti-loop stamp: written by the sweep, inside the staging repoRoot.
    Assert-Equal 'anti-loop stamp written'                   $true (Test-Path (Join-Path $stage 'outputs/vibe/stale-sweep.stamp'))
}
finally {
    $ErrorActionPreference = $savedEap
    if ($lockStream) { $lockStream.Dispose() }
    if ($script:idxStream) { $script:idxStream.Dispose() }
    if ($gXIdx -and (Test-Path $gXIdx) -and $env:OS -ne 'Windows_NT') {
        & chmod 644 $gXIdx 2>$null   # restore so the tree cleanup can remove it
    }
    if (Test-Path $root) {
        Get-ChildItem -Path $root -Recurse -File -Filter '.git' -ErrorAction SilentlyContinue |
            Where-Object { $_.Parent.FullName -like '*wt*' } |
            ForEach-Object { & git -C $_.Parent.FullName worktree remove --force 2>$null }
        Remove-Item -Recurse -Force $root -ErrorAction SilentlyContinue
    }
}

# ============================================================================
Write-Host "`n=== Summary ===" -ForegroundColor Cyan
Write-Host "  Passed: $TestsPassed" -ForegroundColor Green
Write-Host "  Failed: $TestsFailed" -ForegroundColor $(if ($TestsFailed -gt 0) { 'Red' } else { 'Green' })
if ($TestsFailed -gt 0) { exit 1 }
Write-Host "ALL TESTS PASSED" -ForegroundColor Green
exit 0
