<#
.SYNOPSIS
    Démarre un worker Claude Code avec mode automatique et escalade

.DESCRIPTION
    Phase 1 - Scheduling Claude Code (#414)

    Ce script :
    1. Récupère les tâches assignées via RooSync
    2. Détermine le mode approprié (simple/complex)
    3. Crée un worktree pour isolation (optionnel)
    4. Lance Claude avec --dangerously-skip-permissions
    5. Gère les escalades automatiques
    6. Reporte les résultats au coordinateur

.PARAMETER Mode
    Mode Claude à utiliser (sync-simple, code-simple, etc.)
    Si non spécifié, déterminé automatiquement selon la tâche

.PARAMETER TaskId
    ID de la tâche RooSync à traiter
    Si non spécifié, récupère la prochaine tâche de l'inbox

.PARAMETER UseWorktree
    Créer un worktree Git pour isolation (recommandé)

.PARAMETER MaxIterations
    Nombre maximum d'itérations (override config mode)

.EXAMPLE
    .\start-claude-worker.ps1
    # Récupère prochaine tâche inbox + mode auto

.EXAMPLE
    .\start-claude-worker.ps1 -Mode "sync-complex" -TaskId "msg-20260211-abc123"
    # Traite tâche spécifique en mode complex

.NOTES
    Auteur: Claude Code (myia-po-2026)
    Date: 2026-02-11
    Version: 1.0.0
    Issue: #414
#>

[CmdletBinding()]
param(
    [string]$Mode,
    [string]$TaskId,
    [switch]$UseWorktree = $false,
    [int]$MaxIterations = 0,
    [switch]$DryRun = $false
)

# Configuration
$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Resolve-Path "$ScriptDir\..\.."
$ModesConfigPath = Join-Path $RepoRoot ".claude\modes\modes-config.json"
$LogDir = Join-Path $RepoRoot ".claude\logs"

# Créer répertoire logs si nécessaire
if (-not (Test-Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir | Out-Null
}

$LogFile = Join-Path $LogDir "worker-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogMessage = "[$Timestamp] [$Level] $Message"
    Write-Host $LogMessage
    Add-Content -Path $LogFile -Value $LogMessage
}

function Get-ModeConfig {
    param([string]$ModeId)

    if (-not (Test-Path $ModesConfigPath)) {
        Write-Log "Configuration modes introuvable: $ModesConfigPath" "ERROR"
        return $null
    }

    $Config = Get-Content $ModesConfigPath | ConvertFrom-Json
    $ModeConfig = $Config.modes | Where-Object { $_.id -eq $ModeId }

    if (-not $ModeConfig) {
        Write-Log "Mode '$ModeId' introuvable dans config" "ERROR"
        return $null
    }

    return $ModeConfig
}

function Get-NextTask {
    Write-Log "Récupération prochaine tâche RooSync..."

    # Appel MCP roosync_read pour lire inbox
    # TODO: Implémenter appel MCP via claude CLI
    # Pour l'instant, retourne tâche factice

    $Task = @{
        id = "msg-test-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
        subject = "Sync tour quotidien"
        priority = "MEDIUM"
        suggestedMode = "sync-simple"
        prompt = "Effectue un sync-tour complet : git pull, check messages RooSync, valider build/tests, reporter status."
    }

    Write-Log "Tâche récupérée: $($Task.id) - $($Task.subject)"
    return $Task
}

function Determine-Mode {
    param($Task)

    # Si mode spécifié en paramètre, utiliser celui-là
    if ($Mode) {
        Write-Log "Mode spécifié explicitement: $Mode"
        return $Mode
    }

    # Sinon, utiliser mode suggéré par la tâche
    if ($Task.suggestedMode) {
        Write-Log "Mode suggéré par tâche: $($Task.suggestedMode)"
        return $Task.suggestedMode
    }

    # Par défaut, sync-simple
    Write-Log "Aucun mode spécifié, utilisation par défaut: sync-simple"
    return "sync-simple"
}

function Create-Worktree {
    param([string]$TaskId)

    if (-not $UseWorktree) {
        Write-Log "Worktree désactivé, travail sur branche principale"
        return $null
    }

    $WorktreeName = "claude-worker-$TaskId"
    $WorktreePath = Join-Path $RepoRoot ".worktrees\$WorktreeName"

    Write-Log "Création worktree: $WorktreePath"

    try {
        # Créer worktree
        git worktree add $WorktreePath -b $WorktreeName 2>&1 | ForEach-Object { Write-Log $_ "GIT" }

        Write-Log "Worktree créé avec succès"
        return $WorktreePath
    }
    catch {
        Write-Log "Erreur création worktree: $_" "ERROR"
        return $null
    }
}

function Remove-Worktree {
    param([string]$WorktreePath)

    if (-not $WorktreePath -or -not (Test-Path $WorktreePath)) {
        return
    }

    Write-Log "Suppression worktree: $WorktreePath"

    try {
        git worktree remove $WorktreePath --force 2>&1 | ForEach-Object { Write-Log $_ "GIT" }
        Write-Log "Worktree supprimé"
    }
    catch {
        Write-Log "Erreur suppression worktree: $_" "WARN"
    }
}

function Invoke-Claude {
    param(
        [string]$ModeId,
        [string]$Prompt,
        [string]$WorkingDir,
        [int]$MaxIter
    )

    $ModeConfig = Get-ModeConfig -ModeId $ModeId
    if (-not $ModeConfig) {
        Write-Log "Configuration mode '$ModeId' introuvable" "ERROR"
        return @{ success = $false; error = "Mode config not found" }
    }

    Write-Log "Lancement Claude en mode: $ModeId (model: $($ModeConfig.model))"
    Write-Log "Prompt: $Prompt"

    # Déterminer maxIterations
    $Iterations = if ($MaxIter -gt 0) { $MaxIter } else { $ModeConfig.maxIterations }

    # Construire commande Claude CLI
    # Note: --dangerously-skip-permissions requis pour autonomie
    $ClaudeArgs = @(
        "--dangerously-skip-permissions",
        "-p", "`"$Prompt`""
    )

    # TODO: Ajouter support model selection (via env var ou config)
    # Pour l'instant, utilise modèle par défaut

    if ($DryRun) {
        Write-Log "[DRY-RUN] Commande qui serait exécutée:" "INFO"
        Write-Log "claude $($ClaudeArgs -join ' ')" "INFO"
        return @{ success = $true; dryRun = $true }
    }

    try {
        Push-Location $WorkingDir

        Write-Log "Exécution dans: $WorkingDir"
        Write-Log "Max iterations: $Iterations"

        # Lancer Claude (note: cette ligne ne fonctionnera pas encore car
        # il faut implémenter l'intégration avec Ralph Wiggum pour les boucles)
        # $Output = & claude @ClaudeArgs 2>&1

        # Pour l'instant, simuler succès
        Write-Log "[SIMULATION] Claude s'exécuterait avec mode $ModeId" "INFO"
        $Output = "Simulation: sync-tour complété avec succès"

        Pop-Location

        Write-Log "Exécution Claude terminée"
        Write-Log "Output: $Output"

        return @{
            success = $true
            output = $Output
            mode = $ModeId
            iterations = 1  # À implémenter: compter réellement
        }
    }
    catch {
        Pop-Location
        Write-Log "Erreur exécution Claude: $_" "ERROR"
        return @{ success = $false; error = $_.Exception.Message }
    }
}

function Check-Escalation {
    param(
        $Result,
        [string]$CurrentMode
    )

    $ModeConfig = Get-ModeConfig -ModeId $CurrentMode

    # Pas d'escalade si pas de config ou déjà au max
    if (-not $ModeConfig -or -not $ModeConfig.escalation) {
        return $null
    }

    # Vérifier conditions d'escalade
    if (-not $Result.success) {
        Write-Log "Échec détecté, escalade vers: $($ModeConfig.escalation.triggerMode)" "WARN"
        return $ModeConfig.escalation.triggerMode
    }

    # TODO: Analyser output pour détecter conditions d'escalade
    # (conflits git, complexité détectée, etc.)

    return $null
}

function Report-Results {
    param($Task, $Result, [string]$FinalMode)

    Write-Log "Rapport des résultats au coordinateur..."

    $ReportMessage = @"
## Worker Report - $($env:COMPUTERNAME)

**Tâche:** $($Task.id) - $($Task.subject)
**Mode utilisé:** $FinalMode
**Statut:** $(if ($Result.success) { "✅ SUCCÈS" } else { "❌ ÉCHEC" })
**Itérations:** $($Result.iterations)

### Output
``````
$($Result.output)
``````

### Logs
Voir: $LogFile
"@

    # TODO: Envoyer message RooSync au coordinateur
    # Pour l'instant, juste logger
    Write-Log "Rapport préparé (envoi RooSync à implémenter)"
    Write-Log $ReportMessage
}

# ============================================================================
# MAIN WORKFLOW
# ============================================================================

Write-Log "=== DÉMARRAGE CLAUDE WORKER ==="
Write-Log "Machine: $env:COMPUTERNAME"
Write-Log "RepoRoot: $RepoRoot"
Write-Log "DryRun: $DryRun"

try {
    # 1. Récupérer tâche
    if ($TaskId) {
        Write-Log "TaskId spécifié: $TaskId"
        # TODO: Récupérer tâche spécifique via roosync_read
        $Task = @{ id = $TaskId; subject = "Tâche spécifiée"; suggestedMode = $Mode }
    } else {
        $Task = Get-NextTask
    }

    # 2. Déterminer mode
    $SelectedMode = Determine-Mode -Task $Task

    # 3. Créer worktree (optionnel)
    $WorktreePath = if ($UseWorktree) {
        Create-Worktree -TaskId $Task.id
    } else {
        $RepoRoot
    }

    if (-not $WorktreePath) {
        $WorktreePath = $RepoRoot
    }

    # 4. Exécuter Claude avec mode sélectionné
    $Result = Invoke-Claude -ModeId $SelectedMode -Prompt $Task.prompt -WorkingDir $WorktreePath -MaxIter $MaxIterations

    # 5. Vérifier escalade
    $EscalateMode = Check-Escalation -Result $Result -CurrentMode $SelectedMode

    if ($EscalateMode) {
        Write-Log "ESCALADE vers mode: $EscalateMode" "WARN"
        $Result = Invoke-Claude -ModeId $EscalateMode -Prompt $Task.prompt -WorkingDir $WorktreePath -MaxIter $MaxIterations
        $SelectedMode = $EscalateMode
    }

    # 6. Reporter résultats
    Report-Results -Task $Task -Result $Result -FinalMode $SelectedMode

    # 7. Cleanup worktree
    if ($UseWorktree -and $WorktreePath -ne $RepoRoot) {
        Remove-Worktree -WorktreePath $WorktreePath
    }

    Write-Log "=== WORKER TERMINÉ ==="

    if ($Result.success) {
        exit 0
    } else {
        exit 1
    }
}
catch {
    Write-Log "ERREUR CRITIQUE: $_" "ERROR"
    Write-Log $_.ScriptStackTrace "ERROR"

    # Cleanup en cas d'erreur
    if ($UseWorktree -and $WorktreePath -and ($WorktreePath -ne $RepoRoot)) {
        Remove-Worktree -WorktreePath $WorktreePath
    }

    exit 1
}
