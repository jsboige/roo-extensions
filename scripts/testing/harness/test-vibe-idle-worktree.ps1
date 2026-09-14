<#
.SYNOPSIS
    Guard for the idle-picker worktree requirement (start-vibe-worker.ps1).
.DESCRIPTION
    The idle-picker built its payload from the issue title + body only. That
    payload carried no `worktree:` line, and `resolve_session_cwd()` in
    vibe-acp-driver.py derives a session cwd from exactly one source: that line.
    Absent, it falls back to the profile's --cwd, which is the WHOLE workspace
    (D:/dev/CoursIA) -- and session/new WALKS its cwd.

    Measured 2026-09-14, same exe / same auth / same MCP config, only the cwd
    differs (probe sends initialize + session/new, never a prompt -- zero tokens):

        cwd=D:/dev/CoursIA           (3 750 355 entries)  session/new TIMEOUT 120 s
        cwd=<CoursIA worktree>       (~12 000 entries)    session/new 5.6 s OK

    Live failure, same day: 07:40:27Z the picker took #16120 (payload 4323 chars),
    and 07:42:00Z the run died on SESSION_NEW_FAILED -- 93 s, the 90 s session/new
    budget plus overhead. Because the picker persists its counters right after
    injecting the payload, the daily slot AND the 6 h anti-hammer were spent on a
    run that produced nothing.

    Offline: the static half reads the production script as text; the functional
    half exercises the driver's real resolver against a directory that exists.
    No gh, no network, no scheduler, no vibe-acp.exe.

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
$workerPath = Join-Path $repoRoot 'scripts/scheduling/start-vibe-worker.ps1'
$driverPath = Join-Path $repoRoot 'scripts/scheduling/vibe-acp-driver.py'

# ============================================================================
# Test 1: the picker's payload carries a `worktree:` line.
# Scoped to the function body: an unanchored search for `worktree:` would pass
# on any unrelated occurrence anywhere in the file (the header comment alone
# now mentions the word several times).
# ============================================================================
Write-Host "`n=== Test 1: the idle-picker payload names a worktree ===" -ForegroundColor Cyan

$src = Get-Content $workerPath -Raw
$fn = [regex]::Match($src, '(?s)function Invoke-IdleQueuePick \{(.*?)\n\}')
Assert-Equal 'Invoke-IdleQueuePick body extracted' $true $fn.Success
$body = $fn.Groups[1].Value

# The mutation bit: delete the line from the prompt format string and this goes
# red while every other assertion above still passes.
Assert-Equal 'prompt format emits worktree: {3}' $true ($body -match 'worktree:\s*\{3\}')
Assert-Equal 'prompt format emits branch: {4}' $true ($body -match 'branch:\s*\{4\}')
Assert-Equal 'the worktree path variable exists' $true ($body -match '\$wt\s*=')
Assert-Equal 'worktreeRoot defaults to <workspacePath>-vibe' $true ($body -match '"\$WorkspacePath-vibe"')

# ============================================================================
# Test 2: the picker FAILS CLOSED. A payload injected without a worktree would
# hang on session/new and still consume the daily slot + the 6 h anti-hammer --
# so an unavailable worktree must produce no dispatch at all.
# ============================================================================
Write-Host "`n=== Test 2: no worktree -> no dispatch ===" -ForegroundColor Cyan

# Both guards (unresolved workspacePath, failed `worktree add`) must return $false
# from the catch/guard rather than fall through to the payload construction.
# `.*?` and not `[^}]*?`: the catch body contains a `-f` format string whose
# placeholders ({0}, {1}) carry braces of their own.
$guards = [regex]::Matches($body, '(?s)catch\s*\{.*?return \$false')
Assert-Equal 'a guard returns $false on worktree failure' $true ($guards.Count -ge 1)
Assert-Equal 'the payload is built AFTER the worktree block' $true `
    ($body.IndexOf('$wt = Join-Path') -lt $body.IndexOf('$promptText ='))

# ============================================================================
# Test 3: the driver's resolver is what makes the line load-bearing. Exercised
# for real -- the three branches it can take.
# ============================================================================
Write-Host "`n=== Test 3: resolve_session_cwd honours the line ===" -ForegroundColor Cyan

