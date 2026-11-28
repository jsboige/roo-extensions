# measure-gdrive-write-freeze.Tests.ps1 — Phase D : le verdict lit l'age BRUT, pas l'arrondi
#
# Precedent scan-store-forks.Tests.ps1 (#4441) : l'hote est pwsh 7 + Pester 5 ;
# la CIBLE tourne en process enfant powershell.exe 5.1, sur le store d'un fixture
# jetable (-SharedPath pointe dessus).
#
# ASSERTIONS EN `throw` (et non `Should -Be`) : le DSL `Should` a change de forme
# entre Pester 3.4 (dispo en PS 5.1), Pester 5 (CI) et Pester 6 (exige PS 7).
# Un `throw` dans un bloc It est un echec de test dans les TROIS versions.
#
# MESURE le 30/10/2026 sur ce siege (scan-store-forks, meme hote/enfant) :
# Pester 6.2.0 charge sous PowerShell 5.1.26100.9711 -> 9/9.
#
# Scenarios (review ai-01 de #4451, 30/10) -- chaque cas epingle un chemin qui
# rendait un verdict FAUX avant le fix :
#   (a) trois familles gelees (+ jumeaux)      -> exit 0, la ligne MET liste les familles vues
#   (b) un fichier CHAUD dans un jumeau        -> exit 1, NOT-MET nomme le jumeau
#   (c) une famille absente (zero instance)    -> exit 2, la sortie NOMME la famille
#   (d) age brut 23 h 58 (affiche 24,0) a 24 h -> exit 1 : la decision lit le brut, l'arrondi n'est que l'affichage
#   (e) une enumeration qui ECHOUE              -> exit 2, la sortie nomme le chemin en echec
#       (jonction cassee : sans la garde, la recursion rend 0 fichier et le mtime de la
#        jonction -- date de sa creation -- fabrique un verdict. Une famille illisible ne
#        doit jamais devenir un verdict, ni FROZEN ni ACTIVE.)
#   #4131 G-MES -- famille dashboards (verdict EXPORT-AWARE, pas gel total) :
#   (f) ecriture recente JUSTIFIEE par un tampon mirrorExportAt frais -> exit 0
#   (g) ecriture recente SANS tampon                            -> exit 1, le fichier est nomme
#   (h) ecriture recente avec tampon PÉRIMÉ (écrit après le dernier export) -> exit 1
#   (i) instance dashboards sans aucun .md                     -> exit 2, pas de verdict fabriqué
#   (j) item 5a : residu + export justifie dans la meme instance -> exit 1, la ligne ACTIVE
#       affiche le compte justifie par export (avant le fix, seule la branche FROZEN le faisait)
#   faux positif mesure c.7126720160 (famille generique, listing recursif) :
#   (k) un desktop.ini FRAIS (caché, posé par l'explorateur) dans une famille gelée
#       -> exit 0 : ce n'est pas un écrivain de données (avant le fix : faux NOT-MET)
#   (l) un fichier CHAUD à côté d'un desktop.ini -> exit 1 : l'exclusion porte sur le NOM
#       du fichier, jamais sur le répertoire (témoin de frontière, vert avant ET après)
#
# Execution : powershell -NoProfile -ExecutionPolicy Bypass -File scripts/testing/run-pester-tests.ps1 -Path scripts/diagnostic/measure-gdrive-write-freeze.Tests.ps1

