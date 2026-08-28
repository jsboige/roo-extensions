#requires -Version 5.1
<#
.SYNOPSIS
  Append-only off-site archiving of Claude Code conversation transcripts.

.DESCRIPTION
  Claude Code stores every session as a JSONL transcript under
  ~/.claude/projects/<project>/<sessionId>.jsonl. These are the only complete
  record of what the fleet agents actually did: the RooSync task-archive on
  GDrive covers Roo tasks ONLY (measured 2026-08-28: 7648 archives, 100%
  source=roo, zero Claude Code), and the Qdrant semantic index holds chunks,
  not originals.

  Worse, Claude Code prunes those transcripts on its own: absent an explicit
  cleanupPeriodDays in ~/.claude/settings.json it deletes anything older than
  30 days, at every session start, silently. On myia-ai-01 that had emptied 387
  of 484 project directories before anyone noticed.

  This script does two things, in this order:

    1. SELF-HEALS the retention setting (the guard that was missing), so the
       deletion cannot resume behind our back.
    2. Archives every new-or-changed transcript into a run-stamped .7z, verifies
       it with "7z t", copies it to Google Drive, and records a manifest that
       makes fleet coverage checkable at a glance.

  Modelled on the claudish scripts/compress-captures.ps1 job, with one
  deliberate inversion: compress-captures DELETES the loose originals once
  archived, because captures are disposable. Transcripts are not. This script
  NEVER deletes, moves or rewrites anything under the projects directory.
  Archives accumulate; later runs win on extraction order.

.PARAMETER ProjectsDir
  Root holding the per-project transcript directories.

.PARAMETER ArchiveDir
  Local archive destination. Default: <ProjectsDir>\..\transcript-archive.

.PARAMETER GDriveDir
  Off-site destination on the mounted Google Drive. Empty = local only.

.PARAMETER SevenZip
  Path to 7z.exe. Auto-detected from PATH and the usual install locations.

.PARAMETER MinRetentionDays
  Floor enforced on cleanupPeriodDays. Below it (or absent), the setting is
  rewritten to 36500 and the event is logged as a repair.

.PARAMETER SkipRetentionGuard
  Do not touch settings.json. For dry inspection only; leaves the leak open.

.NOTES
  Schedule it the way the claudish compaction job is scheduled (interactive
  user, StartWhenAvailable so a missed run catches up), at 04:41 - offset from
  the claudish 04:17 slot so the two jobs do not contend for the same GDrive
  upload window. See docs/harness/reference/claude-transcript-archiving.md for
  the exact Register-ScheduledTask block and the fleet rollout.
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
  [string]$ProjectsDir      = (Join-Path $env:USERPROFILE ".claude\projects"),
  [string]$ArchiveDir       = "",
  [string]$GDriveDir        = "G:\Mon Drive\Backups-Cloud\claude-transcripts",
  [string]$SevenZip         = "",
  [int]   $MinRetentionDays = 3650,
  [switch]$SkipRetentionGuard
)

$ErrorActionPreference = "Stop"
$machine = $env:COMPUTERNAME.ToLower()
if (-not $ArchiveDir) { $ArchiveDir = Join-Path (Split-Path $ProjectsDir -Parent) "transcript-archive" }
$stateFile = Join-Path $ArchiveDir "state.json"
$logFile   = Join-Path $ArchiveDir "archive.log"

function Log([string]$msg) {
  $line = "{0:yyyy-MM-ddTHH:mm:ssZ} {1}" -f (Get-Date).ToUniversalTime(), $msg
  Write-Host $line
  try { Add-Content -LiteralPath $logFile -Value $line -Encoding utf8 } catch {}
}

function Resolve-SevenZip([string]$hint) {
  if ($hint -and (Test-Path -LiteralPath $hint)) { return $hint }
  $cmd = Get-Command 7z.exe -ErrorAction SilentlyContinue
  if ($cmd) { return $cmd.Source }
  $cands = @(
    "D:\Apps\PortableApps\7-ZipPortable\App\7-Zip64\7z.exe",
    (Join-Path $env:ProgramFiles "7-Zip\7z.exe"),
    (Join-Path ${env:ProgramFiles(x86)} "7-Zip\7z.exe"))
  foreach ($c in $cands) { if ($c -and (Test-Path -LiteralPath $c)) { return $c } }
  return $null
}

