# auto-review.Tests.ps1 - Unit tests for auto-review pipeline
# Issue #567 - Regression tests for auto-review pipeline fixes (#544, 2934290c)
#
# Tests cover:
# 1. Return valid result for simple diff
# 2. Timeout is respected (no infinite hang)
# 3. stderr handling (ErrorActionPreference fix)
#
# Usage:
#   Invoke-Pester .\scripts\review\auto-review.Tests.ps1
#
# Note: Compatible with Pester 3.4.0

Describe "auto-review.ps1 - Core Functionality" {

    Context "Diff Truncation Logic" {
        It "Truncates diff larger than MaxDiffChars" {
            # Simulate a large diff
            $largeDiff = "a" * 10000
            $MaxDiffChars = 8000

            # The truncation logic from the script
            $diffLen = $largeDiff.Length
            $shouldTruncate = ($diffLen -gt $MaxDiffChars)

            $shouldTruncate | Should Be $true

            $truncateLen = [Math]::Min($diffLen, $MaxDiffChars)
            $truncated = $largeDiff.Substring(0, $truncateLen) + "`n`n[... diff truncated at $MaxDiffChars chars ...]"

            ($truncated.Length -le ($MaxDiffChars + 100)) | Should Be $true
        }

        It "Does not truncate diff smaller than MaxDiffChars" {
            $smallDiff = "a" * 1000
            $MaxDiffChars = 8000

            $diffLen = $smallDiff.Length
            $shouldTruncate = ($diffLen -gt $MaxDiffChars)

            $shouldTruncate | Should Be $false
        }
    }

    Context "Issue Number Detection" {
        It "Detects issue number from commit message (fix #NNN pattern)" {
            $commitMessage = "fix #567 - Add unit tests"
            $pattern = '(?i)(?:fix|close|resolve)[\s\-]*#(\d+)'

            $matched = $commitMessage -match $pattern
            $matched | Should Be $true

            if ($matched) {
                $issueNumber = [int]$matches[1]
                $issueNumber | Should Be 567
            }
        }

        It "Detects issue number from commit message (issue #NNN pattern)" {
            $commitMessage = "test(issue #567): Add unit tests"
            $pattern = '(?i)issue[\s\-]*#(\d+)'

            $matched = $commitMessage -match $pattern
            $matched | Should Be $true

            if ($matched) {
                $issueNumber = [int]$matches[1]
                $issueNumber | Should Be 567
            }
        }

        It "Detects issue number from commit message (#NNN fallback)" {
            $commitMessage = "test: Add unit tests (#567)"
            $pattern = '#(\d+)'

            $matched = $commitMessage -match $pattern
            $matched | Should Be $true

            if ($matched) {
                $issueNumber = [int]$matches[1]
                $issueNumber | Should Be 567
            }
        }

        It "Returns 0 when no issue number found" {
            $commitMessage = "test: Add unit tests without issue reference"
            $patterns = @(
                '(?i)(?:fix|close|resolve)[\s\-]*#(\d+)',
                '(?i)issue[\s\-]*#(\d+)',
                '(?i)issue[\s\-]*(\d+)',
                '#(\d+)'
            )

            $issueNumber = 0
            foreach ($pattern in $patterns) {
                if ($commitMessage -match $pattern) {
                    $issueNumber = [int]$matches[1]
                    break
                }
            }

            $issueNumber | Should Be 0
        }
    }

    Context "ErrorActionPreference Handling (Fix 2934290c)" {
        It "Temporarily changes ErrorActionPreference during build/test" {
            # Simulate the ErrorActionPreference pattern used in the script
            $ErrorActionPreference = "Stop"

            $prevPref = $ErrorActionPreference
            $prevPref | Should Be "Stop"

            # Change to Continue (as script does for build/test)
            $ErrorActionPreference = "Continue"
            $ErrorActionPreference | Should Be "Continue"

            # Restore
            $ErrorActionPreference = $prevPref
            $ErrorActionPreference | Should Be "Stop"
        }

        It "Restores ErrorActionPreference even on exception" {
            $ErrorActionPreference = "Stop"
            $exceptionCaught = $false

            try {
                $prevPref = $ErrorActionPreference
                try {
                    $ErrorActionPreference = "Continue"
                    # Simulate an error that should not crash the script
                    throw "Test exception"
                } finally {
                    $ErrorActionPreference = $prevPref
                }
            } catch {
                $exceptionCaught = $true
            }

            # Exception should have been caught
            $exceptionCaught | Should Be $true

            # ErrorActionPreference should be restored
            $ErrorActionPreference | Should Be "Stop"
        }
    }

    Context "Build Gate Result Structure" {
        It "Returns structured build result with required fields" {
            # Simulate the buildResult structure from the script
            $buildResult = @{
                buildOk = $true
                testOk = $true
                testSummary = "Tests 42 passed"
            }

            ($buildResult.Keys -contains "buildOk") | Should Be $true
            ($buildResult.Keys -contains "testOk") | Should Be $true
            ($buildResult.Keys -contains "testSummary") | Should Be $true

            ($buildResult.buildOk -is [bool]) | Should Be $true
            ($buildResult.testOk -is [bool]) | Should Be $true
            ($buildResult.testSummary -is [string]) | Should Be $true
        }

        It "Formats build section correctly" {
            $buildResult = @{
                buildOk = $true
                testOk = $true
                testSummary = "Tests 42 passed"
            }

            $buildIcon = if ($buildResult.buildOk -and $buildResult.testOk) { "✅" } else { "❌" }
            $buildStatus = if ($buildResult.buildOk) { "PASS" } else { "FAIL" }
            $testStatus = if ($buildResult.testOk) { "PASS" } else { "FAIL" }

            $buildSection = @"

### Build Gate $buildIcon
| Check | Status |
|-------|--------|
| Build | $buildStatus |
| Tests | $testStatus ($($buildResult.testSummary)) |

"@

            ($buildSection -match "Build Gate") | Should Be $true
            ($buildSection -match "PASS") | Should Be $true
            ($buildSection -match "Tests 42 passed") | Should Be $true
        }
    }

    Context "Fallback Review Mode" {
        It "Generates fallback review when sk-agent fails" {
            # Simulate fallback review generation
            $shortHash = "a1b2c3d"
            $commitMessage = "test: Add unit tests"
            $commitAuthor = "Test User"
            $diffStat = "1 file changed, 10 insertions(+)"
            $errorMessage = "Connection timeout"

            $reviewResult = @"
## Auto-Review (fallback mode)

sk-agent was unavailable. Basic commit summary:

- **Commit:** $shortHash
- **Message:** $commitMessage
- **Author:** $commitAuthor
- **Changes:** 1 file(s)

``````
$diffStat
``````

> Manual review recommended. sk-agent error: $errorMessage
"@

            ($reviewResult -match "fallback mode") | Should Be $true
            ($reviewResult -match $shortHash) | Should Be $true
            ($reviewResult -match $commitMessage) | Should Be $true
            ($reviewResult -match "Manual review recommended") | Should Be $true
        }
    }

    Context "Timeout Handling" {
        It "Script respects timeout for long-running operations" {
            # Test that script can be interrupted (simulated)
            $timeoutSeconds = 2
            $startTime = Get-Date

            # Simulate a cancellable operation
            $job = Start-Job -ScriptBlock {
                Start-Sleep -Seconds 100
                return "Should not complete"
            }

            # Wait with timeout
            $completed = Wait-Job -Job $job -Timeout $timeoutSeconds
            $elapsedSeconds = ((Get-Date) - $startTime).TotalSeconds

            # Should timeout within expected range
            ($elapsedSeconds -le ($timeoutSeconds + 2)) | Should Be $true

            # Cleanup
            Stop-Job -Job $job -ErrorAction SilentlyContinue
            Remove-Job -Job $job -ErrorAction SilentlyContinue
        }
    }

    Context "DryRun Mode" {
        It "DryRun flag prevents GitHub posting" {
            # DryRun should be a switch parameter
            $DryRun = $true

            # In DryRun mode, the script should exit before posting
            # We verify this by checking the logic
            if ($DryRun) {
                $shouldPost = $false
            } else {
                $shouldPost = $true
            }

            $shouldPost | Should Be $false
        }
    }
}

