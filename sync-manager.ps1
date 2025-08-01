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

Import-Module "$PSScriptRoot\modules\Dashboard.psm1" -Force
$PSScriptRoot = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition
Import-Module "$PSScriptRoot\modules\Core.psm1" -Force
Import-Module "$PSScriptRoot\modules\Configuration.psm1" -Force
Import-Module "$PSScriptRoot\modules\Dashboard.psm1" -Force

try {
    $localContext = Get-LocalContext
    $config = Resolve-AppConfiguration
    
    # Mettre à jour le dashboard
    $dashboardPath = Join-Path $config.sharedStatePath "sync-dashboard.json"
    if (Test-Path $dashboardPath) {
        $dashboard = Get-Content -Path $dashboardPath | ConvertFrom-Json
    } else {
        $dashboard = [PSCustomObject]@{ machineStates = @() }
    }
    
    $machineName = $localContext.computerInfo.CsName
    $machineState = $dashboard.machineStates | Where-Object { $_.machineName -eq $machineName }
    
    if (-not $machineState) {
        $machineState = [PSCustomObject]@{ machineName = $machineName }
        $dashboard.machineStates += $machineState
    }
    
    $machineState | Add-Member -MemberType NoteProperty -Name "lastContext" -Value $localContext -Force
    
    $dashboard | ConvertTo-Json -Depth 5 | Set-Content -Path $dashboardPath

    # Mettre à jour le rapport
    $reportPath = Join-Path $config.sharedStatePath "sync-report.md"
    $reportHeader = "## 🖥️ Contexte de l'Exécution"
    $reportContent = @"
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
"@
    
    # Ajoute ou met à jour la section dans le rapport
    # (Cette logique est simplifiée, une implémentation plus robuste rechercherait et remplacerait la section)
    Add-Content -Path $reportPath -Value "`n$reportHeader`n$reportContent"

    Invoke-SyncManager -SyncAction $Action -Parameters $PSBoundParameters
}
catch {
    # Gestion d'erreur basique pour le moment
    Write-Error "Une erreur critique est survenue: $_"
    exit 1
}