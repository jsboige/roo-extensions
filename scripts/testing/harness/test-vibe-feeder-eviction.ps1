<#
.SYNOPSIS
    Guard for the feeder-level eviction guard in vibe-feeder.ps1 (#3755).
.DESCRIPTION
    PR #3643 added eviction in refresh-vibe-queue.py but only on pass 2, which
    only runs when pass 1 finds the queue empty -- a delivered grain was
    therefore REPOSTED before eviction could speak. Cost measured on 14/09
    on g1-genai: 0.56 $ of NOOP.

    The fix in #3755 adds a feeder-level eviction, BEFORE Update-StaleGrainBase
    and BEFORE Prepare-Worktree, keyed on the `wtHead` field that
    refresh-vibe-queue.py now records at grain-creation time:

      if recorded wtHead != actual worktree HEAD
          -> evict (remove grain from queue, move to next)

    This is purely local (two git reads, no gh, no Python), catches the
    replay class at the feeder, and does not depend on a refresh.

    The wiring half (static) pins that the eviction sits BEFORE the post, on
    EVERY iteration. The behavioral half exercises the eviction against a
    real git worktree. Test 5 (review #3756 M1) goes one level up: it EXECUTES
    the real feeder end-to-end in -DryRun against a staged copy with a
    self-origin runtime repo and a three-grain queue, asserting on the
    feeder's own log and the resulting queue FILE -- evidence that survives
    any predicate rewrite inside this harness:
      - case A: worktree absent              -> no eviction (no wtHead mismatch)
      - case B: worktree at recorded wtHead   -> no eviction (same generation)
      - case C: worktree ahead of wtHead      -> EVICTION, grain removed from queue
      - case D: wtHead field absent           -> no eviction (legacy grains)

    Wired into the scheduling-harness job so a change to vibe-feeder.ps1
    landing on main re-runs it.
#>

$ErrorActionPreference = 'Stop'

$TestsPassed = 0
$TestsFailed = 0

function Assert-Equal {
    param([string]$TestName, $Expected, $Actual)
    if ($Expected -eq $Actual) {
        Write-Host "  PASS: $TestName (expected=$Expected, got=$Actual)" -ForegroundColor Green
        $script:TestsPassed++
    } else {
        Write-Host "  FAIL: $TestName (expected=$Expected, got=$Actual)" -ForegroundColor Red
        $script:TestsFailed++
    }
}

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
$srcPath = Join-Path $repoRoot 'scripts/scheduling/vibe-feeder.ps1'

# ============================================================================
# Test 1: the wiring. the eviction guard MUST sit before the post, before
# Update-StaleGrainBase, before Prepare-Worktree -- any other order re-opens
# the replay class this closes.
# ============================================================================
Write-Host "`n=== Test 1: the eviction guard is wired BEFORE the post ===" -ForegroundColor Cyan

$src = Get-Content $srcPath -Raw

# (a) the field is consulted
Assert-Equal 'feeder reads wtHead field'  $true ($src -match '\$g\.wtHead')
# (b) the comparison is between recorded and actual HEAD
Assert-Equal 'feeder compares wtHead to actual HEAD' $true ($src -match '\$currentHead\s*-ne\s*\$g\.wtHead')
# (c) eviction removes the grain from the queue (Write-Queue within the guard)
# Extract the eviction block by searching for the EVICT log marker, which
# sits inside the eviction branch and uniquely identifies it.
$evictStartIdx = $src.IndexOf('EVICT ')
$evictBlock = ''
if ($evictStartIdx -ge 0) {
    $evictEndIdx   = $src.IndexOf('continue', $evictStartIdx)
    if ($evictEndIdx -gt $evictStartIdx) {
        $evictBlock = $src.Substring($evictStartIdx, $evictEndIdx - $evictStartIdx + 'continue'.Length)
    }
}
Assert-Equal 'eviction block exists'           $true ($evictBlock.Length -gt 0)
Assert-Equal 'eviction rewrites the queue'     $true ($evictBlock -match 'Write-Queue -Queue \$outObj')
Assert-Equal 'eviction filters out the grain'  $true ($evictBlock -match 'Where-Object \{ \$_\.id -ne \$g\.id \}')
Assert-Equal 'eviction continues to next grain' $true ($evictBlock -match 'continue')

# (d) the eviction sits BEFORE Update-StaleGrainBase and BEFORE Invoke-RsmAppend.
# Without this ordering, the delivered grain gets posted before eviction fires.
$iEvict = $src.IndexOf('EVICT ')
$iStale = $src.IndexOf('Update-StaleGrainBase -Grain $g')
$iPost  = $src.IndexOf('Invoke-RsmAppend -AppendOptions')
Assert-Equal 'eviction marker present'            $true ($iEvict -gt 0)
# Non-vacuous forms (review #3756): with the marker absent, $iEvict is -1 and
# the bare index comparisons pass against ANY positive index. Gate each on
# $iEvict -gt 0 so the absence of the guard fails the ordering too.
Assert-Equal 'eviction sits before stale-base'    $true ($iEvict -gt 0 -and $iStale -gt $iEvict)
Assert-Equal 'eviction sits before post'          $true ($iEvict -gt 0 -and $iPost -gt $iEvict)

# (e) the post is GATED by the eviction -- we never reach Invoke-RsmAppend on
# a grain whose wtHead mismatch was detected. Static check: both the eviction
# block and the post live in the same foreach ($g in $grains) block.
$firstForeach = $src.IndexOf('foreach ($g in $grains)')
$secondForeach = $src.IndexOf('foreach ($g in $grains)', $firstForeach + 1)
Assert-Equal 'feeder has a single foreach on grains'           $true ($secondForeach -lt 0 -or $secondForeach -eq -1)
Assert-Equal 'eviction marker inside the grains foreach'        $true ($firstForeach -lt $iEvict)
Assert-Equal 'post inside the grains foreach'                   $true ($firstForeach -lt $iPost)

# ============================================================================
# Test 2: refresh-vibe-queue.py now writes the wtHead field on each grain.
# Without this, the feeder's discriminator has nothing to compare against and
# the guard is silent. This is the schema half of #3755.
# ============================================================================
Write-Host "`n=== Test 2: refresh-vibe-queue.py records wtHead at grain creation ===" -ForegroundColor Cyan

$refreshPath = Join-Path $repoRoot 'scripts/scheduling/refresh-vibe-queue.py'
$refreshSrc = Get-Content $refreshPath -Raw

Assert-Equal 'refresh captures wtHead'        $true ($refreshSrc -match 'wt_head\s*=\s*sh\(\[.*"rev-parse",\s*"HEAD"')
Assert-Equal 'refresh persists wtHead on grain' $true ($refreshSrc -match '"wtHead":\s*wt_head')

# ============================================================================
# Test 3: the eviction logic, exercised against a real git worktree. We
# extract the exact decision block from the feeder, feed it four real
# scenarios, and assert the verdict + queue-rewrite semantics.
# ============================================================================
Write-Host "`n=== Test 3: the eviction predicate, exercised on a real repo ===" -ForegroundColor Cyan

$evictLine = ($src -split "`n" | Where-Object { $_ -match '^\s*\$currentHead\s*=\s*\(git ' } | Select-Object -First 1)
$compareLine = ($src -split "`n" | Where-Object { $_ -match '^\s*if \(\$currentHead\s*-and\s+\$currentHead\s+-ne' } | Select-Object -First 1)
Assert-Equal 'extraction: head read line'    $true ($null -ne $evictLine)
Assert-Equal 'extraction: compare line'      $true ($null -ne $compareLine)

$savedEap = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
$root = Join-Path ([System.IO.Path]::GetTempPath()) ("vibe-evict-" + [guid]::NewGuid().ToString('N').Substring(0,8))
try {
    New-Item -ItemType Directory -Path $root -Force | Out-Null
    $repo = Join-Path $root 'runtime'
    & git init -q --initial-branch=main $repo
    & git -C $repo config user.email 't@t'
    & git -C $repo config user.name 't'
    Set-Content -Path (Join-Path $repo 'f.txt') -Value 'base'
    & git -C $repo add f.txt
    & git -C $repo commit -qm base
    $baseSha = (& git -C $repo rev-parse HEAD).Trim()

    # --- Case A: worktree absent. No wtHead mismatch possible (Test-Path fails
    # at the guard's first AND clause). Recorded wtHead is non-empty but the
    # worktree does not exist on disk.
    $g = [pscustomobject]@{ id = 'g-A'; worktree = (Join-Path $root 'missing'); wtHead = $baseSha; baseSha = $baseSha; branch = 'wt/missing' }
    $present = Test-Path $g.worktree
    Assert-Equal 'case A: worktree absent -> guard short-circuits' $false $present

    # --- Case B: worktree at the recorded wtHead. Same generation. No eviction.
    $wtB = Join-Path $root 'wtB'
    & git -C $repo worktree add $wtB $baseSha 2>$null | Out-Null
    $gB = [pscustomobject]@{ id = 'g-B'; worktree = $wtB; wtHead = $baseSha; baseSha = $baseSha; branch = 'wt/B' }
    $currentB = (git -C $gB.worktree rev-parse HEAD).Trim()
    $verdictB = ($currentB -eq $gB.wtHead)
    Assert-Equal 'case B: HEAD == wtHead -> no eviction' $true $verdictB

    # --- Case C: worktree AHEAD of wtHead (simulates: worktree reused for a
    # new generation that pulled in additional commits since grain creation).
    # This is the exact replay class #3755 closes.
    $wtC = Join-Path $root 'wtC'
    & git -C $repo worktree add $wtC $baseSha 2>$null | Out-Null
    Set-Content -Path (Join-Path $wtC 'f.txt') -Value 'g2-work'
    & git -C $wtC commit -qam 'g2 commit'
    $gC = [pscustomobject]@{ id = 'g-C'; worktree = $wtC; wtHead = $baseSha; baseSha = $baseSha; branch = 'wt/C' }
    $currentC = (git -C $gC.worktree rev-parse HEAD).Trim()
    $verdictC = ($currentC -eq $gC.wtHead)
    Assert-Equal 'case C: HEAD diverges from wtHead -> EVICTION triggered' $false $verdictC
    Assert-Equal 'case C: divergence is real (HEAD != wtHead)' $true ($currentC -ne $gC.wtHead)
    $ancestorOut = & git -C $wtC merge-base --is-ancestor $baseSha HEAD 2>$null
    $ancestorRc = $LASTEXITCODE
    Assert-Equal 'case C: ahead sha is a descendant of wtHead' $true ($ancestorRc -eq 0)

    # --- Case D: legacy grain without wtHead (pre-#3755 queue). Guard
    # short-circuits on the missing field; existing grains are not evicted
    # retroactively -- the refresh rewrites them on the next tick.
    $gD = [pscustomobject]@{ id = 'g-D'; worktree = $wtC; baseSha = $baseSha; branch = 'wt/D' }
    $hasWtHead = $gD.PSObject.Properties['wtHead'] -and $gD.wtHead
    Assert-Equal 'case D: legacy grain without wtHead -> guard skips' $false $hasWtHead

    # --- Case E: the recorded wtHead is empty string (refresh skipped capture,
    # e.g. worktree did not exist at refresh time). Guard short-circuits.
    $gE = [pscustomobject]@{ id = 'g-E'; worktree = $wtB; wtHead = ''; baseSha = $baseSha; branch = 'wt/E' }
    $truthy = $gE.PSObject.Properties['wtHead'] -and $gE.wtHead
    Assert-Equal 'case E: empty wtHead -> guard skips' $false $truthy

    # --- Case F: regression check for issue criterion d'acceptation. The test
    # MUST FAIL on the pre-#3755 code, which had no wtHead field and no
    # eviction guard. We simulate both worlds:
    #   - pre-fix: a delivered grain (worktree ahead, branch reused) is POSTED
    #   - post-fix: the SAME grain is EVICTED before the post
    # If the feeder source no longer contains the eviction guard, the post-fix
    # verdict collapses to "would have posted" -> this assertion fails, which
    # is exactly what the issue requires.
    Write-Host "`n=== Test 4: criterion d'acceptation #3755 (post-fix evicts where pre-fix posted) ===" -ForegroundColor Cyan
    $hasEvictionGuard = $src.IndexOf('EVICT ') -gt 0 -and $src.IndexOf('wtHead') -gt 0
    $gF = [pscustomobject]@{ id = 'g-F'; worktree = $wtC; wtHead = $baseSha; baseSha = $baseSha; branch = 'wt/F' }
    $currentF = (git -C $gF.worktree rev-parse HEAD).Trim()
    $wtHeadMismatch = ($currentF -ne $gF.wtHead)
    $postFixVerdict = if ($hasEvictionGuard -and $wtHeadMismatch) { 'EVICTED' } else { 'POSTED' }
    Assert-Equal 'criterion d''acceptation: post-fix evicts the delivered grain' 'EVICTED' $postFixVerdict

    # --- Test 5 (behavioral, review #3756 M1): EXECUTE the real feeder. The
    # stages above pin the order by reading the source or replaying a copy of
    # the predicate -- an inversion the copy does not share stays invisible.
    # This stage runs the feeder itself in -DryRun against a staged copy, a
    # self-origin runtime repo, and a three-grain queue, then asserts on the
    # feeder's own LOG FILE and the resulting queue FILE:
    #   g-A: worktree ahead of its recorded wtHead -> EVICTED (replay class)
    #   g-B: stale baseSha, sane worktree -> RECALé (reset + baseSha + wtHead
    #        updated by Update-StaleGrainBase) and the one reaching DRY-RUN
    #   g-C: healthy, never reached (DryRun exits at the first printable grain)
    # Post-conditions prove M2 (g-A stays out of the queue even though g-B's
    # Update-StaleGrainBase rewrites the queue afterwards) and M3 (g-B.wtHead
    # follows the reset instead of staying at the pre-reset base).
    Write-Host "`n=== Test 5: the real feeder, executed end-to-end in DryRun ===" -ForegroundColor Cyan
    $stage = Join-Path $root 'stage'
    New-Item -ItemType Directory -Path (Join-Path $stage 'scripts/scheduling') -Force | Out-Null
    Copy-Item $srcPath (Join-Path $stage 'scripts/scheduling/vibe-feeder.ps1') -Force
    # The feeder derives repoRoot from its own path -> $stage, so Test-RunInFlight
    # reads an empty log dir and every post path is inert in DryRun.
    $rt = Join-Path $root 'rt5'
    & git init -q --initial-branch=main $rt
    & git -C $rt config user.email 't@t'
    & git -C $rt config user.name 't'
    Set-Content -Path (Join-Path $rt 'f.txt') -Value 'base0'
    & git -C $rt add f.txt
    & git -C $rt commit -qm base0
    $rtBase0 = (& git -C $rt rev-parse HEAD).Trim()
    Set-Content -Path (Join-Path $rt 'f.txt') -Value 'base1'
    & git -C $rt commit -qam base1
    $rtBase1 = (& git -C $rt rev-parse HEAD).Trim()
    # Self-referencing origin: the feeder's `fetch origin main` and
    # `rev-parse origin/main` both resolve without any network.
    & git -C $rt remote add origin $rt
    & git -C $rt fetch -q origin main

    # Queue worktree paths use FORWARD slashes: `git worktree list` prints
    # them that way and Prepare-Worktree matches the grain path against that
    # output verbatim (backslashes would never match -> spurious re-add).
    $wtA5 = (Join-Path $root 'wtA5') -replace '\\', '/'
    $wtB5 = (Join-Path $root 'wtB5') -replace '\\', '/'
    & git -C $rt worktree add $wtA5 $rtBase0 2>$null | Out-Null
    Set-Content -Path (Join-Path $wtA5 'f.txt') -Value 'g2-work'
    & git -C $wtA5 commit -qam 'reused generation'
    & git -C $rt worktree add $wtB5 $rtBase0 2>$null | Out-Null

    $queue5 = [ordered]@{
        _comment = 'behavioral stage (test 5)'
        grains = @(
            [ordered]@{ id = 'g-A'; issue = 1; baseSha = $rtBase0; branch = 'wt/vibe-gA'; worktree = $wtA5; wtHead = $rtBase0; payload = 'payload A' }
            [ordered]@{ id = 'g-B'; issue = 2; baseSha = $rtBase0; branch = 'wt/vibe-gB'; worktree = $wtB5; wtHead = $rtBase0; payload = 'payload B' }
            [ordered]@{ id = 'g-C'; issue = 3; baseSha = $rtBase1; branch = 'wt/vibe-gC'; worktree = ((Join-Path $root 'wtC5') -replace '\\', '/'); wtHead = $rtBase1; payload = 'payload C' }
        )
    }
    $queuePath5 = Join-Path $root 'queue5.json'
    [System.IO.File]::WriteAllText($queuePath5, ($queue5 | ConvertTo-Json -Depth 8), (New-Object System.Text.UTF8Encoding $false))

    $childPs = (Get-Command pwsh -ErrorAction SilentlyContinue).Source
    if (-not $childPs) { $childPs = 'powershell' }
    $stagedFeeder = Join-Path $stage 'scripts/scheduling/vibe-feeder.ps1'
    $null = & $childPs -NoProfile -ExecutionPolicy Bypass -File $stagedFeeder -DryRun -QueuePath $queuePath5 -RuntimeDir $rt 2>&1
    $rc5 = $LASTEXITCODE
    # Evidence lives in the feeder's OWN log file (Add-Content path, immune to
    # Write-Host stream-capture differences between PS 5.1 and pwsh).
    $logFile5 = Join-Path $stage ("outputs/scheduling/logs/vibe-feeder-{0}.log" -f (Get-Date -Format yyyyMMdd))
    $log5 = ''
    if (Test-Path $logFile5) { $log5 = Get-Content $logFile5 -Raw -Encoding utf8 }
    Assert-Equal 'test5: feeder child exits 0'             0     $rc5
    Assert-Equal 'test5: log file written by the child'    $true ($null -ne $log5 -and $log5.Length -gt 0)
    Assert-Equal 'test5: g-A evicted (EVICT in feeder log)' $true ($log5 -match 'EVICT g-A')
    Assert-Equal 'test5: g-B reaches the DRY-RUN print'    $true ($log5 -match 'grain pret: g-B')
    Assert-Equal 'test5: g-A never reaches the DRY-RUN'    $false ($log5 -match 'grain pret: g-A')

    $q5 = Get-Content $queuePath5 -Raw -Encoding utf8 | ConvertFrom-Json
    $ids5 = (@($q5.grains) | ForEach-Object { $_.id }) -join ','
    Assert-Equal 'test5 (M2): evicted grain stays out after Update-StaleGrainBase rewrite' 'g-B,g-C' $ids5
    $gB5 = @($q5.grains | Where-Object { $_.id -eq 'g-B' })[0]
    Assert-Equal 'test5 (M3): g-B baseSha recalé to new main' $rtBase1 $gB5.baseSha
    Assert-Equal 'test5 (M3): g-B wtHead recalé to new main'  $rtBase1 $gB5.wtHead
    Assert-Equal 'test5: g-B worktree reset to new main'      $rtBase1 ((& git -C $wtB5 rev-parse HEAD).Trim())
}
finally {
    $ErrorActionPreference = $savedEap
    if (Test-Path $root) {
        # Cleanup worktrees first (they hold locks on the repo), then the repo.
        # A WORKTREE's .git is a FILE, not a directory -- the previous
        # -Directory filter never matched anything and this git pass never ran
        # (review #3756 minor). Files named .git under *wt* paths only; the
        # runtime repos' own .git directories are excluded by the pattern.
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
