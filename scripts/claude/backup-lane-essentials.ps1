# backup-lane-essentials.ps1 - Lane disaster-recovery backup to GDrive (mandate 2026-10-23)
#
# Backs up "what matters" for ONE lane (NOT volume tars):
#   1. Lane memory dir  (~/.claude/projects/<workspace>/memory/) - lessons, registries
#   2. RSM server .env  - seat-rebuild secrets (user-mandated on shared Drive, 2026-10-23)
#   3. CLAUDE.local.md  - machine-local project notes, if present
#
# Every path default is DERIVED FROM THE SEAT at run time (repo root = this
# checkout, machine id = ROOSYNC_MACHINE_ID or COMPUTERNAME, lane root =
# $env:ROOSYNC_SHARED_PATH\lane-backups\<machine>-<lane>). The first version
# hardcoded po-2027's paths (D:\dev, G:\Mon Drive) and failed with
# "memory dir missing" on every other seat (measured on web2, 28/10).
# Nothing is guessed: an unresolvable path fails loud and names the override.
#
# The lane key <machine>-<checkout basename> is the repo's lane identity
# (#4114, one instance per lane per machine): two seats cannot collide. Two
# CHECKOUTS of the same workspace on one machine WOULD share daily/ and rotate
# each other's archives - deliberate (one lane per machine); separate them
# with -LaneLabel/-TargetRoot if a seat ever runs two. (ai-01 review #4415)
#
# Output: timestamped zip + sha256 fingerprints, bounded rotation, fail-loud guards.
# Never prints file contents (secrets) - only names, sizes and hashes.
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File scripts\claude\backup-lane-essentials.ps1
#   powershell -ExecutionPolicy Bypass -File scripts\claude\backup-lane-essentials.ps1 -Keep 14 -WhatIf
#   Overrides: -TargetRoot/-MachineId/-MemoryDir/-RsmEnvFile/-LocalNotes/-RepoRoot/-LaneLabel/-ExtraPath
#     -LaneLabel 'CoursIA'        manifest trace label (default = this checkout's basename)
#     -Exclude  @()               per-file name patterns skipped from the memory dir (default: *.bak-*
#                                 superseded local backups, measured 72% of web1's payload)
#     -ExtraPath @('D:\repo\.secrets\master.env')  extra files/dirs staged under extras\
#
# Manifests: one per archive (manifest-<stamp>.txt, paired) + latest-manifest.txt convenience copy.
# Rotation sorts by Name (UTC stamp in the name) - immune to Drive re-sync mtime drift.
#
# Exit codes: 0 = ok, 1 = source missing / unresolvable default / empty archive guard / write failure.

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    # Lane root on the shared Drive. Empty = resolved in the body from the seat.
    # Hermes mandate 2026-10-23: <lane>-backups convention under the shared state root.
    [string]$TargetRoot = '',
    [int]$Keep = 14,
    # Machine id used in the default lane root (same precedence as RSM's getLocalMachineId)
    [string]$MachineId = '',
    # Sources (empty = derived from this checkout in the body)
    [string]$MemoryDir = '',
    [string]$RsmEnvFile = '',
    [string]$LocalNotes = '',
    # Checkout whose lane this is (empty = two levels above this script)
    [string]$RepoRoot = '',
    # Lane identity for the manifest (default = this checkout's basename)
    [string]$LaneLabel = '',
    # Name patterns skipped from the memory dir collection (superseded .bak-cNNN backups)
    [string[]]$Exclude = @('*.bak-*'),
    # Extra files or directories staged under extras\ (lane-specific gaps, e.g. .secrets/master.env)
    [string[]]$ExtraPath = @()
)

$ErrorActionPreference = 'Stop'
$stamp = (Get-Date).ToUniversalTime().ToString('yyyyMMdd-HHmmss')

