# modules/Core.psm1
Import-Module "$PSScriptRoot\Actions.psm1" -Force

function Invoke-SyncManager {
    param(
        [string]$SyncAction,
        [hashtable]$Parameters,
        [psobject]$Configuration
    )

    Write-Host "Action demandée : $SyncAction"
    Write-Host "Configuration chargée pour la version $($Configuration.version)"
    
    # Prépare les paramètres pour l'action
    $actionParams = @{
        Configuration = $Configuration
    }

    # Ajoute le contexte s'il est présent
    if ($Parameters.ContainsKey('LocalContext')) {
        $actionParams.Add('LocalContext', $Parameters['LocalContext'])
    }
    
    # Appelle dynamiquement l'action (ex: Compare-Config) avec les bons paramètres
    & $SyncAction @actionParams
}

function Get-LocalContext {
    [CmdletBinding()]
    param()

    # --- Computer Info ---
    $computerInfo = [PSCustomObject]@{
        OsName = $env:OS
        CsName = $env:COMPUTERNAME
        CsManufacturer = "N/A" # Get-ComputerInfo is too slow/buggy in jobs
        CsModel = "N/A"
    }

    # --- PowerShell Info ---
    $psInfo = @{
        version = $PSVersionTable.PSVersion.ToString()
        edition = $PSVersionTable.PSEdition
    }

    # --- Roo Environment ---
    $activeMcps = [System.Collections.Generic.List[string]]::new()
    $activeModes = [System.Collections.Generic.List[string]]::new()

    # Get Active MCPs from global settings
    $mcpSettingsPath = Join-Path $env:APPDATA "Code\User\globalStorage\rooveterinaryinc.roo-cline\settings\mcp_settings.json"
    if (Test-Path $mcpSettingsPath) {
        try {
            $mcpConfig = Get-Content -Path $mcpSettingsPath -Raw | ConvertFrom-Json
            if ($null -ne $mcpConfig.servers) {
                foreach ($server in $mcpConfig.servers) {
                    if ($server.enabled) {
                        $activeMcps.Add($server.name)
                    }
                }
            }
        } catch {
            Write-Warning "Failed to read or parse MCP settings file: $mcpSettingsPath. Error: $_"
        }
    }

    # Get Active Modes by merging global and local settings
    $localModesPath = "d:/roo-extensions/.roomodes"
    $globalModesPath = Join-Path $env:APPDATA "Code\User\globalStorage\rooveterinaryinc.roo-cline\settings\custom_modes.json"
    
    $mergedModes = @{} # Use a hashtable to handle precedence by slug

    # Read global modes first
    if (Test-Path $globalModesPath) {
        try {
            $globalConfig = Get-Content -Path $globalModesPath -Raw | ConvertFrom-Json
            if ($null -ne $globalConfig.customModes) {
                foreach ($mode in $globalConfig.customModes) {
                    $mergedModes[$mode.slug] = $mode
                }
            }
        } catch {
            Write-Warning "Failed to read or parse global Modes settings file: $globalModesPath. Error: $_"
        }
    }

    # Read local modes, which will overwrite global modes with the same slug
    if (Test-Path $localModesPath) {
        try {
            $localConfig = Get-Content -Path $localModesPath -Raw | ConvertFrom-Json
            if ($null -ne $localConfig.customModes) {
                foreach ($mode in $localConfig.customModes) {
                    $mergedModes[$mode.slug] = $mode
                }
            }
        } catch {
            Write-Warning "Failed to read or parse local Modes settings file: $localModesPath. Error: $_"
        }
    }

    # Populate the final list of active modes from the merged set
    foreach ($mode in $mergedModes.Values) {
        # Add if enabled is true or if the property doesn't exist (default to enabled)
        if ($null -eq $mode.PSObject.Properties['enabled'] -or $mode.enabled) {
            $activeModes.Add($mode.slug)
        }
    }

    $rooEnv = @{
        mcps     = $activeMcps
        modes    = $activeModes
        profiles = (Get-ChildItem -Path "d:/roo-extensions/profiles" -Directory).Name # Keep old logic for profiles for now
    }
    
    # --- Final Context Object ---
    $context = [PSCustomObject]@{
        timestamp       = (Get-Date).ToUniversalTime().ToString("o")
        computerInfo    = $computerInfo
        rooEnvironment  = $rooEnv
        powershell      = $psInfo
        defaultEncoding = [System.Text.Encoding]::Default.EncodingName
    }

    return $context
}

Export-ModuleMember -Function Invoke-SyncManager, Get-LocalContext