# Tests for the Agent harness isolation bug (#3345).
#
# Reproduces the failure mode locally: an `agent-*` worktree must be
# genuinely isolated, i.e. `git rev-parse --show-toplevel` run inside the
# worktree must resolve to the worktree directory itself, NOT to a parent
# or sibling repo. The upstream Claude Code Agent harness is supposed to
# enforce this; the test below enforces it at the git primitive level so
# we have a regression baseline while the upstream fix is pending.
#
# Scope:
# - Pure PowerShell + git, no Claude Code Agent tool required
# - Self-contained: creates and tears down a temp repo per test
# - Cross-platform: git on Linux/macOS/Windows
#
# Issue #3345: validation that `git worktree add` produces an actually
# isolated worktree, plus the defensive cleanup script
# (`scripts/maintenance/cleanup-agent-orphan-worktrees.ps1`) is reachable
# and reports (does NOT execute) cleanly on a synthetic orphan — and, since
# the cross-repo gap fix, actually cleans the incident class (registry entry
# in one repo, physical tree under a path-prefix sibling) with -AllowCrossRepo.
#
# Run:
#   pwsh -NoProfile -Command "Invoke-Pester -Path ./scripts/testing/unit/agent-worktree-isolation.Tests.ps1 -Output Detailed"

BeforeAll {
    $script:projectRoot = (Resolve-Path -Path "$PSScriptRoot/../../..").Path
    $script:cleanupScript = Join-Path $script:projectRoot "scripts/maintenance/cleanup-agent-orphan-worktrees.ps1"
    Test-Path $script:cleanupScript | Should -Be $true

    # Helper: create a temp git repo with one commit and a branch, return path.
    function script:New-TempRepo {
        $root = Join-Path ([System.IO.Path]::GetTempPath()) ("agent-iso-" + [Guid]::NewGuid().ToString('N').Substring(0, 8))
        New-Item -ItemType Directory -Path $root | Out-Null
        Push-Location $root
        try {
            git init -q 2>&1 | Out-Null
            git -c user.email=t@t -c user.name=t commit --allow-empty -q -m initial
            git branch feature/test HEAD 2>&1 | Out-Null
        } finally {
            Pop-Location
        }
        return $root
    }

    # Helper: cleanup a temp repo (best-effort).
    function script:Remove-TempRepo {
        param([string]$Path)
        if (Test-Path $Path) {
            Push-Location (Split-Path $Path -Parent)
            try {
                git -C $Path worktree list --porcelain 2>$null | ForEach-Object {
                    if ($_ -match '^worktree (.+)$') {
                        $wt = $Matches[1].Trim()
                        if ($wt -ne $Path) {
                            git -C $Path worktree remove --force $wt 2>&1 | Out-Null
                        }
                    }
                }
            } finally {
                Pop-Location
            }
            Remove-Item -Recurse -Force $Path -ErrorAction SilentlyContinue
        }
    }
}

