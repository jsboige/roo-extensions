<#
.SYNOPSIS
    Migrate Claude schtasks from powershell.exe (PS 5.1) to pwsh.exe (PS 7+) — fix worker AsHashtable WARN.

.DESCRIPTION
    The Claude scheduled tasks (Claude-Coordinator, Claude-Worker, Claude-MetaAudit) historically
    use powershell.exe (Windows PowerShell 5.1). Since 2026-05-25, start-claude-worker.ps1 calls
    ConvertFrom-Json -AsHashtable (a PS 7+ feature) to inject MCP env vars. On PS 5.1 this fails
    silently and falls back to .env injection (#2280) — non-fatal but spams logs with:

        [WARN] Injection env vars MCP echouee: Impossible de trouver un parametre... AsHashtable

    This script switches the executable of the affected schtasks to pwsh.exe so the JSON-based
    env injection (which carries strictly more env vars than the .env fallback) works as designed.

    Idempotent: safe to re-run. Skips schtasks already using pwsh.exe. Aborts cleanly if pwsh.exe
    is not installed (you'll need to install PowerShell 7+ first — usually already present on
    the fleet).

.PARAMETER DryRun
    Show what would change without actually modifying any schtask.

.PARAMETER TaskNames
    Override the default list of schtasks to migrate. Defaults to the three known Claude tasks.

.EXAMPLE
    .\migrate-schtasks-to-pwsh.ps1 -DryRun

.EXAMPLE
    .\migrate-schtasks-to-pwsh.ps1
#>

param(
    [switch]$DryRun,
    [string[]]$TaskNames = @('Claude-Coordinator', 'Claude-Worker', 'Claude-MetaAudit')
)

$ErrorActionPreference = 'Stop'

$pwshExe = 'C:\Program Files\PowerShell\7\pwsh.exe'

if (-not (Test-Path $pwshExe)) {
    Write-Host "[ABORT] pwsh.exe not found at $pwshExe" -ForegroundColor Red
    Write-Host "        Install PowerShell 7+ first: winget install Microsoft.PowerShell"
    exit 1
}

Write-Host "Target executable: $pwshExe" -ForegroundColor Cyan
if ($DryRun) { Write-Host "[DRY-RUN] No schtasks will be modified" -ForegroundColor Yellow }
Write-Host ""

$migrated = 0
$skipped  = 0
$missing  = 0
$failed   = 0

foreach ($name in $TaskNames) {
    try {
        $task = Get-ScheduledTask -TaskName $name -ErrorAction Stop
    } catch {
        Write-Host "[MISS] $name : task not registered on this machine" -ForegroundColor DarkGray
        $missing++
        continue
    }

    $currentExe     = $task.Actions[0].Execute
    $currentArgs    = $task.Actions[0].Arguments
    $currentWorkDir = $task.Actions[0].WorkingDirectory

    if ($currentExe -ieq $pwshExe) {
        Write-Host "[SKIP] $name : already on pwsh.exe" -ForegroundColor Green
        $skipped++
        continue
    }

    if ($DryRun) {
        Write-Host "[DRY ] $name : $currentExe -> $pwshExe" -ForegroundColor Yellow
        Write-Host "       args (unchanged): $currentArgs" -ForegroundColor DarkGray
        $migrated++
        continue
    }

    try {
        $newAction = New-ScheduledTaskAction -Execute $pwshExe -Argument $currentArgs -WorkingDirectory $currentWorkDir
        Set-ScheduledTask -TaskName $name -Action $newAction -ErrorAction Stop | Out-Null
        Write-Host "[OK  ] $name : migrated to pwsh.exe" -ForegroundColor Green
        $migrated++
    } catch {
        Write-Host "[FAIL] $name : $_" -ForegroundColor Red
        $failed++
    }
}

Write-Host ""
Write-Host "=== Summary ===" -ForegroundColor Cyan
Write-Host "  Migrated : $migrated"
Write-Host "  Skipped  : $skipped (already pwsh)"
Write-Host "  Missing  : $missing (not on this machine)"
Write-Host "  Failed   : $failed"

if ($failed -gt 0) { exit 2 }
exit 0
