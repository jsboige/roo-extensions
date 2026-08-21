<#
.SYNOPSIS
    Vibe worker: execute un tick Mistral Vibe (pas de cron dans son harnais — la cadence est portee par schtask).

.DESCRIPTION
    Worker dedie pour Mistral Vibe (#3202, decision utilisateur 21/08 : Vibe n'a pas de
    CronCreate, la schtask est la seule option de cadence, 1h au depart). Reutilise les
    conventions eprouvees de start-claude-worker.ps1 sans toucher ce script :
      - Lock-file anti-chevauchement (JSON pid/startedAt/machine)
      - Write-WorkerHeartbeat (pattern #3199 : worker-heartbeats/<machine>.heartbeat)
      - Logs dans outputs/scheduling/logs/
      - Sortie bruyante sur erreur (exit 1 + Write-Log ERROR)
    Pas d'escalade multi-modele en v1 (Vibe n'a pas la chaine Haiku->Sonnet->Opus).

    La commande harnais est passee via -HarnessCommand ; le profil CoursIA
    (vibe-profiles/coursia.json) documente l'invocation standard pour la serie vibe-coding.

.PARAMETER HarnessCommand
    Commande CLI Vibe a executer (ex: "mistral vibe run --prompt ..."). Requis sauf si -ConfigPath.

.PARAMETER Workspace
    Workspace cible (contexte logs/heartbeat). Defaut : nom du repertoire courant.

.PARAMETER ConfigPath
    Chemin optionnel vers un profil JSON (workspace, harnessCommand, intervalHours).
    Si fourni, -HarnessCommand et -Workspace sont ecrases par les valeurs du profil.

.PARAMETER MaxIterations
    Nombre max d'iterations par tick (defaut : 1). Reserve pour l'avenir.

.PARAMETER MessagePayloadFile
    Fichier JSON optionnel avec le message declencheur (passe par le dashboard-listener
    sur un [WAKE-VIBE]). Le contenu est injecte dans la variable d'environnement
    VIBE_WAKE_PAYLOAD pour que la commande harnais puisse le consommer.

