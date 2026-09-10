#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Flag open issues that look like discussions that never got actioned (watchguard D4, #3381).

.DESCRIPTION
    An issue is flagged when ALL of the following hold:
      - comments_count >= -MinComments (default 10)
      - no cross-referenced pull request in its timeline (cross_ref_pr_count == 0)
      - age >= -MinAgeDays days (default 30)

    This is the derived view prescribed as watchguard D4 in the #3381 §7.C triage
    (web1 c.355, triaged VALIDE-trivial 02/09, absence of implementation verified
    on main 2026-09-09). Read-only: this script only reads GitHub.

    A "discussion without PR" is the Epic's core failure mode: an issue that
    generated sustained exchange but never produced a pull request.

    Reporting contract (anti self-unflag): naming a flagged issue inside a
    report PR creates a cross-referenced event in its timeline, which would
    silently un-flag it on the next run. Cross-references whose source PR
    title mentions "watchguard" are treated as report artifacts and ignored
    — a report PR must not mutate the state it measures. Execution PRs
    (fixes, features) keep un-flagging normally.

.PARAMETER MinComments
    Minimum comment count to consider an issue a discussion. Default: 10.

.PARAMETER MinAgeDays
    Minimum age in days for the issue to be flagged. Default: 30.

.PARAMETER Owner
    GitHub owner. Default: jsboige.

.PARAMETER Repo
    GitHub repository. Default: roo-extensions.

.EXAMPLE
    ./flag-discussion-without-pr.ps1
    # Lists open issues with >= 10 comments, no linked PR, older than 30 days.

.EXAMPLE
    ./flag-discussion-without-pr.ps1 -MinComments 5 -MinAgeDays 14
    # Tightens both thresholds to catch younger discussions.
#>

[CmdletBinding()]
param(
    [int]$MinComments = 10,
    [int]$MinAgeDays = 30,
    [string]$Owner = "jsboige",
    [string]$Repo = "roo-extensions"
)

$ErrorActionPreference = "Stop"

function Get-OpenIssues {
    $issues = @()
    $page = 1
    while ($true) {
        $batch = gh api "repos/$Owner/$Repo/issues?state=open&per_page=100&page=$page" --jq '.[] | select(.pull_request == null) | {number, title, created_at, comments}' 2>$null
        if (-not $batch) { break }
        $parsed = $batch | ConvertFrom-Json
        if (-not $parsed) { break }
        $issues += $parsed
        if ($parsed.Count -lt 100) { break }
        $page++
    }
    return $issues
}

function Get-CrossReferencedPrCount {
    param([int]$Number)
    # Raw JSON + PS filtering: embedded double quotes in a --jq expression are
    # stripped by the PowerShell 5.1 -> native argument pass ("function not
    # defined: referenced/0"), so no --jq for expressions containing string
    # literals.
    # Timeline is paginated like issue enumeration: a candidate can carry more
    # than 100 events and a late cross-reference must not be missed (8/36
    # candidates exceeded one page at review time).
    $count = 0
    $page = 1
    while ($true) {
        $raw = gh api "repos/$Owner/$Repo/issues/$Number/timeline?per_page=100&page=$page" 2>$null
        if (-not $raw) { break }
        $events = $raw | ConvertFrom-Json
        if (-not $events) { break }
        $count += @($events | Where-Object {
            $_.event -eq 'cross-referenced' `
            -and $_.source.issue.pull_request `
            -and ($_.source.issue.title -notmatch 'watchguard')
        }).Count
        if (@($events).Count -lt 100) { break }
        $page++
    }
    return $count
}

# Main guard: dot-sourcing (unit tests) loads the functions only.
if ($MyInvocation.InvocationName -ne '.') {
    $now = Get-Date
    $flagged = @()
    foreach ($issue in Get-OpenIssues) {
        if ($issue.comments -lt $MinComments) { continue }
        $ageDays = ($now - ([datetime]$issue.created_at)).TotalDays
        if ($ageDays -lt $MinAgeDays) { continue }
        $crossRefCount = Get-CrossReferencedPrCount -Number $issue.number
        if ($crossRefCount -eq 0) {
            $flagged += [pscustomobject]@{
                Number      = $issue.number
                Comments    = $issue.comments
                AgeDays     = [math]::Round($ageDays, 1)
                CrossRefPrs = 0
                Title       = $issue.title
            }
        }
    }

    if ($flagged.Count -eq 0) {
        Write-Host "No open issue matches: comments >= $MinComments, no cross-referenced PR, age >= $MinAgeDays days."
        exit 0
    }

    $flagged | Sort-Object AgeDays -Descending | Format-Table Number, Comments, AgeDays, CrossRefPrs, Title -AutoSize
    Write-Host ($flagged.Count.ToString() + " issue(s) look like discussions that never produced a pull request.")
}