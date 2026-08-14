<#
.SYNOPSIS
    Pure classification of a git worktree into a cleanup class.
.DESCRIPTION
    Dot-source this file and call Get-WorktreeClass with a fact object. The
    function performs NO I/O: every fact it needs is passed in. That is what
    makes the logic that decides to DELETE WORK testable without a disk, a
    network, or a GitHub token.

    Fact gathering lives in audit-worktrees-fleet.ps1; the table below is the
    only place where a class is decided.

    Order matters, and the order is the safety property:

      0. main worktree of the repo          -> MAIN                 keep
      0b. on disk but no repo registers it  -> ORPHAN-DIR           keep, report
      1. directory gone, or gitdir target   -> GHOST                delete (safe)
         no longer exists
      2. uncommitted or untracked files     -> DIRTY                keep
      3. HEAD is an ancestor of the default -> MERGED               delete (safe)
         remote branch
      4. branch whose PR is MERGED, holding  -> MERGED-BY-PR        delete (safe)
         no commit the PR head cannot reach
      4b. branch whose PR is MERGED but that -> PR-MERGED-DIVERGED  keep, report
         holds commits ahead of the PR head
      5. branch whose PR is OPEN            -> PR-OPEN              keep
      6. branch whose PR is CLOSED unmerged -> PR-CLOSED            keep, report
      7. branch, no PR, commits ahead       -> PR-FORGOTTEN         keep, report
      8. detached, every commit's patch is  -> DETACHED-LANDED      delete (safe)
         already on the default branch
      8b. detached, commits not in default  -> DETACHED-ORPHANABLE  keep, report
      -  anything else                      -> UNDETERMINED         keep

    Four rules carry the weight:

    * DIRTY is tested BEFORE any "merged" test. A worktree whose PR is merged
      can still hold uncommitted work; deleting it because the PR landed would
      destroy exactly the changes nobody has seen yet.

    * Ancestry alone cannot prove "unmerged". A squash-merged branch keeps
      commits that are not ancestors of the default branch even though its
      content landed. Rule 4 therefore asks GitHub for the PR state, which is
      authoritative, before rule 7 concludes anything from git topology.

    * A merged PR only vouches for the commit it merged. Commits the PR head
      cannot reach were never in that PR and were never reviewed, so reporting
      the worktree as fully merged is wrong.

      "Ahead of the PR head", not "different from the PR head": measured on
      ai-01, of three worktrees whose HEAD differed from their merged PR's head,
      only ONE was ahead (pr9962, +1). The other two were stale checkouts
      sitting 4 and 45 commits behind -- their content is entirely inside the
      merge. Reading SHA inequality as divergence misclassified two of three.

      Note this is a reporting refinement, not a data-loss guard: removing a
      worktree never deletes its branch, so those commits survive either way.
      The guard against actual loss is the rescue branch on detached worktrees,
      which never reach this rule (they have no branch, so no PR).

    * A detached HEAD is not evidence of unmerged work. Counting commits that
      are not ANCESTORS of the default branch is the same squash-merge trap as
      above, and for detached worktrees no PR state is available to escape it:
      there is no branch name to look a PR up by.

      Patch identity escapes it. `git cherry <default> <head>` marks each commit
      "-" when an equivalent patch already exists upstream and "+" when it does
      not. Measured on ai-01, of SEVENTEEN detached worktrees held back as
      possibly-orphanable work, FOURTEEN carried patches already on main -- they
      were squash-merged PR heads. Only three held work that never landed.
      Reading "not an ancestor" as "unmerged" over-reported by a factor of five.

      Deleting one of these is safe on two independent grounds: the content is
      provably upstream, AND the rescue branch is created first, so the commits
      remain reachable even if patch identity were wrong.
.NOTES
    Companion harness: scripts/testing/harness/test-worktree-classify.ps1
#>

Set-StrictMode -Version Latest