.PARAMETER Model
    Accepte mais non utilise en v1 (Vibe n'a pas de chaine multi-modele). Present pour que
    l'invocation reste valide si un `model=X` traverse depuis une ligne WAKE : le listener
    garde deja le -Model a la branche claude, ce parametre est la defense en profondeur.

.PARAMETER DryRun
    Affiche l'invocation prevue sans executer.

.EXAMPLE
    pwsh -File scripts/scheduling/start-vibe-worker.ps1 -HarnessCommand "mistral vibe run" -Workspace CoursIA

.EXAMPLE
    pwsh -File scripts/scheduling/start-vibe-worker.ps1 -ConfigPath scripts/scheduling/vibe-profiles/coursia.json -DryRun

.NOTES
    Issue : #3202 (GO user 21/08)
    Mutualisation : lock, heartbeat, logs sont candidats a une extraction commune future
    (voir table des gisements dans le body de l'issue #3202).
#>
[CmdletBinding()]
param(
    [string]$HarnessCommand = "",
    [string]$Workspace = "",
    [string]$ConfigPath = "",
    [int]$MaxIterations = 1,
    [string]$MessagePayloadFile = "",
    [string]$Model = "",
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = (Split-Path (Split-Path $ScriptDir -Parent) -Parent)

# ========== LOGGING ==========

$LogDir = if (-not [string]::IsNullOrWhiteSpace($env:VIBE_WORKER_LOG_DIR)) {
    $env:VIBE_WORKER_LOG_DIR
} else {
    Join-Path $RepoRoot "outputs\scheduling\logs"
}
if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir -Force | Out-Null }
$LogFile = Join-Path $LogDir ("vibe-worker-{0}.log" -f (Get-Date -Format "yyyyMMdd"))

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "[$ts] [$Level] $Message"
    try {
        Add-Content -Path $LogFile -Value $line -Encoding utf8NoBOM
    } catch { }
    $color = switch ($Level) { "ERROR" { "Red" }; "WARN" { "Yellow" }; default { "Gray" } }
    Write-Host $line -ForegroundColor $color
}

# ========== HEARTBEAT (pattern #3199) ==========
# Declared before the early-exit guards so EVERY exit path can heartbeat, including
# operator errors (missing profile / missing command). #3199 covers all exits in
# start-claude-worker; keeping parity here matters for the future shared extraction.

function Write-WorkerHeartbeat {
    try {
        $SharedPath = $env:ROOSYNC_SHARED_PATH
        if (-not $SharedPath) { return }
        $HeartbeatDir = Join-Path $SharedPath "worker-heartbeats"
        if (-not (Test-Path $HeartbeatDir)) {
            New-Item -ItemType Directory -Path $HeartbeatDir -Force | Out-Null
        }
        $MachineId = if ($env:COMPUTERNAME) { $env:COMPUTERNAME.ToLower() } else { 'unknown' }
        $HeartbeatFile = Join-Path $HeartbeatDir "$MachineId.heartbeat"
        $Timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
        # Écriture bornée (#3207) : le WriteAllText GDrive peut staller indéfiniment si DriveFS est
        # en attente I/O ininterruptible (observé ~12 min dans un appel réputé « non-fatal »). On
        # l'exécute dans un process enfant (Start-Job) borné à 3 s, tuable par Stop-Job : le tick ne
        # stalle jamais, et on tue un process (pas un thread .NET bloqué, dont on ne se libère pas).
        $job = Start-Job -ScriptBlock {
            param($file, $content)
            [System.IO.File]::WriteAllText($file, $content, [System.Text.UTF8Encoding]::new($false))
        } -ArgumentList $HeartbeatFile, $Timestamp

        if ($null -ne $job) {
            if (Wait-Job $job -Timeout 3) {
                if ($job.State -eq 'Failed') {
                    Write-Log "Heartbeat failed (non-fatal): $($job.ChildJobs[0].JobStateInfo.Reason)" "WARN"
                } else {
                    Write-Log "Heartbeat written ($Timestamp)" "DEBUG"
                }
            } else {
                Write-Log "Heartbeat write exceeded 3s — abandoned (DriveFS stall?)" "WARN"
            }
            Remove-Job $job -Force -ErrorAction SilentlyContinue
        }
    } catch {
        # Non-fatal : GDriveFS indisponible ne doit jamais faire echouer le worker (#2845)
        Write-Log "Heartbeat failed (non-fatal): $_" "WARN"
    }
}

# ========== PROFILE LOADING ==========

if (-not [string]::IsNullOrWhiteSpace($Model)) {
    Write-Log "Model hint received ('$Model') — ignored in v1 (Vibe has no multi-model chain)"
}

$profileObj = $null
if (-not [string]::IsNullOrWhiteSpace($ConfigPath)) {
    if (-not (Test-Path $ConfigPath)) {
        Write-Log "ConfigPath not found: $ConfigPath" "ERROR"
        Write-WorkerHeartbeat
        exit 1
    }
    $profileObj = Get-Content $ConfigPath -Raw | ConvertFrom-Json
    if ($profileObj.harnessCommand) { $HarnessCommand = $profileObj.harnessCommand }
    if ($profileObj.workspace) { $Workspace = $profileObj.workspace }
    Write-Log "Profile loaded: workspace=$Workspace"
}

if ([string]::IsNullOrWhiteSpace($HarnessCommand)) {
    Write-Log "HarnessCommand is required (or -ConfigPath with harnessCommand)" "ERROR"
    Write-WorkerHeartbeat
    exit 1
}
if ([string]::IsNullOrWhiteSpace($Workspace)) {
    $Workspace = Split-Path (Get-Location) -Leaf
}

# Workspace path resolution: profile wins, else workspace-paths.json, else CWD
$WorkspacePath = ""
if ($profileObj -and $profileObj.workspacePath) {
    $WorkspacePath = $profileObj.workspacePath
} else {
    $wsPathFile = Join-Path $RepoRoot ".claude/local/workspace-paths.json"
    if (Test-Path $wsPathFile) {
        try {
            $wsMap = Get-Content $wsPathFile -Raw | ConvertFrom-Json
            foreach ($prop in $wsMap.PSObject.Properties) {
                if ($prop.Name -ieq $Workspace) { $WorkspacePath = [string]$prop.Value; break }
            }
        } catch { }
    }
}
if (-not [string]::IsNullOrWhiteSpace($WorkspacePath) -and (Test-Path $WorkspacePath)) {
    Set-Location $WorkspacePath
    Write-Log "Working directory: $WorkspacePath"
} else {
    Write-Log "No workspace path resolved for '$Workspace' — running from $PWD" "WARN"
}

Write-Log "Vibe worker tick: workspace=$Workspace cmd='$HarnessCommand' maxIter=$MaxIterations dryRun=$DryRun"

if ($DryRun) {
    Write-Log "[DRY-RUN] Would execute: $HarnessCommand (workspace=$Workspace)" "INFO"
    exit 0
}

# ========== ANTI-OVERLAP LOCK (pattern start-claude-worker.ps1) ==========

$LockFile = Join-Path $LogDir "vibe-worker.lock"
if (Test-Path $LockFile) {
    try {
        $LockContent = Get-Content $LockFile -Raw | ConvertFrom-Json
        if ($LockContent.pid) {
            $ExistingProcess = Get-Process -Id $LockContent.pid -ErrorAction SilentlyContinue
            if ($ExistingProcess) {
                Write-Log "[SKIP] Another vibe worker is running (PID $($LockContent.pid), started $($LockContent.startedAt))"
                exit 0
            }
        }
    } catch { }
    Remove-Item $LockFile -Force -ErrorAction SilentlyContinue
}
$MachineLock = if ($env:COMPUTERNAME) { $env:COMPUTERNAME.ToLower() } else { 'unknown' }
@{ pid = $PID; startedAt = (Get-Date -Format "o"); machine = $MachineLock } | ConvertTo-Json | Set-Content $LockFile -Force

# ========== EXECUTION ==========

# #3202: If a WAKE payload was passed by the listener, expose it to the harness
# command via VIBE_WAKE_PAYLOAD (env var avoids quoting issues with markdown content).
if (-not [string]::IsNullOrWhiteSpace($MessagePayloadFile) -and (Test-Path $MessagePayloadFile)) {
    $env:VIBE_WAKE_PAYLOAD = [System.IO.File]::ReadAllText($MessagePayloadFile, [System.Text.UTF8Encoding]::new($false))
    Write-Log "WAKE payload injected from $MessagePayloadFile ($($env:VIBE_WAKE_PAYLOAD.Length) chars)"
}

$exitCode = 0
try {
    $iterations = [Math]::Max(1, $MaxIterations)
    for ($i = 1; $i -le $iterations; $i++) {
        Write-Log "Iteration $i/$iterations : $HarnessCommand"
        $output = & pwsh -NoProfile -Command $HarnessCommand 2>&1
        $iterExit = $LASTEXITCODE
        if ($output) { $output | ForEach-Object { Write-Log "  $_" } }
        if ($iterExit -ne 0) {
            Write-Log "HarnessCommand exited with code $iterExit (iteration $i)" "ERROR"
            $exitCode = 1
            break
        }
    }
} catch {
    Write-Log "Worker crashed: $_" "ERROR"
    Write-Log "Stack: $($_.ScriptStackTrace)" "ERROR"
    $exitCode = 1
} finally {
    Write-WorkerHeartbeat
    Remove-Item $LockFile -Force -ErrorAction SilentlyContinue
}

exit $exitCode
