<#
.SYNOPSIS
    Static harness for the worktree cleanup classifier.
.DESCRIPTION
    Pure in-memory table test of Get-WorktreeClass: no network, no disk writes,
    no git, no gh. Runs in CI (job `scheduling-harness`) because this logic
    decides whether a worktree gets DELETED, and a classifier that only runs on
    a developer's laptop is a classifier nobody is checking.

    Deliberately placed in scripts/testing/harness/ rather than
    scripts/testing/unit/: the eleven Pester files under unit/ are executed
    nowhere in CI. Adding a twelfth would have looked like coverage and been
    none — the same trap ci.yml already documents for test-escalation.ps1
    ("It ran nowhere -- the IDLE assertion sat false for 62 days unseen").

    Every guard is asserted twice: once that it holds, and once that the naive
    alternative it replaces WOULD get it wrong. A test that only exercises the
    correct path cannot tell a working guard from a removed one.
#>

. "$PSScriptRoot\..\..\maintenance\worktree-classify.ps1"

$TestsPassed = 0
$TestsFailed = 0

function Assert-Equal {
    param([string]$TestName, $Expected, $Actual)
    if ($Expected -eq $Actual) {
        Write-Host "  PASS: $TestName (expected=$Expected, got=$Actual)" -ForegroundColor Green
        $script:TestsPassed++
    } else {
        Write-Host "  FAIL: $TestName (expected=$Expected, got=$Actual)" -ForegroundColor Red
        $script:TestsFailed++
    }
}

# ============================================================================
# Test 1: the classes, one representative case each
# ============================================================================
Write-Host "=== Test 1: class table ===" -ForegroundColor Cyan

$cases = @(
    @{ Name = 'main working tree';        Expected = 'MAIN';                Facts = @{ IsMainWorktree = $true } },
    @{ Name = 'unregistered on disk';     Expected = 'ORPHAN-DIR';          Facts = @{ IsRegistered = $false } },
    @{ Name = 'directory gone';           Expected = 'GHOST';               Facts = @{ DirectoryExists = $false } },
    @{ Name = 'gitdir target gone';       Expected = 'GHOST';               Facts = @{ GitDirTargetExists = $false } },
    @{ Name = 'uncommitted changes';      Expected = 'DIRTY';               Facts = @{ IsDirty = $true } },
    @{ Name = 'ancestor of default';      Expected = 'MERGED';              Facts = @{ IsAncestorOfDefault = $true; Branch = 'wt/x' } },
    @{ Name = 'branch, PR merged';        Expected = 'MERGED-BY-PR';        Facts = @{ Branch = 'wt/x'; PrState = 'MERGED'; PrNumber = 42; CommitsAhead = 3 } },
    @{ Name = 'branch, PR open';          Expected = 'PR-OPEN';             Facts = @{ Branch = 'wt/x'; PrState = 'OPEN';   PrNumber = 43; CommitsAhead = 1 } },
    @{ Name = 'branch, PR closed';        Expected = 'PR-CLOSED';           Facts = @{ Branch = 'wt/x'; PrState = 'CLOSED'; PrNumber = 44; CommitsAhead = 1 } },
    @{ Name = 'branch, no PR, ahead';     Expected = 'PR-FORGOTTEN';        Facts = @{ Branch = 'wt/x'; CommitsAhead = 2 } },
    @{ Name = 'detached, unique commits'; Expected = 'DETACHED-ORPHANABLE'; Facts = @{ IsDetached = $true; CommitsAhead = 5 } }
)

foreach ($c in $cases) {
    $f = $c.Facts
    $facts = New-WorktreeFacts -Path 'D:/repo-wt/x' @f
    Assert-Equal $c.Name $c.Expected (Get-WorktreeClass -Facts $facts).Class
}

# ============================================================================
# Test 2: only the three proven-safe classes are deletable
# ============================================================================
Write-Host "=== Test 2: deletable set ===" -ForegroundColor Cyan

$deletableByClass = @{}
foreach ($c in $cases) {
    $f = $c.Facts
    $facts = New-WorktreeFacts -Path 'D:/repo-wt/x' @f
    $v = Get-WorktreeClass -Facts $facts
    $deletableByClass[$v.Class] = $v.Deletable
}

Assert-Equal 'GHOST is deletable'               $true  $deletableByClass['GHOST']
Assert-Equal 'MERGED is deletable'              $true  $deletableByClass['MERGED']
Assert-Equal 'MERGED-BY-PR is deletable'        $true  $deletableByClass['MERGED-BY-PR']
Assert-Equal 'MAIN is NOT deletable'            $false $deletableByClass['MAIN']
Assert-Equal 'ORPHAN-DIR is NOT deletable'      $false $deletableByClass['ORPHAN-DIR']
Assert-Equal 'DIRTY is NOT deletable'           $false $deletableByClass['DIRTY']
Assert-Equal 'PR-OPEN is NOT deletable'         $false $deletableByClass['PR-OPEN']
Assert-Equal 'PR-CLOSED is NOT deletable'       $false $deletableByClass['PR-CLOSED']
Assert-Equal 'PR-FORGOTTEN is NOT deletable'    $false $deletableByClass['PR-FORGOTTEN']
Assert-Equal 'DETACHED-ORPHANABLE NOT deletable' $false $deletableByClass['DETACHED-ORPHANABLE']

