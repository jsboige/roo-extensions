<#
.SYNOPSIS
    Shared path-safety guards for recursive deletion in cleanup automation.
.DESCRIPTION
    Guard #2772 (couche 3b) — root cause of the 28h web1 outage (#2772): gitignored
    secrets (.env) live inside submodule working trees. Any `Remove-Item -Recurse -Force`
    whose target resolves inside (or contains) a submodule working tree silently
    destroys them. Same failure family as the nested-worktree incident #2123.

    Cleanup scripts must dot-source this module and call the guards BEFORE any
    recursive-delete strategy (Remove-Item, cmd rmdir, robocopy /MIR, ...):

      . "$PSScriptRoot\..\common\path-guards.ps1"

      # Once, at startup — vets the cleanup container itself (#2123 guard):
      $rootVerdict = Test-SafeCleanupRoot -Root $WorktreesDir -RepoRoot $RepoRoot
      if (-not $rootVerdict.Safe) { <refuse whole run: $rootVerdict.Reason> }

      # Per deletion target (#2772 guard):
      $verdict = Test-SafeDeletionPath -Path $target -RepoRoot $RepoRoot -AllowedRoot $WorktreesDir
      if (-not $verdict.Safe) { <refuse this target: $verdict.Reason> }

    Mirrors the creation-time Guard #2351 idiom (start-claude-worker.ps1): dynamic
    .gitmodules read (never hardcoded submodule names), backslash normalization,
    prefix comparison with trailing-separator anchoring (no sibling-prefix false
    positives: 'mcps/internal-backup' does not match submodule 'mcps/internal').

    Failure semantics: if git/.gitmodules cannot be read, the submodule list is
    empty and the checks pass (fail-open, same as Guard #2351) — the AllowedRoot
    containment check is pure string logic and always applies.
.NOTES
    Issue #2772 (couche 3b) — audit cleaners + submodule deletion guard.
    Related: #2123 (nested worktrees), #2351 (creation-time guard).
#>

function ConvertTo-NormalizedPath {
    <#
    .SYNOPSIS
        Absolute + forward-slash + no-trailing-slash normalization, without
        requiring the path to exist (works on partially-deleted targets).
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path)

    # Strip Windows long-path prefix if present (\\?\C:\...)
    $candidate = $Path -replace '^\\\\\?\\', ''
    try {
        if (-not [System.IO.Path]::IsPathRooted($candidate)) {
            $candidate = Join-Path (Get-Location).Path $candidate
        }
        $candidate = [System.IO.Path]::GetFullPath($candidate)
    } catch {
        # Keep the raw value; comparisons still run on the normalized string form
    }
    return (($candidate -replace '\\', '/').TrimEnd('/'))
}

function Test-PathUnder {
    <#
    .SYNOPSIS
        True if $Path equals $Root or lies strictly under it (case-insensitive,
        trailing-separator anchored — no sibling-prefix false positives).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Root,
        [switch]$Strict   # exclude equality
    )
    $p = ConvertTo-NormalizedPath -Path $Path
    $r = ConvertTo-NormalizedPath -Path $Root
    if (-not $Strict -and [string]::Equals($p, $r, [System.StringComparison]::OrdinalIgnoreCase)) {
        return $true
    }
    return $p.StartsWith("$r/", [System.StringComparison]::OrdinalIgnoreCase)
}

function Get-SubmodulePaths {
    <#
    .SYNOPSIS
        Absolute, normalized working-tree paths of every submodule registered in
        $RepoRoot/.gitmodules. Empty array when unreadable (fail-open, cf. #2351).
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$RepoRoot)

    $paths = @()
    try {
        # 2>&1 + `-is [string]` filter: callers run under $ErrorActionPreference='Stop',
        # where bare stderr from native git can throw (same idiom as Guard #2351)
        $lines = @(git -C $RepoRoot config --file .gitmodules --get-regexp path 2>&1)
        foreach ($line in $lines) {
            if ($line -is [string] -and $line -match '^submodule\.\S+\.path\s+(.+)$') {
                $paths += (ConvertTo-NormalizedPath -Path (Join-Path $RepoRoot $Matches[1]))
            }
        }
    } catch {
        # .gitmodules absent or git unavailable — no submodules to protect
    }
    return ,$paths
}

