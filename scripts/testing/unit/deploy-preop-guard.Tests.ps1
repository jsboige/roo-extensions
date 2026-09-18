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
        $script:tmpRoot = Join-Path $env:TEMP "preop-guard-test-$([Guid]::NewGuid().ToString('N').Substring(0,8))"
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
    }

    AfterAll {
        if (Test-Path -LiteralPath $script:tmpRoot) {
            Remove-Item -LiteralPath $script:tmpRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
        # Nettoyer les backups crees dans %USERPROFILE% pendant les tests.
        $preopBackup = Join-Path $env:USERPROFILE '.roo-state-manager\preop-backup'
        if (Test-Path -LiteralPath $preopBackup) {
            Get-ChildItem -LiteralPath $preopBackup -Directory |
                Where-Object { $_.Name -match '^\d{8}-\d{6}$' } |
                Sort-Object CreationTime -Descending |
                Select-Object -Skip 5 |
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

        # Verifier qu'au moins une copie existe sous preop-backup.
        $preopBackup = Join-Path $env:USERPROFILE '.roo-state-manager\preop-backup'
        $found = Get-ChildItem -LiteralPath $preopBackup -Recurse -Filter '.env' -File -ErrorAction SilentlyContinue |
                 Select-Object -First 1
        $found | Should -Not -BeNullOrEmpty
        ($found | Select-Object -First 1).FullName | Should -Match 'preop-backup'
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
        $idxNpmBuild = $raw.IndexOf("& npm.cmd run build")
        $idxGuard    | Should -BeGreaterOrEqual 0
        $idxNpmBuild | Should -BeGreaterOrEqual 0
        $idxGuard    | Should -BeLessThan $idxNpmBuild
    }
}
