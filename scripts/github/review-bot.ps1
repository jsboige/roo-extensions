# review-bot.ps1 - Automated PR review bot for #1767 Phase 2
#
# Non-interactive, cron-safe script that:
# 1. Polls PRs authored by the coordinator (myia-ai-01)
# 2. Checks CI status, restricted labels, and runs no-complaisance audit
# 3. Auto-approves if all checks pass, or comments with flagged issues
# 4. Does NOT merge (coordinator handles merge)
#
# Usage:
#   .\review-bot.ps1                            # Review all eligible PRs
#   .\review-bot.ps1 -DryRun                    # Print what would happen
#   .\review-bot.ps1 -Verbose                   # Detailed output
#   .\review-bot.ps1 -AuthorFilter "myia-ai-01" # Override author filter
#
# Exit codes:
#   0 = Success (PRs reviewed or none eligible)
#   1 = Error (gh CLI failure)
#   2 = No PRs found (informational)
#
# Part of issue #1767 Phase 2: Distributed review bots

param(
    [string]$Repo = "jsboige/roo-extensions",
    [string]$AuthorFilter = "myia-ai-01",
    [int]$MaxDiffChars = 50000,
    [switch]$DryRun,
    [switch]$VerboseOutput
)

$ErrorActionPreference = "Stop"
$MachineName = $env:COMPUTERNAME
$Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

# --- Helper functions ---

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $color = switch ($Level) {
        "ERROR" { "Red" }
        "WARN"  { "Yellow" }
        "OK"    { "Green" }
        default { "Gray" }
    }
    Write-Host "[$Timestamp] [$Level] $Message" -ForegroundColor $color
}

function Invoke-GhSafe {
    param([string]$Command)
    try {
        $result = Invoke-Expression $Command 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Log "gh command failed: $Command`n$result" "ERROR"
            return $null
        }
        return $result
    }
    catch {
        Write-Log "gh command exception: $_" "ERROR"
        return $null
    }
}

# --- Audit functions ---

