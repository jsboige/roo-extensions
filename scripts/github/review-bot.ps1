# review-bot.ps1 - Automated PR review bot for #1767 Phase 2
#
# Non-interactive, cron-safe script that:
# 1. Polls open PRs - default repo jsboige/jsboige-mcp-servers, no author
#    filter by default (#1767: the PRs that actually block live in the
#    submodule and are authored by jsboige)
# 2. Checks CI status, restricted labels, and runs no-complaisance audit
# 3. Posts a review if all checks pass, or comments with flagged issues
# 4. Does NOT merge (coordinator handles merge)
#
# APPROVE est OPT-IN (-AllowApprove). Sans ce commutateur, toute passe est
# postee en --comment, jamais en --approve. Ce defaut existe parce que
# l'arbitrage utilisateur du 13/05 sur #1767 dit : << je ne suis pas pour que
# tout le monde ait le pouvoir de merger, mais tout le monde doit pouvoir
# utiliser github correctement et notamment faire des comments et des
# reviews >>. La frontiere approve/comment n'est pas tranchee et ce script ne
# doit pas la trancher a la place de l'utilisateur.
#
# -Once : traite les PRs candidates puis rend la main - une seule passe,
# aucune boucle, aucun sleep, code de sortie explicite (voir ci-dessous).
# Pense pour etre invoque par le cycle /executor (4 h) : ce script
# n'installe AUCUNE tache planifiee et n'appelle ni Register-ScheduledTask
# ni schtasks.
#
# Usage:
#   .\review-bot.ps1 -Once                                 # Single pass, comment-only
#   .\review-bot.ps1 -Once -DryRun                         # Print what would happen
#   .\review-bot.ps1 -Once -VerboseOutput                  # Detailed output
#   .\review-bot.ps1 -Once -Repo "jsboige/roo-extensions"  # Target another repo
#   .\review-bot.ps1 -Once -AuthorFilter "myia-ai-01"      # Restrict to one author
#   .\review-bot.ps1 -Once -AllowApprove                   # Opt in to --approve
#
# Exit codes:
#   0 = Success (PRs reviewed or none eligible)
#   1 = Error (gh CLI failure)
#   2 = No PRs found (informational)
#
# Part of issue #1767 Phase 2: Distributed review bots

param(
    [string]$Repo = "jsboige/jsboige-mcp-servers",
    [string]$AuthorFilter = "",
    [int]$MaxDiffChars = 50000,
    [switch]$DryRun,
    [switch]$VerboseOutput,
    [switch]$AllowApprove,
    [switch]$Once
)

$ErrorActionPreference = "Stop"
$MachineName = $env:COMPUTERNAME
$Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

# Lectures PR en REST seul (#4150 lot 3, doctrine #4604) : `gh pr list` / `gh pr view`
# brûlaient un point GraphQL par passe et par PR.
. "$PSScriptRoot\..\common\gh-pull-requests.ps1"

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
        # Lot 3 (#4150) : le helper REST rend les labels en noms (strings) ; l'ancien
        # `gh pr list --json labels` rendait des objets {name}. Les deux passent.
        $name = if ($label -is [string]) { $label } else { $label.name }
        if ($restricted -contains $name) {
            $findings += "Restricted label: $name — requires human review"
        }
    }
    return $findings
}

# --- Main logic ---

Write-Log "=== Review Bot Started ===" "INFO"
$AuthorDisplay = if ([string]::IsNullOrEmpty($AuthorFilter)) { "(all)" } else { $AuthorFilter }
Write-Log "Machine: $MachineName | Repo: $Repo | Author filter: $AuthorDisplay" "INFO"
if ($DryRun) {
    Write-Log "MODE: DRY RUN (no review posted)" "WARN"
}
if ($Once) {
    Write-Log "MODE: ONCE - single pass, returns immediately (for /executor cycle)" "INFO"
}

# Step 1: Fetch eligible PRs (empty author filter = all open PRs are candidates)
# REST (#4150 lot 3, doctrine #4604) : `gh pr list` brûlait un point GraphQL par
# passe ; le helper rend la liste en REST, et le filtre auteur (`--search author:`,
# qui n'existe pas sur l'API pulls) s'applique côté client sur user.login.
Write-Log "Fetching open PRs (author filter: $AuthorDisplay)..." "INFO"
$prSummary = Get-PullRequestSummary -Repo $Repo -State open
if (-not $prSummary.Ok) {
    Write-Log "Failed to fetch PR list: $($prSummary.Error)" "ERROR"
    exit 1
}

$prList = @($prSummary.Items)
if (-not [string]::IsNullOrEmpty($AuthorFilter)) {
    $prList = @($prList | Where-Object { "$($_.AuthorLogin)" -eq $AuthorFilter })
}
if ($prList.Count -eq 0) {
    Write-Log "No open PRs found (author filter: $AuthorDisplay)" "INFO"
    exit 2
}

Write-Log "Found $($prList.Count) open PR(s) (author filter: $AuthorDisplay)" "INFO"

# Step 2: Process each PR
$approved = 0
$flagged = 0
$skipped = 0

