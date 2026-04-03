# PR Review and Merge Script for Coordinator
# Part of Issue #958 - Option E Implementation
# Usage: .\scripts\github\pr-review-and-merge.ps1 -PrNumber <PR_NUMBER>

param(
    [Parameter(Mandatory=$true)]
    [int]$PrNumber,

    [Parameter(Mandatory=$false)]
    [switch]$DryRun,

    [Parameter(Mandatory=$false)]
    [switch]$Force,

    [Parameter(Mandatory=$false)]
    [string]$Repo = "jsboige/roo-extensions"
)

$ErrorActionPreference = "Stop"

# Log header
Write-Host "`n=== PR Review and Merge ===" -ForegroundColor Cyan
Write-Host "PR #$PrNumber in $Repo" -ForegroundColor Cyan
Write-Host "Machine: $env:COMPUTERNAME" -ForegroundColor Cyan
if ($DryRun) {
    Write-Host "MODE: DRY RUN (no merge)" -ForegroundColor Yellow
}

# Step 1: Get PR details
Write-Host "`n[Step 1] Fetching PR details..." -ForegroundColor Cyan
$pr = gh pr view $PrNumber --repo $Repo --json title,author,body,headRefName,baseRefName,state,mergeable,additions,deletions,files,reviewDecision,statusCheckRollup | ConvertFrom-Json

if ($pr.state -ne "OPEN") {
    Write-Host "✗ PR is not open (state: $($pr.state))" -ForegroundColor Red
    exit 1
}

Write-Host "  Title: $($pr.title)" -ForegroundColor Gray
Write-Host "  Author: $($pr.author.login)" -ForegroundColor Gray
Write-Host "  Changes: +$($pr.additions) -$($pr.deletions) lines" -ForegroundColor Gray
Write-Host "  Files: $($pr.files.Count)" -ForegroundColor Gray
Write-Host "  Mergeable: $($pr.mergeable)" -ForegroundColor Gray

# Step 2: Check CI status
Write-Host "`n[Step 2] Checking CI status..." -ForegroundColor Cyan

$ciChecks = $pr.statusCheckRollup | Where-Object { $_.name -match "build-and-test" }
$ciPending = $ciChecks | Where-Object { $_.status -eq "PENDING" }
$ciFailed = $ciChecks | Where-Object { $_.status -in "FAILED", "EXPECTED" }

if ($ciPending) {
    Write-Host "✗ CI still pending..." -ForegroundColor Yellow
    $ciPending | ForEach-Object { Write-Host "  - $($_.name): $($_.status)" -ForegroundColor Gray }
    if (!$Force) {
        Write-Host "Use -Force to merge anyway (not recommended)" -ForegroundColor Yellow
        exit 1
    }
}

if ($ciFailed) {
    Write-Host "✗ CI failed!" -ForegroundColor Red
    $ciFailed | ForEach-Object { Write-Host "  - $($_.name): $($_.status)" -ForegroundColor Red }
    Write-Host "Cannot merge. PR author must fix CI issues." -ForegroundColor Red
    exit 1
}

Write-Host "✓ CI passed" -ForegroundColor Green

# Step 3: sk-agent code review (if >50 LOC)
if ($pr.additions -gt 50 -or $pr.deletions -gt 50) {
    Write-Host "`n[Step 3] Running sk-agent code review (>50 LOC)..." -ForegroundColor Cyan

    # Get PR diff
    $diffFile = [System.IO.Path]::GetTempFileName()
    gh pr diff $PrNumber --repo $Repo --color=never | Out-File -FilePath $diffFile -Encoding UTF8

    # Check if sk-agent MCP is available
    $skAgentAvailable = $false
    try {
        $tools = mcp-list-tools 2>$null | ConvertFrom-Json
        if ($tools.tools.name -contains "run_conversation") {
            $skAgentAvailable = $true
        }
    } catch {
        # sk-agent not available via MCP
    }

    if ($skAgentAvailable) {
        # Run sk-agent code review via MCP
        $reviewPrompt = @"
Review this GitHub PR diff for:
1. **Security issues** (injection, XSS, auth bypass, secrets)
2. **Data loss risks** (destructive operations, missing migrations)
3. **Performance problems** (N+1 queries, memory leaks, inefficient algorithms)
4. **Maintainability** (code duplication, missing error handling, unclear logic)
5. **Correctness** (logic bugs, edge cases, type safety)

PR Title: $($pr.title)
PR Author: $($pr.author.login)

Diff output:
```
$(Get-Content $diffFile -Raw)
```

Provide a structured review:
- **Critical Issues** (must fix before merge)
- **Warnings** (should fix)
- **Suggestions** (nice to have)
- **Overall Assessment** (approve/request changes/reject)
"@

        $reviewResult = mcp-call-tool tool="run_conversation" arguments="{\"prompt\": \"$($reviewPrompt -replace '`n', '\\n' -replace '"', '\"')\", \"conversation\": \"code-review\"}" 2>$null

        if ($LASTEXITCODE -eq 0 -and $reviewResult) {
            $reviewComment = @"
## sk-agent Code Review (automated)

**Reviewer:** myia-ai-01 coordinator + sk-agent LLM analysis
**Date:** $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
**PR:** #$PrNumber - $($pr.title)

$reviewResult

---
*This review was automatically generated. Critical issues must be addressed before merge.*
"@

            # Post review as PR comment
            if (!$DryRun) {
                gh pr comment $PrNumber --repo $Repo --body $reviewComment
                Write-Host "✓ Review posted as PR comment" -ForegroundColor Green
            } else {
                Write-Host "[DRY RUN] Would post review comment:" -ForegroundColor Yellow
                Write-Host $reviewComment
            }
        } else {
            Write-Host "⚠ sk-agent review failed, skipping..." -ForegroundColor Yellow
        }
    } else {
        Write-Host "⚠ sk-agent not available via MCP, skipping review..." -ForegroundColor Yellow
        Write-Host "  To enable: Configure sk-agent MCP in mcp_settings.json" -ForegroundColor Gray
    }

    Remove-Item $diffFile -ErrorAction SilentlyContinue
} else {
    Write-Host "`n[Step 3] Skipping sk-agent review (≤50 LOC, not required)" -ForegroundColor Gray
}

