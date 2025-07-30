# modules/Dashboard.psm1
function Get-SyncDashboard {
    [CmdletBinding()]
    param(
        [string]$Path = 'sync-dashboard.json' # Doit être un chemin partagé à terme
    )
    if (-not (Test-Path $Path)) {
        Write-Warning "Dashboard non trouvé à l'adresse '$Path'. Un état vide sera retourné."
        # On pourrait initialiser un dashboard vide ici si nécessaire
        return $null 
    }
    return Get-Content -Path $Path -Raw | ConvertFrom-Json
}

function Update-SyncDashboard {
    param(
        [psobject]$DashboardData,
        [string]$Path = 'sync-dashboard.json'
    )
    $DashboardData | ConvertTo-Json -Depth 5 | Set-Content -Path $Path
}

Export-ModuleMember -Function Get-SyncDashboard, Update-SyncDashboard