function Test-SafeDeletionPath {
    <#
    .SYNOPSIS
        Vets a single recursive-deletion target (Guard #2772).
    .DESCRIPTION
        Refuses when the target:
          1. equals or lies inside a submodule working tree (would destroy
             gitignored secrets such as .env — root cause of #2772), or
          2. CONTAINS a submodule working tree (deleting a parent directory
             destroys the submodule just the same), or
          3. falls outside $AllowedRoot when one is provided (a cleaner must
             only ever delete inside its designated container).
    .OUTPUTS
        Hashtable @{ Safe = [bool]; Reason = [string] }
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$RepoRoot,
        [string]$AllowedRoot
    )

    $target = ConvertTo-NormalizedPath -Path $Path

    if ($AllowedRoot) {
        if (-not (Test-PathUnder -Path $target -Root $AllowedRoot -Strict)) {
            return @{ Safe = $false; Reason = "target '$target' is not strictly under the allowed cleanup root '$(ConvertTo-NormalizedPath -Path $AllowedRoot)' (#2772)" }
        }
    }

    foreach ($sm in (Get-SubmodulePaths -RepoRoot $RepoRoot)) {
        if (Test-PathUnder -Path $target -Root $sm) {
            return @{ Safe = $false; Reason = "target '$target' resolves inside submodule working tree '$sm' — recursive delete would destroy gitignored files (.env) (#2772)" }
        }
        if (Test-PathUnder -Path $sm -Root $target -Strict) {
            return @{ Safe = $false; Reason = "target '$target' contains submodule working tree '$sm' — recursive delete would destroy it (#2772)" }
        }
    }

    return @{ Safe = $true; Reason = '' }
}

function Test-SafeCleanupRoot {
    <#
    .SYNOPSIS
        Vets the cleanup container itself, once per run (Guard #2123).
    .DESCRIPTION
        Refuses when:
          1. the container (e.g. .claude/worktrees) resolves inside a submodule
             working tree of $RepoRoot, or
          2. $RepoRoot is itself a submodule of an enclosing superproject
             (git rev-parse --show-superproject-working-tree non-empty) — the
             nested-repo configuration of incident #2123: cleaning there operates
             inside the parent repository's working tree.
    .OUTPUTS
        Hashtable @{ Safe = [bool]; Reason = [string] }
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Root,
        [Parameter(Mandatory)][string]$RepoRoot
    )

    $container = ConvertTo-NormalizedPath -Path $Root

    foreach ($sm in (Get-SubmodulePaths -RepoRoot $RepoRoot)) {
        if (Test-PathUnder -Path $container -Root $sm) {
            return @{ Safe = $false; Reason = "cleanup root '$container' resolves inside submodule working tree '$sm' (#2123/#2772)" }
        }
    }

    try {
        # 2>&1 + `-is [string]` filter: same EAP-Stop-safe idiom as Guard #2351
        $superLines = @(git -C $RepoRoot rev-parse --show-superproject-working-tree 2>&1)
        $super = $superLines | Where-Object { $_ -is [string] -and $_.Trim() } | Select-Object -First 1
        if ($super) {
            return @{ Safe = $false; Reason = "repo '$(ConvertTo-NormalizedPath -Path $RepoRoot)' is a submodule of superproject '$($super.Trim())' — cleanup automation must run from the superproject, never from a nested repo (#2123)" }
        }
    } catch {
        # git unavailable — cannot detect nesting; fall through (fail-open, cf. #2351)
    }

    return @{ Safe = $true; Reason = '' }
}
