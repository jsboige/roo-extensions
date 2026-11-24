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
# source currently checked out. Legacy callers remain non-fatal on
# skips/build failures; `-RequireFresh` makes those conditions block an executor pre-flight.
#
# WORKSPACE STEPS (#4886, PR #4893): since ms#1882 `mcps/internal` is an npm workspace and the
# RSM build consumes the compiled dist/ of its sibling package `@vibesync/core`. Before any
# rebuild this script ENSURES two steps instead of advising them:
#   1. the workspace install is current with `mcps/internal/package-lock.json` -- a CONTENT
#      question (npm's own on-disk stamp vs the lockfile), never an mtime one. When it is not,
#      `npm ci` is required, and `npm ci` deletes node_modules first: it is REFUSED (exit 1,
#      whatever -RequireFresh) while any RSM host process is alive, with the remedy in the line.
#   2. `@vibesync/core` is rebuilt. (`npm run build` in the server also rebuilds it through its
#      `prebuild`; this step runs first and names the failure on its own line.)
# A failed `npm ci` or core build takes the same exit path as a failed server build, and the
# server build never runs after either. The workspace decision is taken BEFORE the ARM guard
# and the dry-run exits: a refused run rebuilds nothing and owes no restart, and -DryRun /
# -WhatIf name the steps a real run would take.
#
# WHICH PATH RUNS, AND WHY IT DECIDES EVERYTHING BELOW (#3713)
# ------------------------------------------------------------------------------------------
# Read this before the ARM GUARD section: on any checkout that has a `build-current` marker --
# which is every post-#3713 checkout, i.e. the normal case today -- the ARM GUARD prose below
# DOES NOT APPLY, and a rebuild OWES NO RESTART.
#
#   vintage path (#3713, default today)  -> `npm run build` republishes a CONTENT-ADDRESSED
#                                           vintage next to the frozen `build/` shim and flips
#                                           the `build-current` marker. Live v5 wrappers
#                                           hot-swap on their own; v4 hosts take it at their
#                                           next session spawn. Nothing is armed, nothing is
#                                           owed, however many hosts are alive.
#   legacy mtime path (marker absent)    -> pre-#3713 checkout only. THAT is what the ARM
#                                           GUARD below describes.
#
# Stated explicitly because the cost is asymmetric and falls on the operator. An agent that
# reads the ARM GUARD prose without reaching the vintage code concludes "a rebuild owes a
# restart", and then either refuses a rebuild that was free, or announces a restart the user
# does not owe -- on a machine where restart frequency is precisely the standing complaint.
# The runtime already says the right thing (`SKIP ... vintage rebuild arms nothing ... no
# restart owed (#3713)`); only this header lagged.
#
# ARM GUARD (#3489, revised by the #3489 FRICTION arbitration) -- LEGACY MTIME PATH ONLY,
# superseded by the vintage path above on any checkout carrying a `build-current` marker.
# Rebuilding `build/` while a
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
# restart before the executor continues ([INTERACTIVE-ONLY]). Legacy path only -- under the
# vintage pipeline the marker flip is what makes a build current, and no restart is owed.
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
        'ERROR'   { 'Red' }
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
# #4886: `@vibesync/core` is a workspace package with its own compiled dist/. The RSM
# build consumes it, so a core source edit that is newer than its dist/ makes the
# published vintage stale even when no RSM src/ file changed.
$CorePath     = Join-Path $RepoRoot 'mcps/internal/packages/vibesync-core'
$CoreSrcPath  = Join-Path $CorePath 'src'
$CoreDistIndex = Join-Path $CorePath 'dist/index.js'

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

