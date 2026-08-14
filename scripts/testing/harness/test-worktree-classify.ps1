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
# Test 8: a merged PR vouches for one commit, not for a branch
#
# Measured on ai-01 (CoursIA). Three worktrees sat on a merged PR at a commit
# that was NOT the PR's head. Counting commits in each direction, rather than
# comparing the two SHAs, splits them one against two:
#
#   pr9962                          ahead 1, behind 8   -> a commit the PR never had
#   pr9967                          ahead 0, behind 4   -> stale checkout, fully merged
#   feature/c-voting-density-10488  ahead 0, behind 45  -> stale checkout, fully merged
#
# "HEAD differs from the PR head" would call all three diverged and would be
# wrong twice: a checkout sitting behind is also a different SHA, and its
# content is entirely inside the merge.
# ============================================================================
Write-Host "=== Test 8: merged PR vs commits ahead of it ===" -ForegroundColor Cyan

$onPrHead = New-WorktreeFacts -Path 'D:/repo-wt/pr10010' -Branch 'pr10010' `
    -PrState 'MERGED' -PrNumber 10010 `
    -Head 'be526bb234fa3142dd4f3929cb735aa73c4a53e1' `
    -PrHeadOid 'be526bb234fa3142dd4f3929cb735aa73c4a53e1' `
    -PrHeadComparable $true -CommitsAheadOfPrHead 0 -CommitsAhead 3
$v = Get-WorktreeClass -Facts $onPrHead
Assert-Equal 'sitting on the PR head classifies MERGED-BY-PR' 'MERGED-BY-PR' $v.Class
Assert-Equal 'sitting on the PR head is deletable'            $true          $v.Deletable

# pr9967: behind, not ahead -- deletable despite a different SHA.
$behind = New-WorktreeFacts -Path 'D:/repo-wt/pr9967' -Branch 'pr9967' `
    -PrState 'MERGED' -PrNumber 9967 `
    -Head 'c7b525cf9812c22fefdc8bbfec1e433d5a96355f' `
    -PrHeadOid '0427c1920ebc730bcf6984f90f2b7721d4795489' `
    -PrHeadComparable $true -CommitsAheadOfPrHead 0 -CommitsAhead 7
$v = Get-WorktreeClass -Facts $behind
Assert-Equal 'behind the PR head is still MERGED-BY-PR' 'MERGED-BY-PR' $v.Class
Assert-Equal 'behind the PR head stays deletable'       $true          $v.Deletable

# The defect this pins: an inequality test calls the stale checkout diverged.
$sha = ($behind.Head -ne $behind.PrHeadOid)
Assert-Equal 'a SHA-inequality rule WOULD have called it diverged' $true $sha

# pr9962: one commit the PR never carried.
$diverged = New-WorktreeFacts -Path 'D:/repo-wt/pr9962' -Branch 'pr9962' `
    -PrState 'MERGED' -PrNumber 9962 `
    -Head '6ed747a339253edf1a52835b37210f02057ea821' `
    -PrHeadOid '4b7121381237863f92f198d321454a8ce0e99561' `
    -PrHeadComparable $true -CommitsAheadOfPrHead 1 -CommitsAhead 5
$v = Get-WorktreeClass -Facts $diverged
Assert-Equal 'ahead of the PR head classifies PR-MERGED-DIVERGED' 'PR-MERGED-DIVERGED' $v.Class
Assert-Equal 'ahead of the PR head is NOT deletable'              $false               $v.Deletable
Assert-Equal 'the reason names the PR and the count'              $true `
    ($v.Reason -match '#9962' -and $v.Reason -match '1 commit')

# The defect this pins: reading only PrState reports the branch as fully merged.
$naiveSaysMerged = ($diverged.PrState -eq 'MERGED')
Assert-Equal 'a PrState-only rule WOULD have called it fully merged' $true $naiveSaysMerged

# A PR head absent from the local object store makes the count meaningless; the
# classifier must fall back to the PR state, never invent a divergence.
$notComparable = New-WorktreeFacts -Path 'D:/repo-wt/y' -Branch 'wt/y' `
    -PrState 'MERGED' -PrNumber 42 -Head 'aaaaaaaa' -PrHeadOid 'bbbbbbbb' `
    -PrHeadComparable $false -CommitsAheadOfPrHead 0 -CommitsAhead 1
Assert-Equal 'an unfetchable PR head falls back to MERGED-BY-PR' 'MERGED-BY-PR' `
    (Get-WorktreeClass -Facts $notComparable).Class

