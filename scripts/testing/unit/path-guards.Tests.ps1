# Tests unitaires pour les guards de suppression (#2772 couche 3b)
# Module: scripts/common/path-guards.ps1
# Guard: les cleaners refusent tout `Remove-Item -Recurse -Force` dont la cible
# resout dans (ou contient) un working tree de submodule, ou echappe au conteneur
# .claude/worktrees — plus garde #2123 (repo imbrique dans un superproject).
# Syntaxe Pester v3 (Windows PowerShell 5.1)
#
# Usage (Pester v3 explicit — required because the default Invoke-Pester on modern
# Windows loads Pester 5.x, which rejects v3 syntax like `Should Be` / `BeGreaterThan`):
#   powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Import-Module Pester -RequiredVersion 3.4.0 -Force; Invoke-Pester .\scripts\testing\unit\path-guards.Tests.ps1"
#
# Contexte : incident #2772 (28h outage web1) — un .env gitignored vivant dans le
# working tree du submodule mcps/internal peut etre detruit par n'importe quel
# cleaner recursif. Meme famille d'incident que #2123 (nested worktrees).
# Idiome mirroir du Guard #2351 (creation-time, start-claude-worker.ps1).

Describe "Path Guards - #2772 couche 3b (deletion-time)" {

    $projectRoot = (Resolve-Path -Path "$PSScriptRoot\..\..\..").Path
    . (Join-Path $projectRoot "scripts\common\path-guards.ps1")

    # Fixture: fake repo layout with a .gitmodules (git config --file works on a
    # plain directory — no git init required)
    $tempRoot = Join-Path $env:TEMP "path-guards-tests-$(Get-Random)"
    New-Item -ItemType Directory -Path (Join-Path $tempRoot ".claude\worktrees\wt-sample") -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $tempRoot "mcps\internal\servers") -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $tempRoot "mcps\internal-backup") -Force | Out-Null
    $gitmodules = @"
[submodule "mcps/internal"]
	path = mcps/internal
	url = https://example.invalid/internal.git
[submodule "mcps/external/win-cli/server"]
	path = mcps/external/win-cli/server
	url = https://example.invalid/win-cli.git
