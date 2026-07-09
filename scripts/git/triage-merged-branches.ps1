#Requires -Version 5.1
<#
.SYNOPSIS
    Triage local git branches: classify as backup / merged-ancestor / squash-merged / unknown,
    and (with -Execute) delete only the ancestor-proven merged set.

.DESCRIPTION
    Addresses the recurring #2638 branch-backlog cleanup need (326+ stale local branches on
    ai-01 alone, tens on each executor). Manual per-branch `gh pr` proofs across coordination
    cycles are not viable; this is the scripted lane.

    Safe-by-construction:
      * DRY-RUN by default (report only, never deletes).
      * -Execute deletes ONLY the "merged-ancestor" set (branch tip is an ancestor of
        origin/main => content is fully preserved in main), using `git branch -d`, which
        itself refuses to delete anything not merged into HEAD/upstream. Double safety.
      * Backup-pattern branches (sauvegarde-*, recovery-*, backup-*, clean-*, reconciliation)
        are treated as intentional safety-nets and NEVER touched.
      * Squash-merged branches (NOT ancestors, but a MERGED PR exists for their head ref) are
        only REPORTED with their PR number by default. Deleting them requires the explicit
        -Execute -IncludeSquashMerged combination and uses `git branch -D` (the merged PR is
        the preservation proof; -d would refuse because squash rewrites history).
      * Unknown branches (no ancestor proof, no merged PR) are only reported, never deleted
        (they may hold unpushed work).

    DORMANT tool: intentionally NOT wired into any cron/recurring execution (destructive
    automation stays user-gated per .claude/rules + feedback_process_killing_automation_gate_first).
    Invoke manually, once per repo. Deleted branches remain recoverable via reflog (~90 days).

.PARAMETER RepoPath
    Path to the git repo whose local branches to triage. Default: current directory.
    Run once for the parent repo, once for each submodule (mcps/internal, etc.).

.PARAMETER GhRepo
    owner/repo slug for `gh pr list` (e.g. jsboige/roo-extensions or jsboige/jsboige-mcp-servers).

.PARAMETER Execute
    Actually delete the merged-ancestor set. Without this switch the script only reports.

.PARAMETER IncludeSquashMerged
    With -Execute, ALSO delete branches proven squash-merged via a MERGED PR (git branch -D).

.PARAMETER BackupPatterns
    Substrings; any branch whose name contains one is treated as a safety-net and skipped.

.EXAMPLE
    ./triage-merged-branches.ps1 -RepoPath d:/roo-extensions -GhRepo jsboige/roo-extensions
    # dry-run report for the parent repo

.EXAMPLE
    ./triage-merged-branches.ps1 -RepoPath d:/roo-extensions/mcps/internal -GhRepo jsboige/jsboige-mcp-servers -Execute
    # delete the ancestor-proven merged set in the submodule
#>
[CmdletBinding()]
param(
    [string]$RepoPath = ".",
    [Parameter(Mandatory = $true)][string]$GhRepo,
    [switch]$Execute,
    [switch]$IncludeSquashMerged,
    [string[]]$BackupPatterns = @('sauvegarde', 'recovery', 'backup', 'reconciliation', 'clean-repo', 'clean-main')
)

$ErrorActionPreference = 'Stop'

# Resolve absolute repo path up front so the helper closes over the final value.
$RepoPath = (Resolve-Path -LiteralPath $RepoPath).Path

function Invoke-Git {
    param([string[]]$GitArgs)
    # A non-zero git exit does NOT throw in PowerShell; callers inspect $LASTEXITCODE.
    & git -C $RepoPath @GitArgs 2>&1
}

Write-Host "== Branch triage: $RepoPath ($GhRepo) ==" -ForegroundColor Cyan
if ($Execute) { Write-Host "MODE: EXECUTE (deletes merged-ancestor set)" -ForegroundColor Red }
else { Write-Host "MODE: DRY-RUN (no deletions)" -ForegroundColor Yellow }

# 1. Fetch origin (read-only) so ancestor checks are accurate.
Write-Host "Fetching origin/main..." -ForegroundColor DarkGray
Invoke-Git @('fetch', 'origin', 'main', '--quiet') | Out-Null

# Never delete the checked-out branch.
$current = (Invoke-Git @('symbolic-ref', '--quiet', '--short', 'HEAD') | Out-String).Trim()
if ([string]::IsNullOrWhiteSpace($current)) { $current = '(detached)' }

# 2. Enumerate local branches (excluding main/master and the current branch).
$branches = @(Invoke-Git @('branch', '--format=%(refname:short)') |
    ForEach-Object { $_.ToString().Trim() } |
    Where-Object { $_ -and ($_ -notin @('main', 'master', $current)) })

