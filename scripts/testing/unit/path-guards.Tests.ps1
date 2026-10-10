# Tests unitaires pour les guards de suppression (#2772 couche 3b)
# Module: scripts/common/path-guards.ps1
# Guard: les cleaners refusent tout `Remove-Item -Recurse -Force` dont la cible
# résout dans (ou contient) un working tree de submodule, ou échappe au conteneur
# .claude/worktrees — plus garde #2123 (repo imbriqué dans un superproject).
#
# Syntaxe Pester v5 — exécuté en CI par le job `unit-pester` (#3216) via
# scripts/testing/run-pester-tests.ps1. Fonctionne sur pwsh Windows ET Linux :
# - fixture en slashes + [IO.Path]::GetTempPath() (pas de $env:TEMP, absent de pwsh Linux)
# - la comparaison de chemins est portable : ConvertTo-NormalizedPath normalise les
#   backslashes et compare en OrdinalIgnoreCase sur les deux OS
#
# Usage:
#   pwsh -NoProfile -Command "Invoke-Pester -Path ./scripts/testing/unit/path-guards.Tests.ps1 -Output Detailed"
#
# Contexte : incident #2772 (28h outage web1) — un .env gitignored vivant dans le
# working tree du submodule mcps/internal peut être détruit par n'importe quel
# cleaner récursif. Même famille d'incident que #2123 (nested worktrees).
# Idiome miroir du Guard #2351 (creation-time, start-claude-worker.ps1).

# Discovery-time copy: the conditional test inclusion at the bottom of the file
# runs during Pester's discovery pass, when BeforeAll has not executed yet.
$projectRoot = (Resolve-Path -Path "$PSScriptRoot/../../..").Path

BeforeAll {
    $projectRoot = (Resolve-Path -Path "$PSScriptRoot/../../..").Path
    . (Join-Path $projectRoot "scripts/common/path-guards.ps1")

    # Fixture: fake repo layout with a .gitmodules (git config --file works on a
    # plain directory — no git init required)
    $script:TempRoot = Join-Path ([System.IO.Path]::GetTempPath()) "path-guards-tests-$(Get-Random)"
    New-Item -ItemType Directory -Path (Join-Path $script:TempRoot ".claude/worktrees/wt-sample") -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $script:TempRoot "mcps/internal/servers") -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $script:TempRoot "mcps/internal-backup") -Force | Out-Null
    $gitmodules = @"
[submodule "mcps/internal"]
	path = mcps/internal
	url = https://example.invalid/internal.git
[submodule "mcps/external/win-cli/server"]
	path = mcps/external/win-cli/server
	url = https://example.invalid/win-cli.git
"@
    [System.IO.File]::WriteAllText((Join-Path $script:TempRoot ".gitmodules"), $gitmodules, [System.Text.UTF8Encoding]::new($false))

    $script:WorktreesDir = Join-Path $script:TempRoot ".claude/worktrees"
}

AfterAll {
    Remove-Item $script:TempRoot -Recurse -Force -ErrorAction SilentlyContinue
}

