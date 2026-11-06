# Tests unitaires -- sonde de boot-sur-crash (po-2028 crash guard, mandat user 06/11).
#
# Le pre-vol appelle scripts/diagnostic/check-unclean-boot.ps1 : il signale le crash
# (arret non propre) le plus recent NON encore acquitte, pour qu'un crash suivi d'un
# reboot manuel propre AVANT le prochain cycle ne passe pas inapercu (mesure po-2028
# 06/11 : crash 07:08 -> auto-boot 09:23 [Event 41] -> reboot manuel propre 09:52
# [Event 1074]). Relayer en Write-Warning, jamais bloquer (#3169).
#
# Ce que ces tests epinglent, et pourquoi chacun tue un mutant precis :
#   1. SEMANTIQUE "NON ACQUITTE" : la sonde compare le marqueur de crash le plus recent
#      a un fichier d'acquittement machine-local. Un mutant qui n'ancre la detection
#      que sur le boot courant rate le cas "crash puis reboot propre" (le crash 09:23
#      est anterieur au boot 09:52 -> il ne serait jamais signale).
#   2. ACQUITTEMENT APRES RELAI SEULEMENT : l'acquittement est un switch separe
#      (-Acknowledge) que le pre-vol n'appelle qu'apres avoir relaye le WARN. Un mutant
#      qui acquitte dans la meme passe que la detection ferait taire le crash avant
#      tout relai (visible beats deduplicated, review #4388 r3).
#   3. WARN NE BLOQUE PAS : le pre-vol traduit l'exit 2 de la sonde en Write-Warning et
#      ne lui associe AUCUN exit bloquant -- assertion statique sur executor-preflight.ps1.
#   4. PORTABILITE : le script parse sans erreur et n'exige pas l'event log a la
#      compilation ; les appels Get-WinEvent sont dans le corps (jamais au parse).
#
# Assertions statiques (Get-Content -Raw + -match) : aucun appel a l'event log reel,
# les tests tournent sur n'importe quel OS (lesson pester-ubuntu-ci-portability).

BeforeAll {
    $projectRoot = (Resolve-Path -Path "$PSScriptRoot/../../..").Path
    $probePath = Join-Path $projectRoot "scripts/diagnostic/check-unclean-boot.ps1"
    $preflightPath = Join-Path $projectRoot "scripts/claude/executor-preflight.ps1"
    $script:probe = Get-Content $probePath -Raw
    $script:preflight = Get-Content $preflightPath -Raw
}

Describe 'check-unclean-boot.ps1 -- semantique et structure' {

    It 'parse sans erreur' {
        $errors = $null
        [System.Management.Automation.Language.Parser]::ParseFile($probePath, [ref]$null, [ref]$errors) | Out-Null
        $errors.Count | Should -Be 0
    }

    It 'lit les marqueurs d arret non propre (Event 41 et 6008)' {
        # 41 = Kernel-Power, 6008 = EventLog : les deux sont ecrits au boot qui SUIT le crash.
        $script:probe | Should -Match 'Id\s*=\s*41,\s*6008'
    }

    It 'ancre la detection sur le crash NON ACQUITTE, pas seulement sur le boot courant' {
        # Tue le mutant "ce boot a-t-il suivi un crash" : la sonde doit comparer le
        # marqueur le plus recent a un fichier d acquittement, et le signaler meme si
        # le boot courant est propre (crash 09:23 < boot 09:52).
        $script:probe | Should -Match 'unclean-boot-ack-'
        $script:probe | Should -Match '\$latest\.TimeCreated\s*-le\s*\$acked'
    }

    It 'expose un switch -Acknowledge SEPARE de la detection' {
        # L acquittement ne doit PAS etre dans la meme passe que la detection : le
        # pre-vol ne l appelle qu apres avoir relaye le WARN.
        $script:probe | Should -Match '\[switch\]\$Acknowledge'
        # La branche Acknowledge ecrit le marqueur puis sort proprement, sans alerter.
        $script:probe | Should -Match 'if \(\$Acknowledge\)'
    }

    It 'stocke l acquittement hors depot et hors ~/.claude (regle sanctuaire)' {
        $script:probe | Should -Match 'LOCALAPPDATA'
        $script:probe | Should -Match "claude-executor"
        $script:probe | Should -Not -Match '\.claude\\projects'
    }

    It 'contrat de sortie : 0 propre/acquitte, 2 crash non signale, 1 erreur instrument' {
        $script:probe | Should -Match 'exit 0'
        $script:probe | Should -Match 'exit 2'
        $script:probe | Should -Match 'exit 1'
    }
}

Describe 'executor-preflight.ps1 -- cablage de la sonde crash' {

    It 'appelle la sonde et la traduit en Write-Warning (jamais bloquant)' {
        $script:preflight | Should -Match 'check-unclean-boot\.ps1'
        $script:preflight | Should -Match '\[executor-preflight\]\[UNCLEAN-BOOT\]'
        $script:preflight | Should -Match 'Write-Warning'
    }

    It 'ne bloque jamais le cycle sur un crash detecte' {
        # La branche UNCLEAN-BOOT ne doit contenir AUCUN exit bloquant : un crash est un
        # fait a surfacer, pas une raison d arreter. On isole la branche et on verifie
        # qu elle n a pas d exit 1 / exit 10 (seuls des Write-Warning).
        $branch = [regex]::Match($script:preflight, '(?s)if \(\$crashExit -eq 2\).*?The cycle continues')
        $branch.Success | Should -Be $true
        $branch.Value | Should -Not -Match 'exit\s+(1|10)\b'
        $branch.Value | Should -Match 'Write-Warning'
    }

    It 'documente l acquittement apres relai (l agent ou le pre-vol acquitte ensuite)' {
        $script:preflight | Should -Match '-Acknowledge'
    }
}
