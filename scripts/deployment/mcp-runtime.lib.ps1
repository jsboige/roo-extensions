# mcp-runtime.lib.ps1 — per-seat MCP runtime install + launcher flattening (#4149 F1)
#
# Dot-sourced by deploy-claude-mcp-settings.ps1. Kept side-file so the Pester
# suite (unit-pester, ubuntu runner) can exercise the REAL functions against
# fixtures — the deploy script itself is Windows-seat-facing and not runnable
# in CI.

# --- Resolve-McpRuntimeEntry -------------------------------------------------
#
# `npx -y <pkg>` costs FOUR processes per session (cmd -> npx-node -> cmd .bin
# shim -> server-node; measured po-2027 28/10: 16 processes for 4 sessions, per
# server, ~94-117 MB working set each) and may consult the npm registry at every
# start. Installing the package once per seat under
# <Root>\<Name> and launching the manifest bin with `node <entry>` costs ONE
# process per session and no registry access at start.
#
# Idempotent: when the installed version already matches the spec, npm is not
# invoked (a deploy on a healthy seat does not touch the network). The bin
# entry is resolved from the package manifest, never hardcoded — a version bump
# that moves the bin survives without touching this file.

function Resolve-McpRuntimeEntry {
    param(
        [string]$Root,       # runtimes root, e.g. ~/.claude/mcp-runtimes
        [hashtable]$Spec,    # @{ Name; Package; Version; BinHint }  (BinHint optional, WhatIf display only)
        [switch]$WhatIf
    )
    $Dir = Join-Path $Root $Spec.Name
    $PkgJson = Join-Path $Dir ("node_modules\" + $Spec.Package + "\package.json")
    $Installed = $null
    if (Test-Path -LiteralPath $PkgJson) {
        try { $Installed = (Get-Content -LiteralPath $PkgJson -Raw | ConvertFrom-Json).version } catch { $Installed = $null }
    }
    if ($Installed -ne $Spec.Version) {
        if ($WhatIf) {
            Write-Host "[WHATIF] Would run: npm install --prefix $Dir $($Spec.Package)@$($Spec.Version)" -ForegroundColor Cyan
            if (-not (Test-Path -LiteralPath $PkgJson)) {
                # No manifest to read the bin from: show the pinned hint so the
                # would-be config stays readable. Real runs never take this path.
                return Join-Path $Dir ("node_modules\" + $Spec.Package + "\" + $Spec.BinHint)
            }
        } else {
            if ($Installed) { Write-Host "[RUNTIME] $($Spec.Package) $Installed -> $($Spec.Version) (upgrade)" -ForegroundColor Yellow }
            else { Write-Host "[RUNTIME] Installing $($Spec.Package)@$($Spec.Version) into $Dir" -ForegroundColor Cyan }
            # W1 (#4411 review): under the EAP=Stop inherited from the deploy
            # script, PS 5.1 turns the FIRST stderr line merged by 2>&1 into a
            # terminating RemoteException — and npm routinely warns on stderr
            # (funding, deprecation, network). EAP is lowered ONLY around the
            # call; $LASTEXITCODE stays the sole judge of success. The command
            # is a script-scoped seam (defaults to npm) so the suite can drive
            # the real EAP path against a stub that writes stderr with exit 0.
            if (-not $script:McpRuntimeNpmCommand) { $script:McpRuntimeNpmCommand = 'npm' }
            $PrevEAP = $ErrorActionPreference
            $ErrorActionPreference = 'Continue'
            try {
                & $script:McpRuntimeNpmCommand install --prefix $Dir "$($Spec.Package)@$($Spec.Version)" 2>&1 |
                    ForEach-Object { Write-Host "  $_" -ForegroundColor DarkGray }
            } finally {
                $ErrorActionPreference = $PrevEAP
            }
            if ($LASTEXITCODE -ne 0) {
                throw "npm install failed for $($Spec.Package)@$($Spec.Version) (exit $LASTEXITCODE)"
            }
        }
    } else {
        Write-Host "[RUNTIME] $($Spec.Package) $($Spec.Version) already installed at $Dir (no npm call)" -ForegroundColor DarkGray
    }
    if (-not (Test-Path -LiteralPath $PkgJson)) {
        throw "runtime manifest missing after install: $PkgJson"
    }
    $Manifest = Get-Content -LiteralPath $PkgJson -Raw | ConvertFrom-Json
    $Bin = $Manifest.bin
    if ($Bin -is [System.Management.Automation.PSCustomObject]) {
        # npm bin-key resolution: a scoped package maps a bin keyed on the
        # UNSCOPED name (@playwright/mcp -> bin "playwright-mcp" — caught live
        # on the first real deploy; a symmetric fixture had masked it). Fall
        # back to the single entry when present: one bin = no ambiguity.
        $Unscoped = ($Manifest.name -split '/')[-1]
        if ($Bin.PSObject.Properties[$Manifest.name]) { $Bin = $Bin.($Manifest.name) }
        elseif ($Bin.PSObject.Properties[$Unscoped]) { $Bin = $Bin.$Unscoped }
        elseif (@($Bin.PSObject.Properties).Count -eq 1) { $Bin = @($Bin.PSObject.Properties)[0].Value }
        else { $Bin = $null }
    }
    if (-not $Bin) {
        throw "no bin entry in manifest: $PkgJson"
    }
    $Entry = Join-Path $Dir ("node_modules\" + $Spec.Package + "\" + $Bin)
    if (-not (Test-Path -LiteralPath $Entry)) {
        throw "bin entry not found after install: $Entry"
    }
    return $Entry
}

# --- New-SearxngTakeoverConfig ------------------------------------------------
#
# searxng joins the MANAGED set with #4149 F1 (it was an unmanaged npx survivor
# since #3411). Its live entry carries per-seat data — env with SEARXNG_URL and
# possibly auth credentials, alwaysAllow, disabled — that must survive every
# later deploy: only command/args change, the rest is copied verbatim from the
# live entry. Secrets stay in ~/.claude.json, never in this repo.
#
# A seat with no existing entry gets the public default URL only (the
# install-mcps.ps1 pattern). If that seat later needs auth, the env is added by
# hand to ~/.claude.json and preserved by the takeover from then on.

function New-SearxngTakeoverConfig {
    param(
        [string]$EntryPath,
        $ExistingEntry,   # PSCustomObject from the live ~/.claude.json, or $null
        [string]$DefaultSearxngUrl = 'https://search.myia.io/'
    )
    $Config = @{ command = 'node'; args = @($EntryPath) }
    if ($ExistingEntry) {
        # Copy EVERY live field except the launcher pair (command/args) — not a
        # fixed whitelist: this takeover pattern is the template for RSM (F2),
        # where per-seat fields the list didn't name (type, timeout, ...) must
        # survive too (#4411 review, non-blocking note).
        foreach ($Prop in $ExistingEntry.PSObject.Properties) {
            if ($Prop.Name -notin 'command', 'args') {
                $Config[$Prop.Name] = $Prop.Value
            }
        }
    } else {
        $Config['env'] = @{ SEARXNG_URL = $DefaultSearxngUrl }
    }
    return $Config
}

# --- Resolve-DeployRepoRoot ---------------------------------------------------
#
# A linked worktree is a place of work, not a deployment target. The deploy
# script derives $RepoRoot from its OWN location, so launching it from
# `.claude/worktrees/wt-*` writes THAT path into ~/.claude.json. Nothing breaks
# at that moment — the failure lands later, when the worktree is removed: the
# roo-state-manager launcher then points at a directory that no longer exists
# and the seat has no RSM at its next session start, having done nothing worse
# than cleaning up a worktree (measured po-2027, 2026-10-29: the F1 worktree was
# purged minutes after a deploy made from it).
#
# `git worktree list` always prints the MAIN worktree first, so its path is the
# deployment root whatever checkout launched us. Every uncertainty (not a git
# repo, git missing, unparsable output, path that does not exist) returns the
# input unchanged: this guard may fail to redirect, it must never invent a root.

function Resolve-DeployRepoRoot {
    param([string]$RepoRoot)
    if (-not $script:McpRuntimeGitCommand) { $script:McpRuntimeGitCommand = 'git' }
    # Same EAP discipline as the npm call above (W1): stderr from a native
    # command is not an error condition, and $LASTEXITCODE is the only judge.
    # The whole output is captured BEFORE the first line is read: piping into
    # Select-Object -First 1 would stop the native command early and leave
    # $LASTEXITCODE stale — the previous command's exit code.
    $GitArgs = @('-C', $RepoRoot, 'worktree', 'list', '--porcelain')
    if ($script:McpRuntimeGitArgs) { $GitArgs = @($script:McpRuntimeGitArgs) }
    $PrevEAP = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $Out = & $script:McpRuntimeGitCommand @GitArgs 2>&1
        $Code = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $PrevEAP
    }
    $First = @($Out) | Select-Object -First 1
    if ($Code -ne 0 -or -not $First) { return $RepoRoot }
    if (([string]$First) -notmatch '^worktree\s+(.+?)\s*$') { return $RepoRoot }
    $Main = $Matches[1].Trim()
    if (-not $Main) { return $RepoRoot }
    # GetFullPath normalises separators and relative segments on every platform
    # (Windows accepts the forward slashes git prints); no manual '/' -> '\'.
    $Main = ([System.IO.Path]::GetFullPath($Main)).TrimEnd('\')
    $Current = ([System.IO.Path]::GetFullPath($RepoRoot)).TrimEnd('\')
    if ($Main -eq $Current) { return $RepoRoot }
    if (-not (Test-Path -LiteralPath $Main)) { return $RepoRoot }
    Write-Host "[MAIN-CHECKOUT] launched from a linked worktree ('$Current') -> deploying from '$Main'" -ForegroundColor Yellow
    return $Main
}