function New-WorktreeFacts {
    <#
    .SYNOPSIS
        Builds a complete fact object with explicit defaults.
    .DESCRIPTION
        Every caller goes through this so that a forgotten field is a documented
        default rather than a StrictMode explosion deep inside the classifier.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path,
        [bool]$IsMainWorktree     = $false,
        # $false only for a directory found on disk that no repository lists.
        [bool]$IsRegistered       = $true,
        [bool]$DirectoryExists    = $true,
        [bool]$GitDirTargetExists = $true,
        [bool]$IsDirty            = $false,
        [bool]$IsDetached         = $false,
        [string]$Branch           = '',
        [bool]$IsAncestorOfDefault = $false,
        [int]$CommitsAhead        = 0,
        # $null = no PR found; otherwise MERGED / OPEN / CLOSED
        [string]$PrState          = $null,
        [int]$PrNumber            = 0,
        # The commit the PR actually carried, and how many commits this worktree
        # holds that are NOT reachable from it. Comparable = $false when the PR
        # head is not in the local object store, so the count means nothing.
        [string]$PrHeadOid        = '',
        [bool]$PrHeadComparable   = $false,
        [int]$CommitsAheadOfPrHead = 0,
        # Patch identity against the default branch, for detached worktrees.
        # Measured = $false when git cherry could not run, in which case the
        # count means nothing and the worktree stays in the manual pile.
        [bool]$PatchesMeasured    = $false,
        [int]$PatchesNotLanded    = 0,
        [string]$Head             = '',
        [string]$LastCommitDate   = ''
    )
    return [pscustomobject]@{
        Path                = $Path
        IsMainWorktree      = $IsMainWorktree
        IsRegistered        = $IsRegistered
        DirectoryExists     = $DirectoryExists
        GitDirTargetExists  = $GitDirTargetExists
        IsDirty             = $IsDirty
        IsDetached          = $IsDetached
        Branch              = $Branch
        IsAncestorOfDefault = $IsAncestorOfDefault
        CommitsAhead        = $CommitsAhead
        PrState             = $PrState
        PrNumber            = $PrNumber
        PrHeadOid           = $PrHeadOid
        PrHeadComparable    = $PrHeadComparable
        CommitsAheadOfPrHead = $CommitsAheadOfPrHead
        PatchesMeasured     = $PatchesMeasured
        PatchesNotLanded    = $PatchesNotLanded
        Head                = $Head
        LastCommitDate      = $LastCommitDate
    }
}

function Get-WorktreePointerKind {
    <#
    .SYNOPSIS
        Reads the shape of a .git file's gitdir pointer. Pure: takes the text.
    .DESCRIPTION
        A .git FILE is not proof of a worktree. The pointer's shape is:

          .../.git/worktrees/<name>   -> Worktree
          .../.git/modules/<name>     -> Submodule
          anything else               -> Unknown

        This is a decision, not a detail: mistaking a submodule for an orphaned
        worktree is how a cleanup pass talks someone into deleting one. Measured
        on ai-01 before this test existed -- mcps/internal, roo-code and zoo-code
        (three intact submodules) were all reported as orphaned worktrees, along
        with a VS Code extension shipping a .git file pointing at its author's
        machine.
    .OUTPUTS
        [pscustomobject] @{ Kind; OwnerRepo }  -- OwnerRepo is '' unless Worktree.
    #>
    [CmdletBinding()]
    param([string]$DotGitContent)

    if ([string]::IsNullOrWhiteSpace($DotGitContent) -or $DotGitContent -notmatch 'gitdir:\s*(.+)') {
        return [pscustomobject]@{ Kind = 'Unknown'; OwnerRepo = '' }
    }
    $target = $Matches[1].Trim()

    if ($target -match '^(.*?)[\\/]\.git[\\/]worktrees[\\/]') {
        return [pscustomobject]@{ Kind = 'Worktree'; OwnerRepo = $Matches[1] }
    }
    if ($target -match '[\\/]\.git[\\/]modules[\\/]') {
        return [pscustomobject]@{ Kind = 'Submodule'; OwnerRepo = '' }
    }
    return [pscustomobject]@{ Kind = 'Unknown'; OwnerRepo = '' }
}

function Get-PrNumberFromBranchName {
    <#
    .SYNOPSIS
        Returns the PR number a branch name encodes, or 0. Pure: takes the name.
    .DESCRIPTION
        `git fetch origin pull/N/head:prN` -- the usual way to get someone
        else's PR onto disk -- names the local branch `prN`. That name is NOT
        the PR's headRefName, so looking the PR up by branch name finds nothing
        and the branch reads as "no PR at all", i.e. forgotten work.

        Measured on ai-01: four CoursIA worktrees on branches pr9962, pr9967,
        pr9968 and pr10010 were reported as forgotten. All four PRs are merged.

        Only the exact `pr<digits>` shape counts. `pr-fix-thing` or `prefetch`
        are ordinary branch names and must not be read as PR numbers.
    .OUTPUTS
        [int] the PR number, or 0 when the name does not encode one.
    #>
    [CmdletBinding()]
    param([string]$Branch)

    if ([string]::IsNullOrWhiteSpace($Branch)) { return 0 }
    if ($Branch -match '^pr(\d+)$') { return [int]$Matches[1] }
    return 0
}

