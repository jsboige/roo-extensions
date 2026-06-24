#Requires -Version 5.1
<#
.SYNOPSIS
    Push provider profiles (endpoints + models + keys) into Zoo/Roo Code SecretStorage, as-code.

.DESCRIPTION
    Fleet entrypoint wrapper around sync-zoo-provider-profiles.py. Reads
    roo-config/model-configs.json, resolves {{SECRET:xxx}} from .env, and writes the
    providerProfiles blob into VS Code SecretStorage (OSCrypt v10) — eliminating the
    manual "enter API key per machine" step (#2543 Phase 2).

    The Python core handles DPAPI master-key extraction, AES-GCM encryption, sqlite
    state.vscdb I/O, backup, verify-by-decrypt and auto-rollback.

    Dependencies: Python 3 + pywin32 + cryptography. The wrapper checks them.

.PARAMETER Mode
    verify   : read + decrypt the current blob (read-only).
    dry-run  : build the planned blob, print diff, no write (default).
    apply    : write the blob (backup + verify-by-decrypt + rollback on mismatch).

.PARAMETER Target
    zoo (default) or roo. Selects the VS Code extension SecretStorage namespace.

.PARAMETER Force
    Allow --apply while VS Code is running (by default the wrapper refuses, because
    Zoo may flush its in-memory state and overwrite the write — prefer close/apply/reopen).

.EXAMPLE
    .\sync-zoo-provider-profiles.ps1 -Mode verify
    Show what's currently in Zoo SecretStorage.

.EXAMPLE
    .\sync-zoo-provider-profiles.ps1 -Mode dry-run
    Preview the planned profiles + mode mapping (no write).

.EXAMPLE
    .\sync-zoo-provider-profiles.ps1 -Mode apply
    Write profiles to Zoo SecretStorage. Close VS Code first (or use -Force).

.NOTES
    Issue: #2543 (Phase 2 as-code), #2134, Epic #2639 WS3.
#>

param(
    [ValidateSet("verify", "dry-run", "apply")]
    [string]$Mode = "dry-run",

    [ValidateSet("zoo", "roo")]
    [string]$Target = "zoo",

    [switch]$Force,

    [string]$EnvFile = "",

    [string]$ModelConfigs = ""
)

$ErrorActionPreference = "Stop"
$repoRoot = (Get-Item "$PSScriptRoot\..\..").FullName
$pyScript = Join-Path $PSScriptRoot "sync-zoo-provider-profiles.py"

# --- dependency checks ---
$python = (Get-Command python -ErrorAction SilentlyContinue)
if (-not $python) { $python = (Get-Command py -ErrorAction SilentlyContinue); $pyExe = "py" } else { $pyExe = "python" }
if (-not $python) {
    Write-Host "ERROR: python not found on PATH." -ForegroundColor Red
    exit 1
}

$depCheck = & $pyExe -c "import importlib; [importlib.import_module(m) for m in ('win32crypt','cryptography','sqlite3')]" 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: missing Python deps. Install with:" -ForegroundColor Red
    Write-Host "  pip install pywin32 cryptography" -ForegroundColor Yellow
    Write-Host "$depCheck" -ForegroundColor Gray
    exit 1
}

# --- VS Code running guard for apply ---
if ($Mode -eq "apply") {
    $codeProcs = @(Get-Process -Name "Code","Code-Insiders" -ErrorAction SilentlyContinue)
    if ($codeProcs.Count -gt 0 -and -not $Force) {
        Write-Host "ERROR: VS Code is running ($($codeProcs.Count) process(es))." -ForegroundColor Red
        Write-Host "Zoo may flush its in-memory SecretStorage on exit and overwrite this write." -ForegroundColor Yellow
        Write-Host "Close VS Code, then re-run, OR use -Force to proceed at your own risk." -ForegroundColor Yellow
        exit 1
    }
    if ($codeProcs.Count -gt 0 -and $Force) {
        Write-Host "WARN: -Force set, VS Code running — write may be overwritten. Proceeding." -ForegroundColor Yellow
    }
}

# --- build python arg list ---
$pyArgs = @($pyScript)
switch ($Mode) {
    "verify"  { $pyArgs += "--verify" }
    "dry-run" { $pyArgs += "--dry-run" }
    "apply"   { $pyArgs += "--apply" }
}
$pyArgs += @("--target", $Target)
if ($EnvFile)       { $pyArgs += @("--env", $EnvFile) }
if ($ModelConfigs)  { $pyArgs += @("--model-configs", $ModelConfigs) }

Write-Host "[wrapper] $pyExe $($pyArgs -join ' ')" -ForegroundColor Cyan
& $pyExe @pyArgs
$code = $LASTEXITCODE
if ($code -ne 0) {
    Write-Host "`n[wrapper] script exited with code $code" -ForegroundColor Red
}
exit $code
