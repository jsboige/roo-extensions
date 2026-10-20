# Tests unitaires pour Deploy-GlobalConfig.ps1 -- le script qui pousse le harnais
# global (CLAUDE.md, agents, skills, commands, rules) du depot vers ~/.claude/.
#
# Syntaxe Pester v5 -- execute en CI par le job `unit-pester` (#3216) via
# scripts/testing/run-pester-tests.ps1, sur ubuntu-latest. Deux regimes :
#   * STATIQUE (les deux premiers Describe) : assertions sur le texte des
#     scripts. On n'y execute pas le script ENTIER — il ecrit dans
#     $env:USERPROFILE et ses joints `".claude\configs"` en backslash ne
#     resolvent pas sous Linux (un run complet y serait un succes VIDE :
#     tout SKIP, exit 0 — pire qu'un echec, il ne testerait rien).
#   * BLOCS EXTRAITS (le troisieme Describe, #4260 reviews) : les fonctions
#     et blocs du VRAI script (extraits par ancres a chaque run, jamais
#     recopies — aucune derive possible) sont executes sur des fixtures
#     git reelles. Le meme split que ps51-parse-class (#4139) : la CI parse
#     sous pwsh 7/ubuntu, la classe PS 5.1 (NativeCommandError) y est
#     INVISIBLE — la moitie STATIQUE du garde est la seule effective pour
#     elle, la moitie dynamique verifie la logique (exit code, repli,
#     idempotence) sur les deux moteurs.
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

