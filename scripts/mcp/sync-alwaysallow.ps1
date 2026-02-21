<#
.SYNOPSIS
    Synchronise les alwaysAllow MCP depuis une configuration de reference

.DESCRIPTION
    Ce script lit la configuration de reference et met a jour le fichier
    mcp_settings.json de Roo pour auto-approuver tous les outils listes.

.PARAMETER ReferencePath
    Chemin vers le fichier de reference JSON (defaut: roo-config/mcp/reference-alwaysallow.json)

.PARAMETER Backup
    Creer une sauvegarde avant modification (defaut: true)

.PARAMETER DryRun
    Simuler les changements sans modifier les fichiers

.EXAMPLE
    .\sync-alwaysallow.ps1
    .\sync-alwaysallow.ps1 -DryRun
    .\sync-alwaysallow.ps1 -ReferencePath "custom-reference.json"

.NOTES
    Issue #496: Auto-approbation complete des outils Roo
#>

param(
    [string]$ReferencePath = "$PSScriptRoot\..\..\roo-config\mcp\reference-alwaysallow.json",
    [bool]$Backup = $true,
    [bool]$DryRun = $false
)

$ErrorActionPreference = "Stop"

# Chemin vers les settings Roo
$RooSettingsPath = "$env:APPDATA\Code\User\globalStorage\rooveterinaryinc.roo-cline\settings\mcp_settings.json"

Write-Host "=== Sync AlwaysAllow MCP ===" -ForegroundColor Cyan
Write-Host "Reference: $ReferencePath"
Write-Host "Target: $RooSettingsPath"
Write-Host "Backup: $Backup"
Write-Host "DryRun: $DryRun"
Write-Host ""

# Verifier que les fichiers existent
if (-not (Test-Path $ReferencePath)) {
    Write-Error "Fichier de reference non trouve: $ReferencePath"
    exit 1
}

if (-not (Test-Path $RooSettingsPath)) {
    Write-Error "Fichier settings Roo non trouve: $RooSettingsPath"
    exit 1
}

# Charger les configurations
$reference = Get-Content $ReferencePath -Raw | ConvertFrom-Json
$settings = Get-Content $RooSettingsPath -Raw | ConvertFrom-Json

# Statistiques
$totalAdded = 0
$totalRemoved = 0
$serversProcessed = 0
$changes = @()

# Parcourir chaque serveur dans la reference
foreach ($serverName in $reference.mcpServers.PSObject.Properties.Name) {
    $refTools = $reference.mcpServers.$serverName.alwaysAllow
    $currentTools = @()

    # Verifier si le serveur existe dans les settings actuels
    if ($settings.mcpServers.$serverName) {
        $currentTools = $settings.mcpServers.$serverName.alwaysAllow
        if (-not $currentTools) { $currentTools = @() }
    } else {
        Write-Host "  [SKIP] $serverName - non installe sur cette machine" -ForegroundColor DarkGray
        continue
    }

    # Calculer les differences
    $added = $refTools | Where-Object { $_ -notin $currentTools }
    $removed = $currentTools | Where-Object { $_ -notin $refTools }

    if ($added.Count -gt 0 -or $removed.Count -gt 0) {
        $serversProcessed++
        $totalAdded += $added.Count
        $totalRemoved += $removed.Count

        $changeInfo = @{
            Server = $serverName
            Added = $added
            Removed = $removed
            Before = $currentTools.Count
            After = $refTools.Count
        }
        $changes += $changeInfo

        Write-Host "  [$serverName] $($currentTools.Count) -> $($refTools.Count) outils" -ForegroundColor Yellow
        if ($added.Count -gt 0) {
            Write-Host "    + Ajoutes: $($added -join ', ')" -ForegroundColor Green
        }
        if ($removed.Count -gt 0) {
            Write-Host "    - Retires: $($removed -join ', ')" -ForegroundColor Red
        }

        # Appliquer les changements si pas DryRun
        if (-not $DryRun) {
            $settings.mcpServers.$serverName.alwaysAllow = $refTools
        }
    } else {
        Write-Host "  [OK] $serverName - $($currentTools.Count) outils (aucun changement)" -ForegroundColor Green
    }
}

Write-Host ""
Write-Host "=== Resume ===" -ForegroundColor Cyan
Write-Host "Serveurs modifies: $serversProcessed"
Write-Host "Outils ajoutes: $totalAdded"
Write-Host "Outils retires: $totalRemoved"

if ($DryRun) {
    Write-Host ""
    Write-Host "*** MODE DRYRUN - Aucun changement applique ***" -ForegroundColor Magenta
} else {
    if ($serversProcessed -gt 0) {
        # Backup si demande
        if ($Backup) {
            $backupPath = "$RooSettingsPath.backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
            Copy-Item $RooSettingsPath $backupPath
            Write-Host "Backup cree: $backupPath" -ForegroundColor DarkGray
        }

        # Sauvegarder les changements
        $settings | ConvertTo-Json -Depth 10 | Set-Content $RooSettingsPath -Encoding UTF8
        Write-Host ""
        Write-Host "Settings mis a jour avec succes!" -ForegroundColor Green
        Write-Host "Redemarrez VS Code pour appliquer les changements." -ForegroundColor Yellow
    } else {
        Write-Host ""
        Write-Host "Aucun changement necessaire - configuration deja a jour." -ForegroundColor Green
    }
}
