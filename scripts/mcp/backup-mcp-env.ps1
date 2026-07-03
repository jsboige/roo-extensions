<#
.SYNOPSIS
    Backup du .env du MCP roo-state-manager vers un emplacement LOCAL hors-git
    (bootstrap-safe) + copie offsite best-effort sur le shared-state GDrive.

.DESCRIPTION
    Remediation #2772 (incident web1 : .env supprime par un agent -> MCP DOWN 28h).

    Le .env vit dans le working-tree git du submodule (mcps/internal/...) donc il est
    expose a `git clean`, suppression de worktree et reset de submodule. Ce script en
    conserve une copie a un chemin machine-independant HORS de tout repo git :

        %USERPROFILE%\.roo-state-manager\.env            (backup primaire, source de restore)
        %USERPROFILE%\.roo-state-manager\.env.bak.<ts>   (snapshots rotatifs, N derniers)

    Pourquoi local hors-git et PAS GDrive comme source primaire : le chemin GDrive
    (ROOSYNC_SHARED_PATH) est lui-meme STOCKE dans le .env et differe par machine.
    Si le .env disparait, on ne sait plus ou est GDrive -> impossible de s'auto-reparer
    depuis GDrive (bootstrap). Seul $env:USERPROFILE est toujours defini sans le .env.

    La copie GDrive est faite en best-effort ("juste un backup" offsite) et n'echoue
    jamais le script.

.NOTES
    A executer sur une machine SAINE (dont le .env est valide), manuellement ou en cron.
    Copie octet-pour-octet (Copy-Item) : les secrets/cles ne sont jamais reserialises.
#>
[CmdletBinding()]
param(
    # Nombre de snapshots horodates a conserver dans le backup local hors-git.
    [int]$KeepSnapshots = 10,

    # Ne pas tenter la copie offsite GDrive (backup local uniquement).
    [switch]$NoOffsite
)

$ErrorActionPreference = 'Stop'

function Resolve-RepoRoot {
    try {
        $top = (git -C $PSScriptRoot rev-parse --show-toplevel 2>$null | Out-String).Trim()
        if ($top) { return $top }
    } catch {}
    # Fallback : scripts/mcp/ -> deux niveaux au-dessus (Join-Path 2-args pour compat PS 5.1).
    return (Resolve-Path (Join-Path (Join-Path $PSScriptRoot '..') '..')).Path
}

$repoRoot   = Resolve-RepoRoot
$envRelPath = 'mcps/internal/servers/roo-state-manager/.env'
$envPath    = Join-Path $repoRoot $envRelPath

if (-not (Test-Path -LiteralPath $envPath)) {
    Write-Host "[backup-mcp-env] ABORT: source .env introuvable ($envPath). Rien a sauvegarder." -ForegroundColor Yellow
    exit 2
}
if ((Get-Item -LiteralPath $envPath).Length -eq 0) {
    Write-Host "[backup-mcp-env] ABORT: source .env vide ($envPath). Refus de sauvegarder un fichier vide." -ForegroundColor Yellow
    exit 2
}

# --- Backup primaire : local hors-git, chemin machine-independant ---
$backupDir     = Join-Path $env:USERPROFILE '.roo-state-manager'
$primaryBackup = Join-Path $backupDir '.env'
if (-not (Test-Path -LiteralPath $backupDir)) {
    New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
}

Copy-Item -LiteralPath $envPath -Destination $primaryBackup -Force
Write-Host "[backup-mcp-env] OK backup primaire -> $primaryBackup" -ForegroundColor Green

# --- Snapshot rotatif horodate ---
$stamp        = Get-Date -Format 'yyyyMMdd-HHmmss'
$snapshot     = Join-Path $backupDir ".env.bak.$stamp"
Copy-Item -LiteralPath $envPath -Destination $snapshot -Force
Write-Host "[backup-mcp-env] OK snapshot        -> $snapshot" -ForegroundColor Green

# Purge : ne garder que les $KeepSnapshots plus recents.
$snaps = Get-ChildItem -LiteralPath $backupDir -Filter '.env.bak.*' -File |
         Sort-Object LastWriteTime -Descending
if ($snaps.Count -gt $KeepSnapshots) {
    $snaps | Select-Object -Skip $KeepSnapshots | ForEach-Object {
        Remove-Item -LiteralPath $_.FullName -Force
        Write-Host "[backup-mcp-env]   purge snapshot -> $($_.Name)" -ForegroundColor DarkGray
    }
}

# --- Copie offsite GDrive : best-effort, "juste un backup", ne fait JAMAIS echouer ---
if (-not $NoOffsite) {
    try {
        # ROOSYNC_SHARED_PATH depuis l'env du process, sinon parse depuis le .env sauvegarde.
        $sharedPath = $env:ROOSYNC_SHARED_PATH
        $machineId  = $env:ROOSYNC_MACHINE_ID
        if (-not $sharedPath -or -not $machineId) {
            foreach ($line in Get-Content -LiteralPath $envPath) {
                if (-not $sharedPath -and $line -match '^\s*ROOSYNC_SHARED_PATH\s*=\s*(.+?)\s*$') { $sharedPath = $Matches[1].Trim('"').Trim("'") }
                if (-not $machineId  -and $line -match '^\s*ROOSYNC_MACHINE_ID\s*=\s*(.+?)\s*$')  { $machineId  = $Matches[1].Trim('"').Trim("'") }
            }
        }
        if (-not $machineId) { $machineId = $env:COMPUTERNAME }

        if ($sharedPath -and (Test-Path -LiteralPath $sharedPath)) {
            $offsiteDir = Join-Path $sharedPath 'mcp-env'
            if (-not (Test-Path -LiteralPath $offsiteDir)) {
                New-Item -ItemType Directory -Path $offsiteDir -Force | Out-Null
            }
            $offsiteBlob = Join-Path $offsiteDir "$machineId.env"
            Copy-Item -LiteralPath $envPath -Destination $offsiteBlob -Force
            Write-Host "[backup-mcp-env] OK offsite GDrive  -> $offsiteBlob" -ForegroundColor Green
        } else {
            Write-Host "[backup-mcp-env] SKIP offsite : ROOSYNC_SHARED_PATH indisponible/inaccessible (backup local suffit)." -ForegroundColor DarkGray
        }
    } catch {
        Write-Host "[backup-mcp-env] WARN offsite GDrive echoue (best-effort, ignore): $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

Write-Host "[backup-mcp-env] DONE." -ForegroundColor Cyan
exit 0
