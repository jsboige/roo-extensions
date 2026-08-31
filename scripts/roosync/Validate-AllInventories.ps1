<#
.SYNOPSIS
    Valide les inventaires RooSync de toutes les machines

.DESCRIPTION
    Vérifie que les 5 inventaires sont complets, cohérents et valides :
    - Fichiers existent
    - JSON valide
    - Champs obligatoires présents
    - Paths corrects

.PARAMETER SharedStatePath
    Chemin vers le répertoire shared-state RooSync sur GDrive
    Par défaut: G:\Mon Drive\Synchronisation\RooSync\.shared-state

.EXAMPLE
    .\Validate-AllInventories.ps1
    Valide tous les inventaires avec le path par défaut

.EXAMPLE
    .\Validate-AllInventories.ps1 -SharedStatePath "C:\custom\path"
    Valide avec un path personnalisé

.NOTES
    Issue: #350 P0.1 - Validation croisée inventaires 5 machines
    Author: Claude Code (myia-po-2026)
    Date: 2026-01-23
#>

param(
    [string]$SharedStatePath = "G:\Mon Drive\Synchronisation\RooSync\.shared-state"
)

$ErrorActionPreference = 'Stop'

# Machines du système RooSync
$machines = @("myia-ai-01", "myia-po-2023", "myia-po-2024", "myia-po-2026", "myia-web1")

# Résultats de validation
$results = @()
$errors = @()

Write-Host "======================================" -ForegroundColor Cyan
Write-Host "  Validation Inventaires RooSync" -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "SharedStatePath: $SharedStatePath" -ForegroundColor Yellow
Write-Host "Inventories Path: $SharedStatePath\inventories" -ForegroundColor Yellow
Write-Host ""

$inventoriesPath = Join-Path $SharedStatePath "inventories"

# Vérifier que le dossier inventories existe
if (-not (Test-Path $inventoriesPath)) {
    Write-Host "❌ ERREUR: Le dossier inventories n'existe pas : $inventoriesPath" -ForegroundColor Red
    exit 1
}