function Resolve-LaneMemoryDir([string]$RepoRoot) {
    # Claude Code names the per-workspace project dir after the workspace path
    # (C:\dev\roo-extensions -> c--dev-roo-extensions), but that naming is an
    # internal convention. Resolution order (ai-01 review of #4415, note 2):
    #   1. EXACT path-derived spelling first - when that form exists it IS this
    #      workspace's dir, so a same-leaf dir belonging to another checkout can
    #      never be picked silently over it;
    #   2. suffix DISCOVERY as fallback (a renamed project dir the naming
    #      convention missed must not silently miss);
    #   3. ambiguity is refused, never resolved by guess.
    $projects = Join-Path $env:USERPROFILE '.claude\projects'
    $leaf = Split-Path -Leaf $RepoRoot
    if (-not (Test-Path $projects)) { Write-Output "[FAIL] no projects dir: $projects"; exit 1 }
    $derived = $RepoRoot.ToLower() -replace '[^a-z0-9]', '-'
    $exactPath = Join-Path $projects $derived
    if ((Test-Path $exactPath) -and (Test-Path (Join-Path $exactPath 'memory'))) {
        return (Join-Path $exactPath 'memory')
    }
    $candidates = @(Get-ChildItem $projects -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -like "*$leaf" -and (Test-Path (Join-Path $_.FullName 'memory')) })
    if ($candidates.Count -eq 1) { return (Join-Path $candidates[0].FullName 'memory') }
    if ($candidates.Count -eq 0) {
        Write-Output "[FAIL] no memory dir found under $projects for lane '$leaf' - pass -MemoryDir"
        exit 1
    }
    Write-Output "[FAIL] ambiguous memory dir for lane '$leaf' - pass -MemoryDir. Candidates:"
    $candidates | ForEach-Object { Write-Output "       $($_.FullName)" }
    exit 1
}

# --- 0. Resolve defaults from THIS seat ---
# NB: resolved in the body, never in a param default -- $PSScriptRoot is empty
# during param binding under `powershell.exe -File` (PS 5.1, measured 28/10).
if (-not $RepoRoot) { $RepoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot) }
# A worktree is a place to work, not a lane (<main>\.claude\worktrees\wt-x).
# Resolved back to <main>, otherwise the lane label becomes the worktree name
# and the RSM .env path points into an unpopulated submodule.
if ($RepoRoot -match '[\\/]\.claude[\\/]worktrees[\\/][^\\/]+$') {
    $RepoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $RepoRoot))
}
if (-not $LaneLabel) { $LaneLabel = Split-Path -Leaf $RepoRoot }
if (-not $MachineId) {
    $MachineId = if ($env:ROOSYNC_MACHINE_ID) { $env:ROOSYNC_MACHINE_ID.ToLower() } else { $env:COMPUTERNAME.ToLower() }
}
if (-not $RsmEnvFile) { $RsmEnvFile = Join-Path $RepoRoot 'mcps\internal\servers\roo-state-manager\.env' }
if (-not $LocalNotes) { $LocalNotes = Join-Path $RepoRoot 'CLAUDE.local.md' }
if (-not $MemoryDir) { $MemoryDir = Resolve-LaneMemoryDir -RepoRoot $RepoRoot }
if (-not $TargetRoot) {
    if (-not $env:ROOSYNC_SHARED_PATH) {
        Write-Output '[FAIL] TargetRoot not resolvable on this seat: pass -TargetRoot,'
        Write-Output '       or set ROOSYNC_SHARED_PATH (the shared-state root). No drive letter is assumed.'
        exit 1
    }
    $TargetRoot = Join-Path $env:ROOSYNC_SHARED_PATH "lane-backups\$MachineId-$LaneLabel"
}

# --- 1. Collect sources, fail loud on the empty-archive trap (155-byte archives measured 2026-10-23) ---
if (-not (Test-Path $MemoryDir)) { Write-Error "memory dir missing: $MemoryDir" ; exit 1 }
if (-not (Test-Path $RsmEnvFile)) { Write-Error "RSM .env missing: $RsmEnvFile" ; exit 1 }

# WhatIf: enumerate sources read-only, then stop - no staging, no write.
if (-not $PSCmdlet.ShouldProcess($TargetRoot, 'write lane backup archive')) {
    $mem = Get-ChildItem $MemoryDir -Recurse -File | Where-Object {
        $keepFile = $true; foreach ($e in $Exclude) { if ($_.Name -like $e) { $keepFile = $false; break } }; $keepFile
    }
    $n = @($mem).Count + 1
    if (Test-Path $LocalNotes) { $n++ }
    $n += @($ExtraPath | Where-Object { Test-Path $_ }).Count
    Write-Output ("[WhatIf] would write {0}\daily\lane-essentials-{1}.zip from {2} files (memory + rsm .env{3}{4})" -f $TargetRoot, $stamp, $n, $(if (Test-Path $LocalNotes) { ' + local notes' }), $(if ($ExtraPath.Count) { ' + extras' }))
    exit 0
}

$stage = Join-Path $env:TEMP "lane-backup-$stamp"
if (Test-Path $stage) { Remove-Item $stage -Recurse -Force -Confirm:$false }
New-Item -ItemType Directory -Path $stage | Out-Null

