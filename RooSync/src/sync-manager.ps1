# sync-manager.ps1
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [ValidateSet('Pull', 'Push', 'Status', 'Resolve', 'Configure', 'Compare-Config', 'Initialize-Workspace', 'Apply-Decisions')]
    [string]$Action,

    [string]$Repository,
    [string]$Message,
    [switch]$Detailed,
    [string]$Strategy
)

# Import-Module "$PSScriptRoot\modules\Dashboard.psm1" -Force
# Définition de l'environnement et importations
$PSScriptRoot = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition
Import-Module "$PSScriptRoot\modules\Core.psm1" -Force

try {
    # Définir ROO_HOME si non-existant
    if (-not $env:ROO_HOME) {
        $env:ROO_HOME = 'd:/roo-extensions'
    }

    # Configuration
    $configPath = "$PSScriptRoot/../.config/sync-config.json"
    if (-not (Test-Path $configPath)) {
        throw "Le fichier de configuration '$configPath' est introuvable."
    }
    $configContent = (Get-Content -Path $configPath -Raw) -replace '\$\{ROO_HOME\}', $env:ROO_HOME
    $config = $configContent | ConvertFrom-Json

    # Charger la configuration depuis .env si le fichier existe
    $envFilePath = "$PSScriptRoot/../.env"
    if (Test-Path $envFilePath) {
        Get-Content $envFilePath | ForEach-Object {
            if ($_ -match "^\s*SHARED_STATE_PATH\s*=\s*(.*)") {
                $config.sharedStatePath = $Matches[1].Trim('"')
            }
        }
    }

    # Contexte local
    $localContext = Get-LocalContext
    
    # Création du dossier partagé si nécessaire
    if (-not (Test-Path $config.sharedStatePath -PathType Container)) {
        New-Item -Path $config.sharedStatePath -ItemType Directory -Force | Out-Null
    }

    # Dashboard
    $dashboardPath = "$($config.sharedStatePath)/sync-dashboard.json"
    if (Test-Path $dashboardPath) {
        $dashboard = Get-Content -Path $dashboardPath | ConvertFrom-Json
    } else {
        $dashboard = [PSCustomObject]@{ machineStates = @() }
    }
    
    # Assurer la robustesse de l'objet dashboard
    if ($null -eq $dashboard -or -not $dashboard.PSObject.Properties['machineStates']) {
        $dashboard = [PSCustomObject]@{ machineStates = @() }
    }

    $machineName = $localContext.computerInfo.CsName
    $machineState = $dashboard.machineStates | Where-Object { $_.machineName -eq $machineName }
    
    if (-not $machineState) {
        $machineState = [PSCustomObject]@{ machineName = $machineName }
        $dashboard.machineStates += $machineState
    }
    
    $machineState | Add-Member -MemberType NoteProperty -Name "lastContext" -Value $localContext -Force
    
    $dashboard | ConvertTo-Json -Depth 5 | Set-Content -Path $dashboardPath -Encoding Utf8

    # Mettre à jour le rapport
    # Rapport
    $reportPath = "$($config.sharedStatePath)/sync-report.md"
    $startMarker = "<!-- START: RUSH_SYNC_CONTEXT -->"
    $endMarker = "<!-- END: RUSH_SYNC_CONTEXT -->"

    $newReportBlock = @"
$startMarker
## 🖥️ Contexte de l'Exécution
| Catégorie | Information |
|---|---|
| **OS** | $($localContext.computerInfo.OsName) |
| **Machine** | $($localContext.computerInfo.CsName) ($($localContext.computerInfo.CsManufacturer) $($localContext.computerInfo.CsModel)) |
| **PowerShell** | $($localContext.powershell.version) ($($localContext.powershell.edition)) |
| **Encodage** | $($localContext.defaultEncoding) |

### Environnement Roo
#### MCPs Installés
$($localContext.rooEnvironment.mcps | ForEach-Object { "- $_" })

#### Modes Disponibles
$($localContext.rooEnvironment.modes | ForEach-Object { "- $_" })
$endMarker
"@

    if (Test-Path $reportPath) {
        $currentContent = Get-Content -Path $reportPath -Raw
        $regex = "(?s)$startMarker.*$endMarker"
        $updatedContent = [regex]::Replace($currentContent, $regex, "").Trim()
    } else {
        $updatedContent = ""
    }

    $finalContent = "$updatedContent`n`n$newReportBlock".Trim()
    Set-Content -Path $reportPath -Value $finalContent -Encoding Utf8

    # Remplace l'appel existant à Invoke-SyncManager
    $params = $PSBoundParameters
    $params.Add('LocalContext', $localContext)

    Invoke-SyncManager -SyncAction $Action -Parameters $params -Configuration $config
}
catch {
    # Gestion d'erreur basique pour le moment
    Write-Error "Une erreur critique est survenue: $_"
    exit 1
}