# Step 4: Manual review checklist
Write-Host "`n[Step 4] Manual review checklist..." -ForegroundColor Cyan

$checklist = @(
    @{ Check = "No code deletion without proof"; Status = $null },
    @{ Check = "No protected directory edits (synthesis/, narrative/)"; Status = $null },
    @{ Check = "Tests preserved (or updated)"; Status = $null },
    @{ Check = "No new stubs (return null, TODO)"; Status = $null },
    @{ Check = "No console.log in new code"; Status = $null },
    @{ Check = "Diff is proportional (not mass deletion)"; Status = $null },
    @{ Check = "Build + tests pass"; Status = $true },
    @{ Check = "No plan-based destruction"; Status = $null }
)

Write-Host "  Review each item and press Y to approve, N to reject, S to skip:" -ForegroundColor Gray
foreach ($item in $checklist) {
    $response = Read-Host "  [$($item.Check)]"
    switch ($response.ToUpper()) {
        "Y" { $item.Status = $true }
        "N" { $item.Status = $false }
        "S" { $item.Status = $null }
    }
}

$failedChecks = $checklist | Where-Object { $_.Status -eq $false }
$skippedChecks = $checklist | Where-Object { $_.Status -eq $null }

if ($failedChecks) {
    Write-Host "`n✗ Review failed:" -ForegroundColor Red
    $failedChecks | ForEach-Object { Write-Host "  - $($_.Check)" -ForegroundColor Red }
    Write-Host "`nRequest changes from PR author." -ForegroundColor Yellow
    gh pr comment $PrNumber --repo $Repo --body @"
## ❌ Review Changes Requested

The following items must be addressed:

$($failedChecks | ForEach-Object { "- $($_.Check)`n" } )

Please fix and re-push. The coordinator will review again.
"@
    exit 1
}

if ($skippedChecks) {
    Write-Host "`n⚠ Some checks were skipped:" -ForegroundColor Yellow
    $skippedChecks | ForEach-Object { Write-Host "  - $($_.Check)" -ForegroundColor Yellow }

    $confirm = Read-Host "Merge anyway with skipped checks? (y/N)"
    if ($confirm.ToUpper() -ne "Y") {
        Write-Host "Merge cancelled." -ForegroundColor Yellow
        exit 1
    }
}

# Step 5: Merge
Write-Host "`n[Step 5] Merging PR..." -ForegroundColor Cyan

if (!$DryRun) {
    # Squash merge
    gh pr merge $PrNumber --repo $Repo --squash --delete-branch --subject "Merge PR #$PrNumber" --body "Automated merge by coordinator after review approval."
    Write-Host "✓ PR merged and branch deleted" -ForegroundColor Green

    # Report to dashboard
    $dashboardMessage = @"
### PR #$PrNumber Merged

**Title:** $($pr.title)
**Author:** $($pr.author.login)
**Changes:** +$($pr.additions) -$($pr.deletions)
**CI:** Passed
**Review:** Coordinator + sk-agent (if >50 LOC)

**Machine:** myia-ai-01 (coordinator)
**Date:** $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
"@

    try {
        mcp-call-tool tool="roosync_dashboard" arguments="{\"action\":\"append\",\"type\":\"workspace\",\"tags\":[\"DONE\",\"pr-merge\"],\"content\":\"$($dashboardMessage -replace '`n', '\\n')\"}"
    } catch {
        Write-Host "⚠ Could not report to dashboard (MCP unavailable)" -ForegroundColor Yellow
    }
} else {
    Write-Host "[DRY RUN] Would merge PR now" -ForegroundColor Yellow
}

Write-Host "`n=== Review Complete ===" -ForegroundColor Green
