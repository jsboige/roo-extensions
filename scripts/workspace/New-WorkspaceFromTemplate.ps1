<#
.SYNOPSIS
Amorce un nouveau workspace depuis le gabarit .claude/configs/workspace-template/.

.DESCRIPTION
Creation seule (Epic #3111 candidat #7, etape 1 - #4873, decision user RX152) :
  - refuse d'ecraser un fichier existant : chaque fichier deja present dans la
    cible est liste comme saute, son contenu n'est pas touche ;
  - -DryRun n'ecrit rien, pas meme un repertoire, et imprime ce qui serait cree ;
  - fusionne gitignore.fragment dans un .gitignore existant par ajout des seules
    lignes absentes (aucune ligne existante n'est jamais retiree) ;
  - n'ecrit jamais hors de -Target : refuse la racine d'un lecteur et toute
    cible qui contiendrait le gabarit lui-meme.

Les marqueurs {{WORKSPACE}} et {{REPO}} sont remplaces dans chaque fichier copie
{{WORKSPACE}} par le parametre, {{REPO}} par le nom du repertoire cible (dernier
segment de -Target). Le README.md a la racine du gabarit est sa documentation :
il ne part jamais dans la cible.

Compatible Windows PowerShell 5.1 et PowerShell 7+ (Linux compris - la suite
scripts/testing/unit/new-workspace-from-template.Tests.ps1 execute CE script
comme enfant reel sur la CI ubuntu).

.PARAMETER Target
Chemin du depot cible (relatif ou absolu). Cree s'il n'existe pas - sauf sous
-DryRun, ou rien n'est alloue.

.PARAMETER Workspace
Nom du workspace (identite de lane machine:workspace).

.EXAMPLE
powershell -ExecutionPolicy Bypass -File scripts/workspace/New-WorkspaceFromTemplate.ps1 -Target D:\Dev\NouveauDepot -Workspace MonWorkspace -DryRun
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$Target,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$Workspace,

    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'

# --- Resolution des chemins -------------------------------------------------
# Le script vit dans <repo>/scripts/workspace/ ; le gabarit dans
# <repo>/.claude/configs/workspace-template/.
$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$templateRoot = Join-Path $repoRoot '.claude/configs/workspace-template'
if (-not (Test-Path -LiteralPath $templateRoot)) {
    throw "Gabarit introuvable : $templateRoot"
}

if ([System.IO.Path]::IsPathRooted($Target)) {
    $targetRaw = $Target
} else {
    $targetRaw = Join-Path (Get-Location).Path $Target
}
$targetFull = [System.IO.Path]::GetFullPath($targetRaw).TrimEnd('\', '/')
$templateFull = [System.IO.Path]::GetFullPath($templateRoot).TrimEnd('\', '/')
$sep = [System.IO.Path]::DirectorySeparatorChar

# --- Gardes : la cible ne peut ni etre une racine, ni contenir le gabarit ---
$driveRoot = [System.IO.Path]::GetPathRoot($targetFull)
if ($driveRoot -and ($targetFull -eq $driveRoot.TrimEnd('\', '/'))) {
    throw "Refus : -Target est la racine d'un lecteur ($targetFull)."
}
if (($targetFull -eq $templateFull) -or
    $templateFull.StartsWith($targetFull + $sep, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Refus : -Target contient le gabarit lui-meme ($templateFull) - la cible doit etre un autre depot."
}

# --- Plan : chaque fichier du gabarit a destination normalisee en '/' -------
# Tout le contenu du gabarit part dans la cible, SAUF le README.md racinal
# (documentation du gabarit). CLAUDE.md.template devient CLAUDE.md ;
# gitignore.fragment est traite a part (fusion).
$plan = New-Object System.Collections.Generic.List[hashtable]
$fragmentPath = $null
$templateFiles = Get-ChildItem -LiteralPath $templateFull -Recurse -File -Force | Sort-Object -Property FullName
foreach ($f in $templateFiles) {
    $rel = $f.FullName.Substring($templateFull.Length + 1).Replace('\', '/')
    if ($rel -eq 'README.md') { continue }
    if ($rel -eq 'CLAUDE.md.template') {
        $plan.Add(@{ Source = $f.FullName; DestRel = 'CLAUDE.md' })
        continue
    }
    if ($rel -eq 'gitignore.fragment') {
        $fragmentPath = $f.FullName
        continue
    }
    $plan.Add(@{ Source = $f.FullName; DestRel = $rel })
}
if (-not $fragmentPath) {
    throw 'gitignore.fragment absent du gabarit - le gabarit est incomplet.'
}

# --- Execution : creation seule, marqueurs remplaces ------------------------
$repoName = Split-Path -Leaf $targetFull
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$created = New-Object System.Collections.Generic.List[string]
$skipped = New-Object System.Collections.Generic.List[string]

if (-not $DryRun) {
    New-Item -ItemType Directory -Path $targetFull -Force | Out-Null
}

foreach ($entry in $plan) {
    $destNative = Join-Path $targetFull ($entry.DestRel.Replace('/', $sep))
    if (Test-Path -LiteralPath $destNative) {
        $skipped.Add($entry.DestRel)
        continue
    }
    if ($DryRun) {
        $created.Add($entry.DestRel)
        continue
    }
    $destDir = Split-Path -Parent $destNative
    if (-not (Test-Path -LiteralPath $destDir)) {
        New-Item -ItemType Directory -Path $destDir -Force | Out-Null
    }
    $content = [System.IO.File]::ReadAllText($entry.Source)
    $content = $content.Replace('{{WORKSPACE}}', $Workspace).Replace('{{REPO}}', $repoName)
    [System.IO.File]::WriteAllText($destNative, $content, $utf8NoBom)
    $created.Add($entry.DestRel)
}

# --- Fusion .gitignore : ajout des seules lignes absentes -------------------
$gitignoreDest = Join-Path $targetFull '.gitignore'
$gitignoreExists = Test-Path -LiteralPath $gitignoreDest
$fragmentLines = [System.IO.File]::ReadAllLines($fragmentPath)
$existingLines = @()
if ($gitignoreExists) {
    $existingLines = [System.IO.File]::ReadAllLines($gitignoreDest)
}
$missing = New-Object System.Collections.Generic.List[string]
foreach ($line in $fragmentLines) {
    $t = $line.Trim()
    if ($t -eq '') { continue }
    $present = $false
    foreach ($e in $existingLines) {
        if ($e.Trim() -eq $t) { $present = $true; break }
    }
    if (-not $present) { $missing.Add($t) }
}
$nl = [System.Environment]::NewLine
if ($missing.Count -gt 0 -and -not $DryRun) {
    if ($gitignoreExists) {
        $current = [System.IO.File]::ReadAllText($gitignoreDest)
        $prefix = ''
        if ($current.Length -gt 0 -and -not ($current.EndsWith("`n") -or $current.EndsWith("`r"))) {
            $prefix = $nl
        }
        [System.IO.File]::WriteAllText($gitignoreDest, $current + $prefix + ($missing -join $nl) + $nl, $utf8NoBom)
    } else {
        [System.IO.File]::WriteAllText($gitignoreDest, ($missing -join $nl) + $nl, $utf8NoBom)
        $created.Add('.gitignore')
    }
}
if ($missing.Count -gt 0 -and $DryRun -and -not $gitignoreExists) {
    $created.Add('.gitignore')
}

# --- Rapport ----------------------------------------------------------------
$label = ''
$verbCreate = 'Fichiers crees'
if ($DryRun) {
    $label = '[DRY-RUN] '
    $verbCreate = 'Fichiers qui seraient crees'
}
Write-Host ($label + "Cible : $targetFull")
Write-Host ($label + "Workspace : $Workspace")
Write-Host ($label + "$verbCreate ($($created.Count)) :")
if ($created.Count -eq 0) { Write-Host ($label + '  (aucun)') }
foreach ($c in $created) { Write-Host ($label + "  + $c") }
Write-Host ($label + "Fichiers sautes - existent deja ($($skipped.Count)) :")
if ($skipped.Count -eq 0) { Write-Host ($label + '  (aucun)') }
foreach ($s in $skipped) { Write-Host ($label + "  - $s") }
if ($missing.Count -gt 0) {
    $gitDetail = if ($gitignoreExists) { 'fusion dans le .gitignore existant' } else { 'nouveau fichier .gitignore' }
    Write-Host ($label + ".gitignore : $($missing.Count) ligne(s) a ajouter ($gitDetail, aucune ligne retiree)")
} else {
    Write-Host ($label + '.gitignore : rien a ajouter (deja complet)')
}
if ($DryRun) {
    Write-Host ($label + "Rien n'a ete ecrit (0 fichier, 0 repertoire).")
} else {
    Write-Host ('Termine - 0 ecrasement.')
}
