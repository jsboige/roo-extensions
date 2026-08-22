# Tests unitaires pour scripts/infra/update-gandi-dns.ps1
#
# Ce que ces tests couvrent, et POURQUOI c'est ce morceau-la :
# le script reecrit les enregistrements A de myia.io, par lesquels TOUTE la flotte
# resout. Le chemin nominal ("l'IP n'a pas change") s'eprouve en vrai sans risque ;
# le chemin qui compte -- celui du changement d'IP -- ne peut pas etre declenche en
# production sans provoquer la panne qu'il est cense reparer.
#
# La piece critique est donc testee ici en isolation : Get-BoxFollowingRrsets, qui
# decide QUELS rrsets sont reecrits. S'y tromper coute soit des enregistrements
# perimes (mesure du 2026-08-22 : 8 rrsets A suivaient la box, un updater limite au
# wildcard en aurait laisse 7 derriere), soit l'ecrasement d'un enregistrement qui
# pointait deliberement ailleurs.
#
# Le script est dot-source : il ne definit alors que ses fonctions, sans effet de
# bord ni P/Invoke Windows -- les tests tournent donc aussi sur Linux en CI.
#
# Syntaxe Pester v5 -- execute en CI par le job `unit-pester` (#3216) via
# scripts/testing/run-pester-tests.ps1.
#
# Usage:
#   pwsh -NoProfile -Command "Invoke-Pester -Path ./scripts/testing/unit/update-gandi-dns.Tests.ps1 -Output Detailed"

BeforeAll {
    $projectRoot = (Resolve-Path -Path "$PSScriptRoot/../../..").Path
    $script:ScriptPath = Join-Path $projectRoot 'scripts/infra/update-gandi-dns.ps1'
    . $script:ScriptPath

    # Forme reelle de la zone myia.io, relevee le 2026-08-22.
    function New-Rrset {
        param([string]$Name, [string]$Type, [string[]]$Values, [int]$Ttl = 300)
        [pscustomobject]@{ rrset_name = $Name; rrset_type = $Type; rrset_values = $Values; rrset_ttl = $Ttl }
    }

    $script:BoxIp = '90.65.170.144'
    $script:Zone = @(
        New-Rrset '@'         'A'     @($script:BoxIp)
        New-Rrset '*'         'A'     @($script:BoxIp)
        New-Rrset '*.blog'    'A'     @($script:BoxIp)
        New-Rrset '*.imap'    'A'     @($script:BoxIp)
        New-Rrset '*.pop'     'A'     @($script:BoxIp)
        New-Rrset '*.smtp'    'A'     @($script:BoxIp)
        New-Rrset '*.webmail' 'A'     @($script:BoxIp)
        New-Rrset '*.www'     'A'     @($script:BoxIp)
        New-Rrset 'www'       'CNAME' @('webredir.vip.gandi.net.')
        New-Rrset '@'         'MX'    @('10 spool.mail.gandi.net.')
        New-Rrset '@'         'TXT'   @('"v=spf1 include:_mailcust.gandi.net ?all"')
    )
}

