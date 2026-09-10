<#
.SYNOPSIS
    Setter additif et preservatif d'UNE SEULE variable dans un fichier .env (#3555).

.DESCRIPTION
    Upsert minimaliste d'une seule cle : ajoute la variable si absente, ou remplace
    exactement son assignation ACTIVE si presente. Toutes les autres lignes
    (commentaires, lignes vides, reglages machine, valeurs quotees, ordre) sont
    preservees octet-pour-octet, ainsi que le style de fin de ligne (CRLF/LF) de
    chaque ligne non modifiee.

    Pourquoi pas EnvRotationService : il fait un remplacement de fichier ENTIER et
    ne convient pas a une mise a jour additive d'une seule cle d'un .env qui porte
    aussi des reglages machine et des credentials (cf. rollout SKELETON_PREWARM
    post-#1128). Les scripts backup-mcp-env/restore-mcp-env restent les outils de
    sauvegarde/restauration COMPLETS du fichier ; le present script ne fait que
    l'upsert d'une cle, avec son propre backup preservatif prealable.

    Contrat volontairement etroit :
    - Windows PowerShell 5.1 compatible (syntaxe et encodage) ;
    - -WhatIf natif : sortie AVANT toute ecriture (ni backup, ni fichier) ;
    - backup byte-identique hors de tout depot Git avant mutation ;
    - idempotent : si la cle est deja a la valeur cible, aucun ecriture ;
    - UTF-8 sans BOM en sortie ;
    - la valeur n'est JAMAIS affichee, journalisee ou hashee ;
    - le rebuild/restart du service reste a la charge de l'operateur.

    Definition retenue d'une "assignation active" : une ligne correspondant a
    '^\\s*NAME\\s*=' (les lignes commentees '# NAME=...' ou ' # NAME=...' ne sont
    PAS actives et sont preservees telles quelles). En cas de remplacement, la
    ligne entiere est reecrite sous forme canonique 'NAME=value' : un commentaire
    en ligne (trailing '# ...' sur la meme ligne) ou un quote de l'ancienne valeur
    font partie de la ligne remplacee et disparaissent avec elle.

.PARAMETER TargetPath
    Chemin explicite du fichier .env cible. Doit exister et etre un fichier.

.PARAMETER Name
    Nom de la variable. Doit matcher '^[A-Za-z_][A-Za-z0-9_]*$'.

.PARAMETER Value
    Valeur a poser, ecrite telle quelle (verbatim, ni trim ni quote). Les
    caracteres CR/LF/NUL sont refuses (ils corrompraient la structure du fichier).

.PARAMETER BackupDir
    Repertoire du backup preservatif. Defaut : %USERPROFILE%\.roo-state-manager\
    env-var-backups (hors de tout depot Git). Le script REFUSE un backup dir qui
    se resolve a l'interieur d'un depot Git (garde .git par parcours des parents).

.EXAMPLE
    powershell -NoProfile -File scripts\mcp\set-mcp-env-var.ps1 `
        -TargetPath "mcps\internal\servers\roo-state-manager\.env" `
        -Name SKELETON_PREWARM -Value false

    Etape SKELETON_PREWARM=false (valeur publique, pas un secret). Le restart du
    service reste a l'operateur.

.NOTES
    Issue #3555. Fixtures de test : valeurs fictives uniquement.

    Codes de sortie :
      0  succes (y compris NO-CHANGE idempotent et dry-run -WhatIf)
      2  arguments invalides (valeur avec CR/LF/NUL)
      3  fichier cible introuvable (ou n'est pas un fichier)
      4  backup impossible (dir dans un depot Git, ou echec de copie)
      5  echec d'ecriture apres backup (le backup est conserve)
      6  plusieurs assignations actives detectees (aucune mutation)

    Fichier volontairement ASCII pur sans BOM : PowerShell 5.1 lit un .ps1 sans
    BOM comme ANSI ; le contenu reste correct meme sans BOM (#3338/#3339).
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $true)]
    [string]$TargetPath,

    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[A-Za-z_][A-Za-z0-9_]*$')]
    [string]$Name,

    [Parameter(Mandatory = $true)]
    [AllowEmptyString()]
    [string]$Value,

    [Parameter(Mandatory = $false)]
    [string]$BackupDir
)

$ErrorActionPreference = 'Stop'

# --- Garde : le backup vit HORS de tout depot Git (parcours des parents, .git) ---
function Test-PathInsideGitRepo {
    param([string]$Path)
    $dir = [System.IO.Path]::GetFullPath($Path)
    while ($true) {
        if (Test-Path -LiteralPath (Join-Path $dir '.git')) { return $true }
        $parent = Split-Path -Path $dir -Parent
        if (-not $parent -or $parent -eq $dir) { return $false }
        $dir = $parent
    }
}

