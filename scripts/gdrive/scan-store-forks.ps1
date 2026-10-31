<#
.SYNOPSIS
    Inventaire des copies de conflit DriveFS dans le magasin partage RooSync (grain G2).

.DESCRIPTION
    DriveFS fork un fichier ou un repertoire quand deux clients ecrivent le meme
    chemin : le second ecrit `nom (1).ext` (fichier) ou `nom (1)` (repertoire).
    Un lecteur qui ne connait que le nom canonique voit alors ABSENT ce qui
    existe reellement ailleurs dans le store.

    Cette sonde est un INVENTAIRE, en LECTURE SEULE :
      - elle n'ecrit rien, ne deplace rien, ne supprime rien ;
      - elle ne fait aucun rename (le rename cote client ne propage pas le
        contenu et recree une cle canonique vide - mesure po-2023, 30/10) ;
      - elle ne lit pas le contenu des fichiers (seulement leur taille) ;
        l'empreinte SHA-256 est opt-in (-Hash), pour l'archivage prealable du
        proprietaire du montage.

    Sortie : un groupe par nom canonique, avec l'etat du canonique et la liste
    des jumeaux. Etats :
      canonical-absent  le canonique n'existe pas -> les lecteurs "canonique
                        seul" ne voient RIEN (cas du registre des machines)
      canonical-empty   le canonique existe mais est vide alors qu'un jumeau
                        porte le contenu
      content-split     canonique et jumeaux portent tous deux du contenu
                        (les deux moities du canal divergent)
      empty-both        canonique et jumeaux sont vides

    La convergence (archiver une reference + empreintes, puis retirer les
    jumeaux, UNE SEULE FOIS) appartient au proprietaire du montage DriveFS.

.PARAMETER SharedStatePath
    racine du magasin partage (.shared-state). Par defaut : detection G: puis D:.
.PARAMETER Depth
    profondeur maximale de parcours (defaut 4). Le store est sur un montage
    DriveFS : une enumeration profonde est lente.
.PARAMETER Hash
    calcule l'empreinte SHA-256 des jumeauxFICHIERS (opt-in : cout sur
    montage lent).
.PARAMETER Json
    sortie JSON (une seule ligne) au lieu du rapport lisible.
.PARAMETER IncludeArchive
    inclut le repertoire conflict-archive/ (par defaut il est ignore : il
    contient les copies deja archivees, pas des forks vivants). Le nom dit ce
    que le commutateur FAIT : la premiere version s'appelait -SkipArchive et
    l'activait, a rebours de son nom (review ai-01 sur #4441).

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File scripts\gdrive\scan-store-forks.ps1
.EXAMPLE
    powershell -ExecutionPolicy Bypass -File scripts\gdrive\scan-store-forks.ps1 -Json
#>
param(
    [string]$SharedStatePath,
    [int]$Depth = 4,
    [switch]$Hash,
    [switch]$Json,
    [switch]$IncludeArchive
)

$ErrorActionPreference = 'Stop'

# DriveFS numerote les copies de conflit : "nom (1).ext", "nom (2)".
# Seul un index EN CHIFFRES compte comme marqueur de conflit.
$ForkPattern = '^(?<base>.*?)(?:\s\((\d+)\))+$'

function Resolve-SharedStatePath {
    param([string]$Override)
    if ($Override) { return $Override }
    $candidates = @(
        'G:\Mon Drive\Synchronisation\RooSync\.shared-state',
        'D:\Mon Drive\Synchronisation\RooSync\.shared-state'
    )
    foreach ($p in $candidates) {
        if (Test-Path -LiteralPath $p) { return $p }
    }
    return $null
}

function Get-ForkMarker {
    <#
        Retourne $null si le nom n'est pas une copie de conflit, sinon un objet
        { Base, Ext, Index, Stem }.
    #>
    param([string]$Name)
    $ext = [System.IO.Path]::GetExtension($Name)
    $stem = if ($ext) { $Name.Substring(0, $Name.Length - $ext.Length) } else { $Name }
    if ($stem -notmatch $ForkPattern) { return $null }
    $base = $Matches['base']
    if (-not $base) { return $null }
    # .NET numerote les groupes NOMMES apres les groupes anonymes : le groupe
    # des chiffres est donc $Matches[1] (le groupe nomme 'base' est le 2).
    $index = [int]($Matches[1])
    return [pscustomobject]@{
        Base  = $base
        Ext   = $ext
        Index = $index
        Stem  = $stem
    }
}

