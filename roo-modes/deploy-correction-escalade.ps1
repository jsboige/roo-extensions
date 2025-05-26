# Script de déploiement des corrections de logique d'escalade
# Copie le fichier corrigé vers le profil Roo actif

param(
    [string]$SourceConfig = "configs/refactored-modes.json",
    [string]$RooProfilePath = "$env:APPDATA\Roo\profiles\default\modes.json",
    [switch]$Backup = $true,
    [switch]$Validate = $true
)

Write-Host "=== DEPLOIEMENT CORRECTION LOGIQUE ESCALADE ===" -ForegroundColor Cyan
Write-Host "Source: $SourceConfig" -ForegroundColor Yellow
Write-Host "Destination: $RooProfilePath" -ForegroundColor Yellow
Write-Host ""

# Vérification du fichier source
if (-not (Test-Path $SourceConfig)) {
    Write-Host "ERREUR: Fichier source non trouvé: $SourceConfig" -ForegroundColor Red
    exit 1
}

# Validation optionnelle avant déploiement
if ($Validate) {
    Write-Host "Validation du fichier source..." -ForegroundColor Cyan
    $validationResult = & powershell -ExecutionPolicy Bypass -File "validation-simple.ps1" -ConfigPath $SourceConfig
    if ($LASTEXITCODE -ne 0) {
        Write-Host "ERREUR: La validation a échoué. Déploiement annulé." -ForegroundColor Red
        exit 1
    }
    Write-Host "Validation réussie ✅" -ForegroundColor Green
    Write-Host ""
}

# Création du répertoire de destination si nécessaire
$destDir = Split-Path $RooProfilePath -Parent
if (-not (Test-Path $destDir)) {
    Write-Host "Création du répertoire: $destDir" -ForegroundColor Yellow
    New-Item -ItemType Directory -Path $destDir -Force | Out-Null
}

# Sauvegarde optionnelle
if ($Backup -and (Test-Path $RooProfilePath)) {
    $backupPath = "$RooProfilePath.backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    Write-Host "Sauvegarde: $backupPath" -ForegroundColor Yellow
    Copy-Item $RooProfilePath $backupPath
    Write-Host "Sauvegarde créée ✅" -ForegroundColor Green
}

# Déploiement
try {
    Write-Host "Déploiement en cours..." -ForegroundColor Cyan
    Copy-Item $SourceConfig $RooProfilePath -Force
    Write-Host "Déploiement réussi ✅" -ForegroundColor Green
} catch {
    Write-Host "ERREUR lors du déploiement: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Vérification post-déploiement
if (Test-Path $RooProfilePath) {
    $fileSize = (Get-Item $RooProfilePath).Length
    Write-Host "Fichier déployé: $fileSize octets" -ForegroundColor Green
    
    # Test de lecture JSON
    try {
        $deployedConfig = Get-Content $RooProfilePath -Raw -Encoding UTF8 | ConvertFrom-Json
        $modesCount = $deployedConfig.customModes.Count
        Write-Host "Modes déployés: $modesCount" -ForegroundColor Green
    } catch {
        Write-Host "ATTENTION: Problème de lecture du fichier déployé" -ForegroundColor Yellow
    }
} else {
    Write-Host "ERREUR: Fichier de destination non trouvé après déploiement" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "=== DEPLOIEMENT TERMINE ===" -ForegroundColor Cyan
Write-Host "REDEMARREZ ROO pour appliquer les changements" -ForegroundColor Yellow
Write-Host ""
Write-Host "RESUME DES CORRECTIONS APPLIQUEES:" -ForegroundColor Cyan
Write-Host "✅ Modes SIMPLE: Points d'entrée et orchestrateurs principaux" -ForegroundColor Green
Write-Host "✅ Modes COMPLEX: Délégateurs créant uniquement des sous-tâches SIMPLE" -ForegroundColor Green
Write-Host "✅ Logique d'escalade/désescalade corrigée" -ForegroundColor Green