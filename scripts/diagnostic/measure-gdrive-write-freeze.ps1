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

Writes nothing. Exit 0 = FROZEN (criterion met), 1 = ACTIVE (criterion not met),
2 = instrument error (shared path unreadable, or no family found).

.EXAMPLE
powershell -ExecutionPolicy Bypass -File scripts\diagnostic\measure-gdrive-write-freeze.ps1

.EXAMPLE
powershell -ExecutionPolicy Bypass -File scripts\diagnostic\measure-gdrive-write-freeze.ps1 -SharedPath 'G:\Mon Drive\Synchronisation\RooSync\.shared-state' -FreezeHours 24
#>
[CmdletBinding()]
param(
    [string]$SharedPath,
    [double]$FreezeHours = 24
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
$families = @('inventories', 'messages', '.machine-registry')

$rows = @()
foreach ($family in $families) {
    $entries = @(Get-ChildItem -LiteralPath $SharedPath -Filter ($family + '*') -Force -ErrorAction SilentlyContinue)
    foreach ($entry in $entries) {
        $isDir = [bool]$entry.PSIsContainer
        if ($isDir) {
            $kind = 'DIR'
            $files = @(Get-ChildItem -LiteralPath $entry.FullName -Recurse -File -Force -ErrorAction SilentlyContinue)
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
        $ageH = [math]::Round(($now - $mtime).TotalHours, 1)
        $verdict = 'ACTIVE'
        if ($ageH -ge $FreezeHours) { $verdict = 'FROZEN' }

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

if ($rows.Count -eq 0) {
    Write-Output "[INSTRUMENT] no inventories*/messages*/.machine-registry* under $SharedPath"
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

Write-Output ("[PHASE-D] MET -- all {0} family instance(s) frozen for at least {1} h" -f $rows.Count, $FreezeHours)
exit 0
