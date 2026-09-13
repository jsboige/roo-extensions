# Tests unitaires pour les gardes du drainer Vibe-Feeder (review #3518).
# Script sous test : scripts/scheduling/vibe-feeder.ps1
#
# Syntaxe Pester v5 -- execute en CI par le job `unit-pester` (#3216) via
# scripts/testing/run-pester-tests.ps1, sur ubuntu-latest. Assertions
# STATIQUES sur le texte du drainer, comme vibe-worker-noop-guard : le ps1
# cible des chemins Windows (D:\dev\...) et ne s'execute pas sous pwsh Linux.
#
# EXCEPTION : le contexte C3-bis est COMPORTEMENTAL. Il n'execute pas le
# drainer non plus -- il en EXTRAIT les lignes d'eligibilite et les evalue
# contre un depot git jetable. Ces lignes-la ne portent aucun chemin Windows
# (elles ne connaissent que $Grain.worktree / $runtimeDir, que le test pose
# lui-meme), donc elles sont portables sous pwsh Linux.
#
# CE QUE CES TESTS PROUVENT, ET CE QU'ILS NE PROUVENT PAS
# -------------------------------------------------------
# Ils prouvent que chaque garde est TOUJOURS LA, au bon endroit du script --
# c'est une regression, pas une validation. La preuve de COMPORTEMENT a ete
# faite en live sous PowerShell 5.1 Windows (07-08/09) :
#   * dispatch reel -> pickup listener 21 s -> run Mistral -> PR (07/09 23:22Z)
#   * feu naturel   -> NOOP run-in-flight correct (07/09 23:54:49Z)
#   * GDrive coupe  -> success:false detecte, ERROR + exit 1, file NON
#     consommee (08/09 01:04:48Z)
#   * DryRun        -> Read-Queue nouvelle forme + fetch + payload (08/09 01:53Z)
#
# Origine : review ai-01 du 08/09 00:44Z -- "supprimer n'importe laquelle
# (des gardes) laisse les 5 checks verts ; deux gardes statiques auraient rendu
# C1 et C2 immergeables".
#
# Usage:
#   pwsh -NoProfile -Command "Invoke-Pester -Path ./scripts/testing/unit/vibe-feeder-guards.Tests.ps1 -Output Detailed"

BeforeAll {
    $projectRoot = (Resolve-Path -Path "$PSScriptRoot/../../..").Path
    $feederScript = Join-Path $projectRoot "scripts/scheduling/vibe-feeder.ps1"
    $refreshScript = Join-Path $projectRoot "scripts/scheduling/vibe-refresh-basesha.py"
    $content      = Get-Content $feederScript -Raw
    $refreshContent = Get-Content $refreshScript -Raw
}