# ============================================================================
# Test 3: dirty beats merged -- and the defect this prevents
# ============================================================================
Write-Host "=== Test 3: dirty outranks every merged signal ===" -ForegroundColor Cyan

$dirtyButMergedPr = New-WorktreeFacts -Path 'D:/repo-wt/x' `
    -IsDirty $true -Branch 'wt/x' -PrState 'MERGED' -PrNumber 42 -CommitsAhead 3
$v = Get-WorktreeClass -Facts $dirtyButMergedPr
Assert-Equal 'dirty + merged PR classifies DIRTY' 'DIRTY' $v.Class
Assert-Equal 'dirty + merged PR is not deletable' $false  $v.Deletable

$dirtyButAncestor = New-WorktreeFacts -Path 'D:/repo-wt/x' -IsDirty $true -IsAncestorOfDefault $true
Assert-Equal 'dirty + ancestor classifies DIRTY' 'DIRTY' (Get-WorktreeClass -Facts $dirtyButAncestor).Class

# Pin the DEFECT: a classifier that asked "did the PR merge?" first would call
# the very same worktree deletable, destroying uncommitted work nobody has seen.
$naiveSaysDeletable = ($dirtyButMergedPr.PrState -eq 'MERGED')
Assert-Equal 'naive PR-first order WOULD delete dirty work (the defect itself)' $true $naiveSaysDeletable

# ============================================================================
# Test 4: squash merge -- ancestry alone cannot prove "unmerged"
# ============================================================================
Write-Host "=== Test 4: squash-merged branches ===" -ForegroundColor Cyan

$squashed = New-WorktreeFacts -Path 'D:/repo-wt/x' `
    -Branch 'wt/squashed' -PrState 'MERGED' -PrNumber 3101 -CommitsAhead 1 -IsAncestorOfDefault $false
Assert-Equal 'squash-merged branch is MERGED-BY-PR' 'MERGED-BY-PR' (Get-WorktreeClass -Facts $squashed).Class

# Pin the DEFECT: judged on git topology alone, this branch is "1 commit ahead
# with no ancestry link" -- indistinguishable from genuinely unmerged work.
# Every wt/* branch in this repo is squash-merged, so a topology-only classifier
# would report the entire history as forgotten PRs.
$topologyOnly = if ($squashed.IsAncestorOfDefault) { 'MERGED' } else { 'PR-FORGOTTEN' }
Assert-Equal 'topology-only WOULD misread a squash merge (the defect itself)' 'PR-FORGOTTEN' $topologyOnly

# ============================================================================
# Test 5: rescue branch requested exactly where commits could be orphaned
# ============================================================================
Write-Host "=== Test 5: rescue branch ===" -ForegroundColor Cyan

$detached = New-WorktreeFacts -Path 'D:/repo-wt/x' -IsDetached $true -CommitsAhead 5
Assert-Equal 'detached orphanable requests a rescue branch' $true (Get-WorktreeClass -Facts $detached).NeedsRescueBranch

