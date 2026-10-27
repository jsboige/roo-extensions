# Tests unitaires -- moniteur embeddings (check-embeddings.ps1)
#
# Incident 26/10 : le moniteur classait un service SANTE comme DOWN. Mesure
# ai-01 04:18-04:25Z : le vhost embeddings.myia.io repond en 5,9-26 s, le
# conteneur vLLM est healthy. Le budget de 15 s produisait 8 fausses alertes
# [CRITICAL] dont l action recommandee (restart vLLM) etait un faux
# diagnostic. Ces tests epinglent les trois causes :
#   1. le budget par defaut doit couvrir la latence mesuree du vhost ;
#   2. un timeout doit etre CONFIRME avant d etre traite comme une panne, et
#      un service lent mais vivant ne doit jamais recommander un restart ;
#   3. l alerte elle-meme doit savoir partir (claude -p autorise).
#
# Assertions statiques sur le texte du script, plus UN test de comportement
# (dernier Describe) qui fait echouer une vraie connexion sur la boucle locale :
# une classification se verifie par la sortie du classifieur, pas seulement par
# la presence d'une chaine dans le fichier. Pas de reseau externe, pas de cle.
# Les motifs sont ecrits entre apostrophes simples : une chaine a guillemets
# doubles interpolerait le $ des variables PowerShell et casserait le motif.
BeforeAll {
    $projectRoot = (Resolve-Path -Path "$PSScriptRoot/../../..").Path
    $scriptPath = Join-Path $projectRoot "scripts/monitoring/check-embeddings.ps1"
    $script:mon = Get-Content $scriptPath -Raw
    $script:verdict = Get-Content (Join-Path $projectRoot "scripts/monitoring/embeddings-verdict.ps1") -Raw
}
Describe "Moniteur embeddings -- budget de timeout" {
    It "Le budget par defaut doit couvrir la latence mesuree du vhost" {
        $script:mon | Should -Match '\[int\]\$TimeoutSeconds\s*=\s*(6\d|90|1\d\d)'
    }
    It "Le budget ne doit pas rester a 15 s (cause mesuree des 8 fausses alertes)" {
        $script:mon | Should -Not -Match '\[int\]\$TimeoutSeconds\s*=\s*15\b'
    }
    It "La mesure qui justifie le budget doit etre tracee dans le script" {
        $script:mon | Should -Match '5,9-26 s'
    }
}
Describe "Moniteur embeddings -- timeout confirme, pas presume panne" {
    It "Doit distinguer un timeout d une panne franche" {
        $script:verdict | Should -Match 'WebExceptionStatus\]::Timeout'
    }

    It "Le moniteur doit classer via la fonction de verdict" {
        $script:mon | Should -Match 'Get-EmbeddingsVerdict -ErrorRecord'
        $script:mon | Should -Match 'embeddings-verdict\.ps1'
    }

    It "Le classifieur doit couvrir le timeout de PowerShell 7" {
        $script:verdict | Should -Match 'OperationCanceledException'
    }

    It "Le classifieur doit distinguer un 401/403 : service vivant, cle refusee" {
        $script:verdict | Should -Match 'StatusCode'
        $script:verdict | Should -Match 'Status = "AUTH"'
    }

    It "Un 401 ne doit ni alerte ni code de sortie en echec" {
        $script:mon | Should -Match 'if \(\$status -eq "AUTH"\)\ { exit 0 }'
    }
    It "Doit confirmer par un second essai quand le premier expire" {
        $script:mon | Should -Match 'ConfirmTimeoutSeconds'
    }
    It "Le budget de confirmation doit depasser le budget du premier essai" {
        $script:mon | Should -Match '\[int\]\$ConfirmTimeoutSeconds\s*=\s*1\d\d'
    }
    It "Doit classer un service lent mais vivant en DEGRADED" {
        $script:mon | Should -Match 'DEGRADED'
    }
    It "Le DEGRADED doit produire une alerte [WARN], pas [CRITICAL]" {
        $script:mon | Should -Match 'status\s*-eq\s*"DEGRADED"\s*-and'
        $script:mon | Should -Match 'tags=\[WARN,health-check\]'
    }
}
Describe "Moniteur embeddings -- reponse lente mais vivante (SLOW)" {
    It "Doit distinguer SLOW de OK par un seuil de latence" {
        $script:mon | Should -Match '\[int\]\$SlowThresholdMs\s*=\s*5000'
        $script:mon | Should -Match 'status = "SLOW"'
    }
    It "Le SLOW ne doit pas faire echouer la tache planifiee" {
        $script:mon | Should -Match 'if \(\$status -eq "SLOW"\)\ { exit 0 }'
    }
}
Describe "Moniteur embeddings -- pas de faux diagnostic" {
    It "Le message DEGRADED ne doit pas recommander de restart vLLM" {
        $degradedLine = ($script:mon -split [char]10 | Where-Object { $_ -match "DEGRADED on" }) -join " "
        $degradedLine | Should -Match 'DO NOT restart vLLM'
    }
    It "La branche DEGRADED doit dire que le service est VIVANT" {
        $script:mon | Should -Match 'VIVANT mais lent'
    }
    It "Le DEGRADED ne doit pas faire echouer la tache planifiee" {
        $script:mon | Should -Match 'if \(\$status -eq "DEGRADED"\)\ { exit 0 }'
    }
}
Describe "Moniteur embeddings -- l alerte ne doit pas affirmer une cause non mesuree" {
    # Incident 27/10 : quatre [CRITICAL] contradictoires pour UN incident, et une
    # consigne qui envoyait un agent redemarrer un service situe sur une AUTRE
    # machine (l embedder tourne sur po-2023, la machine qui alerte est ai-01).
    # La branche `timeout` avait deja ete corrigee (#4366, ae8b8218) ; la branche
    # `http` etait restee sur l ancienne formulation et affirmait « the backend
    # itself may be at fault » alors que la sonde n a rien mesure de tel.
    It "La branche HTTP ne doit pas affirmer que le backend est en cause" {
        $httpLine = ($script:mon -split [char]10 | Where-Object { $_ -match "DOWN as seen from" }) -join " "
        $httpLine | Should -Match 'did NOT establish which layer is at fault'
    }
    It "La branche HTTP ne doit pas ordonner un restart sur la machine qui sonde" {
        $httpLine = ($script:mon -split [char]10 | Where-Object { $_ -match "DOWN as seen from" }) -join " "
        $httpLine | Should -Not -Match 'the backend itself may be at fault'
        $httpLine | Should -Match 'Do NOT restart a backend you have not proven to be the culprit'
    }
    It "La branche HTTP doit nommer le proprietaire du backend, pas le lecteur de l alerte" {
        $httpLine = ($script:mon -split [char]10 | Where-Object { $_ -match "DOWN as seen from" }) -join " "
        $httpLine | Should -Match 'the host that actually serves this endpoint'
    }
}

