# ensure-build-fresh.ps1 — Rebuild the MCP submodule build/ if stale (#2822 STALE-TRAP)
# Usage: powershell -File scripts/claude/ensure-build-fresh.ps1 [-RepoRoot <path>] [-DryRun] [-Arm] [-Headless] [-RequireFresh]
#
# WHY: Interactive Claude Code executor sessions run `git submodule update` (Phase 0)
# which refreshes the TypeScript SOURCE but never triggers `npm run build`. The compiled
# `build/*.js` drifts stale vs `src/*.ts`, so a VS Code restart can silently serve
# pre-fix code — defeating the very fix the restart was meant to activate (#2822).
# The scheduled worker already rebuilds (`start-claude-worker.ps1` `Sync-McpSubmoduleBuild`);
# this helper mirrors that staleness check + rebuild for the INTERACTIVE path.
#
# WHAT: Compares the newest mtime of compiled source (`src/**/*.ts`, excluding tests which
# tsconfig.exclude removes from compilation) against the newest `build/**/*.js`. If the
# source is newer than the build (or build/ is absent), runs `npm run build` (clean + tsc).
# Idempotent: a no-op when the build is already fresh -- and, since the content-key guard below,
# also when the mtimes merely LOOK stale while `build-info.json` proves the build came from the
# source currently checked out. A rebuild owes a restart, so a redundant one costs an operator
# interruption, not just CPU. Legacy callers remain non-fatal on
# skips/build failures; `-RequireFresh` makes those conditions block an executor pre-flight.
#
# ARM GUARD (#3489, revised by the #3489 FRICTION arbitration): rebuilding `build/` while a
# live RSM host process runs produces mixed ESM graphs -> the `assertSharedStoreAccessible`
# crash on the next dynamic import, which makes `roosync_messages` (inbox) unreadable until a
# VS Code restart. Any live host is armed by a rebuild, fresh or stale (proven 2026-09-06).
#
# What decides is NOT how many hosts are alive. RSM is the MCP of every session, so on an
# interactive machine that count is never 0, and "refuse under live hosts" reduces to "never
# rebuild" (measured 2026-09-07: po-2026 STALE 14 h across 4 executor cycles, po-2025
# deadlocked; both released only by direct human mandate). What decides is whether the CALLER
# can close the armed window with a restart:
#   - interactive caller (default)   -> rebuild, then emit `ARM`. The machine is armed until
#                                       the operator restarts VS Code; that restart is OWED.
#   - headless caller (`-Headless`)  -> `ARMED-DEFER`. A worker/cron/pre-flight cannot restart
#                                       VS Code, so its rebuild leaves the machine armed
#                                       indefinitely (measured po-2024, 2026-09-07 02:08Z).
# `-Arm` overrides `-Headless`, for a human running a scheduled path by hand under mandate.
#
# NOTE: This ensures the ON-DISK build is current. In strict mode it also detects the distinct
# failure mode where live MCP hosts predate that fresh build and returns 10, requiring a VS Code
# restart before the executor continues ([INTERACTIVE-ONLY]).
[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$RepoRoot,
    [switch]$DryRun,
    [switch]$Arm,
    [switch]$Headless,
    [switch]$RequireFresh
)

$ErrorActionPreference = 'Continue'
$exitCode = 0
$restartRequired = $false

function Exit-NotFresh {
    param([string]$Status, [string]$Message)
    Write-Result $Status $Message
    if ($RequireFresh) { exit 1 }
    exit 0
}

function Write-Result {
    param([string]$Status, [string]$Message)
    $color = switch ($Status) {
        'OK'      { 'Green' }
        'FRESH'   { 'DarkGray' }
        'REBUILT' { 'Cyan' }
        'WARN'    { 'Yellow' }
        'SKIP'    { 'DarkGray' }
        'ARMED-DEFER' { 'Magenta' }
        'ARM'      { 'Red' }
        default   { 'White' }
    }
    Write-Host "[ensure-build-fresh][$Status] $Message" -ForegroundColor $color
}

