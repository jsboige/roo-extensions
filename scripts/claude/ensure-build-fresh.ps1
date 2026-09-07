# ensure-build-fresh.ps1 — Rebuild the MCP submodule build/ if stale (#2822 STALE-TRAP)
# Usage: powershell -File scripts/claude/ensure-build-fresh.ps1 [-RepoRoot <path>] [-DryRun] [-Arm] [-Headless]
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
# Idempotent: a no-op when the build is already fresh. Non-fatal: a build failure logs WARN
# and exits 0 so it never blocks the executor session.
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
# NOTE: This ensures the ON-DISK build is current. A separate, distinct failure mode — the
# MCP host process serving a stale in-memory build even though build/ is fresh on disk —
# still requires a VS Code restart ([INTERACTIVE-ONLY], out of scope here).
[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$RepoRoot,
    [switch]$DryRun,
    [switch]$Arm,
    [switch]$Headless
)

$ErrorActionPreference = 'Continue'
$exitCode = 0

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
        Write-Result 'SKIP' "Not in a git repo and -RepoRoot not given."
        exit 0
    }
}

# --- Resolve MCP server path; skip gracefully if absent (e.g. machine without submod) ---
$McpServerPath = Join-Path $RepoRoot 'mcps/internal/servers/roo-state-manager'
if (-not (Test-Path $McpServerPath)) {
    Write-Result 'SKIP' "MCP server path not found ($McpServerPath). Machine without submodule — nothing to rebuild."
    exit 0
}

$SrcPath   = Join-Path $McpServerPath 'src'
$BuildPath = Join-Path $McpServerPath 'build'

if (-not (Test-Path $SrcPath)) {
    Write-Result 'SKIP' "src/ not found at $SrcPath. Nothing to compare."
    exit 0
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
    Write-Result 'SKIP' "No compiled src/*.ts found under $SrcPath."
    exit 0
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

# --- Decision ---
if ($buildNewest -gt 0 -and $buildNewest -ge $srcNewest) {
    Write-Result 'FRESH' "build/ is up to date (newest build .js >= newest src .ts: $srcFileRel)."
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
$indexHosts = @(Get-CimInstance Win32_Process -Filter "Name = 'node.exe'" -ErrorAction SilentlyContinue |
    Where-Object { $_.CommandLine -match 'roo-state-manager[\\/](build[\\/]index\.js)( |"|$)' } |
    Select-Object -Property ProcessId, CreationDate, CommandLine)
$wrapperHosts = @(Get-CimInstance Win32_Process -Filter "Name = 'node.exe'" -ErrorAction SilentlyContinue |
    Where-Object { $_.CommandLine -match 'roo-state-manager[\\/]mcp-wrapper\.cjs' } |
    Select-Object -Property ProcessId, CreationDate, CommandLine)
$liveHosts = @($indexHosts + $wrapperHosts)

if ($liveHosts.Count -gt 0) {
    # ARMÉ signature: index.js processes whose creation predates the current build/index.js
    # mtime. Reported on BOTH branches — it names what the operator has to restart, and it is
    # how a machine left armed is recognised after the fact.
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

    if ($Headless -and -not $Arm) {
        Write-Result 'ARMED-DEFER' "$hostsDetail. Headless caller (worker/cron/pre-flight) cannot restart VS Code, so rebuilding here would leave the machine ARMED indefinitely (#3489) and inbox broken. Deferred — an interactive session must rebuild and restart. Pass -Arm to override under an explicit human mandate."
        exit 0
    }

    Write-Result 'ARM' "$hostsDetail. Rebuilding now ARMS the ESM mixed-millage crash (#3489) on those sessions: the new build is served only after a VS Code restart, and inbox stays broken until then. THE RESTART IS OWED ([INTERACTIVE-ONLY])."
}

if ($DryRun) {
    Write-Result 'SKIP' "-DryRun set: would run 'npm run build' in $McpServerPath."
    exit 0
}

if (-not $PSCmdlet.ShouldProcess($McpServerPath, "Run 'npm run build' (clean + tsc)")) {
    Write-Result 'SKIP' "ShouldProcess declined — not rebuilding."
    exit 0
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
    } else {
        $tail = ($buildOutput | Select-Object -Last 5 | Out-String).Trim()
        Write-Result 'WARN' "Build FAILED (exit $buildExit) — proceeding on existing build. Tail:`n$tail"
        $exitCode = 0   # non-fatal: do not block the executor session
    }
} catch {
    Write-Result 'WARN' "Build invocation threw (non-fatal): $_"
    $exitCode = 0
} finally {
    Pop-Location
}

exit $exitCode
