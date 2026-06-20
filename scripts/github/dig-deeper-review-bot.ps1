# dig-deeper-review-bot.ps1 - Prototype "dig-deeper" review bot (#2505)
#
# Discipline (from issue #2505): a bot that goes DEEPER than surface reviews,
# posting ONLY findings that no existing reviewer has already raised.
#
# Workflow per PR:
#   STEP 1 (MANDATORY, verifiable in log) - READ FIRST:
#       Fetch ALL existing reviews + comments (gh pr view --json reviews,comments)
#       and extract the set of points already raised.
#   STEP 2 - DIG DEEPER (haiku via claude -p):
#       Hand the LLM the diff + the existing-points summary, ask for NEW findings
#       only (edge cases, untested error paths, subtle regressions, implicit
#       assumptions). Instruct: if nothing new, stay silent.
#   STEP 3 - POST only new findings:
#       Comment-only (NEVER approve/merge - governance #1767, this is what sank
#       #2500). If the LLM has nothing new, post a brief [ACK] referencing the
#       strongest existing review, or stay silent (-SilentIfEmpty).
#
# Why claude -p and not a raw API call: the existing worker infra
# (start-claude-worker.ps1) already routes claude -p through the claudish proxy
# with the right provider/model env. Model override via -Model (default haiku =
# economical, per #2505).
#
# Usage:
#   .\dig-deeper-review-bot.ps1                         # Review all open PRs
#   .\dig-deeper-review-bot.ps1 -PrNumber 2630          # Single PR
#   .\dig-deeper-review-bot.ps1 -DryRun                 # Print, do not comment
#   .\dig-deeper-review-bot.ps1 -Model sonnet           # Override model
#   .\dig-deeper-review-bot.ps1 -SilentIfEmpty          # No [ACK] when nothing new
#
# Exit codes:
#   0 = Success (PRs processed or none eligible)
#   1 = Error (gh / claude failure)
#   2 = No open PRs found (informational)
#
# Status: PROTOTYPE for #2505 (needs-approval). Not wired to any cron. Deploying
# the cron schedule is a separate user decision (see bots-directory.md).
#
# Part of issue #2505. References: #1767 (bot governance), #2372 (review quality
# postmortem), #2500 (rejected auto-approve approach).

param(
    [string]$Repo = "jsboige/roo-extensions",
    [int]$PrNumber = 0,
    [string]$Model = "haiku",
    [int]$MaxDiffChars = 40000,
    [int]$MaxExistingPointsChars = 8000,
    [switch]$DryRun,
    [switch]$SilentIfEmpty,
    [switch]$VerboseOutput
)

$ErrorActionPreference = "Stop"
$MachineName = $env:COMPUTERNAME
$Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$BotIdentity = "$MachineName-dig-deeper"

# --- Helpers (mirrors review-bot.ps1 #1767 Phase 2 conventions) ---

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

# NOTE: argv-array + call operator (`& gh @Argv`) instead of `Invoke-Expression`.
# Defense-in-depth (review po-2026 c.57): avoids string re-parsing, removes the
# injection surface should a future edit ever interpolate attacker-controllable
# data (e.g. PR titles). Behavior is identical; args bind positionally, no eval.
function Invoke-GhSafe {
    param([string[]]$Argv)
    try {
        $result = & gh @Argv 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Log "gh command failed: $($Argv -join ' ')" "ERROR"
            return $null
        }
        return $result
    }
    catch {
        Write-Log "gh command exception: $_" "ERROR"
        return $null
    }
}

# UTF-8 no-BOM temp file writer (avoids PowerShell quoting issues with gh --body-file)
function Write-TempBody {
    param([string]$Content)
    $tempFile = [System.IO.Path]::GetTempFileName()
    [System.IO.File]::WriteAllText($tempFile, $Content, [System.Text.UTF8Encoding]::new($false))
    return $tempFile
}

