# Tests unitaires pour deploy-zoo-scheduler.ps1 -- garde versionnee de
# l'etape 4 (install VSIX).
#
# Syntaxe Pester v5 -- executee en CI par le job `unit-pester` (#3216) via
# scripts/testing/run-pester-tests.ps1.
#
# Defaut qui motivait ce fichier : la garde d'etape 4 testait l'EXISTENCE
# (`-match "zoo-scheduler"` sur `code --list-extensions` sans versions) --
# toute version installee faisait SKIP, bloquant tout upgrade. Mesure 16/10
# pendant le pilote #4025 : zoo.4 saute au-dessus de zoo.3, installe manuelle
# `code --install-extension` requise.
#
# Source-pattern + logique de garde : le script s'execute top-level (worktree
# VSIX, code CLI), pas isolable en fils sur fixture -- on verifie donc la
# FORME de la garde (versions lues, comparaison explicite) et on rejoue
# l'expression de decision sur des lignes simulees de `--show-versions`.

Describe "deploy-zoo-scheduler.ps1 - garde versionnee etape 4" {

    BeforeAll {
        $projectRoot = (Resolve-Path -Path "$PSScriptRoot/../../..").Path
        $script:DeployScript = Join-Path $projectRoot "scripts/zoo-scheduler/deploy-zoo-scheduler.ps1"
        $script:Source = Get-Content -Raw -Path $script:DeployScript
    }

    It "lit les versions installees (--show-versions), pas la seule existence" {
        $script:Source | Should -Match '--list-extensions --show-versions'
        # la garde d'existence bare (defaut d'origine) ne doit plus exister
        $script:Source | Should -Not -Match '\$zooScheduler = code --list-extensions 2>\$null'
    }

    It "derive la version cible depuis le basename du VSIX resolu, pas la constante" {
        $script:Source | Should -Match 'Split-Path -Leaf \$VsixPath'
        # la constante dure ne doit plus alimenter la garde : un -VsixPath plus
        # recent produisait un SKIP compare a l'ancienne version (dispatch c.28)
        $script:Source | Should -Not -Match '\$vsixVersion = \$VsixName -replace'
    }

    It "ne SKIP que si la version installee EGALE la version VSIX" {
        $script:Source | Should -Match 'EndsWith\("@"\+\$vsixVersion\)|EndsWith\("@\{\$vsixVersion\}"\)|EndsWith\("@\$vsixVersion"\)'
    }

    Context "logique de garde (expression rejouee)" {
        BeforeAll {
            # reproduction exacte de l'expression du script : la version cible
            # vient du basename du VSIX resolu, pas de la constante
            $script:VsixName = 'zoo-scheduler-0.0.11-zoo.4.vsix'
            $script:ZooSchedulerId = 'jsboige.zoo-scheduler'
            $script:ResolvedVsix = Join-Path 'D:\packages' $script:VsixName
            $script:TargetVersion = (Split-Path -Leaf $script:ResolvedVsix) -replace '^zoo-scheduler-', '' -replace '\.vsix$', ''
        }

        It "VSIX utilisateur plus recent (-VsixPath) -> la cible suit son basename" {
            $newer = Join-Path 'D:\packages' 'zoo-scheduler-0.0.12-zoo.5.vsix'
            ((Split-Path -Leaf $newer) -replace '^zoo-scheduler-', '' -replace '\.vsix$', '') | Should -Be '0.0.12-zoo.5'
        }

        It "version inferieure installee -> PAS de skip (upgrade requis)" {
            $installedLine = 'jsboige.zoo-scheduler@0.0.11-zoo.3'
            ($installedLine -and "$installedLine".EndsWith("@$($script:TargetVersion)")) | Should -BeFalse
        }

        It "version cible installee -> skip" {
            $installedLine = 'jsboige.zoo-scheduler@0.0.11-zoo.4'
            ($installedLine -and "$installedLine".EndsWith("@$($script:TargetVersion)")) | Should -BeTrue
        }

        It "autre extension zoo presente seule -> pas de skip" {
            $installedLine = 'someoneelse.zoo-scheduler@9.9.9' -as [string]
            ($installedLine -like "$($script:ZooSchedulerId)@*" -and $installedLine.EndsWith("@$($script:TargetVersion)")) | Should -BeFalse
        }
    }
}