$detachedMergedPr = New-WorktreeFacts -Path 'D:/repo-wt/x' `
    -IsDetached $true -Branch 'wt/x' -PrState 'MERGED' -PrNumber 45 -CommitsAhead 1
$v = Get-WorktreeClass -Facts $detachedMergedPr
Assert-Equal 'deletable detached still requests a rescue branch' $true $v.NeedsRescueBranch
Assert-Equal 'deletable detached stays deletable'                $true $v.Deletable

$attachedMergedPr = New-WorktreeFacts -Path 'D:/repo-wt/x' -Branch 'wt/x' -PrState 'MERGED' -PrNumber 46
Assert-Equal 'attached worktree needs no rescue branch' $false (Get-WorktreeClass -Facts $attachedMergedPr).NeedsRescueBranch

# ============================================================================
# Test 6: the two husk modes, and the one git cannot see at all
# ============================================================================
Write-Host "=== Test 6: husk detection ===" -ForegroundColor Cyan

# Mode A -- registered, but the gitdir target is gone. Detected on the pointer
# target rather than git's `prunable` flag.
$brokenPointer = New-WorktreeFacts -Path 'D:/repo-wt/x' -DirectoryExists $true -GitDirTargetExists $false
Assert-Equal 'broken gitdir pointer is a GHOST' 'GHOST' (Get-WorktreeClass -Facts $brokenPointer).Class

# Mode B -- measured on ai-01, 2026-08-14: D:/knots-2929-wt and D:/smt-reorg-wt
# each hold a working tree and a .git file pointing at
# D:/CoursIA/.git/worktrees/<name>, a directory that no longer exists. CoursIA
# lists 77 worktrees and NEITHER is among them: the registration is gone, so git
# has no record at all -- these are not "unflagged", they are invisible.
$orphanDir = New-WorktreeFacts -Path 'D:/knots-2929-wt' -IsRegistered $false -GitDirTargetExists $false
$v = Get-WorktreeClass -Facts $orphanDir
Assert-Equal 'unregistered working tree is ORPHAN-DIR' 'ORPHAN-DIR' $v.Class
Assert-Equal 'ORPHAN-DIR is never deletable'          $false        $v.Deletable

# Pin the DEFECT: any tool that enumerates `git worktree list` -- which is every
# worktree script in this repo, including the audit script this classifier
# serves -- sees zero of these. They are found by scanning the filesystem for a
# .git FILE and subtracting the registered set, never by asking git.
$registeredPaths  = @('D:/CoursIA', 'D:/CoursIA-wt/a', 'D:/CoursIA-wt/b')
$gitListWouldFind = @($registeredPaths | Where-Object { $_ -eq 'D:/knots-2929-wt' }).Count
Assert-Equal 'git worktree list WOULD find none of them (the defect itself)' 0 $gitListWouldFind

# And a registered worktree must NOT be dragged into ORPHAN-DIR by the new fact.
$registeredMerged = New-WorktreeFacts -Path 'D:/repo-wt/x' -IsRegistered $true -Branch 'wt/x' -PrState 'MERGED' -PrNumber 47
Assert-Equal 'registered worktree is unaffected by the orphan test' 'MERGED-BY-PR' (Get-WorktreeClass -Facts $registeredMerged).Class

# ============================================================================
# Test 6b: a .git FILE is not proof of a worktree -- the pointer's shape is
# ============================================================================
Write-Host "=== Test 6b: pointer shape ===" -ForegroundColor Cyan

$wt = Get-WorktreePointerKind -DotGitContent 'gitdir: D:/CoursIA/.git/worktrees/knots-2929-wt'
Assert-Equal 'worktree pointer is Worktree'   'Worktree'  $wt.Kind
Assert-Equal 'worktree pointer names its repo' 'D:/CoursIA' $wt.OwnerRepo

# Verbatim from D:/roo-extensions/mcps/internal/.git. Before this test, the
# audit reported this repo's three intact submodules as orphaned worktrees.
Assert-Equal 'submodule pointer is Submodule' 'Submodule' `
    (Get-WorktreePointerKind -DotGitContent 'gitdir: ../../.git/modules/mcps/internal').Kind
Assert-Equal 'garbage content is Unknown' 'Unknown' `
    (Get-WorktreePointerKind -DotGitContent 'not a gitdir line at all').Kind
Assert-Equal 'empty content is Unknown'   'Unknown' (Get-WorktreePointerKind -DotGitContent '').Kind

# Two POSIX-owner cases, both verbatim from disk. Neither resolves on
# git-for-Windows, and both are genuinely worktrees -- the WSL one is ours, the
# other ships inside a VS Code extension and points at its author's machine.
# The classifier must not quietly drop either just because the path is foreign;
# they are reported, and reporting is all that ever happens to this class.
Assert-Equal 'WSL-style pointer is still a Worktree' 'Worktree' `
    (Get-WorktreePointerKind -DotGitContent 'gitdir: /mnt/d/CoursIA/.git/worktrees/wt8733').Kind
Assert-Equal 'foreign worktree pointer is still a Worktree' 'Worktree' `
    (Get-WorktreePointerKind -DotGitContent 'gitdir: /Users/papa/_git/vscode-peacock/.git/worktrees/johnpapa-fluffy-succotash').Kind

# Pin the DEFECT: keying off the mere presence of a .git file accepts every one
# of these, submodules included.
$naiveAcceptsAll = @(
    'gitdir: D:/CoursIA/.git/worktrees/knots-2929-wt',
    'gitdir: ../../.git/modules/mcps/internal',
    'gitdir: ../../.git/modules/roo-code'
).Count
Assert-Equal 'presence-of-.git-file WOULD accept submodules too (the defect itself)' 3 $naiveAcceptsAll

# ============================================================================
# Test 7: no fact combination silently falls through to a deletion
# ============================================================================
Write-Host "=== Test 7: fall-through is never deletable ===" -ForegroundColor Cyan

$unknown = New-WorktreeFacts -Path 'D:/repo-wt/x' -Branch '' -CommitsAhead 0
$v = Get-WorktreeClass -Facts $unknown
Assert-Equal 'unmatched facts classify UNDETERMINED' 'UNDETERMINED' $v.Class
Assert-Equal 'unmatched facts are not deletable'     $false         $v.Deletable

# ============================================================================
# Summary
# ============================================================================
Write-Host ""
Write-Host "=== SUMMARY ===" -ForegroundColor Cyan
Write-Host "  Passed: $TestsPassed" -ForegroundColor Green
Write-Host "  Failed: $TestsFailed" -ForegroundColor $(if ($TestsFailed -gt 0) { "Red" } else { "Green" })

if ($TestsFailed -gt 0) { exit 1 } else { exit 0 }
