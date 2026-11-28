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

`desktop.ini` is not a data write: Explorer drops it (Hidden) when a folder view is
customised, so it is excluded from the three generic families -- by file NAME, never by
directory. Measured c.7126720160: four of them, identical fresh mtime, turned frozen
instances ACTIVE.

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

The head of each dashboard file is read through .NET (FileShare.ReadWrite), not through
Get-Content: on the DriveFS reader, a file held open for writing by a local writer fails
with ERROR_FILE_NOT_FOUND under the PowerShell provider while the .NET open succeeds
(measured 28/11 -- same file, same instant, 6 readings in a row). The verdict must not
depend on the reader's share mode.

A head that stays unreadable is NOT an instrument error: the file is counted UNKNOWN --
its justification is neither proved nor disproved, never counted as export-justified --
it is named in the output, and the family stays ACTIVE. A freeze criterion is not proved
on an incomplete measurement.

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

function Read-DashboardHead {
    # Lecture de tete par .NET, PAS par Get-Content : sur le lecteur DriveFS (G:),
    # un fichier tenu en ecriture par un ecrivain local s'ouvre par le fournisseur
    # PowerShell en FileShare.Read et echoue en ERROR_FILE_NOT_FOUND (DriveFS rend
    # ce code la ou Windows rendrait un conflit de partage), la ou un FileStream en
    # FileShare.ReadWrite reussit. Mesure 28/11 (ai-01, #4915) : meme fichier, meme
    # instant -- Get-Content FAIL et File.Open OK, 6 fois de suite. Un verdict
    # Phase D ne doit pas dependre du mode de partage du lecteur.
    # 3 tentatives : un fichier remplace entre l'enumeration et la lecture
    # (reecriture locale concurrente) disparait brievement.
    param([Parameter(Mandatory=$true)][string]$Path, [int]$Lines = 20)
    $last = $null
    for ($attempt = 1; $attempt -le 3; $attempt++) {
        try {
            $fs = [System.IO.File]::Open($Path, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
            try {
                $sr = New-Object System.IO.StreamReader($fs)
                try {
                    $out = New-Object System.Collections.Generic.List[string]
                    while ($out.Count -lt $Lines -and -not $sr.EndOfStream) { [void]$out.Add($sr.ReadLine()) }
                    return $out.ToArray()
                } finally { $sr.Dispose() }
            } finally { $fs.Dispose() }
        } catch {
            $last = $_
            if ($attempt -lt 3) { Start-Sleep -Milliseconds 200 }
        }
    }
    throw $last
}

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
            $unknown = @()
            $exportedRecent = 0
            $frozenFiles = 0
            foreach ($f in $mdFiles) {
                $ageF = ($now - $f.LastWriteTimeUtc).TotalHours
                if ($ageF -ge $FreezeHours) { $frozenFiles++; continue }
                $stampUtc = $null
                $headRead = $true
                try {
                    $head = (Read-DashboardHead -Path $f.FullName -Lines 20) -join "`n"
                    if ($head -match "(?m)^mirrorExportAt:\s*'?([^'\r\n]+)'?") {
                        $stampUtc = [DateTimeOffset]::Parse($Matches[1], [System.Globalization.CultureInfo]::InvariantCulture).UtcDateTime
                    }
                } catch {
                    # Tete illisible : le contenu n'est pas servi (DriveFS : contenu
                    # indisponible). Le verdict ne peut NI confirmer NI infirmer la
                    # justification de cette ecriture -- elle passe en INCONNUE,
                    # nommee, et n'est JAMAIS comptee comme export justifiee. Un
                    # critere de gel ne se prouve pas sur une mesure incomplete :
                    # la famille reste ACTIVE.
                    $headRead = $false
                }
                if (-not $headRead) {
                    $unknown += [pscustomobject]@{ Name = $f.Name; AgeH = [math]::Round($ageF, 1) }
                    continue
                }
                if ($null -ne $stampUtc) {
                    $gapMin = [math]::Abs(($f.LastWriteTimeUtc - $stampUtc).TotalMinutes)
                    if ($gapMin -le $ExportToleranceMinutes) { $exportedRecent++; continue }
                }
                $residual += [pscustomobject]@{ Name = $f.Name; AgeH = [math]::Round($ageF, 1) }
            }
            $unknownNames = (($unknown | ForEach-Object { $_.Name } | Sort-Object) -join ', ')
            if ($residual.Count -gt 0 -or $unknown.Count -gt 0) {
                $worst = (@($residual) + @($unknown)) | Sort-Object AgeH | Select-Object -First 1
                $named = @($residual | ForEach-Object { $_.Name } | Sort-Object)
                if ($unknown.Count -gt 0) {
                    $named += ("{0} head illisible ({1})" -f $unknown.Count, $unknownNames)
                }
                $names = ($named -join ', ')
                $rows += [pscustomobject]@{
                    Family      = 'dashboards'
                    Instance    = $entry.Name
                    Kind        = 'DIR'
                    Files       = $mdFiles.Count
                    NewestUtc   = $now.AddHours(-$worst.AgeH).ToString('yyyy-MM-dd HH:mm:ss')
                    AgeHours    = $worst.AgeH
                    Verdict     = 'ACTIVE'
                    NewestEntry = ('{0} (+ {1} export-justified, {2} older than {3} h)' -f $names, $exportedRecent, $frozenFiles, $FreezeHours)
                    Exported    = $exportedRecent
                    Unknown     = $unknown.Count
                    Residual    = $residual.Count
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
                    Exported    = $exportedRecent
                    Unknown     = $unknown.Count
                    Residual    = 0
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
            # `desktop.ini` (Explorer view settings, Hidden) is excluded by file NAME,
            # case-insensitive -- never by directory: a real hot file beside one still
            # decides (Pester case l). Measured false positive, c.7126720160.
            $files = @(Get-ChildItem -LiteralPath $entry.FullName -Recurse -File -Force -ErrorAction SilentlyContinue -ErrorVariable recErr |
                Where-Object { $_.Name -ine 'desktop.ini' })
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

# Le detail dashboards (export-aware) est imprime dans les DEUX branches : c'est
# lui qui porte le compte des ecritures justifiees par un tampon frais, et ce
# compte se lit aussi quand le verdict global reste NOT-MET.
$dashRows = @($rows | Where-Object { $_.Family -eq 'dashboards' })
if ($dashRows.Count -gt 0) {
    $dashExported = ($dashRows | Measure-Object -Property Exported -Sum).Sum
    $dashUnknown = ($dashRows | Measure-Object -Property Unknown -Sum).Sum
    $dashResidual = ($dashRows | Measure-Object -Property Residual -Sum).Sum
    if ($dashResidual -eq 0 -and $dashUnknown -eq 0) {
        Write-Output ("[PHASE-D] dashboards detail: export-aware -- every recent write carries a fresh mirrorExportAt stamp (tolerance {0} min). mtime only proves the LAST write per file: sample repeatedly to cover a window." -f $ExportToleranceMinutes)
    } else {
        Write-Output ("[PHASE-D] dashboards detail: export-aware -- {0} recent write(s) justified by a fresh mirrorExportAt stamp (tolerance {1} min), {2} residual (recent write without a fresh stamp), {3} head(s) unreadable (justification UNKNOWN, never counted as justified). mtime only proves the LAST write per file: sample repeatedly to cover a window." -f $dashExported, $ExportToleranceMinutes, $dashResidual, $dashUnknown)
    }
}

if ($active.Count -gt 0) {
    Write-Output ("[PHASE-D] NOT-MET -- {0}/{1} family instance(s) written within the last {2} h:" -f $active.Count, $rows.Count, $FreezeHours)
    foreach ($a in ($active | Sort-Object AgeHours)) {
        Write-Output ("  {0}\{1} <- {2} ({3} h ago)" -f $a.Family, $a.Instance, $a.NewestEntry, $a.AgeHours)
    }
    exit 1
}

Write-Output ("[PHASE-D] MET -- all {0} instance(s) across {1} frozen for at least {2} h" -f $rows.Count, ($seen -join ', '), $FreezeHours)
exit 0
