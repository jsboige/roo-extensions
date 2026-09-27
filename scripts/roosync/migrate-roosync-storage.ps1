<#
.SYNOPSIS
    Migre le stockage local .shared-state vers le chemin défini par ROOSYNC_SHARED_PATH.

.DESCRIPTION
    Ce script automatise la migration des données RooSync vers un emplacement externe.
    Il effectue les actions suivantes :
    1. Lit la variable d'environnement ROOSYNC_SHARED_PATH depuis le fichier .env du projet.
    2. Vérifie l'existence du dossier source local (.shared-state).
    3. Copie le contenu vers la destination cible.
    4. Renomme le dossier source en .shared-state.bak pour archivage.

    Sécurité (audit 27/09, dispatch ai-01 18:39Z — Plan Marshall des scripts destructeurs) :
    - DRY-RUN par défaut : sans -Apply, le script affiche le plan et n'écrit rien.
    - Un échec de copie arrête le script immédiatement (aucune étape d'archivage).
    - Le renommage de la source n'a lieu qu'après vérification d'intégrité :
      compte de fichiers ET empreinte SHA256 de chaque fichier source == copie.
    - Un .shared-state.bak préexistant est conservé (renommé .shared-state.bak.<timestamp>),
      jamais supprimé.

.EXAMPLE
    .\scripts\roosync\migrate-roosync-storage.ps1            # dry-run : plan seul
    .\scripts\roosync\migrate-roosync-storage.ps1 -Apply     # exécute la migration
#>
param(
    [switch]$Apply,

    # Overrides de banc (Pester) : court-circuitent la déduction ProjectRoot/.env.
    [string]$SourcePath,
    [string]$TargetPath
)

$ErrorActionPreference = "Stop"

# --- Configuration ---
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir
$EnvFile = Join-Path $ProjectRoot "mcps\internal\servers\roo-state-manager\.env"
$LocalSharedState = if ($SourcePath) { $SourcePath } else { Join-Path $ProjectRoot ".shared-state" }
$SourceLeaf = Split-Path -Leaf $LocalSharedState

Write-Host "=== Migration du Stockage RooSync ===" -ForegroundColor Cyan

function Test-MigrationIntegrity {
    param(
        [Parameter(Mandatory)] [string]$Source,
        [Parameter(Mandatory)] [string]$Target
    )
    $srcRoot = (Resolve-Path -LiteralPath $Source).ProviderPath.TrimEnd('\')
    $tgtFiles = @(Get-ChildItem -LiteralPath $Target -Recurse -File)
    $srcFiles = @(Get-ChildItem -LiteralPath $Source -Recurse -File)
    if ($srcFiles.Count -ne $tgtFiles.Count) {
        return @{ Ok = $false
                  Reason = ("nombre de fichiers : {0} source vs {1} copie" -f $srcFiles.Count, $tgtFiles.Count) }
    }
    foreach ($f in $srcFiles) {
        $rel = $f.FullName.Substring($srcRoot.Length + 1)
        $t = Join-Path $Target $rel
        if (-not (Test-Path -LiteralPath $t -PathType Leaf)) {
            return @{ Ok = $false; Reason = "fichier manquant dans la copie : $rel" }
        }
        $h1 = (Get-FileHash -LiteralPath $f.FullName -Algorithm SHA256).Hash
        $h2 = (Get-FileHash -LiteralPath $t -Algorithm SHA256).Hash
        if ($h1 -ne $h2) {
            return @{ Ok = $false; Reason = "empreinte différente : $rel" }
        }
    }
    return @{ Ok = $true; Reason = ("{0} fichiers, empreintes égales" -f $srcFiles.Count) }
}

# 1. Lecture de la configuration
if ($TargetPath) {
    $TargetSharedPath = $TargetPath
}
else {
    if (-not (Test-Path $EnvFile)) {
        Write-Error "Fichier .env introuvable : $EnvFile"
    }
    $EnvContent = Get-Content $EnvFile
    $TargetSharedPath = $null
    foreach ($line in $EnvContent) {
        if ($line -match "^ROOSYNC_SHARED_PATH=(.*)$") {
            $TargetSharedPath = $matches[1].Trim()
            break
        }
    }
    if ([string]::IsNullOrWhiteSpace($TargetSharedPath)) {
        # Non interactif (audit 27/09) : un prompt silencieux bloque bancs et cron.
        Write-Error "ROOSYNC_SHARED_PATH non trouvé dans $EnvFile — définissez-le avant de relancer."
    }
    $TargetSharedPath = $TargetSharedPath -replace '"', ''
}

Write-Host "Source : $LocalSharedState"
Write-Host "Cible  : $TargetSharedPath"

# 2. Vérifications
if (-not (Test-Path $LocalSharedState)) {
    Write-Warning "Le dossier source $LocalSharedState n'existe pas. Rien à migrer."
    exit 0
}

$SourceStats = @(Get-ChildItem -LiteralPath $LocalSharedState -Recurse -File)
$SourceBytes = ($SourceStats | Measure-Object -Property Length -Sum).Sum

# 3. Dry-run par défaut
if (-not $Apply) {
    Write-Host "[DRY] $($SourceStats.Count) fichiers, $SourceBytes octets seraient copiés vers $TargetSharedPath" -ForegroundColor Yellow
    Write-Host "[DRY] La source serait ensuite renommée en $SourceLeaf.bak (après contrôle d'intégrité)." -ForegroundColor Yellow
    Write-Host "[DRY] Relancez avec -Apply pour exécuter."
    exit 0
}

if (-not (Test-Path $TargetSharedPath)) {
    Write-Host "Création du dossier cible..."
    New-Item -ItemType Directory -Path $TargetSharedPath -Force | Out-Null
}

# 4. Copie — un échec termine le script ici (ErrorAction Stop), rien d'autre ne s'exécute.
Write-Host "Copie des fichiers en cours..."
Copy-Item -Path "$LocalSharedState\*" -Destination $TargetSharedPath -Recurse -Force -ErrorAction Stop
Write-Host "Copie terminée." -ForegroundColor Green

# 5. Contrôle d'intégrité AVANT tout geste sur la source ou le .bak
$integrity = Test-MigrationIntegrity -Source $LocalSharedState -Target $TargetSharedPath
if (-not $integrity.Ok) {
    Write-Error ("Copie INCOMPLETE — migration annulée : {0}. Source NON renommee, .bak preserve." -f $integrity.Reason)
}
Write-Host "Integrite verifiee : $($integrity.Reason)" -ForegroundColor Green

# 6. Archivage local — le .bak existant est conserve, jamais supprime
$BackupPath = Join-Path (Split-Path -Parent $LocalSharedState) "$SourceLeaf.bak"
if (Test-Path $BackupPath) {
    $stamp = Get-Date -Format 'yyyyMMddHHmmss'
    Rename-Item -Path $BackupPath -NewName ("{0}.{1}" -f (Split-Path -Leaf $BackupPath), $stamp)
    Write-Host "Backup precedent conserve : $(Split-Path -Leaf $BackupPath).$stamp"
}

Rename-Item -Path $LocalSharedState -NewName "$SourceLeaf.bak"
Write-Host "Dossier local renomme en $SourceLeaf.bak" -ForegroundColor Green

Write-Host "=== Migration Terminee ===" -ForegroundColor Cyan
Write-Host "Verifiez que tout fonctionne correctement avant de supprimer .shared-state.bak"