# #4886: the shared package's compiled sources are part of "the source".
if (Test-Path $CoreSrcPath) {
    $coreSrcFiles = Get-ChildItem -Path $CoreSrcPath -Recurse -File -Filter '*.ts' -ErrorAction SilentlyContinue |
        Where-Object {
            $_.FullName -notmatch '[\\/]__tests__[\\/]' -and
            $_.Name -notmatch '\.(test|spec)\.ts$'
        }
    foreach ($f in $coreSrcFiles) {
        if ($f.LastWriteTime.ToFileTimeUtc() -gt $srcNewest) {
            $srcNewest = $f.LastWriteTime.ToFileTimeUtc()
            $srcNewestFile = $f.FullName
        }
    }
    if (-not (Test-Path $CoreDistIndex)) {
        # No dist/ means the workspace package was never built: force the rebuild path.
        $srcNewest = [long]::MaxValue
        $srcNewestFile = $CoreDistIndex
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
function Test-ProcessExited {
    # Ghost corroboration (po-2024, 2026-09-12): Win32_Process keeps listing a process after
    # termination when a third party holds its object handle (observed: the unreaped child of a
    # killed mcp-wrapper -- CIM listed it with a 2.3 GB working set, taskkill said "no running
    # instance", the .NET view said HasExited=True). Counted as a live host, such a ghost wedges
    # this guard at exit 10 indefinitely after a legitimate host-kill pass. Only a POSITIVE
    # verdict excludes: a PID the .NET enumeration cannot see is absent from the OS process
    # list (the same source taskkill consults); HasExited=$true means no code is executing.
    # Any failure to prove exit (property access denied, enumeration error) keeps the host
    # counted -- the corroboration can only ever remove a process that cannot run, never a
    # live server.
    param([int]$ProbePid)
    try {
        $p = Get-Process -Id $ProbePid -ErrorAction SilentlyContinue
        if ($null -eq $p) { return $true }
        return [bool]$p.HasExited
    } catch {
        return $false
    }
}
$indexHosts = @(Get-CimInstance Win32_Process -Filter "Name = 'node.exe'" -ErrorAction SilentlyContinue |
    Where-Object { $_.CommandLine -match 'roo-state-manager[\\/](build[\\/]index\.js)( |"|$)' } |
    Select-Object -Property ProcessId, CreationDate, CommandLine)
$wrapperHosts = @(Get-CimInstance Win32_Process -Filter "Name = 'node.exe'" -ErrorAction SilentlyContinue |
    Where-Object { $_.CommandLine -match 'roo-state-manager[\\/]mcp-wrapper\.cjs' } |
    Select-Object -Property ProcessId, CreationDate, CommandLine)
# Versioned children (#3713): build-<hash>/index.js, the shape every post-#3713 seat runs.
# Consulted by the `npm ci` refusal ONLY (#4886): they are neither part of the ARM guard's
# session count nor of the ARMÉ signature, which stay legacy-only below.
$vintageHosts = @(Get-CimInstance Win32_Process -Filter "Name = 'node.exe'" -ErrorAction SilentlyContinue |
    Where-Object { $_.CommandLine -match 'roo-state-manager[\\/]build-[0-9a-f]{16}[\\/]index\.js( |"|$)' } |
    Select-Object -Property ProcessId, CreationDate, CommandLine)
# Drop CIM-listed processes that the .NET view positively reports exited (see Test-ProcessExited).
$indexHosts   = @($indexHosts   | Where-Object { -not (Test-ProcessExited $_.ProcessId) })
$vintageHosts = @($vintageHosts | Where-Object { -not (Test-ProcessExited $_.ProcessId) })
$wrapperHosts = @($wrapperHosts | Where-Object { -not (Test-ProcessExited $_.ProcessId) })
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
# Kill remedy (host-kill validated po-2024 2026-09-12; role discrimination corrected by po-2026
# 2026-09-13): kill ONLY the build/index.js children predating the build. $staleCount counts the
# children alone, and the mcp-wrapper.cjs parent exits by itself when its child exits
# (server.on('exit') -> process.exit in mcp-wrapper.cjs) -- so killing a child retires the pair,
# while killing a WRAPPER first orphans the child: it stays counted here and can linger as an
# unreaped CIM ghost (the case Test-ProcessExited above tolerates). The stale set is machine-wide,
# so a caller whose OWN session host is in it cannot cure itself by killing -- that one clears
# only via a VS Code restart (Claude Code does not respawn a killed MCP host; restartOnCrash is
# absent from the client config).
$killHint = "Kill remedy: kill ONLY the build/index.js node processes predating it -- NEVER the mcp-wrapper.cjs parents (each parent exits when its child exits; a killed wrapper orphans the child). If this session's own host is in the stale set, only a VS Code restart clears it."

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
    # directory, scoping it to this server's src/ and the workspace package's src/ inside the
    # submodule (#4886).
    & git -C $McpServerPath diff --quiet -- src ../../packages/vibesync-core/src 2>$null
    if ($LASTEXITCODE -ne 0) { return $false }

    # `diff` compares the index against the worktree, so it only ever reports files git already
    # TRACKS. A new, never-added `src/*.ts` is silent here -- while tsconfig includes
    # `src/**/*.ts`, so tsc WOULD emit a module for it and the build really is behind. The stamp
    # cannot rescue this either: `dirty` is computed WHEN THE BUILD RAN, so a file created
    # afterwards postdates it by construction. Measured on ai-01 (2026-09-11): with an untracked
    # `src/__probe.ts` present, `diff --quiet -- src` still exits 0. Raised by web1 on #3589.
    # #4886: the workspace package's src/ is part of the same build input.
    $untracked = (& git -C $McpServerPath ls-files --others --exclude-standard -- src ../../packages/vibesync-core/src 2>$null)
    if ($LASTEXITCODE -ne 0) { return $false }
    if ($untracked) { return $false }

    # The content key proves the source, not the compilation of the workspace package.
    $coreSrcPath = Join-Path $RepoRoot 'mcps/internal/packages/vibesync-core/src'
    $coreDistIndex = Join-Path $RepoRoot 'mcps/internal/packages/vibesync-core/dist/index.js'
    if (Test-Path $coreSrcPath) {
        if (-not (Test-Path $coreDistIndex)) { return $false }
        $coreSrcNewest = (Get-ChildItem -Path $coreSrcPath -Recurse -File -Filter '*.ts' -ErrorAction SilentlyContinue |
            Measure-Object -Property LastWriteTimeUtc -Maximum).Maximum
        if ($coreSrcNewest -and (Get-Item $coreDistIndex).LastWriteTimeUtc -lt $coreSrcNewest) { return $false }
    }

    return $true
}

# Fail-closed exit for the workspace steps this script ENSURES (#4886): a failed workspace
# install or a failed core build must take the same exit path as a failed server build.
# The default remains the legacy 0 for the non-strict callers
# (start-claude-worker.ps1 / start-meta-audit.ps1 log the verdict and carry on),
# exactly like the existing server-build failure path; -RequireFresh fails.
# `-Refused` fails in BOTH modes: a refused `npm ci` leaves nothing to carry on with, and a
# 0 there would read as "install not needed" to anyone scripting this helper (#4893 review).
# Every call exits BEFORE the server build, and the line says so. The workspace plan is
# computed above the ARM guard, so a refusal gets its own non-categorical ARM line -- but a
# reader who only sees this one still cannot inherit a claim of an earlier line.
function Exit-WorkspaceStepFailed {
    param([string]$Message, [switch]$Refused)
    Write-Result 'ERROR' "$Message The server build did not run: this run published no vintage and rewrote no build/."
    if ($Refused -or $RequireFresh) { exit 1 }
    exit 0
}

# Engine-portable JSON -> IDictionary, both Windows PowerShell 5.1 and PowerShell 7+ (#2368):
# the two available mechanisms are MUTUALLY EXCLUSIVE (-AsHashtable does not exist on 5.1;
# JavaScriptSerializer lives in System.Web.Extensions, .NET Framework only). Same name and
# body as the helper of spawn-claude.ps1 / dashboard-listener.ps1, which is also what the
# CI guard pwsh-engine-portability requires of any .ps1 that pipes into -AsHashtable.
# Caller contract: the two engines return different .NET types -- test membership with
# -is [System.Collections.IDictionary], never the concrete [hashtable].
# Behaviour measured on BOTH engines through this body (2026-11-24, 5.1.26100.9818 and
# 7.6.10): IDictionary true; the empty root key "" is carried; two keys differing only
# by case stay two keys; a missing key reads as null; malformed JSON throws.
function ConvertFrom-JsonToDictionary {
    param([Parameter(Mandatory = $true)][string]$Json)
    if ($PSVersionTable.PSVersion.Major -ge 7) {
        return $Json | ConvertFrom-Json -AsHashtable
    }
    Add-Type -AssemblyName System.Web.Extensions -ErrorAction Stop
    $serializer = New-Object System.Web.Script.Serialization.JavaScriptSerializer
    $serializer.MaxJsonLength = [int]::MaxValue
    return $serializer.DeserializeObject($Json)
}

# Is the installed tree current with the workspace lockfile? Content question, not an
# mtime one (#4886 review: a checkout that rewrites an identical package-lock.json
# must not re-run `npm ci`).
#
# Measured npm behaviour (npm 11.5.1, isolated `npm ci`, 2026-11-24): the root
# hidden stamp held 1647 entries versus 1648 in the source lockfile. The ONLY
# source-only key was the root entry ""; there were zero stamp-only keys and zero
# version mismatches. The exact content invariant is therefore:
#     ignoring the source's root entry, lockfile and stamp have the same package
#     keys, every shared package has the same version, and tsc is actually on disk.
# Mtime never enters this decision: the same measurement rewrote 18,223 files in
# the server-local dependency tree with unchanged hashes.
#
# Measured on a real installed workspace (2026-11-24, 823-KB lockfile): $true under
# powershell.exe 5.1.26100.9818 AND under pwsh 7.6.10, about 300 ms and about 200 ms. That matters as much as the
# false cases -- a correct seat read as stale would be refused below on every pre-flight.
function Test-WorkspaceInstallCurrent {
    param([string]$LockPath, [string]$ModulesPath, [string]$ServerPath)
    if (-not (Test-Path -LiteralPath $ModulesPath)) { return $false }
    $stampPath = Join-Path $ModulesPath '.package-lock.json'
    if (-not (Test-Path -LiteralPath $stampPath)) { return $false }
    # npm's lockfile names its root entry "" -- a key no PSCustomObject can carry:
    # Windows PowerShell 5.1 ConvertFrom-Json REJECTS the whole file (invalid argument
    # name), so a plain conversion would read every seat as stale. The portable reader
    # returns an IDictionary on both engines, and that type can hold the key.
    function Read-PackageVersions {
        param([string]$Path)
        $root = ConvertFrom-JsonToDictionary -Json ([System.IO.File]::ReadAllText($Path))
        if (-not ($root -is [System.Collections.IDictionary])) { return $null }
        $packages = $root['packages']
        if (-not ($packages -is [System.Collections.IDictionary])) { return $null }
        # Ordinal, like both readers and like npm's own tree: two paths that differ only by
        # case are two packages. A case-insensitive table would merge them, and a missing
        # one would then read as "current" (measured 2026-11-24: each engine's reader keeps
        # `node_modules/a` and `node_modules/A` as two keys).
        $versions = [System.Collections.Generic.Dictionary[string,string]]::new([System.StringComparer]::Ordinal)
        foreach ($name in $packages.Keys) {
            if ($name -eq '') { continue }
            $entry = $packages[$name]
            if (-not ($entry -is [System.Collections.IDictionary])) { return $null }
            $versions[$name] = [string]$entry['version']
        }
        return $versions
    }
    $want = $null
    $have = $null
    try { $want = Read-PackageVersions $LockPath } catch { return $false }
    try { $have = Read-PackageVersions $stampPath } catch { return $false }
    if ($null -eq $want -or $null -eq $have) { return $false }
    # 1. every installed entry must still be the version the lockfile wants.
    foreach ($n in $have.Keys) {
        if (-not $want.ContainsKey($n)) { return $false }
        if ($want[$n] -ne $have[$n]) { return $false }
    }
    # 2. the reverse direction: same package count plus the key/version loop above
    #    proves exact set equality, so an added or removed package cannot hide.
    if ($want.Count -ne $have.Count) { return $false }
    # 3. the toolchain the rebuild consumes must exist, whatever the stamps say.
    if (-not (Test-Path -LiteralPath (Join-Path $ServerPath 'node_modules/typescript/bin/tsc')) -and
        -not (Test-Path -LiteralPath (Join-Path $ModulesPath 'typescript/bin/tsc'))) {
        return $false
    }
    return $true
}

# Can the stale workspace install be reconciled UNDER live RSM hosts? (#4918)
# `npm ci` deletes both node_modules trees, so it is refused while hosts are alive (below).
# `npm install` does something else: it brings the tree in line with the lockfile -- it ADDS
# what the lockfile has and the disk lacks, REMOVES what the disk has and the lockfile
# lacks, and REPLACES what differs in version, resolved or integrity. It is therefore safe
# under live hosts exactly when the two destructive directions are empty.
#
# npm keeps the record of the last install: the hidden stamp
# node_modules/.package-lock.json. A root stamp does not spare the disk. npm accepts it
# only after walking every package directory -- nothing may be newer than the stamp, and
# nothing it lists may be missing unless the stamp marks the entry ideallyInert -- and
# otherwise it reads the package.json files it finds (arborist assertNoNewer and
# loadActual, npm 11.5.1). So this reads the disk every time, and takes from the stamps
# only what they record: what was installed, and what the install left out.
#
# This asks less than "is every tree unchanged": the first deployment of the workspace
# ADDS the whole root tree, and that is the case it exists for. It asks three things:
#   1. nothing a stamp records as installed is missing from the lockfile or differs from
#      it -- no REMOVE and no REPLACE, whatever the tree;
#   2. everything the lockfile adds lands in the ROOT node_modules tree. An addition
#      anywhere else is refused. Measured on the built server (2026-11-24, vintage
#      build-6755d61ff811b4bb): 21 bare specifiers resolve into
#      servers/roo-state-manager/node_modules and 6 into the vintage's own copy of
#      @vibesync/core, the rest are Node builtins -- nothing resolves at the root;
#   3. the package directories on disk are exactly what the stamps record, in every
#      workspace tree: a directory no stamp knows would be REMOVED, a recorded one that
#      is gone would be ADDED back, and one whose package.json says another version would
#      be REPLACED. One gap is tolerated, the one npm tolerates itself: a package the
#      stamp marks ideallyInert, left out by the last install on this platform (119 of
#      the 1017 server entries on po-204, measured 2026-11-24, exactly the 119 without a
#      directory). A link is accepted only where a stamp records it as a link to the same
#      target -- npm makes exactly two, the workspace links of the root tree -- and is
#      never followed.
# A later lockfile that removes or changes an installed package keeps the refusal below:
# this opens the first deployment, not every deployment.
# The server tree must carry its stamp: without a record of the tree the live hosts
# resolve into, nothing can be vouched for. Fail-closed -- a missing or unreadable lockfile
# or stamp, a link, anything not evaluated answers $false, and $Reason names the rule.
#
# Measured on the first-deployment shape (po-204, 2026-11-24, node 24.6.0, npm 11.5.1):
# the seat at gitlink 30348860 (server tree installed by `npm ci`, 898 packages, root
# tree without packages) and the lockfile of 9e293b0a. `npm install` at the root exited 0
# in 20 s, added 747 packages, and under the server tree removed 0, modified 0 and added
# 0 files out of 18,453 (sha256 per file). This check answered $true on that seat and on
# the reconciled copy (1.5-8.1 s under pwsh 7.6, 2.5-4.8 s under Windows PowerShell 5.1
# across runs -- the spread tracks file-cache warmth, not the tree size: the larger
# reconciled copy measured faster once warm), and $false on each of three lockfiles
# derived from it: one that changes, one that drops and one that adds a package under the
# server tree (0.6-0.8 s each -- the refusal comes before the disk walk).
function Test-WorkspaceInstallReconcileSafe {
    param(
        [string]$LockPath,
        [string]$WorkspaceRoot,
        [string]$WorkspaceModulesPath,
        [string]$ServerPath,
        [ref]$Reason
    )
    # The reason first, the verdict last: the reader of one line learns why this closed.
    function Deny-Reconcile {
        param([string]$Why)
        $Reason.Value = $Why
        return $false
    }
    function Read-Packages {
        param([string]$Path)
        if (-not ([System.IO.File]::Exists($Path))) { return $null }
        try {
            $root = ConvertFrom-JsonToDictionary -Json ([System.IO.File]::ReadAllText($Path))
            if (-not ($root -is [System.Collections.IDictionary])) { return $null }
            $packages = $root['packages']
            if (-not ($packages -is [System.Collections.IDictionary])) { return $null }
            return ,$packages
        } catch { return $null }
    }
    # version, resolved, integrity, link: the fields npm's own diff reads to tell CHANGE.
    function Get-PackageIdentity {
        param($Entry)
        if (-not ($Entry -is [System.Collections.IDictionary])) { return $null }
        return '{0}|{1}|{2}|{3}' -f [string]$Entry['version'], [string]$Entry['resolved'], [string]$Entry['integrity'], [string][int][bool]$Entry['link']
    }
    function Read-ManifestVersion {
        param([string]$Path)
        if (-not ([System.IO.File]::Exists($Path))) { return $null }
        try {
            $manifest = ConvertFrom-JsonToDictionary -Json ([System.IO.File]::ReadAllText($Path))
            if ($manifest -is [System.Collections.IDictionary]) { return [string]$manifest['version'] }
        } catch { }
        return $null
    }
    # Where a link points, on both engines: Get-Item reports the stored target of a
    # junction (absolute) and of a symbolic link (as written).
    function Get-LinkTarget {
        param([string]$Path)
        try {
            $targets = @((Get-Item -LiteralPath $Path -Force -ErrorAction Stop).Target)
            if ($targets.Count -gt 0 -and -not [string]::IsNullOrEmpty([string]$targets[0])) { return [string]$targets[0] }
        } catch { }
        return $null
    }
    function Test-IsLink {
        param([string]$Path)
        return (([System.IO.File]::GetAttributes($Path)) -band [System.IO.FileAttributes]::ReparsePoint) -ne 0
    }
    $Reason.Value = ''
    try {
        $wsFull  = [System.IO.Path]::GetFullPath($WorkspaceRoot)
        $srvFull = [System.IO.Path]::GetFullPath($ServerPath)
        if (-not $srvFull.StartsWith($wsFull + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase)) {
            return (Deny-Reconcile "$ServerPath is not a directory below $WorkspaceRoot, so its packages cannot be located in the lockfile.")
        }
        # Lockfile keys are workspace-relative and use '/'. The server stamp was written
        # for the server alone, so its keys are server-relative: anchor each one under
        # the server's own folder in the workspace.
        $serverRel   = $srvFull.Substring($wsFull.Length + 1).Replace('\', '/')
        $serverStamp = [System.IO.Path]::Combine($ServerPath, 'node_modules', '.package-lock.json')
        if (-not ([System.IO.File]::Exists($serverStamp))) {
            return (Deny-Reconcile "npm left no install record at $serverStamp, so the tree the live RSM hosts resolve into cannot be compared with the lockfile.")
        }
        $lockPackages = Read-Packages $LockPath
        if ($null -eq $lockPackages) { return (Deny-Reconcile 'the lockfile is absent, unreadable or holds no packages object.') }
        $serverPackages = Read-Packages $serverStamp
        if ($null -eq $serverPackages) { return (Deny-Reconcile "the install record at $serverStamp is unreadable or holds no packages object.") }
        $rootStamp    = [System.IO.Path]::Combine($WorkspaceModulesPath, '.package-lock.json')
        $rootPackages = $null
        if ([System.IO.File]::Exists($rootStamp)) {
            $rootPackages = Read-Packages $rootStamp
            if ($null -eq $rootPackages) { return (Deny-Reconcile "the install record at $rootStamp is unreadable or holds no packages object.") }
        }
        # $recorded: lockfile key -> what was installed. $skipped: what the install left
        # out on this platform. The root stamp is the record of the last WORKSPACE install,
        # so where both stamps list a package it prevails over the server-local one, which
        # a reconciled seat keeps as a leftover of the install that preceded it.
        $recorded = [System.Collections.Generic.Dictionary[string,string]]::new([System.StringComparer]::Ordinal)
        $skipped  = [System.Collections.Generic.Dictionary[string,bool]]::new([System.StringComparer]::Ordinal)
        foreach ($name in $serverPackages.Keys) {
            if ([string]$name -eq '') { continue }
            $key      = $serverRel + '/' + [string]$name
            $entry    = $serverPackages[$name]
            $identity = Get-PackageIdentity $entry
            if ($null -eq $identity) { return (Deny-Reconcile "the install record at $serverStamp holds an entry with no package object.") }
            $recorded[$key] = $identity
            $skipped[$key]  = [bool]$entry['ideallyInert']
        }
        if ($null -ne $rootPackages) {
            foreach ($name in $rootPackages.Keys) {
                if ([string]$name -eq '') { continue }
                $key      = [string]$name
                $entry    = $rootPackages[$name]
                $identity = Get-PackageIdentity $entry
                if ($null -eq $identity) { return (Deny-Reconcile "the install record at $rootStamp holds an entry with no package object.") }
                $recorded[$key] = $identity
                $skipped[$key]  = [bool]$entry['ideallyInert']
            }
        }
        $lockKeys = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
        foreach ($name in $lockPackages.Keys) { $lockKeys.Add([string]$name) | Out-Null }
        # 1. Nothing recorded as installed may be removed or replaced, whatever its tree.
        foreach ($key in $recorded.Keys) {
            if (-not $lockKeys.Contains($key)) { return (Deny-Reconcile "npm would REMOVE ${key}: it is installed here and absent from the lockfile.") }
            $wanted = Get-PackageIdentity $lockPackages[$key]
            if ($null -eq $wanted -or $wanted -cne $recorded[$key]) { return (Deny-Reconcile "npm would REPLACE ${key}: the installed entry and the lockfile entry differ.") }
        }
        # 2. The lockfile may only add to the ROOT tree. A key that names no node_modules
        #    directory is a workspace source entry, not an installed package.
        foreach ($key in $lockKeys) {
            if ($recorded.ContainsKey($key)) { continue }
            if ($key.StartsWith('node_modules/', [System.StringComparison]::Ordinal)) { continue }
            if ($key.IndexOf('node_modules/', [System.StringComparison]::Ordinal) -lt 0) { continue }
            return (Deny-Reconcile "npm would ADD $key outside the root node_modules tree.")
        }
        # 3. The disk, in every workspace tree: the workspace folder itself, the server,
        #    and each workspace the lockfile names. Same enumeration as npm's -- every
        #    child of a node_modules directory, a scope one level deeper, and the same
        #    below every nested node_modules. Names starting with '.' are not packages.
        $trees = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
        [void]$trees.Add($wsFull)
        [void]$trees.Add($srvFull)
        foreach ($key in $lockKeys) {
            # The root's own entry names the workspace folder, already in the list.
            if ([string]::IsNullOrEmpty($key)) { continue }
            if ($key.IndexOf('node_modules/', [System.StringComparison]::Ordinal) -ge 0) { continue }
            $full = [System.IO.Path]::GetFullPath((Join-Path $wsFull $key))
            if (-not $full.StartsWith($wsFull + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase)) {
                return (Deny-Reconcile "the lockfile names $key, which is not a folder below $WorkspaceRoot.")
            }
            [void]$trees.Add($full)
        }
        $seen = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
        $pathComparison = [System.StringComparison]::Ordinal
        if ([System.IO.Path]::DirectorySeparatorChar -eq '\') { $pathComparison = [System.StringComparison]::OrdinalIgnoreCase }
        foreach ($tree in $trees) {
            $modules = [System.IO.Path]::Combine($tree, 'node_modules')
            if (-not ([System.IO.Directory]::Exists($modules))) { continue }
            $treeRel = $tree.Substring($wsFull.Length).TrimStart([char[]]('\', '/')).Replace('\', '/')
            if ($treeRel -ne '') { $treeRel = $treeRel + '/' }
            $pending = [System.Collections.Generic.Stack[string]]::new()
            $pending.Push($modules)
            while ($pending.Count -gt 0) {
                $dir = $pending.Pop()
                $inScope = [System.IO.Path]::GetFileName($dir).StartsWith('@')
                foreach ($child in [System.IO.Directory]::GetDirectories($dir)) {
                    $leaf = [System.IO.Path]::GetFileName($child)
                    if ($leaf.StartsWith('.')) { continue }
                    if ((-not $inScope) -and $leaf.StartsWith('@')) {
                        # A scope folder holds packages one level down.
                        $pending.Push($child)
                        continue
                    }
                    $key = $treeRel + 'node_modules/' + $child.Substring($modules.Length + 1).Replace('\', '/')
                    if (Test-IsLink $child) {
                        # A link stands for a package only where an install record made it,
                        # to the target the lockfile names. It is never followed.
                        $target = Get-LinkTarget $child
                        $fields = $null
                        if ($recorded.ContainsKey($key)) { $fields = $recorded[$key].Split('|') }
                        if ([string]::IsNullOrEmpty($target) -or $null -eq $fields -or $fields[3] -ne '1' -or [string]::IsNullOrEmpty($fields[1])) {
                            return (Deny-Reconcile "$key is a link and no install record made it to the target the lockfile names, so what npm would do with it is not evaluated.")
                        }
                        # npm stores a workspace link's target relative to the workspace.
                        $wanted = [System.IO.Path]::GetFullPath((Join-Path $wsFull $fields[1]))
                        $actual = $target
                        if (-not [System.IO.Path]::IsPathRooted($actual)) {
                            $actual = [System.IO.Path]::GetFullPath((Join-Path ([System.IO.Path]::GetDirectoryName($child)) $actual))
                        }
                        if (-not [string]::Equals($wanted, $actual, $pathComparison)) {
                            return (Deny-Reconcile "npm would REPLACE the link ${key}: it points at $target and the lockfile wants $($fields[1]).")
                        }
                        [void]$seen.Add($key)
                        continue
                    }
                    if (-not $recorded.ContainsKey($key)) { return (Deny-Reconcile "npm would REMOVE ${key}: it is on disk and in no install record.") }
                    [void]$seen.Add($key)
                    $fields = $recorded[$key].Split('|')
                    if ($fields[3] -ne '0') { return (Deny-Reconcile "npm would REPLACE ${key}: the install record holds a link there and the disk holds a directory.") }
                    $installed = Read-ManifestVersion ([System.IO.Path]::Combine($child, 'package.json'))
                    if ($installed -cne $fields[0]) { return (Deny-Reconcile "npm would REPLACE ${key}: the package.json on disk does not say version $($fields[0]).") }
                    $nested = [System.IO.Path]::Combine($child, 'node_modules')
                    if ([System.IO.Directory]::Exists($nested)) { $pending.Push($nested) }
                }
            }
        }
        foreach ($key in $recorded.Keys) {
            if ($seen.Contains($key) -or $skipped[$key]) { continue }
            if ($key.IndexOf('node_modules/', [System.StringComparison]::Ordinal) -lt 0) { continue }
            return (Deny-Reconcile "npm would ADD $key back: it is recorded as installed here and its directory is gone.")
        }
        $Reason.Value = ''
        return $true
    } catch {
        return (Deny-Reconcile "the lockfile, an install record or the installed tree could not be read: $_")
    }
}
# --- Vintage pipeline (#3713): marker-based freshness when present ---
# When the content-addressed marker exists, freshness means "the current vintage
# was built from exactly this source" — the mtime of the frozen legacy build/
# carries no signal there (nothing rewrites it anymore). A vintage rebuild
# publishes build-<sha>/ + switches the marker atomically; it rewrites NOTHING a
# live process reads, so the ARM debt below is legacy-only: v5 wrappers
# hot-swap on the marker switch, v4 wrappers keep serving the frozen build/
# harmlessly until their session respawns.
$markerFile = Join-Path $McpServerPath 'build-current'
$vintageMode = $false
$vintageStale = $false
if (Test-Path $markerFile) {
    $vintageName = (Get-Content -Raw -LiteralPath $markerFile -ErrorAction SilentlyContinue).Trim()
    $vintageDir = Join-Path $McpServerPath $vintageName
    if ($vintageName -match '^build-[0-9a-f]{16}$') {
        if (-not (Test-Path (Join-Path $vintageDir 'index.js'))) {
            # W3 (#3713): a marker naming a vintage whose index.js is gone (retention
            # pruned the live one, publish interrupted) must not fall through to the
            # legacy mtime path — that would ARM live hosts for a legacy rebuild while
            # the correct recovery is a vintage republish, which arms nothing.
            $vintageMode = $true
            $vintageStale = $true
            Write-Result 'WARN' "build-current points at '$vintageName' but its index.js is missing (retention pruned the live vintage? corrupted publish?) — republishing to repair the marker (#3713 W3)."
        } else {
            $vintageMode = $true
            if (Test-BuildMatchesSource -BuildPath $vintageDir -McpServerPath $McpServerPath -RepoRoot $RepoRoot) {
                Write-Result 'FRESH' "vintage $vintageName was built from the checked-out source (build-current marker)."
                if ($liveHosts.Count -gt 0) {
                    Write-Result 'SKIP' "$($liveHosts.Count) legacy host(s) alive on the frozen build/ — they take the new vintage at their next session spawn; v5 wrappers hot-swap on publish. No restart is owed (#3713)."
                }
                exit 0
            }
            $vintageStale = $true
            Write-Result 'WARN' "vintage $vintageName does not match the checked-out source — republishing (content-addressed rebuild arms nothing)."
        }
    } else {
        # W3 (#3713): the vintage naming pattern is duplicated between this guard and
        # the submodule's publish-build.mjs. Content the guard does not recognize means
        # the two have diverged — a SILENT fallthrough to the mtime path would read as
        # "no vintages on this machine" and hide the drift. Say it, then fall through.
        Write-Result 'WARN' "build-current marker content unrecognized ('$vintageName') — pattern divergence between this guard and publish-build.mjs (#3713 W3)? Falling back to the legacy mtime path."
    }
    # Absent marker = pre-#3713 checkout: legacy mtime path, normal and silent.
}

# --- Decision ---
if (-not $vintageStale -and $buildNewest -gt 0 -and $buildNewest -ge $srcNewest) {
    Write-Result 'FRESH' "build/ is up to date (newest build .js >= newest src .ts: $srcFileRel)."
    if ($RequireFresh -and $staleCount -gt 0) {
        Write-Result 'ARM' "$hostsDetail. Build is fresh on disk, but these live hosts still serve the previous build. Restart VS Code before continuing the executor cycle. $killHint"
        exit 10
    }
    exit 0
}

# mtime says STALE. Before paying for a rebuild -- and for the VS Code restart that a rebuild
# OWES (ARM guard below) -- ask whether the source actually moved. Guarded on `$buildNewest -gt 0`:
# an absent build/ carries no stamp to trust and must always be produced.
if (-not $vintageMode -and $buildNewest -gt 0 -and (Test-BuildMatchesSource -BuildPath $BuildPath -McpServerPath $McpServerPath -RepoRoot $RepoRoot)) {
    $lagSec = [math]::Round(($srcNewest - $buildNewest) / 10000000)
    Write-Result 'FRESH' "build/ was produced from the checked-out source (build-info.json sha = submodule HEAD, src/ clean). Newest src .ts ($srcFileRel) leads by ${lagSec}s in MTIME ONLY -- a git checkout rewrites mtimes without changing content. No rebuild, so no restart is owed."
    # The ARM debt is NOT suppressed with the rebuild: a host predating build/index.js loaded an
    # EARLIER build and genuinely serves older modules. What disappears is the spurious arming
    # that a redundant rebuild manufactured for every live host at once.
    if ($RequireFresh -and $staleCount -gt 0) {
        Write-Result 'ARM' "$hostsDetail. Build is fresh on disk, but these live hosts still serve the previous build. Restart VS Code before continuing the executor cycle. $killHint"
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

# --- Workspace plan (#4886): decided BEFORE the ARM guard and the dry-run exits ---
# Since ms#1882 `mcps/internal` is an npm workspace and the RSM build consumes the compiled
# dist/ of its sibling package @vibesync/core. The vintage of ms#1882 at 9e293b0a did not
# carry it: 87 of its .js files kept bare '@vibesync/core' imports (measured 2026-11-24),
# resolved at run time through the workspace link into packages/vibesync-core/dist. Since
# ms#1910 (roo-extensions #4918) publish-build.mjs bundles the package into the vintage.
# A rebuild therefore needs up to two workspace steps first, and whether they CAN run must be
# known before anything is claimed or announced: a run refused here rebuilds nothing, so it
# must not owe a restart, and a dry run must say what a real one would do. Read-only --
# nothing is installed or built in this section.
$WorkspaceRoot    = Join-Path $RepoRoot 'mcps/internal'
$WorkspaceLock    = Join-Path $WorkspaceRoot 'package-lock.json'
$WorkspaceModules = Join-Path $WorkspaceRoot 'node_modules'
# Pre-#4886 gitlink: no workspace package under mcps/internal yet, nothing applies. It has
# to stay a no-op until the bump lands, or every seat logs a line on every rebuild -- and
# `npm run build --workspace` fails there with "No workspaces found" (measured on PR #4893's
# first CI run).
$wsApplies       = Test-Path $CoreSrcPath
$wsNeedsInstall  = $false
$wsAlive         = 0
$wsPlan          = ''
$wsReconcileSafe = $false
$wsReconcileWhy  = ''
if ($wsApplies) {
    if (-not (Test-Path $WorkspaceLock)) {
        # A workspace package without a workspace lockfile cannot be installed by this
        # gate: failing loudly beats compiling against a silently stale dist/.
        Exit-WorkspaceStepFailed "Workspace lockfile not found at $WorkspaceLock while packages/vibesync-core exists - cannot guarantee the install or the core build."
    }
    $wsNeedsInstall = -not (Test-WorkspaceInstallCurrent -LockPath $WorkspaceLock -ModulesPath $WorkspaceModules -ServerPath $McpServerPath)
    # `npm ci` deletes and reinstalls the node_modules trees live RSM hosts run from, so it
    # is refused while ANY RSM host process is alive: legacy children, versioned children
    # and wrappers, each through its corroborated role list above (a combined probe would
    # double-count wrapper + child pairs -- ensure-build-fresh.arm-guard). Not restricted
    # to hosts running from THIS tree: on a seat, all RSM sessions share the one checkout.
    $wsAlive = @($indexHosts + $vintageHosts + $wrapperHosts).Count
    if ($wsNeedsInstall -and $wsAlive -gt 0) {
        # The hot path (#4918): `npm install` stands in for the refused `npm ci` when all it
        # would do is add to the root tree. Read-only here, like everything in this section.
        $verdict = @(Test-WorkspaceInstallReconcileSafe -LockPath $WorkspaceLock -WorkspaceRoot $WorkspaceRoot -WorkspaceModulesPath $WorkspaceModules -ServerPath $McpServerPath -Reason ([ref]$wsReconcileWhy))
        # Exactly one boolean, and it must be true: anything else is not a green light.
        $wsReconcileSafe = ($verdict.Count -eq 1 -and $verdict[0] -is [bool] -and $verdict[0])
    }
    $wsPlan = if ($wsNeedsInstall) {
        if ($wsReconcileSafe) {
            " It would first bring the workspace install in line with 'npm install' in $WorkspaceRoot under the $wsAlive RSM host process(es) this run's probe found -- nothing under an installed tree would be removed or replaced (#4918) -- then 'npm run build --workspace @vibesync/core'."
        } else {
            " It would first need 'npm ci' in $WorkspaceRoot -- refused while any RSM host is alive ($wsAlive found by this run's probe) -- then 'npm run build --workspace @vibesync/core'."
        }
    } else {
        " It would first run 'npm run build --workspace @vibesync/core' in $WorkspaceRoot."
    }
}
# A REAL run would exit on the refusal instead of reaching the server build.
$wsWillRefuse = $wsApplies -and $wsNeedsInstall -and $wsAlive -gt 0 -and -not $wsReconcileSafe
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
if ($liveHosts.Count -gt 0 -and -not $vintageMode) {
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
    if ($wsWillRefuse) {
        # Same rule, another door (#4893): a run that will be refused on the workspace
        # install never reaches the server build, so it arms nothing and owes nothing --
        # under -DryRun too, since a REAL run would hit the same refusal. Measured
        # 2026-11-24 on an isolated legacy-shape tree: the categorical line printed
        # first, then the refusal.
        Write-Result 'ARM' "$hostsDetail. NOTHING was rebuilt and NOTHING is armed: the workspace install is stale and 'npm ci' is refused while RSM hosts are alive, so this run does not reach the server build (#4886). No restart is owed."
    } elseif ($noRebuildThisRun) {
        $dryLabel = if ($DryRun) { '-DryRun' } else { '-WhatIf' }
        Write-Result 'ARM' "$hostsDetail. ${dryLabel}: NOTHING was rebuilt and NOTHING is armed. A REAL run would ARM the ESM mixed-millage crash (#3489) on those sessions -- the new build is served only after a VS Code restart, and inbox stays broken until then -- and would OWE that restart ([INTERACTIVE-ONLY])."
    } else {
        Write-Result 'ARM' "$hostsDetail. Rebuilding now ARMS the ESM mixed-millage crash (#3489) on those sessions: the new build is served only after a VS Code restart, and inbox stays broken until then. THE RESTART IS OWED ([INTERACTIVE-ONLY])."
        $restartRequired = $true
    }
}

# Vintage mode (#3713): the rebuild below republishes a content-addressed vintage and
# rewrites nothing a live process reads - v5 wrappers hot-swap on the marker switch,
# v4 wrappers keep serving the frozen build/. No restart is owed, so no ARM is emitted.
if ($vintageMode -and $liveHosts.Count -gt 0) {
    Write-Result 'SKIP' "$($liveHosts.Count) live host(s) - vintage rebuild arms nothing (v5 hot-swaps, v4 serves frozen build/) - no restart owed (#3713)."
}

if ($DryRun) {
    # $wsPlan names the workspace steps a real run would take first (#4886): without it a
    # dry run reported the server build and stayed silent on an 'npm ci' it would refuse.
    Exit-NotFresh 'SKIP' "-DryRun set: would run 'npm run build' in ${McpServerPath}.$wsPlan"
}

if (-not $PSCmdlet.ShouldProcess($McpServerPath, "Run 'npm run build' (clean + tsc)")) {
    Exit-NotFresh 'SKIP' "ShouldProcess declined — not rebuilding.$wsPlan"
}

# --- Workspace install + shared package build (#4886): the plan above, executed ---
# Deliberately AFTER the ARM guard: a headless caller on the legacy path keeps its
# ARMED-DEFER precedence. A refusal exits here, before the pre-op backup and any build.
if (-not $wsApplies) {
    Write-Result 'SKIP' "No packages/vibesync-core under mcps/internal - pre-#4886 gitlink, shared-package install and build do not apply."
} else {
    if (-not $wsNeedsInstall) {
        Write-Result 'OK' "Workspace install is current with the lockfile (content check, not mtime) - no 'npm ci' needed."
    } else {
        if ($wsAlive -gt 0 -and -not $wsReconcileSafe) {
            Exit-WorkspaceStepFailed -Refused "Workspace install is missing or stale, so 'npm ci' is required in $WorkspaceRoot -- REFUSED while $wsAlive RSM host process(es) are alive (npm would remove and reinstall the dependency trees those processes use; on Windows a locked native .node aborts it after a partial removal). The hot path of #4918 does not open on this tree either: $wsReconcileWhy Remedy: stop the RSM hosts (full-quit VS Code on an interactive seat), then run scripts/claude/executor-preflight.ps1 again, or run 'npm ci' in mcps/internal yourself with VS Code closed. No install was attempted and no host was touched."
        } elseif ($wsAlive -gt 0) {
            # The hot path (#4918). `npm install` where `npm ci` is refused: the check above
            # read every installed tree and found that npm would neither remove nor replace
            # anything under one, only add to the root tree -- the tree no live RSM host
            # resolves into (build-6755d61ff811b4bb, 2026-11-24). Measured once, end to end,
            # on the first-deployment shape of po-204: 20 s, and 0 files removed, modified or
            # added under the server tree out of 18,453.
            Write-Result 'OK' "Workspace install missing or stale under live RSM hosts, and 'npm install' would only add to the root tree - reconciling in place in $WorkspaceRoot (no 'npm ci', nothing under an installed tree removed or replaced, #4918)..."
            $lockHash = (Get-FileHash -LiteralPath $WorkspaceLock -Algorithm SHA256).Hash
            Push-Location $WorkspaceRoot
            try {
                $installOutput = & cmd /c "npm install 2>&1"
                $installExit = $LASTEXITCODE
            } finally {
                Pop-Location
            }
            if ($installExit -ne 0) {
                $tail = ($installOutput | Select-Object -Last 5 | Out-String).Trim()
                Exit-WorkspaceStepFailed "'npm install' failed (exit $installExit) in $WorkspaceRoot - NOT continuing to a build that would compile against a half-installed tree. Tail:`n$tail"
            }
            # npm's exit code is not enough: the lockfile must still be the one this run
            # planned against (npm rewrote nothing), and the install must now read current.
            if ((Get-FileHash -LiteralPath $WorkspaceLock -Algorithm SHA256).Hash -ne $lockHash) {
                Exit-WorkspaceStepFailed "'npm install' exited 0 in $WorkspaceRoot but rewrote package-lock.json - the lockfile npm planned against is no longer the one on disk. NOT continuing to a build. Inspect it with: git -C mcps/internal diff package-lock.json"
            }
            if (-not (Test-WorkspaceInstallCurrent -LockPath $WorkspaceLock -ModulesPath $WorkspaceModules -ServerPath $McpServerPath)) {
                Exit-WorkspaceStepFailed "'npm install' exited 0 in $WorkspaceRoot but the workspace install is still not current with the lockfile (content check) - NOT continuing to a build that would compile against an unverified tree."
            }
            Write-Result 'OK' "Workspace install reconciled under live RSM hosts and current with the lockfile."
        } else {
            Write-Result 'OK' "Workspace install missing or stale and no RSM host is alive - running 'npm ci' in $WorkspaceRoot..."
            Push-Location $WorkspaceRoot
            try {
                $installOutput = & cmd /c "npm ci 2>&1"
                $installExit = $LASTEXITCODE
            } finally {
                Pop-Location
            }
            if ($installExit -ne 0) {
                $tail = ($installOutput | Select-Object -Last 5 | Out-String).Trim()
                Exit-WorkspaceStepFailed "'npm ci' failed (exit $installExit) in $WorkspaceRoot - NOT continuing to a build that would compile against a half-installed tree. Tail:`n$tail"
            }
            Write-Result 'OK' "Workspace install completed."
        }
    }

    # Refresh the shared package before the RSM build consumes its dist/. (`npm run build`
    # in the server rebuilds it too, through `prebuild`; this step runs first and names the
    # failure on its own line.)
    Push-Location $WorkspaceRoot
    try {
        $coreOutput = & cmd /c "npm run build --workspace @vibesync/core 2>&1"
        $coreExit = $LASTEXITCODE
    } finally {
        Pop-Location
    }
    if ($coreExit -eq 0) {
        Write-Result 'OK' "Built @vibesync/core (workspace dependency of the RSM build)."
    } else {
        $tail = ($coreOutput | Select-Object -Last 5 | Out-String).Trim()
        Exit-WorkspaceStepFailed "Core build FAILED (exit $coreExit) - refusing to publish a server build against the previous @vibesync/core/dist (the seat would read STALE again on the next run and republish forever). Same exit path as a failed server build. Tail:`n$tail"
    }
}
# --- Pre-op guard (#3712) : backup pre-destruction de build/ avant npm run build.
# npm run build (clean + tsc) detruit build/ avant de le reconstruire. Le guard prend
# un snapshot du build courant (s'il existe) dans %USERPROFILE%\.roo-state-manager\
# preop-backup\ -- best-effort, n'echoue jamais.
$guardScript = Join-Path $RepoRoot 'scripts/mcp/deploy-preop-guard.ps1'
if (Test-Path -LiteralPath $guardScript) {
    try {
        . $guardScript
        $guardTarget = if ($vintageMode) { Join-Path $McpServerPath 'build-out' } else { $BuildPath }
        $guardResult = Invoke-DeployPreOpGuard -Operation "npm run build (ensure-build-fresh)" -LiteralPath $guardTarget -Mode Backup -RepoRoot $RepoRoot
        Write-Result 'OK' "[guard] pre-op: Action=$($guardResult.Action) BackupDir=$($guardResult.BackupDir)"
    } catch {
        Write-Result 'WARN' "[guard] pre-op guard echoue (non-fatal, build continue): $_"
    }
} else {
    Write-Result 'WARN' "[guard] deploy-preop-guard.ps1 introuvable, pre-op desactive."
}

# --- Rebuild (mirror worker Sync-McpSubmoduleBuild: clean:build + tsc, non-fatal on failure) ---
Push-Location $McpServerPath
try {
    Write-Result 'OK' "Running 'npm run build' (clean rebuild)..."
    # Merge stderr at the cmd.exe layer. A PS-level `2>&1` lets PS 5.1 mint
    # ErrorRecords from npm's stderr (npm warn allow-scripts ...), and an
    # intermittent promotion to terminating fired the catch below on a build
    # that had succeeded — vintage marker never published, false preflight
    # exit 1 (po-2027, 2026-09-19 01:12Z, EAP=Continue in force). With cmd
    # doing the merge, PS only ever sees strings: no ErrorRecord exists to
    # promote, under any EAP. cmd owns PATH resolution now, which also
    # retires the npm.cmd-vs-npm.ps1-wrapper hazard guarded here before.
    $buildOutput = & cmd /c "npm run build 2>&1"
    $buildExit = $LASTEXITCODE
    if ($buildExit -eq 0) {
        if ($vintageMode) {
            Write-Result 'REBUILT' "Vintage published and marker switched - live v5 wrappers hot-swap on their own; v4 hosts pick it up at next session spawn. No restart owed (#3713)."
        } else {
            Write-Result 'REBUILT' "MCP build regenerated successfully. Restart VS Code to activate the new build ([INTERACTIVE-ONLY])."
        }
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
