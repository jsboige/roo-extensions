<#
.SYNOPSIS
    Synchronizes the executor checkout and guarantees a fresh RSM build before work starts.

.DESCRIPTION
    Runs the parent pull, materializes the mcps/internal gitlink, verifies the submodule identity,
    then invokes the freshly pulled ensure-build-fresh.ps1 in strict mode. Exit 10 means live RSM
    hosts predate the fresh on-disk build, so VS Code must restart before the executor continues.
#>
[CmdletBinding()]
param(
    [string]$RepoRoot
)

$ErrorActionPreference = 'Stop'

if (-not $RepoRoot) {
    $RepoRoot = (& git rev-parse --show-toplevel 2>$null)
}
if (-not $RepoRoot -or -not (Test-Path (Join-Path $RepoRoot '.git'))) {
    Write-Error '[executor-preflight] Repository root not found.'
    exit 1
}

function Invoke-GitChecked {
    param([string[]]$Arguments)
    & git -C $RepoRoot @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "git $($Arguments -join ' ') failed with exit $LASTEXITCODE"
    }
}

try {
    $branch = (& git -C $RepoRoot branch --show-current).Trim()
    if ($branch -ne 'main') {
        throw "Executor pre-flight must run from main, not '$branch'."
    }

    Invoke-GitChecked @('fetch', 'origin')
    Invoke-GitChecked @('pull', 'origin', 'main', '--no-rebase')
    Invoke-GitChecked @('submodule', 'update', '--init', 'mcps/internal')

    $parentTop = (& git -C $RepoRoot rev-parse --show-toplevel).Trim()
    $submodulePath = Join-Path $RepoRoot 'mcps/internal'
    $submoduleTop = (& git -C $submodulePath rev-parse --show-toplevel).Trim()
    if ($LASTEXITCODE -ne 0 -or $submoduleTop -eq $parentTop) {
        throw 'mcps/internal is not a populated submodule; git -C resolved to the parent repository.'
    }

    $gitlink = ((& git -C $RepoRoot ls-tree HEAD mcps/internal) -split '\s+')[2]
    $submoduleHead = (& git -C $submodulePath rev-parse HEAD).Trim()
    if ($gitlink -ne $submoduleHead) {
        throw "mcps/internal HEAD $submoduleHead does not match parent gitlink $gitlink."
    }

    $helper = Join-Path $RepoRoot 'scripts/claude/ensure-build-fresh.ps1'
    if (-not (Test-Path $helper)) {
        throw "Freshness helper missing after pull: $helper"
    }

    & powershell.exe -ExecutionPolicy Bypass -File $helper -RepoRoot $RepoRoot -RequireFresh
    $freshExit = $LASTEXITCODE
    if ($freshExit -eq 10) {
        Write-Host '[executor-preflight][RESTART-REQUIRED] Build is fresh on disk, but live RSM hosts predate it. Restart VS Code now; do not continue this executor cycle.' -ForegroundColor Red
        exit 10
    }
    if ($freshExit -ne 0) {
        throw "ensure-build-fresh.ps1 could not guarantee freshness (exit $freshExit)."
    }

    Write-Host '[executor-preflight][READY] Parent, submodule, and RSM build are synchronized.' -ForegroundColor Green
    exit 0
} catch {
    Write-Error "[executor-preflight][BLOCKED] $($_.Exception.Message)"
    exit 1
}
