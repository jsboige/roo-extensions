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
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"
$MachineName = $env:COMPUTERNAME
$Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

# --- Input validation ---

if ($Repo -notmatch '^[a-zA-Z0-9\-]+/[a-zA-Z0-9_\-.]+$') {
    Write-Host "[$Timestamp] [ERROR] Invalid repo format: $Repo" -ForegroundColor Red
    exit 1
}

if ($AuthorFilter -notmatch '^[a-zA-Z0-9\-_]+$') {
    Write-Host "[$Timestamp] [ERROR] Invalid author filter: $AuthorFilter" -ForegroundColor Red
    exit 1
}

# --- Detect bot identity and guard against self-approval ---

$BotLogin = $null
try {
    $authStatus = & gh auth status 2>&1
    if ($LASTEXITCODE -eq 0) {
        # Extract login from "Logged in to github.com as <login>"
        if ($authStatus -match 'Logged in to github\.com account (\S+)') {
            $BotLogin = $Matches[1]
        }
        elseif ($authStatus -match 'Logged in to github\.com as (\S+)') {
            $BotLogin = $Matches[1]
        }
    }
}
catch {
    # Non-fatal — proceed without identity check
}

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

function Invoke-GhJson {
    # Safe gh wrapper: uses call operator + splatting, NEVER Invoke-Expression
    param(
        [Parameter(Mandatory)]
        [string[]]$Arguments
    )
    try {
        $result = & gh @Arguments 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Log "gh failed: $($Arguments -join ' ')`n$result" "ERROR"
            return $null
        }
        return $result
    }
    catch {
        Write-Log "gh exception: $_" "ERROR"
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
            $preview = $matches[0].Value
            if ($preview.Length -gt 40) { $preview = $preview.Substring(0, 40) + "..." }
            $findings += "Secret pattern detected: $preview"
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
        [int]$Additions
    )
    # Use additions only (deletions inflate LOC)
    if ($Additions -le 50) {
        return @() # Small PRs don't require tests
    }
    $hasTest = $Diff -match '(\.test\.|\.spec\.|_test\.|tests/|__tests__/)' -or `
               $Diff -match '\.Tests\.ps1'
    if (-not $hasTest) {
        return @("PR has $Additions additions but no test files detected (threshold: >50 additions)")
    }
    return @()
}

function Test-OwnFile {
    # Check if PR touches review-bot.ps1 itself
    param($Files)
    foreach ($file in $Files) {
        if ($file.path -match 'review-bot\.ps1$') {
            return @("PR modifies review-bot.ps1 — requires human review (self-modification)")
        }
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
Write-Log "Machine: $MachineName | Repo: $Repo | Author filter: $AuthorFilter | Bot: $BotLogin" "INFO"
if ($DryRun) {
    Write-Log "MODE: DRY RUN (no approve/comment)" "WARN"
}

# Step 1: Fetch eligible PRs
Write-Log "Fetching PRs authored by $AuthorFilter..." "INFO"
$prListJson = Invoke-GhJson -Arguments @("pr", "list", "--repo", $Repo, "--state", "open", "--search", "author:$AuthorFilter", "--json", "number,title,labels,reviewDecision,author")
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

    # Self-approval guard: bot must not approve its own PRs
    if ($null -ne $BotLogin -and $null -ne $pr.author -and $pr.author.login -eq $BotLogin) {
        Write-Log "PR #$prNumber authored by bot identity ($BotLogin), skipping to prevent self-approval" "WARN"
        $skipped++
        continue
    }

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
    $prDetailJson = Invoke-GhJson -Arguments @("pr", "view", "$prNumber", "--repo", $Repo, "--json", "statusCheckRollup,additions,deletions,files,headRefName")
    if ($null -eq $prDetailJson) {
        Write-Log "Failed to fetch PR #$prNumber details" "ERROR"
        continue
    }
    $prDetail = $prDetailJson | ConvertFrom-Json

    # Check CI status — HARD REQUIREMENT (no bypass when no checks configured)
    $ciChecks = $prDetail.statusCheckRollup
    if ($null -eq $ciChecks -or $ciChecks.Count -eq 0) {
        Write-Log "PR #$prNumber has NO CI checks — cannot auto-approve without CI gate" "WARN"
        $skipped++
        continue
    }

    $ciPending = @($ciChecks | Where-Object { $_.status -eq "QUEUED" -or $_.status -eq "IN_PROGRESS" })
    $ciFailed = @($ciChecks | Where-Object { $_.conclusion -eq "FAILURE" })
    $ciSuccess = @($ciChecks | Where-Object { $_.conclusion -eq "SUCCESS" })

    if ($ciPending.Count -gt 0) {
        Write-Log "PR #$prNumber CI still pending ($($ciPending.Count) checks), skipping" "WARN"
        $skipped++
        continue
    }

    if ($ciFailed.Count -gt 0) {
        Write-Log "PR #$prNumber CI FAILED ($($ciFailed.Count) checks), skipping" "ERROR"
        $skipped++
        continue
    }

    if ($ciSuccess.Count -eq 0) {
        Write-Log "PR #$prNumber CI has no successful checks, skipping" "WARN"
        $skipped++
        continue
    }

    Write-Log "CI: $($ciSuccess.Count)/$($ciChecks.Count) checks passed" "OK"

    # Get diff for audit
    Write-Log "Fetching diff for audit..." "INFO"
    $diff = Invoke-GhJson -Arguments @("pr", "diff", "$prNumber", "--repo", $Repo, "--color=never")
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
    $allFindings += Test-HasTests -Diff $diff -Additions $prDetail.additions
    $allFindings += Test-OwnFile -Files $prDetail.files

    # Step 3: Approve or flag
    $botIdentity = "$MachineName-review-bot"

    if ($allFindings.Count -eq 0) {
        $approveBody = @"
## Auto-approve by $botIdentity

**Checks passed:**
- CI: green ($($ciSuccess.Count)/$($ciChecks.Count))
- Secrets: none detected
- Protected dirs: not touched
- Test coverage: adequate
- Self-modification: no

**Machine:** $MachineName
**Timestamp:** $Timestamp

*This is an automated review by $botIdentity. No merge performed — coordinator handles merge.*
"@
        if ($DryRun) {
            Write-Log "[DRY RUN] Would APPROVE PR #$prNumber" "OK"
        }
        else {
            $tempFile = [System.IO.Path]::GetTempFileName()
            try {
                [System.IO.File]::WriteAllText($tempFile, $approveBody, [System.Text.UTF8Encoding]::new($false))
                $result = Invoke-GhJson -Arguments @("pr", "review", "$prNumber", "--repo", $Repo, "--approve", "--body-file", $tempFile)
                if ($null -ne $result) {
                    Write-Log "APPROVED PR #$prNumber" "OK"
                }
                else {
                    Write-Log "Failed to approve PR #$prNumber" "ERROR"
                    continue
                }
            }
            finally {
                Remove-Item $tempFile -ErrorAction SilentlyContinue
            }
        }
        $approved++
    }
    else {
        $issueList = ($allFindings | ForEach-Object { "- $_" }) -join "`n"
        $flagBody = @"
