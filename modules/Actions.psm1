# modules/Actions.psm1
# Pour le moment, pas besoin d'importer d'autres modules ici

function Invoke-SyncStatusAction {
    [CmdletBinding()]
    param(
        [psobject]$Configuration,
        [hashtable]$Parameters
    )
    
    Write-Host "--- Début de l'action Status ---"
    
    $dashboard = Get-SyncDashboard
    if ($null -eq $dashboard) {
        Write-Host "Le dashboard est actuellement vide ou introuvable."
    } else {
        Write-Host "État du dashboard (version $($dashboard.version)):"
        $dashboard.environments | Format-Table -AutoSize
    }

    Write-Host "--- Fin de l'action Status ---"
}

Export-ModuleMember -Function Invoke-SyncStatusAction