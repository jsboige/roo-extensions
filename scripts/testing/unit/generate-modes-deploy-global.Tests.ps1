# Tests unitaires pour generate-modes.js --deploy-global (#595)
#
# Syntaxe Pester v5 -- execute en CI par le job `unit-pester` (#3216) via
# scripts/testing/run-pester-tests.ps1, sur ubuntu-latest. Assertions
# STATIQUES sur le texte du script, dans la lignee de deploy-global-config.Tests.ps1 :
# on ne l'EXECUTE pas ici (le chemin par defaut ecrit dans le globalStorage reel
# de la machine, et le job CI n'a pas a dependre de node pour ce garde).
#
# LE DEFAUT QUI MOTIVE CE FICHIER
# --------------------------------
# L'issue #595 demande un deploiement des modes vers le custom_modes.yaml GLOBAL
# de Roo (VS Code globalStorage), pas seulement vers .roomodes a la racine du
# projet. Le bloc --deploy historique (generate-modes.js:304-309 a l'epoque)
# ne copiait que .roomodes. La capacite a ete ajoute en --deploy-global SANS
# toucher au comportement de --deploy, utilise par applyProfile() et documente
# dans PROFILE_TO_MODES_DESIGN.md / HARNESS-OVERVIEW.md / CLAUDE.md.
#
# La propriete gardee ici est DOUBLE :
#   1. la capacite globale existe et refuse le JSON (Roo 3.51.1+ = YAML only) ;
#   2. le chemin legacy .roomodes n'a pas ete detourne au passage -- sinon le
#      fix de #595 remplace silencieusement la semantique documentee de --deploy.
#
# Usage:
#   pwsh -NoProfile -Command "Invoke-Pester -Path ./scripts/testing/unit/generate-modes-deploy-global.Tests.ps1 -Output Detailed"

BeforeDiscovery {
    $projectRoot = (Resolve-Path -Path "$PSScriptRoot/../../..").Path
    # Singleton -ForEach : la donnee de discovery transite par le parametre
    # (pattern deploy-global-config.Tests.ps1), PAS par $script: -- sous Pester 6
    # le script scope est re-lie entre discovery et runtime (Pester #2669).
    $script:Targets = @(
        @{ Name = "generate-modes.js"; Path = Join-Path $projectRoot "roo-config/scripts/generate-modes.js" }
    )
}

Describe "generate-modes.js --deploy-global <Name> (#595)" -ForEach $script:Targets {

    BeforeAll {
        $script:content = Get-Content $Path -Raw
    }

    It "le script existe a l'emplacement canonique" {
        Test-Path $Path | Should -Be $true
    }

    Context "Nouvelle capacite --deploy-global" {

        It "parse le flag --deploy-global" {
            ($script:content -match [regex]::Escape("--deploy-global")) | Should -Be $true
            ($script:content -match "args\.deployGlobal\s*=\s*true") | Should -Be $true
        }

        It "parse --global-path <path> (echappement Zoo : globalStorage differe)" {
            ($script:content -match "args\.globalPath\s*=\s*process\.argv\[\+\+i\]") | Should -Be $true
        }

        It "resout le chemin explicite AVANT le defaut globalStorage" {
            # resolveGlobalModesPath(explicit) : si un chemin explicite est donne,
            # il gagne -- sinon la machine ecrit dans son vrai globalStorage.
            ($script:content -match "if\s*\(explicit\)\s*\{\s*return explicit;") | Should -Be $true
        }

        It "le defaut vise custom_modes.yaml sous rooveterinaryinc.roo-cline/settings" {
            ($script:content -match "rooveterinaryinc\.roo-cline") | Should -Be $true
            ($script:content -match [regex]::Escape("'custom_modes.yaml'")) | Should -Be $true
        }

        It "cree le repertoire cible (recursive) avant la copie" {
            ($script:content -match "mkdirSync\(globalModesDir,\s*\{\s*recursive:\s*true\s*\}\)") | Should -Be $true
        }

        It "copie le fichier genere vers la cible globale" {
            ($script:content -match "copyFileSync\(args\.output,\s*globalModesPath\)") | Should -Be $true
        }
    }

    Context "Garde YAML-only (Roo 3.51.1+)" {

        It "refuse --deploy-global sans --format yaml" {
            # Le garde vit APRES la boucle de parsing : l'ordre des flags
            # (--format yaml avant ou apres --deploy-global) ne doit pas matter.
            ($script:content -match "args\.deployGlobal\s*&&\s*args\.format\s*!==\s*'yaml'") | Should -Be $true
        }

        It "le garde echoue AVANT toute generation (process.exit(1) dans parseArgs)" {
            # Fail-fast : le JSON ne doit meme pas etre ecrit sur disque avant
            # l'exit -- valide en manuel : aucun fichier produit sur le cas negatif.
            ($script:content -match "deployGlobal\s*&&\s*args\.format\s*!==\s*'yaml'[\s\S]{0,200}process\.exit\(1\)") | Should -Be $true
        }
    }

    Context "Le chemin legacy --deploy reste intact (anti-regression)" {

        It "--deploy cible toujours .roomodes a la racine du projet" {
            ($script:content -match "path\.join\(ROOT,\s*'\.roomodes'\)") | Should -Be $true
        }

        It "--deploy copie toujours args.output vers roomodesPath" {
            ($script:content -match "copyFileSync\(args\.output,\s*roomodesPath\)") | Should -Be $true
        }

        It "la doc du header mentionne les deux cibles distinctement" {
            ($script:content -match [regex]::Escape("--deploy             Also copy to .roomodes at project root")) | Should -Be $true
            ($script:content -match [regex]::Escape("--deploy-global      Also copy to the Roo global custom_modes.yaml")) | Should -Be $true
        }
    }
}
