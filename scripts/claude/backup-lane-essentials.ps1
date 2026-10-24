# backup-lane-essentials.ps1 - Lane disaster-recovery backup to GDrive (mandate 2026-10-23)
#
# Backs up "what matters" for the myia-po-2027:roo-extensions lane (NOT volume tars):
#   1. Lane memory dir  (~/.claude/projects/d--dev-roo-extensions/memory/) - lessons, registries
#   2. RSM server .env  - seat-rebuild secrets (user-mandated on shared Drive, 2026-10-23)
#   3. CLAUDE.local.md  - machine-local project notes, if present
#
# Output: timestamped zip + sha256 fingerprints, bounded rotation, fail-loud guards.
# Never prints file contents (secrets) - only names, sizes and hashes.
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File scripts\claude\backup-lane-essentials.ps1
#   powershell -ExecutionPolicy Bypass -File scripts\claude\backup-lane-essentials.ps1 -Keep 14 -WhatIf
#   Other lanes: override -TargetRoot/-MemoryDir/-RsmEnvFile/-LocalNotes/-LaneLabel/-ExtraPath
#     -LaneLabel 'CoursIA'        manifest trace label (default would mislabel a reusing lane)
#     -Exclude  @()               per-file name patterns skipped from the memory dir (default: *.bak-*
#                                 superseded local backups, measured 72% of web1's payload)
#     -ExtraPath @('D:\repo\.secrets\master.env')  extra files/dirs staged under extras\
#
# Manifests: one per archive (manifest-<stamp>.txt, paired) + latest-manifest.txt convenience copy.
# Rotation sorts by Name (UTC stamp in the name) - immune to Drive re-sync mtime drift.
#
# Exit codes: 0 = ok, 1 = source missing / empty archive guard / write failure.

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    # Lane root on the shared Drive (Hermes mandate 2026-10-23: <lane>-backups convention)
    [string]$TargetRoot = 'G:\Mon Drive\Synchronisation\RooSync\po2027-roo-extensions-backups',
    [int]$Keep = 14,
    # Sources (defaults = this seat's lane)
    [string]$MemoryDir = "$env:USERPROFILE\.claude\projects\d--dev-roo-extensions\memory",
    [string]$RsmEnvFile = 'D:\dev\roo-extensions\mcps\internal\servers\roo-state-manager\.env',
    [string]$LocalNotes = 'D:\dev\roo-extensions\CLAUDE.local.md',
    # Lane identity for the manifest (a reusing lane is NOT roo-extensions)
    [string]$LaneLabel = 'roo-extensions',
    # Name patterns skipped from the memory dir collection (superseded .bak-cNNN backups)
    [string[]]$Exclude = @('*.bak-*'),
    # Extra files or directories staged under extras\ (lane-specific gaps, e.g. .secrets/master.env)
    [string[]]$ExtraPath = @()
)

$ErrorActionPreference = 'Stop'
$stamp = (Get-Date).ToUniversalTime().ToString('yyyyMMdd-HHmmss')

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
