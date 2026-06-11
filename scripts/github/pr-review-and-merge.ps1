# PR Review and Merge Script for Coordinator
# Part of Issue #958 - Option E Implementation
# Usage: .\scripts\github\pr-review-and-merge.ps1 -PrNumber <PR_NUMBER>
#
# Tier-gate (#2565): GLM-class machines can only merge trivial PRs.
# Trivial criteria sourced from docs/harness/reference/pr-trivial-merge-policy.md.

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

# === Tier-gate constants (#2565) ===
# Opus-class: full merge authority
$OpusClassMachines = @('MYIA-AI-01')
# GLM-class: trivial PRs only
$GlmClassMachines = @('MYIA-PO-2023', 'MYIA-PO-2024', 'MYIA-PO-2025', 'MYIA-PO-2026', 'MYIA-WEB1')

# Trivial title patterns (sourced from pr-trivial-merge-policy.md)
$TrivialTitlePatterns = @(
    '^test(\(coverage\))?: .+',
    '^chore\(submod\): bump pointer [a-f0-9]{7,} -> [a-f0-9]{7,}.*$',
    '^chore\(submod\): bundle pointer-bump .+',
    '^docs\([^)]+\): .+',
    '^(chore|docs)\(#?\d+\): .+\.gitkeep$',
    '^fix\(#?\d+\): .+ test (only|fixup).+$'
)

# Paths that make a PR non-trivial if touched
$ProtectedPaths = @(
    'src/', 'lib/', 'mcps/internal/servers/*/src/', 'mcps/internal/servers/*/build/',
    '.claude/', '.roo/', 'CLAUDE.md', '.roomodes', 'package*.json',
    '.github/workflows/', '.github/CODEOWNERS', '*.env*', '*.yml'
)

# File extensions that make a PR non-trivial (outside test dirs)
$ProtectedExtensions = @('.ts')

function Test-IsTrivialPR {
    param($PrData)
    $loc = $PrData.additions + $PrData.deletions

    # 1. LOC check: >=50 LOC total = non-trivial
    if ($loc -ge 50) {
        Write-Host "  [TIER-GATE] Non-trivial: total LOC = $loc (>=50)" -ForegroundColor DarkGray
        return $false
    }

    # 2. Title must match at least one trivial pattern
    $titleMatch = $false
    foreach ($pattern in $TrivialTitlePatterns) {
        if ($PrData.title -match $pattern) {
            $titleMatch = $true
            break
        }
    }
    if (-not $titleMatch) {
        Write-Host "  [TIER-GATE] Non-trivial: title does not match any trivial pattern" -ForegroundColor DarkGray
        return $false
    }

    # 3. Protected path check: no file in protected paths
    foreach ($file in $PrData.files) {
        $path = $file.path
        foreach ($protected in $ProtectedPaths) {
            if ($protected -like '*/*') {
                # Path prefix match
                if ($path -like "$protected*" -or $path -like "*/$protected*") {
                    Write-Host "  [TIER-GATE] Non-trivial: touches protected path $path" -ForegroundColor DarkGray
                    return $false
                }
            } else {
                if ($path -eq $protected -or (Split-Path $path -Leaf) -eq $protected) {
                    Write-Host "  [TIER-GATE] Non-trivial: touches protected file $path" -ForegroundColor DarkGray
                    return $false
                }
            }
        }

        # Protected extensions outside test dirs
        $ext = [System.IO.Path]::GetExtension($path)
        $inTestDir = $path -match '(^|/)tests?/' -or $path -match '(^|/)__tests__/'
        if ($ProtectedExtensions -contains $ext -and -not $inTestDir) {
            Write-Host "  [TIER-GATE] Non-trivial: $ext file outside test dir: $path" -ForegroundColor DarkGray
            return $false
        }
    }

    # 4. Labels check: 'security' label = non-trivial
    # (fetched separately if needed — check PR body/labels)
    try {
        $labels = gh pr view $PrData.number --repo $Repo --json labels --jq '.labels[].name' 2>$null
        if ($labels -contains 'security') {
            Write-Host "  [TIER-GATE] Non-trivial: labeled 'security'" -ForegroundColor DarkGray
            return $false
        }
    } catch {
        # Label check best-effort
    }

    return $true
}

