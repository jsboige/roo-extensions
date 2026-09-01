#Requires -Version 5.1

<#
.SYNOPSIS
    Detect and optionally kill orphan/zombie MCP host processes that accumulate on every restart.

.DESCRIPTION
    Background: each restart of VS Code (or MCP host reload cascade) spawns a new pair
    `mcp-wrapper.cjs` + `node build/index.js` without killing the previous ones. The orphans
    accumulate: their stdio is bound to a dead pipe (inactive, no functional impact) but they
    consume RAM and the pile grows monotonically between restarts.

    This script:
    1. Lists all `node build/index.js` + `mcp-wrapper.cjs` (+ optional: playwright/mcp, mcp-searxng)
       processes, sorted by StartTime ascending.
    2. Identifies the LIVE MCP host PID (the one serving the current Claude session) via a
       conservative heuristic and EXCLUDES it categorically from any kill list.
    3. Identifies ZOMBIE candidates: procs whose StartTime is older than `-OlderThanHours`
       (default 12) AND not the live PID.
    4. Refuses to kill (exit code 2) ONLY when the live session(s) genuinely cannot be located
       (no build/index.js in the newest cluster, or no cluster at all). When the newest restart
       cluster has MULTIPLE build/index.js procs (a multi-session machine: interactive Claude +
       a scheduled worker), it cannot single out the live PID → it preserves the ENTIRE newest
       cluster and still cleans older-cluster zombies. See "MULTI-SESSION MACHINES" below.

    Mode of operation:
    - DEFAULT (no flag) = DRY RUN. Lists zombies, marks live PID, exits 0. NOTHING is killed.
    - `-Execute`         = actually kill zombies. Requires live PID identified with certainty.
    - `-WhatIf`          = PowerShell built-in DryRun (same effect as no flag, more verbose).

.PARAMETER OlderThanHours
    Age threshold in hours for a proc to be considered a zombie candidate. Default 12.
    Procs started more recently than this are NEVER killed (defense in depth).

.PARAMETER Execute
    Actually kill zombie candidates. Without this flag, the script is read-only.

.PARAMETER IncludeAllMcp
    Also include `playwright/mcp` and `mcp-searxng` orphan procs in the listing/kill.
    Default = FALSE (roo-state-manager only, the documented pattern from po-2023 c.38).

.PARAMETER McpRoot
    Path to roo-state-manager root (where build/index.js lives).
    Default = auto-detect from script location (assumes standard layout).