function Get-EntrySummary {
    <#
        Resume un chemin : type, taille (fichier), nombre d'entrees directes
        (repertoire), date de modification. Aucune lecture de contenu.
    #>
    param([string]$Path)
    $item = Get-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue
    if (-not $item) { return $null }
    $summary = [ordered]@{
        path      = $Path
        type      = 'file'
        size      = 0
        entries   = 0
        modified  = $item.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss')
        sha256    = $null
    }
    if ($item.PSIsContainer) {
        $summary.type = 'dir'
        $children = @(Get-ChildItem -LiteralPath $Path -Force -ErrorAction SilentlyContinue)
        $summary.entries = $children.Count
        $newest = $null
        foreach ($c in $children) {
            if ($null -eq $newest -or $c.LastWriteTime -gt $newest) { $newest = $c.LastWriteTime }
        }
        if ($newest) { $summary.modified = $newest.ToString('yyyy-MM-dd HH:mm:ss') }
    }
    else {
        $summary.size = [int64]$item.Length
    }
    return [pscustomobject]$summary
}

function Get-ContentWeight {
    <#
        "Poids" de contenu d'un chemin : nombre d'entrees directes pour un
        repertoire, taille pour un fichier. Sert a comparer canonique/jumeau.
    #>
    param($Summary)
    if ($null -eq $Summary) { return -1 }
    if ($Summary.type -eq 'dir') { return [int64]$Summary.entries }
    return [int64]$Summary.size
}

