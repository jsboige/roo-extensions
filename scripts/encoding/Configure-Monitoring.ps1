<#
.SYNOPSIS
    Configure le monitoring de l'encodage.

.DESCRIPTION
    Active le monitoring dans la configuration de l'EncodingManager et prépare l'environnement.
#>

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ModuleDir = Join-Path $ScriptDir "..\..\modules\EncodingManager"
$ModuleDir = Resolve-Path $ModuleDir
$ConfigPath = Join-Path $ModuleDir "encoding-config.json"

Write-Host "=== Configuration du Monitoring ===" -ForegroundColor Cyan

# Configuration par défaut
$Config = @{
    defaultEncoding = "utf-8"
    validationMode = "strict"
    fallbackEncoding = "windows-1252"
    monitoringEnabled = $true
    logLevel = "info"
}

# Sauvegarde de la configuration
$Config | ConvertTo-Json -Depth 2 | Set-Content -Path $ConfigPath -Encoding UTF8
Write-Host "Configuration sauvegardée dans $ConfigPath" -ForegroundColor Green

# Vérification
if (Test-Path $ConfigPath) {
    $Content = Get-Content $ConfigPath | ConvertFrom-Json
    if ($Content.monitoringEnabled) {
        Write-Host "Monitoring activé avec succès." -ForegroundColor Green
    } else {
        Write-Warning "Le monitoring n'a pas pu être activé."
    }
} else {
    Throw "Erreur lors de la création du fichier de configuration."
}

Write-Host "=== Configuration terminée ===" -ForegroundColor Cyan