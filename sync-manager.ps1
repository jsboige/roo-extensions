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
    Set-Content -Path $reportPath -Value $finalContent

    # Remplace l'appel existant à Invoke-SyncManager
    $params = $PSBoundParameters
    $params.Add('LocalContext', $localContext)

    Invoke-SyncManager -SyncAction $Action -Parameters $params
}
catch {
    # Gestion d'erreur basique pour le moment
    Write-Error "Une erreur critique est survenue: $_"
    exit 1
}