# --- 0. preconditions --------------------------------------------------------
if (-not (Test-Path -LiteralPath $ProjectsDir)) { Write-Host "FATAL: projects dir not found: $ProjectsDir"; exit 2 }
if (-not (Test-Path -LiteralPath $ArchiveDir))  { New-Item -ItemType Directory -Path $ArchiveDir -Force | Out-Null }
$SevenZip = Resolve-SevenZip $SevenZip
if (-not $SevenZip) { Log "FATAL: 7z.exe not found (PATH, D:\Apps\PortableApps, Program Files)"; exit 2 }
Log "START machine=$machine projects=$ProjectsDir archive=$ArchiveDir 7z=$SevenZip"

# --- 1. retention guard: the leak this whole script exists because of --------
$retentionState = "skipped"
if (-not $SkipRetentionGuard) {
  $settingsPath = Join-Path $env:USERPROFILE ".claude\settings.json"
  if (-not (Test-Path -LiteralPath $settingsPath)) {
    Log "WARN retention: $settingsPath absent - Claude Code will prune at its 30-day default"
    $retentionState = "settings-missing"
  } else {
    try {
      $json = Get-Content -LiteralPath $settingsPath -Raw -Encoding UTF8 | ConvertFrom-Json
      $cur  = $json.PSObject.Properties["cleanupPeriodDays"]
      $val  = if ($cur) { [int]$cur.Value } else { -1 }
      if ($val -lt $MinRetentionDays) {
        $shown = if ($val -lt 0) { "<absent>" } else { "$val" }
        if ($PSCmdlet.ShouldProcess($settingsPath, "set cleanupPeriodDays $shown -> 36500")) {
          Copy-Item $settingsPath "$settingsPath.bak-retention-$(Get-Date -Format yyyyMMdd-HHmmss)" -Force
          if ($cur) { $json.cleanupPeriodDays = 36500 }
          else { $json | Add-Member -NotePropertyName cleanupPeriodDays -NotePropertyValue 36500 }
          [System.IO.File]::WriteAllText($settingsPath, ($json | ConvertTo-Json -Depth 100), (New-Object System.Text.UTF8Encoding($false)))
          Log "REPAIR retention: cleanupPeriodDays $shown -> 36500 (transcripts were being deleted)"
          $retentionState = "repaired-from-$shown"
        }
      } else {
        $retentionState = "ok-$val"
      }
    } catch { Log "WARN retention: could not read/patch settings.json - $($_.Exception.Message)"; $retentionState = "error" }
  }
}

# --- 2. what changed since the last run --------------------------------------
$state = @{}
if (Test-Path -LiteralPath $stateFile) {
  try {
    (Get-Content -LiteralPath $stateFile -Raw | ConvertFrom-Json).PSObject.Properties |
      ForEach-Object { $state[$_.Name] = $_.Value }
  } catch { Log "WARN state.json unreadable, treating as first run" }
}

$all = @(Get-ChildItem -LiteralPath $ProjectsDir -Recurse -Filter *.jsonl -File -ErrorAction SilentlyContinue)
if ($all.Count -eq 0) { Log "nothing to do (0 transcripts)"; Log "END"; exit 0 }