Describe 'update-gandi-dns.ps1' {

    Context 'Le dot-source ne produit aucun effet de bord' {
        It 'expose les fonctions sans executer la mise a jour' {
            Get-Command Get-BoxFollowingRrsets -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
            Get-Command Invoke-GandiDnsUpdate  -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }

        It "n'ecrit pas de fichier de log au chargement" {
            # Initialize-Logging n'est appelee que par le chemin d'execution reelle.
            $script:LogFile | Should -BeNullOrEmpty
        }
    }

    Context 'Get-BoxFollowingRrsets -- selection des enregistrements a reecrire' {

        It 'retient les 8 rrsets A qui suivent la box' {
            $r = Get-BoxFollowingRrsets -Records $script:Zone -Ip $script:BoxIp
            $r.Count | Should -Be 8
        }

        It "retient l'apex ET le wildcard -- un updater limite a '*' laisserait l'apex perime" {
            $names = @(Get-BoxFollowingRrsets -Records $script:Zone -Ip $script:BoxIp | ForEach-Object { $_.rrset_name })
            $names | Should -Contain '@'
            $names | Should -Contain '*'
        }

        It 'retient les sous-wildcards, invisibles pour qui ne regarde que la racine' {
            $names = @(Get-BoxFollowingRrsets -Records $script:Zone -Ip $script:BoxIp | ForEach-Object { $_.rrset_name })
            foreach ($n in '*.blog', '*.imap', '*.pop', '*.smtp', '*.webmail', '*.www') {
                $names | Should -Contain $n
            }
        }

        It 'ignore les types autres que A' {
            $types = @(Get-BoxFollowingRrsets -Records $script:Zone -Ip $script:BoxIp | ForEach-Object { $_.rrset_type })
            $types | Should -Not -Contain 'CNAME'
            $types | Should -Not -Contain 'MX'
            $types | Should -Not -Contain 'TXT'
        }

        It "ne touche pas un A qui pointe deliberement ailleurs" {
            $zone = $script:Zone + @(New-Rrset 'vps' 'A' @('37.187.180.135'))
            $names = @(Get-BoxFollowingRrsets -Records $zone -Ip $script:BoxIp | ForEach-Object { $_.rrset_name })
            $names | Should -Not -Contain 'vps'
            $names.Count | Should -Be 8
        }

        It "ne touche pas un rrset multi-valeurs -- l'ecraser detruirait un round-robin" {
            $zone = $script:Zone + @(New-Rrset 'ha' 'A' @($script:BoxIp, '37.187.180.135'))
            $names = @(Get-BoxFollowingRrsets -Records $zone -Ip $script:BoxIp | ForEach-Object { $_.rrset_name })
            $names | Should -Not -Contain 'ha'
        }

        It 'ne retient rien une fois la zone deja migree vers la nouvelle IP' {
            # Etat attendu apres une mise a jour reussie : c'est l'assertion sur laquelle
            # repose la contre-epreuve de fin de script.
            $migre = @($script:Zone | ForEach-Object {
                $v = if ($_.rrset_type -eq 'A' -and $_.rrset_values -contains $script:BoxIp) { @('203.0.113.7') } else { $_.rrset_values }
                New-Rrset $_.rrset_name $_.rrset_type $v $_.rrset_ttl
            })
            (Get-BoxFollowingRrsets -Records $migre -Ip $script:BoxIp).Count | Should -Be 0
            (Get-BoxFollowingRrsets -Records $migre -Ip '203.0.113.7').Count | Should -Be 8
        }

        It 'rend un tableau vide, pas $null, quand rien ne correspond' {
            # Regression : PowerShell deroule un tableau vide au retour d'une fonction,
            # qui revient alors en $null -- et '$null.Count' leve sous StrictMode. Le cas
            # vide etant celui du SUCCES dans la contre-epreuve de fin de mise a jour,
            # chaque update reussie aurait ete rapportee comme un echec. D'ou le ',' dans
            # Get-BoxFollowingRrsets. Ne PAS piper vers Should ici : le pipe deroulerait
            # a nouveau le tableau et l'assertion perdrait son objet.
            $r = Get-BoxFollowingRrsets -Records $script:Zone -Ip '198.51.100.1'
            $r -is [array] | Should -BeTrue -Because 'le tableau ne doit pas etre deroule en $null au retour'
            $r.Count | Should -Be 0
        }
    }

    Context 'Preservation du TTL' {
        It 'conserve le TTL de chaque rrset -- le script reecrit la valeur, pas la politique de cache' {
            $zone = @(
                New-Rrset '@' 'A' @($script:BoxIp) 300
                New-Rrset 'x' 'A' @($script:BoxIp) 1800
            )
            $ttls = @(Get-BoxFollowingRrsets -Records $zone -Ip $script:BoxIp | ForEach-Object { $_.rrset_ttl })
            $ttls | Should -Contain 300
            $ttls | Should -Contain 1800
        }
    }
}