"@
    [System.IO.File]::WriteAllText((Join-Path $tempRoot ".gitmodules"), $gitmodules, [System.Text.UTF8Encoding]::new($false))

    $worktreesDir = Join-Path $tempRoot ".claude\worktrees"

    # ---------------------------------------------------------------------------
    # ConvertTo-NormalizedPath / Test-PathUnder
    # ---------------------------------------------------------------------------

    Context "Test-PathUnder - containment semantics" {

        It "matches a child path" {
            Test-PathUnder -Path "$tempRoot\mcps\internal\servers" -Root "$tempRoot\mcps\internal" | Should Be $true
        }

        It "matches equality when not strict" {
            Test-PathUnder -Path "$tempRoot\mcps\internal" -Root "$tempRoot\mcps\internal" | Should Be $true
        }

        It "rejects equality when -Strict" {
            Test-PathUnder -Path "$tempRoot\mcps\internal" -Root "$tempRoot\mcps\internal" -Strict | Should Be $false
        }

        It "does NOT match a sibling-prefix path (internal-backup vs internal)" {
            Test-PathUnder -Path "$tempRoot\mcps\internal-backup" -Root "$tempRoot\mcps\internal" | Should Be $false
        }

        It "is case-insensitive (Windows filesystems)" {
            Test-PathUnder -Path ($tempRoot.ToUpper() + "\MCPS\INTERNAL\SERVERS") -Root "$tempRoot\mcps\internal" | Should Be $true
        }

        It "normalizes mixed slashes" {
            Test-PathUnder -Path "$tempRoot/mcps/internal/servers" -Root "$tempRoot\mcps\internal" | Should Be $true
        }

        It "strips the Windows long-path prefix" {
            Test-PathUnder -Path "\\?\$tempRoot\mcps\internal\servers" -Root "$tempRoot\mcps\internal" | Should Be $true
        }
    }

    # ---------------------------------------------------------------------------
    # Get-SubmodulePaths
    # ---------------------------------------------------------------------------

    Context "Get-SubmodulePaths - dynamic .gitmodules read (no hardcoded names)" {

        It "returns every submodule declared in .gitmodules, absolute + normalized" {
            $paths = Get-SubmodulePaths -RepoRoot $tempRoot
            $paths.Count | Should Be 2
            ($paths -join ';') | Should Match 'mcps/internal'
            ($paths -join ';') | Should Match 'mcps/external/win-cli/server'
            foreach ($p in $paths) {
                ($p -match '\\') | Should Be $false   # forward slashes only
                ($p -match '/$') | Should Be $false   # no trailing slash
            }
        }

        It "returns an empty array when .gitmodules is absent (fail-open, cf. #2351)" {
            $emptyDir = Join-Path $env:TEMP "path-guards-empty-$(Get-Random)"
            New-Item -ItemType Directory -Path $emptyDir -Force | Out-Null
            $paths = Get-SubmodulePaths -RepoRoot $emptyDir
            @($paths).Count | Should Be 0
            Remove-Item $emptyDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    # ---------------------------------------------------------------------------
    # Test-SafeDeletionPath — the #2772 guard proper
    # ---------------------------------------------------------------------------

    Context "Test-SafeDeletionPath - refuses submodule-resolving targets (#2772)" {

        It "refuses a target INSIDE a submodule working tree" {
            $v = Test-SafeDeletionPath -Path "$tempRoot\mcps\internal\servers" -RepoRoot $tempRoot
            $v.Safe | Should Be $false
            $v.Reason | Should Match '#2772'
            $v.Reason | Should Match 'submodule'
        }

        It "refuses a target EQUAL to a submodule working tree" {
            $v = Test-SafeDeletionPath -Path "$tempRoot\mcps\internal" -RepoRoot $tempRoot
            $v.Safe | Should Be $false
        }

        It "refuses a target CONTAINING a submodule working tree (parent dir)" {
            $v = Test-SafeDeletionPath -Path "$tempRoot\mcps" -RepoRoot $tempRoot
            $v.Safe | Should Be $false
            $v.Reason | Should Match 'contains submodule'
        }

        It "refuses even with uppercase/mixed-case target (Windows)" {
            $v = Test-SafeDeletionPath -Path ($tempRoot.ToUpper() + "\MCPS\INTERNAL\SERVERS") -RepoRoot $tempRoot
            $v.Safe | Should Be $false
        }

        It "accepts a sibling-prefix path (internal-backup) — no false positive" {
            $v = Test-SafeDeletionPath -Path "$tempRoot\mcps\internal-backup" -RepoRoot $tempRoot
            $v.Safe | Should Be $true
        }

        It "accepts a legitimate worktree dir under AllowedRoot" {
            $v = Test-SafeDeletionPath -Path "$tempRoot\.claude\worktrees\wt-sample" -RepoRoot $tempRoot -AllowedRoot $worktreesDir
            $v.Safe | Should Be $true
        }

        It "accepts a worktree dir given with the long-path prefix" {
            $v = Test-SafeDeletionPath -Path "\\?\$tempRoot\.claude\worktrees\wt-sample" -RepoRoot $tempRoot -AllowedRoot $worktreesDir
            $v.Safe | Should Be $true
        }

        It "refuses a target OUTSIDE AllowedRoot" {
            $v = Test-SafeDeletionPath -Path "$tempRoot\mcps\internal-backup" -RepoRoot $tempRoot -AllowedRoot $worktreesDir
            $v.Safe | Should Be $false
            $v.Reason | Should Match 'not strictly under'
        }

        It "refuses a target EQUAL to AllowedRoot (would delete the whole container)" {
            $v = Test-SafeDeletionPath -Path $worktreesDir -RepoRoot $tempRoot -AllowedRoot $worktreesDir
            $v.Safe | Should Be $false
        }

        It "refuses a relative-path escape (..) out of AllowedRoot" {
            $v = Test-SafeDeletionPath -Path "$worktreesDir\..\..\mcps\internal" -RepoRoot $tempRoot -AllowedRoot $worktreesDir
            $v.Safe | Should Be $false
        }
    }

    # ---------------------------------------------------------------------------
    # Test-SafeCleanupRoot — the #2123 guard (container vetting)
    # ---------------------------------------------------------------------------

    Context "Test-SafeCleanupRoot - container vetting (#2123)" {

        It "accepts a worktrees dir at the repo root (fixture, non-repo => superproject check fails open)" {
            $v = Test-SafeCleanupRoot -Root $worktreesDir -RepoRoot $tempRoot
            $v.Safe | Should Be $true
        }

        It "refuses a worktrees dir nested INSIDE a submodule (the #2123 configuration)" {
            $v = Test-SafeCleanupRoot -Root "$tempRoot\mcps\internal\.claude\worktrees" -RepoRoot $tempRoot
            $v.Safe | Should Be $false
            $v.Reason | Should Match '#2123'
        }

        It "accepts the real repository's worktrees dir" {
            $v = Test-SafeCleanupRoot -Root (Join-Path $projectRoot ".claude\worktrees") -RepoRoot $projectRoot
            $v.Safe | Should Be $true
        }

        # Real-world nested fixture: mcps/internal is an initialized submodule of
        # this repo — rev-parse --show-superproject-working-tree must flag it.
        # Skipped when the submodule is not initialized (e.g. fresh worktree copy).
        if (Test-Path (Join-Path $projectRoot "mcps\internal\.git")) {
            It "refuses when RepoRoot is an initialized submodule (real mcps/internal)" {
                $smRoot = Join-Path $projectRoot "mcps\internal"
                $v = Test-SafeCleanupRoot -Root (Join-Path $smRoot ".claude\worktrees") -RepoRoot $smRoot
                $v.Safe | Should Be $false
                $v.Reason | Should Match '#2123'
            }
        }
    }

    # ---------------------------------------------------------------------------
    # Wiring — the guards are actually dot-sourced and called by the cleaners,
    # BEFORE any deletion strategy (structure checks, same style as #2351 tests)
    # ---------------------------------------------------------------------------

    Context "Wiring - scripts/claude/worktree-cleanup.ps1" {

        $cleaner1 = Get-Content (Join-Path $projectRoot "scripts\claude\worktree-cleanup.ps1") -Raw

        It "dot-sources path-guards.ps1" {
            ($cleaner1 -match 'path-guards\.ps1') | Should Be $true
        }

        It "vets the cleanup container once via Test-SafeCleanupRoot" {
            ($cleaner1 -match 'Test-SafeCleanupRoot') | Should Be $true
        }

        It "guards Remove-OrphanWorktreeDir BEFORE the first deletion strategy" {
            $funcPos     = $cleaner1.IndexOf('function Remove-OrphanWorktreeDir')
            $guardPos    = $cleaner1.IndexOf('Test-SafeDeletionPath', $funcPos)
            $strategyPos = $cleaner1.IndexOf('Remove-Item -Path $Path -Recurse -Force', $funcPos)
            $funcPos     | Should BeGreaterThan 0
            $guardPos    | Should BeGreaterThan $funcPos
            $strategyPos | Should BeGreaterThan $guardPos
        }

        It "refuses with a descriptive REFUSED (#2772) message" {
            ($cleaner1 -match 'REFUSED \(#2772\)') | Should Be $true
        }

        It "normalizes both sides of the active-worktree comparison (slash-mismatch fix)" {
            # git worktree list emits D:/dev/... while FullName is D:\dev\... — the raw
            # -eq never matched, flagging every ACTIVE worktree as orphan (deletable)
            $funcPos = $cleaner1.IndexOf('function Get-OrphanWorktreeDirs')
            $funcEnd = $cleaner1.IndexOf('function Remove-OrphanWorktreeDir')
            $window  = $cleaner1.Substring($funcPos, $funcEnd - $funcPos)
            ($window -match 'ConvertTo-NormalizedPath') | Should Be $true
            ($window -match '\$wt\.Path -eq \$dir\.FullName') | Should Be $false
        }
    }

    Context "Wiring - scripts/maintenance/cleanup-orphan-worktrees.ps1" {

        $cleaner2 = Get-Content (Join-Path $projectRoot "scripts\maintenance\cleanup-orphan-worktrees.ps1") -Raw

        It "dot-sources path-guards.ps1" {
            ($cleaner2 -match 'path-guards\.ps1') | Should Be $true
        }

        It "vets the cleanup container once via Test-SafeCleanupRoot" {
            ($cleaner2 -match 'Test-SafeCleanupRoot') | Should Be $true
        }

        It "guards Remove-ItemWithRetry BEFORE its Remove-Item call" {
            $funcPos     = $cleaner2.IndexOf('function Remove-ItemWithRetry')
            $guardPos    = $cleaner2.IndexOf('Test-SafeDeletionPath', $funcPos)
            $strategyPos = $cleaner2.IndexOf('Remove-Item -Path $Path -Recurse -Force', $funcPos)
            $funcPos     | Should BeGreaterThan 0
            $guardPos    | Should BeGreaterThan $funcPos
            $strategyPos | Should BeGreaterThan $guardPos
        }

        It "refuses with a descriptive REFUSED (#2772) message" {
            ($cleaner2 -match 'REFUSED \(#2772\)') | Should Be $true
        }
    }

    # Fixture cleanup (runs after the Contexts above in Pester v3 sequential flow)
    Remove-Item $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
}
