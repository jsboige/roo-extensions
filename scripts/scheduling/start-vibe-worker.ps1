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
    Issue : #3277 — lock atomique (CreateNew + FileShare.None), SKIP = exit 75
    (le listener n'avance pas lastAck sur 75 : un skip ne consomme pas le dispatch).
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
    # UTC réel (#3277 fix 5) : l'heure locale collait au raisonnement cross-machine.
    $ts = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    $line = "[$ts] [$Level] $Message"
    try {
        Add-Content -Path $LogFile -Value $line -Encoding utf8NoBOM
    } catch { }
    $color = switch ($Level) { "ERROR" { "Red" }; "WARN" { "Yellow" }; default { "Gray" } }
    Write-Host $line -ForegroundColor $color
}

# ========== HEARTBEAT (pattern #3199) ==========
# Implémentation partagée : scripts/common/worker-heartbeat.ps1 (#3207, #3209).
# Declared before the early-exit guards so EVERY exit path can heartbeat, including
# operator errors (missing profile / missing command). Les appels passent
# -LogPrefix 'Heartbeat' pour préserver les logs greppables d'avant l'extraction.

. (Join-Path $ScriptDir '..\common\worker-heartbeat.ps1')

# ========== PROFILE LOADING ==========

if (-not [string]::IsNullOrWhiteSpace($Model)) {
    Write-Log "Model hint received ('$Model') — ignored in v1 (Vibe has no multi-model chain)"
}

$profileObj = $null
if (-not [string]::IsNullOrWhiteSpace($ConfigPath)) {
    if (-not (Test-Path $ConfigPath)) {
        Write-Log "ConfigPath not found: $ConfigPath" "ERROR"
        Write-WorkerHeartbeat -LogPrefix 'Heartbeat'
        exit 1
    }
    $profileObj = Get-Content $ConfigPath -Raw | ConvertFrom-Json
    if ($profileObj.harnessCommand) { $HarnessCommand = $profileObj.harnessCommand }
    if ($profileObj.workspace) { $Workspace = $profileObj.workspace }
    Write-Log "Profile loaded: workspace=$Workspace"
}

