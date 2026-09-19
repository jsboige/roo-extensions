<#
.SYNOPSIS
    Guard tests for scripts/mcp/deploy-preop-guard.ps1 (#3712).

.DESCRIPTION
    Verifies the deploy pre-op guard catches the git-blind destruction pattern:
    the 2026-09-17 incident family where git status is clean but .env / build/
    get wiped because they're gitignored.

    Structural + behavioural tests:
      - Test-ProtectedPath detects .env, build/, settings.json (the issue's targets)
      - Test-ProtectedPath is git-blind: works against paths that git status cannot see
      - Backup-ProtectedPaths copies protected artefacts under a tmp root
      - Invoke-DeployPreOpGuard in Mode Block returns Action='Blocked' for protected paths
      - Invoke-DeployPreOpGuard in Mode Backup performs a backup before returning Proceeded
      - Invoke-DeployPreOpGuard in Mode Warn returns Action='Warned'
      - DEPLOY_PROTECTED_PATHS env var extends the whitelist
      - rebuild-roo-state-manager.ps1 and ensure-build-fresh.ps1 call the guard
        before destroying build/ (structural)

.NOTES
    Issue #3712 — the git-blind path test is mandatory per acceptance criteria.
#>

Describe 'Deploy pre-op guard (#3712)' {

    BeforeAll {
        # Localiser le repoRoot depuis la position du test (scripts/testing/unit/ -> 3 niveaux).
        $script:testDir  = $PSScriptRoot
        $script:repoRoot = (Get-Item (Join-Path $testDir '..\..\..')).FullName
        $script:guard    = Join-Path $repoRoot 'scripts\mcp\deploy-preop-guard.ps1'

        # Construire un repo de test "git-blind" : un working tree OU .gitignore est absent
        # (pour valider que Test-ProtectedPath marche SANS dependre de l'etat git).
        # GetTempPath() : cross-platform (TMPDIR sur Unix, TEMP sur Windows) — $env:TEMP
        # est null sur le runner CI Ubuntu et faisait crasher tout le Describe (review #3714).
        $script:tmpRoot = Join-Path ([System.IO.Path]::GetTempPath()) "preop-guard-test-$([Guid]::NewGuid().ToString('N').Substring(0,8))"
        New-Item -ItemType Directory -Path $tmpRoot -Force | Out-Null

        # Arborescence type d'un deploy :
        #   <root>/.env                  (creds, gitignored)
        #   <root>/build/                (gitignored)
        #   <root>/build/index.js        (the file)
        #   <root>/.claude/settings.json (gitignored)
        #   <root>/.claude.json          (gitignored)
        #   <root>/src/foo.ts            (tracked, NOT protected)
        $script:tmpEnv      = Join-Path $tmpRoot '.env'
        $script:tmpEnvLocal = Join-Path $tmpRoot '.env.local'
        $script:tmpBuild    = Join-Path $tmpRoot 'build'
        $script:tmpBuildIdx = Join-Path $tmpBuild  'index.js'
        $script:tmpSettings = Join-Path $tmpRoot '.claude'
        $script:tmpSetJson  = Join-Path $tmpSettings 'settings.json'
        $script:tmpClaudeJ  = Join-Path $tmpRoot '.claude.json'
        $script:tmpSrc      = Join-Path $tmpRoot 'src'

        New-Item -ItemType Directory -Path $tmpBuild  -Force | Out-Null
        New-Item -ItemType Directory -Path $tmpSettings -Force | Out-Null
        New-Item -ItemType Directory -Path $tmpSrc   -Force | Out-Null

        'API_KEY=sk-test-1234'                   | Set-Content -LiteralPath $tmpEnv
        'API_KEY_LOCAL=sk-test-5678'             | Set-Content -LiteralPath $tmpEnvLocal
        'module.exports={}'                      | Set-Content -LiteralPath $tmpBuildIdx
        '{"CLAUDE_CODE_AUTO_COMPACT_WINDOW":"280000"}' | Set-Content -LiteralPath $tmpSetJson
        '{"mcpServers":{}}'                      | Set-Content -LiteralPath $tmpClaudeJ
        'export const x = 1'                     | Set-Content -LiteralPath (Join-Path $tmpSrc 'foo.ts')

        # Charger le guard en dot-source (mode module).
        # Patch : Get-ProtectedPaths utilise $PSScriptRoot pour git toplevel. En dot-source
        # depuis un test, $PSScriptRoot = chemin du test. On surcharge $script:DefaultProtectedRelativePatterns
        # en faisant pointer le repoRoot de detection vers $tmpRoot via -RepoRoot.
        . $script:guard

        # Capturer l'etat du stock de backup AVANT tout test. Le AfterAll ne doit
        # nettoyer QUE les snapshots crees par CE run : le stock de production compose
        # exactement le meme chemin avec le meme format yyyyMMdd-HHmmss — test et prod
        # sont indiscernables par construction (bloquant review #3714).
        $script:preopBackupRoot = [IO.Path]::Combine([Environment]::GetFolderPath('UserProfile'), '.roo-state-manager', 'preop-backup')
        $script:preopSnapshotsBefore = @()
        if (Test-Path -LiteralPath $script:preopBackupRoot) {
            $script:preopSnapshotsBefore = @(
                Get-ChildItem -LiteralPath $script:preopBackupRoot -Directory -Force -ErrorAction SilentlyContinue |
                Select-Object -ExpandProperty Name
            )
        }
    }

    AfterAll {
        if (Test-Path -LiteralPath $script:tmpRoot) {
            Remove-Item -LiteralPath $script:tmpRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
        # Nettoyer UNIQUEMENT les repertoires absents de la liste capturee au BeforeAll
        # (= crees par ce run). Jamais de filtre par nom ni de plafond type Skip 5 :
        # ^\d{8}-\d{6}$ matche precisement le format des snapshots de production, et
        # Selection -Skip 5 emportait les plus anciens snapshots REELS en silence
        # (bloquant review #3714).
        if (Test-Path -LiteralPath $script:preopBackupRoot) {
            Get-ChildItem -LiteralPath $script:preopBackupRoot -Directory -Force -ErrorAction SilentlyContinue |
                Where-Object { $script:preopSnapshotsBefore -notcontains $_.Name } |
                ForEach-Object { Remove-Item -LiteralPath $_.FullName -Recurse -Force -ErrorAction SilentlyContinue }
        }
    }

    It 'Parses the guard script without syntax errors' {
        Test-Path -LiteralPath $script:guard | Should -Be $true
    }

    It 'Exposes the four guard functions' {
        Get-Command Test-ProtectedPath          -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        Get-Command Get-ProtectedPaths          -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        Get-Command Backup-ProtectedPaths       -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        Get-Command Invoke-DeployPreOpGuard     -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
    }

    It 'Detects .env as protected (git-blind: no .git in tmpRoot, status is irrelevant)' {
        # Le tmpRoot n'a pas de .git -> git status est inapplicable. Le garde doit quand
        # meme reconnaitre .env comme protege (la detection est liste-de-chemins, pas etat git).
        $r = Test-ProtectedPath -LiteralPath $script:tmpEnv -RepoRoot $script:tmpRoot
        $r.IsProtected | Should -Be $true
        $r.Reason      | Should -Be 'ExactMatch'
    }

    It 'Detects build/ as protected' {
        $r = Test-ProtectedPath -LiteralPath $script:tmpBuild -RepoRoot $script:tmpRoot
        $r.IsProtected | Should -Be $true
        $r.Reason      | Should -Be 'ExactMatch'
    }

    It 'Detects .env.local as protected via the .env.* wildcard (review #3714: -LiteralPath never expanded patterns)' {
        # Regression du defect signale en review : Resolve-Path -LiteralPath cherchait le
        # fichier litteral ".env.*" (inexistant) -> pattern saut en silence -> .env.local
        # non protege. Le fix expand les patterns via Get-Item -Path.
        $r = Test-ProtectedPath -LiteralPath $script:tmpEnvLocal -RepoRoot $script:tmpRoot
        $r.IsProtected | Should -Be $true
        $r.Reason      | Should -Be 'ExactMatch'
        $r.Pattern     | Should -Be '.env.*'
    }

    It 'Get-ProtectedPaths expands .env.* into one existing entry per matched file' {
        $paths = Get-ProtectedPaths -RepoRoot $script:tmpRoot
        $entries = @($paths | Where-Object { $_.Pattern -eq '.env.*' -and $_.Exists })
        $entries.Count | Should -Be 1
        $entries[0].FullPath | Should -Be $script:tmpEnvLocal
    }

    It 'Mode Block returns Action=Blocked for .env.local (wildcard variant)' {
        $r = Invoke-DeployPreOpGuard -Operation 'rm .env.local' -LiteralPath $script:tmpEnvLocal -Mode Block -RepoRoot $script:tmpRoot
        $r.Action | Should -Be 'Blocked'
        Test-Path -LiteralPath $script:tmpEnvLocal | Should -Be $true
    }

    It 'Detects a file INSIDE build/ as protected (Reason=InsideProtectedDir)' {
        $r = Test-ProtectedPath -LiteralPath $script:tmpBuildIdx -RepoRoot $script:tmpRoot
        $r.IsProtected | Should -Be $true
        $r.Reason      | Should -Be 'InsideProtectedDir'
    }

    It 'Detects .claude/settings.json as protected' {
        $r = Test-ProtectedPath -LiteralPath $script:tmpSetJson -RepoRoot $script:tmpRoot
        $r.IsProtected | Should -Be $true
    }

    It 'Does NOT flag src/foo.ts as protected' {
        $srcFile = Join-Path $script:tmpSrc 'foo.ts'
        $r = Test-ProtectedPath -LiteralPath $srcFile -RepoRoot $script:tmpRoot
        $r.IsProtected | Should -Be $false
        $r.Reason      | Should -Be 'NotInWhitelist'
    }

    It 'Mode Block returns Action=Blocked for .env without modifying the file' {
        $r = Invoke-DeployPreOpGuard -Operation 'rm .env' -LiteralPath $script:tmpEnv -Mode Block -RepoRoot $script:tmpRoot
        $r.Action | Should -Be 'Blocked'
        # Le fichier doit etre intact (Block ne touche a rien).
        Test-Path -LiteralPath $script:tmpEnv | Should -Be $true
        (Get-Content -LiteralPath $script:tmpEnv -Raw).Trim() | Should -Be 'API_KEY=sk-test-1234'
    }

    It 'Mode Backup copies .env to preop-backup/<ts>/.env and returns Action=BackedUp' {
        $r = Invoke-DeployPreOpGuard -Operation 'rm .env' -LiteralPath $script:tmpEnv -Mode Backup -RepoRoot $script:tmpRoot
        $r.Action | Should -Be 'BackedUp'
        $r.BackupDir | Should -Not -BeNullOrEmpty

        # BackupDir doit designer le snapshot EXACT de cette session (review #3714 :
        # l'ancien rendu Split-Path -Parent designait toujours la racine preop-backup,
        # jamais la session — le test ne verifiait que l'existence du parent et passait
        # a vide sur la promesse). On enumere SOUS le BackupDir rendu.
        # -Force OBLIGATOIRE : sur Unix, PowerShell marque les dotfiles de
        # l'attribut Hidden et Get-ChildItem sans -Force ne les enumere PAS
        # (idem Get-Item sans -Force — cause racine commune des rouges CI
        # #3714 iterations 2 et 3). Where-Object en ceinture : -Filter '.env'
        # a aussi un comportement dotfile specifique Unix.
        $found = Get-ChildItem -LiteralPath $r.BackupDir -Recurse -File -Force -ErrorAction SilentlyContinue |
                 Where-Object { $_.Name -eq '.env' } |
                 Select-Object -First 1
        $found | Should -Not -BeNullOrEmpty
        $found.FullName | Should -BeLike "$($r.BackupDir)*"
    }

    It 'Treats an unresolvable relative path as protected (fail-closed, review #3714)' {
        # Un garde ne doit jamais rendre "sur" un chemin qu'il n'a pas su resoudre :
        # la direction d'erreur conservatrice est de refuser l'operation jusqu'a
        # clarification. Masque aujourd'hui par des callers qui passent des absolus ;
        # vivant des que la couverture .env s'elargit.
        $r = Test-ProtectedPath -LiteralPath 'no-such-protected-file-xyz' -RepoRoot $script:tmpRoot
        $r.IsProtected | Should -Be $true
        $r.Reason      | Should -Be 'PathNotResolved'
    }

    It 'Mode Warn returns Action=Warned' {
        $r = Invoke-DeployPreOpGuard -Operation 'rm .env' -LiteralPath $script:tmpEnv -Mode Warn -RepoRoot $script:tmpRoot
        $r.Action | Should -Be 'Warned'
    }

    It 'Returns Proceeded for non-protected paths' {
        $r = Invoke-DeployPreOpGuard -Operation 'rm src/foo.ts' -LiteralPath (Join-Path $script:tmpSrc 'foo.ts') -Mode Block -RepoRoot $script:tmpRoot
        $r.Action | Should -Be 'Proceeded'
    }

    It 'Is git-blind: Test-ProtectedPath works even without a .git in the root' {
        # On a un tmpRoot SANS .git, .gitignore, ou quoi que ce soit de git -- le test
        # demontre que le garde marche en mode liste-de-chemins pur.
        Test-Path -LiteralPath (Join-Path $script:tmpRoot '.git') | Should -Be $false
        $r = Test-ProtectedPath -LiteralPath $script:tmpBuild -RepoRoot $script:tmpRoot
        $r.IsProtected | Should -Be $true
    }

    Context 'Root-level destructive ops (#3712 volet racine : git clean -fdx sur le worktree)' {
        # L'exemple CLI documente (`deploy-preop-guard.ps1 'git clean -fdx' . Backup`)
        # etait DECORATIF avant la detection d'ancetre : le root n'est pas lui-meme
        # protege, donc Test-ProtectedPath rendait NotProtected et le Backup mode
        # rendait 'Proceeded' SANS aucun snapshot. Un garde racine qui ne voit pas
        # les proteges CONTENUS sous la cible ne bloque pas la classe d'incident
        # visee par l'issue (le wipe au deploy).

        It 'Detects protected paths CONTAINED under an ancestor target (Reason=ContainsProtectedPath)' {
            $r = Test-ProtectedPath -LiteralPath $script:tmpRoot -RepoRoot $script:tmpRoot
            $r.IsProtected | Should -Be $true
            $r.Reason      | Should -Be 'ContainsProtectedPath'
        }

        It 'Mode Block on the worktree ROOT returns Blocked and destroys nothing' {
            $r = Invoke-DeployPreOpGuard -Operation 'git clean -fdx' -LiteralPath $script:tmpRoot -Mode Block -RepoRoot $script:tmpRoot
            $r.Action   | Should -Be 'Blocked'
            $r.Reason   | Should -Be 'ContainsProtectedPath'
            # Rien n'est detruit : .env, .env.local et build/ sont intacts.
            Test-Path -LiteralPath $script:tmpEnv      | Should -Be $true
            Test-Path -LiteralPath $script:tmpEnvLocal | Should -Be $true
            Test-Path -LiteralPath $script:tmpBuildIdx | Should -Be $true
        }

        It 'Mode Backup on the worktree ROOT snapshots EVERY protected path under it (the documented CLI example is now honest)' {
            $r = Invoke-DeployPreOpGuard -Operation 'git clean -fdx' -LiteralPath $script:tmpRoot -Mode Backup -RepoRoot $script:tmpRoot
            $r.Action   | Should -Be 'BackedUp'
            $r.BackupDir | Should -Not -BeNullOrEmpty
            # .env, .env.local (wildcard) ET build/index.js doivent tous etre dans
            # le snapshot — c'est la promesse du Backup mode racine.
            # -Force : dotfiles caches sur Unix (lecon #3714).
            $names = @(Get-ChildItem -LiteralPath $r.BackupDir -Recurse -File -Force -ErrorAction SilentlyContinue |
                       Select-Object -ExpandProperty Name)
            $names | Should -Contain '.env'
            $names | Should -Contain '.env.local'
            $names | Should -Contain 'index.js'
        }

        It 'A subtree with NO protected content stays Proceeded (no false positive on src/)' {
            $r = Test-ProtectedPath -LiteralPath $script:tmpSrc -RepoRoot $script:tmpRoot
            $r.IsProtected | Should -Be $false
            $r.Reason      | Should -Be 'NotInWhitelist'
        }
    }
}

Describe 'Deploy pipeline entry points wire the guard (#3712)' {

    It 'rebuild-roo-state-manager.ps1 dot-sources deploy-preop-guard.ps1' {
        $scriptPath = Join-Path $PSScriptRoot '..\..\mcp\rebuild-roo-state-manager.ps1'
        $raw = Get-Content -LiteralPath $scriptPath -Raw
        # Le wiring peut prendre deux formes : Test-Path + . $guardScript OU un dot-source
        # direct `. $guardScript`. On cherche la mention du chemin du guard.
        $raw | Should -Match 'deploy-preop-guard\.ps1'
        # Et le pattern de wiring "Test-Path ... puis dot-source" (defensif sur les 2 formes).
        $raw | Should -Match 'Test-Path -LiteralPath \$guardScript'
    }

    It 'rebuild-roo-state-manager.ps1 invokes the guard in Backup mode before Remove-Item build' {
        $scriptPath = Join-Path $PSScriptRoot '..\..\mcp\rebuild-roo-state-manager.ps1'
        $raw = Get-Content -LiteralPath $scriptPath -Raw
        # Ordre dans le fichier : guard Invoke avant Remove-Item build (sentinelle de l'ordre).
        $idxGuard  = $raw.IndexOf('Invoke-DeployPreOpGuard')
        $idxRemove = $raw.IndexOf('Remove-Item -Recurse -Force $buildDir')
        $idxGuard  | Should -BeGreaterOrEqual 0
        $idxRemove | Should -BeGreaterOrEqual 0
        $idxGuard  | Should -BeLessThan $idxRemove
    }

    It 'ensure-build-fresh.ps1 invokes the guard in Backup mode before npm run build' {
        $scriptPath = Join-Path $PSScriptRoot '..\..\claude\ensure-build-fresh.ps1'
        $raw = Get-Content -LiteralPath $scriptPath -Raw
        $idxGuard   = $raw.IndexOf('Invoke-DeployPreOpGuard')
        $idxNpmBuild = $raw.IndexOf('cmd /c "npm run build 2>&1"')
        $idxGuard    | Should -BeGreaterOrEqual 0
        $idxNpmBuild | Should -BeGreaterOrEqual 0
        $idxGuard    | Should -BeLessThan $idxNpmBuild
    }

    It 'start-claude-worker.ps1 invokes the guard in Backup mode before the maintenance git clean (#3712 volet racine)' {
        # Reset-WorktreeForMaintenance est le seul site VIVANT de git clean racine du
        # depot. Ses flags -e protegent .env/*.log/node_modules mais PAS .env.* (un
        # -e .env ne matche que le litteral) : le garde fournit le snapshot de la
        # liste centrale avant le clean.
        $scriptPath = Join-Path $PSScriptRoot '..\..\scheduling\start-claude-worker.ps1'
        $raw = Get-Content -LiteralPath $scriptPath -Raw
        $idxGuard = $raw.IndexOf('Invoke-DeployPreOpGuard')
        $idxClean = $raw.IndexOf('git -C $WorktreePath clean -fd -e .env')
        $idxGuard | Should -BeGreaterOrEqual 0
        $idxClean | Should -BeGreaterOrEqual 0
        $idxGuard | Should -BeLessThan $idxClean
        # Le wiring est bien DANS Reset-WorktreeForMaintenance (pas ailleurs dans le
        # script de 2800 lignes) : la fenetre function...clean doit contenir l'appel.
        $resetPos = $raw.IndexOf('function Reset-WorktreeForMaintenance')
        $resetPos | Should -BeGreaterThan 0
        $window   = $raw.Substring($resetPos, [Math]::Min(4000, $raw.Length - $resetPos))
        ($window -match 'Invoke-DeployPreOpGuard') | Should -Be $true
    }

    It 'test-roo-state-manager-build.ps1 invokes the guard in Backup mode before Remove-Item build' {
        # Meme doctrine que rebuild-roo-state-manager.ps1 : ce script detruisait
        # build/ sans garde (classe d'incident ai-01 17/09).
        $scriptPath = Join-Path $PSScriptRoot '..\test-roo-state-manager-build.ps1'
        $raw = Get-Content -LiteralPath $scriptPath -Raw
        $idxGuard  = $raw.IndexOf('Invoke-DeployPreOpGuard')
        $idxRemove = $raw.IndexOf('Remove-Item "$projectPath/build" -Recurse -Force')
        $idxGuard  | Should -BeGreaterOrEqual 0
        $idxRemove | Should -BeGreaterOrEqual 0
        $idxGuard  | Should -BeLessThan $idxRemove
    }
}
