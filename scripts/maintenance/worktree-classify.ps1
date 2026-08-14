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
      4. branch whose PR is MERGED          -> MERGED-BY-PR         delete (safe)
      5. branch whose PR is OPEN            -> PR-OPEN              keep
      6. branch whose PR is CLOSED unmerged -> PR-CLOSED            keep, report
      7. branch, no PR, commits ahead       -> PR-FORGOTTEN         keep, report
      8. detached, commits not in default   -> DETACHED-ORPHANABLE  keep, report
      -  anything else                      -> UNDETERMINED         keep

    Two rules carry the weight:

    * DIRTY is tested BEFORE any "merged" test. A worktree whose PR is merged
      can still hold uncommitted work; deleting it because the PR landed would
      destroy exactly the changes nobody has seen yet.

    * Ancestry alone cannot prove "unmerged". A squash-merged branch keeps
      commits that are not ancestors of the default branch even though its
      content landed. Rule 4 therefore asks GitHub for the PR state, which is
      authoritative, before rule 7 concludes anything from git topology.
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
        # No branch references these commits: removing the worktree orphans them.
        return New-Verdict 'DETACHED-ORPHANABLE' $false "detached HEAD with $($Facts.CommitsAhead) commit(s) no branch points at" $true
    }

    return New-Verdict 'UNDETERMINED' $false 'facts do not match any known class'
}