if ([string]::IsNullOrWhiteSpace($HarnessCommand)) {
    Write-Log "HarnessCommand is required (or -ConfigPath with harnessCommand)" "ERROR"
    Write-WorkerHeartbeat -LogPrefix 'Heartbeat'
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

# ========== NO-OP GUARD (#3296) ==========
# Un tick planifie sans [WAKE-VIBE] en attente est un NO-OP, pas un echec. La commande
# harnais du profil CoursIA est `--wake`-only : le driver prend son prompt dans
# VIBE_WAKE_PAYLOAD (vibe-acp-driver.py l.149) et sort en erreur sans lui. La schtask
# tirant toutes les heures sans condition, ~105 des 121 ticks de 5 jours (86 %) etaient
# des exit-1 structurels — assez de bruit ERROR pour noyer les vrais.
#
# On sort AVANT le lock : un tick qui ne fera rien n'a aucune raison de le prendre, et
# rien a liberer (le `finally` de l'execution ne couvre pas ce point du script).
# Le heartbeat, lui, est ecrit : sans lui le worker paraitrait mort entre deux WAKE,
# qui sont rares. C'est la convention que ce fichier declare l.96.
#
# Deux absences distinctes, deux sorties — ne pas les confondre :
#   * aucun -MessagePayloadFile passe  -> tick planifie, aucun dispatch n'existe -> exit 0.
#   * -MessagePayloadFile passe mais illisible -> un dispatch A ete route et son payload
#     manque : c'est une anomalie, elle doit rester bruyante. Ce cas ne passe donc PAS
#     par cette garde et retombe sur le chemin d'erreur existant.
# Un `--prompt`/`--prompt-file` explicite bat le payload cote driver (l.149) : une telle
# commande fonctionne sans WAKE et ne doit pas etre sautee.
$wakeOnly = ($HarnessCommand -match '(^|\s)--wake(\s|$)') -and
            ($HarnessCommand -notmatch '(^|\s)--prompt(-file)?[\s=]')
if ($wakeOnly -and
    [string]::IsNullOrWhiteSpace($MessagePayloadFile) -and
    [string]::IsNullOrWhiteSpace($env:VIBE_WAKE_PAYLOAD)) {
    Write-Log "[SKIP] no WAKE payload pending - scheduled tick is a no-op (exit 0)."
    Write-WorkerHeartbeat -LogPrefix 'Heartbeat'
    exit 0
}

# ========== ANTI-OVERLAP LOCK (#3277 fix 2 : création atomique, pas check-then-create) ==========
# Incident 25/08 : deux invocations à la même seconde passaient TOUTES DEUX le check
# Test-Path/Set-Content → 2 workers payés en parallèle (le logueur du vainqueur
# voyait « Remove-Item vibe-worker.lock — does not exist » : chaque worker supprimait
# le lock de l'autre).
#
# CreateNew + FileShare.None est atomique kernel-side : un seul gagnant, et le handle
# resté ouvert bloque toute réouverture tant que le worker vit. Discriminateur
# stale : si la lecture du lock RÉUSSIT, personne ne détient de handle (le titulaire
# bloque aussi la lecture via FileShare.None) → reste de crash → remove + un unique
# retry. Si la lecture échoue (sharing violation), un worker VIVANT le détient → SKIP.

$LockFile = Join-Path $LogDir "vibe-worker.lock"
$script:LockStream = $null

function Open-WorkerLock {
    for ($attempt = 1; $attempt -le 2; $attempt++) {
        try {
            $script:LockStream = [System.IO.File]::Open($LockFile,
                [System.IO.FileMode]::CreateNew,
                [System.IO.FileAccess]::Write,
                [System.IO.FileShare]::None)
            $MachineLock = if ($env:COMPUTERNAME) { $env:COMPUTERNAME.ToLower() } else { 'unknown' }
            $lockBody = @{ pid = $PID; startedAt = (Get-Date).ToUniversalTime().ToString("o"); machine = $MachineLock } | ConvertTo-Json -Compress
            $bytes = [System.Text.Encoding]::UTF8.GetBytes($lockBody)
            $script:LockStream.Write($bytes, 0, $bytes.Length)
            $script:LockStream.Flush()
            return $true
        } catch [System.IO.IOException] {
            try {
                # Le fichier existe (CreateNew a échoué). Le lit-on ?
                $null = [System.IO.File]::ReadAllText($LockFile)
                # Lecture OK → aucun handle détient le fichier → lock stale (crash d'un
                # worker précédent) → remove + retry CreateNew (au plus une fois).
                Remove-Item $LockFile -Force -ErrorAction SilentlyContinue
                continue
            } catch {
                # Sharing violation → un worker VIVANT détient le lock → SKIP.
                return $false
            }
        } catch {
            return $false
        }
    }
    return $false
}

if (-not (Open-WorkerLock)) {
    # exit 75 (#3277 fix 3) : SKIP ≠ succès. Le listener n'avance PAS lastAck sur 75 —
    # le dispatch n'est pas consommé par un worker qui n'a rien fait.
    Write-Log "[SKIP] Another vibe worker holds the lock — exiting WITHOUT consuming the dispatch (exit 75)."
    Write-WorkerHeartbeat -LogPrefix 'Heartbeat'
    exit 75
}

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
    Write-WorkerHeartbeat -LogPrefix 'Heartbeat'
    # Relâcher le handle AVANT le delete (un handle ouvert rend le remove non garanti).
    if ($script:LockStream) {
        try { $script:LockStream.Close() } catch { }
        $script:LockStream = $null
    }
    Remove-Item $LockFile -Force -ErrorAction SilentlyContinue
}

exit $exitCode
