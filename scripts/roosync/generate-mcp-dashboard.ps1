# generate-mcp-dashboard.ps1
# Compare les MCPs entre les 5 machines et génère un dashboard
# Issue #345 - Dashboard diffs MCP 5 machines

param(
    [string]$Baseline = "myia-ai-01",
    [string]$OutputDir = $null  # Sera déterminé depuis $env:ROOSYNC_SHARED_PATH
)

# CORRECTION Bug #368: Utiliser ROOSYNC_SHARED_PATH depuis l'environnement, JAMAIS de chemin local dans le dépôt
if (-not $OutputDir) {
    if (-not $env:ROOSYNC_SHARED_PATH) {
        Write-Error "ROOSYNC_SHARED_PATH non configuré - impossible de générer le dashboard"
        exit 1
    }
    $OutputDir = Join-Path $env:ROOSYNC_SHARED_PATH "dashboards"
}

# Configuration
$Machines = @("myia-ai-01", "myia-po-2023", "myia-po-2024", "myia-po-2026", "myia-web1")
# Fichier fixe (plus de timestamp) - Issue #xxx Plan "Écuries d'Augias"
$OutputFile = Join-Path $OutputDir "DASHBOARD.md"

# Créer le répertoire de sortie si nécessaire
if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}

Write-Host "=== Génération du Dashboard MCP ===" -ForegroundColor Cyan
Write-Host "Baseline: $Baseline" -ForegroundColor Yellow
Write-Host "Machines: $($Machines -join ', ')" -ForegroundColor Yellow
Write-Host "Output: $OutputFile" -ForegroundColor Yellow
Write-Host ""

# Initialiser le contenu du dashboard
$Dashboard = @"
# Dashboard MCP - Comparaison des Configurations

**Généré:** $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
**Baseline:** $Baseline
**Granularité:** MCP uniquement

---

## Résumé

| Machine | Status Inventaire | Diffs MCP vs Baseline |
|---------|-------------------|----------------------|
"@

# Fonction pour vérifier si un inventaire existe
function Test-InventoryExists {
    param([string]$MachineId)

    # CORRECTION Bug #368: Utiliser ROOSYNC_SHARED_PATH, pas de chemin local
    $InventoriesDir = Join-Path $env:ROOSYNC_SHARED_PATH "inventories"

    # Essayer les trois formats de nom possibles
    $InventoryPath1 = Join-Path $InventoriesDir "$MachineId-inventory.json"
    $InventoryPath2 = Join-Path $InventoriesDir "machine-inventory-$MachineId.json"
    $InventoryPath3 = Join-Path $InventoriesDir "$MachineId.json"

    return (Test-Path $InventoryPath1) -or (Test-Path $InventoryPath2) -or (Test-Path $InventoryPath3)
}

# Fonction pour lire un inventaire de machine
function Get-MachineInventory {
    param([string]$MachineId)

    $InventoriesDir = Join-Path $env:ROOSYNC_SHARED_PATH "inventories"

    # Essayer les trois formats de nom possibles
    $InventoryPath1 = Join-Path $InventoriesDir "$MachineId-inventory.json"
    $InventoryPath2 = Join-Path $InventoriesDir "machine-inventory-$MachineId.json"
    $InventoryPath3 = Join-Path $InventoriesDir "$MachineId.json"

    $inventoryPath = $null
    if (Test-Path $InventoryPath1) { $inventoryPath = $InventoryPath1 }
    elseif (Test-Path $InventoryPath2) { $inventoryPath = $InventoryPath2 }
    elseif (Test-Path $InventoryPath3) { $inventoryPath = $InventoryPath3 }

    if ($inventoryPath) {
        try {
            $content = Get-Content $inventoryPath -Raw | ConvertFrom-Json
            return $content
        } catch {
            Write-Host "Erreur lors de la lecture de l'inventaire ${MachineId}: $($_)" -ForegroundColor Red
            return $null
        }
    }
    return $null
}

# Fonction pour comparer les configurations MCP entre deux machines
function Get-McpDiffs {
    param(
        [string]$Source,
        [string]$Target
    )

    try {
        # Lire les inventaires
        $sourceInventory = Get-MachineInventory -MachineId $Source
        $targetInventory = Get-MachineInventory -MachineId $Target

        if (-not $sourceInventory) {
            return @{
                Success = $false
                Error = "Inventaire source introuvable: $Source"
            }
        }

        if (-not $targetInventory) {
            return @{
                Success = $false
                Error = "Inventaire cible introuvable: $Target"
            }
        }

        # Extraire les configurations MCP (tableau d'objets)
        $sourceMcps = $sourceInventory.inventory.mcpServers
        $targetMcps = $targetInventory.inventory.mcpServers

        $diffs = @()

        # Créer des dictionnaires par nom de MCP
        $sourceMcpDict = @{}
        foreach ($mcp in $sourceMcps) {
            $sourceMcpDict[$mcp.name] = $mcp
        }

        $targetMcpDict = @{}
        foreach ($mcp in $targetMcps) {
            $targetMcpDict[$mcp.name] = $mcp
        }

        # Comparer les serveurs MCP
        $allMcpNames = @($sourceMcpDict.Keys) + @($targetMcpDict.Keys) | Sort-Object -Unique

        foreach ($mcpName in $allMcpNames) {
            $sourceMcp = $sourceMcpDict[$mcpName]
            $targetMcp = $targetMcpDict[$mcpName]

            if (-not $sourceMcp) {
                # MCP présent uniquement dans la cible
                $diffs += @{
                    path = "inventory.mcpServers.$mcpName"
                    type = "added"
                    severity = "INFO"
                    description = "MCP '$mcpName' présent uniquement sur $Target"
                }
            } elseif (-not $targetMcp) {
                # MCP présent uniquement dans la source
                $diffs += @{
                    path = "inventory.mcpServers.$mcpName"
                    type = "removed"
                    severity = "WARNING"
                    description = "MCP '$mcpName' présent uniquement sur $Source"
                }
            } else {
                # Comparer les propriétés du MCP
                $sourceValue = $sourceMcp | ConvertTo-Json -Compress
                $targetValue = $targetMcp | ConvertTo-Json -Compress

                if ($sourceValue -ne $targetValue) {
                    $diffs += @{
                        path = "inventory.mcpServers.$mcpName"
                        type = "modified"
                        severity = "INFO"
                        description = "MCP '$mcpName' diffère entre $Source et $Target"
                    }
                }
            }
        }

        return @{
            Success = $true
            TotalDiffs = $diffs.Count
            McpDiffs = $diffs.Count
            Details = $diffs
        }
    } catch {
        Write-Host "Erreur lors de la comparaison ${Source} vs ${Target}: $_" -ForegroundColor Red
        return @{
            Success = $false
            Error = $_.Exception.Message
        }
    }
}

