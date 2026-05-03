# Tests unitaires pour les fixes anti-worktree-husk du worker script (#1913)
# Fixes B/C/D/E: defensive cleanup, staleness guard, retry-on-lock
# Syntaxe Pester v3 (Windows PowerShell 5.1)
#
# Usage: Invoke-Pester .\scripts\testing\unit\worktree-husk-prevention.Tests.ps1

Describe "Worktree Husk Prevention - #1913 Fixes B/C/D/E" {

    $projectRoot = (Resolve-Path -Path "$PSScriptRoot\..\..\..").Path
    $workerScript = Join-Path $projectRoot "scripts\scheduling\start-claude-worker.ps1"
    $content = Get-Content $workerScript -Raw

    # ---------------------------------------------------------------------------
    # Fix A/B: cleanup scripts exist
    # ---------------------------------------------------------------------------

    Context "Fix A/B - Cleanup scripts availability" {

        It "cleanup-orphan-worktrees.ps1 must exist" {
            $cleanupScript = Join-Path $projectRoot "scripts\maintenance\cleanup-orphan-worktrees.ps1"
            Test-Path $cleanupScript | Should Be $true
        }

        It "install-worktree-cleanup-schtask.ps1 must exist" {
            $installScript = Join-Path $projectRoot "scripts\maintenance\install-worktree-cleanup-schtask.ps1"
            Test-Path $installScript | Should Be $true
        }
    }

    # ---------------------------------------------------------------------------
    # Fix C: Staleness guard — refuse auto-commit if >50 commits behind
    # ---------------------------------------------------------------------------

    Context "Fix C - Staleness guard (#1913)" {

        It "Must contain staleness guard marker" {
            ($content -match 'Guard #1913: Staleness check') | Should Be $true
        }

        It "Must fetch origin/main before comparing" {
            ($content -match 'git fetch origin main') | Should Be $true
        }

        It "Must use rev-list to count commits behind" {
            ($content -match 'rev-list HEAD\.\.origin/main --count') | Should Be $true
        }

        It "Must threshold at 50 commits behind" {
            ($content -match '\$BehindCount.*-gt 50') | Should Be $true
        }

        It "Must refuse auto-commit with descriptive message" {
            ($content -match 'REFUSED auto-commit') | Should Be $true
        }

        It "Must reference #1913 in refusal message" {
            ($content -match 'REFUSED auto-commit.*#1913') | Should Be $true
        }

        It "Staleness check must be non-fatal on failure" {
            # Look for try/catch around the staleness guard (need larger window)
            $guardPos = $content.IndexOf('Guard #1913: Staleness check')
            $afterGuard = $content.Substring($guardPos, 800)
            ($afterGuard -match 'catch') | Should Be $true
        }

        It "Must validate BehindCount is numeric before comparison" {
            ($content -match 'BehindCount -match') | Should Be $true
        }
    }

    # ---------------------------------------------------------------------------
    # Fix D: Defensive cleanup at startup
    # ---------------------------------------------------------------------------

    Context "Fix D - Defensive cleanup at startup (#1913)" {

        It "Must reference cleanup-orphan-worktrees.ps1 at startup" {
            ($content -match 'cleanup-orphan-worktrees\.ps1') | Should Be $true
        }

        It "Must use -Execute flag for cleanup" {
            ($content -match 'CleanupScript.*-Execute') | Should Be $true
        }

        It "Must use -DaysThreshold 2 for startup cleanup" {
            ($content -match '-DaysThreshold 2') | Should Be $true
        }

        It "Must run cleanup silently (non-fatal on failure)" {
            ($content -match 'Defensive cleanup failed \(non-fatal\)') | Should Be $true
        }

        It "Must reference #1913 D in pre-flight section" {
            ($content -match 'crashed runs.*#1913 D') | Should Be $true
        }

        It "Cleanup must run before main worker loop" {
            $cleanupPos = $content.IndexOf('Defensive cleanup of orphan worktrees')
            $watchdogPos = $content.IndexOf('Test-WatchdogTimeout')
            $cleanupPos | Should BeGreaterThan 0
            $watchdogPos | Should BeGreaterThan 0
            $watchdogPos | Should BeGreaterThan $cleanupPos
        }
    }

    # ---------------------------------------------------------------------------
    # Fix E: Retry-on-lock in Remove-Worktree
    # ---------------------------------------------------------------------------

    Context "Fix E - Retry-on-lock in Remove-Worktree (#1913)" {

        It "Must contain retry marker" {
            ($content -match '#1913 Fix E') | Should Be $true
        }

        It "Must retry 3 times before giving up" {
            ($content -match 'MaxRetries = 3') | Should Be $true
        }

        It "Must use 5 second backoff delay" {
            ($content -match 'RetryDelaySec = 5') | Should Be $true
        }

        It "Must attempt git worktree remove --force" {
            ($content -match 'git.*worktree remove.*--force') | Should Be $true
        }

        It "Must fall back to git worktree prune on failure" {
            ($content -match 'git.*worktree prune') | Should Be $true
        }

        It "Must log retry attempts" {
            ($content -match 'retrying in.*RetryDelaySec') | Should Be $true
        }

        It "Must log when all retries exhausted" {
            ($content -match 'all retries exhausted') | Should Be $true
        }

        It "Remove-Worktree function must exist" {
            ($content -match 'function Remove-Worktree') | Should Be $true
        }

        It "Must track removal success with a flag" {
            ($content -match '\$Removed = \$false') | Should Be $true
            ($content -match '\$Removed = \$true') | Should Be $true
        }
    }

    # ---------------------------------------------------------------------------
    # Guard interaction - existing guards preserved
    # ---------------------------------------------------------------------------

    Context "Guard interaction - existing guards still present after #1913" {

        It "Guard #1156 (phantom auto-commits) still present" {
            ($content -match 'PHANTOM PR BLOCKED \(#1156\)') | Should Be $true
        }

        It "Guard #1156 v2 (phantom submodule) still present" {
            ($content -match 'PHANTOM PR BLOCKED \(#1156 v2\)') | Should Be $true
        }

        It "Guard #1404 (empty diff) still present" {
            ($content -match 'EMPTY PR BLOCKED \(#1404\)') | Should Be $true
        }

        It "Guard #1949 (trivial PR) still present" {
            ($content -match 'TRIVIAL PR BLOCKED \(#1949\)') | Should Be $true
        }

        It "Staleness guard is separate from PR guards (auto-commit vs PR creation)" {
            # Staleness guard is in auto-commit section, PR guards are in PR creation section
            $stalenessPos = $content.IndexOf('Guard #1913: Staleness check')
            $stalenessPos | Should BeGreaterThan 0
        }

        It "Trivial PR guard is present and distinct from staleness guard" {
            $stalenessPos = $content.IndexOf('Guard #1913: Staleness check')
            $trivialPos = $content.IndexOf('TRIVIAL PR BLOCKED (#1949)')
            $stalenessPos | Should BeGreaterThan 0
            $trivialPos | Should BeGreaterThan 0
            ($stalenessPos -ne $trivialPos) | Should Be $true
        }
    }
}