$base    = (Resolve-Path -LiteralPath $ProjectsDir).Path.TrimEnd("\") + "\"
$changed = New-Object System.Collections.ArrayList
foreach ($f in $all) {
  $rel = $f.FullName.Substring($base.Length)
  $sig = "{0}:{1}" -f $f.Length, $f.LastWriteTimeUtc.Ticks
  if ($state[$rel] -ne $sig) { [void]$changed.Add([pscustomobject]@{ Rel = $rel; Sig = $sig; Len = $f.Length }) }
}

$sorted     = $all | Sort-Object LastWriteTimeUtc
$oldest     = $sorted[0].LastWriteTimeUtc
$newest     = $sorted[-1].LastWriteTimeUtc
$totalBytes = ($all | Measure-Object -Property Length -Sum).Sum
Log ("tracked={0} changed={1} oldest={2:yyyy-MM-dd} newest={3:yyyy-MM-dd} local={4:N1} MB retention={5}" -f `
      $all.Count, $changed.Count, $oldest, $newest, ($totalBytes / 1MB), $retentionState)

# --- 3. archive the delta, verify, ship --------------------------------------
$stamp       = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHHmmssZ")
$archiveName = "transcripts-$machine-$stamp.7z"
$archivePath = Join-Path $ArchiveDir $archiveName
$shipped     = $false

if ($changed.Count -gt 0) {
  if ($PSCmdlet.ShouldProcess("$($changed.Count) transcripts", "7z -> $archiveName then copy to GDrive")) {
    $listFile = Join-Path $env:TEMP ("claude-transcripts-$stamp-{0}.lst" -f $PID)
    [System.IO.File]::WriteAllLines($listFile, ($changed | ForEach-Object { $_.Rel }), (New-Object System.Text.UTF8Encoding($false)))
    Push-Location -LiteralPath $ProjectsDir
    try {
      # LZMA2, large dictionary. Transcripts repeat their system prompts and
      # conversation prefixes across thousands of sessions, so -md=128m pays
      # for itself several times over while staying memory-safe (~1.5 GB) for
      # an unattended job.
      # NB: no "--" here. 7-Zip treats "--" as end-of-switches for @listfile
      # too, which would make it read the list as a literal filename - the
      # exact failure this script hit on its first run.
      & $SevenZip a -t7z -m0=lzma2 -mx=9 -md=128m -mfb=273 -mmt=on -bso0 -bsp0 "$archivePath" "@$listFile" | Out-Null
      $addRc = $LASTEXITCODE
      & $SevenZip t -bso0 -bsp0 "$archivePath" | Out-Null
      $testRc = $LASTEXITCODE
    } finally {
      Pop-Location
      Remove-Item -LiteralPath $listFile -Force -ErrorAction SilentlyContinue
    }

    if ($addRc -ne 0 -or $testRc -ne 0 -or -not (Test-Path -LiteralPath $archivePath)) {
      Log "FATAL 7z failed (add=$addRc verify=$testRc) - partial archive discarded, state NOT advanced, nothing lost"
      Remove-Item -LiteralPath $archivePath -Force -ErrorAction SilentlyContinue
      exit 3
    }
    $aLen = (Get-Item -LiteralPath $archivePath).Length
    Log ("archived {0} transcripts -> {1} ({2:N1} MB, verified)" -f $changed.Count, $archiveName, ($aLen / 1MB))

    if ($GDriveDir) {
      try {
        $dst = Join-Path $GDriveDir $machine
        if (-not (Test-Path -LiteralPath $dst)) { New-Item -ItemType Directory -Path $dst -Force | Out-Null }
        $remote = Join-Path $dst $archiveName
        Copy-Item -LiteralPath $archivePath -Destination $remote -Force
        $rLen = (Get-Item -LiteralPath $remote).Length
        if ($rLen -ne $aLen) { Log "WARN GDrive copy size mismatch ($rLen != $aLen) - kept local, will retry next run" }
        else { $shipped = $true; Log "shipped -> $remote" }
      } catch { Log "WARN GDrive copy failed: $($_.Exception.Message) - archive kept locally" }
    }

    # Advance state only once the archive is verified. If the GDrive copy failed
    # the local archive still holds the delta and the manifest says shippedOffsite=false.
    foreach ($c in $changed) { $state[$c.Rel] = $c.Sig }
    [System.IO.File]::WriteAllText($stateFile, ($state | ConvertTo-Json -Depth 4), (New-Object System.Text.UTF8Encoding($false)))
  }
} else {
  Log "no change since last run - no archive produced"
}

# --- 4. manifest: what makes coverage checkable instead of assumed -----------
$manifest = [ordered]@{
  machine            = $machine
  generatedAt        = (Get-Date).ToUniversalTime().ToString("o")
  retention          = $retentionState
  transcriptsTracked = $all.Count
  archivedThisRun    = $changed.Count
  oldestTranscript   = $oldest.ToString("yyyy-MM-dd")
  newestTranscript   = $newest.ToString("yyyy-MM-dd")
  localBytes         = $totalBytes
  lastArchive        = $(if ($changed.Count -gt 0) { $archiveName } else { $null })
  shippedOffsite     = $shipped
}
$mJson = $manifest | ConvertTo-Json -Depth 4
[System.IO.File]::WriteAllText((Join-Path $ArchiveDir "manifest.json"), $mJson, (New-Object System.Text.UTF8Encoding($false)))
if ($GDriveDir) {
  try {
    $dst = Join-Path $GDriveDir $machine
    if (-not (Test-Path -LiteralPath $dst)) { New-Item -ItemType Directory -Path $dst -Force | Out-Null }
    [System.IO.File]::WriteAllText((Join-Path $dst "manifest.json"), $mJson, (New-Object System.Text.UTF8Encoding($false)))
  } catch { Log "WARN manifest not shipped: $($_.Exception.Message)" }
}

Log "END"
