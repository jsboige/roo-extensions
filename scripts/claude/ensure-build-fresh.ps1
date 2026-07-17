# ensure-build-fresh.ps1 — Rebuild the MCP submodule build/ if stale (#2822 STALE-TRAP)
# Usage: pwsh -File scripts/claude/ensure-build-fresh.ps1 [-RepoRoot <path>] [-DryRun]
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
# NOTE: This ensures the ON-DISK build is current. A separate, distinct failure mode — the
# MCP host process serving a stale in-memory build even though build/ is fresh on disk —
# still requires a VS Code restart ([INTERACTIVE-ONLY], out of scope here).
[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$RepoRoot,
    [switch]$DryRun
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
    $buildOutput = & npm run build 2>&1
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
