<#
.SYNOPSIS
    Bootstrap l'inventaire machine pour RooSync

.DESCRIPTION
    Ce script simplifie le processus de création et publication d'inventaire machine.
    Il utilise Get-MachineInventory.ps1 et copie le résultat dans shared-state.

.PARAMETER MachineId
    ID de la machine (défaut: hostname)

.PARAMETER Force
    Force la régénération même si l'inventaire existe

.EXAMPLE
    .\Bootstrap-Inventory.ps1
    # Crée/met à jour l'inventaire pour la machine actuelle

.EXAMPLE
    .\Bootstrap-Inventory.ps1 -Force
    # Force la régénération de l'inventaire

.NOTES
    Author: Claude Code @ myia-po-2024
    Date: 2026-01-23
    Issue: #356
#>

param(
    [string]$MachineId = $env:COMPUTERNAME,
    [switch]$Force
)

$ErrorActionPreference = "Stop"

# Chemins
$scriptRoot = Split-Path -Parent $PSScriptRoot
$inventoryScript = Join-Path $scriptRoot "inventory\Get-MachineInventory.ps1"
$sharedState = "G:\Mon Drive\Synchronisation\RooSync\.shared-state\inventories"
$outputFile = Join-Path $sharedState "$MachineId.json"

Write-Host "=== Bootstrap Inventaire - $MachineId ===" -ForegroundColor Cyan
Write-Host ""

# Vérifier si shared-state existe
if (-not (Test-Path $sharedState)) {
    Write-Error "Shared-state n'existe pas: $sharedState"
    Write-Host "Assurez-vous que Google Drive est synchronisé." -ForegroundColor Yellow
    exit 1
}

# Vérifier si inventaire existe déjà
if ((Test-Path $outputFile) -and -not $Force) {
    $existingSize = (Get-Item $outputFile).Length
    Write-Host "✅ Inventaire existe déjà ($([math]::Round($existingSize/1KB, 2)) KB)" -ForegroundColor Green
    Write-Host "   Fichier: $outputFile" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Utilisez -Force pour régénérer." -ForegroundColor Yellow
    exit 0
}

# Vérifier script d'inventaire
if (-not (Test-Path $inventoryScript)) {
    Write-Error "Script Get-MachineInventory.ps1 introuvable: $inventoryScript"
    exit 1
}

# Générer inventaire
Write-Host "Génération inventaire..." -ForegroundColor Yellow
$tempFile = Join-Path $env:TEMP "$MachineId-inventory.json"

try {
    & $inventoryScript -MachineId $MachineId -OutputPath $tempFile | Out-Null

    if (-not (Test-Path $tempFile)) {
        Write-Error "Échec génération inventaire"
        exit 1
    }

    # Valider JSON
    $json = Get-Content $tempFile -Raw | ConvertFrom-Json
    if (-not $json.machineId) {
        Write-Error "Inventaire invalide: machineId manquant"
        exit 1
    }

    $tempSize = (Get-Item $tempFile).Length
    Write-Host "✅ Inventaire généré ($([math]::Round($tempSize/1KB, 2)) KB)" -ForegroundColor Green

    # Copier vers shared-state
    Write-Host "Publication vers shared-state..." -ForegroundColor Yellow
    Copy-Item $tempFile $outputFile -Force

    Write-Host "✅ Inventaire publié" -ForegroundColor Green
    Write-Host "   Fichier: $outputFile" -ForegroundColor Gray
    Write-Host ""

    # Afficher résumé
    Write-Host "=== Résumé ===" -ForegroundColor Cyan
    Write-Host "Machine ID: $($json.machineId)" -ForegroundColor White
    Write-Host "Timestamp: $($json.timestamp)" -ForegroundColor White
    Write-Host "Taille: $([math]::Round($tempSize/1KB, 2)) KB" -ForegroundColor White

    if ($json.inventory.mcpServers) {
        $mcpCount = ($json.inventory.mcpServers | Get-Member -MemberType NoteProperty).Count
        Write-Host "MCPs: $mcpCount serveurs" -ForegroundColor White
    }

    if ($json.inventory.rooModes) {
        $modeCount = ($json.inventory.rooModes | Get-Member -MemberType NoteProperty).Count
        Write-Host "Modes: $modeCount modes Roo" -ForegroundColor White
    }

    Write-Host ""
    Write-Host "✅ Bootstrap réussi !" -ForegroundColor Green

} finally {
    # Nettoyage
    if (Test-Path $tempFile) {
        Remove-Item $tempFile -Force
    }
}