# BeforeAll a la RACINE du fichier (pattern BOM-SafeFileWriter, mesure 2026-10-10
# sous Pester 6.1.0 : un BeforeAll imbrique dans un Describe perd ses definitions
# de fonctions pour les It/AfterAll et fait echouer le Describe entier — modes-
# deploy-mcp-nonregression documente le precedent). Ne touche que le scope
# lecture : extraction de blocs + definitions de fonctions, zero ecriture disque.
BeforeAll {
    $script:projectRoot = (Resolve-Path -Path "$PSScriptRoot/../../..").Path
    $script:deployScript = Join-Path $script:projectRoot ".claude/configs/scripts/Deploy-GlobalConfig.ps1"
    $script:templatePath = Join-Path $script:projectRoot ".claude/configs/settings.template.json"
    $script:deployContent = Get-Content $script:deployScript -Raw

    # Extraction par ancres : IndexOf en texte litteral, jamais de regex —
    # un marqueur deplace = throw explicite (test rouge), pas un match vide.
    function Get-ExtractedBlock {
        param([string]$StartMarker, [string]$EndMarker, [switch]$IncludeEnd)
        $s = $script:deployContent.IndexOf($StartMarker)
        if ($s -lt 0) { throw "extraction: marqueur debut introuvable -> $($StartMarker.Substring(0, [Math]::Min(60, $StartMarker.Length)))" }
        $e = $script:deployContent.IndexOf($EndMarker, $s)
        if ($e -lt 0) { throw "extraction: marqueur fin introuvable -> $($EndMarker.Substring(0, [Math]::Min(60, $EndMarker.Length)))" }
        if ($IncludeEnd) { $e = $e + $EndMarker.Length }
        return $script:deployContent.Substring($s, $e - $s).TrimEnd()
    }

    # (1) Le bloc de resolution <<repo>> : du default $hooksRepoRoot a la
    # normalisation finale en slashes avant (bornes litterales uniques).
    $endMarkerLine = '$hooksRepoRoot = $hooksRepoRoot -replace ''\\'', ''/'''
    $script:ResolutionBlock = Get-ExtractedBlock `
        -StartMarker '$hooksRepoRoot = $repoRoot' `
        -EndMarker $endMarkerLine `
        -IncludeEnd

    # (2) Convert-ToOrderedHash — le convertisseur du script lui-meme (le
    # canon DOIT etre un IDictionary : $canonHooks[$event] echoue sur un
    # PSCustomObject ; reproduire la conversion ici creerait la derive que
    # modes-deploy-mcp-nonregression documente).
    $script:OrderedHashFn = Get-ExtractedBlock `
        -StartMarker 'function Convert-ToOrderedHash {' `
        -EndMarker 'function Merge-CanonIntoLive'

    # (3) Ensure-FleetHooks — le dedup par signature de commande.
    $script:FleetHooksFn = Get-ExtractedBlock `
        -StartMarker 'function Ensure-FleetHooks {' `
        -EndMarker 'if (Test-Path $livePath)'

    # (4) Le bloc hooks du scaffold fresh : de $freshHooks a la fermeture du
    # if ($freshHooks.Keys.Count -gt 0) — la fermeture est le '}' qui suit
    # la ligne du marqueur HOOK-ADDED (scaffold).
    $scaffoldStart = $script:deployContent.IndexOf('$freshHooks = [ordered]@{}')
    if ($scaffoldStart -lt 0) { throw "extraction: marqueur scaffold introuvable" }
    $markerIdx = $script:deployContent.IndexOf('HOOK-ADDED (scaffold)', $scaffoldStart)
    if ($markerIdx -lt 0) { throw "extraction: marqueur HOOK-ADDED (scaffold) introuvable" }
    $closeIdx = $script:deployContent.IndexOf('}', $markerIdx)
    if ($closeIdx -lt 0) { throw "extraction: fermeture scaffold introuvable" }
    $script:ScaffoldHooksBlock = $script:deployContent.Substring($scaffoldStart, ($closeIdx + 1) - $scaffoldStart)

    # Definitions executees dans le scope partage racine (voir note ci-dessus).
    Invoke-Expression $script:OrderedHashFn
    Invoke-Expression $script:FleetHooksFn

    # Canon reel : les hooks du VRAI settings.template.json (2 entrees
    # PreToolUse aujourd'hui — compte dynamique, jamais figure).
    $canon = Convert-ToOrderedHash (Get-Content $script:templatePath -Raw -Encoding UTF8 | ConvertFrom-Json)
    $script:canonHooks = if ($canon.Contains('hooks')) { $canon['hooks'] } else { $null }
    $script:ExpectedAdds = 0
    foreach ($ev in @($script:canonHooks.Keys)) {
        if ($ev -like '__*') { continue }
        $script:ExpectedAdds += @($script:canonHooks[$ev]).Count
    }
    $script:ExpectedPreToolUse = @($script:canonHooks['PreToolUse']).Count
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

# ─── Blocs executes (#4260 reviews : jsboige "a Pester case that runs this
# block with git failing would lock it in" + web2 "fresh-scaffold + re-run
# idempotence") ─────────────────────────────────────────────────────────────
# Les blocs testes sont EXTRAITS du script reel par ancres a chaque run (voir
# le BeforeAll racine ci-dessus) : le test execute toujours la source courante,
# pas une copie qui deriverait. Aucune ecriture hors temp ; USERPROFILE n'est
# jamais touche.
# NB: JAMAIS de "<<repo>>" dans un NOM de Describe/Context/It — Pester 6.1.0 y
# voit le templating <-ForEach-> (<variable>), variable absente => le bloc
# entier meurt, habille d'un trompeur "break or continue ... escaped" (issue
# #2669 ; mesure 20/10, cf. memory). Le placeholder ne vit que en commentaires
# et here-strings.
Describe "Deploy-GlobalConfig - blocs executes: resolution placeholder-repo + hooks flotte" {

    Context "Resolution de la racine des hooks : le repli racine-non-git n'aborte plus le deploy (#4260)" {

        It 'repertoire NON-git en $repoRoot : repli silencieux vers la racine du script' {
            # La demande exacte de la review : "a non-git temp directory as
            # $repoRoot is enough". Pre-fix, l'appel git non garde sous PS 5.1
            # (EAP=Stop + 2>$null -> NativeCommandError TERMINANT) tuait le
            # deploy entier avant l'ecriture de settings.json. Sous pwsh (CI)
            # ce test verifie le repli par exit code ; la classe 5.1 est
            # verrouillee par le test statique ci-dessous (split #4139).
            $nonGit = (New-Item -ItemType Directory -Path ([System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), [guid]::NewGuid().ToString('N')))).FullName
            try {
                $repoRoot = $nonGit
                $ErrorActionPreference = 'Stop'
                Invoke-Expression $script:ResolutionBlock
                $hooksRepoRoot | Should -Be ($nonGit -replace '\\', '/')
                $gitCommonDir | Should -BeNullOrEmpty
            } finally {
                if (Test-Path -LiteralPath $nonGit) { Remove-Item -LiteralPath $nonGit -Recurse -Force -ErrorAction SilentlyContinue }
            }
        }

        It "checkout git normal : git-common-dir relatif, racine inchangee" {
            # Dans un checkout simple, rev-parse --git-common-dir rend ".git"
            # (relatif) -> mainRoot == repoRoot -> aucun deplacement.
            $repo = (New-Item -ItemType Directory -Path ([System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), [guid]::NewGuid().ToString('N')))).FullName
            try {
                $null = git -C $repo init -q 2>$null
                $repoRoot = $repo
                $ErrorActionPreference = 'Stop'
                Invoke-Expression $script:ResolutionBlock
                $hooksRepoRoot | Should -Be ($repo -replace '\\', '/')
            } finally {
                if (Test-Path -LiteralPath $repo) { Remove-Item -LiteralPath $repo -Recurse -Force -ErrorAction SilentlyContinue }
            }
        }

        It "worktree LIE : la racine resolue pointe vers le checkout persistant, pas l'ephemere" {
            # La propriete qui motive le garde : un agent en worktree lie ne doit
            # PAS cable les hooks vers le worktree (supprime au cleanup = hooks
            # morts sur toute la machine) mais vers le checkout principal.
            $main = (New-Item -ItemType Directory -Path ([System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), [guid]::NewGuid().ToString('N')))).FullName
            # Cible volontairement NON creee : git worktree add l'alloue lui-meme
            # (et refuse une cible non vide) — le finally couvre le cas ou le
            # add echoue apres allocation partielle.
            $wt = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), ([guid]::NewGuid().ToString('N') + '-wt'))
            try {
                $null = git -C $main init -q 2>$null
                $null = git -C $main -c user.email=t@t -c user.name=t commit --allow-empty -q -m init 2>$null
                # Le garde exige Test-Path <main>/.claude\configs pour basculer.
                # Cree via le MEME Join-Path que le script : sous Linux le
                # backslash est un caractere de nom ordinaire -> repertoire
                # litteral ".claude\configs" ; sous Windows, arborescence
                # reelle. La fixture colle a la joint par construction.
                New-Item -ItemType Directory -Force -Path (Join-Path $main ".claude\configs") | Out-Null
                $null = git -C $main worktree add $wt -q 2>$null

                $repoRoot = $wt
                $ErrorActionPreference = 'Stop'
                Invoke-Expression $script:ResolutionBlock
                $hooksRepoRoot | Should -Be ((Resolve-Path -LiteralPath $main).Path -replace '\\', '/')
            } finally {
                $null = git -C $main worktree remove --force $wt 2>$null
                if (Test-Path -LiteralPath $main) { Remove-Item -LiteralPath $main -Recurse -Force -ErrorAction SilentlyContinue }
                if (Test-Path -LiteralPath $wt) { Remove-Item -LiteralPath $wt -Recurse -Force -ErrorAction SilentlyContinue }
            }
        }

        It "le garde PS 5.1 entoure l'appel git (moitie STATIQUE, effective pour la CI pwsh)" {
            # Sous pwsh 7 (ubuntu), un appel natif en echec ne leve PAS via
            # EAP=Stop : le test dynamique non-git passerait meme sans le
            # garde. La classe 5.1 ne se verrouille que sur le TEXTE — meme
            # split que ps51-parse-class (#4139) : BOM/statique = la moitie
            # effective pour la classe de moteur que la CI ne parle pas.
            $eapSave = @'
$eap = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
'@
            $exitGate = @'
if ($LASTEXITCODE -eq 0) { $gitCommonDir = $out }
'@
            $catchFinally = @'
} catch { $gitCommonDir = $null } finally { $ErrorActionPreference = $eap }
'@
            $script:ResolutionBlock | Should -Match ([regex]::Escape($eapSave.Trim()))
            $script:ResolutionBlock | Should -Match ([regex]::Escape($exitGate.Trim()))
            $script:ResolutionBlock | Should -Match ([regex]::Escape($catchFinally.Trim()))
            # Le repli par defaut PRECEDE l'appel git (sinon un echec laisse une
            # variable non initialisee, pas un repli).
            $script:ResolutionBlock.IndexOf('$hooksRepoRoot = $repoRoot') | Should -BeLessThan $script:ResolutionBlock.IndexOf('git -C $repoRoot rev-parse --git-common-dir')
        }
    }

    Context "Ensure-FleetHooks : scaffold fresh puis re-run idempotents (#4260)" {

        It "le scaffold ecrit les N hooks canon resolus, puis Ensure-FleetHooks n'en re-ajoute AUCUN" {
            # La demande de la review web2 : "fresh-scaffold + re-run
            # idempotence". Run 1 = le bloc scaffold du script (extrait) ;
            # re-run = Ensure-FleetHooks sur le resultat. Les deux chemins
            # doivent produire les memes signatures de commande.
            $root = 'C:/dev/roo-extensions'
            $hooksRepoRoot = $root
            $fresh = [ordered]@{}
            $actions = [System.Collections.ArrayList]::new()
            Invoke-Expression $script:ScaffoldHooksBlock

            $fresh.Contains('hooks') | Should -Be $true
            ($fresh | ConvertTo-Json -Depth 10) | Should -Not -Match '<<repo>>'
            @($fresh['hooks']['PreToolUse']).Count | Should -Be $script:ExpectedPreToolUse

            # Re-run : le live hash EST le scaffold fraichement ecrit.
            $live = [ordered]@{}
            $live['hooks'] = $fresh['hooks']
            $actions2 = [System.Collections.ArrayList]::new()
            Ensure-FleetHooks -liveHash $live -canonHooks $script:canonHooks -repoRoot $root -actions ([ref]$actions2)
            $actions2.Count | Should -Be 0
            # Idempotence = aussi rien n'a pousse dans la structure live.
            @($live['hooks']['PreToolUse']).Count | Should -Be $script:ExpectedPreToolUse
        }

        It "live vide : exactement les N entrees canon ajoutees, une seule fois" {
            $root = 'C:/dev/roo-extensions'
            $live = [ordered]@{}
            $actions = [System.Collections.ArrayList]::new()
            Ensure-FleetHooks -liveHash $live -canonHooks $script:canonHooks -repoRoot $root -actions ([ref]$actions)
            @($actions | Where-Object { $_ -like 'HOOK-ADDED*' }).Count | Should -Be $script:ExpectedAdds
            @($live['hooks']['PreToolUse']).Count | Should -Be $script:ExpectedPreToolUse
        }

        It "meme commande sur plusieurs evenements : ajoutee sur CHACUN, puis idempotente" {
            # user-words-journal.js est cable sur Stop, PreCompact et SessionStart.
            # Une signature globale (pre-20/10) le voyait "deja present" apres
            # Stop et ne l'ajoutait jamais aux deux autres evenements.
            $root = 'C:/dev/roo-extensions'
            $multi = @($script:canonHooks.Keys | Where-Object { $_ -notlike '__*' -and $_ -ne 'PreToolUse' })
            $multi.Count | Should -BeGreaterThan 1
            $live = [ordered]@{}
            $actions = [System.Collections.ArrayList]::new()
            Ensure-FleetHooks -liveHash $live -canonHooks $script:canonHooks -repoRoot $root -actions ([ref]$actions)
            foreach ($ev in $multi) {
                @($live['hooks'][$ev]).Count | Should -Be @($script:canonHooks[$ev]).Count
            }
            $actions2 = [System.Collections.ArrayList]::new()
            Ensure-FleetHooks -liveHash $live -canonHooks $script:canonHooks -repoRoot $root -actions ([ref]$actions2)
            $actions2.Count | Should -Be 0
        }

        It "cable main en backslash : reconnu par signature, pas de doublon (RUN3 c.669)" {
            # Le cas mesure au sandbox RUN3 : un hook cable a la main avec la
            # racine en backslash et le canon en forward doit etre reconnu
            # comme DEJA present — sinon chaque deploy ajoute un doublon.
            # La commande live est construite DEPUIS le canon (resolution puis
            # inversion des slashes) : le test ne figure pas le texte canon.
            $root = 'C:/dev/roo-extensions'
            # Pas de chainage d'index dans une interpolation "$(...)": le
            # sous-motif se referme a la premiere parenthese fermante et le
            # reste ([0]['command']) devient du TEXTE literal (mesure 20/10 —
            # le test echouait sur une commande-poubelle, pas sur le dedup).
            # Extraction pas-a-pas, hors chaine.
            $matcherEntries = @($script:canonHooks['PreToolUse'] | Where-Object { $_.Contains('matcher') })
            $matcherEntries.Count | Should -BeGreaterThan 0
            $canonHook = @($matcherEntries[0]['hooks'])[0]
            $canonCmd = [string]$canonHook['command']
            $canonCmd | Should -Match '<<repo>>'
            $wiredCmd = ($canonCmd -replace '<<repo>>', $root) -replace '/', '\'

            $live = [ordered]@{}
            $live['hooks'] = [ordered]@{
                PreToolUse = @(
                    [ordered]@{ matcher = 'Bash'; hooks = @([ordered]@{ type = 'command'; command = $wiredCmd }) }
                )
            }
            $actions = [System.Collections.ArrayList]::new()
            Ensure-FleetHooks -liveHash $live -canonHooks $script:canonHooks -repoRoot $root -actions ([ref]$actions)

            # L'entree cablee n'est PAS re-ajouee ; seule l'autre entree canon manque.
            @($actions | Where-Object { $_ -like 'HOOK-ADDED*' }).Count | Should -Be ($script:ExpectedAdds - 1)
            @($actions | Where-Object { $_ -like '*guard-bash-composite*' -or $_ -like '*echo-loop-counter*' } | Where-Object { $_ -like 'HOOK-ADDED*' }).Count | Should -Be ($script:ExpectedPreToolUse - 1)
            @($live['hooks']['PreToolUse']).Count | Should -Be $script:ExpectedPreToolUse
        }
    }
}