Describe "Moniteur embeddings -- pas de reponse HTTP : une cause distincte du 5xx" {
    # Incident 27/10 : sur ai-01 (PS 5.1), une connexion refusee sortait
    # Status=FAILURE FailureKind=unknown http=0. Le classifieur etait juste ;
    # c est l ALERTE qui tombait dans la branche « l endpoint a repondu » et
    # affirmait une cause que la sonde n avait pas mesuree. Les tests qui
    # precedent lisent le TEXTE ; celui-ci fait echouer une vraie connexion et
    # verifie ce que le classifieur en DIT.
    BeforeAll {
        $verdictPath = Join-Path (Resolve-Path -Path "$PSScriptRoot/../../..").Path "scripts/monitoring/embeddings-verdict.ps1"
        . $verdictPath

        # Port 1 sur la boucle locale : personne n ecoute, le noyau refuse la
        # connexion immediatement. Aucun service externe en depend.
        $script:connectError = $null
        try {
            Invoke-RestMethod -Uri "http://127.0.0.1:1/v1/models" -TimeoutSec 5 | Out-Null
        } catch {
            $script:connectError = $_.Exception
        }
        $script:connectVerdict = Get-EmbeddingsVerdict -ErrorRecord $script:connectError -Message $script:connectError.Message
    }

    It "La connexion doit vraiment echouer (sinon ce Describe ne mesure rien)" {
        $script:connectError | Should -Not -BeNullOrEmpty
    }

    It "Une connexion refusee doit sortir en 'unknown', jamais en 'http'" {
        $script:connectVerdict.FailureKind | Should -Be 'unknown'
        $script:connectVerdict.Status | Should -Be 'FAILURE'
    }

    It "Aucun code HTTP ne doit etre lu quand il n y a pas de reponse" {
        Get-EmbeddingsHttpStatus -ErrorRecord $script:connectError | Should -Be 0
    }

    It "L alerte doit traiter ce cas dans une branche propre, pas dans celle du 5xx" {
        $script:mon | Should -Match 'elseif \(\$failureKind -eq "http"\)'
        $noResponse = ($script:mon -split [char]10 | Where-Object { $_ -match 'NO HTTP response was received' }) -join " "
        $noResponse | Should -Not -BeNullOrEmpty
        $noResponse | Should -Match 'do NOT restart anything'
        $noResponse | Should -Match 'curl --resolve'
        $noResponse | Should -Not -Match 'the endpoint DID answer'
    }
}

Describe "Moniteur embeddings -- l alerte doit savoir partir" {
    It "claude -p doit etre autorise a poster sur le dashboard" {
        $script:mon | Should -Match '--allowedTools "mcp__roo-state-manager__roosync_dashboard"'
        $script:mon | Should -Match '--permission-mode acceptEdits'
    }
    It "Le succes ne doit etre annonce que si claude -p sort en 0" {
        $script:mon | Should -Match 'if \(\$exitCode -eq 0\) { return \$true }'
        $script:mon | Should -Match 'if \(Send-DashboardAlert -Prompt \$prompt\)'
    }
}
