<#
.SYNOPSIS
    Guard for the delivered-grain eviction in refresh-vibe-queue.py (#3643).
.DESCRIPTION
    keepable() dropped a grain only when its branch carried an OPEN PR --
    open_prs() reads `gh pr list --state open`, nothing else. A grain whose PR
    had been MERGED therefore fell out of that set and looked in-flight again:
    it SKIP-looped on its stale baseSha at every tick, the refresh re-kept it,
    and once its worktree was gone the feeder re-seeded the base and REPLAYED
    it -- a paid run on work already merged.

    Measured 2026-09-14 on g1-genai, delivered by #16041 (00:19:53Z) and
    #16067 (03:57:44Z): SKIP-looped from the first tick after the merge and
    was replayed at 07:16:01Z, the moment its worktree was removed.

    Review #3643 (2026-09-15) added two discriminating guards this harness
    pins:
      - the merged lookup is EXACT per branch (`--head`), never a bulk
        `--limit N` row window -- at the measured CoursIA rate 300 rows span
        ~58 h and a merged grain queued past the window reopens the replay;
      - a delivered NAME is not proof the GRAIN is delivered: branch names are
        positional and get reused after a drain, so a delivered branch is
        dropped only when its worktree is absent or provably empty. An
        ahead/dirty worktree on a delivered name is an in-flight generation
        and must be KEPT.

    Offline by construction: no gh, no network. The git probes inside
    keepable() are monkeypatched, so a plain temp directory stands in for the
    worktree. The static half asserts the wiring itself -- that the merged set
    is still unioned into the set keepable() consults -- because that one-line
    union is what a future "simplification" would drop while every functional
    case above still passed against a hand-fed set.

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
$mbBody = [regex]::Match($src, '(?s)def merged_branches\(slug[^)]*\):(.*?)(?=\ndef )')
Assert-Equal 'merged_branches reads --state merged' $true `
    ($mbBody.Success -and $mbBody.Groups[1].Value -match '"--state",\s*"merged"')
# Window independence (#3643 review): the merged answer must be an exact
# per-branch `--head` lookup, never a bulk row window that history scrolls
# past. Scoped to the function body for the same reason as above.
Assert-Equal 'merged_branches queries --head per branch' $true `
    ($mbBody.Success -and $mbBody.Groups[1].Value -match '"--head"')

# ============================================================================
# Tests 2-4: the drop behaviour itself, exercised offline. keepable()'s git
# probes are monkeypatched, so a temp directory stands in for the worktree and
# the ahead/dirty state is whatever the fake says. Cases 3-4 are the review's
# discriminating guard: a delivered branch NAME reused by an in-flight
# generation must NOT be dropped.
# ============================================================================
Write-Host "`n=== Test 2: a delivered branch with no in-flight work drops the grain ===" -ForegroundColor Cyan

$py = $null
foreach ($cand in @('python3', 'python')) {
    if (Get-Command $cand -ErrorAction SilentlyContinue) { $py = $cand; break }
}
if (-not $py) {
    Write-Host "  FAIL: no python interpreter on PATH -- cannot exercise keepable()" -ForegroundColor Red
    $TestsFailed++
} else {
    $probe = @'
import importlib.util, json, sys, tempfile
spec = importlib.util.spec_from_file_location("rvq", sys.argv[1])
m = importlib.util.module_from_spec(spec)
sys.argv = ["rvq"]
spec.loader.exec_module(m)

MISSING = "D:/no/such/worktree/at/all"
REAL = tempfile.mkdtemp(prefix="rvq-keepable-")

STATE = {"ahead": "0", "dirty": ""}
def fake_sh(cmd, cwd=None, check=True):
    key = " ".join(cmd)
    if "rev-list" in key:
        return STATE["ahead"]
    if "status" in key:
        return STATE["dirty"]
    return ""

m.sh = fake_sh

def run(wt, branch, delivered, ahead, dirty):
    STATE["ahead"] = ahead
    STATE["dirty"] = dirty
    q = {"grains": [{"id": "g", "worktree": wt, "branch": branch}]}
    keep, dropped = m.keepable(q, "deadbeef", set(delivered))
    return {"kept": [g["id"] for g in keep], "dropped": dropped}

# delivered + worktree absent -> dropped
print("delivered_missing=%s" % json.dumps(run(MISSING, "wt/livree", ["wt/livree"], "0", "")))
# not delivered + worktree absent -> neither kept nor journaled
print("inflight_missing=%s" % json.dumps(run(MISSING, "wt/autre", ["wt/livree"], "0", "")))
# delivered name + worktree 3 ahead -> KEPT (name reuse: in-flight generation)
print("delivered_inflight=%s" % json.dumps(run(REAL, "wt/livree", ["wt/livree"], "3", "")))
# delivered name + dirty-only worktree -> KEPT (uncommitted work is in flight)
print("delivered_dirty=%s" % json.dumps(run(REAL, "wt/livree", ["wt/livree"], "0", "M f")))
# delivered name + provably empty worktree -> dropped
print("delivered_empty=%s" % json.dumps(run(REAL, "wt/livree", ["wt/livree"], "0", "")))
# not delivered + 2 ahead -> kept
print("inflight_kept=%s" % json.dumps(run(REAL, "wt/autre", ["wt/livree"], "2", "")))
'@
    $utf8 = New-Object System.Text.UTF8Encoding($false)
    $tmpPy = [System.IO.Path]::GetTempFileName() + '.py'
    [System.IO.File]::WriteAllText($tmpPy, $probe, $utf8)
    $out = & $py $tmpPy $srcPath
    $rc = $LASTEXITCODE
    Remove-Item $tmpPy -ErrorAction SilentlyContinue

    # keepable() journals the name-reuse keeps on stdout; filter to the six
    # result lines so the assertions do not depend on the WARN interleaving.
    $lines = @($out | Where-Object { $_ -match '^(delivered_missing|inflight_missing|delivered_inflight|delivered_dirty|delivered_empty|inflight_kept)=' })

    Assert-Equal 'probe ran' 0 $rc
    Assert-Equal 'probe emitted all six cases' 6 $lines.Count

    Write-Host "`n=== Test 3: a delivered branch reused by an in-flight generation is KEPT ===" -ForegroundColor Cyan
    Assert-Equal 'delivered + absent worktree is dropped' 'delivered_missing={"kept": [], "dropped": ["g"]}' $lines[0]
    Assert-Equal 'not delivered + absent worktree is not journaled' 'inflight_missing={"kept": [], "dropped": []}' $lines[1]
    Assert-Equal 'delivered name + 3 ahead is KEPT (name reuse)' 'delivered_inflight={"kept": ["g"], "dropped": []}' $lines[2]
    Assert-Equal 'delivered name + dirty worktree is KEPT' 'delivered_dirty={"kept": ["g"], "dropped": []}' $lines[3]

    Write-Host "`n=== Test 4: a delivered branch with provably empty work is dropped; plain in-flight kept ===" -ForegroundColor Cyan
    Assert-Equal 'delivered + provably empty worktree is dropped' 'delivered_empty={"kept": [], "dropped": ["g"]}' $lines[4]
    Assert-Equal 'not delivered + 2 ahead is kept' 'inflight_kept={"kept": ["g"], "dropped": []}' $lines[5]

    # The name-reuse keep must be VISIBLE, not silent: one WARN per kept
    # delivered-name grain (cases 3 and 4 above).
    $warns = @($out | Where-Object { $_ -match 'WARN: branche livree .* reutilisee' })
    Assert-Equal 'name-reuse keeps are journaled (WARN x2)' 2 $warns.Count
}

# ============================================================================
Write-Host "`n=== Summary ===" -ForegroundColor Cyan
Write-Host "  Passed: $TestsPassed" -ForegroundColor Green
Write-Host "  Failed: $TestsFailed" -ForegroundColor $(if ($TestsFailed -gt 0) { 'Red' } else { 'Green' })
if ($TestsFailed -gt 0) { exit 1 }
Write-Host "ALL TESTS PASSED" -ForegroundColor Green
exit 0