foreach ($machine in $machines) {
    Write-Host "🔍 Validation de $machine..." -ForegroundColor Cyan

    $inventoryPath = Join-Path $inventoriesPath "$machine.json"
    $machineResult = @{
        Machine = $machine
        Exists = $false
        ValidJSON = $false
        HasRequiredFields = $false
        PathsValid = $false
        Errors = @()
    }

    # 1. Vérifier existence
    if (Test-Path $inventoryPath) {
        $machineResult.Exists = $true
        Write-Host "  ✅ Fichier existe" -ForegroundColor Green

        try {
            # 2. Vérifier JSON valide
            $inventory = Get-Content $inventoryPath -Raw | ConvertFrom-Json
            $machineResult.ValidJSON = $true
            Write-Host "  ✅ JSON valide" -ForegroundColor Green

            # 3. Vérifier champs obligatoires (structure imbriquée)
            $missingFields = @()

            # machineId (top-level)
            if (-not $inventory.machineId) {
                $missingFields += "machineId"
            }

            # mcpServers (dans inventory)
            if (-not $inventory.inventory.mcpServers) {
                $missingFields += "inventory.mcpServers"
            }

            # rooModes (dans inventory)
            if (-not $inventory.inventory.rooModes) {
                $missingFields += "inventory.rooModes"
            }

            # rooExtensionsPath (dans paths)
            if (-not $inventory.paths.rooExtensions) {
                $missingFields += "paths.rooExtensions"
            }

            # mcpSettingsPath (dans paths)
            if (-not $inventory.paths.mcpSettings) {
                $missingFields += "paths.mcpSettings"
            }

            if ($missingFields.Count -eq 0) {
                $machineResult.HasRequiredFields = $true
                Write-Host "  ✅ Champs obligatoires présents" -ForegroundColor Green
            }
            else {
                $machineResult.Errors += "Champs manquants: $($missingFields -join ', ')"
                Write-Host "  ❌ Champs manquants: $($missingFields -join ', ')" -ForegroundColor Red
            }

            # 4. Vérifier machineId correspond
            if ($inventory.machineId -ne $machine) {
                $machineResult.Errors += "machineId incorrect: attendu '$machine', trouvé '$($inventory.machineId)'"
                Write-Host "  ❌ machineId incorrect" -ForegroundColor Red
            }
            else {
                Write-Host "  ✅ machineId correct" -ForegroundColor Green
            }

            # 5. Vérifier paths
            if ($inventory.paths.rooExtensions -and $inventory.paths.mcpSettings) {
                $machineResult.PathsValid = $true
                Write-Host "  ✅ Paths définis" -ForegroundColor Green
                Write-Host "    - rooExtensions: $($inventory.paths.rooExtensions)" -ForegroundColor Gray
                Write-Host "    - mcpSettings: $($inventory.paths.mcpSettings)" -ForegroundColor Gray
            }
            else {
                $machineResult.Errors += "Paths manquants ou invalides"
                Write-Host "  ❌ Paths manquants" -ForegroundColor Red
            }

            # 6. Vérifier MCP servers count
            if ($inventory.mcpServers) {
                $mcpCount = ($inventory.mcpServers | Measure-Object).Count
                Write-Host "  📊 MCP Servers: $mcpCount" -ForegroundColor Cyan
            }

            # 7. Vérifier Roo modes count
            if ($inventory.rooModes) {
                $modeCount = ($inventory.rooModes | Measure-Object).Count
                Write-Host "  📊 Roo Modes: $modeCount" -ForegroundColor Cyan
            }
        }
        catch {
            $machineResult.Errors += "Erreur parsing JSON: $_"
            Write-Host "  ❌ Erreur JSON: $_" -ForegroundColor Red
        }
    }
    else {
        $machineResult.Errors += "Fichier manquant"
        Write-Host "  ❌ Fichier manquant: $inventoryPath" -ForegroundColor Red
    }

    $results += $machineResult
    Write-Host ""
}

# Rapport final
Write-Host "======================================" -ForegroundColor Cyan
Write-Host "  RAPPORT FINAL" -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor Cyan
Write-Host ""

$totalMachines = $machines.Count
$validMachines = ($results | Where-Object { $_.Exists -and $_.ValidJSON -and $_.HasRequiredFields -and $_.PathsValid }).Count
$missingMachines = ($results | Where-Object { -not $_.Exists }).Count

Write-Host "📊 Statistiques:" -ForegroundColor Yellow
Write-Host "  - Machines totales: $totalMachines" -ForegroundColor White
Write-Host "  - Machines valides: $validMachines" -ForegroundColor Green
Write-Host "  - Machines manquantes: $missingMachines" -ForegroundColor $(if ($missingMachines -gt 0) { "Red" } else { "Green" })
Write-Host ""

Write-Host "📋 Détail par machine:" -ForegroundColor Yellow
foreach ($result in $results) {
    $status = if ($result.Exists -and $result.ValidJSON -and $result.HasRequiredFields -and $result.PathsValid) { "✅" } else { "❌" }
    Write-Host "  $status $($result.Machine)" -ForegroundColor $(if ($status -eq "✅") { "Green" } else { "Red" })

    if ($result.Errors.Count -gt 0) {
        foreach ($err in $result.Errors) {
            Write-Host "      - $err" -ForegroundColor Red
        }
    }
}
Write-Host ""

# Conclusion
if ($validMachines -eq $totalMachines) {
    Write-Host "✅ SUCCÈS: Tous les inventaires sont valides !" -ForegroundColor Green
    exit 0
}
else {
    Write-Host "❌ ÉCHEC: $($totalMachines - $validMachines) inventaire(s) invalide(s)" -ForegroundColor Red
    exit 1
}
