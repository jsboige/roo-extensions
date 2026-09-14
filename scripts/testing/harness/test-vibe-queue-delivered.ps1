<#
.SYNOPSIS
    Guard for the delivered-grain eviction in refresh-vibe-queue.py (#3641).
.DESCRIPTION
    keepable() dropped a grain only when its branch carried an OPEN PR --
    open_prs() reads `gh pr list --state open`, nothing else. A grain whose PR
    had been MERGED therefore fell out of that set and looked in-flight again:
    it SKIP-looped on its stale baseSha at every tick, the refresh re-kept it,
    and once its worktree was gone the feeder re-seeded the base and REPLAYED
    it -- a paid run on work already merged.

    Measured 2026-09-14 on g1-genai, delivered by #16041 (00:19:53Z) and
    #16067 (03:57:44Z): SKIP-looped from the first tick after the merge and was
    replayed at 07:16:01Z, the moment its worktree was removed.

    Offline by construction: no gh, no network. The drop path returns before
    any git call, so a non-existent worktree is enough to exercise it. The
    static half asserts the wiring itself -- that the merged set is still
    unioned into the set keepable() consults -- because that one-line union is
    what a future "simplification" would drop while every functional case
    above still passed against a hand-fed set.

    Wired into the scheduling-harness job so a change to the production script
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
$srcPath = Join-Path $repoRoot 'scripts/scheduling/refresh-vibe-queue.py'

# ============================================================================
# Test 1: the wiring. keepable() must be handed the union of open AND merged
# branches -- the functional tests below pass a set directly and so would stay
# green if this union were removed from main().
# ============================================================================
Write-Host "`n=== Test 1: merged branches are unioned into keepable's delivered set ===" -ForegroundColor Cyan

$src = Get-Content $srcPath -Raw
Assert-Equal 'merged_branches is defined' $true ($src -match 'def merged_branches\(')
Assert-Equal 'main() unions open | merged' $true ($src -match 'open_branches\s*\|\s*merged_branches\(')
Assert-Equal 'the union is what keepable() receives' $true ($src -match 'keepable\(old,\s*base,\s*delivered\)')
# The stale read is what created the hole: a merged PR must not be reachable
# only through the open list. Scoped to the function body -- an unanchored
# search would pass on any `--state merged` anywhere in the file.
$mbBody = [regex]::Match($src, '(?s)def merged_branches\(slug\):(.*?)(?=\ndef )')
Assert-Equal 'merged_branches reads --state merged' $true `
    ($mbBody.Success -and $mbBody.Groups[1].Value -match '"--state",\s*"merged"')

# ============================================================================
# Tests 2-3: the drop behaviour itself, exercised offline. Both cases use a
# worktree path that does not exist, which also pins the branch check as the
# FIRST decision: were the order reversed, the missing worktree would skip the
# grain and it would never be dropped.
# ============================================================================
Write-Host "`n=== Test 2: a delivered branch drops the grain ===" -ForegroundColor Cyan

$py = $null
foreach ($cand in @('python3', 'python')) {
    if (Get-Command $cand -ErrorAction SilentlyContinue) { $py = $cand; break }
}
if (-not $py) {
    Write-Host "  FAIL: no python interpreter on PATH -- cannot exercise keepable()" -ForegroundColor Red
    $TestsFailed++
} else {
    $probe = @'
import importlib.util, json, sys
spec = importlib.util.spec_from_file_location("rvq", sys.argv[1])
m = importlib.util.module_from_spec(spec)
sys.argv = ["rvq"]
spec.loader.exec_module(m)

MISSING = "D:/no/such/worktree/at/all"
def run(branch, delivered):
    q = {"grains": [{"id": "g", "worktree": MISSING, "branch": branch}]}
    keep, dropped = m.keepable(q, "deadbeef", set(delivered))
    return dropped

# delivered branch -> dropped, despite the worktree being gone
print("delivered=%s" % json.dumps(run("wt/livree", ["wt/livree"])))
# not delivered -> skipped (neither kept nor dropped), never a spurious drop
print("inflight=%s" % json.dumps(run("wt/en-vol", ["wt/autre"])))
'@
    $utf8 = New-Object System.Text.UTF8Encoding($false)
    $tmpPy = [System.IO.Path]::GetTempFileName() + '.py'
    [System.IO.File]::WriteAllText($tmpPy, $probe, $utf8)
    $out = & $py $tmpPy $srcPath
    $rc = $LASTEXITCODE
    Remove-Item $tmpPy -ErrorAction SilentlyContinue

    Assert-Equal 'probe ran' 0 $rc
    Assert-Equal 'delivered grain is dropped' 'delivered=["g"]' ($out[0])
    Assert-Equal 'in-flight grain is not dropped' 'inflight=[]' ($out[1])
}

# ============================================================================
Write-Host "`n=== Summary ===" -ForegroundColor Cyan
Write-Host "  Passed: $TestsPassed" -ForegroundColor Green
Write-Host "  Failed: $TestsFailed" -ForegroundColor $(if ($TestsFailed -gt 0) { 'Red' } else { 'Green' })
if ($TestsFailed -gt 0) { exit 1 }
Write-Host "ALL TESTS PASSED" -ForegroundColor Green
exit 0
