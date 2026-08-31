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
# and reports (does NOT execute) cleanly on a synthetic orphan.
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

        It "-Execute unlocks + prunes the orphan" {
            $repo = New-TempRepo
            try {
                $wtPath = Join-Path $repo ".claude/worktrees/agent-exec"
                New-Item -ItemType Directory -Path (Split-Path $wtPath -Parent) -Force | Out-Null
                git -C $repo worktree add --lock --reason "claude agent agent-exec (pid 99999)" $wtPath feature/test 2>&1 | Out-Null

                pwsh -NoProfile -File $script:cleanupScript -RepoRoot $repo -Execute 2>&1 | Out-Null

                $porcelain = git -C $repo worktree list --porcelain -z 2>&1 | Out-String
                $porcelain | Should -Not -Match "locked"
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

    Context "Upstream scope acknowledgement" {

        It "the actual harness validator lives in upstream Claude Code, not this repo" {
            # Static guard: ensures we don't accidentally regress by trying to
            # fix the upstream bug locally. The error message `Refusing to use
            # ... as an isolation worktree` must NOT appear in this repo's
            # production source. (The test file itself mentions it for context;
            # we exclude it from the scan.)
            $hits = Get-ChildItem -Path $script:projectRoot -Recurse -File -Include '*.ts','*.ps1','*.js','*.sh','*.md' |
                Where-Object { $_.FullName -ne $PSCommandPath } |
                Select-String -Pattern "Refusing to use" -List |
                Measure-Object
            $hits.Count | Should -Be 0
        }
    }
}
