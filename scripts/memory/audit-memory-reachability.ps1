<#
.SYNOPSIS
    Audite l'atteignabilite du corpus memoire d'un agent depuis son index MEMORY.md.

.DESCRIPTION
    MEMORY.md est le SEUL fichier re-injecte au demarrage d'une session. Un fichier de
    memoire qu'aucune chaine de pointeurs ne relie a l'index n'est jamais relu : il
    existe sur le disque et n'existe pas pour l'agent.

    Cette sonde mesure l'atteignabilite TRANSITIVE : un fichier compte comme atteignable
    si l'index le cite, OU si un fichier deja atteignable le cite. Mesurer un seul saut
    sous-estime lourdement -- les archives (index-d-index) sont legitimement a profondeur 2+.

    ELLE NE SUPPRIME RIEN. Un fichier inatteignable n'est pas un fichier sans valeur :
    c'est un fichier a re-lier, ou a archiver deliberement sous un index d'archives.

.PARAMETER MemoryDir
    Repertoire memoire a auditer (celui qui contient MEMORY.md). Si omis, tous les
    repertoires ~/.claude/projects/*/memory/ contenant un MEMORY.md sont audites.

.PARAMETER ListUnreachable
    Liste les fichiers inatteignables (date de modification + nom), au lieu des seuls compteurs.

.PARAMETER FailUnder
    Code de sortie 1 si le pourcentage atteignable est strictement inferieur a ce seuil.
    Par defaut 0 (l'audit ne fait jamais echouer). Utiliser pour un garde-fou CI/cron.

.EXAMPLE
    pwsh -File scripts/memory/audit-memory-reachability.ps1
    pwsh -File scripts/memory/audit-memory-reachability.ps1 -ListUnreachable
    pwsh -File scripts/memory/audit-memory-reachability.ps1 -FailUnder 80

.NOTES
    Issue #3385. Sortie volontairement ASCII : les machines de la flotte n'ont pas toutes
    la meme page de code active (voir reference_ps51_scripts_depend_on_ai01_utf8_codepage).
#>
[CmdletBinding()]
param(
    [string] $MemoryDir,
    [switch] $ListUnreachable,
    [int]    $FailUnder = 0
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-MemoryDirs {
    param([string] $Explicit)
    if ($Explicit) {
        if (-not (Test-Path (Join-Path $Explicit 'MEMORY.md'))) {
            throw "Pas de MEMORY.md dans '$Explicit' -- ce n'est pas un repertoire memoire."
        }
        return @((Resolve-Path $Explicit).Path)
    }
    $root = Join-Path $HOME '.claude/projects'
    if (-not (Test-Path $root)) { return @() }
    Get-ChildItem -Path $root -Directory |
        ForEach-Object { Join-Path $_.FullName 'memory' } |
        Where-Object { Test-Path (Join-Path $_ 'MEMORY.md') }
}

function Invoke-ReachabilityAudit {
    param([string] $Dir)

    $indexPath = Join-Path $Dir 'MEMORY.md'
    $files = @(Get-ChildItem -Path $Dir -Filter '*.md' -File |
             Where-Object { $_.Name -ne 'MEMORY.md' })
    # Comparateur insensible a la casse : aligne $slugs sur les tables @{} ci-dessous (insensibles
    # par defaut en PowerShell) et sur NTFS, ou un lien differant seulement par la casse ouvre
    # bien le fichier. Sans cela un tel lien compte a la fois comme mort ET comme inatteignable.
    $slugs = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $mtime = @{}
    foreach ($f in $files) {
        $s = $f.BaseName
        [void]$slugs.Add($s)
        $mtime[$s] = $f.LastWriteTime
    }

    # DEUX conventions de lien coexistent sur la flotte, et une sonde qui n'en connait
    # qu'une rend 0 % sur les corpus de l'autre -- constate le 02/09 sur les index
    # Argumentum (131 liens markdown, 0 wikilink) et claudish (72 / 0).
    #   (a) wikilink   [[slug]]
    #   (b) markdown   [libelle](slug.md)  -- le chemin peut etre relatif
    $wikiRx = [regex]'\[\[([A-Za-z0-9_\-]+)\]\]'
    $mdRx   = [regex]'\]\(\s*(?:\./)?([A-Za-z0-9_\-]+)\.md(?:#[^)]*)?\s*\)'
    function Get-Links([string] $path) {
        if (-not (Test-Path $path)) { return @() }
        $txt = Get-Content -Path $path -Raw -Encoding UTF8
        if ([string]::IsNullOrEmpty($txt)) { return @() }
        @($wikiRx.Matches($txt) | ForEach-Object { $_.Groups[1].Value }) +
        @($mdRx.Matches($txt)   | ForEach-Object { $_.Groups[1].Value })
    }

    $rootLinks = @(Get-Links $indexPath | Sort-Object -Unique)
    $direct    = @($rootLinks | Where-Object { $slugs.Contains($_) })
    $dead      = @($rootLinks | Where-Object { -not $slugs.Contains($_) })

    # BFS transitive, en gardant la profondeur.
    $depth = @{}
    $queue = [System.Collections.Generic.Queue[string]]::new()
    foreach ($s in $direct) { if (-not $depth.ContainsKey($s)) { $depth[$s] = 1; $queue.Enqueue($s) } }
    while ($queue.Count -gt 0) {
        $cur = $queue.Dequeue()
        foreach ($n in (Get-Links (Join-Path $Dir "$cur.md"))) {
            if ($slugs.Contains($n) -and -not $depth.ContainsKey($n)) {
                $depth[$n] = $depth[$cur] + 1
                $queue.Enqueue($n)
            }
        }
    }

    $total   = $files.Count
    $reach   = $depth.Count
    $unreach = @($slugs | Where-Object { -not $depth.ContainsKey($_) } | Sort-Object)
    $pct     = if ($total -gt 0) { [math]::Round(100.0 * $reach / $total, 1) } else { 100.0 }

    Write-Host ''
    Write-Host "=== $Dir ==="
    Write-Host ("  fichiers (hors MEMORY.md) : {0}" -f $total)
    Write-Host ("  pointeurs directs         : {0}" -f $direct.Count)
    if ($dead.Count -gt 0) {
        Write-Host ("  POINTEURS MORTS           : {0} -> {1}" -f $dead.Count, ($dead -join ', ')) -ForegroundColor Yellow
    } else {
        Write-Host  "  pointeurs morts           : 0"
    }
    Write-Host ("  ATTEIGNABLES (transitif)  : {0} / {1}  ({2} %)" -f $reach, $total, $pct)

    $byDepth = $depth.Values | Group-Object | Sort-Object { [int]$_.Name }
    foreach ($g in $byDepth) { Write-Host ("     profondeur {0} : {1}" -f $g.Name, $g.Count) }

    # --- CONTROLE DE L'INSTRUMENT ---------------------------------------------
    # Si la regex ne mordait pas, TOUT paraitrait inatteignable et on "decouvrirait"
    # une catastrophe qui ne serait qu'une sonde cassee. Deux gardes :
    #   (a) l'index doit produire au moins un pointeur direct ;
    #   (b) au moins un fichier doit avoir ete atteint a profondeur >= 2, sinon on ne
    #       peut pas distinguer "corpus vraiment plat" de "traversee non exercee".
    if ($total -gt 0 -and $direct.Count -lt (0.05 * $total)) {
        Write-Host ("  INSTRUMENT SUSPECT : {0} pointeur(s) direct(s) pour {1} fichiers -- index a une autre convention, ou volontairement condense ?" -f $direct.Count, $total) -ForegroundColor Red
    }
    $maxDepth = 0
    if ($depth.Count -gt 0) { $maxDepth = ($depth.Values | Measure-Object -Maximum).Maximum }
    if ($maxDepth -le 1 -and $total -gt 0) {
        Write-Host "  TRAVERSEE NON EXERCEE : aucun fichier atteint au-dela du 1er saut. Le chiffre ci-dessus vaut alors un audit a UN saut, pas transitif." -ForegroundColor Yellow
    } else {
        Write-Host ("  controle traversee        : OK (profondeur max atteinte = {0})" -f $maxDepth)
    }
    # --------------------------------------------------------------------------

    Write-Host ("  INATTEIGNABLES            : {0}" -f $unreach.Count)
    if ($unreach.Count -gt 0) {
        # Decoupage sur - ET _ : le corpus est en kebab-case, un split sur le seul underscore
        # rendait un seau par fichier et ne pouvait donc repondre a "combien de feedback- ?".
        $byPrefix = $unreach | ForEach-Object { ($_ -split '[-_]')[0] } | Group-Object | Sort-Object Count -Descending
        Write-Host ("     par prefixe : {0}" -f (($byPrefix | ForEach-Object { "$($_.Name)=$($_.Count)" }) -join '  '))
        if ($ListUnreachable) {
            foreach ($u in $unreach) {
                Write-Host ("     {0:yyyy-MM-dd}  {1}" -f $mtime[$u], $u)
            }
        }
    }

    [pscustomobject]@{
        Dir = $Dir; Total = $total; Reachable = $reach; Percent = $pct
        Unreachable = $unreach.Count; DeadPointers = $dead.Count; MaxDepth = $maxDepth
    }
}

$dirs = @(Get-MemoryDirs -Explicit $MemoryDir)
if ($dirs.Count -eq 0) {
    Write-Host "Aucun repertoire memoire trouve (~/.claude/projects/*/memory/MEMORY.md)." -ForegroundColor Yellow
    exit 0
}

$results = @(foreach ($d in $dirs) { Invoke-ReachabilityAudit -Dir $d })

Write-Host ''
Write-Host '=== RESUME ==='
$results | Format-Table -AutoSize Dir, Total, Reachable, Percent, Unreachable, DeadPointers, MaxDepth

$worst = ($results | Measure-Object -Property Percent -Minimum).Minimum
if ($FailUnder -gt 0 -and $worst -lt $FailUnder) {
    $under = @($results | Where-Object { $_.Percent -lt $FailUnder } | Sort-Object Percent)
    Write-Host ("ECHEC : atteignabilite minimale {0} % < seuil {1} %." -f $worst, $FailUnder) -ForegroundColor Red
    foreach ($u in $under) {
        Write-Host ("   sous le seuil : {0} % -- {1}" -f $u.Percent, $u.Dir) -ForegroundColor Red
    }
    Write-Host "   Un index volontairement condense (peu de pointeurs, detail retrouve autrement) descend legitimement bas :" -ForegroundColor Yellow
    Write-Host "   verifier le motif avant de cabler ce seuil dans un cron." -ForegroundColor Yellow
    exit 1
}
exit 0