function Get-WorktreeClass {
    <#
    .SYNOPSIS
        Classifies one worktree. Pure: no I/O, no side effects.
    .OUTPUTS
        [pscustomobject] @{ Class; Deletable; NeedsRescueBranch; Reason }
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][psobject]$Facts)

    function New-Verdict {
        param([string]$Class, [bool]$Deletable, [string]$Reason, [bool]$Rescue = $false)
        return [pscustomobject]@{
            Class             = $Class
            Deletable         = $Deletable
            NeedsRescueBranch = $Rescue
            Reason            = $Reason
        }
    }

    # 0. The repository's own working tree is listed by `git worktree list` and is
    #    never a cleanup candidate.
    if ($Facts.IsMainWorktree) {
        return New-Verdict 'MAIN' $false 'main working tree of the repository'
    }

    # 0b. A working tree on disk that no repository lists. Its refs lived in the
    #     deleted <repo>/.git/worktrees/<name>, so nothing points at its commits
    #     and git can say nothing about them -- they may be uncommitted, or
    #     already garbage-collected. Never deletable: this is precisely the case
    #     where the tool cannot tell what it would be destroying.
    if (-not $Facts.IsRegistered) {
        return New-Verdict 'ORPHAN-DIR' $false 'working tree on disk that no repository registers; its refs are gone'
    }

    # 1. Ghost: registered, but the working tree or the gitdir target is gone.
    #    Checked on the gitdir TARGET rather than git's `prunable` flag.
    if (-not $Facts.DirectoryExists) {
        return New-Verdict 'GHOST' $true 'working directory no longer exists'
    }
    if (-not $Facts.GitDirTargetExists) {
        return New-Verdict 'GHOST' $true 'gitdir pointer targets a directory that no longer exists'
    }

    # 2. Dirty beats everything below, including a merged PR.
    if ($Facts.IsDirty) {
        return New-Verdict 'DIRTY' $false 'uncommitted or untracked files present'
    }

    # 3. Content provably in the default branch.
    if ($Facts.IsAncestorOfDefault) {
        return New-Verdict 'MERGED' $true 'HEAD is an ancestor of the default remote branch'
    }

    $hasBranch = -not [string]::IsNullOrWhiteSpace($Facts.Branch)

    if ($hasBranch -and $Facts.PrState) {
        switch ($Facts.PrState.ToUpperInvariant()) {
            'MERGED' {
                # A merged PR vouches for the commit it merged, and for nothing
                # else. Commits this worktree holds that the PR head cannot
                # reach never went through that PR and were never reviewed.
                #
                # The test is "ahead of the PR head", NOT "different from the PR
                # head": a stale checkout sitting several commits BEHIND is also
                # a different SHA, and its content is entirely inside the merge.
                if ($Facts.PrHeadComparable -and $Facts.CommitsAheadOfPrHead -gt 0) {
                    return New-Verdict 'PR-MERGED-DIVERGED' $false "PR #$($Facts.PrNumber) is merged, but this worktree holds $($Facts.CommitsAheadOfPrHead) commit(s) the PR never carried"
                }
                # Squash merge: the commits are not ancestors, yet the content landed.
                $rescue = [bool]$Facts.IsDetached
                return New-Verdict 'MERGED-BY-PR' $true "PR #$($Facts.PrNumber) is merged (squash merge keeps commits off the ancestry line)" $rescue
            }
            'OPEN' {
                return New-Verdict 'PR-OPEN' $false "PR #$($Facts.PrNumber) is still open"
            }
            'CLOSED' {
                return New-Verdict 'PR-CLOSED' $false "PR #$($Facts.PrNumber) was closed without merging"
            }
        }
    }

    if ($hasBranch -and $Facts.CommitsAhead -gt 0) {
        return New-Verdict 'PR-FORGOTTEN' $false "$($Facts.CommitsAhead) commit(s) ahead of the default branch and no pull request"
    }

    if ($Facts.IsDetached -and $Facts.CommitsAhead -gt 0) {
        # "Not an ancestor" is not "unmerged" -- a squash merge leaves the head
        # off the ancestry line. Patch identity settles it where the missing
        # branch name makes a PR lookup impossible.
        if ($Facts.PatchesMeasured -and $Facts.PatchesNotLanded -eq 0) {
            return New-Verdict 'DETACHED-LANDED' $true "detached HEAD, but every one of its $($Facts.CommitsAhead) commit(s) has an equivalent patch on the default branch" $true
        }
        # No branch references these commits: removing the worktree orphans them.
        $unlanded = if ($Facts.PatchesMeasured) { "$($Facts.PatchesNotLanded) commit(s) whose patch is nowhere on the default branch" }
                    else { "$($Facts.CommitsAhead) commit(s) no branch points at, patch identity unmeasured" }
        return New-Verdict 'DETACHED-ORPHANABLE' $false "detached HEAD with $unlanded" $true
    }

    return New-Verdict 'UNDETERMINED' $false 'facts do not match any known class'
}
