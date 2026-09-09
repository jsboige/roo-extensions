#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Report merged PR attribution without trusting the PR author login alone (watchguard D13, #3381).

.DESCRIPTION
    gh identity is shared across machines and sessions (#3032: one hosts.yml per box,
    switched by several processes), so the PR author login is NOT a reliable
    production-attribution signal. This read-only script reconstructs attribution for
    merged PRs from the commit layer: distinct commit authors (login+email) and
    Co-Authored-By trailers found in commit messages.

    Watchguard D13 prescription (ai-01 03/09, triaged VALIDE-trivial web1 07/09):
    "Co-Authored-By or dedicated login, not creation login". Absence of implementation
    verified on main 2026-09-09.

.PARAMETER Days
    Look-back window in days for merged PRs. Default: 30.

.PARAMETER Owner
    GitHub owner. Default: jsboige.

.PARAMETER Repo
    GitHub repository. Default: roo-extensions.

.PARAMETER Json
    Emit the full per-PR payload (raw list) instead of the summary table.

.EXAMPLE
    ./production-attribution.ps1 -Days 14
    # Per-PR attribution table for the last 14 days of merged PRs.

.EXAMPLE
    ./production-attribution.ps1 -Json
    # Machine-readable attribution for the default 30-day window.
#>

[CmdletBinding()]
param(
    [int]$Days = 30,
    [string]$Owner = "jsboige",
    [string]$Repo = "roo-extensions",
    [switch]$Json
)

$ErrorActionPreference = "Stop"

$since = (Get-Date).AddDays(-$Days)

function Get-MergedPrs {
    $prs = @()
    $page = 1
    while ($true) {
        $batch = gh api "repos/$Owner/$Repo/pulls?state=closed&per_page=100&page=$page" `
            --jq '.[] | select(.merged_at != null) | {number, title, merged_at, author: .user.login}' 2>$null
        if (-not $batch) { break }
        $parsed = $batch | ConvertFrom-Json
        if (-not $parsed) { break }
        $prs += $parsed
        if ($parsed.Count -lt 100) { break }
        $page++
    }
    return $prs | Where-Object { [datetime]$_.merged_at -ge $since }
}

function Get-CommitAttribution {
    param([int]$Number)
    $commits = gh api "repos/$Owner/$Repo/pulls/$Number/commits?per_page=100" `
        --jq '[.[] | {msg: .commit.message, author: .commit.author.name, email: .commit.author.email}]' 2>$null
    if (-not $commits) { return @() }
    $parsed = $commits | ConvertFrom-Json
    $authors = $parsed | ForEach-Object { "$($_.author) <$($_.email)>" } | Select-Object -Unique
    $trailers = foreach ($c in $parsed) {
        foreach ($line in ($c.msg -split "`n")) {
            if ($line -match '^\s*Co-Authored-By:\s*(.+)$') { $matches[1].Trim() }
        }
    }
    return [pscustomobject]@{
        Authors     = ($authors -join "; ")
        CoAuthored  = (($trailers | Select-Object -Unique) -join "; ")
    }
}

$rows = @()
foreach ($pr in Get-MergedPrs) {
    $attr = Get-CommitAttribution -Number $pr.number
    if ($attr) {
        $rows += [pscustomobject]@{
            Number     = $pr.number
            MergedAt   = $pr.merged_at
            PrAuthor   = $pr.author
            CommitAuth = $attr.Authors
            CoAuthored = $attr.CoAuthored
            Title      = $pr.title
        }
    }
}

if ($rows.Count -eq 0) {
    Write-Host "No merged PR found in the last $Days day(s)."
    exit 0
}

if ($Json) {
    $rows | ConvertTo-Json -Depth 3
    exit 0
}

$rows | Sort-Object MergedAt -Descending | Format-Table Number, MergedAt, PrAuthor, CommitAuth, CoAuthored -AutoSize -Wrap
$loginOnly = ($rows | Where-Object { $_.PrAuthor -and $_.CommitAuth -and ($_.CommitAuth -notmatch "^$([regex]::Escape($_.PrAuthor))") }).Count
Write-Host ("$($rows.Count) merged PR(s) in window; $loginOnly where commit authors differ from the PR author login (shared-identity candidates).")