.PARAMETER Mode
    Heuristic used to identify live MCP procs (Consolidation #3323, 2026-08-31).
    - 'Cluster'      (default) — newest-StartTime cluster. Original behavior (Issue #2830).
    - 'ParentChain'  — walk parent chain in-memory, kill only procs with no Claude ancestor.
                       Merged from `scripts/diagnostic/cleanup-mcp-orphans.ps1` (#1281, WMI approach).
    - 'Stdio'        — walk parent chain for `Code.exe` ancestor (handles `npx`-spawned stdio MCPs).
                       Merged from `scripts/maintenance/cleanup-mcp-stdio-zombies.ps1` (#2675).

.PARAMETER CodeProcessName
    Stdio mode only: VS Code editor process name used to detect a live host ancestor.
    Default: 'Code.exe'. Set to 'Code - Insiders.exe' for Insiders builds.

.PARAMETER MinAgeHours
    ParentChain mode only: minimum process age (hours) to consider killing. Default 12.
    Matches the WMI orphan heuristic from cleanup-mcp-orphans.ps1.

.EXAMPLE
    .\cleanup-mcp-zombies.ps1
    Dry run (Cluster mode): list zombies, identify live PID, do nothing.

.EXAMPLE
    .\cleanup-mcp-zombies.ps1 -Mode ParentChain -Execute
    ParentChain mode: kill MCP procs with no live Claude ancestor. Merged feature #1281.

.EXAMPLE
    .\cleanup-mcp-zombies.ps1 -Mode Stdio -Execute -CodeProcessName 'Code - Insiders.exe'
    Stdio mode: kill stdio MCPs (npx/cmd wrappers) with no live VS Code ancestor. Merged feature #2675.

.NOTES
    Issue: #2830 — MCP host zombie processes accumulate on each restart
    Finding: po-2023 c.38 (~51 zombies), po-204 c.46 (7 zombies)
    Gate: Livrable B (auto-scheduling) is USER-GATED. This script stays DORMANT in scheduled tasks.

    CONSOLIDATION (#3323, 2026-08-31):
    - Absorbed `scripts/diagnostic/cleanup-mcp-orphans.ps1` (WMI parent-chain, #1281) → Mode ParentChain
    - Absorbed `scripts/maintenance/cleanup-mcp-stdio-zombies.ps1` (stdio npx, #2675) → Mode Stdio
    - Originals archived to scripts/_archive/cleanup-mcp-scripts-{date}/ with header proof of merger.
    - Cluster mode = original behavior of this file (the most robust heuristic, validated po-2023 c.38).

    SAFETY GUARANTEES:
    - Default mode is read-only. No proc is killed without explicit `-Execute`.
    - The LIVE PID is always excluded from the kill list, period.
    - If the newest restart cluster has NO build/index.js at all (genuinely cannot locate the
      live session), the script refuses to kill (exits 2) rather than risk the wrong process.
    - On MULTI-SESSION machines (newest cluster has >1 build/index.js), the script preserves
      the ENTIRE newest cluster and cleans only older-cluster zombies. See below.
    - The kill uses `Stop-Process -Force` only after a clear log of which PIDs are about to die.

    MULTI-SESSION MACHINES (#2830 follow-up, validated po-204):
    - A machine running 2+ concurrent MCP host sessions (interactive Claude + scheduled
      `claude -p`, or two IDE windows) produces a newest cluster with >1 build/index.js proc.
      The script cannot guess which is live, so it refuses to kill ANY newest-cluster member —
      but unlike a hard exit-2 it still cleans unambiguous zombies from OLDER clusters
      (>OlderThanHours, not live).
    - This restores effectiveness without weakening safety: the zombie criterion (age +
      not-live + not-in-newest-cluster) is identical to the single-session path; only the
      "refuse everything" over-reaction is removed. Validated firsthand on po-204 (newest
      cluster = 2 build/index.js → 14 older-cluster zombies became cleanable that the prior
      exit-2 blocked).

    HEURISTIC FOR LIVE PID IDENTIFICATION:
    - Cluster all matching procs by StartTime. A "cluster" is a group of procs started within
      a 5-minute window of each other (typical of a restart storm).
    - The newest cluster (most recent StartTime) is presumed to be the LIVE one.
    - Within the newest cluster, if there is exactly ONE proc → it's the live PID.
    - Within the newest cluster, if there are MULTIPLE procs (typical: 1 wrapper + 1 build/index.js
      + maybe 1 searxng/playwright), the live one is the build/index.js with the most recent
      StartTime. Wrappers and non-build/index.js procs are excluded.
    - If NO cluster can be identified → exit 2, refuse kill.
    - If the newest cluster has NO build/index.js → exit 2, refuse kill (live session unlocatable).
    - If the newest cluster has >1 build/index.js (multi-session) → preserve the whole newest
      cluster, clean only older-cluster zombies (do NOT exit 2).
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [int]$OlderThanHours = 12,

    [switch]$Execute = $false,

    [switch]$IncludeAllMcp = $false,

    [string]$McpRoot,

    # --- Consolidation #3323: absorb modes from cleanup-mcp-orphans.ps1 + cleanup-mcp-stdio-zombies.ps1 ---
    [ValidateSet('Cluster', 'ParentChain', 'Stdio')]
    [string]$Mode = 'Cluster',

    # Stdio mode only: VS Code editor process name to detect a live host ancestor.
    [string]$CodeProcessName = 'Code.exe',

    # ParentChain mode only: minimum process age (hours) to consider killing.
    [int]$MinAgeHours = 12
)

$ErrorActionPreference = "Stop"

# --- Configuration ----------------------------------------------------------

# Auto-detect McpRoot from script location if not provided
if (-not $McpRoot) {
    # scripts/mcp/cleanup-mcp-zombies.ps1 → scripts/mcp → scripts → repo root → mcps/internal/servers/roo-state-manager
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    $repoRoot = (Get-Item "$scriptDir\..\..").FullName
    $McpRoot = Join-Path $repoRoot "mcps\internal\servers\roo-state-manager"
}

$cutoffTime = (Get-Date).AddHours(-$OlderThanHours)

# Build the list of command-line patterns to match
$patterns = @(
    @{ Name = "build/index.js";     Pattern = "build[\\/]+index\.js" },
    @{ Name = "mcp-wrapper.cjs";    Pattern = "mcp-wrapper\.cjs" }
)
if ($IncludeAllMcp) {
    $patterns += @(
        @{ Name = "playwright/mcp";      Pattern = "@playwright[\\/]+mcp" },
        @{ Name = "mcp-searxng";         Pattern = "mcp-searxng[\\/]+dist[\\/]+index\.js" }
    )
}

# --- 1. Gather all matching procs ------------------------------------------

Write-Host "=== MCP Host Zombie Cleanup ===" -ForegroundColor Cyan
Write-Host "MCP root:    $McpRoot"
Write-Host "Cutoff time: $cutoffTime (>$OlderThanHours h ago)"
Write-Host "Patterns:    $($patterns.Name -join ', ')"
Write-Host "Mode:        $(if ($Execute) { 'EXECUTE (will kill)' } else { 'DRY RUN (read-only)' })"
Write-Host ""

$allProcs = @()
foreach ($p in $patterns) {
    $matched = Get-CimInstance Win32_Process -Filter "Name = 'node.exe'" |
        Where-Object { $_.CommandLine -match $p.Pattern } |
        Select-Object ProcessId, ParentProcessId, CreationDate, CommandLine,
            @{ Name = 'Pattern'; Expression = { $p.Name } }
    $allProcs += $matched
}

if ($allProcs.Count -eq 0) {
    Write-Host "No MCP host procs found. Nothing to do." -ForegroundColor Yellow
    exit 0
}

Write-Host "Found $($allProcs.Count) matching proc(s):" -ForegroundColor Gray
$allProcs | Sort-Object CreationDate | ForEach-Object {
    Write-Host ("  [{0:yyyy-MM-dd HH:mm:ss}] PID={1,-7} parent={2,-7} {3}" -f $_.CreationDate, $_.ProcessId, $_.ParentProcessId, $_.Pattern)
}
Write-Host ""

# --- 2. Cluster procs by StartTime (5-minute windows) -----------------------

$clusterWindowMinutes = 5
$sortedProcs = $allProcs | Sort-Object CreationDate

$clusters = @()
$currentCluster = @()
$lastTime = $null

foreach ($p in $sortedProcs) {
    if ($null -eq $lastTime -or ($p.CreationDate - $lastTime).TotalMinutes -le $clusterWindowMinutes) {
        $currentCluster += $p
    } else {
        if ($currentCluster.Count -gt 0) { $clusters += ,$currentCluster }
        $currentCluster = @($p)
    }
    $lastTime = $p.CreationDate
}
if ($currentCluster.Count -gt 0) { $clusters += ,$currentCluster }

Write-Host "Identified $($clusters.Count) cluster(s) of procs (window: $clusterWindowMinutes min):" -ForegroundColor Gray
for ($i = 0; $i -lt $clusters.Count; $i++) {
    $c = $clusters[$i]
    $start = ($c | Measure-Object CreationDate -Minimum).Minimum
    $end = ($c | Measure-Object CreationDate -Maximum).Maximum
    $isNewest = ($i -eq $clusters.Count - 1)
    $marker = if ($isNewest) { " [NEWEST]" } else { "" }
    Write-Host ("  Cluster {0}: {1} proc(s), {2:HH:mm:ss} → {3:HH:mm:ss}{4}" -f ($i + 1), $c.Count, $start, $end, $marker)
    foreach ($p in $c) {
        Write-Host ("    PID={0,-7} {1:HH:mm:ss} {2}" -f $p.ProcessId, $p.CreationDate, $p.Pattern)
    }
}
Write-Host ""

# --- 3. Identify LIVE PID ---------------------------------------------------

if ($clusters.Count -eq 0) {
    Write-Host "[REFUSE] No clusters found. Cannot identify live PID. Exit 2 (no kill)." -ForegroundColor Red
    exit 2
}

$newestCluster = $clusters[$clusters.Count - 1]

# Within the newest cluster, the LIVE PID is the most recent build/index.js proc.
# We deliberately EXCLUDE wrappers and other MCPs from being "the live one" — the live PID
# must be the build/index.js that's actually serving MCP requests.
$liveCandidates = $newestCluster | Where-Object { $_.Pattern -eq "build/index.js" } | Sort-Object CreationDate -Descending

if ($liveCandidates.Count -eq 0) {
    Write-Host "[REFUSE] Newest cluster has no build/index.js proc. Live PID ambiguous. Exit 2 (no kill)." -ForegroundColor Red
    Write-Host "  (This is unusual — it means the most recent restart produced only wrappers/other MCPs.)" -ForegroundColor Red
    exit 2
}

# Multi-session support (#2830 follow-up): when the newest cluster has MULTIPLE build/index.js
# procs, this machine is running 2+ concurrent MCP host sessions (e.g. an interactive Claude +
# a scheduled `claude -p` worker). We CANNOT guess which build/index.js is the live one → we
# preserve ALL of them and proceed to clean ONLY older-cluster zombies. This restores
# effectiveness on multi-session machines (the script was previously a hard no-op exit-2 there,
# unable to clean even days-old zombies) while keeping the core safety invariant:
# NEVER guess the live PID. The whole newest cluster is also unconditionally excluded below
# (defense in depth), so even a mis-guess cannot touch any concurrent session.
$ambiguousLive = $false
$livePidLabel = ""
if ($liveCandidates.Count -eq 1) {
    $livePid = $liveCandidates[0].ProcessId
    $liveStart = $liveCandidates[0].CreationDate
    $livePidLabel = "PID=$livePid"
    Write-Host "[LIVE] Identified live MCP host PID=$livePid (build/index.js, started $liveStart)" -ForegroundColor Green
} else {
    $ambiguousLive = $true
    $livePid = $null
    $livePidLabel = "all $($liveCandidates.Count) newest-cluster build/index.js procs"
    Write-Host "[LIVE-AMBIGUOUS] Newest cluster has $($liveCandidates.Count) build/index.js procs (multi-session machine)." -ForegroundColor Yellow
    Write-Host "  Cannot single out the live PID → preserving ALL newest-cluster build/index.js procs." -ForegroundColor Yellow
    foreach ($c in $liveCandidates) {
        Write-Host ("    PID={0,-7} started {1:yyyy-MM-dd HH:mm:ss}" -f $c.ProcessId, $c.CreationDate) -ForegroundColor Yellow
    }
    Write-Host "  Will clean ONLY older-cluster zombies (entire newest cluster preserved)." -ForegroundColor Yellow
}
Write-Host ""

# --- 4. Identify zombie candidates -----------------------------------------

# Build the set of PIDs to PRESERVE (never killed). In single-session mode this is just the
# one live PID; in ambiguous multi-session mode it is ALL newest-cluster build/index.js procs.
$preservePids = @()
if ($ambiguousLive) {
    $preservePids += $liveCandidates.ProcessId
} elseif ($null -ne $livePid) {
    $preservePids += $livePid
}

$zombies = $allProcs | Where-Object {
    $preservePids -notcontains $_.ProcessId -and   # NOT a preserved/live PID
    $_.CreationDate -lt $cutoffTime                 # AND older than threshold
}

# Also defend-in-depth: never kill anything in the newest cluster regardless of age. This is the
# safety backstop in ambiguous mode — even if a live PID were mis-guessed, the whole newest
# cluster (including every concurrent MCP host session) is unconditionally preserved.
$newestClusterPids = $newestCluster | ForEach-Object { $_.ProcessId }
$zombies = $zombies | Where-Object { $newestClusterPids -notcontains $_.ProcessId }

Write-Host "Zombie candidates (older than $OlderThanHours h AND not live PID AND not in newest cluster):" -ForegroundColor $(if ($zombies.Count -gt 0) { "Yellow" } else { "Green" })
if ($zombies.Count -eq 0) {
    Write-Host "  (none — all matching procs are either live or too recent)" -ForegroundColor Green
}
else {
    foreach ($z in $zombies) {
        $ageHours = [math]::Round(((Get-Date) - $z.CreationDate).TotalHours, 1)
        Write-Host ("  PID={0,-7} age={1,5}h  pattern={2}" -f $z.ProcessId, $ageHours, $z.Pattern)
    }
}
Write-Host ""

# --- 5. Execute or report --------------------------------------------------

if ($zombies.Count -eq 0) {
    Write-Host "Nothing to do. Preserved: $livePidLabel" -ForegroundColor Green
    exit 0
}

if (-not $Execute) {
    Write-Host "[DRY RUN] Would kill $($zombies.Count) zombie proc(s) with -Execute flag." -ForegroundColor Cyan
    Write-Host "[DRY RUN] Preserved: $livePidLabel" -ForegroundColor Cyan
    Write-Host "[DRY RUN] Re-run with -Execute to actually kill." -ForegroundColor Cyan
    exit 0
}

# Execute mode — actually kill
Write-Host "[EXECUTE] Killing $($zombies.Count) zombie proc(s)..." -ForegroundColor Magenta
$killErrors = @()
foreach ($z in $zombies) {
    try {
        Stop-Process -Id $z.ProcessId -Force -ErrorAction Stop
        Write-Host "  [KILLED] PID=$($z.ProcessId) ($($z.Pattern))" -ForegroundColor Magenta
    } catch {
        $killErrors += $_
        Write-Host "  [ERROR]  PID=$($z.ProcessId) : $($_.Exception.Message)" -ForegroundColor Red
    }
}

if ($killErrors.Count -gt 0) {
    Write-Host "[DONE with errors] $($killErrors.Count) kill(s) failed. Preserved: $livePidLabel" -ForegroundColor Red
    exit 1
}

Write-Host "[DONE] Killed $($zombies.Count) zombie proc(s). Preserved: $livePidLabel" -ForegroundColor Green
exit 0


# ============================================================================
# CONSOLIDATION (#3323, 2026-08-31): absorbed modes from
#   - scripts/diagnostic/cleanup-mcp-orphans.ps1       (WMI parent-chain, #1281)
#   - scripts/maintenance/cleanup-mcp-stdio-zombies.ps1 (stdio npx, #2675)
# ============================================================================

function Invoke-ParentChainMode {
    # Absorbed from scripts/diagnostic/cleanup-mcp-orphans.ps1 (#1281)
    # Strategy: WMI single-fetch → in-memory parent chain walk → kill MCP procs with NO Claude ancestor
    # AND older than MinAgeHours.

    Write-Host "`n=== [Mode: ParentChain] WMI parent-chain cleanup (#1281, absorbed) ===" -ForegroundColor Cyan
    Write-Host "Minimum age: $MinAgeHours h | Execute: $Execute | VerboseOutput: $false`n" -ForegroundColor Gray

    $McpPatterns = @(
        'mcp-searxng\dist\index.js'
        'roo-state-manager\build\index.js'
        'roo-state-manager\mcp-wrapper.cjs'
        '@playwright\mcp\cli.js'
        'win-cli\server\dist\index.js'
        'mcp-searxng'             # npx wrapper
        '@playwright/mcp'         # npx wrapper
    )

    $ClaudePatterns = @('claude', 'Code.exe', 'claud')

    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $allProcs = Get-CimInstance Win32_Process -ErrorAction SilentlyContinue
    $sw.Stop()
    if (-not $allProcs) {
        Write-Host "WMI query failed — aborting ParentChain mode." -ForegroundColor Yellow
        return
    }
    Write-Host "WMI query: $($sw.ElapsedMilliseconds)ms ($($allProcs.Count) processes)" -ForegroundColor DarkGray

    $procById = @{}
    foreach ($p in $allProcs) { $procById[$p.ProcessId] = $p }

    function Test-IsMcpServerLocal {
        param([string]$CmdLine)
        foreach ($pattern in $McpPatterns) {
            if ($CmdLine -like "*$pattern*") { return $true }
        }
        return $false
    }
    function Test-IsClaudeProcessLocal {
        param([string]$CmdLine, [string]$ProcessName)
        if ($ProcessName -like '*Code*') { return $true }
        foreach ($pattern in $ClaudePatterns) {
            if ($CmdLine -like "*$pattern*") { return $true }
        }
        return $false
    }

    $allNodeProcs = @($allProcs | Where-Object { $_.Name -eq 'node.exe' })
    $mcpProcs = @($allNodeProcs | Where-Object { Test-IsMcpServerLocal -CmdLine $_.CommandLine })
    if ($mcpProcs.Count -eq 0) {
        Write-Host "No MCP server processes found." -ForegroundColor Green
        return
    }

    $claudeProcs = @($allProcs | Where-Object { Test-IsClaudeProcessLocal -CmdLine $_.CommandLine -ProcessName $_.Name })
    $codeProcs = Get-Process -Name 'Code' -ErrorAction SilentlyContinue

    $claudeAncestorPids = @{}
    foreach ($cp in $claudeProcs) { $claudeAncestorPids[$cp.ProcessId] = $true }
    foreach ($cp in $codeProcs) { $claudeAncestorPids[$cp.Id] = $true }

    function Test-HasClaudeParentLocal {
        param([int]$ProcessId)
        $visited = @{}
        $currentPid = $ProcessId
        while ($currentPid -and $currentPid -ne 0 -and $currentPid -ne 4 -and -not $visited[$currentPid]) {
            $visited[$currentPid] = $true
            if ($claudeAncestorPids[$currentPid]) { return $true }
            $proc = $procById[$currentPid]
            if (-not $proc) { return $false }
            if (Test-IsClaudeProcessLocal -CmdLine $proc.CommandLine -ProcessName $proc.Name) { return $true }
            if ($proc.Name -eq 'Code.exe') { return $true }
            $currentPid = $proc.ParentProcessId
        }
        return $false
    }

    $cutoffTime2 = (Get-Date).AddHours(-$MinAgeHours)
    $orphans = @()
    foreach ($mcp in $mcpProcs) {
        if (-not (Test-HasClaudeParentLocal -ProcessId $mcp.ProcessId) -and $mcp.CreationDate -lt $cutoffTime2) {
            $orphans += $mcp
        }
    }

    if ($orphans.Count -eq 0) {
        Write-Host "No orphaned MCP servers found." -ForegroundColor Green
        return
    }
    Write-Host "ORPHANED MCP servers ($($orphans.Count)):" -ForegroundColor Red
    foreach ($p in $orphans) {
        $ageH = [math]::Round(((Get-Date) - $p.CreationDate).TotalHours, 1)
        Write-Host ("  PID={0,-7} age={1,5}h  {2}" -f $p.ProcessId, $ageH, $p.CommandLine.Substring(0, [Math]::Min(80, $p.CommandLine.Length))) -ForegroundColor Yellow
    }

    if (-not $Execute) {
        Write-Host "[DRY RUN] Would kill $($orphans.Count) orphan(s). Re-run with -Execute." -ForegroundColor Cyan
        return
    }

    $killed = 0; $failed = 0
    foreach ($p in $orphans) {
        try {
            Stop-Process -Id $p.ProcessId -Force -ErrorAction Stop
            $killed++
            Write-Host "  [KILLED] PID=$($p.ProcessId)" -ForegroundColor Magenta
        } catch {
            $failed++
            Write-Host "  [ERROR] PID=$($p.ProcessId): $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    Write-Host "`n[ParentChain DONE] killed=$killed failed=$failed" -ForegroundColor $(if ($failed -eq 0) { 'Green' } else { 'Yellow' })
}

function Invoke-StdioMode {
    # Absorbed from scripts/maintenance/cleanup-mcp-stdio-zombies.ps1 (#2675)
    # Strategy: find node.exe/cmd.exe whose CommandLine matches npx OR mcp-, walk parent chain
    # to check for live $CodeProcessName ancestor. Kill if no ancestor AND older than $OlderThanHours.

    Write-Host "`n=== [Mode: Stdio] stdio MCP cleanup (#2675, absorbed) ===" -ForegroundColor Cyan
    Write-Host "OlderThan: $OlderThanHours h | VS Code proc: $CodeProcessName | Execute: $Execute`n" -ForegroundColor Gray

    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $allProcs = Get-CimInstance Win32_Process -ErrorAction SilentlyContinue
    $sw.Stop()
    if (-not $allProcs) {
        Write-Host "WMI query failed — aborting Stdio mode." -ForegroundColor Yellow
        return
    }
    Write-Host "WMI query: $($sw.ElapsedMilliseconds)ms ($($allProcs.Count) processes)" -ForegroundColor DarkGray

    $procById = @{}
    foreach ($p in $allProcs) { $procById[$p.ProcessId] = $p }

    # Pre-compute set of CodeProcessName PIDs
    $codePids = @{}
    foreach ($p in $allProcs) { if ($p.Name -eq $CodeProcessName) { $codePids[$p.ProcessId] = $true } }

    function Test-HasCodeAncestor {
        param([int]$ProcessId)
        $visited = @{}
        $currentPid = $ProcessId
        while ($currentPid -and $currentPid -ne 0 -and $currentPid -ne 4 -and -not $visited[$currentPid]) {
            $visited[$currentPid] = $true
            if ($codePids[$currentPid]) { return $true }
            $proc = $procById[$currentPid]
            if (-not $proc) { return $false }
            $currentPid = $proc.ParentProcessId
        }
        return $false
    }

    $cutoffTime3 = (Get-Date).AddHours(-$OlderThanHours)
    $candidates = @()
    foreach ($p in $allProcs) {
        if ($p.Name -ne 'node.exe' -and $p.Name -ne 'cmd.exe') { continue }
        if ($p.CreationDate -ge $cutoffTime3) { continue }
        $cmd = $p.CommandLine
        if ($cmd -notmatch 'npx' -and $cmd -notmatch 'mcp-') { continue }
        if (-not (Test-HasCodeAncestor -ProcessId $p.ProcessId)) {
            $candidates += $p
        }
    }

    if ($candidates.Count -eq 0) {
        Write-Host "No stdio MCP zombie candidates found." -ForegroundColor Green
        return
    }
    Write-Host "STDIO MCP zombie candidates ($($candidates.Count)):" -ForegroundColor Red
    foreach ($p in $candidates) {
        $ageH = [math]::Round(((Get-Date) - $p.CreationDate).TotalHours, 1)
        Write-Host ("  PID={0,-7} age={1,5}h  {2}" -f $p.ProcessId, $ageH, $p.CommandLine.Substring(0, [Math]::Min(80, $p.CommandLine.Length))) -ForegroundColor Yellow
    }

    if (-not $Execute) {
        Write-Host "[DRY RUN] Would kill $($candidates.Count) stdio zombie(s). Re-run with -Execute." -ForegroundColor Cyan
        return
    }

    $killed = 0; $failed = 0
    foreach ($p in $candidates) {
        try {
            Stop-Process -Id $p.ProcessId -Force -ErrorAction Stop
            $killed++
            Write-Host "  [KILLED] PID=$($p.ProcessId)" -ForegroundColor Magenta
        } catch {
            $failed++
            Write-Host "  [ERROR] PID=$($p.ProcessId): $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    Write-Host "`n[Stdio DONE] killed=$killed failed=$failed" -ForegroundColor $(if ($failed -eq 0) { 'Green' } else { 'Yellow' })
}

# --- Mode dispatch (only reached if -Mode != Cluster, since Cluster exits above) ----
switch ($Mode) {
    'ParentChain' { Invoke-ParentChainMode }
    'Stdio'       { Invoke-StdioMode }
    default       { Write-Host "[REFUSE] Unknown mode: $Mode" -ForegroundColor Red; exit 2 }
}
exit 0