Describe "Vibe feeder - gardes du drainer (review #3518)" {

    Context "C1 : le grain poste est consomme (la file est reecrite apres post)" {

        It "reecrit la file via Write-Queue sur QueuePath" {
            ($content -match 'function Write-Queue') | Should -Be $true
            ($content -match '\[System\.IO\.File\]::WriteAllText\(') | Should -Be $true
            ($content -match '\$QueuePath') | Should -Be $true
        }

        It "retire le grain poste, pas un autre" {
            # La consommation cible $g (le grain du tour courant) -- un filtre
            # sur autre chose (hardcode, dernier element) consommerait mal.
            ($content -match '\$grains \| Where-Object \{ \$_\.id -ne \$g\.id \}') | Should -Be $true
        }

        It "preserve le _comment de la file" {
            ($content -match '\$q\._comment') | Should -Be $true
        }

        It "la consommation est DANS la branche du post reussi, avant son exit" {
            # Extraire le bloc if ($posted) jusqu'a son exit 0 : la reecriture
            # doit vivre a l'interieur, pas apres un exit qui la court-circuite.
            $postedBlock = [regex]::Match($content, '(?s)if \(\$posted\) \{.*?exit 0').Value
            $postedBlock | Should -Not -BeNullOrEmpty
            ($postedBlock -match 'Write-Queue -Queue \$outObj') | Should -Be $true
        }

        It "la consommation suit l'appel de post, pas l'inverse" {
            $iPost = $content.IndexOf('$posted = Invoke-RsmAppend')
            $iConsume = $content.IndexOf('Write-Queue -Queue $outObj')
            $iPost | Should -BeGreaterThan 0
            $iConsume | Should -BeGreaterThan $iPost
        }
    }

    Context "C2 : un fetch precede la garde de fraicheur baseSha" {

        It "contient un fetch origin main" {
            ($content -match 'fetch origin main') | Should -Be $true
        }

        It "le fetch est AVANT le rev-parse origin/main" {
            # Sans cet ordre, la garde compare au ref local tel que le dernier
            # processus l'a laisse -- un merge distant passe inapercu.
            $iFetch = $content.IndexOf('fetch origin main')
            $iRev   = $content.IndexOf('rev-parse origin/main')
            $iFetch | Should -BeGreaterThan 0
            $iRev   | Should -BeGreaterThan $iFetch
        }
    }

    Context "C3 : la fraicheur est recalee dans le tick, sans course cron :44 -> :54" {

        It "tente un recalage avant de declarer baseSha perime" {
            $iRefresh = $content.IndexOf('Update-StaleGrainBase')
            $iSkip = $content.IndexOf('baseSha perime')
            $iRefresh | Should -BeGreaterThan 0
            $iSkip | Should -BeGreaterThan $iRefresh
        }

        It "ne recale qu'un worktree propre sans commit propre au grain" {
            ($content -match 'status --porcelain') | Should -Be $true
            ($content -match 'rev-list --count') | Should -Be $true
            ($content -match 'merge-base --is-ancestor') | Should -Be $true
        }

        It "mesure l'eligibilite par rapport a MAIN, pas a l'ancienne base" {
            # `baseSha..HEAD` compte aussi ce que MAIN a pris depuis : un worktree
            # deja fast-forwarde sur main (crash entre reset et persistance) y
            # paraissait "avec commits" et restait refuse indefiniment.
            ($content -match 'rev-list --count "\$OriginMain\.\.HEAD"') | Should -Be $true
            ($content -match 'rev-list --count "\$\(\$Grain\.baseSha\)\.\.HEAD"') | Should -Be $false
        }

        It "ne juge pas l'eligibilite sur un code retour git perime" {
            # Deux appels git se suivent : le code retour du premier doit etre
            # capture avant que le second ne l'ecrase.
            ($content -match '\$rcDirty = \$LASTEXITCODE') | Should -Be $true
            ($content -match '\$rcDirty -ne 0') | Should -Be $true
        }

        It "persiste le nouveau baseSha dans la file avant le post" {
            $iQueueRefresh = $content.IndexOf('$Grain.baseSha = $OriginMain')
            $iPost = $content.IndexOf('$posted = Invoke-RsmAppend')
            $iQueueRefresh | Should -BeGreaterThan 0
            $iPost | Should -BeGreaterThan $iQueueRefresh
            ($content -match 'Write-Queue') | Should -Be $true
        }
    }

    Context "C3-bis : le predicat d'eligibilite, exerce sur un vrai depot" {

        # Les tests C3 ci-dessus sont des contrats de SOURCE : ils verifient que la
        # bonne expression est ecrite au bon endroit. Ils passeraient encore si
        # l'expression etait juste a la lettre et fausse au sens. Ce contexte-ci
        # extrait les lignes du drainer et les EXECUTE contre un depot jetable --
        # c'est la seule forme qui rougit quand la mesure change de referentiel.

        It "accepte un worktree deja fast-forwarde sur main, refuse un commit propre ou un arbre sale" {
            # $ErrorActionPreference = 'Continue' pendant la plomberie git : sous
            # PowerShell 5.1 la moindre ligne de stderr native devient une erreur
            # TERMINANTE quand la preference vaut 'Stop', et le harnais echoue
            # alors a la place de la garde. Restauree dans le finally.
            $savedEap = $ErrorActionPreference
            $ErrorActionPreference = 'Continue'
            $root = Join-Path ([System.IO.Path]::GetTempPath()) ("vibe-elig-" + [guid]::NewGuid().ToString('N').Substring(0,8))
            try {
                New-Item -ItemType Directory -Path $root -Force | Out-Null
                $repo = Join-Path $root 'runtime'
                & git init -q --initial-branch=main $repo
                & git -C $repo config user.email 't@t'
                & git -C $repo config user.name 't'
                Set-Content -Path (Join-Path $repo 'f.txt') -Value 'base'
                & git -C $repo add f.txt
                & git -C $repo commit -qm base
                $oldBase = (& git -C $repo rev-parse HEAD).Trim()
                Set-Content -Path (Join-Path $repo 'f.txt') -Value 'main-advanced'
                & git -C $repo commit -qam advance
                $mainSha = (& git -C $repo rev-parse HEAD).Trim()

                $lines  = $content -split "`n"
                $lDirty = ($lines | Where-Object { $_ -match '^\s*\$dirty = \(git ' }   | Select-Object -First 1)
                $lRc    = ($lines | Where-Object { $_ -match '^\s*\$rcDirty = ' }       | Select-Object -First 1)
                $lAhead = ($lines | Where-Object { $_ -match '^\s*\$ahead = \(git ' }   | Select-Object -First 1)
                $lIf    = ($lines | Where-Object { $_ -match '^\s*if \(\$dirty -or ' }  | Select-Object -First 1)
                $lDirty | Should -Not -BeNullOrEmpty
                $lRc    | Should -Not -BeNullOrEmpty
                $lAhead | Should -Not -BeNullOrEmpty
                $lIf    | Should -Not -BeNullOrEmpty
                $cond = [regex]::Match($lIf, '^\s*if \((.+)\)\s*\{\s*$').Groups[1].Value
                $cond | Should -Not -BeNullOrEmpty

                $OriginMain = $mainSha
                $Grain = [pscustomobject]@{ worktree = $repo; baseSha = $oldBase }

                # (1) arbre propre, deja sur main, base ANCIENNE dans la file :
                #     c'est l'etat exact laisse par un kill entre le reset --hard et
                #     la persistance du baseSha. Mesure contre l'ancienne base il
                #     paraissait "avec commits" et restait refuse a chaque tick.
                Invoke-Expression $lDirty; Invoke-Expression $lRc; Invoke-Expression $lAhead
                (Invoke-Expression $cond) | Should -Be $false

                # (2) le worktree porte un commit a lui : le refus tient (fail-closed).
                Set-Content -Path (Join-Path $repo 'f.txt') -Value 'grain-work'
                & git -C $repo commit -qam grain
                Invoke-Expression $lDirty; Invoke-Expression $lRc; Invoke-Expression $lAhead
                (Invoke-Expression $cond) | Should -Be $true

                # (3) arbre sale sans commit : le refus tient aussi.
                & git -C $repo reset -q --hard $mainSha
                Set-Content -Path (Join-Path $repo 'f.txt') -Value 'edit-non-commit'
                Invoke-Expression $lDirty; Invoke-Expression $lRc; Invoke-Expression $lAhead
                (Invoke-Expression $cond) | Should -Be $true
            }
            finally {
                $ErrorActionPreference = $savedEap
                if (Test-Path $root) { Remove-Item -Recurse -Force $root -ErrorAction SilentlyContinue }
            }
        }

        It "refuse une base qui n'est pas ancetre de main, et accepte celle qui l'est" {
            $savedEap = $ErrorActionPreference
            $ErrorActionPreference = 'Continue'
            $root = Join-Path ([System.IO.Path]::GetTempPath()) ("vibe-anc-" + [guid]::NewGuid().ToString('N').Substring(0,8))
            try {
                New-Item -ItemType Directory -Path $root -Force | Out-Null
                $repo = Join-Path $root 'runtime'
                & git init -q --initial-branch=main $repo
                & git -C $repo config user.email 't@t'
                & git -C $repo config user.name 't'
                Set-Content -Path (Join-Path $repo 'f.txt') -Value 'base'
                & git -C $repo add f.txt
                & git -C $repo commit -qm base
                $oldBase = (& git -C $repo rev-parse HEAD).Trim()
                & git -C $repo checkout -q -b side
                Set-Content -Path (Join-Path $repo 'g.txt') -Value 'side'
                & git -C $repo add g.txt
                & git -C $repo commit -qm side
                $sideSha = (& git -C $repo rev-parse HEAD).Trim()
                & git -C $repo checkout -q main
                Set-Content -Path (Join-Path $repo 'f.txt') -Value 'main-advanced'
                & git -C $repo commit -qam advance
                $mainSha = (& git -C $repo rev-parse HEAD).Trim()

                $lAnc = ($content -split "`n" | Where-Object { $_ -match 'merge-base --is-ancestor' } | Select-Object -First 1)
                $lAnc | Should -Not -BeNullOrEmpty

                $runtimeDir = $repo
                $OriginMain = $mainSha

                # Base sur une branche laterale : hors de l'ascendance de main.
                $Grain = [pscustomobject]@{ baseSha = $sideSha }
                Invoke-Expression $lAnc
                $LASTEXITCODE | Should -Not -Be 0

                # Controle negatif : la vraie ancienne base EST ancetre -> la garde
                # se tait. Sans ce cas, un git casse ferait passer le cas ci-dessus.
                $Grain = [pscustomobject]@{ baseSha = $oldBase }
                Invoke-Expression $lAnc
                $LASTEXITCODE | Should -Be 0
            }
            finally {
                $ErrorActionPreference = $savedEap
                if (Test-Path $root) { Remove-Item -Recurse -Force $root -ErrorAction SilentlyContinue }
            }
        }
    }

    Context "C4 : le refresh ne supprime pas un grain au payload non reconnu" {

        It "utilise targetPath comme contrat structure avant les heuristiques de payload" {
            ($refreshContent -match 'grain\.get\("targetPath"\)') | Should -Be $true
        }

        It "conserve explicitement un grain dont la cible est inconnue" {
            ($refreshContent -match 'cible inconnue conservee') | Should -Be $true
            ($refreshContent -match 'if not target:\s+keep\.append\(grain\)') | Should -Be $true
        }
    }

    Context "W2 : worktree add idempotent si la branche survit au remove" {

        It "teste l'existence de la branche avant le -b" {
            ($content -match 'branch --list \$branch') | Should -Be $true
        }

        It "possede le repli sans -b sur branche existante" {
            # Distinct du createur 'worktree add $wt -b $branch $base' : le
            # repli attache $wt DIRECTEMENT a $branch (adjacents).
            ($content -match 'worktree add \$wt \$branch') | Should -Be $true
        }
    }

    Context "Verdict de post a 3 jambes (durci apres le faux succes 08/09 01:02Z)" {

        It "exige success:true dans le texte de la reponse" {
            # GDrive coupe rend success:false DANS LE TEXTE sans isError --
            # sans cette jambe le drainer croit le post reussi.
            ($content -match "\`"success\`"\s*:\s*true") | Should -Be $true
        }

        It "la recence in-flight se lit sur l'horodatage de ligne, pas le mtime" {
            # Le heartbeat de tick rafraichit le mtime d'un fichier a marqueurs
            # historiques -> faux 'en vol' perpetuel (mesure 08/09 00:57Z). Le
            # tri par LastWriteTime pour CHOISIR le dernier log reste legitime ;
            # c'est sa COMPARAISON au cut qui etait le bug.
            ($content -match 'Parse\(\$Matches\[1\]') | Should -Be $true
            ($content -match 'LastWriteTime\s*-(gt|ge|lt|le)') | Should -Be $false
        }
    }

    Context "Logging resilient aux verrous de lecture (mesure 08/09 03:15Z)" {

        It "l'Add-Content du log est retry-able (-ErrorAction Stop dans un try)" {
            # EAP=Continue avale l'IOException de partage : 3 lignes perdues en
            # direct, un feu entier sans trace. Le Stop local capture l'echec.
            ($content -match 'Add-Content -Path \$logFile -Value \$line -Encoding utf8 -ErrorAction Stop') | Should -Be $true
        }

        It "un fichier de repli recueille la ligne quand le log reste verrouille" {
            ($content -match '\$logFile\.sidecar') | Should -Be $true
        }

        It "deux tentatives avant le repli" {
            ($content -match 'foreach \(\$attempt in 1\.\.2\)') | Should -Be $true
        }
    }

    Context "C5 : un timeout de post n'est pas une preuve de non-livraison (maillon 3, mesure 13/09)" {

        # WRITE-FIRST ecrit le message AVANT la condensation, qui peut durer
        # 132 s (13/09 09:31Z : append 146 s dont ecriture 7,5 s). Un post
        # livre etait donc enregistre ECHOUE (13/09 08:57:54Z timeout 151 s,
        # message visible des 08:56:10Z) : repli local heurtant le lock du run
        # parti de CE message (exit 75), grain garde, re-dispatch au tick
        # suivant = run double paye. Ces contrats verifient que la relecture
        # tranche AVANT tout repli.

        It "possede une fonction de verification par relecture" {
            ($content -match 'function Test-WakeDelivered') | Should -Be $true
        }

        It "la relecture lit l'intercom du meme dashboard que le post" {
            # Un read sur une autre section/canal ne pourrait jamais y voir
            # le message qui vient d'etre poste.
            ($content -match "section = 'intercom'; intercomLimit = 12") | Should -Be $true
        }

        It "le marqueur est l'ID du message, pas le contenu" {
            # Un grain garde apres exit 75 est re-poste au tick suivant avec
            # un contenu byte-identique : matcher sur le contenu confondrait
            # le message du tick precedent avec celui-ci (faux positif =
            # grain consomme sans run). $noteId = machine + grain + minute.
            ($content -match 'Test-WakeDelivered -Marker \$noteId') | Should -Be $true
            ($content -match '\$marker = "\[WAKE-VIBE\] \$payload"') | Should -Be $false
        }

        It "la relecture precede le repli local (WARN puis spawn)" {
            $iVerify = $content.IndexOf('Test-WakeDelivered -Marker $noteId')
            $iWarn   = $content.IndexOf('repli sur spawn LOCAL')
            $iSpawn  = $content.IndexOf('& $psHost -File $vibeWorkerScript')
            $iVerify | Should -BeGreaterThan 0
            $iWarn   | Should -BeGreaterThan $iVerify
            $iSpawn  | Should -BeGreaterThan $iWarn
        }

        It "la relecture exige le wrapper present" {
            # Sans wrapper, la relecture stdio est impossible : passer
            # directement au repli au lieu d'un faux verdict.
            ($content -match 'if \(-not \$wrapperMissing\) \{\s*\r?\n\s*if \(Test-WakeDelivered') | Should -Be $true
        }

        It "la branche livre consomme le grain SANS spawner" {
            # Si le message est livre : ecrire la file et sortir. Le spawn
            # local serait un double-run (le listener part du message poste).
            $delivered = [regex]::Match($content, '(?s)if \(Test-WakeDelivered.*?exit 0').Value
            $delivered | Should -Not -BeNullOrEmpty
            ($delivered -match 'Write-Queue -Queue \$outObj') | Should -Be $true
            ($delivered -match '\$grains \| Where-Object \{ \$_\.id -ne \$g\.id \}') | Should -Be $true
            ($delivered -match '\$psHost -File') | Should -Be $false
        }
    }
}
