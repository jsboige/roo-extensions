<#
.SYNOPSIS
    Enregistre et configure le module EncodingManager pour l'environnement courant.

.DESCRIPTION
    Ce script vérifie la présence du module EncodingManager compilé,
    configure les variables d'environnement nécessaires, et s'assure
    que le module est prêt à être utilisé par les profils PowerShell.

.EXAMPLE
    .\Register-EncodingManager.ps1 -Verbose

.NOTES
    Auteur: Roo Architect
    Date: 2025-11-26
#>

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

Write-Verbose "Début de l'enregistrement de EncodingManager..."

# Chemins
$ScriptRoot = $PSScriptRoot
$ModuleRoot = Resolve-Path "$ScriptRoot\..\..\modules\EncodingManager"
$DistPath = Join-Path $ModuleRoot "dist"

# Vérification de la compilation
if (-not (Test-Path $DistPath)) {
    Write-Warning "Le module EncodingManager n'est pas compilé (dossier dist manquant)."
    Write-Verbose "Tentative de compilation..."
    
    Push-Location $ModuleRoot
    try {
        if (Get-Command npm -ErrorAction SilentlyContinue) {
            npm install
            npm run build
            if ($LASTEXITCODE -eq 0) {
                Write-Verbose "Compilation réussie."
            } else {
                throw "La compilation a échoué."
            }
        } else {
            throw "npm n'est pas installé ou accessible."
        }
    }
    finally {
        Pop-Location
    }
}

# Vérification des fichiers clés
$MainFile = Join-Path $DistPath "core\EncodingManager.js"
if (-not (Test-Path $MainFile)) {
    throw "Le fichier principal du module est manquant: $MainFile"
}

# Configuration de l'environnement (si nécessaire pour Node.js)
# Ici on pourrait ajouter le chemin aux modules node globaux si besoin,
# mais pour l'instant on utilise des chemins relatifs.

Write-Verbose "Validation de l'intégration PowerShell..."
$InitScript = Join-Path $ScriptRoot "Initialize-EncodingManager.ps1"

if (-not (Test-Path $InitScript)) {
    throw "Le script d'initialisation PowerShell est manquant: $InitScript"
}

# Test de chargement basique (via Node)
Write-Verbose "Test de chargement du module via Node.js..."
$TestScript = @"
const { EncodingManager } = require('./dist/core/EncodingManager');
const manager = new EncodingManager();
console.log('EncodingManager loaded successfully. Default encoding: ' + manager.getConfig().defaultEncoding);
"@

$TestFile = Join-Path $ModuleRoot "test-load.js"
Set-Content -Path $TestFile -Value $TestScript -Encoding UTF8

try {
    Push-Location $ModuleRoot
    $Output = node test-load.js
    if ($LASTEXITCODE -eq 0) {
        Write-Verbose "Test de chargement réussi: $Output"
    } else {
        throw "Le test de chargement a échoué."
    }
}
finally {
    if (Test-Path $TestFile) { Remove-Item $TestFile }
    Pop-Location
}

Write-Host "EncodingManager enregistré et validé avec succès." -ForegroundColor Green