# --- Resolve repo root ---
if (-not $RepoRoot) {
    $RepoRoot = (git rev-parse --show-toplevel 2>$null)
    if (-not $RepoRoot) {
        Exit-NotFresh 'SKIP' "Not in a git repo and -RepoRoot not given."
    }
}

# --- Resolve MCP server path; skip gracefully if absent (e.g. machine without submod) ---
$McpServerPath = Join-Path $RepoRoot 'mcps/internal/servers/roo-state-manager'
if (-not (Test-Path $McpServerPath)) {
    Exit-NotFresh 'SKIP' "MCP server path not found ($McpServerPath). Machine without submodule — nothing to rebuild."
}

$SrcPath   = Join-Path $McpServerPath 'src'
$BuildPath = Join-Path $McpServerPath 'build'

if (-not (Test-Path $SrcPath)) {
    Exit-NotFresh 'SKIP' "src/ not found at $SrcPath. Nothing to compare."
}

# --- Newest mtime among COMPILED source files ---
# Mirror tsconfig.exclude: skip __tests__, *.test.ts, *.spec.ts, _archive(s).
# A test-only change (e.g. #870 vi.mock) must NOT trigger a runtime rebuild.
$srcNewest = [long]0
$srcNewestFile = ''
$srcFiles = Get-ChildItem -Path $SrcPath -Recurse -File -Filter '*.ts' -ErrorAction SilentlyContinue |
    Where-Object {
        $_.FullName -notmatch '[\\/]__tests__[\\/]' -and
        $_.FullName -notmatch '[\\/]_archive[s]?[\\/]' -and
        $_.Name -notmatch '\.(test|spec)\.ts$'
    }
foreach ($f in $srcFiles) {
    if ($f.LastWriteTime.ToFileTimeUtc() -gt $srcNewest) {
        $srcNewest = $f.LastWriteTime.ToFileTimeUtc()
        $srcNewestFile = $f.FullName
    }
}

if ($srcNewest -eq 0) {
    Exit-NotFresh 'SKIP' "No compiled src/*.ts found under $SrcPath."
}

# --- Newest mtime among compiled build outputs ---
$buildNewest = [long]0
if (Test-Path $BuildPath) {
    $buildFiles = Get-ChildItem -Path $BuildPath -Recurse -File -Filter '*.js' -ErrorAction SilentlyContinue
    foreach ($f in $buildFiles) {
        if ($f.LastWriteTime.ToFileTimeUtc() -gt $buildNewest) {
            $buildNewest = $f.LastWriteTime.ToFileTimeUtc()
        }
    }
}

