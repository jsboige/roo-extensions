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

# #4131 G-INV : la génération ne publie plus le fichier sur G:. Elle produit un
# JSON LOCAL que le CLI RSM pousse dans PG (ligne `inventory:{machineId}`) ; le
# repli miroir G: est décidé par le service lui-même, pas ici. Chemin résolu
# depuis la racine du dépôt — ce script vit dans <repo>/scripts/inventory.
$RepoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$SaveInventoryScript = Join-Path $RepoRoot "mcps\internal\servers\roo-state-manager\scripts\rsm-inventory-save.mjs"

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

    # #4131 G-INV — fail-closed. Sans le CLI, on n'écrit PAS sur G: en direct :
    # le service est la seule surface de publication (PG d'abord, miroir en
    # repli). Un repli direct recréerait l'écrivain hors RSM que le grain ferme.
    if (-not (Test-Path $SaveInventoryScript)) {
        Write-Host "  ❌ CLI RSM introuvable: $SaveInventoryScript" -ForegroundColor Red
        Write-Host "     fail-closed : aucune écriture G: directe (#4131 G-INV)" -ForegroundColor Red
        return $false
    }

    $localPath = Join-Path (Join-Path $env:TEMP "rsm-inventory") "$MachineId.json"

    try {
        # Collecte LOCALE : -OutputPath seul, plus de -SharedStatePath — c'est le
        # paramètre -OutputPath qui était mort avant #4131 (clobber ligne 35).
        $null = & $GetInventoryScript -MachineId $MachineId -OutputPath $localPath

        if (-not ((Test-Path $localPath) -and (Test-InventoryValid -InventoryPath $localPath))) {
            Write-Host "  ❌ Inventaire local généré mais validation échouée: $localPath" -ForegroundColor Red
            return $false
        }
        Write-Host "  ✅ Inventaire local validé: $localPath" -ForegroundColor Green

        # Publication PG-first par le service. Son verdict JSON (pgSaved /
        # mirrorSaved) reste dans le journal ; c'est le code de sortie qui tranche.
        $publishOutput = & node $SaveInventoryScript --file $localPath
        $publishExit = $LASTEXITCODE
        $publishOutput | ForEach-Object { Write-Host "    $_" -ForegroundColor Gray }

        if ($publishExit -ne 0) {
            Write-Host "  ❌ Publication refusée (exit $publishExit) — voir la sortie ci-dessus" -ForegroundColor Red
            return $false
        }

        Write-Host "  ✅ Inventaire publié par RSM (#4131 G-INV)" -ForegroundColor Green
        return $true
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

    # ========================================
    # LOCKFILE GUARD — double-fire protection
    # ========================================
    # Two concurrent Bootstrap runs would both write inventories/{machineId}.json
    # during the ~32s collection, risking a partial-write corruption (a manual run
    # colliding with the daily scheduled task during debugging). The PID lockfile
    # serializes generation. Stale locks (holder process no longer alive, e.g. after
    # a crash or kill) are reclaimed automatically.
    $lockFile = Join-Path $env:TEMP "roosync-inventory-bootstrap.lock"
    if (Test-Path $lockFile) {
        $lockPid = 0
        try { $lockPid = [int]((Get-Content $lockFile -Raw).Trim()) } catch {}
        $holderAlive = ($lockPid -gt 0) -and ($null -ne (Get-Process -Id $lockPid -ErrorAction SilentlyContinue))
        if ($holderAlive) {
            Write-Host "  Another Bootstrap run in progress (PID $lockPid). Skipping to avoid concurrent write." -ForegroundColor Yellow
            exit 0
        }
        Write-Host "  Stale lockfile (PID $lockPid not alive). Reclaiming." -ForegroundColor Gray
    }
    [System.IO.File]::WriteAllText($lockFile, "$PID", [System.Text.UTF8Encoding]::new($false))

    try {
        $success = Invoke-InventoryGeneration -MachineId $MachineId
    } finally {
        Remove-Item $lockFile -Force -ErrorAction SilentlyContinue
    }

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
