<#
.SYNOPSIS
    Regression tests for post-run artifact reconciliation (#3560).

.DESCRIPTION
    The worker must preserve a failed stream verdict while reporting pull requests or
    remote branches that were independently verified after the run. The functional test
    executes only the extracted helper function with a mocked gh command; it never calls
    GitHub or mutates a repository.
#>

Describe 'Worker artifact reconciliation (#3560)' {
    BeforeAll {
        $scriptPath = Join-Path $PSScriptRoot '..\..\..\scripts\scheduling\start-claude-worker.ps1'
        $errors = $null
        $tokens = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($scriptPath, [ref]$tokens, [ref]$errors)
        $content = Get-Content $scriptPath -Raw

        $fn = $ast.FindAll({
            param($node)
            $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
                $node.Name -eq 'Get-DeliveredArtifacts'
        }, $true) | Select-Object -First 1

        if ($fn) {
            Invoke-Expression $fn.Extent.Text
        }

        function Write-Log { param($Message, $Level) }

        $script:observedSearches = @()
        $script:prListProvider = {
            param($repository, $searchQuery)
            $script:observedSearches += $searchQuery
            if ($repository -eq 'jsboige/roo-extensions') {
                return @(
                    [PSCustomObject]@{ number = 101; url = 'https://example.test/pr/101'; title = 'fix: reconcile worker result'; body = 'Relates to #3560'; headRefName = 'fix/3560'; createdAt = '2026-09-10T12:05:00Z'; author = [PSCustomObject]@{ login = 'worker-account' } },
                    [PSCustomObject]@{ number = 102; url = 'https://example.test/pr/102'; title = 'fix: unrelated #35601 result'; body = ''; headRefName = 'fix/35601'; createdAt = '2026-09-10T12:06:00Z'; author = [PSCustomObject]@{ login = 'worker-account' } },
                    [PSCustomObject]@{ number = 103; url = 'https://example.test/pr/103'; title = 'fix: foreign #3560 result'; body = ''; headRefName = 'fix/foreign'; createdAt = '2026-09-10T12:07:00Z'; author = [PSCustomObject]@{ login = 'other-account' } },
                    [PSCustomObject]@{ number = 99; url = 'https://example.test/pr/99'; title = 'fix: old #3560 result'; body = ''; headRefName = 'fix/old'; createdAt = '2026-09-10T10:00:00Z'; author = [PSCustomObject]@{ login = 'worker-account' } }
                )
            }
            return @()
        }
    }

    It 'parses the worker without syntax errors and defines the helper' {
        $errors.Count | Should -Be 0
        $fn | Should -Not -BeNullOrEmpty
    }

    It 'queries both repositories read-only with a numeric issue boundary' {
        $code = $fn.Extent.Text
        $code | Should -Match "jsboige/roo-extensions"
        $code | Should -Match "jsboige/jsboige-mcp-servers"
        $code | Should -Match "\(\[\^0-9\]\|\$\)"
        $code | Should -Match "gh pr list"
        $code | Should -Match "--search"
        $code | Should -Match "created:>="
        $code | Should -Match 'git -C \$WorktreePath config --get user\.name'
        $code | Should -Not -Match "gh api user"
        $code | Should -Not -Match "--limit 100(?!0)"
        $code | Should -Not -Match "gh pr (create|merge|close|edit|comment)"
        $code | Should -Not -Match "gh issue (edit|close|comment)"
    }

    It 'retains only a recent exact issue reference from the expected author' {
        try {
            $task = [PSCustomObject]@{ issueNumber = 3560 }
            $script:observedSearches = @()
            $artifacts = @(Get-DeliveredArtifacts -Task $task -RunStartUtc ([DateTime]'2026-09-10T12:00:00Z') -WorktreePath $null -PrListProvider $script:prListProvider -ExpectedAuthor 'worker-account')

            $artifacts.Count | Should -Be 1
            $artifacts[0].Type | Should -Be 'pull_request'
            $artifacts[0].Number | Should -Be 101
            $artifacts[0].Repository | Should -Be 'jsboige/roo-extensions'
            $script:observedSearches.Count | Should -Be 2
            $script:observedSearches[0] | Should -Match '#3560 in:title,body created:>=2026-09-10T12:00:00Z'
        }
        finally {
            $artifacts = $null
        }
    }

    It 'examines a valid artifact beyond the former 100-PR window' {
        $largeProvider = {
            param($repository, $searchQuery)
            if ($repository -ne 'jsboige/roo-extensions') { return @() }

            $rows = @(1..150 | ForEach-Object {
                [PSCustomObject]@{
                    number = $_
                    url = "https://example.test/pr/$_"
                    title = 'unrelated pull request'
                    body = ''
                    headRefName = "other/$_"
                    createdAt = '2026-09-10T12:01:00Z'
                    author = [PSCustomObject]@{ login = 'worker-account' }
                }
            })
            $rows += [PSCustomObject]@{
                number = 151
                url = 'https://example.test/pr/151'
                title = 'fix: delivered #3560 artifact'
                body = ''
                headRefName = 'fix/3560-late-in-list'
                createdAt = '2026-09-10T12:02:00Z'
                author = [PSCustomObject]@{ login = 'worker-account' }
            }
            return $rows
        }

        $task = [PSCustomObject]@{ issueNumber = 3560 }
        $artifacts = @(Get-DeliveredArtifacts -Task $task -RunStartUtc ([DateTime]'2026-09-10T12:00:00Z') -WorktreePath $null -PrListProvider $largeProvider -ExpectedAuthor 'worker-account')

        $artifacts.Count | Should -Be 1
        $artifacts[0].Number | Should -Be 151
    }

    It 'reconciles after PR creation and before both terminal outputs' {
        $prWorkflow = $content.IndexOf('$PrUrl = New-WorkerPR')
        $reconcile = $content.IndexOf('$DeliveredArtifacts = Get-DeliveredArtifacts')
        $report = $content.IndexOf('Report-Results -Task $Task -Result $Result')
        $verdict = $content.IndexOf('Mark-TaskAsComplete -Task $Task')

        $prWorkflow | Should -BeGreaterThan 0
        $reconcile | Should -BeGreaterThan $prWorkflow
        $report | Should -BeGreaterThan $reconcile
        $verdict | Should -BeGreaterThan $report
    }

    It 'does not convert an invalid stream into success' {
        $content | Should -Match '(?i)success = \$StreamValid -and'
        $content | Should -Match 'leaves Result\.success and the process exit code unchanged'
        $content | Should -Match 'if \(\$Result\.success\) \{\s*exit 0\s*\} else \{\s*exit 1'
        $content | Should -Match 'FAIL — run terminal en échec, mais artefacts livrés et vérifiés'
        $content | Should -Match 'ne pas redispatcher \(#3560\)'
        $content.IndexOf('if ($Success -and $PrUrl)') | Should -BeGreaterThan 0
        $content | Should -Not -Match 'if \(\$PrUrl\) \{\s*\$Body = "\[RESULT\].*PASS'
    }
}
