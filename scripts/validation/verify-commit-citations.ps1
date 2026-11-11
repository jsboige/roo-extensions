# =================================================================================================
#
#   verify-commit-citations.ps1
#
#   Issue: #1666 Phase A5 (EPIC remediation, pair with .claude/rules/agent-claim-discipline.md)
#
#   Purpose
#   -------
#   Anti-hallucination helper for agents AND reviewers. Given a block of text
#   (a dashboard post, [DONE] report, PR body, commit message, whatever), extract
#   every cited git SHA and every #NNN PR/issue reference, and verify each:
#
#     - SHA (7-40 hex) → `git cat-file -e <sha>` must succeed
#     - #NNN           → `gh pr view <N>` OR `gh issue view <N>` must resolve
#
#   Agents invoke this BEFORE posting [DONE]/[RESULT] with artefact citations,
#   per `.claude/rules/agent-claim-discipline.md`. Reviewers can invoke it
#   against any incoming report to detect hallucinated SHAs/PRs.
#
#   This script is read-only: no writes, no pushes, no state mutation.
#   Exit codes:
#     0 = all citations verified (or no citations found)
#     1 = one or more citations could not be verified → agent must NOT post
#     2 = usage error (missing input)
#
#   Usage
#   -----
#   # From stdin
#   echo "See commit 826894f51d4f4ab074318334c726ddce59fcf29d and PR #1605" |
#       powershell -File scripts/validation/verify-commit-citations.ps1
#
#   # From file
#   powershell -File scripts/validation/verify-commit-citations.ps1 -File claim.txt
#
#   # From inline argument
#   powershell -File scripts/validation/verify-commit-citations.ps1 -Text "..."
#
# =================================================================================================

[CmdletBinding()]
param(
    [string]$Text,
    [string]$File,
    [string]$Repo = "jsboige/roo-extensions",
    [switch]$Quiet
)

# Lot 7b (#4150) : la jambe issue passe par le module REST (0 point GraphQL) ;
# la jambe PR est un détail REST 3 champs — Get-PullRequestDetail paierait
# fichiers+revues+check-runs pour trois scalaires.
. "$PSScriptRoot\..\common\gh-issues.ps1"

function Write-Line { param([string]$Msg, [string]$Color = "White")
    if (-not $Quiet) { Write-Host $Msg -ForegroundColor $Color }
}

# ----- Gather input -----

$input = $null
if ($Text) {
    $input = $Text
} elseif ($File) {
    if (-not (Test-Path $File)) {
        Write-Error "File not found: $File"
        exit 2
    }
    $input = Get-Content -Path $File -Raw
} else {
    # Stdin
    $input = [Console]::In.ReadToEnd()
}

if (-not $input -or $input.Trim().Length -eq 0) {
    Write-Error "No input provided. Use -Text, -File, or pipe text via stdin."
    exit 2
}

# ----- Extract citations -----

# SHA patterns: 7-40 hex. We require at least 7 to avoid false positives on short hashes
# in log output. Word-boundary + lookahead to avoid matching inside longer strings
# (e.g., 64-char blobs).
$shaMatches = [regex]::Matches($input, '\b([0-9a-f]{7,40})\b') | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique

# PR/issue references: #NNN (not preceded by a hex char, not followed by alphanumeric)
$numMatches = [regex]::Matches($input, '(?<![#\w])#(\d{2,6})\b') | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique

if ($shaMatches.Count -eq 0 -and $numMatches.Count -eq 0) {
    Write-Line "No SHAs or #NNN references found. Nothing to verify." "Gray"
    exit 0
}

# ----- Verify SHAs -----

$results = @()

foreach ($sha in $shaMatches) {
    $evidence = ""
    $verified = $false
    try {
        $null = git cat-file -e $sha 2>&1
        if ($LASTEXITCODE -eq 0) {
            $subject = (git log -1 --format='%s' $sha 2>&1) | Out-String
            $evidence = $subject.Trim()
            $verified = $true
        }
    } catch { }
    $results += [PSCustomObject]@{
        Citation = $sha
        Type     = "SHA"
        Verified = $verified
        Evidence = if ($verified) { $evidence } else { "git cat-file -e failed" }
    }
}

# ----- Verify #NNN (try PR first, then issue) -----

foreach ($num in $numMatches) {
    $evidence = ""
    $verified = $false
    $kind = $null

    # Lot 7b : détail REST (404 = pas une PR -> exit non-nul, comme gh pr view).
    # MERGED reconstruit : REST rend open/closed + merged, gh rend MERGED.
    # Guillemets INCORPORÉS dans l'URL (le module les embédie aussi) : le `?`
    # sans espace n'est pas cité par PowerShell et casse l'argument sous cmd.
    $prUrl = '"repos/' + $Repo + '/pulls/' + $num + '"'
    # 2>$null APRÈS le pipeline : couvre l'invocation entière (#3731 — un
    # redirect DANS la parenthèse ne couvre pas l'erreur sous EAP=Stop 5.1,
    # exactement comme l'ancienne jambe `(gh pr view ... 2>$null) | Out-String`).
    $prJson = (gh api $prUrl --jq '{state: .state, merged: .merged, title: .title}') 2>$null | Out-String
    if ($LASTEXITCODE -eq 0 -and $prJson.Trim().Length -gt 0) {
        try {
            $obj = $prJson | ConvertFrom-Json
            $prState = if ($obj.merged) { 'MERGED' } elseif ("$($obj.state)" -eq 'open') { 'OPEN' } else { 'CLOSED' }
            $evidence = "[PR $prState] $($obj.title)"
            $verified = $true
            $kind = "PR"
        } catch { }
    }

    if (-not $verified) {
        $detail = Get-IssueDetail -Repo $Repo -Number $num
        if ($detail.Ok) {
            $evidence = "[Issue $($detail.Item.state)] $($detail.Item.title)"
            $verified = $true
            $kind = "Issue"
        }
    }

    $results += [PSCustomObject]@{
        Citation = "#$num"
        Type     = if ($kind) { $kind } else { "#NNN" }
        Verified = $verified
        Evidence = if ($verified) { $evidence } else { "neither PR nor Issue found" }
    }
}

# ----- Report -----

Write-Line ""
Write-Line "Citation verification report" "Cyan"
Write-Line ("Repo: {0}" -f $Repo) "Gray"
Write-Line ("Total citations: {0}" -f $results.Count) "Gray"
Write-Line ""

$unverified = $results | Where-Object { -not $_.Verified }
foreach ($r in $results) {
    $color = if ($r.Verified) { "Green" } else { "Red" }
    $mark = if ($r.Verified) { "OK" } else { "FAIL" }
    Write-Line ("  [{0}] {1,-12} {2}  --  {3}" -f $mark, $r.Type, $r.Citation, $r.Evidence) $color
}

Write-Line ""
if ($unverified.Count -eq 0) {
    Write-Line ("All {0} citations verified." -f $results.Count) "Green"
    exit 0
} else {
    Write-Line ("{0} unverified citation(s) — do NOT post this claim." -f $unverified.Count) "Red"
    Write-Line "Per .claude/rules/agent-claim-discipline.md: pas de SHA sans 'git cat-file -e'. Pas de PR sans URL 200. Pas de [DONE] sur une promesse." "Yellow"
    exit 1
}
