# Unit tests - a success the worker could not reconcile is never "no code changes needed" (#3560)
#
# Run of 2026-11-01 (#2609, myia-ai-01): the agent opened and merged its own PRs, then
# de-registered its own worktree. The folder stayed, so `git -C <worktree>` climbed to the
# main checkout and answered in its name: no artifact was reconciled, the ghost-hash check
# flagged a real submodule commit, and the issue received
# "[RESULT] ...: PASS - completed (no code changes needed)".
#
# Behavioural tests: Test-WorktreeUsable runs against real temporary git repositories, and
# the [RESULT] verdict chain of Mark-TaskAsComplete is extracted by AST and executed with
# stubbed inputs (no GitHub call, no repository mutation outside TestDrive).
#
# Positive control: dropping either new branch of the verdict chain, or comparing the
# toplevel loosely, must turn tests of this file red - checked by mutation on the PR branch.
#
# Usage:
#   pwsh -NoProfile -Command "Invoke-Pester -Path ./scripts/testing/unit/worker-unreconciled-verdict.Tests.ps1 -Output Detailed"

BeforeAll {
    $script:workerScript = (Resolve-Path -Path "$PSScriptRoot/../../scheduling/start-claude-worker.ps1").Path
    $tokens = $null
    $script:parseErrors = $null
    $script:ast = [System.Management.Automation.Language.Parser]::ParseFile($script:workerScript, [ref]$tokens, [ref]$script:parseErrors)
    $script:content = Get-Content $script:workerScript -Raw

    $script:fnUsable = $script:ast.FindAll({
        param($node)
        $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'Test-WorktreeUsable'
    }, $true) | Select-Object -First 1
    if ($script:fnUsable) { Invoke-Expression $script:fnUsable.Extent.Text }

    $script:fnMark = $script:ast.FindAll({
        param($node)
        $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'Mark-TaskAsComplete'
    }, $true) | Select-Object -First 1

    $script:fnReport = $script:ast.FindAll({
        param($node)
        $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'Report-Results'
    }, $true) | Select-Object -First 1

    # The [RESULT] verdict chain: the if-statement whose first condition is `$Success -and $PrUrl`.
    $script:verdictIf = $null
    if ($script:fnMark) {
        $script:verdictIf = $script:fnMark.FindAll({
            param($node)
            $node -is [System.Management.Automation.Language.IfStatementAst] -and
                $node.Clauses[0].Item1.Extent.Text -eq '$Success -and $PrUrl'
        }, $true) | Select-Object -First 1
    }

    # The worker calls git through `& cmd /c "..."` (#3731). The CI runner is Linux, where
    # cmd.exe does not exist: replay the same command string through sh there, so the
    # behavioural tests below exercise the real function on both platforms.
    if ([IO.Path]::DirectorySeparatorChar -ne '\') {
        function cmd {
            param([string]$Flag, [string]$Line)
            sh -c (($Line -replace '""', '"') -replace '2>nul', '2>/dev/null')
        }
    }

    function Get-Sha8([string]$Sha) { if ($Sha) { $Sha.Substring(0, [Math]::Min(8, $Sha.Length)) } else { '' } }

    # Runs the extracted chain with the given inputs and returns what it decided.
    function Invoke-Verdict {
        param(
            [bool]$Success,
            [string]$PrUrl = $null,
            [array]$DeliveredArtifacts = @(),
            [bool]$DeliveryReconciled = $true,
            [array]$Rescued = @(),
            $PhantomRefused = $null
        )
        $MachineId = 'myia-test:roo-extensions'
        $HoldLock = $false
        $Body = $null
        $script:PhantomRescueRefused = $PhantomRefused
        $script:RescuedSubmoduleBranches = $Rescued
        . ([scriptblock]::Create($script:verdictIf.Extent.Text))
        [PSCustomObject]@{ Body = $Body; HoldLock = $HoldLock }
    }

    function New-TestRepo([string]$Path) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
        git -C $Path init -q 2>$null | Out-Null
        git -C $Path -c user.name=t -c user.email=t@example.test commit -q --allow-empty -m init 2>$null | Out-Null
    }

    $script:prArtifact = [PSCustomObject]@{
        Type = 'pull_request'; Repository = 'jsboige/jsboige-mcp-servers'; Number = 1613
        Url = 'https://example.test/pull/1613'; Ref = 'fix/2609'; Commit = $null
    }
    $script:branchArtifact = [PSCustomObject]@{
        Type = 'remote_branch'; Repository = 'jsboige/roo-extensions'; Number = $null
        Url = $null; Ref = 'wt/fix-2609'; Commit = '32a66000aaaabbbbccccddddeeeeffff00001111'
    }
}

