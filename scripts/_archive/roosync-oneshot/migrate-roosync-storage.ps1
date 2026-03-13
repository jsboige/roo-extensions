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

.EXAMPLE
    .\scripts\migrate-roosync-storage.ps1
#>

$ErrorActionPreference = "Stop"

# --- Configuration ---
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir
$EnvFile = Join-Path $ProjectRoot "mcps\internal\servers\roo-state-manager\.env"
$LocalSharedState = Join-Path $ProjectRoot ".shared-state"

Write-Host "=== Migration du Stockage RooSync ===" -ForegroundColor Cyan

# 1. Lecture de la configuration
if (-not (Test-Path $EnvFile)) {
    Write-Error "Fichier .env introuvable : $EnvFile"
}

Write-Host "Lecture de la configuration depuis $EnvFile..."
$EnvContent = Get-Content $EnvFile
$TargetSharedPath = $null

foreach ($line in $EnvContent) {
    if ($line -match "^ROOSYNC_SHARED_PATH=(.*)$") {
        $TargetSharedPath = $matches[1].Trim()
        break
    }
}

if ([string]::IsNullOrWhiteSpace($TargetSharedPath)) {
    Write-Warning "ROOSYNC_SHARED_PATH non trouvé dans .env."
    $TargetSharedPath = Read-Host "Veuillez entrer le chemin cible complet (ex: G:\Mon Drive\RooSync\.shared-state)"
}

if ([string]::IsNullOrWhiteSpace($TargetSharedPath)) {
    Write-Error "Aucun chemin cible défini. Abandon."
}

# Nettoyage des guillemets éventuels
$TargetSharedPath = $TargetSharedPath -replace '"', ''

Write-Host "Source : $LocalSharedState"
Write-Host "Cible  : $TargetSharedPath"

# 2. Vérifications
if (-not (Test-Path $LocalSharedState)) {
    Write-Warning "Le dossier source $LocalSharedState n'existe pas. Rien à migrer."
    exit
}

if (-not (Test-Path $TargetSharedPath)) {
    Write-Host "Création du dossier cible..."
    New-Item -ItemType Directory -Path $TargetSharedPath -Force | Out-Null
}

# 3. Migration
Write-Host "Copie des fichiers en cours..."
try {
    Copy-Item -Path "$LocalSharedState\*" -Destination $TargetSharedPath -Recurse -Force
    Write-Host "Copie terminée avec succès." -ForegroundColor Green
}
catch {
    Write-Error "Erreur lors de la copie : $_"
}

# 4. Archivage local
Write-Host "Archivage du dossier local..."
$BackupPath = "$LocalSharedState.bak"
if (Test-Path $BackupPath) {
    Write-Warning "Un backup existe déjà ($BackupPath). Suppression..."
    Remove-Item -Path $BackupPath -Recurse -Force
}

Rename-Item -Path $LocalSharedState -NewName ".shared-state.bak"
Write-Host "Dossier local renommé en .shared-state.bak" -ForegroundColor Green

Write-Host "=== Migration Terminée ===" -ForegroundColor Cyan
Write-Host "Veuillez vérifier que tout fonctionne correctement avant de supprimer .shared-state.bak"