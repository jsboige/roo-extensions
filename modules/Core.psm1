# modules/Core.psm1
Import-Module (Join-Path (Split-Path $MyInvocation.MyCommand.Path) 'Actions.psm1') -Force

function Invoke-SyncManager {
    param(
        [string]$SyncAction,
        [hashtable]$Parameters
    )

    Write-Host "Action demandée : $SyncAction"
    $config = Resolve-AppConfiguration
    Write-Host "Configuration chargée pour la version $($config.version)"
    
    # Prépare les paramètres pour l'action
    $actionParams = @{
        Configuration = $config # $config est résolu à l'intérieur
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

    $computerInfo = Get-ComputerInfo | Select-Object -Property OsName, CsName, CsManufacturer, CsModel
    
    $rooEnv = @{
        mcps     = (Get-ChildItem -Path "d:/roo-extensions/mcps" -Directory).Name
        modes    = (Get-ChildItem -Path "d:/roo-extensions/roo-modes" -Directory).Name
        profiles = (Get-ChildItem -Path "d:/roo-extensions/profiles" -Directory).Name
    }

    $psInfo = @{
        version = $PSVersionTable.PSVersion
        edition = $PSVersionTable.PSEdition
    }

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