foreach ($pr in $prList) {
    $prNumber = $pr.Number
    Write-Log "`n--- Processing PR #$prNumber : $($pr.Title) ---" "INFO"

    # Skip if already approved — reviewDecision est GraphQL-only : composé en REST
    # depuis les revues (#4150 lot 3). Échec du fetch = skip : commenter une PR
    # peut-être déjà approuvée est précisément le doublon que ce skip évite.
    $reviewDecision = Get-PullRequestReviewDecision -Repo $Repo -Number $prNumber
    if (-not $reviewDecision.Ok) {
        Write-Log "Failed to fetch review decision for PR #$prNumber ($($reviewDecision.Error)), skipping" "WARN"
        $skipped++
        continue
    }
    if ($reviewDecision.Decision -eq "APPROVED") {
        Write-Log "PR #$prNumber already APPROVED, skipping" "INFO"
        $skipped++
        continue
    }

    # Check restricted labels
    $labelFindings = Test-RestrictedLabels -Labels $pr.Labels
    if ($labelFindings.Count -gt 0) {
        Write-Log "PR #$prNumber has restricted labels, skipping auto-review:" "WARN"
        $labelFindings | ForEach-Object { Write-Log "  $_" "WARN" }
        $skipped++
        continue
    }

    # Get full PR details (CI status, files, LOC) — REST (#4150 lot 3), forme
    # « gh pr view --json » préservée : statusCheckRollup composé des check-runs,
    # casse MAJUSCULE comme gh, additions/deletions inchangés.
    $prDetailR = Get-PullRequestDetail -Repo $Repo -Number $prNumber
    if (-not $prDetailR.Ok) {
        Write-Log "Failed to fetch PR #$prNumber details: $($prDetailR.Error)" "ERROR"
        continue
    }
    $prDetail = $prDetailR.Item

    # Check CI status — porte unique Get-CiRollupGate (#4150 lot 5, review #4626
    # SHOULD 2) : l'inline ne voyait QUE FAILURE, laissant TIMED_OUT/ACTION_REQUIRED/
    # CANCELLED et toute conclusion inconnue (STARTUP_FAILURE) passer pour un CI green.
    $ciChecks = $prDetail.statusCheckRollup
    if ($null -ne $ciChecks -and $ciChecks.Count -gt 0) {
        $ciGate = Get-CiRollupGate -Checks $ciChecks
        $ciPending = @($ciGate.Pending)
        $ciFailed = @($ciGate.Failed)
        $ciPassed = $ciChecks.Count - $ciPending.Count - $ciFailed.Count

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

        if ($ciPassed -gt 0) {
            Write-Log "CI: $ciPassed/$($ciChecks.Count) checks passed" "OK"
        }

        # #4150 lot 5 suite (APPROVE #4628, trou a) : exiger au moins un run
        # build-and-test, comme pr-review-and-merge — ici en WARN (le bot audite,
        # il ne merge pas) : un rollup sans build-and-test n'est pas un CI certifié.
        $bat = @($ciChecks | Where-Object { $_.name -match "build-and-test" })
        if ($bat.Count -eq 0) {
            Write-Log "PR #$prNumber has no build-and-test check-run — CI not certified (empty build-and-test set)" "WARN"
        }
    }
    else {
        # #4150 lot 6 (INFO ai-01) : un rollup TOTALEMENT vide n'est pas « proceeding
        # without CI gate » (qui se lisait comme un acquittement) — c'est un CI non
        # certifié, explicitement : aucun run n'atteste le build. Le bot audite, il ne
        # merge pas : WARN non bloquant, comme la garde build-and-test vide ci-dessus.
        Write-Log "PR #$prNumber has no CI check-runs at all — CI not certified (empty rollup)" "WARN"
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
        # Approve is opt-in (#1767): without -AllowApprove the pass is a plain comment
        $reviewFlag = "--comment"
        $reviewHeader = "Checks passed - comment-only review by $botIdentity"
        if ($AllowApprove) {
            $reviewFlag = "--approve"
            $reviewHeader = "Auto-approve by $botIdentity"
        }
        $approveBody = @"
## $reviewHeader

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
            Write-Log "[DRY RUN] Would post $reviewFlag review on PR #$prNumber" "OK"
            if ($VerboseOutput) { Write-Host $approveBody }
        }
        else {
            # Write body to temp file to avoid quoting issues
            $tempFile = [System.IO.Path]::GetTempFileName()
            [System.IO.File]::WriteAllText($tempFile, $approveBody, [System.Text.UTF8Encoding]::new($false))
            $result = Invoke-GhSafe "gh pr review $prNumber --repo $Repo $reviewFlag --body-file $tempFile"
            Remove-Item $tempFile -ErrorAction SilentlyContinue
            if ($null -ne $result) {
                Write-Log "Posted $reviewFlag review on PR #$prNumber" "OK"
            }
            else {
                Write-Log "Failed to post $reviewFlag review on PR #$prNumber" "ERROR"
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
Write-Log "Total: $($prList.Count) | Passed: $approved | Flagged: $flagged | Skipped: $skipped" "INFO"
exit 0