Describe 'measure-gdrive-write-freeze (Phase D #4131)' {
    BeforeAll {
        $script:RepoRoot = (git -C "$PSScriptRoot\..\.." rev-parse --show-toplevel).Trim()
        $script:SourceScript = Join-Path $script:RepoRoot 'scripts\diagnostic\measure-gdrive-write-freeze.ps1'
        $script:Fixtures = New-Object System.Collections.Generic.List[string]

        function Assert-That {
            param([bool]$Condition, [string]$Message)
            if (-not $Condition) { throw $Message }
        }

        # Store fige : les 3 familles + jumeaux + dashboards (vieux, sans marqueur),
        # tout ecrit il y a $AgeHours h. #4131 G-MES : un .md plus vieux que le
        # seuil ne porte AUCUN signal (ni residual ni export) -- c'est le cas
        # nominal du fixture pour la famille dashboards.
        function New-FrozenStore {
            param([double]$AgeHours = 30)
            $fx = Join-Path $env:TEMP ("gdrivefreeze-" + [guid]::NewGuid().ToString('N').Substring(0, 8))
            New-Item -ItemType Directory -Path (Join-Path $fx 'inventories') -Force | Out-Null
            New-Item -ItemType Directory -Path (Join-Path $fx 'inventories (2)') -Force | Out-Null
            New-Item -ItemType Directory -Path (Join-Path $fx 'messages') -Force | Out-Null
            New-Item -ItemType Directory -Path (Join-Path $fx 'dashboards') -Force | Out-Null
            $stamp = [DateTime]::UtcNow.AddHours(-$AgeHours)
            foreach ($rel in @('inventories\ai-01.json', 'inventories (2)\po-2025.json',
                               'messages\m1.json', '.machine-registry.json', '.machine-registry (1).json',
                               'dashboards\global.md')) {
                $p = Join-Path $fx $rel
                Set-Content -LiteralPath $p -Value '{}' -Encoding ASCII
                (Get-Item -LiteralPath $p).LastWriteTimeUtc = $stamp
            }
            $script:Fixtures.Add($fx)
            return $fx
        }

        # #4131 G-MES -- un .md de dashboard avec frontmatter et (optionnellement)
        # le tampon mirrorExportAt de l'export PG->fichier, mtime reglee a part.
        function New-DashboardFile {
            param([string]$Path, [double]$AgeHours, [double]$StampAgeHours = $null)
            $mtime = [DateTime]::UtcNow.AddHours(-$AgeHours)
            $iso = $mtime.ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
            $fm = "---`ntype: workspace`nlastModified: '$iso'`nlastModifiedBy:`n  machineId: m`n  workspace: w`ntotalMessages: 0`n"
            if ($null -ne $StampAgeHours) {
                $s = [DateTime]::UtcNow.AddHours(-$StampAgeHours).ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
                $fm += "mirrorExportAt: '$s'`n"
            }
            Set-Content -LiteralPath $Path -Value ($fm + "---`n") -Encoding ASCII
            (Get-Item -LiteralPath $Path).LastWriteTimeUtc = $mtime
        }

        function Invoke-Measure {
            param([string]$Store, [double]$FreezeHours = 24)
            $out = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $script:SourceScript `
                -SharedPath $Store -FreezeHours $FreezeHours 2>&1
            return [pscustomobject]@{
                ExitCode = $LASTEXITCODE
                Output   = ($out | Out-String)
            }
        }

        function Set-FileAge {
            param([string]$Path, [double]$AgeHours)
            (Get-Item -LiteralPath $Path).LastWriteTimeUtc = [DateTime]::UtcNow.AddHours(-$AgeHours)
        }

        # Reproduction du faux positif mesure sur le store reel (c.7126720160) : un
        # `desktop.ini` pose par l'explorateur -- attribut Hidden, mtime recent -- dans
        # une instance sinon gelee. Ce fichier configure la VUE du dossier ; aucun
        # ecrivain de donnees ne le produit.
        function Add-DesktopIni {
            param([string]$Path, [double]$AgeHours = 0.5)
            Set-Content -LiteralPath $Path -Value '[ViewState]' -Encoding ASCII
            # L'age se regle AVANT l'attribut : `Get-Item -LiteralPath` sans -Force ne voit
            # pas un fichier cache (mesure : ItemNotFound dans Set-FileAge).
            Set-FileAge -Path $Path -AgeHours $AgeHours
            (Get-Item -LiteralPath $Path -Force).Attributes = [IO.FileAttributes]::Hidden
        }
    }

    AfterAll {
        foreach ($fx in $script:Fixtures) {
            if (Test-Path -LiteralPath $fx) {
                # Cas (e) : delier les jonctions AVANT le rm recursif -- `Remove-Item -Recurse`
                # suit un reparse point et supprimerait la cible, et refuse la jonction cassee.
                # `[IO.Directory]::Delete($p, $false)` = rmdir nu : supprime le lien seul.
                Get-ChildItem -LiteralPath $fx -Force -ErrorAction SilentlyContinue |
                    Where-Object { $_.LinkType } |
                    ForEach-Object { [IO.Directory]::Delete($_.FullName, $false) }
                Remove-Item -LiteralPath $fx -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }


    It '(a) trois familles gelees (+ jumeaux) rendent MET, avec les familles vues' {
        $fx = New-FrozenStore
        $r = Invoke-Measure -Store $fx
        Assert-That ($r.ExitCode -eq 0) "exit code attendu 0 (FROZEN), obtenu $($r.ExitCode) -- sortie: $($r.Output)"
        Assert-That ($r.Output -match 'PHASE-D\] MET') "ligne MET absente de la sortie"
        Assert-That ($r.Output -match [regex]::Escape('inventories, messages, .machine-registry')) "la ligne MET ne liste pas les familles vues"
    }

    It '(b) un fichier chaud dans un jumeau rend NOT-MET en nommant le jumeau' {
        $fx = New-FrozenStore
        Set-FileAge -Path (Join-Path $fx 'inventories (2)\po-2025.json') -AgeHours 1
        $r = Invoke-Measure -Store $fx
        Assert-That ($r.ExitCode -eq 1) "exit code attendu 1 (ACTIVE), obtenu $($r.ExitCode) -- sortie: $($r.Output)"
        Assert-That ($r.Output -match 'PHASE-D\] NOT-MET') "ligne NOT-MET absente de la sortie"
        Assert-That ($r.Output -match [regex]::Escape('inventories (2)')) "le jumeau chaud n'est pas nomme dans la sortie"
    }

    It '(c) une famille sans aucune instance rend exit 2 en la NOMMANT (jamais MET silencieux)' {
        $fx = New-FrozenStore
        Remove-Item -LiteralPath (Join-Path $fx 'messages') -Recurse -Force
        $r = Invoke-Measure -Store $fx
        Assert-That ($r.ExitCode -eq 2) "exit code attendu 2 (instrument), obtenu $($r.ExitCode) -- sortie: $($r.Output)"
        Assert-That ($r.Output -match [regex]::Escape('messages')) "la famille absente n'est pas nommee dans la sortie"
    }

    It '(d) age brut 23 h 58 sous un seuil de 24 h reste ACTIVE (l''arrondi n''est que l''affichage)' {
        $fx = New-FrozenStore
        Set-FileAge -Path (Join-Path $fx 'messages\m1.json') -AgeHours (23 + 58/60)
        $r = Invoke-Measure -Store $fx
        Assert-That ($r.ExitCode -eq 1) "exit code attendu 1 (ACTIVE) : 23 h 58 brut < 24 h meme si l'arrondi affiche 24,0 -- obtenu $($r.ExitCode) -- sortie: $($r.Output)"
        Assert-That ($r.Output -match 'PHASE-D\] NOT-MET') "ligne NOT-MET absente de la sortie"
    }

    It '(e) une enumeration en echec (jonction cassee) rend exit 2, jamais un verdict fabrique' {
        $fx = New-FrozenStore
        # Famille lisible, mais une INSTANCE de la famille est illisible : la recursion dedans
        # echoue. Sans la garde, Get-ChildItem rend 0 fichier et le mtime de la jonction (sa
        # date de creation, donc "maintenant") fabrique un verdict ACTIVE sur une ecriture qui
        # n'a jamais eu lieu. Mesure du 31/10 sur ce siege : la garde rend
        # `[INSTRUMENT] enumeration inside <chemin> errored: ...` + exit 2.
        # Jonction et non repertoire : c'est le seul moyen portable de rendre une entree
        # enumerable PARENT mais illisible DEDANS, sans ACE ni droit eleve. La suite est de
        # toute facon Windows-only (enfant powershell.exe 5.1).
        $junc = Join-Path $fx 'inventories (9)'
        # `New-Item -ItemType Junction` REFUSE une cible absente (mesure du 31/10 sur ce siege :
        # "Nous n'avons pas pu trouver l'element ...") -- `mklink /J` l'accepte, c'est donc lui
        # qui fabrique la jonction CASSEE. Les guillemets ne sont pas cosmetiques : le nom du
        # fixture contient un espace et des parentheses.
        cmd /c mklink /J "$junc" (Join-Path $fx '__absent-target__') | Out-Null
        Assert-That ((Get-Item -LiteralPath $junc -Force -ErrorAction SilentlyContinue).LinkType -eq 'Junction') 'fixture : la jonction cassee n''a pas ete creee'
        $r = Invoke-Measure -Store $fx
        Assert-That ($r.ExitCode -eq 2) "exit code attendu 2 (instrument), obtenu $($r.ExitCode) -- sortie: $($r.Output)"
        Assert-That ($r.Output -match 'enumeration inside') "la sortie ne dit pas quelle enumeration a echoue: $($r.Output)"
        Assert-That ($r.Output -match [regex]::Escape('inventories (9)')) "la sortie ne nomme pas l'instance illisible: $($r.Output)"
    }

    It '(f) G-MES: une ecriture recente de dashboard JUSTIFIEE par un tampon mirrorExportAt frais rend MET' {
        $fx = New-FrozenStore
        # mtime il y a 1 h, tampon pose a la MEME heure : c'est une ecriture
        # d'export du daemon (repairDashboardMirrorFromPg), pas un ecrivain
        # residuel. Le reste du store est gele -> MET global.
        New-DashboardFile -Path (Join-Path $fx 'dashboards\workspace-x.md') -AgeHours 1 -StampAgeHours 1
        $r = Invoke-Measure -Store $fx
        Assert-That ($r.ExitCode -eq 0) "exit 0 attendu (l''export ne compte pas comme ecrivain residuel), obtenu $($r.ExitCode) -- sortie: $($r.Output)"
        Assert-That ($r.Output -match 'export-aware') "la ligne dashboards detail absente: $($r.Output)"
    }

    It '(g) G-MES: une ecriture recente SANS tampon rend NOT-MET en nommant le fichier' {
        $fx = New-FrozenStore
        New-DashboardFile -Path (Join-Path $fx 'dashboards\workspace-x.md') -AgeHours 1
        $r = Invoke-Measure -Store $fx
        Assert-That ($r.ExitCode -eq 1) "exit 1 attendu (ecrivain residuel sans marqueur), obtenu $($r.ExitCode) -- sortie: $($r.Output)"
        Assert-That ($r.Output -match 'PHASE-D\] NOT-MET') "ligne NOT-MET absente: $($r.Output)"
        Assert-That ($r.Output -match [regex]::Escape('workspace-x.md')) "le fichier residuel n'est pas nomme: $($r.Output)"
    }

    It '(h) G-MES: tampon PERIME (ecriture apres le dernier export) rend NOT-MET' {
        $fx = New-FrozenStore
        # mtime il y a 1 h mais tampon d'export il y a 30 h : une ecriture a eu
        # lieu APRES le dernier export -- c'est un ecrivain residuel, le
        # marqueur ne justifie que la derniere ecriture d'export.
        New-DashboardFile -Path (Join-Path $fx 'dashboards\workspace-x.md') -AgeHours 1 -StampAgeHours 30
        $r = Invoke-Measure -Store $fx
        Assert-That ($r.ExitCode -eq 1) "exit 1 attendu (ecriture posterieure au dernier export), obtenu $($r.ExitCode) -- sortie: $($r.Output)"
        Assert-That ($r.Output -match [regex]::Escape('workspace-x.md')) "le fichier residuel n'est pas nomme: $($r.Output)"
    }

    It '(i) G-MES: une instance dashboards sans aucun .md rend exit 2' {
        $fx = New-FrozenStore
        Remove-Item -LiteralPath (Join-Path $fx 'dashboards\global.md') -Force
        $r = Invoke-Measure -Store $fx
        Assert-That ($r.ExitCode -eq 2) "exit 2 attendu (famille vide = pas de verdict), obtenu $($r.ExitCode) -- sortie: $($r.Output)"
        Assert-That ($r.Output -match 'zero \.md files') "le motif d'instance vide n'est pas rendu: $($r.Output)"
    }

    It '(j) G-MES item 5a: la branche ACTIVE affiche AUSSI le compte justifie par export' {
        $fx = New-FrozenStore
        # Deux ecritures recentes : l'une justifiee par un tampon frais, l'autre
        # residuelle. Le verdict reste NOT-MET (le residu existe), mais la ligne
        # doit rendre le compte justifie -- avant l'item 5a, seule la branche
        # FROZEN (zero residu) l'affichait : un lecteur de la branche ACTIVE ne
        # pouvait pas distinguer "2 ecrivains" de "1 ecrivain + 1 export justifie".
        New-DashboardFile -Path (Join-Path $fx 'dashboards\workspace-a.md') -AgeHours 1 -StampAgeHours 1
        New-DashboardFile -Path (Join-Path $fx 'dashboards\workspace-b.md') -AgeHours 1
        $r = Invoke-Measure -Store $fx
        Assert-That ($r.ExitCode -eq 1) "exit 1 attendu (un residu subsiste), obtenu $($r.ExitCode) -- sortie: $($r.Output)"
        Assert-That ($r.Output -match [regex]::Escape('workspace-b.md')) "le fichier residuel n'est pas nomme: $($r.Output)"
        Assert-That ($r.Output -match '1 export-justified') "la branche ACTIVE n'affiche pas le compte justifie par export: $($r.Output)"
        Assert-That ($r.Output -notmatch [regex]::Escape('workspace-a.md')) "le fichier justifie ne doit pas etre liste comme residu: $($r.Output)"
    }

    It '(k) un desktop.ini frais (cache, pose par l''explorateur) dans une famille gelee rend MET, pas un faux NOT-MET' {
        $fx = New-FrozenStore
        Add-DesktopIni -Path (Join-Path $fx 'messages\desktop.ini')
        Add-DesktopIni -Path (Join-Path $fx 'inventories (2)\desktop.ini')
        $r = Invoke-Measure -Store $fx
        Assert-That ($r.ExitCode -eq 0) "exit 0 attendu (desktop.ini n'est pas un ecrivain de donnees), obtenu $($r.ExitCode) -- sortie: $($r.Output)"
        Assert-That ($r.Output -match 'PHASE-D\] MET') "ligne MET absente de la sortie"
        Assert-That ($r.Output -match [regex]::Escape('inventories, messages, .machine-registry')) "la ligne MET ne liste pas les familles vues: $($r.Output)"
        Assert-That ($r.Output -notmatch [regex]::Escape('desktop.ini')) "desktop.ini est encore nomme comme derniere ecriture: $($r.Output)"
    }

    It '(l) un fichier chaud a cote d''un desktop.ini reste NOT-MET : l''exclusion est par NOM de fichier, pas par repertoire' {
        $fx = New-FrozenStore
        # Témoin de frontière, vert AVANT et APRES le fix : une exclusion trop large
        # (sauter toute instance qui contient un desktop.ini) masquerait un vrai
        # ecrivain. Le jumeau chaud doit rester nomme.
        Add-DesktopIni -Path (Join-Path $fx 'inventories (2)\desktop.ini')
        Set-FileAge -Path (Join-Path $fx 'inventories (2)\po-2025.json') -AgeHours 1
        $r = Invoke-Measure -Store $fx
        Assert-That ($r.ExitCode -eq 1) "exit 1 attendu (le jumeau chaud reste un ecrivain), obtenu $($r.ExitCode) -- sortie: $($r.Output)"
        Assert-That ($r.Output -match 'PHASE-D\] NOT-MET') "ligne NOT-MET absente: $($r.Output)"
        Assert-That ($r.Output -match [regex]::Escape('inventories (2)')) "le jumeau chaud n'est pas nomme dans la sortie: $($r.Output)"
    }

    It '(m) une tete de dashboard ILLISIBLE rend NOT-MET en la nommant comme INCONNUE, jamais comme export justifiee' {
        $fx = New-FrozenStore
        # Tete illisible = le contenu n'est pas servi (DriveFS) ou le fichier est
        # tenu en ecriture : la justification de l'ecriture ne peut NI etre prouvee
        # NI etre infirmee. Le fichier passe INCONNU -- il ne doit PAS compter comme
        # export justifiee (sinon un residu masqué), et le verdict reste NOT-MET
        # (un critere de gel ne se prouve pas sur une mesure incomplete).
        $locked = Join-Path $fx 'dashboards\workspace-locked.md'
        New-DashboardFile -Path $locked -AgeHours 1
        $handle = [System.IO.File]::Open($locked, [System.IO.FileMode]::Open, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None)
        try {
            $r = Invoke-Measure -Store $fx
            Assert-That ($r.ExitCode -eq 1) "exit 1 attendu (justification inconnue = critere non prouve), obtenu $($r.ExitCode) -- sortie: $($r.Output)"
            Assert-That ($r.Output -match [regex]::Escape('workspace-locked.md')) "le fichier a tete illisible n'est pas nomme: $($r.Output)"
            Assert-That ($r.Output -match 'head illisible') "la sortie ne distingue pas l'inconnue du residu: $($r.Output)"
            Assert-That ($r.Output -notmatch [regex]::Escape('1 export-justified')) "le fichier illisible a ete compte comme export justifie: $($r.Output)"
        } finally {
            $handle.Dispose()
        }
    }
}