$root = Resolve-SharedStatePath -Override $SharedStatePath
if (-not $root) {
    # Write-Error avec $ErrorActionPreference='Stop' leverait : le script
    # mourrait en erreur non geree (code 1) au lieu du code d'instrument 2.
    [Console]::Error.WriteLine("Cannot find the RooSync .shared-state directory. Pass -SharedStatePath explicitly.")
    exit 2
}
if (-not (Test-Path -LiteralPath $root)) {
    [Console]::Error.WriteLine("Shared-state path not found: $root")
    exit 2
}
$root = (Resolve-Path -LiteralPath $root).Path.TrimEnd('\')

# --- parcours : on collecte les NOMS, on ne touche à aucun contenu ---------
$forks = New-Object System.Collections.Generic.List[object]

function Scan-Directory {
    param([string]$Dir, [int]$Level)
    if ($Level -gt $Depth) { return }
    $children = @(Get-ChildItem -LiteralPath $Dir -Force -ErrorAction SilentlyContinue)
    foreach ($child in $children) {
        $marker = Get-ForkMarker -Name $child.Name
        if ($marker) {
            $forks.Add([pscustomobject]@{
                marker = $marker
                item   = $child
                dir    = $Dir
            })
        }
        if ($child.PSIsContainer) {
            if (-not $IncludeArchive -and $child.Name -eq 'conflict-archive') { continue }
            Scan-Directory -Dir $child.FullName -Level ($Level + 1)
        }
    }
}

Scan-Directory -Dir $root -Level 1

# --- regroupement par nom canonique -----------------------------------------
$groups = @{}
foreach ($f in $forks) {
    $canonicalName = $f.marker.Base + $f.marker.Ext
    $key = (Join-Path $f.dir $canonicalName).ToLowerInvariant()
    if (-not $groups.ContainsKey($key)) {
        $groups[$key] = [pscustomobject]@{
            canonicalPath = (Join-Path $f.dir $canonicalName)
            canonicalDir  = $f.dir
            canonicalName = $canonicalName
            twins         = New-Object System.Collections.Generic.List[object]
        }
    }
    $summary = Get-EntrySummary -Path $f.item.FullName
    if ($Hash -and $summary -and $summary.type -eq 'file') {
        try {
            $summary.sha256 = (Get-FileHash -LiteralPath $f.item.FullName -Algorithm SHA256).Hash
        }
        catch {
            $summary.sha256 = "ERREUR: $($_.Exception.Message)"
        }
    }
    $groups[$key].twins.Add([pscustomobject]@{
        index   = $f.marker.Index
        path    = $f.item.FullName
        name    = $f.item.Name
        summary = $summary
    })
}

# --- état de chaque groupe --------------------------------------------------
$report = New-Object System.Collections.Generic.List[object]
foreach ($g in $groups.Values) {
    $canonicalSummary = Get-EntrySummary -Path $g.canonicalPath
    $canonicalWeight = Get-ContentWeight -Summary $canonicalSummary
    $twinWeights = @($g.twins | ForEach-Object { Get-ContentWeight -Summary $_.summary })
    $maxTwin = if ($twinWeights.Count) { ($twinWeights | Measure-Object -Maximum).Maximum } else { 0 }

    $state =
        if ($null -eq $canonicalSummary) { 'canonical-absent' }
        elseif ($canonicalWeight -eq 0 -and $maxTwin -gt 0) { 'canonical-empty' }
        elseif ($canonicalWeight -gt 0 -and $maxTwin -gt 0) { 'content-split' }
        else { 'empty-both' }

    $report.Add([pscustomobject]@{
        canonical   = $g.canonicalPath
        canonicalRel = $g.canonicalPath.Substring($root.Length).TrimStart('\')
        state       = $state
        twinCount   = $g.twins.Count
        canonicalSummary = $canonicalSummary
        twins       = @($g.twins | Sort-Object index | ForEach-Object {
            [pscustomobject]@{
                index   = $_.index
                name    = $_.name
                rel     = $_.path.Substring($root.Length).TrimStart('\')
                type    = $_.summary.type
                size    = $_.summary.size
                entries = $_.summary.entries
                modified = $_.summary.modified
                sha256  = $_.summary.sha256
            }
        })
    })
}

$ordered = @($report | Sort-Object state, canonicalRel)

if ($Json) {
    $payload = [ordered]@{
        store        = $root
        depth        = $Depth
        scannedAt    = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ssK')
        groupCount   = $ordered.Count
        byState      = [ordered]@{
            'canonical-absent' = @($ordered | Where-Object { $_.state -eq 'canonical-absent' }).Count
            'canonical-empty'  = @($ordered | Where-Object { $_.state -eq 'canonical-empty' }).Count
            'content-split'    = @($ordered | Where-Object { $_.state -eq 'content-split' }).Count
            'empty-both'       = @($ordered | Where-Object { $_.state -eq 'empty-both' }).Count
        }
        groups       = $ordered
    }
    Write-Output ($payload | ConvertTo-Json -Depth 6 -Compress)
}
else {
    Write-Output "[STORE-FORKS] store : $root"
    Write-Output "[STORE-FORKS] profondeur $Depth - lecture seule (aucune ecriture, aucun rename, aucune suppression)"
    if ($ordered.Count -eq 0) {
        Write-Output "[STORE-FORKS] aucune copie de conflit detectee."
    }
    else {
        foreach ($g in $ordered) {
            Write-Output ""
            Write-Output ("[{0}] {1}" -f $g.state.ToUpperInvariant(), $g.canonicalRel)
            if ($g.canonicalSummary) {
                Write-Output ("    canonique : {0} type={1} taille={2} entrees={3} modifie={4}" -f `
                    $g.canonicalRel, $g.canonicalSummary.type, $g.canonicalSummary.size, $g.canonicalSummary.entries, $g.canonicalSummary.modified)
            }
            else {
                Write-Output "    canonique : ABSENT"
            }
            foreach ($t in $g.twins) {
                $line = "    jumeau ({0}) : {1} type={2} taille={3} entrees={4} modifie={5}" -f `
                    $t.index, $t.rel, $t.type, $t.size, $t.entries, $t.modified
                if ($t.sha256) { $line += " sha256=" + $t.sha256 }
                Write-Output $line
            }
        }
        Write-Output ""
        Write-Output ("[STORE-FORKS] {0} groupe(s) de copies de conflit." -f $ordered.Count)
        Write-Output "[STORE-FORKS] Convergence = archiver (reference + empreintes) puis retirer les jumeaux, UNE SEULE FOIS, par le proprietaire du montage DriveFS."
    }
}

if ($ordered.Count -gt 0) { exit 1 }
exit 0
