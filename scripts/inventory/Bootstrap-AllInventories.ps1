<#
.SYNOPSIS
    Automatise le bootstrap des inventaires RooSync sur toutes les machines
.DESCRIPTION
    Vérifie l'existence des inventaires et les génère/régénère si nécessaire
.PARAMETER SharedStatePath
    Chemin vers le dossier .shared-state RooSync (défaut: depuis ROOSYNC_SHARED_PATH)
.PARAMETER Force
    Force la régénération même si l'inventaire existe
.PARAMETER MaxAge
    Âge maximum de l'inventaire en heures avant régénération (défaut: 24h)
.EXAMPLE
    .\Bootstrap-AllInventories.ps1
.EXAMPLE
    .\Bootstrap-AllInventories.ps1 -Force
.EXAMPLE
    .\Bootstrap-AllInventories.ps1 -MaxAge 12
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$SharedStatePath,

    [Parameter(Mandatory=$false)]
    [switch]$Force,

    [Parameter(Mandatory=$false)]
    [int]$MaxAge = 24
)

$ErrorActionPreference = 'Stop'

# ========================================
# CONFIGURATION
# ========================================

# Déterminer SharedStatePath
if (-not $SharedStatePath) {
    if ($env:ROOSYNC_SHARED_PATH) {
        $SharedStatePath = $env:ROOSYNC_SHARED_PATH
        Write-Host "  SharedStatePath depuis ROOSYNC_SHARED_PATH: $SharedStatePath" -ForegroundColor Gray
    } else {
        Write-Error "SharedStatePath non fourni et ROOSYNC_SHARED_PATH non défini"
        exit 1
    }
}

# Vérifier que SharedStatePath existe
if (-not (Test-Path $SharedStatePath)) {
    Write-Error "SharedStatePath n'existe pas: $SharedStatePath"
    exit 1
}

$InventoriesDir = Join-Path $SharedStatePath "inventories"
$GetInventoryScript = Join-Path $PSScriptRoot "Get-MachineInventory.ps1"

# Vérifier que Get-MachineInventory.ps1 existe
if (-not (Test-Path $GetInventoryScript)) {
    Write-Error "Script Get-MachineInventory.ps1 introuvable: $GetInventoryScript"
    exit 1
}

# Machine actuelle
$MachineId = $env:COMPUTERNAME.ToLower()

Write-Host "`n======================================" -ForegroundColor Cyan
Write-Host "  Bootstrap Inventaire RooSync" -ForegroundColor Cyan
Write-Host "======================================`n" -ForegroundColor Cyan

# ========================================
# FONCTIONS
# ========================================

function Test-InventoryExists {
    param([string]$MachineId)

    $inventoryPath = Join-Path $InventoriesDir "$MachineId.json"
    return (Test-Path $inventoryPath)
}

function Test-InventoryAge {
    param(
        [string]$MachineId,
        [int]$MaxAgeHours
    )

    $inventoryPath = Join-Path $InventoriesDir "$MachineId.json"

    if (-not (Test-Path $inventoryPath)) {
        return $false
    }

    $fileAge = (Get-Date) - (Get-Item $inventoryPath).LastWriteTime
    return ($fileAge.TotalHours -lt $MaxAgeHours)
}

function Test-InventoryValid {
    param([string]$InventoryPath)

    try {
        # Vérifier que le fichier est un JSON valide
        $content = Get-Content $InventoryPath -Raw | ConvertFrom-Json

        # Vérifier les champs requis
        $requiredFields = @('machineId', 'timestamp', 'inventory', 'paths')
        foreach ($field in $requiredFields) {
            if (-not $content.PSObject.Properties.Name.Contains($field)) {
                Write-Warning "  Champ requis manquant: $field"
                return $false
            }
        }

        # Vérifier que l'inventaire contient des données
        if (-not $content.inventory) {
            Write-Warning "  Inventaire vide"
            return $false
        }

        return $true
    }
    catch {
        Write-Warning "  Erreur de validation: $($_.Exception.Message)"
        return $false
    }
}

function Invoke-InventoryGeneration {
    param([string]$MachineId)

    Write-Host "`n  Génération inventaire pour $MachineId..." -ForegroundColor Yellow

    try {
        # Exécuter Get-MachineInventory.ps1
        $result = & $GetInventoryScript -MachineId $MachineId -SharedStatePath $SharedStatePath

        $inventoryPath = Join-Path $InventoriesDir "$MachineId.json"

        # Valider le fichier généré
        if ((Test-Path $inventoryPath) -and (Test-InventoryValid -InventoryPath $inventoryPath)) {
            Write-Host "  ✅ Inventaire généré et validé: $inventoryPath" -ForegroundColor Green
            return $true
        } else {
            Write-Host "  ❌ Inventaire généré mais validation échouée" -ForegroundColor Red
            return $false
        }
    }
    catch {
        Write-Host "  ❌ Erreur génération: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# ========================================
# TRAITEMENT PRINCIPAL
# ========================================

Write-Host "Machine: $MachineId" -ForegroundColor Cyan
Write-Host "SharedStatePath: $SharedStatePath" -ForegroundColor Gray
Write-Host "InventoriesDir: $InventoriesDir`n" -ForegroundColor Gray

# Créer le dossier inventories si nécessaire
if (-not (Test-Path $InventoriesDir)) {
    Write-Host "  Création dossier inventories..." -ForegroundColor Yellow
    New-Item -ItemType Directory -Path $InventoriesDir -Force | Out-Null
}

$needsGeneration = $false
$reason = ""

# Vérifier si génération nécessaire
if ($Force) {
    $needsGeneration = $true
    $reason = "Force activé"
}
elseif (-not (Test-InventoryExists -MachineId $MachineId)) {
    $needsGeneration = $true
    $reason = "Inventaire inexistant"
}
elseif (-not (Test-InventoryAge -MachineId $MachineId -MaxAgeHours $MaxAge)) {
    $needsGeneration = $true
    $reason = "Inventaire obsolète (> $MaxAge heures)"
}
else {
    $inventoryPath = Join-Path $InventoriesDir "$MachineId.json"
    if (-not (Test-InventoryValid -InventoryPath $inventoryPath)) {
        $needsGeneration = $true
        $reason = "Inventaire invalide"
    }
}

# Générer ou reporter statut
if ($needsGeneration) {
    Write-Host "  Raison: $reason" -ForegroundColor Yellow
    $success = Invoke-InventoryGeneration -MachineId $MachineId

    if ($success) {
        Write-Host "`n✅ Bootstrap complété avec succès" -ForegroundColor Green
        exit 0
    } else {
        Write-Host "`n❌ Bootstrap échoué" -ForegroundColor Red
        exit 1
    }
}
else {
    $inventoryPath = Join-Path $InventoriesDir "$MachineId.json"
    $fileAge = (Get-Date) - (Get-Item $inventoryPath).LastWriteTime

    Write-Host "  ✅ Inventaire valide existant" -ForegroundColor Green
    Write-Host "  Chemin: $inventoryPath" -ForegroundColor Gray
    Write-Host "  Âge: $([Math]::Round($fileAge.TotalHours, 1)) heures" -ForegroundColor Gray
    Write-Host "`n✅ Aucune action nécessaire" -ForegroundColor Green
    exit 0
}
