# Test unitaire pour le script deploy-modes.ps1

Describe "Tests du script de déploiement des modes" {
    BeforeAll {
        # $PSScriptRoot is the directory containing the test script.
        $projectRoot = (Resolve-Path -Path "$PSScriptRoot\..\..\..").Path
        $deployScriptPath = Join-Path -Path $projectRoot -ChildPath "scripts\deployment\deploy-modes.ps1"
    }
    Context "Validation de base" {
        It "Le script deploy-modes.ps1 doit exister" {
            Test-Path -Path $deployScriptPath | Should Be $true
        }
    }
}