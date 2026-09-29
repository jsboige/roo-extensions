# Tests unitaires pour Deploy-GlobalConfig.ps1 -- le script qui pousse le harnais
# global (CLAUDE.md, agents, skills, commands, rules) du depot vers ~/.claude/.
#
# Syntaxe Pester v5 -- execute en CI par le job `unit-pester` (#3216) via
# scripts/testing/run-pester-tests.ps1, sur ubuntu-latest. Assertions purement
# STATIQUES sur le texte des scripts : ils ecrivent dans $env:USERPROFILE et
# resolvent le depot via `git rev-parse`, donc on ne les EXECUTE pas ici.
#
# LE DEFAUT QUI MOTIVAIT CE FICHIER — RESOLU PAR CONSOLIDATION (29/09/2026)
# ----------------------------------------------------------------------
# Le script a existe en DEUX exemplaires pendant six mois :
#   * .claude/configs/scripts/Deploy-GlobalConfig.ps1  (canon, 17 Ko)
#   * scripts/claude/Deploy-GlobalConfig.ps1           (ancien, 4,4 Ko)
# Le bloc `rules` manquait a la seconde du 26/05 (#2376) au 02/09 : un agent
# qui lancait cette copie avec -Target all voyait "Done." pendant que
# ~/.claude/rules/ n'etait PAS mis a jour. Rien ne distinguait ce succes d'un
# vrai.
#
# CONSOLIDATION (dispatch ai-01 29/09, lane po-2025, regle de consolidation) :
# analyse ligne-par-ligne de l'ancien — Deploy-Files (ancien l.42-71 = canon
# l.45-74, byte-identiques), blocs claude-md/agents/skills/commands/rules
# (ancien l.76-119 = canon l.79-122, identiques), param (ancien l.20-24 ⊂
# canon l.20-24 qui ajoute "settings"), repoRoot (ancien git-rev-parse-first
# ⊂ canon PSScriptRoot-first, incident mesure 29/09). AUCUNE feature de
# l'ancien absente du canon → ancien supprime, blob preserve dans l'historique
# git. Ce fichier continue de tester LA copie restante : la propriete "cette
# copie, prise seule, deploie les rules" reste vraie apres consolidation.
#
# Une deuxieme copie apparaitra peut-etre un jour. L'ajouter a
# $script:Copies suffit.
#
# Usage:
#   pwsh -NoProfile -Command "Invoke-Pester -Path ./scripts/testing/unit/deploy-global-config.Tests.ps1 -Output Detailed"

BeforeDiscovery {
    $projectRoot = (Resolve-Path -Path "$PSScriptRoot/../../..").Path
    $script:Copies = @(
        @{ Name = ".claude/configs/scripts"; Path = Join-Path $projectRoot ".claude/configs/scripts/Deploy-GlobalConfig.ps1" }
    )
}

Describe "Deploy-GlobalConfig - copie <Name>" -ForEach $script:Copies {

    BeforeAll {
        $script:content = Get-Content $Path -Raw
    }

    It "existe a l'emplacement documente par son README" {
        Test-Path $Path | Should -Be $true
    }

    Context "Le deploiement des rules -- ce qui manquait pendant trois mois" {

        It "accepte -Target rules" {
            # Sans l'entree de ValidateSet, l'appel cible echoue net. C'est le
            # seul symptome AUDIBLE du defaut ; -Target all, lui, est muet.
            ($script:content -match '\[ValidateSet\([^)]*"rules"') | Should -Be $true
        }

        It "porte un bloc de deploiement des rules gate sur all ET rules" {
            # `-in "all", "rules"` : oublier "all" rendrait le defaut invisible
            # a nouveau, puisque personne ne passe -Target rules a la main.
            ($script:content -match '\$Target\s+-in\s+"all",\s*"rules"') | Should -Be $true
        }

        It "lit .claude/configs/rules et ecrit ~/.claude/rules" {
            ($script:content -match '\$rulesSrc\s*=\s*Join-Path\s+\$configsDir\s+"rules"') | Should -Be $true
            ($script:content -match '\$rulesDst\s*=\s*Join-Path\s+\$globalDir\s+"rules"')  | Should -Be $true
        }

        It "compte les fichiers rules dans le total affiche" {
            # Deploy-Files rend un compte ; ne pas l'additionner afficherait
            # "Files deployed: N" en sous-estimant, autre facon de mentir doucement.
            ($script:content -match '\$totalFiles\s*\+=\s*\(Deploy-Files[^)]*-Label\s+"rules"\)') | Should -Be $true
        }
    }

    Context "L'aide du script decrit ce qu'il fait reellement" {

        It "annonce les rules dans .DESCRIPTION" {
            # L'aide est ce que lit un agent avant de lancer le script. Quand elle
            # omet les rules, elle CONFIRME le defaut au lieu de le denoncer.
            $desc = [regex]::Match($script:content, '(?s)\.DESCRIPTION(.*?)\.PARAMETER').Value
            $desc | Should -Not -BeNullOrEmpty
            ($desc -match 'rules') | Should -Be $true
        }

        It "annonce les rules dans .PARAMETER Target" {
            $param = [regex]::Match($script:content, '(?s)\.PARAMETER Target(.*?)\.PARAMETER').Value
            $param | Should -Not -BeNullOrEmpty
            ($param -match 'rules') | Should -Be $true
        }
    }

    Context "Les cibles historiques restent deployees" {

        # Regression pure : ces quatre-la marchaient avant l'ajout des rules, et
        # rien ne doit les perdre au passage.
        It "deploie <_>" -ForEach @('agents', 'skills', 'commands') {
            ($script:content -match "\`$Target\s+-in\s+`"all`",\s*`"$_`"") | Should -Be $true
        }

        It "deploie CLAUDE.md depuis user-global-claude.md" {
            ($script:content -match '\$Target\s+-in\s+"all",\s*"claude-md"')       | Should -Be $true
            ($script:content -match 'Join-Path \$configsDir "user-global-claude\.md"') | Should -Be $true
        }
    }
}

Describe "Deploy-GlobalConfig - la source qu'il deploie" {

    BeforeAll {
        $script:projectRoot = (Resolve-Path -Path "$PSScriptRoot/../../..").Path
    }

    It "le repertoire .claude/configs/rules existe et n'est pas vide" {
        # Le bloc de deploiement passe en SKIP silencieux quand la source manque
        # (Deploy-Files : "SKIP rules (source not found)") -- et le script sort
        # quand meme sur "Done.". Un repertoire vide reproduit donc le meme
        # symptome que le bloc absent, sans qu'aucune assertion ci-dessus ne morde.
        $rulesDir = Join-Path $script:projectRoot ".claude/configs/rules"
        Test-Path $rulesDir | Should -Be $true
        @(Get-ChildItem -Path $rulesDir -Recurse -File).Count | Should -BeGreaterThan 0
    }
}
