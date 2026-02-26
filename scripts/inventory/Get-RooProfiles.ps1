<#
.SYNOPSIS
    Collecte les profils de modèles Roo pour l'inventaire (#498)
.DESCRIPTION
    Script léger pour capturer model-configs.json et les profils actifs
.PARAMETER MachineId
    L'identifiant de la machine (par defaut: hostname)
.EXAMPLE
    .\Get-RooProfiles.ps1 -MachineId "myia-web1"
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$MachineId = $env:COMPUTERNAME.ToLower(),

    [Parameter(Mandatory=$false)]
    [string]$RooExtensionsPath = "c:\dev\roo-extensions"
)

$ErrorActionPreference = 'Stop'

Write-Host "Collecte des profils Roo pour: $MachineId" -ForegroundColor Cyan

# Chemin vers model-configs.json
$modelConfigsPath = "$RooExtensionsPath\roo-config\model-configs.json"

if (-not (Test-Path $modelConfigsPath)) {
    Write-Host "ERREUR: Fichier non trouve: $modelConfigsPath" -ForegroundColor Red
    exit 1
}

try {
    $modelConfigs = Get-Content $modelConfigsPath -Raw | ConvertFrom-Json

    # Créer l'objet de sortie
    $profiles = @{
        machineId = $MachineId
        timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
        profiles = @{}
        apiConfigs = @{}
        modeApiConfigs = @{}
        profileThresholds = $modelConfigs.profileThresholds
        notes = $modelConfigs.notes
    }

    # Capturer les profils disponibles
    foreach ($modelProfile in $modelConfigs.profiles) {
        $profiles.profiles[$modelProfile.name] = @{
            description = $modelProfile.description
            modeOverrides = $modelProfile.modeOverrides
        }
        Write-Host "  OK Profil: $($modelProfile.name)" -ForegroundColor Green
    }

    # Capturer les configurations API
    foreach ($config in $modelConfigs.apiConfigs.PSObject.Properties) {
        $profiles.apiConfigs[$config.Name] = @{
            apiProvider = $config.Value.apiProvider
            modelId = $config.Value.openAiModelId
            baseUrl = $config.Value.openAiBaseUrl
            description = $config.Value.description
        }
        Write-Host "  OK Config: $($config.Name) = $($config.Value.openAiModelId)" -ForegroundColor Green
    }

    # Capturer les mappings mode -> API config
    foreach ($mapping in $modelConfigs.modeApiConfigs.PSObject.Properties) {
        $profiles.modeApiConfigs[$mapping.Name] = $mapping.Value
    }

    # Sortie JSON
    $output = $profiles | ConvertTo-Json -Depth 10
    Write-Host "`nProfils collectes: $($profiles.profiles.Count), Configs API: $($profiles.apiConfigs.Count)" -ForegroundColor Cyan

    # Retourner l'objet JSON
    Write-Output $output

} catch {
    Write-Host "ERREUR: $_" -ForegroundColor Red
    exit 1
}
