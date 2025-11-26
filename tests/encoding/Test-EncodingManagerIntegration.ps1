<#
.SYNOPSIS
    Tests d'intégration pour EncodingManager.

.DESCRIPTION
    Vérifie que le module EncodingManager est correctement déployé,
    que les scripts d'initialisation fonctionnent, et que le monitoring
    est configurable.
#>

$ErrorActionPreference = "Stop"
$ScriptRoot = $PSScriptRoot
$ModuleRoot = Resolve-Path "$ScriptRoot\..\..\modules\EncodingManager"
$ScriptsRoot = Resolve-Path "$ScriptRoot\..\..\scripts\encoding"

Write-Host "Démarrage des tests d'intégration EncodingManager..." -ForegroundColor Cyan

# 1. Vérification de la structure du module
Write-Host "`n[1/4] Vérification de la structure du module..."
$ExpectedFiles = @(
    "dist\core\EncodingManager.js",
    "dist\core\EncodingManager.d.ts",
    "dist\validation\UnicodeValidator.js",
    "package.json"
)

foreach ($File in $ExpectedFiles) {
    $Path = Join-Path $ModuleRoot $File
    if (Test-Path $Path) {
        Write-Host "  [PASS] Fichier présent: $File" -ForegroundColor Green
    } else {
        Write-Error "  [FAIL] Fichier manquant: $File"
    }
}

# 2. Test de chargement du module (Node.js)
Write-Host "`n[2/4] Test de chargement du module (Node.js)..."
$TestScript = @"
try {
    const { EncodingManager } = require('./dist/core/EncodingManager');
    const manager = new EncodingManager();
    const config = manager.getConfig();
    if (config.defaultEncoding === 'utf-8') {
        console.log('SUCCESS');
    } else {
        console.error('FAIL: Incorrect default encoding');
        process.exit(1);
    }
} catch (e) {
    console.error('FAIL: ' + e.message);
    process.exit(1);
}
"@

$TestFile = Join-Path $ModuleRoot "integration-test.js"
Set-Content -Path $TestFile -Value $TestScript -Encoding UTF8

try {
    Push-Location $ModuleRoot
    $Output = node integration-test.js
    if ($LASTEXITCODE -eq 0 -and $Output -match "SUCCESS") {
        Write-Host "  [PASS] Chargement et instanciation réussis" -ForegroundColor Green
    } else {
        Write-Error "  [FAIL] Échec du chargement: $Output"
    }
}
finally {
    if (Test-Path $TestFile) { Remove-Item $TestFile }
    Pop-Location
}

# 3. Vérification des scripts PowerShell
Write-Host "`n[3/4] Vérification des scripts PowerShell..."
$Scripts = @(
    "Initialize-EncodingManager.ps1",
    "Register-EncodingManager.ps1",
    "Configure-EncodingMonitoring.ps1"
)

foreach ($Script in $Scripts) {
    $Path = Join-Path $ScriptsRoot $Script
    if (Test-Path $Path) {
        Write-Host "  [PASS] Script présent: $Script" -ForegroundColor Green
        
        # Vérification syntaxique
        $Errors = $null
        [System.Management.Automation.PSParser]::Tokenize((Get-Content $Path -Raw), [ref]$Errors) | Out-Null
        if ($Errors.Count -eq 0) {
            Write-Host "  [PASS] Syntaxe valide: $Script" -ForegroundColor Green
        } else {
            Write-Error "  [FAIL] Erreurs de syntaxe dans $Script"
        }
    } else {
        Write-Error "  [FAIL] Script manquant: $Script"
    }
}

# 4. Test de simulation de monitoring
Write-Host "`n[4/4] Test de simulation de monitoring..."
# On ne crée pas vraiment la tâche pour ne pas polluer, mais on teste la commande
$MonitorScript = Join-Path $ScriptsRoot "Configure-EncodingMonitoring.ps1"
try {
    # Test en mode DryRun (si implémenté) ou vérification des paramètres
    $Params = Get-Command $MonitorScript | Select-Object -ExpandProperty Parameters
    if ($Params.ContainsKey("Enable") -and $Params.ContainsKey("Disable")) {
        Write-Host "  [PASS] Paramètres de monitoring valides" -ForegroundColor Green
    } else {
        Write-Error "  [FAIL] Paramètres manquants dans Configure-EncodingMonitoring.ps1"
    }
} catch {
    Write-Error "  [FAIL] Erreur lors de l'analyse du script de monitoring: $_"
}

Write-Host "`nTests d'intégration terminés." -ForegroundColor Cyan