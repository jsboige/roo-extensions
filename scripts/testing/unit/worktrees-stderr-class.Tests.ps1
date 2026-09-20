<#
.SYNOPSIS
    Drift-guard for the #3731 stderr class, lot 2 family `worktrees/*` in
    scripts/worktrees/ (create-worktree 8 sites, cleanup-worktree 14 sites,
    check-worktrees 1 site; submit-pr was covered separately in #3739).

    A PS-level `2>$null`/`2>&1` on a native still lets PS 5.1 mint ErrorRecords
    from stderr; under a file-global EAP=Stop the first one terminates the script
    on a call that succeeded. The sites now discard/merge stderr at the cmd.exe
    layer (`2>nul`/`2>&1` inside `& cmd /c "..."`): no ErrorRecord ever exists,
    under any EAP, and $LASTEXITCODE keeps propagating.

    Path-bearing arguments ($worktreePath, $targetPath) are quoted doubled inside
    the cmd string: the PS form passed them as argv entries (spaces safe), bare
    splicing into one command line breaks at the first space (measured under 5.1
    in #3740). Git refs and integers stay bare.
#>

Describe 'worktrees family stderr class, lot 2 (#3731)' {
    BeforeAll {
        $root = Join-Path $PSScriptRoot '..\..\..\scripts\worktrees'
        $script:files = @{
            create  = Join-Path $root 'create-worktree.ps1'
            cleanup = Join-Path $root 'cleanup-worktree.ps1'
            check   = Join-Path $root 'check-worktrees.ps1'
        }
        $script:src = @{}
        $script:parseErrors = 0
        foreach ($k in $script:files.Keys) {
            $p = $script:files[$k]
            $script:src[$k] = Get-Content $p -Raw
            $errors = $null
            [System.Management.Automation.Language.Parser]::ParseFile($p, [ref]$null, [ref]$errors)
            $script:parseErrors += @($errors).Count
        }
    }

    It 'all three scripts parse cleanly' {
        $script:parseErrors | Should -Be 0
    }

    It 'create-worktree reads repo root, issue title and branch list via cmd-layer discard' {
        $s = $script:src.create
        $s | Should -Match 'cmd /c "git rev-parse --show-toplevel 2>nul"'
        $s | Should -Match 'cmd /c "gh issue view \$IssueNumber --repo jsboige/roo-extensions --json title 2>nul"'
        $s | Should -Match 'cmd /c "git branch --list \$branchName 2>nul"'
        $s | Should -Not -Match 'git rev-parse --show-toplevel 2>\$null'
        $s | Should -Not -Match 'gh issue view \$IssueNumber --repo jsboige/roo-extensions --json title 2>\$null'
        $s | Should -Not -Match 'git branch --list \$branchName 2>\$null'
    }

    It 'create-worktree merges fetch/pull/branch/submodule stderr at the cmd layer' {
        $s = $script:src.create
        $s | Should -Match 'cmd /c "git fetch origin 2>&1"'
        $s | Should -Match 'cmd /c "git pull origin \$BaseBranch --ff-only 2>&1"'
        $s | Should -Match 'cmd /c "git branch \$branchName origin/\$BaseBranch 2>&1"'
        $s | Should -Match 'cmd /c "git submodule update --init --recursive 2>&1"'
        $s | Should -Not -Match 'git fetch origin 2>&1 \| Out-Null'
        $s | Should -Not -Match 'git submodule update --init --recursive 2>&1 \| Out-Null'
    }

    It 'create-worktree quotes the worktree path in the cmd string (spaces, #3740 lesson)' {
        $script:src.create | Should -Match 'cmd /c "git worktree add ""\$worktreePath"" \$branchName 2>&1"'
        $script:src.create | Should -Not -Match 'git worktree add \$worktreePath \$branchName 2>&1'
    }

    It 'cleanup-worktree converts all git reads to cmd-layer discard' {
        $s = $script:src.cleanup
        $s | Should -Match 'cmd /c "git rev-parse --show-toplevel 2>nul"'
        $s | Should -Match 'cmd /c "git worktree list --porcelain 2>nul"'
        $s | Should -Match 'cmd /c "git branch --list feature/\$IssueNumber-\* 2>nul"'
        $s | Should -Match 'cmd /c "git branch --merged main --list \$targetBranch 2>nul"'
        $s | Should -Match 'cmd /c "git worktree prune 2>nul"'
        $s | Should -Match 'cmd /c "git ls-remote --heads origin \$targetBranch 2>nul"'
        $s | Should -Not -Match 'git worktree list --porcelain 2>\$null'
        $s | Should -Not -Match 'git branch --merged main --list \$targetBranch 2>\$null'
        $s | Should -Not -Match 'git worktree prune 2>\$null'
        $s | Should -Not -Match 'git ls-remote --heads origin \$targetBranch 2>\$null'
    }

    It 'cleanup-worktree quotes the worktree path on removal and merges delete stderr at cmd layer' {
        $s = $script:src.cleanup
        $s | Should -Match 'cmd /c "git worktree remove ""\$targetPath"" --force 2>&1"'
        $s | Should -Match 'cmd /c "git worktree remove ""\$targetPath"" 2>&1"'
        $s | Should -Match 'cmd /c "git branch \$deleteFlag \$targetBranch 2>&1" \| Out-Null'
        $s | Should -Match 'cmd /c "git push origin --delete \$targetBranch 2>&1" \| Out-Null'
        $s | Should -Not -Match 'git worktree remove \$targetPath --force 2>&1'
        $s | Should -Not -Match 'git branch \$deleteFlag \$targetBranch 2>&1 \| Out-Null'
    }

    It 'check-worktrees reads the porcelain list via cmd-layer discard' {
        $s = $script:src.check
        $s | Should -Match 'cmd /c "git worktree list --porcelain 2>nul"'
        $s | Should -Not -Match 'git worktree list --porcelain 2>\$null'
    }
}
