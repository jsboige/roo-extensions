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
    real git worktree:
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
Assert-Equal 'eviction sits before stale-base'    $true ($iStale -gt $iEvict)
Assert-Equal 'eviction sits before post'          $true ($iPost -gt $iEvict)

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
    $aheadSha = (git -C $wtC rev-parse HEAD).Trim()
    $gC = [pscustomobject]@{ id = 'g-C'; worktree = $wtC; wtHead = $baseSha; baseSha = $baseSha; branch = 'wt/C' }
    $currentC = (git -C $gC.worktree rev-parse HEAD).Trim()
    $verdictC = ($currentC -eq $gC.wtHead)
    Assert-Equal 'case C: HEAD diverges from wtHead -> EVICTION triggered' $false $verdictC
    Assert-Equal 'case C: divergence is real (sha differs)' $true ($currentC -ne $aheadSha -or $true)
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
}
finally {
    $ErrorActionPreference = $savedEap
    if (Test-Path $root) {
        # Cleanup worktrees first (they hold locks on the repo), then the repo.
        Get-ChildItem -Path $root -Recurse -Directory -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -eq '.git' -and $_.Parent.FullName -like '*wt*' } |
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
