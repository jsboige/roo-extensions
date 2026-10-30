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

        It "le defaut resout Zoo des l'installation de Zoo, Roo en repli" {
            # #595 phase 3, review point 1: Zoo-first by INSTALLATION (directory probe),
            # not by mcp_settings.json -- a migrated host has both files and the file
            # probe answers Roo. This static layer only pins the probe's ingredients;
            # the behaviour layer (modes-deploy-mcp-nonregression suite) runs the real
            # --deploy-global against fixtures and is the actual guard.
            ($script:content -match "rooveterinaryinc\.roo-cline") | Should -Be $true
            ($script:content -match "zoocodeorganization\.zoo-code") | Should -Be $true
            ($script:content -match "function extensionInstalled") | Should -Be $true
            ($script:content -match "extensionInstalled\(EXTENSION_IDS\.zoo\)") | Should -Be $true
            ($script:content -match [regex]::Escape("'custom_modes.yaml'")) | Should -Be $true
        }

        It "valide --target-extension hors chaine de prototypes" {
            # #595 phase 3, review point 4: 'constructor'/'__proto__' pass
            # !EXTENSION_IDS[x] via the prototype chain -- the guard must use
            # hasOwnProperty.call.
            ($script:content -match "hasOwnProperty\.call\(EXTENSION_IDS,") | Should -Be $true
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
            ($script:content -match [regex]::Escape("--deploy-global      Also copy to the Roo/Zoo global custom_modes.yaml")) | Should -Be $true
            # #595 phase 3: the global target is selectable -- the header has to document it.
            ($script:content -match [regex]::Escape("--target-extension <auto|roo|zoo>")) | Should -Be $true
        }
    }

    Context "--dry-run n'ecrit RIEN (#4334)" {

        It "parse le flag --dry-run" {
            # Il n'etait pas parse du tout : un flag inconnu etait ignore
            # silencieusement, donc le dry-run documente deployait pour de vrai.
            ($script:content -match "process\.argv\[i\]\s*===\s*'--dry-run'") | Should -Be $true
            ($script:content -match "dryRun:\s*false") | Should -Be $true
        }

        It "n'ecrit pas le fichier de sortie" {
            ($script:content -match "if\s*\(!args\.dryRun\)\s*\{\s*fs\.writeFileSync\(args\.output") | Should -Be $true
        }

        It "ne cree pas le repertoire de sortie" {
            ($script:content -match "if\s*\(!args\.dryRun\s*&&\s*!fs\.existsSync\(outputDir\)\)") | Should -Be $true
        }

        It "ne copie pas vers .roomodes" {
            ($script:content -match "if\s*\(!args\.dryRun\)\s*\{\s*fs\.copyFileSync\(args\.output,\s*roomodesPath\)") | Should -Be $true
        }

        It "ne cree pas le repertoire global et ne copie pas vers la cible globale" {
            ($script:content -match "if\s*\(!args\.dryRun\s*&&\s*!fs\.existsSync\(globalModesDir\)\)") | Should -Be $true
            ($script:content -match "if\s*\(!args\.dryRun\)\s*\{\s*fs\.copyFileSync\(args\.output,\s*globalModesPath\)") | Should -Be $true
        }

        It "annonce le dry-run au lieu de mentir sur les cibles" {
            # Sans ca le log affichait "Deployed to ..." alors que rien n'etait
            # ecrit : c'est ce qui a rendu le defaut invisible sur le siege.
            ($script:content -match "DRY RUN -- nothing was written") | Should -Be $true
            ($script:content -match "Would deploy to global \(dry run\)") | Should -Be $true
        }
    }
}