$py = $null
foreach ($cand in @('python3', 'python')) {
    if (Get-Command $cand -ErrorAction SilentlyContinue) { $py = $cand; break }
}
if (-not $py) {
    Write-Host "  FAIL: no python interpreter on PATH -- cannot exercise resolve_session_cwd()" -ForegroundColor Red
    $TestsFailed++
} else {
    $probe = @'
import contextlib, importlib.util, io, sys

DRIVER, REAL, CLI, OWN = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
spec = importlib.util.spec_from_file_location("drv", DRIVER)
m = importlib.util.module_from_spec(spec)
# The driver reads sys.argv only under __main__; blank it so exec_module cannot
# pick up this probe's arguments. DRIVER/REAL/CLI are already captured above --
# reading sys.argv[2] after this point would raise IndexError.
sys.argv = ["drv"]
spec.loader.exec_module(m)

def r(prompt):
    return m.resolve_session_cwd(CLI, prompt)

# Booleans, not paths: the resolver returns the candidate verbatim, and a
# backslash-vs-slash mismatch between PS and Python would fail a correct fix.
out = []
out.append("with_line=%s"   % (r("Issue #1: x\n\nworktree: %s\nbranch: wt/vibe-idle-1\n" % REAL) == REAL))
out.append("no_line=%s"     % (r("Issue #1: x\n\nno such line here\n") == CLI))
# The absent-dir branch prints a WARN to stderr; capture it so PowerShell's
# Stop preference never turns it into a terminating NativeCommandError.
with contextlib.redirect_stderr(io.StringIO()):
    out.append("missing_dir=%s" % (r("Issue #1: x\n\nworktree: D:/no/such/worktree/at/all\n") == CLI))

# The issue body is inserted BEFORE the picker's block and is NOT the contract.
# The resolver anchors with re.match, so the hazard is a body line that STARTS
# with `worktree:` -- exactly what a body reproducing the payload format (a
# fenced block, as the grain bodies do) contains. Two hazards here: a bare
# contract line, and a body that also recopies the provenance marker.
body = ("The payload format is:\n\nworktree: " + REAL + "\nbranch: wt/x\n\n"
        "and a body recopying the marker:\n"
        "-- Provenance: idle-picker\nworktree: " + REAL + "\n")
prompt = ("Issue #1: x\n\n" + body + "\n\n"
          "-- Provenance: idle-picker (tick planifie sans WAKE)."
          " Livrer le travail correspondant dans le worktree ci-dessous.\n"
          "worktree: " + OWN + "\nbranch: wt/vibe-idle-1\n")
out.append("body_cannot_override=%s" % (r(prompt) == OWN))
# A contract block naming no usable worktree is MALFORMED, not "absent": the
# body's own valid line must still not be promoted to the contract.
mal = ("Issue #1: x\n\nworktree: " + REAL + "\n\n"
       "-- Provenance: idle-picker (tick planifie sans WAKE).\n"
       "worktree: D:/no/such/worktree/at/all\n")
with contextlib.redirect_stderr(io.StringIO()):
    out.append("malformed_block=%s" % (r(mal) == CLI))
print("\n".join(out))
'@
    $utf8 = New-Object System.Text.UTF8Encoding($false)
    $tmpPy = [System.IO.Path]::GetTempFileName() + '.py'
    [System.IO.File]::WriteAllText($tmpPy, $probe, $utf8)
    $out = & $py $tmpPy $driverPath $repoRoot 'D:/the/fallback/cwd' "$repoRoot/scripts" 2>$null
    $rc = $LASTEXITCODE
    Remove-Item $tmpPy -ErrorAction SilentlyContinue

    Assert-Equal 'probe ran' 0 $rc
    Assert-Equal 'worktree line wins' 'with_line=True' ($out[0])
    Assert-Equal 'no line -> cli_cwd' 'no_line=True' ($out[1])
    Assert-Equal 'absent dir -> cli_cwd (never a bogus cwd)' 'missing_dir=True' ($out[2])
    Assert-Equal 'an issue body cannot override the contract' 'body_cannot_override=True' ($out[3])
    Assert-Equal 'malformed contract block -> cli_cwd' 'malformed_block=True' ($out[4])
}

