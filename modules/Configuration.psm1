# modules/Configuration.psm1
function Get-SyncConfiguration {
    [CmdletBinding()]
    param(
        [string]$Path = 'config/sync-config.json'
    )

    if (-not (Test-Path $Path)) {
        throw "Le fichier de configuration '$Path' est introuvable."
    }

    $content = Get-Content -Path $Path -Raw
    $error.Clear()
    $jsonOutput = $content | ConvertFrom-Json

    if ($error.Count -gt 0) {
        throw "Erreur lors de la lecture ou de l'analyse du fichier de configuration '$Path'. Assurez-vous qu'il s'agit d'un JSON valide."
    }

    return $jsonOutput
}

Export-ModuleMember -Function Get-SyncConfiguration