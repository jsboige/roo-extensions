<#
.SYNOPSIS
    Multi-repository worktree audit: inventory, classify, and delete only what is
    provably safe to delete.
.DESCRIPTION
    The seven worktree scripts already in this repo are each scoped to
    .claude/worktrees/ of a single repository:

      scripts/worktrees/check-worktrees.ps1          $worktreeDir = ".claude/worktrees"
      scripts/maintenance/cleanup-orphan-worktrees.ps1   "directories under .claude/worktrees/"
      scripts/claude/worktree-cleanup.ps1            $WorktreePath = ".claude/worktrees"
      scripts/worktrees/cleanup-worktree.ps1         per issue number, ../roo-extensions-wt

    None of them iterates over repositories, so none of them sees the bulk of the
    problem. Measured on myia-ai-01: CoursIA alone had 75 registered worktrees,
    scattered across D:/CoursIA-wt/, per-session scratchpads, C:/Users/.../Temp/
    and C:/wt*, plus one inside D:/CoursIA/.git/. A filesystem scan finds a
    handful of those; only `git worktree list`, asked of each repository, finds
    them all. The gap was scope, not tooling.

    Discovery therefore works in two stages: scan for REPOSITORIES (a directory
    holding a .git DIRECTORY -- a .git FILE means the directory is itself a
    worktree), then ask each repository for its worktrees. Worktrees living
    outside the scanned roots are still found, because git knows about them.

    Classification is delegated to worktree-classify.ps1 (pure, covered by
    scripts/testing/harness/test-worktree-classify.ps1, which runs in CI).

    Default mode is dry-run. -Apply deletes only GHOST / MERGED / MERGED-BY-PR
    entries, and only clean ones, behind the shared deletion guards of
    scripts/common/path-guards.ps1 (#2772 submodule, #2123 nesting).
.PARAMETER SearchRoots
    Where to look for repositories. Default: D:\, C:\dev, the user profile.
.PARAMETER Repos
    Explicit repository roots. Skips discovery entirely.
.PARAMETER MaxDepth
    Discovery depth below each search root. Default 3.
.PARAMETER Apply
    Perform deletions. Without it, nothing is modified.
.PARAMETER ReportPath
    Markdown report destination. Defaults to
    $ROOSYNC_SHARED_PATH/worktree-audit/<machine>-<date>.md, falling back to
    outputs/ inside this repository when the shared path is unavailable.
.PARAMETER SkipFetch
    Do not fetch before judging. Use only offline: a stale origin/<default>
    makes merged work look unmerged, which turns deletable worktrees into
    false "forgotten PR" reports.
.EXAMPLE
    pwsh -File scripts/maintenance/audit-worktrees-fleet.ps1
    pwsh -File scripts/maintenance/audit-worktrees-fleet.ps1 -Repos D:\roo-extensions -Apply
.NOTES
    Companion: scripts/maintenance/worktree-classify.ps1 (the decision table).
#>

[CmdletBinding()]
param(
    [string[]]$SearchRoots,
    [string[]]$Repos,
    [int]$MaxDepth = 3,
    [switch]$Apply,
    [string]$ReportPath,
    [switch]$SkipFetch
)

$ErrorActionPreference = 'Continue'

. "$PSScriptRoot\worktree-classify.ps1"
. "$PSScriptRoot\..\common\path-guards.ps1"

$Machine = $env:COMPUTERNAME
if (-not $Machine) { $Machine = 'unknown-machine' }
$Stamp = (Get-Date).ToString('yyyy-MM-dd-HHmm')

function Invoke-Git {
    <#
        Returns git's stdout lines. Callers wrap the result in @() because
        PowerShell unrolls a single-element array on return, and this file runs
        under Set-StrictMode (inherited from worktree-classify.ps1) where .Count
        on the resulting scalar string is a terminating error, not 1.
    #>
    param([string[]]$GitArgs)
    return @(& git @GitArgs 2>&1) | Where-Object { $_ -is [string] }
}

# ---------------------------------------------------------------------------
# Stage 1 -- discover repositories
# ---------------------------------------------------------------------------
function Find-GitEntries {
    <#
        One scan, two outputs:

          Repos        directories holding a .git DIRECTORY
          WorktreeDirs directories holding a .git FILE

        The second list exists because of a husk mode git cannot report. Measured
        on ai-01 (2026-08-14): D:/knots-2929-wt and D:/smt-reorg-wt each hold a
        working tree and a .git file pointing at D:/CoursIA/.git/worktrees/<name>,
        a directory that no longer exists. CoursIA lists 77 worktrees and neither
        is among them -- the registration is gone, so `git worktree list` reports
        nothing at all. Every worktree script in this repo enumerates git, so all
        of them are blind to these. Subtracting the registered set from this list
        is the only way to see them.
    #>
    param([string[]]$Roots, [int]$Depth)

    $repos     = [System.Collections.Generic.List[string]]::new()
    $worktrees = [System.Collections.Generic.List[string]]::new()

    foreach ($root in $Roots) {
        if (-not (Test-Path -LiteralPath $root)) { continue }
        Write-Host "  scanning $root (depth $Depth)..." -ForegroundColor DarkGray
        try {
            $hits = Get-ChildItem -LiteralPath $root -Recurse -Depth $Depth -Force -Filter '.git' -ErrorAction SilentlyContinue |
                Where-Object { $_.FullName -notmatch '[\\/]node_modules[\\/]' }
        } catch { continue }
        foreach ($h in $hits) {
            $parent = Split-Path -Parent $h.FullName
            if (-not $parent) { continue }
            if ($h.PSIsContainer) {
                if (-not $repos.Contains($parent)) { $repos.Add($parent) }
            } else {
                if (-not $worktrees.Contains($parent)) { $worktrees.Add($parent) }
            }
        }
    }
    return @{ Repos = $repos; WorktreeDirs = $worktrees }
}

$scannedWorktreeDirs = @()
if (-not $Repos -or $Repos.Count -eq 0) {
    if (-not $SearchRoots -or $SearchRoots.Count -eq 0) {
        $SearchRoots = @('D:\', 'C:\dev', $env:USERPROFILE) | Where-Object { $_ }
    }
    Write-Host "Discovering repositories..." -ForegroundColor Cyan
    $entries = Find-GitEntries -Roots $SearchRoots -Depth $MaxDepth
    $Repos = $entries.Repos
    $scannedWorktreeDirs = @($entries.WorktreeDirs)
}
Write-Host "Repositories: $($Repos.Count)  |  worktree directories on disk: $($scannedWorktreeDirs.Count)" -ForegroundColor Cyan

# ---------------------------------------------------------------------------
# Stage 2 -- per repository
# ---------------------------------------------------------------------------
function Get-DefaultRemoteBranch {
    param([string]$Repo)
    $sym = @(Invoke-Git @('-C', $Repo, 'symbolic-ref', '--quiet', 'refs/remotes/origin/HEAD'))
    if ($sym.Count -gt 0 -and $sym[0] -match 'refs/remotes/(origin/.+)$') { return $Matches[1] }
    foreach ($cand in @('origin/main', 'origin/master')) {
        $v = @(Invoke-Git @('-C', $Repo, 'rev-parse', '--verify', '--quiet', $cand))
        if ($v.Count -gt 0 -and $v[0].Trim()) { return $cand }
    }
    return $null
}

function Get-RepoSlug {
    param([string]$Repo)
    $url = @(Invoke-Git @('-C', $Repo, 'remote', 'get-url', 'origin'))
    if ($url.Count -eq 0) { return $null }
    if ($url[0] -match '[:/]([^/:]+/[^/]+?)(\.git)?\s*$') { return $Matches[1] }
    return $null
}

function Get-PullRequestIndex {
    <#
        One `gh pr list` per repository rather than one per branch: 40 branch
        worktrees would otherwise mean 40 network round-trips.
        Returns @{ branchName = @{ Number; State } }, empty when gh is
        unavailable or the repo has no GitHub remote -- in which case branches
        simply fall through to PR-FORGOTTEN, which is reported, never deleted.
    #>
    param([string]$Slug)

    $index = @{}
    if (-not $Slug) { return $index }
    try {
        $json = & gh pr list --repo $Slug --state all --limit 500 --json number,state,headRefName 2>$null
        if (-not $json) { return $index }
        foreach ($pr in ($json | ConvertFrom-Json)) {
            # Keep the most decisive state when a branch carries several PRs:
            # a merged PR proves the content landed, whatever was closed later.
            if ($index.ContainsKey($pr.headRefName) -and $index[$pr.headRefName].State -eq 'MERGED') { continue }
            $index[$pr.headRefName] = @{ Number = $pr.number; State = $pr.state }
        }
    } catch { }
    return $index
}

function Resolve-PullRequest {
    <#
        Index first, targeted query second.

        The bulk index is capped at 500 PRs. CoursIA is past #10500, so a branch
        whose PR is older than the last 500 is simply absent from it -- and
        "absent from the index" is what the classifier reads as "no PR", i.e.
        PR-FORGOTTEN. That misreports merged work as forgotten, and (harmlessly
        but noisily) keeps worktrees that could have gone.

        So a miss is not a conclusion: it triggers one `--head` query for that
        branch, cached including its negative result.
    #>
    param([string]$Slug, [string]$Branch, [hashtable]$Index, [hashtable]$Cache)

    if (-not $Slug -or -not $Branch) { return $null }
    if ($Index.ContainsKey($Branch))  { return $Index[$Branch] }
    if ($Cache.ContainsKey($Branch))  { return $Cache[$Branch] }

    $result = $null
    try {
        $json = & gh pr list --repo $Slug --head $Branch --state all --limit 10 --json number,state 2>$null
        if ($json) {
            $prs = @($json | ConvertFrom-Json)
            if ($prs.Count -gt 0) {
                $merged = @($prs | Where-Object { $_.state -eq 'MERGED' })
                $chosen = if ($merged.Count -gt 0) { $merged[0] } else { $prs[0] }
                $result = @{ Number = $chosen.number; State = $chosen.state }
            }
        }
    } catch { }

    $Cache[$Branch] = $result
    return $result
}

function Get-WorktreeEntries {
    param([string]$Repo)

    $entries = @()
    $current = $null
    foreach ($line in @(Invoke-Git @('-C', $Repo, 'worktree', 'list', '--porcelain'))) {
        if ($line -match '^worktree (.+)$') {
            if ($current) { $entries += $current }
            $current = [pscustomobject]@{ Path = $Matches[1].Trim(); Head = ''; Branch = ''; Detached = $false }
        } elseif ($current -and $line -match '^HEAD (.+)$') {
            $current.Head = $Matches[1].Trim()
        } elseif ($current -and $line -match '^branch refs/heads/(.+)$') {
            $current.Branch = $Matches[1].Trim()
        } elseif ($current -and $line -match '^detached') {
            $current.Detached = $true
        }
    }
    if ($current) { $entries += $current }
    return $entries
}

function Test-GitDirTarget {
    <#
        A worktree's .git is a FILE holding "gitdir: <path>". When that target is
        gone the worktree is a husk -- and git does NOT flag it prunable
        (measured: 0 prunable across 75 CoursIA entries, two of which were husks).
    #>
    param([string]$WorktreePath)

    $dotGit = Join-Path $WorktreePath '.git'
    if (-not (Test-Path -LiteralPath $dotGit)) { return $false }
    if (Test-Path -LiteralPath $dotGit -PathType Container) { return $true }   # main worktree
    $content = Get-Content -LiteralPath $dotGit -Raw -ErrorAction SilentlyContinue
    if ($content -match 'gitdir:\s*(.+)') { return (Test-Path -LiteralPath $Matches[1].Trim()) }
    return $false
}

$allResults = [System.Collections.Generic.List[psobject]]::new()

foreach ($repo in $Repos) {
    if (-not (Test-Path -LiteralPath (Join-Path $repo '.git'))) { continue }

    $entries = Get-WorktreeEntries -Repo $repo
    if ($entries.Count -le 1) {
        Write-Host "  $repo : no extra worktree" -ForegroundColor DarkGray
        continue
    }
    Write-Host "  $repo : $($entries.Count) entries" -ForegroundColor White

    if (-not $SkipFetch) { Invoke-Git @('-C', $repo, 'fetch', 'origin', '--quiet') | Out-Null }

    $default = Get-DefaultRemoteBranch -Repo $repo
    $slug    = Get-RepoSlug -Repo $repo
    $prIndex = Get-PullRequestIndex -Slug $slug
    $prCache = @{}

    $topLines = @(Invoke-Git @('-C', $repo, 'rev-parse', '--show-toplevel'))
    $mainPath = if ($topLines.Count -gt 0) { ConvertTo-NormalizedPath -Path $topLines[0].Trim() } else { ConvertTo-NormalizedPath -Path $repo }

    foreach ($e in $entries) {
        $exists = Test-Path -LiteralPath $e.Path

        $dirty = $false
        if ($exists) {
            $st = @(Invoke-Git @('-C', $e.Path, 'status', '--porcelain'))
            $dirty = ($st.Count -gt 0)
        }

        $isAncestor = $false
        $ahead = 0
        if ($default -and $e.Head) {
            & git -C $repo merge-base --is-ancestor $e.Head $default 2>$null
            $isAncestor = ($LASTEXITCODE -eq 0)
            if (-not $isAncestor) {
                $c = @(Invoke-Git @('-C', $repo, 'rev-list', '--count', "$default..$($e.Head)"))
                if ($c.Count -gt 0) { [int]::TryParse($c[0].Trim(), [ref]$ahead) | Out-Null }
            }
        }

        $prState = $null; $prNumber = 0
        if ($e.Branch) {
            $pr = Resolve-PullRequest -Slug $slug -Branch $e.Branch -Index $prIndex -Cache $prCache
            if ($pr) { $prState = $pr.State; $prNumber = $pr.Number }
        }

        $lastDate = ''
        if ($e.Head) {
            $d = @(Invoke-Git @('-C', $repo, 'log', '-1', '--format=%ci', $e.Head))
            if ($d.Count -gt 0) { $lastDate = $d[0].Trim() }
        }

        $facts = New-WorktreeFacts -Path $e.Path `
            -IsMainWorktree ((ConvertTo-NormalizedPath -Path $e.Path) -ieq $mainPath) `
            -DirectoryExists $exists `
            -GitDirTargetExists ($(if ($exists) { Test-GitDirTarget -WorktreePath $e.Path } else { $false })) `
            -IsDirty $dirty `
            -IsDetached $e.Detached `
            -Branch $e.Branch `
            -IsAncestorOfDefault $isAncestor `
            -CommitsAhead $ahead `
            -PrState $prState -PrNumber $prNumber `
            -Head $e.Head -LastCommitDate $lastDate

        $verdict = Get-WorktreeClass -Facts $facts

        $allResults.Add([pscustomobject]@{
            Repo = $repo; Slug = $slug; Default = $default
            Path = $e.Path; Branch = $e.Branch; Detached = $e.Detached
            Head = $e.Head; LastCommitDate = $lastDate
            CommitsAhead = $ahead; Dirty = $dirty
            PrNumber = $prNumber; PrState = $prState
            Class = $verdict.Class; Deletable = $verdict.Deletable
            NeedsRescueBranch = $verdict.NeedsRescueBranch; Reason = $verdict.Reason
            Applied = ''
        })
    }
}

# ---------------------------------------------------------------------------
# Stage 2b -- working trees on disk that no repository registers
# ---------------------------------------------------------------------------
if ($scannedWorktreeDirs.Count -gt 0) {
    $registered = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($r in $allResults) { [void]$registered.Add((ConvertTo-NormalizedPath -Path $r.Path)) }

    foreach ($dir in $scannedWorktreeDirs) {
        if ($registered.Contains((ConvertTo-NormalizedPath -Path $dir))) { continue }

        # A .git file is not proof of a worktree -- the pointer's shape is, and
        # that test lives in the classifier so the harness covers it.
        $content = Get-Content -LiteralPath (Join-Path $dir '.git') -Raw -ErrorAction SilentlyContinue
        $pointer = Get-WorktreePointerKind -DotGitContent $content
        if ($pointer.Kind -ne 'Worktree') { continue }
        $owner = $pointer.OwnerRepo

        $mtime = ''
        try { $mtime = (Get-Item -LiteralPath $dir).LastWriteTime.ToString('yyyy-MM-dd HH:mm') } catch { }

        $facts   = New-WorktreeFacts -Path $dir -IsRegistered $false -GitDirTargetExists $false
        $verdict = Get-WorktreeClass -Facts $facts

        $allResults.Add([pscustomobject]@{
            Repo = $(if ($owner) { $owner } else { '(unknown)' }); Slug = $null; Default = $null
            Path = $dir; Branch = ''; Detached = $false
            Head = ''; LastCommitDate = $mtime
            CommitsAhead = 0; Dirty = $false
            PrNumber = 0; PrState = $null
            Class = $verdict.Class; Deletable = $verdict.Deletable
            NeedsRescueBranch = $verdict.NeedsRescueBranch; Reason = $verdict.Reason
            Applied = ''
        })
        Write-Host "  ORPHAN-DIR $dir (was owned by $owner)" -ForegroundColor Yellow
    }
}

# ---------------------------------------------------------------------------
# Stage 3 -- act, only on the proven-safe classes
# ---------------------------------------------------------------------------
if ($Apply) {
    Write-Host ""
    Write-Host "Applying (deletable classes only)..." -ForegroundColor Yellow

    foreach ($r in @($allResults | Where-Object { $_.Deletable })) {
        # Guard #2772/#2123 -- refuse anything touching a submodule working tree.
        $verdict = Test-SafeDeletionPath -Path $r.Path -RepoRoot $r.Repo
        if (-not $verdict.Safe) {
            $r.Applied = "REFUSED: $($verdict.Reason)"
            Write-Host "  REFUSED $($r.Path) -- $($verdict.Reason)" -ForegroundColor Red
            continue
        }

        # Insurance against a misclassification: make the commits reachable
        # before the worktree that holds them goes away.
        if ($r.NeedsRescueBranch -and $r.Head) {
            $name = "rescue/$(Split-Path -Leaf $r.Path)-$($r.Head.Substring(0, [Math]::Min(8, $r.Head.Length)))"
            Invoke-Git @('-C', $r.Repo, 'branch', '-f', $name, $r.Head) | Out-Null
            $r.Applied = "rescue branch $name; "
        }

        # `worktree remove` WITHOUT --force: git refuses a dirty worktree. The
        # classifier already excluded those, so this only ever fires if the
        # classification was wrong -- which is exactly when we want it to fire.
        $out = @(Invoke-Git @('-C', $r.Repo, 'worktree', 'remove', $r.Path))
        if ($LASTEXITCODE -eq 0) {
            $r.Applied += 'removed'
            Write-Host "  removed $($r.Path)" -ForegroundColor Green
        } else {
            $r.Applied += "FAILED: $($out -join ' ')"
            Write-Host "  FAILED  $($r.Path) -- $($out -join ' ')" -ForegroundColor Red
        }
    }

    foreach ($repo in @($allResults | Select-Object -ExpandProperty Repo -Unique)) {
        Invoke-Git @('-C', $repo, 'worktree', 'prune') | Out-Null
    }
}

# ---------------------------------------------------------------------------
# Stage 4 -- report
# ---------------------------------------------------------------------------
if (-not $ReportPath) {
    $shared = $env:ROOSYNC_SHARED_PATH
    if ($shared -and (Test-Path -LiteralPath $shared)) {
        $dir = Join-Path $shared 'worktree-audit'
    } else {
        $dir = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'outputs'
    }
    if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $ReportPath = Join-Path $dir "$Machine-$Stamp.md"
}

$sb = [System.Text.StringBuilder]::new()
[void]$sb.AppendLine("# Worktree audit -- $Machine -- $Stamp")
[void]$sb.AppendLine()
[void]$sb.AppendLine("Mode: $(if ($Apply) { '**APPLY**' } else { 'dry-run' })  |  repositories scanned: $($Repos.Count)  |  worktree entries: $($allResults.Count)")
[void]$sb.AppendLine()
[void]$sb.AppendLine('## Totals by class')
[void]$sb.AppendLine()
[void]$sb.AppendLine('| Class | Count | Deletable |')
[void]$sb.AppendLine('|---|---|---|')
foreach ($g in @($allResults | Group-Object Class | Sort-Object Name)) {
    $del = @($g.Group | Where-Object { $_.Deletable }).Count
    [void]$sb.AppendLine("| $($g.Name) | $($g.Count) | $del |")
}
[void]$sb.AppendLine()

foreach ($section in @(
    @{ Title = 'Needs a decision -- unmerged work'; Classes = @('PR-FORGOTTEN', 'DETACHED-ORPHANABLE', 'PR-CLOSED') },
    @{ Title = 'Needs a decision -- uncommitted work'; Classes = @('DIRTY') },
    @{ Title = 'Needs a decision -- on disk, no repository registers them (git reports nothing)'; Classes = @('ORPHAN-DIR') },
    @{ Title = 'Kept -- open pull request'; Classes = @('PR-OPEN') },
    @{ Title = 'Deletable'; Classes = @('GHOST', 'MERGED', 'MERGED-BY-PR') },
    @{ Title = 'Unclassified'; Classes = @('UNDETERMINED') }
)) {
    $rows = @($allResults | Where-Object { $section.Classes -contains $_.Class })
    if ($rows.Count -eq 0) { continue }
    [void]$sb.AppendLine("## $($section.Title)  ($($rows.Count))")
    [void]$sb.AppendLine()
    [void]$sb.AppendLine('| Repo | Worktree | Branch / HEAD | Class | Ahead | Last commit (ORPHAN-DIR: dir mtime) | PR | Applied |')
    [void]$sb.AppendLine('|---|---|---|---|---|---|---|---|')
    foreach ($r in @($rows | Sort-Object Repo, Path)) {
        $ref = if ($r.Branch) { $r.Branch }
               elseif (-not $r.Head) { '(no ref -- registration gone)' }
               else { "(detached $($r.Head.Substring(0, [Math]::Min(8, $r.Head.Length))))" }
        $pr  = if ($r.PrNumber) { "#$($r.PrNumber) $($r.PrState)" } else { '-' }
        [void]$sb.AppendLine("| $(Split-Path -Leaf $r.Repo) | $($r.Path) | $ref | $($r.Class) | $($r.CommitsAhead) | $($r.LastCommitDate) | $pr | $($r.Applied) |")
    }
    [void]$sb.AppendLine()
}

# UTF-8 without BOM: Set-Content/Out-File would prepend one and break parsers.
[System.IO.File]::WriteAllText($ReportPath, $sb.ToString(), [System.Text.UTF8Encoding]::new($false))

Write-Host ""
Write-Host "=== SUMMARY ($Machine) ===" -ForegroundColor Cyan
$allResults | Group-Object Class | Sort-Object Name | ForEach-Object {
    Write-Host ("  {0,-22} {1,3}" -f $_.Name, $_.Count)
}
Write-Host "  report: $ReportPath" -ForegroundColor Cyan
if (-not $Apply) { Write-Host "  dry-run -- nothing was modified. Re-run with -Apply to delete the safe classes." -ForegroundColor Yellow }
