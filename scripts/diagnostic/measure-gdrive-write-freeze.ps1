<#
.SYNOPSIS
Phase D instrument: are the G: shared-state families still being written?

.DESCRIPTION
Read-only. For each family (`inventories*`, `messages*`, `.machine-registry*`) under the
RooSync shared state, reports the newest mtime and the age of that write, then decides
whether the Phase D criterion "no seat writes to G: any more" is met.

The criterion (proposed by myia-ai-01, #4131 c.6529950951) is: the mtimes of the three
families frozen for 24 h. Twins (`inventories (2)`, `messages (2)`,
`.machine-registry (1).json`) count as members of their own family, because a seat bound
to a twin keeps writing to G: just the same -- an instrument that watched only the
canonical name would report FROZEN while a twin was still hot.

#4131 G-MES -- family `dashboards`: EXPORT-AWARE criterion, not total freeze. Under
PG-first the dashboards dir stays ALIVE by design: the in-host reconcile daemon
(index.ts initializeDashboardReconcile; first pass 90 s after host start, then every
6 h) exports PG->file (repairDashboardMirrorFromPg, repair + materialization). Those
export writes are EXPECTED and must not count as residual writers. Ticks are per-host
(start times drift fleet-wide), so the hour alone can never recognize one: each export
stamps the frontmatter `mirrorExportAt` (the export hour), and this instrument justifies
a recent write ONLY by a fresh stamp (|mtime - stamp| <= -ExportToleranceMinutes).
A recent write without a fresh stamp = residual writer. Limit, stated honestly: mtime
only remembers the LAST write per file -- a residual write later overwritten by an
export is masked; the metric samples last-writer state, run it repeatedly to cover a
window. Top level only (*.md): the archive/ subdir (condensation archives, written on
their own cadence) and staging tmp files are excluded by construction.

Writes nothing. Exit 0 = FROZEN (criterion met), 1 = ACTIVE (criterion not met),
2 = instrument error (shared path unreadable, a family produced no instances,
or an enumeration errored).

.EXAMPLE
powershell -ExecutionPolicy Bypass -File scripts\diagnostic\measure-gdrive-write-freeze.ps1

.EXAMPLE
powershell -ExecutionPolicy Bypass -File scripts\diagnostic\measure-gdrive-write-freeze.ps1 -SharedPath 'G:\Mon Drive\Synchronisation\RooSync\.shared-state' -FreezeHours 24
#>
[CmdletBinding()]
param(
    [string]$SharedPath,
    [double]$FreezeHours = 24,
    # #4131 G-MES -- |mtime - mirrorExportAt| tolerance (minutes) for calling a
    # recent dashboards write an export. The stamp is written by the same
    # process that lands the file (ms apart); 10 min absorbs DriveFS skew.
    [double]$ExportToleranceMinutes = 10
)

$ErrorActionPreference = 'Stop'

if (-not $SharedPath) { $SharedPath = $env:ROOSYNC_SHARED_PATH }
if (-not $SharedPath) { $SharedPath = 'G:\Mon Drive\Synchronisation\RooSync\.shared-state' }
$SharedPath = $SharedPath.Replace('/', '\')

if (-not (Test-Path -LiteralPath $SharedPath)) {
    Write-Output "[INSTRUMENT] shared path unreadable: $SharedPath"
    exit 2
}

$now = (Get-Date).ToUniversalTime()
$families = @('inventories', 'messages', '.machine-registry', 'dashboards')

$rows = @()
foreach ($family in $families) {
    $famErr = $null
    $entries = @(Get-ChildItem -LiteralPath $SharedPath -Filter ($family + '*') -Force -ErrorAction SilentlyContinue -ErrorVariable famErr)
    if (@($famErr).Count -gt 0) {
        Write-Output ("[INSTRUMENT] enumeration of '{0}*' under {1} errored: {2}" -f $family, $SharedPath, $famErr[0].Exception.Message)
        exit 2
    }

    # ---- #4131 G-MES: dashboards = EXPORT-AWARE verdict, not total freeze ----
    # Export writes (daemon PG->file) are expected; a recent write counts as a
    # residual writer UNLESS the frontmatter carries a fresh mirrorExportAt
    # stamp (|mtime - stamp| <= $ExportToleranceMinutes). See .DESCRIPTION.
    if ($family -eq 'dashboards') {
        foreach ($entry in $entries) {
            if (-not $entry.PSIsContainer) {
                Write-Output ("[INSTRUMENT] dashboards instance '{0}' is a FILE, expected a directory" -f $entry.Name)
                exit 2
            }
            $dashErr = $null
            $mdFiles = @(Get-ChildItem -LiteralPath $entry.FullName -File -Filter '*.md' -Force -ErrorAction SilentlyContinue -ErrorVariable dashErr)
            if (@($dashErr).Count -gt 0) {
                Write-Output ("[INSTRUMENT] enumeration inside {0} errored: {1}" -f $entry.FullName, $dashErr[0].Exception.Message)
                exit 2
            }
            if ($mdFiles.Count -eq 0) {
                Write-Output ("[INSTRUMENT] dashboards instance '{0}' has zero .md files -- no verdict possible" -f $entry.Name)
                exit 2
            }
            $residual = @()
            $exportedRecent = 0
            $frozenFiles = 0
            foreach ($f in $mdFiles) {
                $ageF = ($now - $f.LastWriteTimeUtc).TotalHours
                if ($ageF -ge $FreezeHours) { $frozenFiles++; continue }
                $stampUtc = $null
                try {
                    $head = (Get-Content -LiteralPath $f.FullName -TotalCount 20 -ErrorAction Stop) -join "`n"
                    if ($head -match "(?m)^mirrorExportAt:\s*'?([^'\r\n]+)'?") {
                        $stampUtc = [DateTimeOffset]::Parse($Matches[1], [System.Globalization.CultureInfo]::InvariantCulture).UtcDateTime
                    }
                } catch {
                    Write-Output ("[INSTRUMENT] unreadable dashboard file {0}: {1}" -f $f.FullName, $_.Exception.Message)
                    exit 2
                }
                if ($null -ne $stampUtc) {
                    $gapMin = [math]::Abs(($f.LastWriteTimeUtc - $stampUtc).TotalMinutes)
                    if ($gapMin -le $ExportToleranceMinutes) { $exportedRecent++; continue }
                }
                $residual += [pscustomobject]@{ Name = $f.Name; AgeH = [math]::Round($ageF, 1) }
            }
            if ($residual.Count -gt 0) {
                $worst = $residual | Sort-Object AgeH | Select-Object -First 1
                $rows += [pscustomobject]@{
                    Family      = 'dashboards'
                    Instance    = $entry.Name
                    Kind        = 'DIR'
                    Files       = $mdFiles.Count
                    NewestUtc   = $now.AddHours(-$worst.AgeH).ToString('yyyy-MM-dd HH:mm:ss')
                    AgeHours    = $worst.AgeH
                    Verdict     = 'ACTIVE'
                    NewestEntry = ($residual | ForEach-Object { $_.Name } | Sort-Object) -join ', '
                }
            } else {
                $newestAll = $mdFiles | Sort-Object LastWriteTimeUtc -Descending | Select-Object -First 1
                $rows += [pscustomobject]@{
                    Family      = 'dashboards'
                    Instance    = $entry.Name
                    Kind        = 'DIR'
                    Files       = $mdFiles.Count
                    NewestUtc   = $newestAll.LastWriteTimeUtc.ToString('yyyy-MM-dd HH:mm:ss')
                    AgeHours    = [math]::Round(($now - $newestAll.LastWriteTimeUtc).TotalHours, 1)
                    Verdict     = 'FROZEN'
                    NewestEntry = ("export-aware: 0 residual ({0} export-justified, {1} older than {2} h)" -f $exportedRecent, $frozenFiles, $FreezeHours)
                }
            }
        }
        continue
    }

    foreach ($entry in $entries) {
        $isDir = [bool]$entry.PSIsContainer
        if ($isDir) {
            $kind = 'DIR'
            $recErr = $null
            $files = @(Get-ChildItem -LiteralPath $entry.FullName -Recurse -File -Force -ErrorAction SilentlyContinue -ErrorVariable recErr)
            if (@($recErr).Count -gt 0) {
                Write-Output ("[INSTRUMENT] enumeration inside {0} errored: {1}" -f $entry.FullName, $recErr[0].Exception.Message)
                exit 2
            }
            $count = $files.Count
            $newest = $files | Sort-Object LastWriteTimeUtc -Descending | Select-Object -First 1
            if ($newest) {
                $mtime = $newest.LastWriteTimeUtc
                $where = $newest.Name
            } else {
                $mtime = $entry.LastWriteTimeUtc
                $where = '(dir, no files)'
            }
        } else {
            $kind = 'FILE'
            $count = 1
            $mtime = $entry.LastWriteTimeUtc
            $where = $entry.Name
        }
        $ageRaw = ($now - $mtime).TotalHours
        $ageH = [math]::Round($ageRaw, 1)
        $verdict = 'ACTIVE'
        if ($ageRaw -ge $FreezeHours) { $verdict = 'FROZEN' }

        $rows += [pscustomobject]@{
            Family      = $family
            Instance    = $entry.Name
            Kind        = $kind
            Files       = $count
            NewestUtc   = $mtime.ToString('yyyy-MM-dd HH:mm:ss')
            AgeHours    = $ageH
            Verdict     = $verdict
            NewestEntry = $where
        }
    }
}

$seen = @($rows | ForEach-Object { $_.Family } | Select-Object -Unique)
$missing = @($families | Where-Object { $seen -notcontains $_ })
if ($missing.Count -gt 0) {
    Write-Output ("[INSTRUMENT] family(ies) with zero instances under {0}: {1}" -f $SharedPath, ($missing -join ', '))
    exit 2
}

Write-Output ("shared_path={0} freeze_hours={1} now_utc={2}" -f $SharedPath, $FreezeHours, $now.ToString('yyyy-MM-dd HH:mm:ss'))
$rows | Sort-Object Family, Instance | Format-Table -AutoSize | Out-String -Width 200

# Twin split: which machines each `inventories*` instance actually carries.
$invDirs = @($rows | Where-Object { $_.Family -eq 'inventories' -and $_.Kind -eq 'DIR' })
if ($invDirs.Count -gt 1) {
    Write-Output "[TWINS] inventories instances and the machines they carry:"
    foreach ($d in $invDirs) {
        $invFiles = @(Get-ChildItem -LiteralPath (Join-Path $SharedPath $d.Instance) -File -Force -ErrorAction SilentlyContinue | Sort-Object Name)
        $names = ($invFiles | ForEach-Object { $_.BaseName }) -join ', '
        Write-Output ("  {0} : {1}" -f $d.Instance, $names)
    }
}

$active = @($rows | Where-Object { $_.Verdict -eq 'ACTIVE' })
if ($active.Count -gt 0) {
    Write-Output ("[PHASE-D] NOT-MET -- {0}/{1} family instance(s) written within the last {2} h:" -f $active.Count, $rows.Count, $FreezeHours)
    foreach ($a in ($active | Sort-Object AgeHours)) {
        Write-Output ("  {0}\{1} <- {2} ({3} h ago)" -f $a.Family, $a.Instance, $a.NewestEntry, $a.AgeHours)
    }
    exit 1
}

Write-Output ("[PHASE-D] MET -- all {0} instance(s) across {1} frozen for at least {2} h" -f $rows.Count, ($seen -join ', '), $FreezeHours)
$dashMet = @($rows | Where-Object { $_.Family -eq 'dashboards' })
if ($dashMet.Count -gt 0) {
    Write-Output ("[PHASE-D] dashboards detail: export-aware -- every recent write carries a fresh mirrorExportAt stamp (tolerance {0} min). mtime only proves the LAST write per file: sample repeatedly to cover a window." -f $ExportToleranceMinutes)
}
exit 0