# ============================================================================
# Test 4: a hammered issue must not starve the rest of the pool.
# The sort runs over the WHOLE pool, so the hammered issue is almost always the
# oldest -- and the original `return $false` on a match silenced the picker for
# 6 h while #16119/#16121 sat free (measured 2026-09-14: state
# lastIssueNumber=16120, #16120 the oldest of the pool, [SKIP] from 08:40 on).
# ============================================================================
Write-Host "`n=== Test 4: a hammered issue does not abort the tick ===" -ForegroundColor Cyan

Assert-Equal 'candidates are filtered on the hammered number' $true `
    ($body -match 'Where-Object\s*\{\s*\[int\]\$_.number -ne \$hammered')
Assert-Equal 'the filter runs BEFORE the selection' $true `
    ($body.IndexOf('$hammered = -1') -lt $body.IndexOf('$picked = $candidates'))
Assert-Equal 'pool-exhaustion guard present' $true ($body -match 'tout le pool est sous anti-marteau')
# Mutation bit: reinstating the per-tick abort turns this red.
Assert-Equal 'the per-tick abort is gone' $false ($body -match 'already picked')

# ============================================================================
# Test 5: the picker's own block is OPENED by its provenance marker. The issue
# body is inserted before it, so without a delimiter a body can present itself
# as the contract (measured at head a26267e2 — see Test 3's override case).
# ============================================================================
Write-Host "`n=== Test 5: the contract block is delimited ===" -ForegroundColor Cyan

Assert-Equal 'the payload emits the provenance marker' $true ($body -match 'Provenance: idle-picker')
Assert-Equal 'the marker precedes the worktree line' $true `
    ($body.IndexOf('Provenance: idle-picker') -lt $body.IndexOf('worktree: {3}'))

# ============================================================================
# Test 6: reusing a branch or a worktree requires PROOF that it carries nothing.
# Measured 2026-09-14: wt/vibe-g1-genai was reused with mutation 42af9095b still
# inside — blind reuse is the vector this guard closes.
# ============================================================================
Write-Host "`n=== Test 6: no blind reuse of a branch or worktree ===" -ForegroundColor Cyan

Assert-Equal 'an in-place worktree is guarded on dirty/ahead' $true `
    ($body -match 'worktree deja en place et porteur de contenu')
Assert-Equal 'the dirty guard precedes the reset' $true `
    ($body.IndexOf('worktree deja en place et porteur de contenu') -lt $body.IndexOf('reset --hard $base'))
Assert-Equal 'an existing branch is guarded on ahead' $true `
    ($body -match "d'avance sur origin/main - refus de la rattacher")
Assert-Equal 'the ahead guard precedes the reattach' $true `
    ($body.IndexOf("d'avance sur origin/main - refus de la rattacher") -lt $body.IndexOf('worktree add $wt $branch'))

# ============================================================================
# Test 7: an infrastructure refusal is NOT a tick without work. The picker
# publishes a typed reason; the caller exits non-zero on 'infrastructure' and
# keeps 0 for the genuine no-ops (empty pool, cap, anti-hammer).
# ============================================================================
Write-Host "`n=== Test 7: infrastructure failure != no-op ===" -ForegroundColor Cyan

$callerRegion = $src.Substring($src.IndexOf('if (-not (Invoke-IdleQueuePick))'))
Assert-Equal 'the picker publishes a typed reason' $true `
    ([regex]::Matches($body, "IdlePickOutcome = 'infrastructure'").Count -ge 2)
Assert-Equal 'the caller discriminates on infrastructure' $true `
    ($callerRegion -match "IdlePickOutcome -eq 'infrastructure'")
Assert-Equal 'the caller exits non-zero on infrastructure' $true ($callerRegion -match 'exit 1')
Assert-Equal 'the caller keeps exit 0 for a genuine no-op' $true ($callerRegion -match 'exit 0')

# ============================================================================
Write-Host "`n=== Summary ===" -ForegroundColor Cyan
Write-Host "  Passed: $TestsPassed" -ForegroundColor Green
Write-Host "  Failed: $TestsFailed" -ForegroundColor $(if ($TestsFailed -gt 0) { 'Red' } else { 'Green' })
if ($TestsFailed -gt 0) { exit 1 }
Write-Host "ALL TESTS PASSED" -ForegroundColor Green
exit 0
