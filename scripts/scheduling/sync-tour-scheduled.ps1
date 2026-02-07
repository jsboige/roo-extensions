<#
.SYNOPSIS
    Wrapper pour un sync-tour planifie via Task Scheduler.

.DESCRIPTION
    Execute un sync-tour complet avec :
    1. Git pull avant execution
    2. Lance Claude avec le skill sync-tour
    3. Capture resultat
    4. Git push si modifications
    5. Log rotation (garde 7 jours)

    Concu pour etre appele par Task Scheduler Windows.

.PARAMETER MaxMinutes
    Duree max en minutes (defaut: 20)

.PARAMETER LogDir
    Dossier de logs

.PARAMETER SkipPermissions
    Utiliser --dangerously-skip-permissions

.PARAMETER LogRetentionDays
    Nombre de jours de logs a garder (defaut: 7)

.EXAMPLE
    .\sync-tour-scheduled.ps1
    .\sync-tour-scheduled.ps1 -MaxMinutes 30 -SkipPermissions
#>

param(
    [int]$MaxMinutes = 20,
    [string]$LogDir = "",
    [switch]$SkipPermissions,
    [int]$LogRetentionDays = 7
)

$ErrorActionPreference = "Continue"  # Continue on non-critical errors

# Detecter repo
$scriptDir = Split-Path $MyInvocation.MyCommand.Path -Parent
$RepoRoot = git rev-parse --show-toplevel 2>$null
if (-not $RepoRoot) {
    # Fallback: remonter depuis scripts/scheduling/
    $RepoRoot = Split-Path (Split-Path $scriptDir -Parent) -Parent
}

$machineName = ($env:COMPUTERNAME).ToLower()
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"

if (-not $LogDir) {
    $LogDir = "$RepoRoot/logs/scheduling"
}
if (-not (Test-Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
}

$logFile = "$LogDir/$machineName-sync-$timestamp.log"

# Logger
function Log($msg) {
    $ts = Get-Date -Format "HH:mm:ss"
    $line = "[$ts] $msg"
    Write-Host $line
    Add-Content -Path $logFile -Value $line -Encoding UTF8
}

Log "=== Sync Tour Schedule ==="
Log "Machine: $machineName"
Log "Timeout: ${MaxMinutes}min"

# Phase 1: Git pull
Log "[PHASE 1] Git pull..."
Push-Location $RepoRoot
try {
    $pullResult = git pull origin main 2>&1
    Log "  $pullResult"

    # Update submodules
    git submodule update --init --recursive 2>&1 | Out-Null
    Log "  Submodules updated."
} catch {
    Log "  WARN: Git pull error: $_"
}
Pop-Location

# Phase 2: Check si du travail est necessaire
Log "[PHASE 2] Check messages..."
$hasWork = $false

# Verifier s'il y a des messages RooSync non-lus
# (Ceci necessite que le MCP soit accessible, sinon on skip)
try {
    $inboxCheck = & claude --print -p "Verifie s'il y a des messages RooSync non-lus. Reponds uniquement 'OUI' ou 'NON'." 2>$null
    if ($inboxCheck -match "OUI") {
        $hasWork = $true
        Log "  Messages non-lus detectes."
    } else {
        Log "  Pas de messages non-lus."
    }
} catch {
    Log "  WARN: Impossible de verifier inbox: $_"
    $hasWork = $true  # Par precaution, on execute quand meme
}

# Verifier s'il y a des commits depuis le dernier sync
$lastSyncFile = "$LogDir/.last-sync-$machineName"
$newCommits = $false
if (Test-Path $lastSyncFile) {
    $lastCommit = Get-Content $lastSyncFile -Raw
    $currentCommit = git rev-parse HEAD 2>$null
    if ($lastCommit.Trim() -ne $currentCommit.Trim()) {
        $newCommits = $true
        Log "  Nouveaux commits depuis dernier sync."
    }
} else {
    $newCommits = $true
}

if (-not $hasWork -and -not $newCommits) {
    Log "[SKIP] Rien a faire. Pas de messages, pas de nouveaux commits."
    Log "=== Termine (skip) ==="
    exit 0
}

# Phase 3: Lancer sync-tour
Log "[PHASE 3] Lancement sync-tour..."

$workerArgs = @(
    "-Task", "sync-tour",
    "-MaxMinutes", $MaxMinutes,
    "-LogDir", $LogDir
)
if ($SkipPermissions) {
    $workerArgs += "-SkipPermissions"
}

$workerScript = "$scriptDir/start-claude-worker.ps1"
if (Test-Path $workerScript) {
    & powershell -ExecutionPolicy Bypass -File $workerScript @workerArgs
    $workerExit = $LASTEXITCODE
    Log "  Worker exit code: $workerExit"
} else {
    Log "  ERREUR: start-claude-worker.ps1 introuvable"
    exit 1
}

# Phase 4: Git push si modifications
Log "[PHASE 4] Git push si modifications..."
Push-Location $RepoRoot
try {
    $status = git status --porcelain 2>$null
    if ($status) {
        Log "  Modifications detectees, push..."
        git push origin main 2>&1 | ForEach-Object { Log "  $_" }
    } else {
        Log "  Pas de modifications a pousser."
    }

    # Sauvegarder le dernier commit
    $currentCommit = git rev-parse HEAD 2>$null
    Set-Content -Path $lastSyncFile -Value $currentCommit -Encoding UTF8
} catch {
    Log "  WARN: Git push error: $_"
}
Pop-Location

# Phase 5: Log rotation
Log "[PHASE 5] Log rotation (> ${LogRetentionDays} jours)..."
$cutoff = (Get-Date).AddDays(-$LogRetentionDays)
$oldLogs = Get-ChildItem $LogDir -Filter "*.log" |
    Where-Object { $_.LastWriteTime -lt $cutoff }

if ($oldLogs.Count -gt 0) {
    $oldLogs | Remove-Item -Force
    Log "  $($oldLogs.Count) anciens logs supprimes."
} else {
    Log "  Aucun ancien log a supprimer."
}

Log "=== Sync Tour Termine ==="
exit $workerExit
