<#
.SYNOPSIS
    Tests B14 (#4131) — aiguillage PG-first de la lecture inbox du worker planifié.

.DESCRIPTION
    start-claude-worker.ps1 lisait `messages\inbox` comme fichiers dans deux
    fonctions (Get-RooSyncTask, Test-RooSyncResponse). Sous CHANNEL_PG_PRIMARY
    les messages n'ont plus de fichiers : ces fonctions devenaient aveugles.
    B14 les branche sur le CLI du submodule (read-roosync-inbox.mjs) avec le
    contrat de la review ms#1481 :
      - exit 0 = {source:'pg', messages} — PG FAIT FOI, MÊME VIDE (aucun
        repli fichiers sur une lecture PG réussie) ;
      - exit 3 / 1 / CLI absent / exception = repli chemin fichiers legacy ;
      - filtres [TASK]/[URGENT]/status/self côté APPELANT (contrat) ;
      - pas de messageFile sous PG. B17 (25/10) : le marquage « consommé »
        passe par le CLI --mark-read du submodule (même chemin per-reader que
        le mark_read MCP) — sans lui le worker resservait le MÊME [TASK] à
        chaque cycle (6 servis en 30 h, ai-01). Aucune erreur CLI ne doit
        faire échouer le run : WARN et poursuite.

    Les fonctions sont extraites du worker via AST (pas de dot-source du
    script entier — convention worker-resume-prompt.Tests.ps1). Le seam
    Get-RooSyncInboxMessages est stubbé pour les tests d'aiguillage, puis
    testé POUR VRAI avec un faux `node` sur PATH (node.cmd sous Windows,
    script sh + shim `cmd` sous Linux CI — l'invocation du helper passe
    par la couche cmd.exe, convention #3731) — aucun PG réel requis.

    Portabilité CI Linux : la machine du runner est inconnue à l'avance —
    chaque fixture adresse $script:MACHINE (ou 'all'), et les répertoires
    fixtures utilisent le MÊME calcul de chemin que le worker (littéral
    'messages\inbox' via Join-Path), pas un chemin orthographié à la main.

.NOTES
    Coordination: jsboige/roo-extensions#4131 (B14, précondition du 24/10).
    Exécuté en CI par le job `unit-pester` (#3216) via run-pester-tests.ps1.
    Fichier UTF-8 AVEC BOM (#2368 — prose non-ASCII sous PS 5.1).
#>

# Données liées pour les -ForEach (portée fichier, lues à la découverte).
# Placeholders remplis à l'exécution : @@MACHINE@@, @@SELF@@.
$script:FilterCases = @(
    @{ label = 'subject non actionable'; to = '@@MACHINE@@'; from = 'myia-ai-01:roo-extensions'; subject = '[DONE] boucle'; status = 'unread'; tags = $null }
    @{ label = 'deja lu';               to = '@@MACHINE@@'; from = 'myia-ai-01:roo-extensions'; subject = '[TASK] relu';  status = 'read';   tags = $null }
    @{ label = 'message de soi';        to = '@@MACHINE@@'; from = '@@SELF@@';                   subject = '[TASK] self'; status = 'unread'; tags = $null }
    @{ label = 'worker-report';         to = '@@MACHINE@@'; from = 'myia-po-2024:roo-extensions'; subject = '[TASK] report'; status = 'unread'; tags = @('worker-report') }
    @{ label = 'destinataire autre';    to = 'myia-po-2999'; from = 'myia-ai-01:roo-extensions'; subject = '[TASK] autre'; status = 'unread'; tags = $null }
)

Describe 'Worker inbox PG-first (B14 #4131)' {

    BeforeAll {
        $projectRoot = (Resolve-Path -Path "$PSScriptRoot/../../..").Path
        $script:WorkerScript = Join-Path $projectRoot 'scripts/scheduling/start-claude-worker.ps1'
        $script:Content = Get-Content $script:WorkerScript -Raw

        # --- Parse + extraction AST (convention worker-resume-prompt) ---
        $tokens = $null; $errors = $null
        $script:Ast = [System.Management.Automation.Language.Parser]::ParseFile(
            $script:WorkerScript, [ref]$tokens, [ref]$errors)
        $script:ParseErrors = $errors

        foreach ($name in @('Get-RooSyncInboxMessages', 'Get-RooSyncTask', 'Test-RooSyncResponse', 'ConvertTo-UtcDateTime')) {
            $fn = $script:Ast.FindAll({
                param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
                          $n.Name -eq $name
            }, $true) | Select-Object -First 1
            if ($fn) { . ([scriptblock]::Create($fn.Extent.Text)) }
        }

        # Stub du logger attendu dans le scope appelant (convention heartbeat).
        function global:Write-Log {
            param([string]$Message, [string]$Level = "INFO")
            $script:CapturedLogs += $Message
        }
        $script:CapturedLogs = @()

        # $RepoRoot : resolu dynamiquement par le helper extrait.
        $RepoRoot = $projectRoot

        # --- Stub du seam CLI : defini APRES l'extraction, la remplace dans
        # ce scope ; le contexte "vrai helper" re-extrait la version reelle
        # dans son propre BeforeAll (scopage Pester : elle y fait ombre).
        function Get-RooSyncInboxMessages {
            param([string]$MachineId)
            return $script:StubCliResult
        }

        # --- Machine du runner + fixtures chemin fichiers (legacy) ---
        # Test-RooSyncResponse derive la machine EN INTERNE
        # ($env:COMPUTERNAME.ToLower()) : sur Linux CI la variable est absente
        # et .ToLower() sur $null plante dans le catch. On fixe une machine
        # synthetique pour tout le Describe — deterministe sur les deux OS.
        $script:OrigComputerName = $env:COMPUTERNAME
        $env:COMPUTERNAME = 'CI-B14-MACHINE'
        # Le calcul du chemin inbox doit rester IDENTIQUE a celui du worker
        # (litteral 'messages\inbox' via Join-Path) — sous Linux CI, ce
        # litteral est un segment unique : le fixture doit le construire par
        # le meme Join-Path, pas par un chemin re-orthographie.
        $script:MACHINE = 'ci-b14-machine'
        $script:FileRoot = Join-Path ([System.IO.Path]::GetTempPath()) "b14-inbox-tests-$(Get-Random)"
        $script:InboxDir = Join-Path $FileRoot 'messages\inbox'
        New-Item -ItemType Directory -Force -Path $script:InboxDir | Out-Null

        $script:FileTaskPath = Join-Path $script:InboxDir 'file-task-1.json'
        [System.IO.File]::WriteAllText($script:FileTaskPath, (@{
            id = 'file-task-1'; from = 'myia-ai-01:roo-extensions'; to = $script:MACHINE
            subject = '[TASK] fichier legacy'; body = 'reponse a file-task-1'; priority = 'LOW'
            status = 'unread'; timestamp = '2026-10-22T09:00:00Z'
        } | ConvertTo-Json), [System.Text.UTF8Encoding]::new($false))

        $env:ROOSYNC_SHARED_PATH = $script:FileRoot
    }

    BeforeEach {
        $script:CapturedLogs = @()
        $script:StubCliResult = $null
    }

    AfterAll {
        Remove-Item $script:FileRoot -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item Env:\ROOSYNC_SHARED_PATH -ErrorAction SilentlyContinue
        Remove-Item Function:\global:Write-Log -ErrorAction SilentlyContinue
        if ($null -ne $script:OrigComputerName) {
            $env:COMPUTERNAME = $script:OrigComputerName
        } else {
            Remove-Item Env:\COMPUTERNAME -ErrorAction SilentlyContinue
        }
    }

    It 'Parse le worker sans erreur de syntaxe' {
        $script:ParseErrors.Count | Should -Be 0
    }

    Context 'Get-RooSyncTask : PG fait foi (exit 0)' {

        It 'retourne la tache PG avec messageFile NULL, meme si un fichier legacy existe' {
            # Un [TASK] fichier legacy est sur disque : la lecture PG reussie
            # doit l'IGNORER (PG fait foi) et rendre la tache PG.
            $script:StubCliResult = [pscustomobject]@{
                source = 'pg'
                messages = @([pscustomobject]@{
                    id = 'msg-pg-1'; from = 'myia-ai-01:roo-extensions'; to = $script:MACHINE
                    subject = '[TASK] depuis pg'; body = 'corps pg'; priority = 'HIGH'
                    status = 'unread'; timestamp = '2026-10-22T12:00:00Z'
                })
            }
            $task = Get-RooSyncTask -MachineId $script:MACHINE
            $task | Should -Not -BeNullOrEmpty
            $task.id | Should -Be 'msg-pg-1'
            $task.source | Should -Be 'roosync'
            $task.inboxSource | Should -Be 'pg'
            $task.messageFile | Should -BeNullOrEmpty
            $task.prompt | Should -Be 'corps pg'
        }

        It 'PG vide = PAS de repli fichiers (null malgre le fichier legacy present)' {
            # Le contrat : exit 0 avec messages vide est AUTORITAIRE. Le
            # fichier legacy file-task-1.json existe pourtant — jamais servi.
            $script:StubCliResult = [pscustomobject]@{ source = 'pg'; messages = @() }
            Get-RooSyncTask -MachineId $script:MACHINE | Should -BeNullOrEmpty
        }

        It 'filtre cote appelant : <label> ne produit aucune tache' -ForEach $script:FilterCases {
            $msg = @{
                id = 'm-case'; to = ($_.to -replace '@@MACHINE@@', $script:MACHINE)
                from = ($_.from -replace '@@SELF@@', "$($script:MACHINE):roo-extensions")
                subject = $_.subject; body = 'b'; priority = 'MEDIUM'
                status = $_.status; timestamp = '2026-10-22T12:00:00Z'
            }
            if ($_.tags) { $msg.tags = $_.tags }
            $script:StubCliResult = [pscustomobject]@{ source = 'pg'; messages = @([pscustomobject]$msg) }
            Get-RooSyncTask -MachineId $script:MACHINE | Should -BeNullOrEmpty
        }

        It 'tri par priorite : URGENT gagne sur MEDIUM' {
            $script:StubCliResult = [pscustomobject]@{
                source = 'pg'
                messages = @(
                    [pscustomobject]@{ id = 'm-med'; from = 'myia-ai-01:roo-extensions'; to = $script:MACHINE; subject = '[TASK] medium'; body = 'b'; priority = 'MEDIUM'; status = 'unread'; timestamp = '2026-10-22T12:00:00Z' }
                    [pscustomobject]@{ id = 'm-urg'; from = 'myia-ai-01:roo-extensions'; to = $script:MACHINE; subject = '[TASK] urgent'; body = 'b'; priority = 'URGENT'; status = 'unread'; timestamp = '2026-10-22T12:00:00Z' }
                )
            }
            (Get-RooSyncTask -MachineId $script:MACHINE).id | Should -Be 'm-urg'
        }
    }

    Context 'Get-RooSyncTask : repli fichiers (helper null = exit 3/1/absent)' {

        It 'sert la tache fichier legacy AVEC messageFile et inboxSource file' {
            $task = Get-RooSyncTask -MachineId $script:MACHINE
            $task | Should -Not -BeNullOrEmpty
            $task.id | Should -Be 'file-task-1'
            $task.inboxSource | Should -Be 'file'
            $task.messageFile | Should -Be $script:FileTaskPath
        }
    }

    Context 'Test-RooSyncResponse : meme aiguillage' {

        It 'reponse PG plus recente que le checkpoint et matchant TaskId = true' {
            # to='all' : la fonction derive la machine en interne (COMPUTERNAME),
            # on ne peut pas l'injecter — le broadcast matche tout runner.
            $script:StubCliResult = [pscustomobject]@{
                source = 'pg'
                messages = @([pscustomobject]@{
                    id = 'msg-pg-1'; from = 'myia-ai-01:roo-extensions'; to = 'all'
                    subject = '[REPLY] msg-pg-1'; body = 'corps'; priority = 'HIGH'
                    status = 'unread'; timestamp = '2026-10-22T12:00:00Z'
                })
            }
            Test-RooSyncResponse -TaskId 'msg-pg-1' -WaitState @{ timestamp = '2026-10-22T10:00:00Z' } | Should -BeTrue
        }

        It 'reponse PG plus ANCIENNE que le checkpoint = false' {
            $script:StubCliResult = [pscustomobject]@{
                source = 'pg'
                messages = @([pscustomobject]@{
                    id = 'msg-pg-1'; from = 'myia-ai-01:roo-extensions'; to = 'all'
                    subject = '[REPLY] msg-pg-1'; body = 'corps'; priority = 'HIGH'
                    status = 'unread'; timestamp = '2026-10-22T12:00:00Z'
                })
            }
            Test-RooSyncResponse -TaskId 'msg-pg-1' -WaitState @{ timestamp = '2026-10-22T13:00:00Z' } | Should -BeFalse
        }

        It 'repli fichiers : reponse legacy detectee (chemin inchangé)' {
            # Stub null → chemin fichiers ; la fixture file-task-1 (09:00) est
            # plus recente que le checkpoint 08:00 et porte l'id cherche.
            Test-RooSyncResponse -TaskId 'file-task-1' -WaitState @{ timestamp = '2026-10-22T08:00:00Z' } | Should -BeTrue
        }

        It 'PG vide (exit 0, messages vides) = false, sans lire les fichiers' {
            $script:StubCliResult = [pscustomobject]@{ source = 'pg'; messages = @() }
            Test-RooSyncResponse -TaskId 'file-task-1' -WaitState @{ timestamp = '2026-10-22T08:00:00Z' } | Should -BeFalse
        }
    }

    Context 'Get-RooSyncInboxMessages (vrai helper, faux node sur PATH)' {

        BeforeAll {
            # Re-extraction du VRAI helper dans ce scope : elle fait ombre au
            # stub du Describe pour les tests de ce contexte.
            $fn = $script:Ast.FindAll({
                param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
                          $n.Name -eq 'Get-RooSyncInboxMessages'
            }, $true) | Select-Object -First 1
            . ([scriptblock]::Create($fn.Extent.Text))

            # Faux node cross-plateforme : node.cmd (Windows, resolu par cmd.exe
            # via PATHEXT) + node sh (Linux CI). Le discriminant de plateforme
            # est $env:OS, PAS COMPUTERNAME (force a CI-B14-MACHINE par le
            # Describe). Les payloads canned ne contiennent aucun caractere
            # special cmd (%^&|<>).
            $script:FakeBin = Join-Path ([System.IO.Path]::GetTempPath()) "b14-fake-node-$(Get-Random)"
            New-Item -ItemType Directory -Force -Path $script:FakeBin | Out-Null
            $script:Json = '{"source":"pg","messages":[{"id":"msg-pg-1","from":"myia-ai-01:roo-extensions","to":"myia-po-203","subject":"[TASK] depuis pg","body":"corps pg","priority":"HIGH","status":"unread","timestamp":"2026-10-22T12:00:00Z"}]}'

            # Faux RepoRoot CONTENANT le .mjs (le contenu du fichier n'est pas
            # lu : le faux node l'ignore) — hermetique : ce contexte ne depend
            # ni du submodule du checkout ni de la machine (un worktree sans
            # submodule initialise doit passer ces tests).
            $script:CliRoot = Join-Path ([System.IO.Path]::GetTempPath()) "b14-fake-root-$(Get-Random)"
            $cliDir = Join-Path $script:CliRoot 'mcps/internal/servers/roo-state-manager/scripts'
            New-Item -ItemType Directory -Force -Path $cliDir | Out-Null
            Set-Content -Path (Join-Path $cliDir 'read-roosync-inbox.mjs') -Value '// stub' -Encoding ascii
            $RepoRoot = $script:CliRoot

            # Helper d'ecriture du faux node — DANS BeforeAll : Pester v6
            # n'expose pas aux It les fonctions definies au niveau Context.
            # Sous Linux CI, le helper route par `cmd /c "node ... 2>&1"`
            # (#3731) : cmd n'existe pas — un shim deguise sh en cmd (shift
            # sur /c, exec du reste) pour que la couche cmd reste executable
            # et testee sur les deux OS.
            function Set-FakeNode {
                param([string]$PayloadLine, [int]$ExitCode)
                if ($env:OS -eq 'Windows_NT') {
                    Set-Content -Path (Join-Path $script:FakeBin 'node.cmd') `
                        -Value "@echo off`r`necho $PayloadLine`r`nexit /b $ExitCode" -Encoding ascii
                }
                else {
                    Set-Content -Path (Join-Path $script:FakeBin 'node') `
                        -Value "#!/bin/sh`necho '$PayloadLine'`nexit $ExitCode" -Encoding ascii
                    & chmod +x (Join-Path $script:FakeBin 'node')
                    Set-Content -Path (Join-Path $script:FakeBin 'cmd') `
                        -Value "#!/bin/sh`nshift`nexec sh -c `"`$*`"" -Encoding ascii
                    & chmod +x (Join-Path $script:FakeBin 'cmd')
                }
            }
        }

        AfterAll {
            if ($script:FakeBin -and (Test-Path $script:FakeBin)) {
                Remove-Item $script:FakeBin -Recurse -Force -ErrorAction SilentlyContinue
            }
            if ($script:CliRoot -and (Test-Path $script:CliRoot)) {
                Remove-Item $script:CliRoot -Recurse -Force -ErrorAction SilentlyContinue
            }
        }

        # Ecrit les deux variantes du faux node (une par plateforme).

        It 'exit 0 + JSON = resultat pg parse (payload = derniere ligne non vide)' {
            Set-FakeNode -PayloadLine $script:Json -ExitCode 0
            $old = $env:PATH
            try {
                $env:PATH = "$($script:FakeBin)$([IO.Path]::PathSeparator)$env:PATH"
                $r = Get-RooSyncInboxMessages -MachineId 'myia-po-203'
                $r | Should -Not -BeNullOrEmpty
                $r.source | Should -Be 'pg'
                @($r.messages).Count | Should -Be 1
                $r.messages[0].id | Should -Be 'msg-pg-1'
            }
            finally { $env:PATH = $old }
        }

        It 'exit 3 = null (repli fichiers par contrat)' {
            Set-FakeNode -PayloadLine '{"source":"file","reason":"gate-off"}' -ExitCode 3
            $old = $env:PATH
            try {
                $env:PATH = "$($script:FakeBin)$([IO.Path]::PathSeparator)$env:PATH"
                Get-RooSyncInboxMessages -MachineId 'myia-po-203' | Should -BeNullOrEmpty
            }
            finally { $env:PATH = $old }
        }

        It 'exit 0 avec stdout non-JSON = null (fail-open vers fichiers)' {
            Set-FakeNode -PayloadLine 'not-json-at-all' -ExitCode 0
            $old = $env:PATH
            try {
                $env:PATH = "$($script:FakeBin)$([IO.Path]::PathSeparator)$env:PATH"
                Get-RooSyncInboxMessages -MachineId 'myia-po-203' | Should -BeNullOrEmpty
            }
            finally { $env:PATH = $old }
        }

        It 'CLI absent (RepoRoot sans .mjs) = null + WARN, sans exception' {
            $oldRoot = $RepoRoot
            try {
                $RepoRoot = $script:FakeBin
                { Get-RooSyncInboxMessages -MachineId 'myia-po-203' } | Should -Not -Throw
                Get-RooSyncInboxMessages -MachineId 'myia-po-203' | Should -BeNullOrEmpty
                ($script:CapturedLogs | Where-Object { $_ -match 'introuvable' }).Count | Should -BeGreaterThan 0
            }
            finally { $RepoRoot = $oldRoot }
        }
    }

    Context 'Mark-TaskAsComplete : branche PG (garde de structure)' {

        It 'la branche pg precede le elseif messageFile, appelle --mark-read et ne peut pas faire echouer le run' {
            $idxStart = $script:Content.IndexOf('"roosync" {')
            $idxStart | Should -BeGreaterThan -1
            $idxEnd = $script:Content.IndexOf('"github" {', $idxStart)
            $roosyncCase = $script:Content.Substring($idxStart, $idxEnd - $idxStart)

            $roosyncCase | Should -Match '\$Task\.inboxSource -eq "pg"'
            $posPg = $roosyncCase.IndexOf('inboxSource -eq "pg"')
            $posFile = $roosyncCase.IndexOf('elseif ($Task.messageFile')
            $posFile | Should -BeGreaterThan $posPg
            # B17 : le marquage consommé passe par le CLI (même chemin per-reader
            # que le mark_read MCP), avec l'id du message servi.
            $roosyncCase | Should -Match '--mark-read \$\(\$Task\.id\)'
            # B17 : toute erreur CLI est WARN, jamais un throw — le run continue.
            $posTry = $roosyncCase.IndexOf('try {')
            $posTry | Should -BeGreaterThan $posPg
            $posTry | Should -BeLessThan $posFile
            $roosyncCase | Should -Match 'catch \{'
        }
    }

    Context 'Mark-TaskAsComplete : branche PG (B17, vrai appel CLI via faux node)' {

        BeforeAll {
            # Re-extraction de la VRAIE fonction dans ce scope (elle fait ombre
            # au stub du Describe pour les tests de ce contexte).
            $fn = $script:Ast.FindAll({
                param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
                          $n.Name -eq 'Mark-TaskAsComplete'
            }, $true) | Select-Object -First 1
            . ([scriptblock]::Create($fn.Extent.Text))

            # Même fake-node cross-plateforme que le contexte Get-RooSyncInboxMessages,
            # + capture d'argv : le faux node écrit ses arguments dans $script:ArgvFile
            # avant de répondre, pour assert que --machine/--mark-read atteignent le CLI.
            $script:FakeBin2 = Join-Path ([System.IO.Path]::GetTempPath()) "b17-fake-node-$(Get-Random)"
            New-Item -ItemType Directory -Force -Path $script:FakeBin2 | Out-Null
            $script:ArgvFile = Join-Path $script:FakeBin2 'argv.txt'
            $script:CliRoot2 = Join-Path ([System.IO.Path]::GetTempPath()) "b17-fake-root-$(Get-Random)"
            $cliDir2 = Join-Path $script:CliRoot2 'mcps/internal/servers/roo-state-manager/scripts'
            New-Item -ItemType Directory -Force -Path $cliDir2 | Out-Null
            Set-Content -Path (Join-Path $cliDir2 'read-roosync-inbox.mjs') -Value '// stub' -Encoding ascii
            $RepoRoot = $script:CliRoot2

            function Set-FakeMarkNode {
                param([string]$PayloadLine, [int]$ExitCode)
                if ($env:OS -eq 'Windows_NT') {
                    Set-Content -Path (Join-Path $script:FakeBin2 'node.cmd') `
                        -Value "@echo off`r`necho %*> `"$script:ArgvFile`"`r`necho $PayloadLine`r`nexit /b $ExitCode" -Encoding ascii
                }
                else {
                    Set-Content -Path (Join-Path $script:FakeBin2 'node') `
                        -Value "#!/bin/sh`necho `"`$@`" > '$script:ArgvFile'`necho '$PayloadLine'`nexit $ExitCode" -Encoding ascii
                    & chmod +x (Join-Path $script:FakeBin2 'node')
                    Set-Content -Path (Join-Path $script:FakeBin2 'cmd') `
                        -Value "#!/bin/sh`nshift`nexec sh -c `"`$*`"" -Encoding ascii
                    & chmod +x (Join-Path $script:FakeBin2 'cmd')
                }
            }

            $script:PgTask = @{
                id = 'msg-b17-1'; subject = '[TASK] B17'; priority = 'HIGH'
                prompt = 'corps'; source = 'roosync'; messageFile = $null; inboxSource = 'pg'
            }
        }

        AfterAll {
            if ($script:FakeBin2 -and (Test-Path $script:FakeBin2)) {
                Remove-Item $script:FakeBin2 -Recurse -Force -ErrorAction SilentlyContinue
            }
            if ($script:CliRoot2 -and (Test-Path $script:CliRoot2)) {
                Remove-Item $script:CliRoot2 -Recurse -Force -ErrorAction SilentlyContinue
            }
        }

        It 'exit 0 : marque lu sans exception, argv contient --machine et --mark-read avec id du message' {
            Set-FakeMarkNode -PayloadLine '{"source":"pg","written":true}' -ExitCode 0
            $old = $env:PATH
            try {
                $env:PATH = "$($script:FakeBin2)$([IO.Path]::PathSeparator)$env:PATH"
                { Mark-TaskAsComplete -Task $script:PgTask -MachineId 'ci-b14-machine' } | Should -Not -Throw
                ($script:CapturedLogs | Where-Object { $_ -match 'marqué lu' }).Count | Should -BeGreaterThan 0
                $argv = (Get-Content $script:ArgvFile -Raw)
                $argv | Should -Match '--machine ci-b14-machine'
                $argv | Should -Match '--mark-read msg-b17-1'
            }
            finally { $env:PATH = $old }
        }

        It 'exit 3 (gate off) : WARN, jamais de throw — le run continue' {
            Set-FakeMarkNode -PayloadLine '{"source":"file","reason":"gate-off"}' -ExitCode 3
            $old = $env:PATH
            try {
                $env:PATH = "$($script:FakeBin2)$([IO.Path]::PathSeparator)$env:PATH"
                { Mark-TaskAsComplete -Task $script:PgTask -MachineId 'ci-b14-machine' } | Should -Not -Throw
                ($script:CapturedLogs | Where-Object { $_ -match 'exit 3' }).Count | Should -BeGreaterThan 0
            }
            finally { $env:PATH = $old }
        }

        It 'exit 4 (PG na rien ecrit) : WARN avec la reason du payload' {
            Set-FakeMarkNode -PayloadLine '{"source":"pg","written":false,"reason":"denied"}' -ExitCode 4
            $old = $env:PATH
            try {
                $env:PATH = "$($script:FakeBin2)$([IO.Path]::PathSeparator)$env:PATH"
                { Mark-TaskAsComplete -Task $script:PgTask -MachineId 'ci-b14-machine' } | Should -Not -Throw
                ($script:CapturedLogs | Where-Object { $_ -match 'exit 4' -and $_ -match 'denied' }).Count | Should -BeGreaterThan 0
            }
            finally { $env:PATH = $old }
        }

        It 'CLI absent (RepoRoot sans .mjs) : WARN, sans exception' {
            $oldRoot = $RepoRoot
            try {
                $RepoRoot = $script:FakeBin2  # aucun .mjs ici
                { Mark-TaskAsComplete -Task $script:PgTask -MachineId 'ci-b14-machine' } | Should -Not -Throw
                ($script:CapturedLogs | Where-Object { $_ -match 'introuvable' }).Count | Should -BeGreaterThan 0
            }
            finally { $RepoRoot = $oldRoot }
        }

        It 'branche fichiers legacy inchangée : inboxSource file + messageFile reecrit le JSON' {
            $legacyDir = Join-Path $script:FakeBin2 'legacy'
            New-Item -ItemType Directory -Force -Path $legacyDir | Out-Null
            $legacyFile = Join-Path $legacyDir 'msg-legacy.json'
            [System.IO.File]::WriteAllText($legacyFile, '{"id":"msg-legacy","status":"unread"}', [System.Text.UTF8Encoding]::new($false))
            $fileTask = @{ id = 'msg-legacy'; subject = '[TASK] legacy'; priority = 'LOW'; prompt = 'b'; source = 'roosync'; messageFile = $legacyFile; inboxSource = 'file' }
            { Mark-TaskAsComplete -Task $fileTask -MachineId 'ci-b14-machine' } | Should -Not -Throw
            (Get-Content $legacyFile -Raw | ConvertFrom-Json).status | Should -Be 'read'
        }
    }
}
