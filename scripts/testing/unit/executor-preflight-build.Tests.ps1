<#
.SYNOPSIS
    Guards the transactional executor pre-flight introduced after the po-2025 stale-build reboot incident.
#>

Describe 'Executor transactional build pre-flight' {
    BeforeAll {
        $preflightPath = Join-Path $PSScriptRoot '..\..\..\scripts\claude\executor-preflight.ps1'
        $freshPath = Join-Path $PSScriptRoot '..\..\..\scripts\claude\ensure-build-fresh.ps1'
        $skillPath = Join-Path $PSScriptRoot '..\..\..\.claude\skills\executor\SKILL.md'
        $commandPath = Join-Path $PSScriptRoot '..\..\..\.claude\commands\executor.md'

        $preflight = Get-Content $preflightPath -Raw
        $fresh = Get-Content $freshPath -Raw
        $skill = Get-Content $skillPath -Raw
        $command = Get-Content $commandPath -Raw

        $errors = $null
        [System.Management.Automation.Language.Parser]::ParseFile($preflightPath, [ref]$null, [ref]$errors)
    }

    It 'parses executor-preflight.ps1 under PowerShell' {
        $errors.Count | Should -Be 0
    }

    It 'requires the live main checkout before synchronizing or rebuilding' {
        $preflight | Should -Match '\$branch\s+-ne\s+''main'''
        $preflight | Should -Match 'must run from main'
    }

    It 'gates both executor entry points on the MCP inbox before shell pre-flight' {
        foreach ($entryPoint in @($skill, $command)) {
            $inboxGate = $entryPoint.IndexOf('[INBOX-GATE]')
            $inboxCall = $entryPoint.IndexOf('roosync_messages(action:')
            $preflight = $entryPoint.IndexOf('executor-preflight.ps1')

            $inboxGate | Should -BeGreaterThan -1
            $inboxCall | Should -BeGreaterThan $inboxGate
            $preflight | Should -BeGreaterThan $inboxCall
            $entryPoint.Substring($inboxGate, $preflight - $inboxGate) | Should -Match 'HIGH/URGENT'
            $entryPoint.Substring($inboxGate, $preflight - $inboxGate) | Should -Match 'mark_read'
            $gateBlock = $entryPoint.Substring($inboxGate, $preflight - $inboxGate)
            $gateBlock | Should -Match 'STOP & REPAIR'
            $gateBlock | Should -Not -Match 'Get-ChildItem'
        }
    }

    It 'orders pull, submodule materialization, then the strict freshness helper' {
        $pull = $preflight.IndexOf("@('pull', 'origin', 'main', '--no-rebase', '--autostash')")
        $submodule = $preflight.IndexOf("@('submodule', 'update', '--init', 'mcps/internal')")
        $helper = $preflight.IndexOf('-RequireFresh')
        $pull | Should -BeGreaterThan -1
        $submodule | Should -BeGreaterThan $pull
        $helper | Should -BeGreaterThan $submodule
    }

    It 'preserves tracked local edits across pull with autostash' {
        $preflight | Should -Match "@\('pull', 'origin', 'main', '--no-rebase', '--autostash'\)"
    }

    It 'stops on an autostash conflict instead of building a tree with conflict markers' {
        # `--autostash` sort en exit 0 meme quand la remise conflicte : sans garde,
        # `Invoke-GitChecked` (qui ne lit que $LASTEXITCODE) laisse passer un arbre
        # porteur de marqueurs. La garde doit vivre APRES le pull et AVANT le
        # submodule update, sinon le build part sur l'arbre casse.
        $pull = $preflight.IndexOf("@('pull', 'origin', 'main', '--no-rebase', '--autostash')")
        $guard = $preflight.IndexOf('$unmerged =')
        $submodule = $preflight.IndexOf("@('submodule', 'update', '--init', 'mcps/internal')")
        $guard | Should -BeGreaterThan $pull
        $submodule | Should -BeGreaterThan $guard
        $preflight | Should -Match 'Autostash conflict after pull'
    }

    It 'keys the stop on unmerged paths, not on a merely dirty tree' {
        # Un arbre sale apres une remise REUSSIE est le fonctionnement nominal
        # d'--autostash : une garde `if ($dirty)` bloquerait chaque pre-flight
        # legitime. Le predicat doit nommer les codes de non-fusion.
        $preflight | Should -Match 'DD\|AU\|UD\|UA\|DU\|AA\|UU'
    }

    It 'the guard predicate actually fires on a real autostash conflict (throwaway repo)' {
        # Contre-epreuve COMPORTEMENTALE : on reproduit l'etat git reel, puis on evalue
        # l'expression PRISE DANS LE SCRIPT — pas une copie recopiee ici, qui pourrait
        # diverger de ce que le pre-flight execute vraiment.
        #
        # `$ErrorActionPreference = 'Continue'` pendant la plomberie git : ce test pousse
        # DELIBEREMENT git dans un conflit, et sous PowerShell 5.1 la moindre ligne de
        # stderr native (« Auto-merging », « Automatic merge failed ») devient une erreur
        # TERMINANTE quand la preference vaut 'Stop'. L'echec serait alors celui du
        # harnais, pas de la garde — exactement le faux negatif qu'on cherche a exclure.
        $savedEap = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        $root = Join-Path ([System.IO.Path]::GetTempPath()) ("preflight-autostash-" + [guid]::NewGuid().ToString('N').Substring(0,8))
        $bare = Join-Path $root 'origin.git'; $a = Join-Path $root 'A'; $b = Join-Path $root 'B'
        try {
            New-Item -ItemType Directory -Path $root -Force | Out-Null
            # `init` + `remote add` plutot qu'un `clone` de depot vide : ce clone-la emet
            # un warning stderr qui n'a rien a voir avec ce qu'on mesure.
            & git init -q --bare --initial-branch=main $bare
            & git init -q --initial-branch=main $a
            & git -C $a remote add origin $bare
            & git -C $a config user.email 't@t'; & git -C $a config user.name 't'
            Set-Content -Path (Join-Path $a 'f.txt') -Value @('l1','l2','l3')
            & git -C $a add f.txt; & git -C $a commit -qm base; & git -C $a push -q origin main

            & git clone -q $bare $b
            & git -C $b config user.email 't@t'; & git -C $b config user.name 't'
            Set-Content -Path (Join-Path $b 'f.txt') -Value @('l1','UPSTREAM','l3')
            & git -C $b commit -qam upstream; & git -C $b push -q origin main

            Set-Content -Path (Join-Path $a 'f.txt') -Value @('l1','LOCAL','l3')
            & git -C $a pull origin main --no-rebase --autostash 2>&1 | Out-Null
            $pullExit = $LASTEXITCODE

            # Le predicat, extrait du script lui-meme.
            $line = ($preflight -split "`n" | Where-Object { $_ -match '^\s*\$unmerged = ' } | Select-Object -First 1)
            $line | Should -Not -BeNullOrEmpty
            $RepoRoot = $a
            $unmerged = $null
            Invoke-Expression $line

            $pullExit | Should -Be 0                       # la premisse : git ne signale RIEN par le code retour
            @($unmerged).Count | Should -BeGreaterThan 0   # la garde, elle, mord

            # Controle negatif : sur un arbre sale SANS conflit, la garde se tait. Sans
            # lui, un predicat qui renverrait toujours quelque chose passerait ce test.
            & git -C $a checkout -q --theirs f.txt
            & git -C $a add f.txt
            & git -C $a commit -qm resolve
            Set-Content -Path (Join-Path $a 'f.txt') -Value @('l1','edit-propre','l3')
            $unmerged = $null
            Invoke-Expression $line
            @($unmerged).Count | Should -Be 0
        }
        finally {
            $ErrorActionPreference = $savedEap
            if (Test-Path $root) { Remove-Item -Recurse -Force $root -ErrorAction SilentlyContinue }
        }
    }

    It 'rejects a submodule path that resolves to the parent repository' {
        $preflight | Should -Match '\$submoduleTop\s+-eq\s+\$parentTop'
        $preflight | Should -Match 'does not match parent gitlink'
    }

    It 'blocks continuation when a rebuild owes a restart' {
        $preflight | Should -Match '\$freshExit\s+-eq\s+10'
        $preflight | Should -Match 'do not continue this executor cycle'
        $preflight | Should -Match 'exit 10'
    }

    It 'keeps legacy helper callers non-blocking unless RequireFresh is explicit' {
        $fresh | Should -Match '\[switch\]\$RequireFresh'
        $fresh | Should -Match 'if \(\$RequireFresh\) \{ exit 1 \}'
        $fresh | Should -Match '\$RequireFresh -and \$restartRequired'
    }

    It 'routes both executor entry points through the transactional pre-flight' {
        $skill | Should -Match 'executor-preflight\.ps1'
        $command | Should -Match 'executor-preflight\.ps1'
        $skill | Should -Match 'Exit `10`'
        $command | Should -Match '\$LASTEXITCODE -eq 10'
        $command | Should -Match 'Restart VS Code requis'
    }

    It 'keeps a missing MCP path non-blocking for legacy helper callers' {
        $hostExe = (Get-Process -Id $PID).Path
        $output = & $hostExe -NoProfile -ExecutionPolicy Bypass -File $freshPath -RepoRoot $TestDrive 2>&1
        $LASTEXITCODE | Should -Be 0
        ($output | Out-String) | Should -Match '\[SKIP\].*MCP server path not found'
    }

    It 'blocks a missing MCP path for strict executor callers' {
        $hostExe = (Get-Process -Id $PID).Path
        $output = & $hostExe -NoProfile -ExecutionPolicy Bypass -File $freshPath -RepoRoot $TestDrive -RequireFresh 2>&1
        $LASTEXITCODE | Should -Be 1
        ($output | Out-String) | Should -Match '\[SKIP\].*MCP server path not found'
    }
}
