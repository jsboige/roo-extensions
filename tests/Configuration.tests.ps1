# tests/Configuration.tests.ps1
$PSScriptRoot = Split-Path -Parent (Split-Path -Parent -Path $MyInvocation.MyCommand.Definition)
Import-Module "$PSScriptRoot\modules\Configuration.psm1" -Force

Describe 'Get-SyncConfiguration' {
    Context 'Quand le fichier de configuration est valide' {
        BeforeAll {
            # Crée un faux fichier de configuration pour le test
            $mockConfig = @{ version = '1.0-test'; defaultRemote = 'origin-test' } | ConvertTo-Json
            $mockPath = Join-Path $PSScriptRoot 'temp-config.json'
            Set-Content -Path $mockPath -Value $mockConfig
        }

        AfterAll {
            # Nettoie le fichier de configuration après le test
            Remove-Item -Path (Join-Path $PSScriptRoot 'temp-config.json') -Force
        }

        It 'doit lire le fichier et retourner un objet PowerShell' {
            $config = Get-SyncConfiguration -Path (Join-Path $PSScriptRoot 'temp-config.json')
            ($config -ne $null) | Should Be $true
            $config.version | Should Be '1.0-test'
        }
    }

    Context 'Quand le fichier de configuration est introuvable' {
        It 'doit lever une exception' {
            { Get-SyncConfiguration -Path 'un/chemin/inexistant.json' } | Should Throw "Le fichier de configuration 'un/chemin/inexistant.json' est introuvable."
        }
    }

    Context 'Quand le fichier de configuration est malformé' {
        BeforeAll {
            $mockPath = Join-Path $PSScriptRoot 'malformed-config.json'
            Set-Content -Path $mockPath -Value '{ "version": "1.0", ' # JSON invalide
        }

        AfterAll {
            Remove-Item -Path (Join-Path $PSScriptRoot 'malformed-config.json') -Force
        }

        It 'doit lever une exception' {
            $path = Join-Path $PSScriptRoot 'malformed-config.json'
            $exceptionThrown = $false
            try {
                Get-SyncConfiguration -Path $path -ErrorAction Stop
            }
            catch {
                $exceptionThrown = $true
            }
            $exceptionThrown | Should Be $true
        }
    }
}