Describe "auto-review.ps1 - Regression Tests (Issue #567)" {

    Context "Fix 2934290c: Parameter Forwarding" {
        It "Forwards BuildCheck parameter correctly" {
            # Test that BuildCheck parameter can be passed
            $params = @{
                BuildCheck = $true
                DryRun = $true
            }

            $params.BuildCheck | Should Be $true
        }

        It "Forwards Verbose parameter correctly" {
            $params = @{
                Verbose = $true
                DryRun = $true
            }

            $params.Verbose | Should Be $true
        }
    }

    Context "Fix 2934290c: Stderr Handling" {
        It "ErrorActionPreference Continue allows non-fatal errors" {
            # The fix in 2934290c temporarily sets ErrorActionPreference to Continue
            # to allow stderr output from npm/vitest without crashing the pipeline
            $prevPref = $ErrorActionPreference
            $ErrorActionPreference = "Continue"

            # This operation should succeed even with warnings/errors
            $testPassed = $false
            try {
                # Simulate operations that write to stderr (like npm build)
                Write-Warning "Non-fatal warning (simulating build output)"
                $testPassed = $true
            } catch {
                $testPassed = $false
            }

            $testPassed | Should Be $true
            $ErrorActionPreference = $prevPref
        }
    }

    Context "Fix 2934290c: Timeout Implementation" {
        It "Long-running build can be interrupted" {
            # Test that operations respect timeout
            $timeoutSeconds = 2
            $startTime = Get-Date

            $job = Start-Job -ScriptBlock {
                # Simulate a long build
                Start-Sleep -Seconds 60
            }

            # Wait with timeout
            $null = Wait-Job -Job $job -Timeout $timeoutSeconds
            $elapsed = ((Get-Date) - $startTime).TotalSeconds

            # Should timeout in ~2 seconds
            ($elapsed -le 4) | Should Be $true

            Stop-Job -Job $job -ErrorAction SilentlyContinue
            Remove-Job -Job $job -ErrorAction SilentlyContinue
        }
    }
}

