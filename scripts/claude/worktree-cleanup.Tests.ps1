# worktree-cleanup.Tests.ps1 — Pester 5 : gardes de sécurité du cleanup (audit 27/09)
#
# Précédent harden-hidden-tasks.Tests.ps1 : l'hôte est pwsh 7 + Pester 5 (non livrés avec
# 5.1) ; la CIBLE tourne TOUJOURS en process enfant `powershell.exe` 5.1, sur une COPIE du
# script dans un dépôt-fixture jetable (le script opère sur le dépôt qui le porte, via
# $PSScriptRoot\..\.. — le tester en place nettoierait le vrai dépôt).
#
# Scénarios (dispatch ai-01 16:05Z, alignés worktree-lifecycle.md) :
#   1. branche jamais poussée, contenue dans HEAD        → supprimée (par `-d`)
#   2. branche jamais poussée avec commits propres       → KEPT (manual review)
#   3. branche poussée, PR MERGED (shim gh)              → supprimée (par `-D` avec preuve)
#   4. branche poussée, PR OPEN (shim gh)                → KEPT
#   5. dossier orphelin git-dirty                        → REFUSED, le dossier reste
#   6. dossier orphelin vide sans marqueur               → supprimé
#   7. dossier sans marqueur contenant des fichiers      → REFUSED, le dossier reste
#   8. statique : ni `--prune=now` ni règle « NO-PR worker artifact » dans la source
#   9. worktree propre enregistré par un autre dépôt (sous-module) → conservé (02/10)
#
# Exécution : pwsh -NoProfile -File scripts/testing/run-pester-tests.ps1 -Path scripts/claude/worktree-cleanup.Tests.ps1

BeforeAll {
    $script:RepoRoot = (git -C "$PSScriptRoot\..\.." rev-parse --show-toplevel).Trim()
    $script:SourceScript = Join-Path $script:RepoRoot 'scripts\claude\worktree-cleanup.ps1'
    $script:SourceGuards = Join-Path $script:RepoRoot 'scripts\common\path-guards.ps1'
    $script:OldDate = '2026-08-01T12:00:00'

    function New-CleanupFixture {
        $fixture = Join-Path $env:TEMP ("wtc-safety-" + [guid]::NewGuid().ToString('N').Substring(0, 8))
        New-Item -ItemType Directory -Path $fixture -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $fixture 'scripts\claude') -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $fixture 'scripts\common') -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $fixture '.claude\worktrees') -Force | Out-Null
        Copy-Item $script:SourceScript -Destination (Join-Path $fixture 'scripts\claude\worktree-cleanup.ps1')
        Copy-Item $script:SourceGuards -Destination (Join-Path $fixture 'scripts\common\path-guards.ps1')

        git -C $fixture init -q -b master
        if ($LASTEXITCODE -ne 0) { Set-ItResult -Skipped -Because "git init failed"; return $null }
        git -C $fixture config user.email "test@example.com"
        git -C $fixture config user.name "Pester Fixture"
        git -C $fixture config core.autocrlf false

        $env:GIT_AUTHOR_DATE = $script:OldDate
        $env:GIT_COMMITTER_DATE = $script:OldDate
        git -C $fixture commit --allow-empty -q -m "init (backdated)"
        Remove-Item Env:GIT_AUTHOR_DATE, Env:GIT_COMMITTER_DATE -ErrorAction SilentlyContinue
        return $fixture
    }

    function New-GhShim {
        param([string]$Fixture, [string]$Json)
        $shimDir = Join-Path $Fixture 'shim'
        New-Item -ItemType Directory -Path $shimDir -Force | Out-Null
        # Un .cmd suffit : le script enfant appelle `gh pr list ...` et ne lit que la
        # sortie + le code retour. Exit 0 implicite, JSON sur stdout.
        Set-Content -Path (Join-Path $shimDir 'gh.cmd') -Value "@echo $Json" -Encoding ASCII
        return $shimDir
    }

    function Invoke-CleanupChild {
        param([string]$Fixture, [string[]]$ShimPath = @())
        $savedPath = $env:PATH
        try {
            foreach ($s in $ShimPath) { $env:PATH = "$s;$env:PATH" }
            # Cible = process enfant powershell.exe 5.1 (forme -File, celle des schtasks).
            # -Force : l'hôte de test a VS Code ouvert, le script doit pouvoir tourner.
            # -SkipRemote : le bloc distant interroge le vrai dépôt GitHub (hors fixture).
            $out = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File `
                (Join-Path $Fixture 'scripts\claude\worktree-cleanup.ps1') -Force -SkipRemote 2>&1
            return ($out -join "`n")
        }
        finally {
            $env:PATH = $savedPath
        }
    }

    function Test-BranchExists {
        param([string]$Fixture, [string]$Name)
        return [bool](git -C $Fixture branch --list $Name)
    }

    # Nettoyage global des fixtures en fin de suite (AfterAll ne voit pas les vars des It).
    $script:Fixtures = [System.Collections.Generic.List[string]]::new()
}