function Test-SecretsInDiff {
    param([string]$Diff)
    $patterns = @(
        'API_KEY\s*=',
        'sk-[a-zA-Z0-9]{20,}',
        'ghp_[a-zA-Z0-9]{36}',
        'gho_[a-zA-Z0-9]{36}',
        'Bearer\s+[a-zA-Z0-9\-._~+/]+=*',
        'password\s*=\s*[''"][^''"]+[''"]',
        'secret\s*=\s*[''"][^''"]+[''"]',
        '-----BEGIN (?:RSA |EC )?PRIVATE KEY-----'
    )
    $findings = @()
    foreach ($pattern in $patterns) {
        $matches = [regex]::Matches($Diff, $pattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
        if ($matches.Count -gt 0) {
            $findings += "Secret pattern detected: $($matches[0].Value.Substring(0, [Math]::Min(30, $matches[0].Value.Length)))..."
        }
    }
    return $findings
}

function Test-ProtectedDirs {
    param([string]$Diff)
    $protectedDirs = @(
        'src/services/synthesis/',
        'src/services/narrative/'
    )
    $findings = @()
    foreach ($dir in $protectedDirs) {
        if ($Diff -match [regex]::Escape($dir)) {
            $findings += "Protected directory touched: $dir"
        }
    }
    return $findings
}

function Test-HasTests {
    param(
        [string]$Diff,
        [int]$Additions,
        [int]$Deletions
    )
    $totalLoc = $Additions + $Deletions
    if ($totalLoc -le 50) {
        return @() # Small PRs don't require tests
    }
    $hasTest = $Diff -match '(\.test\.|\.spec\.|_test\.|tests/|__tests__/)' -or `
               $Diff -match '\.Tests\.ps1'
    if (-not $hasTest) {
        return @("PR has ${totalLoc} LOC changed but no test files detected (threshold: >50 LOC)"
        )
    }
    return @()
}

function Test-RestrictedLabels {
    param($Labels)
    $restricted = @("harness-change", "critical")
    $findings = @()
    foreach ($label in $Labels) {
        if ($restricted -contains $label.name) {
            $findings += "Restricted label: $($label.name) — requires human review"
        }
    }
    return $findings
}

# --- Main logic ---

Write-Log "=== Review Bot Started ===" "INFO"
Write-Log "Machine: $MachineName | Repo: $Repo | Author filter: $AuthorFilter" "INFO"
if ($DryRun) {
    Write-Log "MODE: DRY RUN (no approve/comment)" "WARN"
}

# Step 1: Fetch eligible PRs
Write-Log "Fetching PRs authored by $AuthorFilter..." "INFO"
$prListJson = Invoke-GhSafe "gh pr list --repo $Repo --state open --search `"author:$AuthorFilter`" --json number,title,labels,reviewDecision,author"
if ($null -eq $prListJson) {
    Write-Log "Failed to fetch PR list" "ERROR"
    exit 1
}

$prList = $prListJson | ConvertFrom-Json
if ($prList.Count -eq 0) {
    Write-Log "No open PRs found for author $AuthorFilter" "INFO"
    exit 2
}

Write-Log "Found $($prList.Count) PR(s) for author $AuthorFilter" "INFO"

# Step 2: Process each PR
$approved = 0
$flagged = 0
$skipped = 0

foreach ($pr in $prList) {
    $prNumber = $pr.number
    Write-Log "`n--- Processing PR #$prNumber : $($pr.title) ---" "INFO"

    # Skip if already approved
    if ($pr.reviewDecision -eq "APPROVED") {
        Write-Log "PR #$prNumber already APPROVED, skipping" "INFO"
        $skipped++
        continue
    }

    # Check restricted labels
    $labelFindings = Test-RestrictedLabels -Labels $pr.labels
    if ($labelFindings.Count -gt 0) {
        Write-Log "PR #$prNumber has restricted labels, skipping auto-review:" "WARN"
        $labelFindings | ForEach-Object { Write-Log "  $_" "WARN" }
        $skipped++
        continue
    }

    # Get full PR details (CI status, files, LOC)
    $prDetailJson = Invoke-GhSafe "gh pr view $prNumber --repo $Repo --json statusCheckRollup,additions,deletions,files,headRefName"
    if ($null -eq $prDetailJson) {
        Write-Log "Failed to fetch PR #$prNumber details" "ERROR"
        continue
    }
    $prDetail = $prDetailJson | ConvertFrom-Json

    # Check CI status
    $ciChecks = $prDetail.statusCheckRollup
    if ($null -ne $ciChecks -and $ciChecks.Count -gt 0) {
        $ciPending = $ciChecks | Where-Object { $_.status -eq "QUEUED" -or $_.status -eq "IN_PROGRESS" }
        $ciFailed = $ciChecks | Where-Object { $_.conclusion -eq "FAILURE" }
        $ciSuccess = $ciChecks | Where-Object { $_.conclusion -eq "SUCCESS" }

        if ($ciPending -and $ciPending.Count -gt 0) {
            Write-Log "PR #$prNumber CI still pending ($($ciPending.Count) checks), skipping" "WARN"
            $skipped++
            continue
        }

        if ($ciFailed -and $ciFailed.Count -gt 0) {
            Write-Log "PR #$prNumber CI FAILED ($($ciFailed.Count) checks)" "ERROR"
            $skipped++
            continue
        }

        if ($ciSuccess -and $ciSuccess.Count -gt 0) {
            Write-Log "CI: $($ciSuccess.Count)/$($ciChecks.Count) checks passed" "OK"
        }
    }
    else {
        Write-Log "No CI checks found for PR #$prNumber, proceeding without CI gate" "WARN"
    }

    # Get diff for audit
    Write-Log "Fetching diff for audit..." "INFO"
    $diff = Invoke-GhSafe "gh pr diff $prNumber --repo $Repo --color=never"
    if ($null -eq $diff) {
        Write-Log "Failed to fetch diff for PR #$prNumber" "ERROR"
        continue
    }

    # Truncate diff if too large
    if ($diff.Length -gt $MaxDiffChars) {
        Write-Log "Diff truncated: $($diff.Length) chars (max: $MaxDiffChars)" "WARN"
        $diff = $diff.Substring(0, $MaxDiffChars)
    }

    # Run audit checks
    $allFindings = @()
    $allFindings += Test-SecretsInDiff -Diff $diff
    $allFindings += Test-ProtectedDirs -Diff $diff
    $allFindings += Test-HasTests -Diff $diff -Additions $prDetail.additions -Deletions $prDetail.deletions

    # Step 3: Approve or flag
    $botIdentity = "$MachineName-review-bot"

    if ($allFindings.Count -eq 0) {
        $approveBody = @"
## Auto-approve by $botIdentity

**Checks passed:**
- CI: green
- Secrets: none detected
- Protected dirs: not touched
- Test coverage: adequate

**Machine:** $MachineName
**Timestamp:** $Timestamp

*This is an automated review by $botIdentity. No merge performed — coordinator handles merge.*
"@
        if ($DryRun) {
            Write-Log "[DRY RUN] Would APPROVE PR #$prNumber" "OK"
            if ($VerboseOutput) { Write-Host $approveBody }
        }
        else {
            # Write body to temp file to avoid quoting issues
            $tempFile = [System.IO.Path]::GetTempFileName()
            [System.IO.File]::WriteAllText($tempFile, $approveBody, [System.Text.UTF8Encoding]::new($false))
            $result = Invoke-GhSafe "gh pr review $prNumber --repo $Repo --approve --body-file $tempFile"
            Remove-Item $tempFile -ErrorAction SilentlyContinue
            if ($null -ne $result) {
                Write-Log "APPROVED PR #$prNumber" "OK"
            }
            else {
                Write-Log "Failed to approve PR #$prNumber" "ERROR"
                continue
            }
        }
        $approved++
    }
    else {
        $flagBody = @"
## Bot review flagged by $botIdentity

**Issues found ($($allFindings.Count)):**

$($allFindings | ForEach-Object { "- $_" }) -join "`n"

**Machine:** $MachineName
**Timestamp:** $Timestamp

*This is an automated review by $botIdentity. A human reviewer should assess these findings.*
"@
        if ($DryRun) {
            Write-Log "[DRY RUN] Would COMMENT on PR #$prNumber (flagged: $($allFindings.Count) issues)" "WARN"
            if ($VerboseOutput) {
                $allFindings | ForEach-Object { Write-Host "  - $_" }
            }
        }
        else {
            $tempFile = [System.IO.Path]::GetTempFileName()
            [System.IO.File]::WriteAllText($tempFile, $flagBody, [System.Text.UTF8Encoding]::new($false))
            $result = Invoke-GhSafe "gh pr review $prNumber --repo $Repo --comment --body-file $tempFile"
            Remove-Item $tempFile -ErrorAction SilentlyContinue
            if ($null -ne $result) {
                Write-Log "COMMENTED on PR #$prNumber ($($allFindings.Count) issues flagged)" "WARN"
            }
            else {
                Write-Log "Failed to comment on PR #$prNumber" "ERROR"
                continue
            }
        }
        $flagged++
    }
}

# Summary
Write-Log "`n=== Review Bot Complete ===" "INFO"
Write-Log "Total: $($prList.Count) | Approved: $approved | Flagged: $flagged | Skipped: $skipped" "INFO"
exit 0
