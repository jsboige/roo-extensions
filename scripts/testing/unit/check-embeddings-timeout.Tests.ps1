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
# Assertions statiques sur le texte du script : pas de reseau, pas de cle.
# Les motifs sont ecrits entre apostrophes simples : une chaine a guillemets
# doubles interpolerait le $ des variables PowerShell et casserait le motif.
BeforeAll {
    $projectRoot = (Resolve-Path -Path "$PSScriptRoot/../../..").Path
    $scriptPath = Join-Path $projectRoot "scripts/monitoring/check-embeddings.ps1"
    $script:mon = Get-Content $scriptPath -Raw
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
        $script:mon | Should -Match 'WebExceptionStatus\]::Timeout'
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