# Memory dir, preserving relative layout, skipping $Exclude patterns (.bak-* = superseded local backups)
$memDest = Join-Path $stage 'memory'
New-Item -ItemType Directory -Path $memDest -Force | Out-Null
$memFiles = Get-ChildItem $MemoryDir -Recurse -File | Where-Object {
    $keepFile = $true; foreach ($e in $Exclude) { if ($_.Name -like $e) { $keepFile = $false; break } }; $keepFile
}
foreach ($mf in $memFiles) {
    $rel = $mf.FullName.Substring($MemoryDir.Length + 1)
    $dest = Join-Path $memDest $rel
    $destDir = Split-Path $dest -Parent
    if (-not (Test-Path $destDir)) { New-Item -ItemType Directory -Path $destDir -Force | Out-Null }
    Copy-Item -Path $mf.FullName -Destination $dest
}
Copy-Item -Path $RsmEnvFile -Destination (Join-Path $stage 'rsm-server.env')
if (Test-Path $LocalNotes) { Copy-Item -Path $LocalNotes -Destination (Join-Path $stage 'CLAUDE.local.md') }

# Lane-specific extras (files or whole dirs) under extras\<leaf> - fail loud if declared but missing
if ($ExtraPath.Count -gt 0) {
    $extrasDest = Join-Path $stage 'extras'
    New-Item -ItemType Directory -Path $extrasDest -Force | Out-Null
    foreach ($xp in $ExtraPath) {
        if (-not (Test-Path $xp)) { Write-Error "ExtraPath missing: $xp" ; exit 1 }
        Copy-Item -Path $xp -Destination (Join-Path $extrasDest (Split-Path $xp -Leaf)) -Recurse
    }
}

$files = Get-ChildItem $stage -Recurse -File
if ($files.Count -lt 3) { Write-Error "staged only $($files.Count) files - aborting (empty-archive guard)" ; exit 1 }

# --- 2. Zip + fingerprints ---
$dailyDir = Join-Path $TargetRoot 'daily'
if (-not (Test-Path $dailyDir)) { New-Item -ItemType Directory -Path $dailyDir -Force | Out-Null }
$zip = Join-Path $dailyDir "lane-essentials-$stamp.zip"

Compress-Archive -Path (Join-Path $stage '*') -DestinationPath $zip -Force

$zipItem = Get-Item $zip
if ($zipItem.Length -lt 1KB) {
    Write-Error "archive below 1KB ($($zipItem.Length) bytes) - removing, empty-archive guard"
    Remove-Item $zip -Force -Confirm:$false
    exit 1
}
$zipHash = (Get-FileHash $zip -Algorithm SHA256).Hash

# --- 3. Manifest (names + sizes + hashes only, never contents) ---
$manifest = @()
$manifest += "lane-essentials backup $stamp (UTC)"
$manifest += "machine: $env:COMPUTERNAME  lane: $LaneLabel"
$manifest += "archive: $(Split-Path $zip -Leaf)  bytes: $($zipItem.Length)  sha256: $zipHash"
$manifest += "sources:"
foreach ($f in $files) {
    $rel = $f.FullName.Substring($stage.Length + 1)
    $manifest += ("  {0}  {1}B  sha256:{2}" -f $rel, $f.Length, (Get-FileHash $f.FullName -Algorithm SHA256).Hash)
}
# One manifest per archive (paired stamp) so every kept archive stays verifiable,
# plus latest-manifest.txt as a convenience copy (web1 review 2026-10-24, nit 2).
$manifest | Set-Content -Path (Join-Path $dailyDir "manifest-$stamp.txt") -Encoding UTF8
$manifest | Set-Content -Path (Join-Path $dailyDir 'latest-manifest.txt') -Encoding UTF8

# --- 4. Bounded rotation (named files only, pattern-anchored, sorted by Name: UTC stamp,
#        immune to Drive re-sync mtime drift - web1 review 2026-10-24, nit 3) ---
$oldZips = Get-ChildItem $dailyDir -Filter 'lane-essentials-*.zip' |
    Sort-Object Name -Descending | Select-Object -Skip $Keep
foreach ($o in $oldZips) { Remove-Item $o.FullName -Force -Confirm:$false }
$oldManifests = Get-ChildItem $dailyDir -Filter 'manifest-*.txt' |
    Sort-Object Name -Descending | Select-Object -Skip $Keep
foreach ($o in $oldManifests) { Remove-Item $o.FullName -Force -Confirm:$false }

Remove-Item $stage -Recurse -Force -Confirm:$false

Write-Output ("[OK] lane-essentials backup written: {0}" -f $zip)
Write-Output ("     files={0}  bytes={1}  sha256={2}" -f $files.Count, $zipItem.Length, $zipHash)
Write-Output ("     manifest: manifest-$stamp.txt (+ latest-manifest.txt)")
Write-Output ("     rotation: keep {0}, pruned {1} zip(s) + {2} manifest(s)" -f $Keep, @($oldZips).Count, @($oldManifests).Count)
exit 0