# STEP 1 core - extract the set of points ALREADY raised on a PR.
# Returns a plain-text bullet list (one line per distinct point). This is the
# verifiable artifact: the log echoes the count + first lines so a reader can
# confirm the bot read before writing (acceptance criterion of #2505).
function Get-ExistingReviewPoints {
    param([int]$Number)

    $detailJson = Invoke-GhSafe @('pr','view',$Number,'--repo',$Repo,'--json','reviews,comments')
    if ($null -eq $detailJson) { return $null }

    $detail = $detailJson | ConvertFrom-Json
    $points = [System.Collections.Generic.List[string]]::new()

    foreach ($rv in $detail.reviews) {
        $author = $rv.author.login
        $state = $rv.state
        $body = ($rv.body -as [string]).Trim()
        if ($body.Length -gt 0) {
            # Split review bodies into rough point-lines (bullets or sentences)
            $lines = $body -split "(`r?`n)|(?<=[.!?])\s+" | ForEach-Object { $_.Trim() } | Where-Object { $_.Length -gt 12 }
            foreach ($line in $lines) {
                $points.Add("[$state $author] $line")
            }
        }
    }
    foreach ($cm in $detail.comments) {
        $author = $cm.author.login
        $body = ($cm.body -as [string]).Trim()
        if ($body.Length -gt 0) {
            $lines = $body -split "(`r?`n)|(?<=[.!?])\s+" | ForEach-Object { $_.Trim() } | Where-Object { $_.Length -gt 12 }
            foreach ($line in $lines) {
                $points.Add("[comment $author] $line")
            }
        }
    }

    return $points
}

# STEP 2 core - ask the LLM (claude -p, haiku) for NEW findings only.
# Returns the LLM's raw text answer (may be empty / "NOTHING_NEW").
function Invoke-DigDeeper {
    param(
        [int]$Number,
        [string]$PrTitle,
        [string]$Diff,
        [string]$ExistingPoints
    )

    $prompt = @"
You are a 'dig-deeper' code reviewer (model $Model on $MachineName). Your ONLY job is to surface NEW findings that no existing reviewer has already raised.

PR #$Number : $PrTitle

## Existing points ALREADY raised by other reviewers (DO NOT repeat these):
$ExistingPoints

## Diff to review:
$Diff

## Your discipline:
- Findings that go DEEPER than the surface: edge cases, untested error paths, subtle regressions, implicit assumptions, concurrency/ordering issues, off-by-one, resource leaks.
- POST ONLY findings absent from the existing-points list above. If a point is already covered (even paraphrased), drop it.
- If you have nothing genuinely new, reply with EXACTLY the token: NOTHING_NEW
- Be concise: one bullet per finding, file:line if you can pinpoint it, max ~8 findings.
- Do NOT approve, do NOT merge, do NOT summarize the PR. New findings only.

Reply:
"@

    $promptFile = Write-TempBody -Content $prompt
    try {
        # claude -p routes through the claudish proxy / worker infra with the
        # right provider env. -p = non-interactive (print mode), exits when done.
        # NB: PowerShell has no input-redirection operator (`<` is reserved) —
        # pipe the prompt via Get-Content -Raw instead.
        $answer = Get-Content -Raw -Path $promptFile | & claude -p --model $Model 2>&1
        return ($answer -as [string]).Trim()
    }
    finally {
        Remove-Item $promptFile -ErrorAction SilentlyContinue
    }
}

# --- Main ---

Write-Log "=== dig-deeper review bot (prototype #2505) started ===" "INFO"
Write-Log "Machine: $MachineName | Repo: $Repo | Model: $Model | Mode: $(if($DryRun){'DRY RUN'}else{'LIVE'})" "INFO"

# Eligible PR list
if ($PrNumber -gt 0) {
    $prList = @([pscustomobject]@{ number = $PrNumber; title = "(single-PR mode)" })
} else {
    $prListJson = Invoke-GhSafe @('pr','list','--repo',$Repo,'--state','open','--limit','50','--json','number,title')
    if ($null -eq $prListJson) { Write-Log "Failed to fetch PR list" "ERROR"; exit 1 }
    $prList = $prListJson | ConvertFrom-Json
    if ($prList.Count -eq 0) { Write-Log "No open PRs found" "INFO"; exit 2 }
}

$commented = 0
$acked = 0
$skipped = 0