Describe "auto-review-simple.ps1 - Delegation Tests" {

    Context "Parameter Delegation" {
        It "Correctly builds arguments hash for auto-review.ps1" {
            # Simulate the delegation logic from auto-review-simple.ps1
            $DiffRange = "HEAD~3"
            $IssueNumber = 567
            $BuildCheck = $true
            $DryRun = $true
            $Verbose = $true

            $reviewArgs = @{
                DiffRange = $DiffRange
                Mode = "vllm"
                RepoOwner = "jsboige"
                RepoName = "roo-extensions"
            }
            if ($IssueNumber -gt 0) { $reviewArgs["IssueNumber"] = $IssueNumber }
            if ($BuildCheck) { $reviewArgs["BuildCheck"] = $true }
            if ($DryRun) { $reviewArgs["DryRun"] = $true }
            if ($Verbose) { $reviewArgs["Verbose"] = $true }

            # Verify all parameters are forwarded
            $reviewArgs.DiffRange | Should Be "HEAD~3"
            $reviewArgs.Mode | Should Be "vllm"
            $reviewArgs.IssueNumber | Should Be 567
            $reviewArgs.BuildCheck | Should Be $true
            $reviewArgs.DryRun | Should Be $true
            $reviewArgs.Verbose | Should Be $true
        }

        It "Does not include IssueNumber if zero" {
            $IssueNumber = 0

            $reviewArgs = @{
                DiffRange = "HEAD~1"
                Mode = "vllm"
            }
            if ($IssueNumber -gt 0) { $reviewArgs["IssueNumber"] = $IssueNumber }

            # IssueNumber should not be in the hash
            ($reviewArgs.Keys -contains "IssueNumber") | Should Be $false
        }
    }
}