$srcFileRel = $srcNewestFile.Substring($RepoRoot.Length).TrimStart('\','/')

# Probe the machine-wide RSM hosts before the FRESH return. A build can be fresh on disk while
# the live hosts still serve the previous modules; strict executor pre-flight must preserve that
# restart debt instead of forgetting it on the next cycle.
$indexHosts = @(Get-CimInstance Win32_Process -Filter "Name = 'node.exe'" -ErrorAction SilentlyContinue |
    Where-Object { $_.CommandLine -match 'roo-state-manager[\\/](build[\\/]index\.js)( |"|$)' } |
    Select-Object -Property ProcessId, CreationDate, CommandLine)
$wrapperHosts = @(Get-CimInstance Win32_Process -Filter "Name = 'node.exe'" -ErrorAction SilentlyContinue |
    Where-Object { $_.CommandLine -match 'roo-state-manager[\\/]mcp-wrapper\.cjs' } |
    Select-Object -Property ProcessId, CreationDate, CommandLine)
$liveHosts = @($indexHosts + $wrapperHosts)
$buildIndex = Join-Path $BuildPath 'index.js'
$buildMtimeUtc = if (Test-Path $buildIndex) { (Get-Item $buildIndex).LastWriteTimeUtc } else { $null }
$staleCount = 0
foreach ($h in $indexHosts) {
    if ($h.CreationDate -and $buildMtimeUtc -and $h.CreationDate.ToUniversalTime() -lt $buildMtimeUtc) {
        $staleCount++
    }
}
$hostsDetail = "{0} RSM session(s) alive ($($wrapperHosts.Count) wrapper + $($indexHosts.Count) build/index.js), running from {1}" -f $indexHosts.Count, (Split-Path $McpServerPath -Leaf)
if ($staleCount -gt 0) {
    $hostsDetail += "; {0} predating build/index.js (ARMÉ signature)" -f $staleCount
}

# --- Content key: an MTIME verdict is not evidence of a source change (#2822/#3489 amendment) ---
# A `git checkout`, a branch switch, a stash, or a `git submodule update` that re-checks-out the
# SAME sha rewrites the mtime of every file it writes, leaving the CONTENT untouched. The mtime
# comparison above then reads STALE; `npm run build` (clean + tsc) rewrites `build/index.js`
# unconditionally -- even when tsc re-emits byte-identical output -- and every live RSM host now
# predates that new mtime, so the ARM guard demands a VS Code restart. Not one of those steps
# needs a real source change: the restart cadence tracks GIT OPERATIONS, not fixes. Measured on
# ai-01 (2026-09-11): the newest `src/*.ts` was `src/utils/secret-redaction.ts`, content identical
# to HEAD. The operator reported ~3 restarts/day for "blocking corrections" that did not exist.
#
# `postbuild` already stamps `build/build-info.json` with the submodule sha the build came from.
# That answers the question mtime cannot: was this build produced from exactly this source? When
# it was, the lag is noise and there is nothing to rebuild -- and nothing to restart.
#
# Fail-CLOSED by construction: every unknown (no stamp, unreadable stamp, absent sha, `dirty`
# stamp, sha mismatch, uncommitted src/, unpopulated submodule, any git failure) returns $false
# and falls through to the existing mtime behaviour. The guard can only ever SUPPRESS a rebuild
# it has positively proven redundant.
function Test-BuildMatchesSource {
    param([string]$BuildPath, [string]$McpServerPath, [string]$RepoRoot)

    $infoPath = Join-Path $BuildPath 'build-info.json'
    if (-not (Test-Path $infoPath)) { return $false }

    $info = $null
    try { $info = Get-Content -Raw -LiteralPath $infoPath -ErrorAction Stop | ConvertFrom-Json } catch { return $false }
    if (-not $info.sha) { return $false }
    if ($info.dirty) { return $false }

    # `git -C` on an UNPOPULATED submodule answers for the PARENT repo instead of failing. Assert
    # the MECHANISM (did -C walk up?), not one of its consequences: a sha comparison made against
    # the parent could only mismatch here, but relying on that accident would leave the guard
    # correct for the wrong reason.
    $subTop = (& git -C $McpServerPath rev-parse --show-toplevel 2>$null)
    $rcSub = $LASTEXITCODE
    $parentTop = (& git -C $RepoRoot rev-parse --show-toplevel 2>$null)
    $rcParent = $LASTEXITCODE
    if ($rcSub -ne 0 -or $rcParent -ne 0 -or -not $subTop -or -not $parentTop) { return $false }
    if ($subTop.Trim() -eq $parentTop.Trim()) { return $false }

    $head = (& git -C $McpServerPath rev-parse HEAD 2>$null)
    if ($LASTEXITCODE -ne 0 -or -not $head) { return $false }
    if ($head.Trim() -ne $info.sha.Trim()) { return $false }

    # A matching HEAD still leaves uncommitted edits. Ask git for CONTENT: `diff --quiet`
    # refreshes the index and compares blobs, so a file whose mtime ALONE was rewritten is silent
    # here -- precisely the case this guard exists to catch. The pathspec resolves against the -C
    # directory, scoping it to this server's src/ inside the submodule.
    & git -C $McpServerPath diff --quiet -- src 2>$null
    if ($LASTEXITCODE -ne 0) { return $false }

    # `diff` compares the index against the worktree, so it only ever reports files git already
    # TRACKS. A new, never-added `src/*.ts` is silent here -- while tsconfig includes
    # `src/**/*.ts`, so tsc WOULD emit a module for it and the build really is behind. The stamp
    # cannot rescue this either: `dirty` is computed WHEN THE BUILD RAN, so a file created
    # afterwards postdates it by construction. Measured on ai-01 (2026-09-11): with an untracked
    # `src/__probe.ts` present, `diff --quiet -- src` still exits 0. Raised by web1 on #3589.
    $untracked = (& git -C $McpServerPath ls-files --others --exclude-standard -- src 2>$null)
    if ($LASTEXITCODE -ne 0) { return $false }
    if ($untracked) { return $false }

    return $true
}

# --- Decision ---
if ($buildNewest -gt 0 -and $buildNewest -ge $srcNewest) {
    Write-Result 'FRESH' "build/ is up to date (newest build .js >= newest src .ts: $srcFileRel)."
    if ($RequireFresh -and $staleCount -gt 0) {
        Write-Result 'ARM' "$hostsDetail. Build is fresh on disk, but these live hosts still serve the previous build. Restart VS Code before continuing the executor cycle."
        exit 10
    }
    exit 0
}

# mtime says STALE. Before paying for a rebuild -- and for the VS Code restart that a rebuild
# OWES (ARM guard below) -- ask whether the source actually moved. Guarded on `$buildNewest -gt 0`:
# an absent build/ carries no stamp to trust and must always be produced.
if ($buildNewest -gt 0 -and (Test-BuildMatchesSource -BuildPath $BuildPath -McpServerPath $McpServerPath -RepoRoot $RepoRoot)) {
    $lagSec = [math]::Round(($srcNewest - $buildNewest) / 10000000)
    Write-Result 'FRESH' "build/ was produced from the checked-out source (build-info.json sha = submodule HEAD, src/ clean). Newest src .ts ($srcFileRel) leads by ${lagSec}s in MTIME ONLY -- a git checkout rewrites mtimes without changing content. No rebuild, so no restart is owed."
    # The ARM debt is NOT suppressed with the rebuild: a host predating build/index.js loaded an
    # EARLIER build and genuinely serves older modules. What disappears is the spurious arming
    # that a redundant rebuild manufactured for every live host at once.
    if ($RequireFresh -and $staleCount -gt 0) {
        Write-Result 'ARM' "$hostsDetail. Build is fresh on disk, but these live hosts still serve the previous build. Restart VS Code before continuing the executor cycle."
        exit 10
    }
    exit 0
}

# Build is stale (or absent) → rebuild needed
if (-not $buildNewest) {
    Write-Result 'WARN' "build/ absent or empty — rebuild required (newest src .ts: $srcFileRel)."
} else {
    $lagSec = [math]::Round(($srcNewest - $buildNewest) / 10000000)
    Write-Result 'WARN' "build/ STALE — newest src .ts ($srcFileRel) is ${lagSec}s newer than newest build .js."
}

# --- ARM GUARD (#3489): refuse to rebuild under live RSM hosts (ESM mixed-millage) ---
# Rebuilding `build/` while a live roo-state-manager host process is running replaces the
# ESM modules that host already imported -> mixed module graph -> the next dynamic import
# crashes with `assertSharedStoreAccessible`, making `roosync_messages` (inbox) unreadable
# until VS Code restart. The crash is armed by ANY live host, fresh or stale (proven
# 2026-09-06: rebuilding under fresh post-build hosts still armed them).
#
# Each VS Code RSM session spawns TWO distinct node processes: `mcp-wrapper.cjs` (parent)
# and `build/index.js` (child). The roles are 1:1 per session, so the message must count
# each role once — not the process count — to give the human operator the number of sessions
# at stake (ai-01 review note, 2026-09-06 23:28Z). The ARMÉ signature is computed against
# `build/index.js` processes specifically: they are the ones that loaded the ESM modules
# the next dynamic import would mismatch.
if ($liveHosts.Count -gt 0) {
    if ($Headless -and -not $Arm) {
        Exit-NotFresh 'ARMED-DEFER' "$hostsDetail. Headless caller (worker/cron/pre-flight) cannot restart VS Code, so rebuilding here would leave the machine ARMED indefinitely (#3489) and inbox broken. Deferred — an interactive session must rebuild and restart. Pass -Arm to override under an explicit human mandate."
    }

    # The ARM claim must match what the run actually DOES. Under -DryRun no rebuild happens
    # (the gate below exits before `npm run build`), so the categorical form announced a debt
    # the run had not incurred: `-DryRun` printed "THE RESTART IS OWED" and then "would run
    # npm run build", with build/index.js mtime unchanged. Reported by po-2024 reviewing #3519
    # and reproduced on main (2026-09-08). The host detail is still worth printing in a dry-run
    # -- it is how an operator learns how many sessions a real run would arm -- so the branch
    # keeps the information and changes only the tense.
    #
    # The predicate is NOT "-DryRun": it is "will this run actually rebuild". `-WhatIf` reaches
    # the same place by another door -- ShouldProcess declines below and no build happens -- and
    # measured identically on main (2026-09-08): categorical ARM, then "ShouldProcess declined",
    # build/index.js mtime unchanged. `$WhatIfPreference` is $true in scope under -WhatIf, so
    # both dry paths share one condition and neither can drift away from it alone.
    $noRebuildThisRun = $DryRun -or $WhatIfPreference
    if ($noRebuildThisRun) {
        $dryLabel = if ($DryRun) { '-DryRun' } else { '-WhatIf' }
        Write-Result 'ARM' "$hostsDetail. ${dryLabel}: NOTHING was rebuilt and NOTHING is armed. A REAL run would ARM the ESM mixed-millage crash (#3489) on those sessions -- the new build is served only after a VS Code restart, and inbox stays broken until then -- and would OWE that restart ([INTERACTIVE-ONLY])."
    } else {
        Write-Result 'ARM' "$hostsDetail. Rebuilding now ARMS the ESM mixed-millage crash (#3489) on those sessions: the new build is served only after a VS Code restart, and inbox stays broken until then. THE RESTART IS OWED ([INTERACTIVE-ONLY])."
        $restartRequired = $true
    }
}

if ($DryRun) {
    Exit-NotFresh 'SKIP' "-DryRun set: would run 'npm run build' in $McpServerPath."
}

if (-not $PSCmdlet.ShouldProcess($McpServerPath, "Run 'npm run build' (clean + tsc)")) {
    Exit-NotFresh 'SKIP' "ShouldProcess declined — not rebuilding."
}

# --- Rebuild (mirror worker Sync-McpSubmoduleBuild: clean:build + tsc, non-fatal on failure) ---
Push-Location $McpServerPath
try {
    Write-Result 'OK' "Running 'npm run build' (clean rebuild)..."
    # Use `npm.cmd` explicitly: under pwsh, bare `npm` resolves to the npm.ps1
    # wrapper, and invoking it via the call operator (`& npm ...`) corrupts arg
    # passing (npm receives a mangled command → "Unknown command: pm", exit 1).
    # The non-fatal design then silently keeps the stale build — exactly the
    # STALE-TRAP this helper exists to prevent. npm.cmd bypasses the wrapper.
    $buildOutput = & npm.cmd run build 2>&1
    $buildExit = $LASTEXITCODE
    if ($buildExit -eq 0) {
        Write-Result 'REBUILT' "MCP build regenerated successfully. Restart VS Code to activate the new build ([INTERACTIVE-ONLY])."
        if ($RequireFresh -and $restartRequired) { $exitCode = 10 }
    } else {
        $tail = ($buildOutput | Select-Object -Last 5 | Out-String).Trim()
        Write-Result 'WARN' "Build FAILED (exit $buildExit) — proceeding on existing build. Tail:`n$tail"
        $exitCode = if ($RequireFresh) { 1 } else { 0 }
    }
} catch {
    Write-Result 'WARN' "Build invocation threw (non-fatal): $_"
    $exitCode = if ($RequireFresh) { 1 } else { 0 }
} finally {
    Pop-Location
}

exit $exitCode