Describe "Worker - an unreconciled success is not 'no code changes needed' (#3560)" {

    Context "Extraction" {

        It "parses the worker without syntax errors" {
            $script:parseErrors.Count | Should -Be 0
        }

        It "defines Test-WorktreeUsable and the verdict chain of Mark-TaskAsComplete" {
            $script:fnUsable | Should -Not -BeNullOrEmpty
            $script:verdictIf | Should -Not -BeNullOrEmpty
        }
    }

    Context "Test-WorktreeUsable measures the worktree, not whatever git climbs to" {

        BeforeAll {
            $script:repo = Join-Path $TestDrive 'main'
            New-TestRepo -Path $script:repo
            $script:wt = Join-Path $script:repo '.wt/wt-x'
            git -C $script:repo worktree add -q -b wt/x $script:wt 2>$null | Out-Null
        }

        It "accepts the root of a repository" {
            Test-WorktreeUsable -WorktreePath $script:repo | Should -Be $true
        }

        It "accepts a registered linked worktree" {
            Test-WorktreeUsable -WorktreePath $script:wt | Should -Be $true
        }

        It "accepts the path with a trailing separator" {
            Test-WorktreeUsable -WorktreePath ($script:repo + '/') | Should -Be $true
        }

        # Windows only: on Linux a backslash is a file-name character, not a separator.
        It "accepts the backslash spelling of a path git prints with forward slashes" -Skip:([IO.Path]::DirectorySeparatorChar -ne '\') {
            Test-WorktreeUsable -WorktreePath ($script:wt -replace '/', '\') | Should -Be $true
        }

        # Windows only: a trailing backslash would close the cmd string as `\"` (escaped quote).
        It "accepts a trailing backslash, which cmd would otherwise read as an escaped quote" -Skip:([IO.Path]::DirectorySeparatorChar -ne '\') {
            Test-WorktreeUsable -WorktreePath (($script:wt -replace '/', '\') + '\') | Should -Be $true
        }

        It "rejects a plain sub-directory: git answers for the enclosing repository" {
            $sub = Join-Path $script:repo 'sub'
            New-Item -ItemType Directory -Path $sub -Force | Out-Null
            Test-WorktreeUsable -WorktreePath $sub | Should -Be $false
        }

        It "rejects a worktree folder left behind after de-registration (the #2609 run)" {
            $gone = Join-Path $script:repo '.wt/wt-gone'
            git -C $script:repo worktree add -q -b wt/gone $gone 2>$null | Out-Null
            Test-WorktreeUsable -WorktreePath $gone | Should -Be $true
            git -C $script:repo worktree remove --force $gone 2>$null | Out-Null
            New-Item -ItemType Directory -Path $gone -Force | Out-Null
            # Same folder, no .git file any more: git climbs to the main checkout.
            (git -C $gone rev-parse --show-toplevel) | Should -Not -BeNullOrEmpty
            Test-WorktreeUsable -WorktreePath $gone | Should -Be $false
        }

        It "rejects a worktree whose administrative entry was pruned" {
            $pruned = Join-Path $script:repo '.wt/wt-pruned'
            git -C $script:repo worktree add -q -b wt/pruned $pruned 2>$null | Out-Null
            Remove-Item -LiteralPath (Join-Path $script:repo '.git/worktrees/wt-pruned') -Recurse -Force
            Test-WorktreeUsable -WorktreePath $pruned | Should -Be $false
        }

        It "rejects a missing path, an empty path and a null path" {
            Test-WorktreeUsable -WorktreePath (Join-Path $TestDrive 'nope') | Should -Be $false
            Test-WorktreeUsable -WorktreePath '' | Should -Be $false
            Test-WorktreeUsable -WorktreePath $null | Should -Be $false
        }
    }

    Context "The [RESULT] verdict chain" {

        It "reports reconciled PRs as delivered when the agent opened them itself" {
            $v = Invoke-Verdict -Success $true -DeliveredArtifacts @($script:prArtifact)
            $v.Body | Should -Match 'PASS . delivered: PR #1613 https://example\.test/pull/1613'
            $v.Body | Should -Not -Match 'no code changes'
            $v.HoldLock | Should -Be $false
        }

        It "reports a reconciled remote branch as delivered" {
            $v = Invoke-Verdict -Success $true -DeliveredArtifacts @($script:branchArtifact)
            $v.Body | Should -Match 'delivered: remote branch wt/fix-2609'
            $v.Body | Should -Not -Match 'no code changes'
        }

        It "says the delivery was NOT reconciled when the worktree was gone (the #2609 run)" {
            $v = Invoke-Verdict -Success $true -DeliveryReconciled $false
            $v.Body | Should -Match 'delivery NOT reconciled'
            $v.Body | Should -Not -Match 'no code changes needed'
        }

        It "prefers reconciled artifacts over the unreconciled note" {
            $v = Invoke-Verdict -Success $true -DeliveryReconciled $false -DeliveredArtifacts @($script:prArtifact)
            $v.Body | Should -Match 'delivered: PR #1613'
        }

        It "keeps 'no code changes needed' for a measured success without artifacts" {
            $v = Invoke-Verdict -Success $true -DeliveryReconciled $true
            $v.Body | Should -Match 'PASS . completed \(no code changes needed\)'
        }

        It "keeps 'PR created' first when the worker opened the PR" {
            $v = Invoke-Verdict -Success $true -PrUrl 'https://example.test/pull/7' -DeliveredArtifacts @($script:prArtifact)
            $v.Body | Should -Match 'PASS . PR created: https://example\.test/pull/7'
        }

        It "keeps the held rescue verdict ahead of the delivered verdict" {
            $rescue = [PSCustomObject]@{ Branch = 'worker-rescue/x'; Commit = '0123456789abcdef0123456789abcdef01234567'; Path = 'mcps/internal' }
            $v = Invoke-Verdict -Success $true -DeliveredArtifacts @($script:prArtifact) -Rescued @($rescue)
            $v.Body | Should -Match 'PRESERVED on a rescue branch'
            $v.HoldLock | Should -Be $true
        }

        It "keeps the FAIL-with-artifacts verdict for a failed run" {
            $v = Invoke-Verdict -Success $false -DeliveredArtifacts @($script:prArtifact)
            $v.Body | Should -Match 'FAIL . run terminal'
            $v.Body | Should -Match 'PR #1613'
            $v.HoldLock | Should -Be $true
        }

        It "keeps the plain FAIL verdict for a failed run without artifacts" {
            $v = Invoke-Verdict -Success $false -DeliveryReconciled $false
            $v.Body | Should -Match 'FAIL . no actionable result produced'
        }
    }

    Context "Wiring" {

        It "declares DeliveryReconciled with a true default (other callers keep today's verdicts)" {
            $script:fnMark.Extent.Text | Should -Match '\[bool\]\$DeliveryReconciled = \$true'
        }

        It "feeds DeliveryReconciled from Test-WorktreeUsable at the call site" {
            $script:content | Should -Match 'Mark-TaskAsComplete -Task \$Task .*-DeliveryReconciled \(Test-WorktreeUsable -WorktreePath \$WorktreePath\)'
        }

        It "gates the real-hash read and the ghost check on Test-WorktreeUsable, not Test-Path" {
            $report = $script:fnReport.Extent.Text
            $report | Should -Match '\$WorktreeUsable = Test-WorktreeUsable -WorktreePath \$WorktreePath'
            $report | Should -Match '\$RealHashes = if \(\$WorktreeUsable\)'
            $report | Should -Not -Match 'Test-Path \$WorktreePath\)\) \{\s*Get-RealCommitHashes'
        }

        It "says in the report that the ghost check was skipped, instead of staying silent" {
            $script:fnReport.Extent.Text | Should -Match 'Ghost-hash check skipped'
        }
    }
}
