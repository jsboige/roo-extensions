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

Describe 'check-unclean-boot.ps1 -- machine a etats (Get-WinEvent mocke, process enfant 5.1)' {

    BeforeAll {
        # Ces tests EXECUTENT la sonde (aucune assertion regex) : chaque cas
        # construit un process enfant powershell.exe 5.1 dont Get-WinEvent est
        # remplace par un mock isole (LOCALAPPDATA rejete sur un tmp), puis
        # tranche sur le code de sortie. Ils tuent les mutants que les gardes
        # statiques ne voient pas (reviews #4578) : healthy-seat throw, fenetre
        # ancree sur l ack, garde no-op de -Acknowledge.
        $script:tmpRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("unclean-boot-tests-" + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $script:tmpRoot -Force | Out-Null

        # Corps de mock : un event 41 a un timestamp FIGE (env), rendu s'il
        # tombe dans la fenetre demandee -- sinon throw NoMatchingEventsFound
        # exactement comme la vraie cmdlet sous -ErrorAction Stop. Respecter
        # FilterHashtable.StartTime est ce qui rend le mutant "fenetre non
        # ancree" reellement mortel.
        $script:mockEvent = @'
    $evt = [pscustomobject]@{ Id = 41; TimeCreated = [datetime]::ParseExact($env:PROBE_EVT_TS, 'o', $null) }
    if ($evt.TimeCreated -lt $FilterHashtable.StartTime) {
        $er = [System.Management.Automation.ErrorRecord]::new(
            [System.Exception]::new('No events were found that match the specified selection criteria.'),
            'NoMatchingEventsFound,Microsoft.PowerShell.Commands.GetWinEventCommand',
            [System.Management.Automation.ErrorCategory]::NotSpecified,
            $null)
        throw $er
    }
    return @($evt)
'@

        $script:mockThrow = @'
    $er = [System.Management.Automation.ErrorRecord]::new(
        [System.Exception]::new('No events were found that match the specified selection criteria.'),
        'NoMatchingEventsFound,Microsoft.PowerShell.Commands.GetWinEventCommand',
        [System.Management.Automation.ErrorCategory]::NotSpecified,
        $null)
    throw $er
'@

        # Helper (Pester 5 : les helpers vivent dans BeforeAll, jamais dans le
        # corps du Describe -- celui-ci ne sert qu'a la decouverte).
        function script:Invoke-MockedProbe {
            param(
                [string]$Name,
                [string]$MockBody,
                [string]$EvtIso,             # timestamp 'o' de l event mocke
                [string]$AckIso = '',        # timestamp 'o' pose dans le marqueur ; vide = aucun
                [int]$LookbackDays = 3,
                [switch]$WithAcknowledge
            )
            $root = Join-Path $script:tmpRoot $Name
            $stateDir = Join-Path $root 'la\claude-executor'
            New-Item -ItemType Directory -Path $stateDir -Force | Out-Null
            if ($AckIso) {
                $ackFile = Join-Path $stateDir ('unclean-boot-ack-{0}.txt' -f $env:COMPUTERNAME.ToLowerInvariant())
                [System.IO.File]::WriteAllText($ackFile, $AckIso, [System.Text.UTF8Encoding]::new($false))
            }
            $runner = Join-Path $root "runner-$Name.ps1"
            # Le call operator + propagation est OBLIGATOIRE : en dot-sourcing,
            # l'`exit` de la sonde termine le SCRIPT appele, pas le process --
            # le wrapper poursuit et le process sort en 0 (mesure de mise au
            # point 06/11 : dot-source rendait 0 sur un cas qui vaut 2).
            $template = @'
$env:LOCALAPPDATA = '{LA}'
$env:PROBE_EVT_TS = '{EVT}'
function Get-WinEvent {
    param($FilterHashtable, $ErrorAction)
{MOCK}
}
& '{PROBE}' -Quiet -LookbackDays {LB}{ACK}
exit $LASTEXITCODE
'@
            $content = $template.
                Replace('{LA}', (Join-Path $root 'la')).
                Replace('{EVT}', $EvtIso).
                Replace('{MOCK}', $MockBody).
                Replace('{PROBE}', $probePath).
                Replace('{LB}', $LookbackDays).
                Replace('{ACK}', $(if ($WithAcknowledge) { ' -Acknowledge' } else { '' }))
            [System.IO.File]::WriteAllText($runner, $content, [System.Text.UTF8Encoding]::new($false))
            & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $runner 2>$null | Out-Null
            return $LASTEXITCODE
        }
    }

    AfterAll {
        if (Test-Path $script:tmpRoot) { Remove-Item -Recurse -Force $script:tmpRoot -Confirm:$false }
    }

    It 'siege sain (throw NoMatchingEventsFound) : exit 0, jamais un WARN permanent' -Skip:($env:OS -ne 'Windows_NT') {
        # Review #4578 blocker : -ErrorAction Stop leve NoMatchingEventsFound
        # quand la fenetre ne contient AUCUN event 41/6008 -- c'est l etat SAIN.
        # Un catch global qui le rend exit 1 transformerait chaque cycle sain en
        # WARN (mesure ai-01 06/11 sous 5.1).
        $code = Invoke-MockedProbe -Name 'healthy' -MockBody $script:mockThrow -EvtIso ([datetime]::Now.ToString('o'))
        $code | Should -Be 0
    }

    It 'crash non acquitte plus vieux que LookbackDays mais posterieur au dernier ack : reste detecte (exit 2)' -Skip:($env:OS -ne 'Windows_NT') {
        # Review #4578 WARN fenetre : ack a T-10j, crash a T-8j. Sans ancrage de
        # la fenetre sur l ack, since = now-3j exclut l event -> throw ->
        # exit 0 silencieux : le crash tomberait du contrat sans jamais etre
        # signale. Le mock respecte StartTime, le mutant meurt reellement.
        $evtIso = [datetime]::Now.AddDays(-8).ToString('o')
        $ackIso = [datetime]::Now.AddDays(-10).ToString('o')
        $code = Invoke-MockedProbe -Name 'window' -MockBody $script:mockEvent -EvtIso $evtIso -AckIso $ackIso
        $code | Should -Be 2
    }

    It '-Acknowledge sur un crash deja acquitte : exit 0 et le marqueur est INCHANGE (garde no-op)' -Skip:($env:OS -ne 'Windows_NT') {
        # Review #4578 WARN ack : le marqueur porte le timestamp de l event
        # acquitte ; re-acker ne doit rien reecrire -- un ack inconditionnel
        # peut taire un crash dont le relai n a jamais eu lieu.
        $evtIso = [datetime]::Now.AddDays(-8).ToString('o')
        $code = Invoke-MockedProbe -Name 'acknoop' -MockBody $script:mockEvent -EvtIso $evtIso -AckIso $evtIso -LookbackDays 30 -WithAcknowledge
        $code | Should -Be 0
        $ackFile = Join-Path (Join-Path $script:tmpRoot 'acknoop\la\claude-executor') ('unclean-boot-ack-{0}.txt' -f $env:COMPUTERNAME.ToLowerInvariant())
        (Get-Content $ackFile -Raw).Trim() | Should -Be $evtIso
    }

    It '-Acknowledge sur un crash NON acquitte : exit 0 et le marqueur est ecrit (contrat normal)' -Skip:($env:OS -ne 'Windows_NT') {
        $evtIso = [datetime]::Now.AddDays(-8).ToString('o')
        $code = Invoke-MockedProbe -Name 'ackwrite' -MockBody $script:mockEvent -EvtIso $evtIso -LookbackDays 30 -WithAcknowledge
        $code | Should -Be 0
        $ackFile = Join-Path (Join-Path $script:tmpRoot 'ackwrite\la\claude-executor') ('unclean-boot-ack-{0}.txt' -f $env:COMPUTERNAME.ToLowerInvariant())
        Test-Path $ackFile | Should -Be $true
        (Get-Content $ackFile -Raw).Trim() | Should -Be $evtIso
    }
}
