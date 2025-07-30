# modules/Core.psm1
Import-Module (Join-Path (Split-Path $MyInvocation.MyCommand.Path) 'Actions.psm1') -Force

function Invoke-SyncManager {
    param(
        [string]$SyncAction,
        [hashtable]$Parameters
    )

    Write-Host "Action demandée : $SyncAction"
    $config = Get-SyncConfiguration
    Write-Host "Configuration chargée pour la version $($config.version)"
    
    switch ($SyncAction) {
        'Status' {
            Invoke-SyncStatusAction -Configuration $config -Parameters $Parameters
        }
        default {
            Write-Warning "L'action '$SyncAction' n'est pas encore implémentée."
        }
    }
}

Export-ModuleMember -Function Invoke-SyncManager