Describe "Issue #3345 — Agent worktree isolation" {

    Context "Basic worktree isolation" {

        It "git rev-parse --show-toplevel inside the worktree equals the worktree path" {
            $repo = New-TempRepo
            try {
                $wtPath = Join-Path $repo ".claude/worktrees/agent-test"
                New-Item -ItemType Directory -Path (Split-Path $wtPath -Parent) -Force | Out-Null
                git -C $repo worktree add $wtPath feature/test 2>&1 | Out-Null

                $inside = (git -C $wtPath rev-parse --show-toplevel).Trim()

                # Normalize to forward-slash form for cross-platform comparison
                $insideNorm = ($inside -replace '\\', '/').TrimEnd('/')
                $wtNorm = ($wtPath -replace '\\', '/').TrimEnd('/')

                $insideNorm | Should -Be $wtNorm
            } finally {
                Remove-TempRepo -Path $repo
            }
        }

        It "core.worktree is set to the parent repo's .git/worktrees/<name>" {
            $repo = New-TempRepo
            try {
                $wtPath = Join-Path $repo ".claude/worktrees/agent-test"
                New-Item -ItemType Directory -Path (Split-Path $wtPath -Parent) -Force | Out-Null
                git -C $repo worktree add $wtPath feature/test 2>&1 | Out-Null

                $gitdir = (git -C $wtPath rev-parse --git-dir).Trim()
                $worktree = (git -C $wtPath rev-parse --parseopt --show-toplevel 2>$null)

                # The worktree's git-dir must live under the parent repo's .git/worktrees/
                $parentGit = Join-Path $repo ".git"
                $gitdirNorm = ($gitdir -replace '\\', '/')
                $parentGitNorm = ($parentGit -replace '\\', '/')
                $gitdirNorm.StartsWith($parentGitNorm, [System.StringComparison]::OrdinalIgnoreCase) | Should -Be $true
            } finally {
                Remove-TempRepo -Path $repo
            }
        }
    }

    Context "Cleanup script — defensive coverage" {

        It "detects a synthetic locked agent-* worktree as orphan" {
            $repo = New-TempRepo
            try {
                $wtPath = Join-Path $repo ".claude/worktrees/agent-dead"
                New-Item -ItemType Directory -Path (Split-Path $wtPath -Parent) -Force | Out-Null
                git -C $repo worktree add --lock --reason "claude agent agent-dead (pid 99999)" $wtPath feature/test 2>&1 | Out-Null

                $output = pwsh -NoProfile -File $script:cleanupScript -RepoRoot $repo 2>&1 | Out-String
                $output | Should -Match "agent-dead"
                $output | Should -Match "orphan"
                $output | Should -Match "DRY-RUN"
            } finally {
                Remove-TempRepo -Path $repo
            }
        }

        It "DRY-RUN does NOT unlock the worktree" {
            $repo = New-TempRepo
            try {
                $wtPath = Join-Path $repo ".claude/worktrees/agent-dry"
                New-Item -ItemType Directory -Path (Split-Path $wtPath -Parent) -Force | Out-Null
                git -C $repo worktree add --lock --reason "claude agent agent-dry (pid 99999)" $wtPath feature/test 2>&1 | Out-Null

                pwsh -NoProfile -File $script:cleanupScript -RepoRoot $repo 2>&1 | Out-Null

                $porcelain = git -C $repo worktree list --porcelain -z 2>&1 | Out-String
                $porcelain | Should -Match "locked"
            } finally {
                Remove-TempRepo -Path $repo
            }
        }

        It "-Execute unlocks + removes + prunes the orphan" {
            $repo = New-TempRepo
            try {
                $wtPath = Join-Path $repo ".claude/worktrees/agent-exec"
                New-Item -ItemType Directory -Path (Split-Path $wtPath -Parent) -Force | Out-Null
                git -C $repo worktree add --lock --reason "claude agent agent-exec (pid 99999)" $wtPath feature/test 2>&1 | Out-Null

                $output = pwsh -NoProfile -File $script:cleanupScript -RepoRoot $repo -Execute 2>&1 | Out-String
                $output | Should -Match "unlocked \+ removed \+ pruned"

                # Criterion #3345-6: no orphan (locked or listed) must remain.
                $porcelain = git -C $repo worktree list --porcelain -z 2>&1 | Out-String
                $porcelain | Should -Not -Match "agent-exec"
                $porcelain | Should -Not -Match "locked"
                (Test-Path $wtPath) | Should -Be $false
            } finally {
                Remove-TempRepo -Path $repo
            }
        }

        It "-Execute leaves a locked worktree alone when the locking PID is alive" {
            $repo = New-TempRepo
            try {
                $wtPath = Join-Path $repo ".claude/worktrees/agent-alive"
                New-Item -ItemType Directory -Path (Split-Path $wtPath -Parent) -Force | Out-Null
                # Lock with the PID of the Pester runner itself — guaranteed
                # alive for the duration of this test (review finding on
                # #3349: the previous Test-Path "pid:" check never returned
                # true, so this safety branch was untested and dead).
                git -C $repo worktree add --lock --reason "claude agent agent-alive (pid $PID)" $wtPath feature/test 2>&1 | Out-Null

                $output = pwsh -NoProfile -File $script:cleanupScript -RepoRoot $repo -Execute 2>&1 | Out-String
                $output | Should -Match "is alive"
                $output | Should -Match "leaving alone"

                # The worktree must STILL be locked — the script must not
                # unlock an in-flight agent's worktree even with -Execute.
                $porcelain = git -C $repo worktree list --porcelain -z 2>&1 | Out-String
                $porcelain | Should -Match "locked"
            } finally {
                Remove-TempRepo -Path $repo
            }
        }

        It "ignores non-agent worktrees by default pattern" {
            $repo = New-TempRepo
            try {
                $wtPath = Join-Path $repo ".claude/worktrees/wt-other"
                New-Item -ItemType Directory -Path (Split-Path $wtPath -Parent) -Force | Out-Null
                git -C $repo worktree add --lock --reason "manual lock (pid 99999)" $wtPath feature/test 2>&1 | Out-Null

                $output = pwsh -NoProfile -File $script:cleanupScript -RepoRoot $repo 2>&1 | Out-String
                # The repo root basename (e.g. agent-iso-XXXX) may also match
                # the pattern, but its worktree entry is unlocked (not an
                # orphan) so the only entry that should be reported is the
                # `wt-other` — and it must NOT appear with the default
                # `agent-*` filter.
                $output | Should -Not -Match "wt-other"
            } finally {
                Remove-TempRepo -Path $repo
            }
        }

        It "custom -NamePattern matches non-default basenames" {
            $repo = New-TempRepo
            try {
                $wtPath = Join-Path $repo ".claude/worktrees/wt-other"
                New-Item -ItemType Directory -Path (Split-Path $wtPath -Parent) -Force | Out-Null
                git -C $repo worktree add --lock --reason "manual lock (pid 99999)" $wtPath feature/test 2>&1 | Out-Null

                $output = pwsh -NoProfile -File $script:cleanupScript -RepoRoot $repo -NamePattern 'wt-*' 2>&1 | Out-String
                $output | Should -Match "wt-other"
            } finally {
                Remove-TempRepo -Path $repo
            }
        }
    }

    Context "Cross-repo orphans (incident class: registry in one repo, tree under a sibling)" {

        # Incident #3345 topology: the admin entry lives in repo A's
        # .git/worktrees/ registry but the physical tree sits under a sibling
        # directory B (path-prefix collision, e.g. D:/Dev/CoursIA vs
        # D:/Dev/CoursIA-2). Review finding on the merged mitigation: -Execute
        # SKIPped this class entirely, so the only real-world instances of the
        # bug could never be cleaned. These tests pin the fixed contract.
        BeforeEach {
            # Sandbox prefix deliberately NOT matching the worktree basename
            # (`agent-xrepo`) so path assertions can't false-positive on the
            # sandbox root itself.
            $script:xroot = Join-Path ([System.IO.Path]::GetTempPath()) ("xrepo-sb-" + [Guid]::NewGuid().ToString('N').Substring(0, 8))
            $script:repoA = Join-Path $script:xroot "A"
            $script:siblB = Join-Path $script:xroot "B"
            New-Item -ItemType Directory -Path $script:repoA | Out-Null
            Push-Location $script:repoA
            try {
                git init -q 2>&1 | Out-Null
                git -c user.email=t@t -c user.name=t commit --allow-empty -q -m initial
                git branch feature/test HEAD 2>&1 | Out-Null
            } finally {
                Pop-Location
            }
            $script:wtPath = Join-Path $script:siblB ".claude/worktrees/agent-xrepo"
            New-Item -ItemType Directory -Path (Split-Path $script:wtPath -Parent) -Force | Out-Null
            git -C $script:repoA worktree add --lock --reason "claude agent agent-xrepo (pid 99999)" $script:wtPath feature/test 2>&1 | Out-Null
        }
        AfterEach {
            if (Test-Path $script:xroot) {
                # Remove any worktree registered from A but living under B
                # before deleting the sandbox, or git blocks dir removal.
                git -C $script:repoA worktree unlock $script:wtPath 2>&1 | Out-Null
                git -C $script:repoA worktree remove --force $script:wtPath 2>&1 | Out-Null
                Remove-Item -Recurse -Force $script:xroot -ErrorAction SilentlyContinue
            }
        }

        It "default -Execute SKIPs a cross-repo orphan (defense unchanged)" {
            $output = pwsh -NoProfile -File $script:cleanupScript -RepoRoot $script:repoA -Execute 2>&1 | Out-String
            $output | Should -Match "orphan"
            $output | Should -Match "SKIP: path outside repo root"
            $output | Should -Match "-AllowCrossRepo"

            # The orphan must remain untouched without explicit consent.
            $porcelain = git -C $script:repoA worktree list --porcelain -z 2>&1 | Out-String
            $porcelain | Should -Match "agent-xrepo"
            $porcelain | Should -Match "locked"
        }

        It "-AllowCrossRepo cleans the cross-repo orphan — no locked orphan remains" {
            $output = pwsh -NoProfile -File $script:cleanupScript -RepoRoot $script:repoA -Execute -AllowCrossRepo 2>&1 | Out-String
            $output | Should -Match "cross-repo orphan"
            $output | Should -Match "unlocked \+ removed \+ pruned"

            # Criterion #3345-6 for the incident class: registry entry gone,
            # physical tree gone, nothing locked left behind.
            $porcelain = git -C $script:repoA worktree list --porcelain -z 2>&1 | Out-String
            $porcelain | Should -Not -Match "agent-xrepo"
            $porcelain | Should -Not -Match "locked"
            (Test-Path $script:wtPath) | Should -Be $false
        }
    }

    Context "Windows path-normalization defect class (#3345 D1)" {

        # The reported #3345 refusal refused a worktree that resolved to
        # ITSELF: the harness held `d:\dev\...` (lowercase drive, backslashes)
        # while git returned `D:/dev/...` (canonical). Measured firsthand
        # (myia-po-2026, 2026-09-02, git 2.55.0.windows.4): git canonicalizes
        # the drive letter to uppercase and separators to `/` even when invoked
        # with the lowercase/backslash form. A strict string comparison on that
        # pair false-positives as "resolves outside the worktree".
        #
        # CI (unit-pester) runs on ubuntu where drive letters don't exist, so
        # this test skips there — it guards Windows dev machines, which is
        # where the defect lives.

        It "lowercase-drive/backslash path variant resolves to the same worktree — strict string comparison false-positives" -Skip:(-not $IsWindows) {
            $repo = New-TempRepo
            try {
                $wtPath = Join-Path $repo ".claude/worktrees/agent-case"
                New-Item -ItemType Directory -Path (Split-Path $wtPath -Parent) -Force | Out-Null
                git -C $repo worktree add $wtPath feature/test 2>&1 | Out-Null

                $canonical = (git -C $wtPath rev-parse --show-toplevel).Trim()

                # The form the #3345 harness held: lowercase drive + backslashes.
                $variant = $canonical.Substring(0, 1).ToLower() + $canonical.Substring(1) -replace '/', '\'

                # The variant IS the same location: git resolves it back to
                # the canonical form, and a read-only command anchors inside
                # the worktree (nothing writes outside it).
                $resolvedFromVariant = (git -C $variant rev-parse --show-toplevel).Trim()
                $resolvedFromVariant | Should -Be $canonical
                git -C $variant status --porcelain 2>&1 | Out-Null
                $LASTEXITCODE | Should -Be 0

                # The exact false-positive class of the #3345 refusal: strict
                # (case-sensitive, separator-sensitive) string comparison of
                # the held form vs git's canonical output FAILS even though
                # both denote the same worktree.
                ($variant -ceq $resolvedFromVariant) | Should -Be $false

                # The comparison the upstream validator should perform on
                # win32: fold separators and case (Windows filesystems are
                # case-insensitive).
                $fold = { param($p) ($p -replace '\\', '/').TrimEnd('/').ToLowerInvariant() }
                (& $fold $variant) | Should -Be (& $fold $resolvedFromVariant)
            } finally {
                Remove-TempRepo -Path $repo
            }
        }
    }

    Context "Upstream scope acknowledgement" {

        It "the actual harness validator lives in upstream Claude Code, not this repo" {
            # Static guard: ensures we don't accidentally regress by trying to
            # fix the upstream bug locally. The error message `Refusing to use
            # ... as an isolation worktree` must NOT appear in this repo's
            # production source. (The test file itself mentions it for context;
            # we exclude it from the scan. Investigation docs under
            # docs/harness/investigations/ quote the upstream message as
            # narrative evidence — they are artefacts, not production source.)
            $hits = Get-ChildItem -Path $script:projectRoot -Recurse -File -Include '*.ts','*.ps1','*.js','*.sh','*.md' |
                Where-Object {
                    $_.FullName -ne $PSCommandPath -and
                    $_.FullName -notmatch '[\\/]docs[\\/]harness[\\/]investigations[\\/]'
                } |
                Select-String -Pattern "Refusing to use" -List |
                Measure-Object
            $hits.Count | Should -Be 0
        }
    }
}
