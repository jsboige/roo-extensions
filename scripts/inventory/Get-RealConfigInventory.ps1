# scripts/inventory/Get-RealConfigInventory.ps1
param(
    [string]$MachineId = $env:COMPUTERNAME.ToLower()
)

$ErrorActionPreference = "Stop"
$RootPath = Resolve-Path "$PSScriptRoot/../.."
$RooSyncPath = Join-Path $RootPath "RooSync"
$InventoriesPath = Join-Path $RooSyncPath "shared/inventories"

# Création du répertoire d'inventaire si nécessaire
if (-not (Test-Path $InventoriesPath)) {
    New-Item -Path $InventoriesPath -ItemType Directory -Force | Out-Null
}

$Inventory = @{
    machineId = $MachineId
    timestamp = (Get-Date).ToUniversalTime().ToString("o")
    config = @{
        mcp = @{}
        modes = @{}
        settings = @{}
        profiles = @{}
    }
}

# 1. MCP Settings
$McpSettingsPath = Join-Path $env:APPDATA "Code\User\globalStorage\rooveterinaryinc.roo-cline\settings\mcp_settings.json"
if (Test-Path $McpSettingsPath) {
    Write-Host "Reading MCP settings from $McpSettingsPath"
    try {
        $mcpContent = Get-Content $McpSettingsPath -Raw | ConvertFrom-Json
        $Inventory.config.mcp = $mcpContent
    } catch {
        Write-Warning "Failed to parse MCP settings: $_"
        $Inventory.config.mcp = @{ error = $_.ToString() }
    }
} else {
    Write-Warning "MCP settings not found at $McpSettingsPath"
}

# 2. Modes (Global & Local)
# Global
$GlobalModesPath = Join-Path $env:APPDATA "Code\User\globalStorage\rooveterinaryinc.roo-cline\settings\custom_modes.json"
if (Test-Path $GlobalModesPath) {
    Write-Host "Reading Global Modes from $GlobalModesPath"
    try {
        $modesContent = Get-Content $GlobalModesPath -Raw | ConvertFrom-Json
        $Inventory.config.modes.global = $modesContent
    } catch {
         Write-Warning "Failed to parse Global Modes: $_"
         $Inventory.config.modes.global = @{ error = $_.ToString() }
    }
}

# Local (roo-config)
$LocalModesPath = Join-Path $RootPath "roo-config/settings/modes.json"
if (Test-Path $LocalModesPath) {
    Write-Host "Reading Local Modes from $LocalModesPath"
    try {
        $modesContent = Get-Content $LocalModesPath -Raw | ConvertFrom-Json
        $Inventory.config.modes.local = $modesContent
    } catch {
         Write-Warning "Failed to parse Local Modes: $_"
         $Inventory.config.modes.local = @{ error = $_.ToString() }
    }
}

# 3. Roo Settings (roo-config/settings.json)
$RooSettingsPath = Join-Path $RootPath "roo-config/settings/settings.json"
if (Test-Path $RooSettingsPath) {
    Write-Host "Reading Roo Settings from $RooSettingsPath"
    try {
        $settingsContent = Get-Content $RooSettingsPath -Raw | ConvertFrom-Json
        $Inventory.config.settings = $settingsContent
    } catch {
        Write-Warning "Failed to parse Roo Settings: $_"
        $Inventory.config.settings = @{ error = $_.ToString() }
    }
}

# 4. Profiles
$ProfilesPath = Join-Path $RootPath "profiles"
if (Test-Path $ProfilesPath) {
    Write-Host "Scanning Profiles in $ProfilesPath"
    $profiles = Get-ChildItem -Path $ProfilesPath -Filter "*.ps1" -Recurse
    foreach ($profile in $profiles) {
        $relPath = $profile.FullName.Replace("$ProfilesPath\", "")
        $Inventory.config.profiles[$relPath] = @{
            content = Get-Content $profile.FullName -Raw
            lastModified = $profile.LastWriteTime.ToString("o")
        }
    }
}

# Sauvegarde
$OutputFile = Join-Path $InventoriesPath "$MachineId.json"
$Inventory | ConvertTo-Json -Depth 10 | Set-Content -Path $OutputFile -Encoding UTF8
Write-Host "Inventory saved to $OutputFile"