Describe "Path Guards - #2772 couche 3b (deletion-time)" {

    # ---------------------------------------------------------------------------
    # ConvertTo-NormalizedPath / Test-PathUnder
    # ---------------------------------------------------------------------------

    Context "Test-PathUnder - containment semantics" {

        It "matches a child path" {
            Test-PathUnder -Path "$script:TempRoot/mcps/internal/servers" -Root "$script:TempRoot/mcps/internal" | Should -Be $true
        }

        It "matches equality when not strict" {
            Test-PathUnder -Path "$script:TempRoot/mcps/internal" -Root "$script:TempRoot/mcps/internal" | Should -Be $true
        }

        It "rejects equality when -Strict" {
            Test-PathUnder -Path "$script:TempRoot/mcps/internal" -Root "$script:TempRoot/mcps/internal" -Strict | Should -Be $false
        }

        It "does NOT match a sibling-prefix path (internal-backup vs internal)" {
            Test-PathUnder -Path "$script:TempRoot/mcps/internal-backup" -Root "$script:TempRoot/mcps/internal" | Should -Be $false
        }

        It "is case-insensitive (explicit OrdinalIgnoreCase — portable on Linux CI)" {
            Test-PathUnder -Path ($script:TempRoot.ToUpper() + "/MCPS/INTERNAL/SERVERS") -Root "$script:TempRoot/mcps/internal" | Should -Be $true
        }

        It "normalizes mixed slashes" {
            Test-PathUnder -Path "$script:TempRoot\mcps\internal\servers" -Root "$script:TempRoot/mcps/internal" | Should -Be $true
        }

        It "strips the Windows long-path prefix" {
            Test-PathUnder -Path "\\?\$script:TempRoot/mcps/internal/servers" -Root "$script:TempRoot/mcps/internal" | Should -Be $true
        }
    }

    # ---------------------------------------------------------------------------
    # Get-SubmodulePaths
    # ---------------------------------------------------------------------------

    Context "Get-SubmodulePaths - dynamic .gitmodules read (no hardcoded names)" {

        It "returns every submodule declared in .gitmodules, absolute + normalized" {
            $paths = Get-SubmodulePaths -RepoRoot $script:TempRoot
            $paths.Count | Should -Be 2
            ($paths -join ';') | Should -Match 'mcps/internal'
            ($paths -join ';') | Should -Match 'mcps/external/win-cli/server'
            foreach ($p in $paths) {
                ($p -match '\\') | Should -Be $false   # forward slashes only
                ($p -match '/$') | Should -Be $false   # no trailing slash
            }
        }

        It "returns an empty array when .gitmodules is absent (fail-open, cf. #2351)" {
            $emptyDir = Join-Path ([System.IO.Path]::GetTempPath()) "path-guards-empty-$(Get-Random)"
            New-Item -ItemType Directory -Path $emptyDir -Force | Out-Null
            $paths = Get-SubmodulePaths -RepoRoot $emptyDir
            @($paths).Count | Should -Be 0
            Remove-Item $emptyDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    # ---------------------------------------------------------------------------
    # Test-SafeDeletionPath — the #2772 guard proper
    # ---------------------------------------------------------------------------

    Context "Test-SafeDeletionPath - refuses submodule-resolving targets (#2772)" {

        It "refuses a target INSIDE a submodule working tree" {
            $v = Test-SafeDeletionPath -Path "$script:TempRoot/mcps/internal/servers" -RepoRoot $script:TempRoot
            $v.Safe | Should -Be $false
            $v.Reason | Should -Match '#2772'
            $v.Reason | Should -Match 'submodule'
        }

        It "refuses a target EQUAL to a submodule working tree" {
            $v = Test-SafeDeletionPath -Path "$script:TempRoot/mcps/internal" -RepoRoot $script:TempRoot
            $v.Safe | Should -Be $false
        }

        It "refuses a target CONTAINING a submodule working tree (parent dir)" {
            $v = Test-SafeDeletionPath -Path "$script:TempRoot/mcps" -RepoRoot $script:TempRoot
            $v.Safe | Should -Be $false
            $v.Reason | Should -Match 'contains submodule'
        }

        It "refuses even with uppercase/mixed-case target" {
            $v = Test-SafeDeletionPath -Path ($script:TempRoot.ToUpper() + "/MCPS/INTERNAL/SERVERS") -RepoRoot $script:TempRoot
            $v.Safe | Should -Be $false
        }

        It "accepts a sibling-prefix path (internal-backup) — no false positive" {
            $v = Test-SafeDeletionPath -Path "$script:TempRoot/mcps/internal-backup" -RepoRoot $script:TempRoot
            $v.Safe | Should -Be $true
        }

        It "accepts a legitimate worktree dir under AllowedRoot" {
            $v = Test-SafeDeletionPath -Path "$script:TempRoot/.claude/worktrees/wt-sample" -RepoRoot $script:TempRoot -AllowedRoot $script:WorktreesDir
            $v.Safe | Should -Be $true
        }

        It "accepts a worktree dir given with the long-path prefix" {
            $v = Test-SafeDeletionPath -Path "\\?\$script:TempRoot/.claude/worktrees/wt-sample" -RepoRoot $script:TempRoot -AllowedRoot $script:WorktreesDir
            $v.Safe | Should -Be $true
        }

        It "refuses a target OUTSIDE AllowedRoot" {
            $v = Test-SafeDeletionPath -Path "$script:TempRoot/mcps/internal-backup" -RepoRoot $script:TempRoot -AllowedRoot $script:WorktreesDir
            $v.Safe | Should -Be $false
            $v.Reason | Should -Match 'not strictly under'
        }

        It "refuses a target EQUAL to AllowedRoot (would delete the whole container)" {
            $v = Test-SafeDeletionPath -Path $script:WorktreesDir -RepoRoot $script:TempRoot -AllowedRoot $script:WorktreesDir
            $v.Safe | Should -Be $false
        }

        It "refuses a relative-path escape (..) out of AllowedRoot" {
            $v = Test-SafeDeletionPath -Path "$script:WorktreesDir/../../mcps/internal" -RepoRoot $script:TempRoot -AllowedRoot $script:WorktreesDir
            $v.Safe | Should -Be $false
        }
    }

    # ---------------------------------------------------------------------------
    # Test-SafeCleanupRoot — the #2123 guard (container vetting)
    # ---------------------------------------------------------------------------

    Context "Test-SafeCleanupRoot - container vetting (#2123)" {

        It "accepts a worktrees dir at the repo root (fixture, non-repo => superproject check fails open)" {
            $v = Test-SafeCleanupRoot -Root $script:WorktreesDir -RepoRoot $script:TempRoot
            $v.Safe | Should -Be $true
        }

        It "refuses a worktrees dir nested INSIDE a submodule (the #2123 configuration)" {
            $v = Test-SafeCleanupRoot -Root "$script:TempRoot/mcps/internal/.claude/worktrees" -RepoRoot $script:TempRoot
            $v.Safe | Should -Be $false
            $v.Reason | Should -Match '#2123'
        }

        It "accepts the real repository's worktrees dir" {
            $v = Test-SafeCleanupRoot -Root (Join-Path $projectRoot ".claude/worktrees") -RepoRoot $projectRoot
            $v.Safe | Should -Be $true
        }

        # Real-world nested fixture: mcps/internal is an initialized submodule of
        # this repo — rev-parse --show-superproject-working-tree must flag it.
        # Skipped when the submodule is not initialized (e.g. CI checkout without
        # submodules, or fresh worktree copy). Evaluated at discovery time.
        if (Test-Path (Join-Path $projectRoot "mcps/internal/.git")) {
            It "refuses when RepoRoot is an initialized submodule (real mcps/internal)" {
                $smRoot = Join-Path $projectRoot "mcps/internal"
                $v = Test-SafeCleanupRoot -Root (Join-Path $smRoot ".claude/worktrees") -RepoRoot $smRoot
                $v.Safe | Should -Be $false
                $v.Reason | Should -Match '#2123'
            }
        }
    }

    # ---------------------------------------------------------------------------
    # Test-RegisteredWorktreeDir — worktrees registered by ANOTHER repo (submodule)
    # are absent from the parent's `git worktree list` but live (po-2026/po-2025 02/10)
    # ---------------------------------------------------------------------------

    Context "Test-RegisteredWorktreeDir - live registration vs husk" {

        BeforeAll {
            $script:RegRoot = Join-Path $script:TempRoot "reg-fixture"
            # Registry dirs that a .git file can point to
            New-Item -ItemType Directory -Path "$script:RegRoot/modules/internal/worktrees/live" -Force | Out-Null
            New-Item -ItemType Directory -Path "$script:RegRoot/rel-registry/worktrees/rel" -Force | Out-Null

            # Untyped content: [string] would turn $null into '' and write an empty .git
            function New-WorktreeDir([string]$Name, $GitFileContent) {
                $d = Join-Path $script:RegRoot $Name
                New-Item -ItemType Directory -Path $d -Force | Out-Null
                if ($null -ne $GitFileContent) {
                    [System.IO.File]::WriteAllText((Join-Path $d '.git'), $GitFileContent, [System.Text.UTF8Encoding]::new($false))
                }
                return $d
            }
        }

        It "returns true when the gitdir target exists (absolute path)" {
            $d = New-WorktreeDir 'wt-live' "gitdir: $script:RegRoot/modules/internal/worktrees/live`n"
            Test-RegisteredWorktreeDir -Path $d | Should -Be $true
        }

        It "returns true when the gitdir target exists (relative path, resolved from the worktree)" {
            $d = New-WorktreeDir 'wt-rel' "gitdir: ../rel-registry/worktrees/rel`n"
            Test-RegisteredWorktreeDir -Path $d | Should -Be $true
        }

        It "returns false when the gitdir target is gone (husk: registry pruned)" {
            $d = New-WorktreeDir 'wt-dangling' "gitdir: $script:RegRoot/modules/internal/worktrees/gone`n"
            Test-RegisteredWorktreeDir -Path $d | Should -Be $false
        }

        It "returns false without a .git file" {
            $d = New-WorktreeDir 'wt-plain' $null
            Test-RegisteredWorktreeDir -Path $d | Should -Be $false
        }

        It "returns false for an empty .git file (no gitdir line), without throwing" {
            $d = New-WorktreeDir 'wt-empty-gitfile' ''
            Test-RegisteredWorktreeDir -Path $d | Should -Be $false
        }

        It "returns false for a .git DIRECTORY (standalone clone, not a linked worktree)" {
            $d = New-WorktreeDir 'wt-clone' $null
            New-Item -ItemType Directory -Path (Join-Path $d '.git') -Force | Out-Null
            Test-RegisteredWorktreeDir -Path $d | Should -Be $false
        }
    }

    # ---------------------------------------------------------------------------
    # Behaviour — cleanup-orphan-worktrees.ps1 runs on every worker start with
    # -Execute -DaysThreshold 0: a live worktree of another repo must survive it
    # ---------------------------------------------------------------------------

    Context "Behaviour - cleanup-orphan-worktrees.ps1 keeps a live foreign worktree" {

        BeforeAll {
            $script:BhvRoot = Join-Path ([System.IO.Path]::GetTempPath()) "orphan-cleaner-bhv-$(Get-Random)"
            $script:Parent = Join-Path $script:BhvRoot 'parent'
            $script:Other  = Join-Path $script:BhvRoot 'other'
            New-Item -ItemType Directory -Path (Join-Path $script:Parent '.claude/worktrees') -Force | Out-Null
            New-Item -ItemType Directory -Path $script:Other -Force | Out-Null
            foreach ($r in @($script:Parent, $script:Other)) {
                git -C $r init -q 2>&1 | Out-Null
                git -C $r -c user.email=t@example.invalid -c user.name=t commit --allow-empty -q -m init 2>&1 | Out-Null
            }
            # Worktree of the OTHER repo placed in the parent's container — the
            # submodule-worktree layout of the 02/10 incidents.
            $script:Foreign = Join-Path $script:Parent '.claude/worktrees/wt-foreign'
            git -C $script:Other worktree add -q -b wt/foreign $script:Foreign 2>&1 | Out-Null
            [System.IO.File]::WriteAllText((Join-Path $script:Foreign 'work.txt'), 'committed elsewhere', [System.Text.UTF8Encoding]::new($false))
            # True husk next to it: must still be cleaned
            $script:Husk = Join-Path $script:Parent '.claude/worktrees/wt-husk'
            New-Item -ItemType Directory -Path $script:Husk -Force | Out-Null

            $cleaner = Join-Path $projectRoot 'scripts/maintenance/cleanup-orphan-worktrees.ps1'
            & $cleaner -RepoRoot $script:Parent -Execute -DaysThreshold 0 -LogPath (Join-Path $script:BhvRoot 'cleanup.log') *> $null
        }

        AfterAll {
            git -C $script:Other worktree remove --force $script:Foreign 2>&1 | Out-Null
            Remove-Item $script:BhvRoot -Recurse -Force -ErrorAction SilentlyContinue
        }

        It "fixture sanity: the foreign worktree is NOT in the parent's worktree list" {
            (@(git -C $script:Parent worktree list --porcelain) -join "`n") | Should -Not -Match 'wt-foreign'
        }

        It "keeps the foreign worktree and its files" {
            Test-Path (Join-Path $script:Foreign 'work.txt') | Should -Be $true
            Test-Path (Join-Path $script:Foreign '.git') | Should -Be $true
        }

        It "still removes the unregistered husk" {
            Test-Path $script:Husk | Should -Be $false
        }
    }

    # ---------------------------------------------------------------------------
    # Wiring — the guards are actually dot-sourced and called by the cleaners,
    # BEFORE any deletion strategy (structure checks, same style as #2351 tests)
    # ---------------------------------------------------------------------------

    Context "Wiring - scripts/claude/worktree-cleanup.ps1" {

        BeforeAll {
            $cleaner1 = Get-Content (Join-Path $projectRoot "scripts/claude/worktree-cleanup.ps1") -Raw
        }

        It "dot-sources path-guards.ps1" {
            ($cleaner1 -match 'path-guards\.ps1') | Should -Be $true
        }

        It "vets the cleanup container once via Test-SafeCleanupRoot" {
            ($cleaner1 -match 'Test-SafeCleanupRoot') | Should -Be $true
        }

        It "guards Remove-OrphanWorktreeDir BEFORE the first deletion strategy" {
            $funcPos     = $cleaner1.IndexOf('function Remove-OrphanWorktreeDir')
            $guardPos    = $cleaner1.IndexOf('Test-SafeDeletionPath', $funcPos)
            $strategyPos = $cleaner1.IndexOf('Remove-Item -Path $Path -Recurse -Force', $funcPos)
            $funcPos     | Should -BeGreaterThan 0
            $guardPos    | Should -BeGreaterThan $funcPos
            $strategyPos | Should -BeGreaterThan $guardPos
        }

        It "refuses with a descriptive REFUSED (#2772) message" {
            ($cleaner1 -match 'REFUSED \(#2772\)') | Should -Be $true
        }

        It "unlinks junctions after the guards and BEFORE the first deletion strategy" {
            $funcPos     = $cleaner1.IndexOf('function Remove-OrphanWorktreeDir')
            $whatIfPos   = $cleaner1.IndexOf('[WHATIF] Would remove', $funcPos)
            $unlinkPos   = $cleaner1.IndexOf('Remove-ReparsePointsUnder -Path $Path', $funcPos)
            $strategyPos = $cleaner1.IndexOf('Remove-Item -Path $Path -Recurse -Force', $funcPos)
            $unlinkPos   | Should -BeGreaterThan $whatIfPos
            $strategyPos | Should -BeGreaterThan $unlinkPos
        }

        It "deletes nothing when a junction survives" {
            ($cleaner1 -match '(?s)if \(-not \$links\.AllUnlinked\) \{[^}]*REFUSED \(junction-guard\)[^}]*return') | Should -Be $true
        }

        It "normalizes both sides of the active-worktree comparison (slash-mismatch fix)" {
            # git worktree list emits D:/dev/... while FullName is D:\dev\... — the raw
            # -eq never matched, flagging every ACTIVE worktree as orphan (deletable)
            $funcPos = $cleaner1.IndexOf('function Get-OrphanWorktreeDirs')
            $funcEnd = $cleaner1.IndexOf('function Remove-OrphanWorktreeDir')
            $window  = $cleaner1.Substring($funcPos, $funcEnd - $funcPos)
            ($window -match 'ConvertTo-NormalizedPath') | Should -Be $true
            ($window -match '\$wt\.Path -eq \$dir\.FullName') | Should -Be $false
        }
    }

    Context "Wiring - scripts/maintenance/cleanup-orphan-worktrees.ps1" {

        BeforeAll {
            $cleaner2 = Get-Content (Join-Path $projectRoot "scripts/maintenance/cleanup-orphan-worktrees.ps1") -Raw
        }

        It "dot-sources path-guards.ps1" {
            ($cleaner2 -match 'path-guards\.ps1') | Should -Be $true
        }

        It "vets the cleanup container once via Test-SafeCleanupRoot" {
            ($cleaner2 -match 'Test-SafeCleanupRoot') | Should -Be $true
        }

        It "guards Remove-ItemWithRetry BEFORE its Remove-Item call" {
            $funcPos     = $cleaner2.IndexOf('function Remove-ItemWithRetry')
            $guardPos    = $cleaner2.IndexOf('Test-SafeDeletionPath', $funcPos)
            $strategyPos = $cleaner2.IndexOf('Remove-Item -Path $Path -Recurse -Force', $funcPos)
            $funcPos     | Should -BeGreaterThan 0
            $guardPos    | Should -BeGreaterThan $funcPos
            $strategyPos | Should -BeGreaterThan $guardPos
        }

        It "refuses with a descriptive REFUSED (#2772) message" {
            ($cleaner2 -match 'REFUSED \(#2772\)') | Should -Be $true
        }

        It "unlinks junctions after the guard and BEFORE its Remove-Item call" {
            $funcPos     = $cleaner2.IndexOf('function Remove-ItemWithRetry')
            $guardPos    = $cleaner2.IndexOf('Test-SafeDeletionPath', $funcPos)
            $unlinkPos   = $cleaner2.IndexOf('Remove-ReparsePointsUnder -Path $Path', $funcPos)
            $strategyPos = $cleaner2.IndexOf('Remove-Item -Path $Path -Recurse -Force', $funcPos)
            $unlinkPos   | Should -BeGreaterThan $guardPos
            $strategyPos | Should -BeGreaterThan $unlinkPos
        }

        It "deletes nothing when a junction survives" {
            ($cleaner2 -match '(?s)if \(-not \$links\.AllUnlinked\) \{[^}]*REFUSED \(junction-guard\)[^}]*return \$false') | Should -Be $true
        }
    }

    Context "Wiring - the two cleaners that call git worktree remove" {

        BeforeAll {
            $agentCleaner = Get-Content (Join-Path $projectRoot "scripts/maintenance/cleanup-agent-orphan-worktrees.ps1") -Raw
            $fleetAudit   = Get-Content (Join-Path $projectRoot "scripts/maintenance/audit-worktrees-fleet.ps1") -Raw
        }

        It "cleanup-agent-orphan-worktrees.ps1 unlinks BEFORE unlock and remove, and skips on failure" {
            $unlinkPos = $agentCleaner.IndexOf('Remove-ReparsePointsUnder -Path $wtPath')
            $unlockPos = $agentCleaner.IndexOf('worktree unlock $wtPath')
            $removePos = $agentCleaner.IndexOf('worktree remove $wtPath')
            $unlinkPos | Should -BeGreaterThan 0
            $unlockPos | Should -BeGreaterThan $unlinkPos
            $removePos | Should -BeGreaterThan $unlockPos
            ($agentCleaner -match '(?s)if \(-not \$links\.AllUnlinked\) \{[^}]*junction-guard[^}]*continue') | Should -Be $true
        }

        It "audit-worktrees-fleet.ps1 unlinks after the #2772 guard and BEFORE worktree remove, and skips on failure" {
            $guardPos  = $fleetAudit.IndexOf('Test-SafeDeletionPath -Path $r.Path')
            $unlinkPos = $fleetAudit.IndexOf('Remove-ReparsePointsUnder -Path $r.Path')
            $removePos = $fleetAudit.IndexOf("'worktree', 'remove', `$r.Path")
            $guardPos  | Should -BeGreaterThan 0
            $unlinkPos | Should -BeGreaterThan $guardPos
            $removePos | Should -BeGreaterThan $unlinkPos
            ($fleetAudit -match '(?s)if \(-not \$links\.AllUnlinked\) \{[^}]*junction-guard[^}]*continue') | Should -Be $true
        }
    }

    Context "Remove-ReparsePointsUnder - unlink without following (junction guard)" {

        BeforeAll {
            # Code of the helper only: from its #> (the help text names the hazards)
            # to the next function, so a later function cannot fake a match.
            $guardSrc = Get-Content (Join-Path $projectRoot "scripts/common/path-guards.ps1") -Raw
            $helperBody = $guardSrc.Substring($guardSrc.IndexOf('function Remove-ReparsePointsUnder'))
            $helperBody = $helperBody.Substring($helperBody.IndexOf('#>'))
            $nextFunc = $helperBody.IndexOf("`nfunction ")
            if ($nextFunc -gt 0) { $helperBody = $helperBody.Substring(0, $nextFunc) }
        }

        It "returns AllUnlinked for a missing path, without error" {
            $r = Remove-ReparsePointsUnder -Path (Join-Path $script:TempRoot 'does-not-exist')
            $r.AllUnlinked | Should -Be $true
            @($r.Failed).Count | Should -Be 0
        }

        It "tests ReparsePoint BEFORE descending (never walks into a link)" {
            $test = $helperBody.IndexOf('$sub.Attributes -band [System.IO.FileAttributes]::ReparsePoint')
            $push = $helperBody.IndexOf('$stack.Push($sub)')
            $test | Should -BeGreaterThan 0
            $push | Should -BeGreaterThan $test
            $helperBody | Should -Match '\[System\.IO\.Directory\]::Delete\(\$sub\.FullName, \$false\)'
            $helperBody | Should -Not -Match 'Remove-Item|rmdir /s|-Recurse'
        }

        It "refuses a root that is itself a reparse point BEFORE walking it" {
            # A junction root lists its TARGET: walking it would unlink links outside the container.
            $rootTest = $helperBody.IndexOf('$root.Attributes -band [System.IO.FileAttributes]::ReparsePoint')
            $rootPush = $helperBody.IndexOf('$stack.Push($root)')
            $rootTest | Should -BeGreaterThan 0
            $rootPush | Should -BeGreaterThan $rootTest
            $helperBody | Should -Match '(?s)\$root\.Attributes -band \[System\.IO\.FileAttributes\]::ReparsePoint\) \{[^}]*AllUnlinked = \$false'
        }

        It "refuses a junction root and leaves the junctions of its target in place" -Skip:($env:OS -ne 'Windows_NT') {
            $root = Join-Path ([System.IO.Path]::GetTempPath()) ("reparse-root-" + [guid]::NewGuid().ToString('N'))
            $target = Join-Path $root 'target'
            New-Item -ItemType Directory -Force (Join-Path $target 'real') | Out-Null
            New-Item -ItemType Junction -Path (Join-Path $target 'inner-link') -Target (Join-Path $target 'real') | Out-Null
            $rootLink = Join-Path $root 'rootlink'
            New-Item -ItemType Junction -Path $rootLink -Target $target | Out-Null

            try {
                $r = Remove-ReparsePointsUnder -Path $rootLink
                $r.AllUnlinked | Should -Be $false
                @($r.Unlinked).Count | Should -Be 0
                Test-Path (Join-Path $target 'inner-link') | Should -Be $true
            } finally {
                foreach ($link in @($rootLink, (Join-Path $target 'inner-link'))) {
                    if (Test-Path -LiteralPath $link) { [System.IO.Directory]::Delete($link, $false) }
                }
                Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
            }
        }

        It "unlinks a junction without touching its target, even with an npm self-link loop" -Skip:($env:OS -ne 'Windows_NT') {
            $root = Join-Path ([System.IO.Path]::GetTempPath()) ("reparse-guard-" + [guid]::NewGuid().ToString('N'))
            $server = Join-Path $root 'main/server'
            New-Item -ItemType Directory -Force (Join-Path $server 'node_modules/pkg') | Out-Null
            Set-Content (Join-Path $server '.env') 'secret'
            Set-Content (Join-Path $server 'node_modules/pkg/index.js') 'x'
            New-Item -ItemType Junction -Path (Join-Path $server 'node_modules/server') -Target $server | Out-Null
            $wt = Join-Path $root 'wt'
            New-Item -ItemType Directory -Force (Join-Path $wt 'servers/server') | Out-Null
            New-Item -ItemType Junction -Path (Join-Path $wt 'servers/server/node_modules') -Target (Join-Path $server 'node_modules') | Out-Null

            try {
                $r = Remove-ReparsePointsUnder -Path $wt
                $r.AllUnlinked | Should -Be $true
                @($r.Unlinked).Count | Should -Be 1
                Test-Path (Join-Path $wt 'servers/server/node_modules') | Should -Be $false
                Remove-Item -LiteralPath $wt -Recurse -Force
                Test-Path (Join-Path $server '.env') | Should -Be $true
                Test-Path (Join-Path $server 'node_modules/pkg/index.js') | Should -Be $true
            } finally {
                & cmd /c "rmdir ""$(Join-Path $server 'node_modules\server')""" 2>&1 | Out-Null
                Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }
}
