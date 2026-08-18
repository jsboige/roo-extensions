<#
.SYNOPSIS
    Lance une session Claude Code /executor (cadence persistante via schtasks).

.DESCRIPTION
    Wrapper minimal pour la cadence 4h des exécuteurs (#3141). Substitue un CronCreate
    session-only (qui meurt au restart VS Code) par une tâche Windows planifiée
    persistante (Register-ScheduledTask).

    Differences d'avec start-claude-worker.ps1 :
    - Pas de coordination de pool (le worker scrape GitHub/Project #67)
    - Pas de model-escalation (on respecte la cadence /executor du skill)
    - Pas de Get-NextTask/claim/Mark-TaskAsComplete (c'est l'orchestrateur interne)
    - Vrai job = "fire claude -p /executor et sortir"

    Le pattern reste coherent avec setup-scheduler.ps1 :
        VBS hidden-launcher  (gestionnaire de taches Windows)
        -> powershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -File start-claude-executor.ps1
        -> claude -p "/executor"  (depuis $RepoRoot)

.PARAMETER RepoRoot
    Chemin du repo (defaut = resolution auto depuis l'emplacement du script).

.PARAMETER DryRun
    Affiche la commande sans lancer Claude.

.NOTES
    Issue : #3141
    Cadence : 4h (alignee sur les mandates user 2026-08-15/17 — executors z.ai unifies)
    Substitution : CronCreate("41 */4 * * *", "/executor") -> Register-ScheduledTask
    Cleanup : apres migration, supprimer CronList job avec CronDelete <id>.
#>

param(
    [string]$RepoRoot = '',
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'

# --- Resolve RepoRoot ---
if ([string]::IsNullOrEmpty($RepoRoot)) {
    $scriptDir = Split-Path $MyInvocation.MyCommand.Path -Parent
    $RepoRoot = (Split-Path (Split-Path $scriptDir -Parent) -Parent)
}

if (-not (Test-Path (Join-Path $RepoRoot '.git'))) {
    Write-Error "[ERROR] RepoRoot invalide (pas de .git) : $RepoRoot"
    exit 1
}

# --- Build the command ---
$claudeCmd = 'claude'
$prompt = '/executor'
# Headless : aucun humain ne peut repondre a une demande d'approbation. Sans ce flag,
# la session spawnee bloque sur la premiere (MCP roo-state-manager, git fetch, gh) et
# le cycle est MUET alors que le fichier de log existe -- le critere d'acceptation
# "le log existe" passe pendant que rien ne tourne (#3141, feux 18/08 : po-2023 12:08,
# po-2024 12:36). Meme posture que les trois autres wrappers headless du repertoire :
# start-claude-worker.ps1, start-claude-coordinator.ps1, start-meta-audit.ps1.
# --permission-mode acceptEdits ne suffirait pas : il n'auto-accepte que les editions,
# pas les appels bash/MCP, qui sont precisement ceux que les logs montrent refuses.
# Une seule liste d'arguments, consommee par le DryRun ET par l'appel reel, pour que
# les deux ne puissent pas diverger.
$claudeArgs = @('-p', $prompt, '--dangerously-skip-permissions')
$envBlock = @{
    CLAUDE_CODE_AUTO_COMPACT_WINDOW = '200000'
    CLAUDE_AUTOCOMPACT_PCT_OVERRIDE = '90'
    WAKE_DEFAULT_MODEL              = 'sonnet'
}

# --- DryRun : sortir AVANT la prise de lock ---
# Incident 17/08 : le DryRun ecrivait le lock puis exit 0 sans passer par le
# finally qui le nettoie -> lock orphelin -> PID reutilise par un processus
# sans rapport -> tous les feux suivants SKIPpent silencieusement.
if ($DryRun) {
    Write-Host "[DRY RUN] cwd: $RepoRoot"
    Write-Host "[DRY RUN] env: $($envBlock | ConvertTo-Json -Compress)"
    Write-Host "[DRY RUN] cmd: $claudeCmd $($claudeArgs -join ' ')"
    exit 0
}

# --- Single-instance guard ---
# Si une session /executor tourne deja (schtask ou interactif), sortir silencieusement.
# Evite double-fire quand deux schtasks pointent vers le meme script.
# Le proprietaire du lock doit etre un process de CETTE chaine (pwsh/claude/node) :
# un PID vivant mais reutilise par un process sans rapport (SoundTune.exe, incident
# 17/08) ne compte pas comme session active.
$lockFile = Join-Path $env:TEMP 'claude-executor.lock'
if (Test-Path $lockFile) {
    $existingPid = Get-Content $lockFile -ErrorAction SilentlyContinue
    $owner = if ($existingPid) { Get-Process -Id $existingPid -ErrorAction SilentlyContinue } else { $null }
    if ($owner -and @('pwsh', 'powershell', 'claude', 'node') -contains $owner.ProcessName) {
        Write-Host "[SKIP] Session /executor deja active (PID $existingPid)"
        exit 0
    }
    Remove-Item $lockFile -Force -ErrorAction SilentlyContinue
}
$myPid = $PID
Set-Content -Path $lockFile -Value $myPid -NoNewline

# --- Log dir ---
$logDir = Join-Path $RepoRoot 'outputs/scheduling/logs'
if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Force -Path $logDir | Out-Null
}
$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$logFile = Join-Path $logDir "executor-$timestamp.log"

# --- Persist env into a temp file so the spawned claude.exe inherits them ---
# (Set-Content alone ne suffit pas — `claude` est un process enfant, pas PowerShell.)
foreach ($kv in $envBlock.GetEnumerator()) {
    [Environment]::SetEnvironmentVariable($kv.Key, $kv.Value, 'Process')
}

# --- Run claude -p /executor, tee to log file ---
Push-Location $RepoRoot
try {
    $envBlock | Out-File -FilePath "$logFile.env" -Encoding utf8
    $output = & $claudeCmd @claudeArgs 2>&1 | Tee-Object -FilePath $logFile
    $exitCode = $LASTEXITCODE
} finally {
    Pop-Location
    Remove-Item $lockFile -Force -ErrorAction SilentlyContinue
}

Write-Host "[DONE] /executor cycle — exit=$exitCode — log=$logFile"
exit $exitCode