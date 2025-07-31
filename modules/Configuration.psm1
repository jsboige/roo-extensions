# modules/Configuration.psm1

function Resolve-AppConfiguration {
    [CmdletBinding()]
    param(
        [string]$ConfigPath = 'config/sync-config.json',
        [string]$EnvPath = '.env'
    )

    # 1. Charger les variables d'environnement depuis .env
    if (Test-Path $EnvPath) {
        Get-Content $EnvPath | ForEach-Object {
            $key, $value = $_.Split('=', 2)
            if ($key -and $value) {
                # Supprimer les guillemets si présents
                $value = $value.Trim('"')
                [System.Environment]::SetEnvironmentVariable($key.Trim(), $value.Trim(), 'Process')
            }
        }
    }

    # 2. Lire le fichier de configuration principal
    if (-not (Test-Path $ConfigPath)) {
        throw "Le fichier de configuration '$ConfigPath' est introuvable."
    }
    $rawContent = Get-Content -Path $ConfigPath -Raw

    # 3. Substituer les variables d'environnement en utilisant la méthode .NET robuste
    $resolvedContent = [System.Environment]::ExpandEnvironmentVariables($rawContent)

    # 4. Parser le JSON
    $configObject = $resolvedContent | ConvertFrom-Json -ErrorAction Stop
    
    return $configObject
}

Export-ModuleMember -Function Resolve-AppConfiguration