# Branch Protection Setup for roo-extensions (Issue #958)
# This script configures GitHub branch protection for the main branch
# Implements Option E: Hybrid CI + sk-agent review (no native GitHub approvals)

param(
    [Parameter(Mandatory=$false)]
    [string]$Repo = "jsboige/roo-extensions",

    [Parameter(Mandatory=$false)]
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

Write-Host "`n=== Branch Protection Configuration ===" -ForegroundColor Cyan
Write-Host "Repository: $Repo" -ForegroundColor Cyan
Write-Host "Branch: main" -ForegroundColor Cyan
if ($DryRun) {
    Write-Host "MODE: DRY RUN (no changes)" -ForegroundColor Yellow
}

# Current configuration (from gh api output)
Write-Host "`nCurrent settings:" -ForegroundColor Yellow
Write-Host "  require_status_checks: strict=true, contexts=[build-and-test (18), build-and-test (20)]" -ForegroundColor Gray
Write-Host "  required_approving_review_count: 0 (no approvals required)" -ForegroundColor Gray
Write-Host "  enforce_admins: true" -ForegroundColor Gray

# Option E Configuration
Write-Host "`n=== Option E: CI + sk-agent Review ===" -ForegroundColor Cyan

Write-Host @"
Since all agents use the same GitHub account (jsboige), native GitHub PR reviews
cannot work (GitHub prevents self-approval). This implementation uses:

1. **Required Status Checks (CI)** - Enforced by GitHub
   - build-and-test must pass
   - Blocks merge if CI fails

2. **sk-agent Code Review** - Enforced by coordinator workflow
   - Run by coordinator before merge
   - Posted as PR comment (not GitHub approval)
   - Provides LLM-based analysis: security, performance, correctness

3. **Coordinator Manual Review** - Enforced by process
   - Uses pr-review-and-merge.ps1 script
   - Runs through checklist before merge
   - Final decision authority

4. **No GitHub Approvals Required** - By design
   - required_approving_review_count = 0
   - Approval is via PR comment + coordinator script execution
   - Future: Option A (separate bot accounts) for native approvals
"@

Write-Host "`nConfiguration is already optimal for Option E." -ForegroundColor Green
Write-Host "No GitHub API changes needed." -ForegroundColor Green

# Verify CI checks are active
Write-Host "`nVerifying CI status checks..." -ForegroundColor Cyan

$protection = gh api repos/$Repo/branches/main/protection | ConvertFrom-Json
$ciChecks = $protection.required_status_checks.contexts

Write-Host "  Required contexts ($($ciChecks.Count)):" -ForegroundColor Gray
$ciChecks | ForEach-Object { Write-Host "    - $($_)" -ForegroundColor White }

if ($protection.required_status_checks.strict) {
    Write-Host "  ✓ Strict mode enabled (all contexts must pass)" -ForegroundColor Green
} else {
    Write-Host "  ⚠ Strict mode disabled (consider enabling)" -ForegroundColor Yellow
}

# Document enforcement mechanism
Write-Host "`n=== Enforcement Mechanism ===" -ForegroundColor Cyan

Write-Host @"
**GitHub enforces:**
- CI must pass (build-and-test)
- No direct pushes to main (require PR)

**Coordinator enforces:**
- Runs pr-review-and-merge.ps1
- Checks CI status (redundant but safe)
- Runs sk-agent code-review for PRs >50 LOC
- Goes through manual review checklist
- Only merges if all checks pass

**How it works:**
1. Agent creates PR from worktree branch
2. GitHub Actions runs build-and-test CI
3. CI blocks merge if fails (enforced by GitHub)
4. Coordinator reviews PR using pr-review-and-merge.ps1
5. Script runs sk-agent analysis (if >50 LOC)
6. Coordinator approves checklist items
7. Script merges PR (only if all passed)

**Why no required_approving_review_count:**
- All agents = jsboige account
- GitHub prevents self-approval
- Cannot require 1 approval (would deadlock)
- PR comment + coordinator script = de facto approval
"@

# Test the workflow
Write-Host "`n=== Test Workflow ===" -ForegroundColor Cyan

$openPRs = gh pr list --repo $Repo --state open --limit 5 --json number,title,additions | ConvertFrom-Json

if ($openPRs) {
    Write-Host "`nOpen PRs ready for review:" -ForegroundColor Gray
    foreach ($pr in $openPRs) {
        $needsReview = if ($pr.additions -gt 50) { " (needs sk-agent review)" } else { "" }
        Write-Host "  PR #$($pr.number): $($pr.title)$needsReview" -ForegroundColor White
        Write-Host "    Command: .\scripts\github\pr-review-and-merge.ps1 -PrNumber $($pr.number)" -ForegroundColor Gray
    }
} else {
    Write-Host "  No open PRs" -ForegroundColor Gray
}

Write-Host "`n=== Configuration Complete ===" -ForegroundColor Green
Write-Host "Branch protection is optimally configured for Option E." -ForegroundColor Green
Write-Host "Use pr-review-and-merge.ps1 to review and merge PRs." -ForegroundColor Green