## Bot review flagged by $botIdentity

**Issues found ($($allFindings.Count)):**

$issueList

**Machine:** $MachineName
**Timestamp:** $Timestamp

*This is an automated review by $botIdentity. A human reviewer should assess these findings.*
"@
        if ($DryRun) {
            Write-Log "[DRY RUN] Would COMMENT on PR #$prNumber (flagged: $($allFindings.Count) issues)" "WARN"
        }
        else {
            $tempFile = [System.IO.Path]::GetTempFileName()
            try {
                [System.IO.File]::WriteAllText($tempFile, $flagBody, [System.Text.UTF8Encoding]::new($false))
                $result = Invoke-GhJson -Arguments @("pr", "review", "$prNumber", "--repo", $Repo, "--comment", "--body-file", $tempFile)
                if ($null -ne $result) {
                    Write-Log "COMMENTED on PR #$prNumber ($($allFindings.Count) issues flagged)" "WARN"
                }
                else {
                    Write-Log "Failed to comment on PR #$prNumber" "ERROR"
                    continue
                }
            }
            finally {
                Remove-Item $tempFile -ErrorAction SilentlyContinue
            }
        }
        $flagged++
    }
}

# Summary
Write-Log "`n=== Review Bot Complete ===" "INFO"
Write-Log "Total: $($prList.Count) | Approved: $approved | Flagged: $flagged | Skipped: $skipped" "INFO"
exit 0
