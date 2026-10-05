# Tests unitaires pour deploy-scheduler.ps1 -- activation/desactivation d'UNE
# seule cadence (-Action enable|disable -Schedule <nom>).
#
# Syntaxe Pester v5 -- executee en CI par le job `unit-pester` (#3216) via
# scripts/testing/run-pester-tests.ps1.
#
# DEFaut qui motivait ce fichier : deploy = les DEUX cadences du template,
# disable = TOUTES les cadences du fichier. Aucune action ne savait toucher
# une seule cadence -- le pilote Zoo #4025 (phase 2 : reactiver 360 seul,
# re-gel Meta-Analyste seul apres un 401) a du faire l'edition a la main,
# hors de tout instrument versionne.
#
# Comportemental, pas statique : le script accepte -BasePath, donc on
# l'execute en PROCESSUS FILS sur un temp dir avec un fixture a deux
# schedules, et on relit le fichier produit. Le fils rend son exit code
# (0 = succes, 1 = echec explicite du script).

# NB : le chemin du script cible est calcule dans BeforeAll (phase RUN), pas
# dans BeforeDiscovery -- une variable posee en discovery n'existe pas au run
# (separation discovery/run de Pester v5+) et le fils rendait exit 64.

Describe "deploy-scheduler.ps1 - cadence unique" {

    BeforeAll {
        $projectRoot = (Resolve-Path -Path "$PSScriptRoot/../../..").Path
        $script:DeployScript = Join-Path $projectRoot "roo-config/scheduler/scripts/install/deploy-scheduler.ps1"
        $script:engine = if (Get-Command pwsh -ErrorAction SilentlyContinue) { "pwsh" } else { "powershell" }
        $script:tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("deploy-sched-test-" + [guid]::NewGuid().ToString("N"))
        New-Item -ItemType Directory -Path (Join-Path $script:tmp ".roo") -Force | Out-Null
        $script:schedulesPath = Join-Path $script:tmp ".roo/schedules.json"

        # Fixture : deux cadences, toutes deux inactives par defaut.
        function New-Fixture {
            param([bool]$AssistantActive = $false, [bool]$MetaActive = $false)
            $json = @{
                schedules = @(
                    @{ id = "1"; name = "Claude-Code Assistant"; mode = "orchestrator-simple"; timeInterval = "360"; active = $AssistantActive; taskInstructions = "run" }
                    @{ id = "2"; name = "Meta-Analyste"; mode = "orchestrator-complex"; timeInterval = "4320"; active = $MetaActive; taskInstructions = "run" }
                )
            } | ConvertTo-Json -Depth 6
            [System.IO.File]::WriteAllText($script:schedulesPath, $json, (New-Object System.Text.UTF8Encoding $false))
        }

        function Invoke-DeployScript {
            param([string]$Action, [string]$Schedule = "")
            if ($Schedule) {
                & $script:engine -NoProfile -NonInteractive -File $script:DeployScript -Action $Action -Schedule $Schedule -BasePath $script:tmp 2>&1 | Out-Null
            } else {
                & $script:engine -NoProfile -NonInteractive -File $script:DeployScript -Action $Action -BasePath $script:tmp 2>&1 | Out-Null
            }
            return $LASTEXITCODE
        }

        function Get-ScheduleState {
            param([string]$Name)
            $json = Get-Content $script:schedulesPath -Raw | ConvertFrom-Json
            return ($json.schedules | Where-Object { $_.name -eq $Name }).active
        }
    }

    AfterAll {
        if (Test-Path $script:tmp) { Remove-Item $script:tmp -Recurse -Force -ErrorAction SilentlyContinue }
    }

    It "-Action enable -Schedule active UNE seule cadence, pas les autres" {
        New-Fixture
        $code = Invoke-DeployScript -Action enable -Schedule "Claude-Code Assistant"
        $code | Should -Be 0
        Get-ScheduleState -Name "Claude-Code Assistant" | Should -Be $true
        Get-ScheduleState -Name "Meta-Analyste" | Should -Be $false
    }

    It "-Action enable sans -Schedule active toutes les cadences" {
        New-Fixture
        $code = Invoke-DeployScript -Action enable
        $code | Should -Be 0
        Get-ScheduleState -Name "Claude-Code Assistant" | Should -Be $true
        Get-ScheduleState -Name "Meta-Analyste" | Should -Be $true
    }

    It "-Action disable -Schedule desactive UNE seule cadence (re-gel pilote Zoo)" {
        New-Fixture -AssistantActive $true -MetaActive $true
        $code = Invoke-DeployScript -Action disable -Schedule "Meta-Analyste"
        $code | Should -Be 0
        Get-ScheduleState -Name "Claude-Code Assistant" | Should -Be $true
        Get-ScheduleState -Name "Meta-Analyste" | Should -Be $false
    }

    It "-Action enable -Schedule <inconnu> echoue net (exit 1) et ne modifie rien" {
        New-Fixture -AssistantActive $true
        $code = Invoke-DeployScript -Action enable -Schedule "Nexiste-Pas"
        $code | Should -Be 1
        Get-ScheduleState -Name "Claude-Code Assistant" | Should -Be $true
    }

    It "le fichier produit reste UTF-8 sans BOM (format lu par le companion)" {
        New-Fixture
        Invoke-DeployScript -Action enable -Schedule "Claude-Code Assistant" | Out-Null
        $bytes = [System.IO.File]::ReadAllBytes($script:schedulesPath)
        ($bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) | Should -Be $false
    }
}
