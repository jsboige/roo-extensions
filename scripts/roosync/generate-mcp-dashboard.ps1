# generate-mcp-dashboard.ps1
# Compare les MCPs entre les 5 machines et génère un dashboard
# Issue #345 - Dashboard diffs MCP 5 machines

param(
    [string]$Baseline = "myia-ai-01",
    [string]$OutputDir = "roo-config/shared-state/dashboards"
)

# Configuration
$Machines = @("myia-ai-01", "myia-po-2023", "myia-po-2024", "myia-po-2026", "myia-web1")
$Timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$OutputFile = Join-Path $OutputDir "mcp-dashboard-$Timestamp.md"

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

    # Essayer les trois formats de nom possibles
    $InventoryPath1 = "roo-config/shared-state/inventories/$MachineId-inventory.json"
    $InventoryPath2 = "roo-config/shared-state/inventories/machine-inventory-$MachineId.json"
    $InventoryPath3 = "roo-config/shared-state/inventories/$MachineId.json"

    return (Test-Path $InventoryPath1) -or (Test-Path $InventoryPath2) -or (Test-Path $InventoryPath3)
}

# Fonction pour extraire les diffs MCP depuis le résultat de compare_config
function Get-McpDiffs {
    param(
        [string]$Source,
        [string]$Target,
        [string]$Granularity = "mcp"
    )

    try {
        # Appeler l'outil roosync_compare_config via le MCP
        $result = mcp--roo___state___manager--roosync_compare_config `
            -source $Source `
            -target $Target `
            -granularity $Granularity `
            -force_refresh $false

        if ($result -and $result.diffs) {
            # Filtrer uniquement les diffs de type MCP
            $mcpDiffs = $result.diffs | Where-Object { $_.path -like "*mcp*" -or $_.category -eq "MCP" }

            return @{
                Success = $true
                TotalDiffs = $result.diffs.Count
                McpDiffs = $mcpDiffs.Count
                Details = $mcpDiffs
                RawResult = $result
            }
        } else {
            return @{
                Success = $true
                TotalDiffs = 0
                McpDiffs = 0
                Details = @()
                RawResult = $result
            }
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
            $diffResult = Get-McpDiffs -Source $Baseline -Target $Machine -Granularity "mcp"

            if ($diffResult.Success) {
                $diffCount = $diffResult.McpDiffs
                $Dashboard += "`n| $Machine | ✅ Disponible | $diffCount diffs |"
                Write-Host "  → $diffCount diffs MCP détectés" -ForegroundColor Green

                # Ajouter les détails des diffs
                if ($diffCount -gt 0) {
                    $Dashboard += "`n`n### Détails MCP - $Machine vs $Baseline`n`n"

                    foreach ($diff in $diffResult.Details) {
                        $severity = $diff.severity ?? "INFO"
                        $path = $diff.path ?? "N/A"
                        $type = $diff.type ?? "unknown"

                        $Dashboard += "- **[$severity]** `$path` ($type)`n"
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