foreach ($pr in $prList) {
    $n = $pr.number
    Write-Log "`n--- PR #$n : $($pr.title) ---" "INFO"

    # STEP 1 - READ FIRST (mandatory, verifiable)
    $existing = Get-ExistingReviewPoints -Number $n
    if ($null -eq $existing) { Write-Log "Failed to read existing reviews for #$n, skip" "WARN"; $skipped++; continue }

    Write-Log "STEP 1 [READ FIRST]: $($existing.Count) existing review/comment point(s) gathered on #$n" "INFO"
    if ($VerboseOutput -and $existing.Count -gt 0) {
        $existing | Select-Object -First 5 | ForEach-Object { Write-Log "  existing: $($_.Substring(0,[Math]::Min(110,$_.Length)))..." "INFO" }
    }

    $existingBlob = ($existing -join "`n")
    if ($existingBlob.Length -gt $MaxExistingPointsChars) {
        $existingBlob = $existingBlob.Substring(0, $MaxExistingPointsChars)
        Write-Log "Existing-points blob truncated to $MaxExistingPointsChars chars" "WARN"
    }

    # Fetch diff
    $diff = Invoke-GhSafe @('pr','diff',$n,'--repo',$Repo,'--color=never')
    if ($null -eq $diff) { Write-Log "Failed to fetch diff for #$n, skip" "WARN"; $skipped++; continue }
    if ($diff.Length -gt $MaxDiffChars) { $diff = $diff.Substring(0, $MaxDiffChars) }

    # STEP 2 - DIG DEEPER
    Write-Log "STEP 2 [DIG DEEPER]: querying $Model for NEW findings only..." "INFO"
    $answer = Invoke-DigDeeper -Number $n -PrTitle $pr.title -Diff $diff -ExistingPoints $existingBlob

    $nothingNew = (-not $answer) -or ($answer -ieq "NOTHING_NEW") -or ($answer.Length -lt 15)

    if ($nothingNew) {
        Write-Log "STEP 3: nothing genuinely new on #$n" "OK"
        if ($SilentIfEmpty) { $skipped++; continue }

        # Brief [ACK] referencing the existing review set (NOT a paraphrasing review)
        $ackBody = @"
## [ACK] dig-deeper by $BotIdentity — nothing new to add

Read $($existing.Count) existing review/comment point(s) on this PR and looked specifically for findings no one had raised. Nothing genuinely new surfaced — existing reviewers covered the ground.

*Comment-only bot (#2505). No approve, no merge.*
"@
        if ($DryRun) {
            Write-Log "[DRY RUN] Would post [ACK] on #$n" "INFO"
        } else {
            $f = Write-TempBody -Content $ackBody
            $r = Invoke-GhSafe @('pr','review',$n,'--repo',$Repo,'--comment','--body-file',$f)
            Remove-Item $f -ErrorAction SilentlyContinue
            if ($null -ne $r) { Write-Log "Posted [ACK] on #$n" "OK"; $acked++ }
            else { Write-Log "Failed to [ACK] #$n" "ERROR"; $skipped++ }
        }
        continue
    }

    # STEP 3 - POST new findings (comment-only, NEVER approve)
    $newBody = @"
## dig-deeper review by $BotIdentity

New findings only (read $($existing.Count) existing review/comment points first, dropped anything already covered):

$answer

*Comment-only bot (#2505). No approve, no merge — a human reviewer should assess.*
"@
    if ($DryRun) {
        Write-Log "[DRY RUN] Would COMMENT new findings on #$n" "WARN"
        if ($VerboseOutput) { Write-Host $newBody }
    } else {
        $f = Write-TempBody -Content $newBody
        $r = Invoke-GhSafe @('pr','review',$n,'--repo',$Repo,'--comment','--body-file',$f)
        Remove-Item $f -ErrorAction SilentlyContinue
        if ($null -ne $r) { Write-Log "COMMENTED new findings on #$n" "OK"; $commented++ }
        else { Write-Log "Failed to comment on #$n" "ERROR"; $skipped++ }
    }
}

Write-Log "`n=== dig-deeper bot complete ===" "INFO"
Write-Log "Total: $($prList.Count) | New-findings commented: $commented | [ACK]: $acked | Skipped: $skipped" "INFO"
exit 0