AfterAll {
    foreach ($f in $script:Fixtures) {
        if ($f -and (Test-Path $f)) {
            Remove-Item $f -Recurse -Force -Confirm:$false -ErrorAction SilentlyContinue
        }
    }
}

Describe 'worktree-cleanup safety guards' {
    It 'branche jamais poussée, contenue dans HEAD → supprimée par -d' {
        $f = New-CleanupFixture
        $script:Fixtures.Add($f)
        git -C $f branch wt/contained   # même commit que master (backdaté) = stale ET contenu

        $out = Invoke-CleanupChild -Fixture $f

        Test-BranchExists -Fixture $f -Name 'wt/contained' | Should -BeFalse
        $out | Should -Match 'Deleted branch \(never pushed, contained in HEAD\): wt/contained'
    }

    It 'branche jamais poussée avec commits propres → KEPT' {
        $f = New-CleanupFixture
        $script:Fixtures.Add($f)
        git -C $f checkout -q -b wt/own
        $env:GIT_AUTHOR_DATE = $script:OldDate; $env:GIT_COMMITTER_DATE = $script:OldDate
        git -C $f commit --allow-empty -q -m "own work (backdated)"
        Remove-Item Env:GIT_AUTHOR_DATE, Env:GIT_COMMITTER_DATE -ErrorAction SilentlyContinue
        git -C $f checkout -q master

        $out = Invoke-CleanupChild -Fixture $f

        Test-BranchExists -Fixture $f -Name 'wt/own' | Should -BeTrue
        $out | Should -Match 'KEPT wt/own — never pushed AND has own commits'
    }

    It 'branche poussée, PR MERGED (shim gh) → -D avec preuve' {
        $f = New-CleanupFixture
        $script:Fixtures.Add($f)
        $origin = "$f-origin.git"
        git init -q --bare $origin
        git -C $f remote add origin $origin
        git -C $f checkout -q -b wt/merged
        $env:GIT_AUTHOR_DATE = $script:OldDate; $env:GIT_COMMITTER_DATE = $script:OldDate
        git -C $f commit --allow-empty -q -m "delivered work (backdated)"
        Remove-Item Env:GIT_AUTHOR_DATE, Env:GIT_COMMITTER_DATE -ErrorAction SilentlyContinue
        git -C $f checkout -q master
        git -C $f push -q -u origin wt/merged
        $shim = New-GhShim -Fixture $f -Json '[{"number":42,"state":"MERGED"}]'

        $out = Invoke-CleanupChild -Fixture $f -ShimPath @($shim)

        Test-BranchExists -Fixture $f -Name 'wt/merged' | Should -BeFalse
        $out | Should -Match 'Deleted branch \(PR #42 MERGED\): wt/merged'
    }

    It 'branche poussée, PR OPEN (shim gh) → KEPT' {
        $f = New-CleanupFixture
        $script:Fixtures.Add($f)
        $origin = "$f-origin.git"
        git init -q --bare $origin
        git -C $f remote add origin $origin
        git -C $f checkout -q -b wt/open-pr
        $env:GIT_AUTHOR_DATE = $script:OldDate; $env:GIT_COMMITTER_DATE = $script:OldDate
        git -C $f commit --allow-empty -q -m "wip (backdated)"
        Remove-Item Env:GIT_AUTHOR_DATE, Env:GIT_COMMITTER_DATE -ErrorAction SilentlyContinue
        git -C $f checkout -q master
        git -C $f push -q -u origin wt/open-pr
        $shim = New-GhShim -Fixture $f -Json '[{"number":43,"state":"OPEN"}]'

        $out = Invoke-CleanupChild -Fixture $f -ShimPath @($shim)

        Test-BranchExists -Fixture $f -Name 'wt/open-pr' | Should -BeTrue
        $out | Should -Match 'KEPT wt/open-pr — pushed, PR state: OPEN'
    }

    It 'dossier orphelin git-dirty → REFUSED, le dossier reste' {
        $f = New-CleanupFixture
        $script:Fixtures.Add($f)
        $dirty = Join-Path $f '.claude\worktrees\dirty-orphan'
        New-Item -ItemType Directory -Path $dirty -Force | Out-Null
        # Vrai repo autonome avec un fichier non commité = sale aux yeux de git.
        git -C $dirty init -q
        Set-Content (Join-Path $dirty 'uncommitted.txt') 'travail jamais livré'

        $out = Invoke-CleanupChild -Fixture $f

        Test-Path $dirty | Should -BeTrue
        $out | Should -Match 'REFUSED \(dirty-guard\): .*dirty-orphan has uncommitted changes'
    }

    It 'dossier orphelin vide sans marqueur → supprimé' {
        $f = New-CleanupFixture
        $script:Fixtures.Add($f)
        $husk = Join-Path $f '.claude\worktrees\empty-husk'
        New-Item -ItemType Directory -Path $husk -Force | Out-Null

        $out = Invoke-CleanupChild -Fixture $f

        Test-Path $husk | Should -BeFalse
        $out | Should -Match 'Removed orphan directory: .*empty-husk'
    }

    It 'dossier sans marqueur contenant des fichiers → REFUSED, le dossier reste' {
        $f = New-CleanupFixture
        $script:Fixtures.Add($f)
        $stray = Join-Path $f '.claude\worktrees\stray-files'
        New-Item -ItemType Directory -Path $stray -Force | Out-Null
        Set-Content (Join-Path $stray 'note.txt') 'résidu'

        $out = Invoke-CleanupChild -Fixture $f

        Test-Path $stray | Should -BeTrue
        $out | Should -Match 'REFUSED \(dirty-guard\): .*stray-files has no git marker but contains 1 file'
    }

    It 'orphelin .git pendant (gitdir disparu) → REFUSED, la suite continue (follow-up #3906)' {
        $f = New-CleanupFixture
        $script:Fixtures.Add($f)
        $pendant = Join-Path $f '.claude\worktrees\pendant-git'
        New-Item -ItemType Directory -Path $pendant -Force | Out-Null
        # .git FICHIER pointant vers un gitdir inexistant : git status sort en
        # fatal 128 — sans try/catch (classe #3731), erreur terminante qui tuait
        # le script au lieu d'être REFUSED.
        Set-Content (Join-Path $pendant '.git') ("gitdir: " + (Join-Path (Join-Path $f 'gone-repo') '.git')) -Encoding ASCII
        # Deuxième cible saine APRÈS la pendante (ordre alpha) : prouve que le
        # REFUSED n'arrête pas la suite.
        $husk = Join-Path $f '.claude\worktrees\zz-empty-husk'
        New-Item -ItemType Directory -Path $husk -Force | Out-Null

        $out = Invoke-CleanupChild -Fixture $f

        Test-Path $pendant | Should -BeTrue
        $out | Should -Match 'REFUSED \(dirty-guard\): git state unreadable .*pendant-git'
        Test-Path $husk | Should -BeFalse
        $out | Should -Match 'Removed orphan directory: .*zz-empty-husk'
    }

    It 'worktree propre enregistré par un AUTRE dépôt (sous-module) → conservé' {
        $f = New-CleanupFixture
        $script:Fixtures.Add($f)
        # Disposition des incidents po-2026/po-2025 du 02/10 : worktree du dépôt
        # sous-module rangé dans le .claude\worktrees du parent. Absent de la liste
        # du parent, propre aux yeux de git — l'ancien classifieur le supprimait.
        $other = "$f-other"
        $script:Fixtures.Add($other)
        git init -q $other
        git -C $other -c user.email=t@example.invalid -c user.name=t commit --allow-empty -q -m init
        $foreign = Join-Path $f '.claude\worktrees\foreign-wt'
        git -C $other worktree add -q -b wt/foreign $foreign

        $out = Invoke-CleanupChild -Fixture $f

        Test-Path (Join-Path $foreign '.git') | Should -BeTrue
        $out | Should -Match 'Skipping foreign-wt: worktree registered by another repository'
        $out | Should -Not -Match 'Removed orphan directory: .*foreign-wt'
    }

    It 'statique : plus de git gc --prune=now ni de règle NO-PR worker dans la source' {
        $src = Get-Content $script:SourceScript -Raw
        # Forme COMMANDE uniquement : les commentaires de rationale citent le littéral
        # retiré (« tourne SANS … ») — c'est l'appel exécutable qu'on interdit.
        $src | Should -Not -Match 'git\s+gc\s+--prune=now'
        $src | Should -Not -Match 'NO-PR worker artifact'
    }
}