# Traiter chaque machine
foreach ($Machine in $Machines) {
    Write-Host "Traitement de $Machine..." -ForegroundColor Cyan

    if ($Machine -eq $Baseline) {
        # Machine baseline
        $Dashboard += "`n| $Machine | ✅ Baseline | - |"
        Write-Host "  → Baseline (pas de comparaison)" -ForegroundColor Green
    } else {
        # Vérifier l'inventaire
        $hasInventory = Test-InventoryExists -MachineId $Machine

        if (-not $hasInventory) {
            # Inventaire manquant
            $Dashboard += "`n| $Machine | ❌ Inventaire manquant | Bootstrap requis |"
            Write-Host "  → Inventaire manquant" -ForegroundColor Yellow
        } else {
            # Comparer avec la baseline
            Write-Host "  → Comparaison avec $Baseline..." -ForegroundColor Yellow
            $diffResult = Get-McpDiffs -Source $Baseline -Target $Machine

            if ($diffResult.Success) {
                $diffCount = $diffResult.McpDiffs
                $Dashboard += "`n| $Machine | ✅ Disponible | $diffCount diffs |"
                Write-Host "  → $diffCount diffs MCP détectés" -ForegroundColor Green

                # Ajouter les détails des diffs avec actions recommandées
                if ($diffCount -gt 0) {
                    $Dashboard += "`n`n### $Machine - $diffCount diffs vs $Baseline`n`n"
                    $Dashboard += "| Élément | Type | Recommandation |`n"
                    $Dashboard += "|---------|------|----------------|`n"

                    $mcpNames = @()
                    foreach ($diff in $diffResult.Details) {
                        # Extraire le nom du MCP depuis le path
                        $mcpName = if ($diff.path -match 'mcpServers\.(.+)$') { $matches[1] } else { "unknown" }
                        $diffType = if ($diff.type) { $diff.type } else { "unknown" }

                        $action = switch ($diffType) {
                            "removed" { "Installer depuis baseline" }
                            "added" { "À évaluer (absent baseline)" }
                            "modified" { "Aligner sur baseline" }
                            default { "À vérifier" }
                        }

                        $Dashboard += "| ``$mcpName`` | $diffType | $action |`n"
                        if ($diffType -in @("removed", "modified")) {
                            $mcpNames += "mcp:$mcpName"
                        }
                    }

                    # Ajouter la commande prête à exécuter
                    if ($mcpNames.Count -gt 0) {
                        $targets = $mcpNames -join '", "'
                        $Dashboard += "`n**Commande pour aligner sur baseline:**`n"
                        $Dashboard += "``````powershell`n"
                        $Dashboard += "roosync_apply_config({ targets: [""$targets""], machineId: ""$Baseline"" })`n"
                        $Dashboard += "```````n"
                    }
                }
            } else {
                $Dashboard += "`n| $Machine | ⚠️ Erreur comparaison | $($diffResult.Error) |"
                Write-Host "  → Erreur: $($diffResult.Error)" -ForegroundColor Red
            }
        }
    }
}

# Ajouter les métadonnées
$Dashboard += @"

---

## Métriques

| Métrique | Valeur |
|----------|--------|
| **Machines analysées** | $($Machines.Count) |
| **Machines avec inventaire** | $(($Machines | Where-Object { Test-InventoryExists -MachineId $_ }).Count) |
| **Machines sans inventaire** | $(($Machines | Where-Object { -not (Test-InventoryExists -MachineId $_) }).Count) |
| **Baseline** | $Baseline |

---

## Notes

- Les machines sans inventaire nécessitent un bootstrap via `roosync_get_machine_inventory`
- Les diffs MCP uniquement sont affichés (granularité `mcp`)
- Pour voir tous les diffs, utiliser `compare_config` avec granularité `full`

---

**Script:** `scripts/roosync/generate-mcp-dashboard.ps1`
**Issue:** #345
"@

# Écrire le fichier
$Dashboard | Out-File -FilePath $OutputFile -Encoding UTF8

Write-Host ""
Write-Host "=== Dashboard généré avec succès ===" -ForegroundColor Green
Write-Host "Fichier: $OutputFile" -ForegroundColor Yellow
Write-Host ""
