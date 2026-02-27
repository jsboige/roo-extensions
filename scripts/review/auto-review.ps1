# auto-review.ps1 - Automated code review via sk-agent
#
# Detects new commits, calls sk-agent for review, posts result to GitHub.
# Part of issue #535: sk-agent auto-review pipeline.
#
# Usage:
#   .\auto-review.ps1                          # Review HEAD vs HEAD~1
#   .\auto-review.ps1 -DiffRange "HEAD~3"      # Review last 3 commits
#   .\auto-review.ps1 -IssueNumber 535         # Force post to specific issue
#   .\auto-review.ps1 -DryRun                  # Print review without posting
#   .\auto-review.ps1 -Mode vllm               # Use vLLM directly (skip sk-agent HTTP)

param(
    [string]$DiffRange = "HEAD~1",
    [int]$IssueNumber = 0,
    [string]$RepoOwner = "jsboige",
    [string]$RepoName = "roo-extensions",
    [int]$MaxDiffChars = 8000,
    [ValidateSet("http", "vllm")]
    [string]$Mode = "http",
    [switch]$DryRun,
    [switch]$Verbose
)

$ErrorActionPreference = "Stop"
$ScriptDir = $PSScriptRoot

Write-Host "[AUTO-REVIEW] Starting review (range: $DiffRange, mode: $Mode)" -ForegroundColor Green

# --- Step 1: Get commit info ---
try {
    $currentHash = git rev-parse HEAD 2>$null
    $parentHash = git rev-parse "$DiffRange" 2>$null

    if (-not $currentHash -or -not $parentHash) {
        Write-Host "[AUTO-REVIEW] Cannot resolve git range, exiting." -ForegroundColor Yellow
        exit 0
    }

    if ($currentHash -eq $parentHash) {
        Write-Host "[AUTO-REVIEW] No new commits, exiting." -ForegroundColor Yellow
        exit 0
    }

    $commitMessage = git log --format="%s" -1 HEAD 2>$null
    $commitAuthor = git log --format="%an" -1 HEAD 2>$null
    $shortHash = $currentHash.Substring(0, 7)

    Write-Host "[AUTO-REVIEW] Commit: $shortHash - $commitMessage ($commitAuthor)" -ForegroundColor Cyan
} catch {
    Write-Host "[AUTO-REVIEW] Git error: $_" -ForegroundColor Red
    exit 1
}

# --- Step 2: Get diff ---
try {
    $diffStat = git diff --stat "$DiffRange" HEAD 2>$null
    $diffFull = git diff "$DiffRange" HEAD --no-color 2>$null

    if ([string]::IsNullOrWhiteSpace($diffFull)) {
        Write-Host "[AUTO-REVIEW] Empty diff, exiting." -ForegroundColor Yellow
        exit 0
    }

    # Truncate if too large
    $diffLen = $diffFull.Length
    if ($diffLen -gt $MaxDiffChars) {
        Write-Host "[AUTO-REVIEW] Diff truncated: $diffLen -> $MaxDiffChars chars" -ForegroundColor Yellow
        $diffFull = $diffFull.Substring(0, $MaxDiffChars) + "`n`n[... diff truncated at $MaxDiffChars chars ...]"
    }

    Write-Host "[AUTO-REVIEW] Diff: $diffLen chars" -ForegroundColor Cyan
} catch {
    Write-Host "[AUTO-REVIEW] Diff error: $_" -ForegroundColor Red
    exit 1
}

# --- Step 3: Find associated GitHub issue ---
if ($IssueNumber -eq 0) {
    # Try commit message patterns
    $patterns = @(
        '(?i)(?:fix|close|resolve)[\s\-]*#(\d+)',
        '(?i)issue[\s\-]*#(\d+)',
        '#(\d+)'
    )

    foreach ($pattern in $patterns) {
        if ($commitMessage -match $pattern) {
            $IssueNumber = [int]$matches[1]
            Write-Host "[AUTO-REVIEW] Found issue #$IssueNumber in commit message" -ForegroundColor Cyan
            break
        }
    }
}

