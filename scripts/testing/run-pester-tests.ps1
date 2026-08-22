# Point d'entrée pour l'exécution des tests Pester
#
# Exécuté en CI par le job `unit-pester` (.github/workflows/ci.yml, #3216) :
#   pwsh -File scripts/testing/run-pester-tests.ps1 -Path scripts/testing/unit -CI
# Le mode -CI fait sortir le process avec un exit code = nombre d'échecs (non-nul
# → job rouge). Sans la propagation de la configuration, Invoke-Pester sortait 0
# quel que soit le résultat — un runner qui ne peut pas échouer n'est pas un runner.

param (
    [Parameter(Mandatory=$false)]
    [string[]]$Path = @('scripts/testing'),

    [Parameter(Mandatory=$false)]
    [switch]$CI
)

try {
    # Détection et installation de Pester si nécessaire (les runners ubuntu
    # n'ont pas Pester préinstallé, contrairement aux runners Windows)
    if (-not (Get-Module -ListAvailable -Name Pester)) {
        Write-Host "Pester n'est pas installé. Tentative d'installation..."
        Install-Module -Name Pester -Force -SkipPublisherCheck -Scope CurrentUser
    }

    # Importation du module Pester
    Import-Module Pester -Force

    # Configuration de Pester en tant que Hashtable.
    # Run.Exit (et pas un hypothétique Run.CI, qui n'existe pas et serait ignoré
    # silencieusement) : c'est le seul réglage qui fait sortir le process avec
    # exit code = nombre d'échecs — mesuré : sans lui, 1 test rouge sortait 0.
    $pesterConfig = @{
        Run = @{
            Path = $Path
            Exit = $CI.IsPresent
        }
        Output = @{
            Verbosity = 'Detailed'
        }
    }

    # Exécution des tests — -Configuration propage le mode CI (exit code)
    Invoke-Pester -Configuration $pesterConfig
}
catch {
    Write-Error "Une erreur est survenue lors de l'exécution des tests : $_"
    exit 1
}
