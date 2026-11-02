# scan-known-names.ps1 — #4434 (c) : inventorier les dashboards DriveFS par
# NOMS CONNUS, jamais par enumeration.
#
# Pourquoi : sur les sieges ou DriveFS timeout (gel d'enumeration mesure
# plusieurs fois >25 min), un Get-Item sur un nom connu rend en <1 s. La liste
# des noms legaux vient du miroir PG (roosync_dashboard action:"list" rend
# .dashboards[].key + .lastModified), pas du repertoire.
#
# Usage :
#   1. Sauver la liste : roosync_dashboard(action:"list") -> .dashboards[]
#      vers keys.json : [{"key":"workspace-X","lm":"2026-..Z"}, ...]
#   2. powershell -ExecutionPolicy Bypass -File scan-known-names.ps1
#        -KeysFile keys.json [-ForkDepth 5] [-HotDays 10] [-BudgetSec 240]
#
# Bornes : aucun Get-ChildItem ; budget total arrete le scan (resultat partiel
# rendu) ; une sonde lente n'interrompt pas les suivantes mais consomme le
# budget. Les fourches DriveFS " (N).md" sont sondees pour les cles fraiches
# (< HotDays) uniquement.
param(
  [string]$SharedPath = "G:/Mon Drive/Synchronisation/RooSync/.shared-state",
  [string]$KeysFile = "keys.json",
  [int]$ForkDepth = 5,
  [int]$HotDays = 10,
  [int]$BudgetSec = 240
)

$ErrorActionPreference = 'SilentlyContinue'
$dashDir = Join-Path $SharedPath 'dashboards'
$keys = Get-Content $KeysFile -Raw -Encoding UTF8 | ConvertFrom-Json
$sw = [Diagnostics.Stopwatch]::StartNew()
$cutoff = ([DateTimeOffset]::UtcNow).AddDays(-$HotDays)

$rows = New-Object System.Collections.Generic.List[object]
$probes = 0; $found = 0; $missing = 0; $slow = 0; $forks = 0

function Probe([string]$name) {
  # rend $null (absent/sonde) ou un objet {path,size,mtime,ms}
  $script:probes++
  $t = [Diagnostics.Stopwatch]::StartNew()
  $item = Get-Item -LiteralPath $name -Force
  $t.Stop()
  if ($t.ElapsedMilliseconds -gt 3000) { $script:slow++ }
  if ($null -eq $item) { return $null }
  [pscustomobject]@{
    path = $name; size = $item.Length
    mtime = $item.LastWriteTimeUtc.ToString('yyyy-MM-ddTHH:mm:ssZ')
    ms = $t.ElapsedMilliseconds
  }
}

foreach ($k in $keys) {
  if ($sw.Elapsed.TotalSeconds -gt $BudgetSec) {
    Write-Output "BUDGET_STOP apres $($rows.Count) lignes ($([int]$sw.Elapsed.TotalSeconds)s)"
    break
  }
  $base = Probe (Join-Path $dashDir ($k.key + '.md'))
  if ($base) {
    $found++
    $rows.Add([pscustomobject]@{ key = $k.key; fork = ''; size = $base.size; mtime = $base.mtime; probe_ms = $base.ms })
  } else {
    $missing++
    $rows.Add([pscustomobject]@{ key = $k.key; fork = ''; size = $null; mtime = 'ABSENT'; probe_ms = $null })
  }
  # fourches : seulement pour les cles fraiches (collisions recentes possibles)
  $lm = $null
  if ($k.lm) { $lm = [DateTimeOffset]::Parse($k.lm) }
  if ($lm -and $lm -ge $cutoff) {
    for ($n = 1; $n -le $ForkDepth; $n++) {
      if ($sw.Elapsed.TotalSeconds -gt $BudgetSec) { break }
      $f = Probe (Join-Path $dashDir ($k.key + " ($n).md"))
      if ($f) {
        $forks++
        $rows.Add([pscustomobject]@{ key = $k.key; fork = "($n)"; size = $f.size; mtime = $f.mtime; probe_ms = $f.ms })
      }
    }
  }
}

$summary = [pscustomobject]@{
  dir = $dashDir
  keys_input = $keys.Count
  probes = $probes
  found = $found
  missing = $missing
  forks_found = $forks
  slow_probes_gt3s = $slow
  elapsed_s = [int]$sw.Elapsed.TotalSeconds
}
Write-Output ("SUMMARY " + ($summary | ConvertTo-Json -Compress))
$rows | Format-Table -AutoSize | Out-String -Width 200