if ($IssueNumber -eq 0) {
    Write-Host "[AUTO-REVIEW] No issue found, skipping review." -ForegroundColor Yellow
    exit 0
}

# --- Step 4: Call sk-agent for review ---
$reviewPrompt = @"
Review this code change concisely. Focus on: correctness, edge cases, security, and actionable improvements.

**Commit:** $shortHash - $commitMessage
**Author:** $commitAuthor
**Files changed:**
$diffStat

**Diff:**
``````diff
$diffFull
``````

Give a structured review in markdown with:
1. Summary (2-3 sentences)
2. Findings table (severity | category | description)
3. Final verdict: APPROVE / APPROVE WITH FIXES / REJECT
"@

$reviewResult = $null

try {
    Write-Host "[AUTO-REVIEW] Calling sk-agent (mode: $Mode)..." -ForegroundColor Cyan

    if ($Verbose) {
        $reviewResult = & "$ScriptDir\call-sk-agent.ps1" -Prompt $reviewPrompt -Agent "critic" -Mode $Mode -ShowDebug
    } else {
        $reviewResult = & "$ScriptDir\call-sk-agent.ps1" -Prompt $reviewPrompt -Agent "critic" -Mode $Mode
    }

    if ([string]::IsNullOrWhiteSpace($reviewResult)) {
        throw "sk-agent returned empty response"
    }

    Write-Host "[AUTO-REVIEW] Review received ($($reviewResult.Length) chars)" -ForegroundColor Cyan

} catch {
    Write-Host "[AUTO-REVIEW] sk-agent failed: $_. Using fallback review." -ForegroundColor Yellow

    # Fallback: basic review without LLM
    $fileCount = ($diffStat -split "`n" | Where-Object { $_ -match '\d+ file' }).Count
    if ($fileCount -eq 0) { $fileCount = "unknown" }

    $reviewResult = @"
## Auto-Review (fallback mode)

sk-agent was unavailable. Basic commit summary:

- **Commit:** $shortHash
- **Message:** $commitMessage
- **Author:** $commitAuthor
- **Changes:** $fileCount file(s)

``````
$diffStat
``````

> Manual review recommended. sk-agent error: $_
"@
}

# --- Step 5: Format and post ---
$fullComment = @"
$reviewResult

---
<sub>Auto-review by sk-agent ($Mode mode) on $env:COMPUTERNAME | Commit: $shortHash | $(Get-Date -Format "yyyy-MM-dd HH:mm")</sub>
"@

if ($DryRun) {
    Write-Host "`n[AUTO-REVIEW] DRY RUN - Would post to #$IssueNumber`:" -ForegroundColor Yellow
    Write-Host $fullComment
    exit 0
}

try {
    Write-Host "[AUTO-REVIEW] Posting to issue #$IssueNumber..." -ForegroundColor Cyan

    # Use gh CLI to post (handles auth automatically)
    $fullComment | gh issue comment $IssueNumber --repo "$RepoOwner/$RepoName" --body-file - 2>&1

    if ($LASTEXITCODE -eq 0) {
        Write-Host "[AUTO-REVIEW] Posted to #$IssueNumber" -ForegroundColor Green
    } else {
        throw "gh issue comment failed (exit code $LASTEXITCODE)"
    }

} catch {
    Write-Host "[AUTO-REVIEW] Post failed: $_" -ForegroundColor Red
    # Save locally as fallback
    $outputFile = Join-Path $ScriptDir "last-review.md"
    $fullComment | Set-Content -Path $outputFile -Encoding UTF8
    Write-Host "[AUTO-REVIEW] Saved to $outputFile" -ForegroundColor Yellow
    exit 1
}

Write-Host "[AUTO-REVIEW] Done." -ForegroundColor Green
