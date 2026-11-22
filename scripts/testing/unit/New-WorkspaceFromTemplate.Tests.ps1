# Tests unitaires -- New-WorkspaceFromTemplate.ps1 (#3111 etape 1, #4873).
#
# Ce que ces tests epinglent, et pourquoi chacun tue un mutant precis :
#   1. DRY-RUN N'ECRIT RIEN : 0 fichier, 0 repertoire crees dans le temoin.
#      Tue un mutant qui provisionnerait les repertoires meme en DryRun.
#   2. CREATION SEULE : un fichier existant n'est JAMAIS ecrase ; les fichiers
#      sautes sont listes. Tue un mutant "overwrite" silencieux.
#   3. IDEMPOTENCE : un second run ne change rien (tout est saute / rien a fusionner).
#   4. MARQUEURS : {{WORKSPACE}} et {{REPO}} sont remplaces, aucun ne subsiste.
#   5. FUSION GITIGNORE : seules les lignes absentes sont ajoutees, une fois.
#
# Portabilite : Join-Path partout, aucun chemin Windows en dur ; le temoin vit dans
# un repertoire jetable ($TestDrive), jamais dans un workspace reel.

BeforeAll {
    $projectRoot = (Resolve-Path -Path "$PSScriptRoot/../../..").Path
    $script:scriptPath = Join-Path $projectRoot 'scripts/workspace/New-WorkspaceFromTemplate.ps1'
    $script:templateDir = Join-Path $projectRoot '.claude/configs/workspace-template'
}

Describe 'New-WorkspaceFromTemplate.ps1' {

    It 'parse sans erreur' {
        $errors = $null
        [System.Management.Automation.Language.Parser]::ParseFile($script:scriptPath, [ref]$null, [ref]$errors) | Out-Null
        $errors.Count | Should -Be 0
    }

    It '-DryRun cree 0 fichier et 0 repertoire dans le temoin vide' {
        $target = Join-Path $TestDrive 'dryrun-target'
        & $script:scriptPath -Target $target -Workspace 'DemoWS' -DryRun | Out-Null
        Test-Path -LiteralPath $target | Should -BeFalse
    }

    It '-DryRun liste les fichiers prevus' {
        $target = Join-Path $TestDrive 'dryrun-list'
        $out = & $script:scriptPath -Target $target -Workspace 'DemoWS' -DryRun | Out-String
        $out | Should -Match 'CLAUDE\.md\.template|CLAUDE\.md'
        $out | Should -Match 'MEMORY\.md'
        $out | Should -Match '\.gitignore'
    }

    It 'creation reelle : les fichiers sont crees et les marqueurs remplaces' {
        $target = Join-Path $TestDrive 'real-target'
        & $script:scriptPath -Target $target -Workspace 'DemoWS' | Out-Null
        $claude = Join-Path $target 'CLAUDE.md'
        Test-Path -LiteralPath $claude | Should -BeTrue
        $content = [System.IO.File]::ReadAllText($claude)
        $content | Should -Match 'DemoWS'
        $content | Should -Not -Match '\{\{WORKSPACE\}\}'
        $content | Should -Not -Match '\{\{REPO\}\}'
        Test-Path -LiteralPath (Join-Path $target '.claude/rules/agent-claim.md') | Should -BeTrue
        Test-Path -LiteralPath (Join-Path $target '.claude/rules/pr-mandatory.md') | Should -BeTrue
        Test-Path -LiteralPath (Join-Path $target '.claude/plans/README.md') | Should -BeTrue
        # memory-seed/ est ensemence HORS du depot (memoire non versionnee) :
        # $HOME/.claude/projects/<slug-du-chemin>/memory/
        $slug = ($target -replace '[\\/:]', '-').TrimStart('-').ToLowerInvariant()
        $memDir = Join-Path (Join-Path $HOME '.claude/projects') (Join-Path $slug 'memory')
        Test-Path -LiteralPath (Join-Path $memDir 'MEMORY.md') | Should -BeTrue
        Test-Path -LiteralPath (Join-Path $memDir 'user-question-registry.md') | Should -BeTrue
        Test-Path -LiteralPath (Join-Path $target 'memory-seed') | Should -BeFalse
        Test-Path -LiteralPath (Join-Path $target '.gitignore') | Should -BeTrue
    }

    It 'un fichier existant n est pas ecrase et est liste comme saute' {
        $target = Join-Path $TestDrive 'no-overwrite'
        New-Item -ItemType Directory -Path $target -Force | Out-Null
        $claude = Join-Path $target 'CLAUDE.md'
        [System.IO.File]::WriteAllText($claude, 'ORIGINAL CONTENT DO NOT TOUCH')
        $out = & $script:scriptPath -Target $target -Workspace 'DemoWS' | Out-String
        [System.IO.File]::ReadAllText($claude) | Should -Be 'ORIGINAL CONTENT DO NOT TOUCH'
        $out | Should -Match 'Skipped existing \([1-9]'
    }

    It 'second run idempotent : rien de modifie' {
        $target = Join-Path $TestDrive 'idempotent'
        & $script:scriptPath -Target $target -Workspace 'DemoWS' | Out-Null
        $claude = Join-Path $target 'CLAUDE.md'
        $before = [System.IO.File]::ReadAllText($claude)
        $gitignoreBefore = [System.IO.File]::ReadAllText((Join-Path $target '.gitignore'))
        $out = & $script:scriptPath -Target $target -Workspace 'DemoWS' | Out-String
        [System.IO.File]::ReadAllText($claude) | Should -Be $before
        [System.IO.File]::ReadAllText((Join-Path $target '.gitignore')) | Should -Be $gitignoreBefore
        $out | Should -Not -Match 'Would-create/Created \([1-9]'
    }

    It 'fusionne gitignore.fragment dans un .gitignore existant (seules lignes absentes)' {
        $target = Join-Path $TestDrive 'gitignore-merge'
        New-Item -ItemType Directory -Path $target -Force | Out-Null
        $gitignore = Join-Path $target '.gitignore'
        [System.IO.File]::WriteAllText($gitignore, "node_modules/`n.tmp/`n")
        & $script:scriptPath -Target $target -Workspace 'DemoWS' | Out-Null
        $lines = [System.IO.File]::ReadAllLines($gitignore)
        $lines | Should -Contain 'node_modules/'
        ($lines | Where-Object { $_ -eq '.tmp/' }).Count | Should -Be 1
        $lines | Should -Contain 'scratchpad_*'
        $lines | Should -Contain '.claude/local/'
        # Deuxieme passage : aucune ligne dupliquee.
        & $script:scriptPath -Target $target -Workspace 'DemoWS' | Out-Null
        $lines2 = [System.IO.File]::ReadAllLines($gitignore)
        ($lines2 | Where-Object { $_ -eq 'scratchpad_*' }).Count | Should -Be 1
    }
}