# Dirty still outranks the divergence test, as it outranks every merge signal.
$dirtyDiverged = New-WorktreeFacts -Path 'D:/repo-wt/z' -Branch 'pr9962' -IsDirty $true `
    -PrState 'MERGED' -PrNumber 9962 -PrHeadComparable $true -CommitsAheadOfPrHead 1
Assert-Equal 'dirty still wins over divergence' 'DIRTY' (Get-WorktreeClass -Facts $dirtyDiverged).Class

# ============================================================================
# Test 9: prN branch names carry a PR number that no --head query can find
# ============================================================================
Write-Host "=== Test 9: prN branch names ===" -ForegroundColor Cyan

Assert-Equal 'pr9962 yields 9962'   9962  (Get-PrNumberFromBranchName -Branch 'pr9962')
Assert-Equal 'pr10010 yields 10010' 10010 (Get-PrNumberFromBranchName -Branch 'pr10010')

# Ordinary branch names must not be mistaken for PR references: resolving the
# wrong PR is how a worktree gets classified against someone else's merge.
foreach ($name in @('wt/worktree-audit', 'pr-fix-thing', 'prefetch', 'feature/pr123', 'pr', '')) {
    Assert-Equal "'$name' yields no PR number" 0 (Get-PrNumberFromBranchName -Branch $name)
}

# The defect this pins: a --head lookup on `pr9962` finds nothing, because the
# PR's own head ref is `feature/c9959-check-lane-paths`. Name-only resolution
# reports merged work as forgotten -- which is what ai-01 measured, 4 times.
$headRefNames = @('feature/c9959-check-lane-paths', 'lean/tricolorable-transfer-invariant')
$headLookupFinds = @($headRefNames | Where-Object { $_ -eq 'pr9962' }).Count
Assert-Equal 'a --head query on pr9962 finds nothing' 0 $headLookupFinds

# ============================================================================
# Test 10: a detached HEAD off the ancestry line is not evidence of lost work
# ============================================================================
# Measured on ai-01, 2026-08-14: seventeen detached worktrees were held back as
# possibly-orphanable. `git cherry origin/main <head>` showed FOURTEEN carried
# only patches already upstream -- squash-merged PR heads. Three held work that
# never landed: wt10305 (+2), CoursIA-wt10496 (+5), wt-tp (+1). Treating "not an
# ancestor" as "unmerged" over-reported the manual pile by a factor of five.
Write-Host "=== Test 10: detached HEAD resolved by patch identity ===" -ForegroundColor Cyan

# 736d6ddc: one commit, patch already on main.
$landed = New-WorktreeFacts -Path 'C:/lt6616' -IsDetached $true `
    -Head '736d6ddc' -CommitsAhead 1 -PatchesMeasured $true -PatchesNotLanded 0
$v = Get-WorktreeClass -Facts $landed
Assert-Equal 'every patch upstream classifies DETACHED-LANDED' 'DETACHED-LANDED' $v.Class
Assert-Equal 'DETACHED-LANDED is deletable'                    $true             $v.Deletable
Assert-Equal 'a rescue branch is still cut first'              $true             $v.NeedsRescueBranch

# The defect this pins: an ancestry-only rule sees commits off the line and
# reports work that is demonstrably already on main.
Assert-Equal 'an ancestry-only rule WOULD have held it back' $true ($landed.CommitsAhead -gt 0)

# 966b0ad0: five commits, none upstream. Real work, must stay in the manual pile.
$orphanable = New-WorktreeFacts -Path 'D:/CoursIA-wt10496' -IsDetached $true `
    -Head '966b0ad0' -CommitsAhead 5 -PatchesMeasured $true -PatchesNotLanded 5
$v = Get-WorktreeClass -Facts $orphanable
Assert-Equal 'unlanded patches stay DETACHED-ORPHANABLE' 'DETACHED-ORPHANABLE' $v.Class
Assert-Equal 'DETACHED-ORPHANABLE is never deletable'    $false                $v.Deletable
Assert-Equal 'the reason counts the unlanded patches'    $true ($v.Reason -match '5 commit')

# A partial landing is not a landing: one unlanded patch is enough to hold it.
$partial = New-WorktreeFacts -Path 'D:/CoursIA-wt/wt10305' -IsDetached $true `
    -Head '4185530e' -CommitsAhead 2 -PatchesMeasured $true -PatchesNotLanded 1
Assert-Equal 'one unlanded patch out of two still holds it back' 'DETACHED-ORPHANABLE' `
    (Get-WorktreeClass -Facts $partial).Class

# Unmeasured means unknown, and unknown must never mean deletable: if git cherry
# could not run, the worktree keeps its conservative class.
$unmeasured = New-WorktreeFacts -Path 'D:/repo-wt/u' -IsDetached $true `
    -Head 'cccccccc' -CommitsAhead 3 -PatchesMeasured $false -PatchesNotLanded 0
$v = Get-WorktreeClass -Facts $unmeasured
Assert-Equal 'unmeasured patch identity stays DETACHED-ORPHANABLE' 'DETACHED-ORPHANABLE' $v.Class
Assert-Equal 'unmeasured is not deletable'                         $false                $v.Deletable
Assert-Equal 'the reason says the measurement is missing' $true ($v.Reason -match 'unmeasured')

# The defect this pins: reading PatchesNotLanded without checking PatchesMeasured
# turns "never measured" into "zero unlanded", i.e. straight into deletable.
$naiveSaysLanded = ($unmeasured.PatchesNotLanded -eq 0)
Assert-Equal 'a count-only rule WOULD have called it landed' $true $naiveSaysLanded

# Dirty outranks patch identity too.
$dirtyLanded = New-WorktreeFacts -Path 'D:/repo-wt/dl' -IsDetached $true -IsDirty $true `
    -Head 'dddddddd' -CommitsAhead 1 -PatchesMeasured $true -PatchesNotLanded 0
Assert-Equal 'dirty wins over patch identity' 'DIRTY' (Get-WorktreeClass -Facts $dirtyLanded).Class

# ============================================================================
# Summary
# ============================================================================
Write-Host ""
Write-Host "=== SUMMARY ===" -ForegroundColor Cyan
Write-Host "  Passed: $TestsPassed" -ForegroundColor Green
Write-Host "  Failed: $TestsFailed" -ForegroundColor $(if ($TestsFailed -gt 0) { "Red" } else { "Green" })

if ($TestsFailed -gt 0) { exit 1 } else { exit 0 }
