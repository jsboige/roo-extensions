# modules/Configuration.psm1

function Resolve-AppConfiguration {
    [CmdletBinding()]
    param(
        [string]$ConfigPath = 'config/sync-config.json',
        [string]$EnvPath = '.env'
    )

    # 1. Lire le fichier de configuration principal
    if (-not (Test-Path $ConfigPath)) {
        throw "Le fichier de configuration '$ConfigPath' est introuvable."
    }
    $rawContent = Get-Content -Path $ConfigPath -Raw

    # 2. Charger les variables .env et les substituer dans le contenu brut
    $resolvedContent = $rawContent
    if (Test-Path $EnvPath) {
        Get-Content $EnvPath | ForEach-Object {
            $key, $value = $_.Split('=', 2)
            if ($key -and $value) {
                $placeholder = "%$($key.Trim())%"
                # Échapper les antislashs pour le JSON et supprimer les guillemets
                $jsonSafeValue = $value.Trim().Trim('"').Replace('\', '\\')
                $resolvedContent = $resolvedContent.Replace($placeholder, $jsonSafeValue)
            }
        }
    }

    # 3. Parser le JSON résolu
    $configObject = $resolvedContent | ConvertFrom-Json -ErrorAction Stop
    
    return $configObject
}

Export-ModuleMember -Function Resolve-AppConfiguration