# --- Validation des entrees (aucune mutation avant la fin de cette phase) ---
if ($Value.IndexOfAny([char[]]@("`r", "`n", "`0")) -ge 0) {
    Write-Host '[set-mcp-env-var] ABORT: value contains CR/LF/NUL -- refusing, no mutation.' -ForegroundColor Red
    exit 2
}

if (-not (Test-Path -LiteralPath $TargetPath -PathType Leaf)) {
    Write-Host "[set-mcp-env-var] ABORT: target file not found: $TargetPath" -ForegroundColor Red
    exit 3
}

if (-not $BackupDir) {
    $base = $env:USERPROFILE
    if (-not $base) { $base = $HOME }
    $BackupDir = Join-Path -Path (Join-Path -Path $base -ChildPath '.roo-state-manager') -ChildPath 'env-var-backups'
}

if (Test-PathInsideGitRepo -Path $BackupDir) {
    Write-Host "[set-mcp-env-var] ABORT: backup dir resolves INSIDE a Git repository ($BackupDir) -- refusing. Pass -BackupDir outside any repo." -ForegroundColor Red
    exit 4
}

# --- Calcul du nouveau contenu (lecture seule ; la valeur n'est jamais affichee) ---
$raw      = [System.IO.File]::ReadAllText($TargetPath)
$pattern  = '^\s*' + [regex]::Escape($Name) + '\s*='
$newLine  = $Name + '=' + $Value

# Decoupe en conservant chaque fin de ligne dans son chunk : les lignes non
# modifiees (et leurs EOL respectifs CRLF/LF) sont restituees a l'identique.
$chunks   = [regex]::Split($raw, '(?<=\n)')
$activeAssignmentCount = @($chunks | Where-Object { $_ -match $pattern }).Count
if ($activeAssignmentCount -gt 1) {
    Write-Host "[set-mcp-env-var] ABORT: multiple active assignments for $Name -- refusing, no backup, no write." -ForegroundColor Red
    exit 6
}

$found    = $false
$outChunks = New-Object System.Collections.Generic.List[string]
foreach ($chunk in $chunks) {
    if (-not $found -and $chunk -match $pattern) {
        $found = $true
        $eol = ''
        if ($chunk -match '(\r?\n)$') { $eol = $Matches[1] }
        $outChunks.Add($newLine + $eol)
    } else {
        $outChunks.Add($chunk)
    }
}

if ($found) {
    $new = -join $outChunks
} else {
    # Absente : ajout en fin de fichier, en respectant le style EOL dominant.
    if ($raw.Length -eq 0) {
        $new = $newLine + "`n"
    } else {
        $eol = "`n"
        if ($raw -match '\r\n') { $eol = "`r`n" }
        if ($raw -match '\n$') { $new = $raw + $newLine + $eol }
        else { $new = $raw + $eol + $newLine + $eol }
    }
}

# --- Idempotence : deja configure -> AUCUNE ecriture (ni backup, ni fichier) ---
if ([string]::Equals($new, $raw, [System.StringComparison]::Ordinal)) {
    Write-Host "[set-mcp-env-var] $Name : NO-CHANGE (already configured) -- no backup, no write."
    exit 0
}

$status = 'ADD'
if ($found) { $status = 'REPLACE' }

# --- Dry-run natif : sortie AVANT chaque ecriture (backup et fichier) ---
if (-not $PSCmdlet.ShouldProcess($TargetPath, "$status variable assignment '$Name' in .env")) {
    Write-Host "[set-mcp-env-var] $Name : $status skipped (dry-run) -- no backup, no write."
    exit 0
}

# --- Backup preservatif byte-identical AVANT toute mutation du fichier ---
try {
    if (-not (Test-Path -LiteralPath $BackupDir)) {
        New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null
    }
    $stamp      = Get-Date -Format 'yyyyMMdd-HHmmss'
    $leaf       = [System.IO.Path]::GetFileName($TargetPath)
    $backupPath = Join-Path -Path $BackupDir -ChildPath ($leaf + '.' + $stamp + '.bak')
    Copy-Item -LiteralPath $TargetPath -Destination $backupPath -Force
} catch {
    Write-Host "[set-mcp-env-var] ABORT: backup failed ($($_.Exception.Message)); target NOT modified." -ForegroundColor Red
    exit 4
}

# --- Mutation : UTF-8 sans BOM uniquement ---
try {
    [System.IO.File]::WriteAllText($TargetPath, $new, (New-Object System.Text.UTF8Encoding($false)))
} catch {
    Write-Host "[set-mcp-env-var] ABORT: write failed after backup ($($_.Exception.Message)); backup kept at $backupPath" -ForegroundColor Red
    exit 5
}

Write-Host "[set-mcp-env-var] $Name : $status applied."
Write-Host "[set-mcp-env-var] backup -> $backupPath"
Write-Host '[set-mcp-env-var] service rebuild/restart is left to the operator (out of scope).'
exit 0