# 3. Bulk-fetch merged PR head-ref names once (for squash-merge detection).
Write-Host "Fetching merged PR heads from $GhRepo..." -ForegroundColor DarkGray
$mergedByHead = @{}
try {
    $mergedPrs = & gh pr list --repo $GhRepo --state merged --limit 5000 --json headRefName,number 2>&1 | ConvertFrom-Json
    foreach ($pr in $mergedPrs) {
        if ($pr.headRefName -and -not $mergedByHead.ContainsKey($pr.headRefName)) {
            $mergedByHead[$pr.headRefName] = $pr.number
        }
    }
    Write-Host "  ($($mergedByHead.Count) distinct merged head refs)" -ForegroundColor DarkGray
} catch {
    Write-Warning "Could not fetch/parse merged PR list; squash-merge detection disabled. ($_)"
}

# 4. Classify.
$backupRegex = ($BackupPatterns | ForEach-Object { [regex]::Escape($_) }) -join '|'
$backup = @(); $ancestor = @(); $squash = @(); $unknown = @()

foreach ($b in $branches) {
    if ($backupRegex -and ($b -match $backupRegex)) { $backup += $b; continue }
    Invoke-Git @('merge-base', '--is-ancestor', $b, 'origin/main') | Out-Null
    if ($LASTEXITCODE -eq 0) { $ancestor += $b; continue }
    if ($mergedByHead.ContainsKey($b)) { $squash += [pscustomobject]@{ Branch = $b; Pr = $mergedByHead[$b] }; continue }
    $unknown += $b
}

# 5. Report.
Write-Host ""
Write-Host "SUMMARY ($($branches.Count) candidate branches, current='$current'):" -ForegroundColor Cyan
Write-Host ("  backup / safety-net (skip)     : {0}" -f $backup.Count)
Write-Host ("  merged-ancestor (safe delete)  : {0}" -f $ancestor.Count) -ForegroundColor Green
Write-Host ("  squash-merged (PR-proven)      : {0}" -f $squash.Count) -ForegroundColor Yellow
Write-Host ("  unknown (leave, inspect)       : {0}" -f $unknown.Count) -ForegroundColor Magenta

if ($ancestor.Count -gt 0) {
    Write-Host "`nMerged-ancestor branches (content preserved in origin/main):" -ForegroundColor Green
    $ancestor | ForEach-Object { Write-Host "  $_" }
}
if ($squash.Count -gt 0) {
    Write-Host "`nSquash-merged branches (MERGED PR exists; needs -IncludeSquashMerged to delete):" -ForegroundColor Yellow
    $squash | ForEach-Object { Write-Host ("  {0}  (PR #{1})" -f $_.Branch, $_.Pr) }
}
if ($unknown.Count -gt 0) {
    Write-Host "`nUnknown branches (NO merge proof - never auto-deleted, inspect manually):" -ForegroundColor Magenta
    $unknown | ForEach-Object { Write-Host "  $_" }
}

if (-not $Execute) {
    Write-Host "`nDry-run complete. Re-run with -Execute to delete the $($ancestor.Count) merged-ancestor branch(es)." -ForegroundColor Yellow
    if ($squash.Count -gt 0) { Write-Host "Add -IncludeSquashMerged to also delete the $($squash.Count) squash-merged branch(es)." -ForegroundColor Yellow }
    return
}

# 6. Execute: delete ancestor-proven set with the safe verb (git branch -d refuses unmerged).
$deleted = 0; $failed = 0
foreach ($b in $ancestor) {
    $out = Invoke-Git @('branch', '-d', $b)
    if ($LASTEXITCODE -eq 0) { Write-Host "  deleted $b" -ForegroundColor Green; $deleted++ }
    else { Write-Host "  FAILED  $b -> $out" -ForegroundColor Red; $failed++ }
}
if ($IncludeSquashMerged) {
    foreach ($item in $squash) {
        $out = Invoke-Git @('branch', '-D', $item.Branch)
        if ($LASTEXITCODE -eq 0) { Write-Host ("  deleted {0} (squash PR #{1})" -f $item.Branch, $item.Pr) -ForegroundColor Green; $deleted++ }
        else { Write-Host ("  FAILED  {0} -> {1}" -f $item.Branch, $out) -ForegroundColor Red; $failed++ }
    }
}
Write-Host "`nDeleted $deleted, failed $failed. Unknown ($($unknown.Count)) and backup ($($backup.Count)) left untouched." -ForegroundColor Cyan
Write-Host "Recover any deletion via reflog (~90d): git reflog / git branch <name> <sha>" -ForegroundColor DarkGray
