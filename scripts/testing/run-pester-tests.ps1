# Point d'entrée pour l'exécution des tests Pester

param (
    [Parameter(Mandatory=$false)]
    [string[]]$Path = @('scripts/testing'),

    [Parameter(Mandatory=$false)]
    [switch]$CI
)

try {
    # Détection et installation de Pester si nécessaire
    if (-not (Get-Module -ListAvailable -Name Pester)) {
        Write-Host "Pester n'est pas installé. Tentative d'installation..."
        Install-Module -Name Pester -Force -SkipPublisherCheck -Scope CurrentUser
    }

    # Importation du module Pester
    Import-Module Pester -Force

    # Configuration de Pester en tant que Hashtable
    $pesterConfig = @{
        Run = @{
            Path = $Path
            CI = $CI.IsPresent
        }
        Output = @{
            Verbosity = 'Detailed'
        }
    }

    # Exécution des tests
    Invoke-Pester -Path $Path
}
catch {
    Write-Error "Une erreur est survenue lors de l'exécution des tests : $_"
    exit 1
}