function Get-MachineTier {
    $machine = $env:COMPUTERNAME
    if ($OpusClassMachines -contains $machine) { return 'opus' }
    if ($GlmClassMachines -contains $machine) { return 'glm' }
    # Unknown machine: treat as GLM-class (conservative)
    Write-Host "  [TIER-GATE] Unknown machine '$machine', treating as GLM-class (conservative)" -ForegroundColor Yellow
    return 'glm'
}

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

# === Tier-gate check (#2565) ===
Write-Host "`n[Tier Gate] Checking merge authority..." -ForegroundColor Cyan
$tier = Get-MachineTier
$isTrivial = Test-IsTrivialPR -PrData (@{title=$pr.title; additions=$pr.additions; deletions=$pr.deletions; files=$pr.files; number=$PrNumber})

Write-Host "  Machine tier: $tier | Trivial: $isTrivial" -ForegroundColor Gray

if ($tier -eq 'glm' -and -not $isTrivial) {
    Write-Host "`n✗ TIER-GATE BLOCKED: GLM-class machine cannot merge non-trivial PR" -ForegroundColor Red
    Write-Host "  This PR must be merged by Opus-class (ai-01/jsboige)." -ForegroundColor Red

    # Post escalation comment on PR
    $escalationComment = @"
## 🔒 Tier-Gate: Merge Refused (GLM-class)

**Machine:** $env:COMPUTERNAME
**Tier:** GLM-class (trivial-only merge authority)
**PR LOC:** $($pr.additions) + $($pr.deletions)
**Title:** $($pr.title)

This PR is **non-trivial** and cannot be merged by a GLM-class machine.
Escalating to **Opus-class (ai-01/jsboige)** for merge authorization.

*Ref: #2565 tier-gate policy*
"@

    if (!$DryRun) {
        try {
            gh pr comment $PrNumber --repo $Repo --body $escalationComment 2>$null
        } catch {
            Write-Host "  Could not post escalation comment" -ForegroundColor Yellow
        }
    } else {
        Write-Host "[DRY RUN] Would post escalation comment" -ForegroundColor Yellow
    }

    # Post [ASK] on dashboard for ai-01
    $askMessage = "[ASK] PR #$PrNumber is non-trivial (LOC $($pr.additions)+$($pr.deletions), title: $($pr.title)). GLM-class $env:COMPUTERNAME cannot merge. Requesting Opus-class merge authorization."
    Write-Host "  Dashboard escalation: $askMessage" -ForegroundColor Yellow

    exit 1
}

if ($tier -eq 'glm' -and $isTrivial) {
    Write-Host "  ✓ GLM-class merge authorized (trivial PR)" -ForegroundColor Green
} elseif ($tier -eq 'opus') {
    Write-Host "  ✓ Opus-class: full merge authority" -ForegroundColor Green
}

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
        # INTEGRATION TRACING TEMPLATE (issue #1471) - focuses on context flow, not just diff correctness
        $filesTouched = $pr.files | ForEach-Object { $_.path } | Out-String
        $reviewPrompt = @"
Review this PR with a focus on INTEGRATION, not just diff correctness.

DIFF:
```
$(Get-Content $diffFile -Raw)
```

FILES TOUCHED:
$filesTouched

CONTEXT TRACING (required):
For each new field, API, or modified behavior in this PR:
1. Where does a value enter the system? (tool input, request body, env var)
2. Where is it validated? (schema, Zod, manual checks)
3. What code CONSUMES it downstream?
4. Where does it have side effects? (network call, DB write, message dispatch)
5. At each step: is required context (workspace, machineId, auth, traceId) preserved?

Use the codebase to trace these. If the PR adds/modifies a schema field,
grep for consumers. If it changes a function signature, find callers.

CRITICAL PATTERNS TO HUNT:
- Silent failures: `.catch(() {})`, fire-and-forget without logging
- Context loss: passing `machineId` alone where `{`machineId`, workspace}` is needed
- Defaults papering over bugs: `|| undefined`, `?? ''`, `|| []` when missing input should error
- E2E test gap: does any test exercise the full flow from input to effect?
- Dual-definition: check if the same schema/type is duplicated elsewhere (tool-definitions vs handler source)

VERDICT: APPROVE / REQUEST_CHANGES / COMMENT.
Be specific about bugs NOT in the diff but exposed/obscured by it.
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

**Machine:** $env:COMPUTERNAME ($tier-tier)
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
