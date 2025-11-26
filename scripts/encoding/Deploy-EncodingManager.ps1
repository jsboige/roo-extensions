<#
.SYNOPSIS
    Déploie le module EncodingManager.

.DESCRIPTION
    Ce script automatise le déploiement du module EncodingManager :
    - Vérification des prérequis (Node.js, npm)
    - Installation des dépendances
    - Compilation TypeScript
    - Configuration de l'environnement

.PARAMETER Force
    Force la réinstallation même si déjà présent.

.EXAMPLE
    .\Deploy-EncodingManager.ps1 -Force
#>

param (
    [Switch]$Force
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ModuleDir = Join-Path $ScriptDir "..\..\modules\EncodingManager"
$ModuleDir = Resolve-Path $ModuleDir

Write-Host "=== Déploiement EncodingManager ===" -ForegroundColor Cyan

# 1. Vérification des prérequis
Write-Host "[1/4] Vérification des prérequis..."
if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    Throw "Node.js n'est pas installé ou n'est pas dans le PATH."
}
if (-not (Get-Command npm -ErrorAction SilentlyContinue)) {
    Throw "npm n'est pas installé ou n'est pas dans le PATH."
}
Write-Host "    Node.js et npm détectés." -ForegroundColor Green

# 2. Installation des dépendances
Write-Host "[2/4] Installation des dépendances..."
Push-Location $ModuleDir
try {
    if ($Force -or -not (Test-Path "node_modules")) {
        npm install
        if ($LASTEXITCODE -ne 0) { Throw "Erreur lors de npm install" }
        Write-Host "    Dépendances installées." -ForegroundColor Green
    } else {
        Write-Host "    Dépendances déjà présentes (utiliser -Force pour réinstaller)." -ForegroundColor Yellow
    }
}
finally {
    Pop-Location
}

# 3. Compilation
Write-Host "[3/4] Compilation du module..."
Push-Location $ModuleDir
try {
    npm run build
    if ($LASTEXITCODE -ne 0) { Throw "Erreur lors de la compilation (npm run build)" }
    Write-Host "    Compilation réussie." -ForegroundColor Green
}
finally {
    Pop-Location
}

# 4. Configuration Environnement (Simulation pour l'instant)
Write-Host "[4/4] Configuration de l'environnement..."
# Ici, on pourrait ajouter le chemin au PATH ou configurer des variables d'environnement globales
# Pour l'instant, on vérifie juste que le build existe
if (Test-Path (Join-Path $ModuleDir "dist\core\EncodingManager.js")) {
    Write-Host "    Module prêt à l'emploi." -ForegroundColor Green
} else {
    Throw "Le fichier principal EncodingManager.js est introuvable après compilation."
}

Write-Host "=== Déploiement terminé avec succès ===" -ForegroundColor Cyan