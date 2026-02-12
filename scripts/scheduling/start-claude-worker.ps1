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

.PARAMETER Model
    Modèle Claude à utiliser (override config mode)
    Ex: "sonnet", "opus", "haiku"

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
    [string]$Model,
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
    <#
    .SYNOPSIS
    Récupère la prochaine tâche depuis RooSync, GitHub, ou fallback (HYBRIDE)

    .DESCRIPTION
    Système hybride à 3 priorités :
    1. RooSync inbox (instructions coordinateur)
    2. GitHub issues avec label "roo-schedulable" ET champ Agent
    3. Fallback maintenance (build + tests)

    .OUTPUTS
    Hashtable avec: id, subject, priority, prompt, source, [messageFile|issueNumber]
    #>

    param(
        [string]$MachineId = $env:COMPUTERNAME.ToLower(),
        [string]$AgentType = "claude"
    )

    Write-Log "Récupération prochaine tâche ($AgentType sur $MachineId)..."

    # --- PRIORITÉ 1 : RooSync inbox ---
    Write-Log "Vérification RooSync inbox..."
    $RooSyncTask = Get-RooSyncTask -MachineId $MachineId
    if ($RooSyncTask) {
        Write-Log "✅ Tâche RooSync: $($RooSyncTask.id)" "INFO"
        return $RooSyncTask
    }

    # --- PRIORITÉ 2 : GitHub issues ---
    Write-Log "Vérification GitHub issues..."
    $GitHubTask = Get-GitHubTask -AgentType $AgentType -MachineId $MachineId
    if ($GitHubTask) {
        Write-Log "✅ Tâche GitHub: #$($GitHubTask.issueNumber)" "INFO"
        # Claim l'issue immédiatement
        Claim-GitHubIssue -IssueNumber $GitHubTask.issueNumber -AgentType $AgentType -MachineId $MachineId
        return $GitHubTask
    }

    # --- PRIORITÉ 3 : Fallback maintenance ---
    Write-Log "Aucune tâche RooSync/GitHub → Fallback maintenance"
    return Get-FallbackTask
}

# =============================================================================
# TODO #1 - Helper Functions (RooSync + GitHub + Fallback)
# =============================================================================

function Get-RooSyncTask {
    param([string]$MachineId)

    $SharedPath = $env:ROOSYNC_SHARED_PATH
    if (-not $SharedPath) {
        Write-Log "ROOSYNC_SHARED_PATH non défini" "WARN"
        return $null
    }

    $InboxPath = Join-Path $SharedPath "messages\inbox"
    if (-not (Test-Path $InboxPath)) {
        Write-Log "Inbox RooSync introuvable: $InboxPath" "WARN"
        return $null
    }

    # Lire tous les messages JSON
    $Messages = Get-ChildItem $InboxPath -Filter "*.json" -ErrorAction SilentlyContinue | ForEach-Object {
        try {
            Get-Content $_.FullName -Raw | ConvertFrom-Json
        } catch {
            Write-Log "Erreur lecture $($_.Name): $_" "WARN"
            $null
        }
    } | Where-Object { $_ -ne $null }

    if ($Messages.Count -eq 0) { return $null }

    # Filtrer par machine + unread
    $MyMessages = $Messages | Where-Object {
        ($_.to -eq $MachineId -or $_.to -eq "all") -and $_.status -eq "unread"
    }

    if ($MyMessages.Count -eq 0) { return $null }

    # Trier par priorité
    $PriorityOrder = @{ "URGENT" = 1; "HIGH" = 2; "MEDIUM" = 3; "LOW" = 4 }
    $NextMessage = $MyMessages | Sort-Object { $PriorityOrder[$_.priority] } | Select-Object -First 1

    return @{
        id = $NextMessage.id
        subject = $NextMessage.subject
        priority = $NextMessage.priority
        prompt = $NextMessage.body
        source = "roosync"
        messageFile = Join-Path $InboxPath "$($NextMessage.id).json"
    }
}

function Get-GitHubTask {
    param([string]$AgentType, [string]$MachineId)

    # Vérifier gh CLI
    $GhPath = Get-Command gh -ErrorAction SilentlyContinue
    if (-not $GhPath) {
        Write-Log "gh CLI non disponible" "WARN"
        return $null
    }

    try {
        # Lister issues roo-schedulable
        $IssuesJson = & gh issue list --repo jsboige/roo-extensions `
            --state open --label roo-schedulable `
            --limit 10 --json number,title,body,assignees 2>&1

        if ($LASTEXITCODE -ne 0) { return $null }

        $Issues = $IssuesJson | ConvertFrom-Json
        if ($Issues.Count -eq 0) { return $null }

        # Filtrer par Agent et disponibilité
        foreach ($Issue in $Issues) {
            # Skip si déjà assignée
            if ($Issue.assignees.Count -gt 0) { continue }

            # Vérifier champ Agent (Claude Code, Both, Any)
            $Body = $Issue.body
            if ($AgentType -eq "claude" -and -not ($Body -match "(?i)agent:\s*(claude code|claude|both|any)")) {
                continue
            }

            # Vérifier locks git
            if (Test-GitHubIssueLock -IssueNumber $Issue.number) { continue }

            # Disponible !
            return @{
                id = "github-$($Issue.number)"
                subject = $Issue.title
                priority = "MEDIUM"
                prompt = $Body
                source = "github"
                issueNumber = $Issue.number
            }
        }

        return $null
    } catch {
        Write-Log "Erreur Get-GitHubTask: $_" "ERROR"
        return $null
    }
}

function Test-GitHubIssueLock {
    param([int]$IssueNumber)

    try {
        $CommentsJson = & gh issue view $IssueNumber --repo jsboige/roo-extensions `
            --json comments --jq '.comments[-3:]' 2>&1

        if ($LASTEXITCODE -ne 0) { return $false }

        $Comments = $CommentsJson | ConvertFrom-Json

        foreach ($Comment in $Comments) {
            $Body = $Comment.body
            $CreatedAt = [DateTime]::Parse($Comment.createdAt)
            $Age = (Get-Date).ToUniversalTime() - $CreatedAt.ToUniversalTime()

            # LOCK actif si < 5 minutes
            if (($Body -match "LOCK:" -or $Body -match "Claimed by") -and $Age.TotalMinutes -lt 5) {
                return $true
            }
        }

        return $false
    } catch {
        return $false
    }
}

function Claim-GitHubIssue {
    param([int]$IssueNumber, [string]$AgentType, [string]$MachineId)

    try {
        $Timestamp = Get-Date -Format "o"
        $Body = "Claimed by $AgentType on $MachineId at $Timestamp"
        & gh issue comment $IssueNumber --repo jsboige/roo-extensions --body $Body 2>&1 | Out-Null
        Write-Log "✅ Issue #$IssueNumber claimed"
    } catch {
        Write-Log "⚠️ Erreur claim #$IssueNumber" "WARN"
    }
}

function Get-FallbackTask {
    return @{
        id = "fallback-maintenance"
        subject = "Maintenance quotidienne (fallback)"
        priority = "LOW"
        prompt = "Exécute les tâches de maintenance :`n1. Vérifier build : cd mcps/internal/servers/roo-state-manager && npm run build`n2. Vérifier tests : npx vitest run`n3. Reporter résultats dans INTERCOM local"
        source = "fallback"
    }
}

function Mark-TaskAsComplete {
    param($Task)

    switch ($Task.source) {
        "roosync" {
            if ($Task.messageFile -and (Test-Path $Task.messageFile)) {
                try {
                    $Message = Get-Content $Task.messageFile -Raw | ConvertFrom-Json
                    $Message.status = "read"
                    $JsonText = $Message | ConvertTo-Json -Depth 10
                    [System.IO.File]::WriteAllText($Task.messageFile, $JsonText, [System.Text.UTF8Encoding]::new($false))
                    Write-Log "✅ Message RooSync marqué comme lu"
                } catch {
                    Write-Log "Erreur mark as read: $_" "ERROR"
                }
            }
        }
        "github" {
            if ($Task.issueNumber) {
                try {
                    $Body = "Executed by Claude Code scheduler on $env:COMPUTERNAME at $(Get-Date -Format o)"
                    & gh issue comment $Task.issueNumber --repo jsboige/roo-extensions --body $Body 2>&1 | Out-Null
                    Write-Log "✅ Commentaire ajouté sur #$($Task.issueNumber)"
                } catch {
                    Write-Log "Erreur comment GitHub: $_" "WARN"
                }
            }
        }
    }
}

# =============================================================================
# TODO #5 - Wait State Management
# =============================================================================

function Save-WaitState {
    <#
    .SYNOPSIS
    Sauvegarde l'état d'une tâche en attente pour reprise ultérieure

    .DESCRIPTION
    Crée un fichier JSON contenant l'état complet de la tâche :
    - Condition d'attente (waitFor, resumeWhen)
    - Contexte d'exécution (mode, model, iteration)
    - Output partiel pour reprise
    #>
    param(
        [string]$TaskId,
        [hashtable]$WaitState
    )

    try {
        # Créer répertoire si inexistant
        $WaitStatesDir = Join-Path $RepoRoot ".claude\scheduler\wait-states"
        if (-not (Test-Path $WaitStatesDir)) {
            New-Item -ItemType Directory -Path $WaitStatesDir -Force | Out-Null
            Write-Log "Répertoire wait-states créé"
        }

        # Construire objet d'état complet
        $StateObject = @{
            taskId = $TaskId
            timestamp = (Get-Date).ToUniversalTime().ToString("o")
            reason = $WaitState.reason
            waitFor = $WaitState.waitFor
            resumeWhen = $WaitState.resumeWhen
            context = @{
                mode = $WaitState.mode
                model = $WaitState.model
                iteration = $WaitState.iteration
                outputSnippet = $WaitState.context  # Dernières lignes de sortie
            }
        }

        # Sauvegarder en JSON UTF-8 sans BOM
        $StateFile = Join-Path $WaitStatesDir "$TaskId.json"
        $JsonText = $StateObject | ConvertTo-Json -Depth 10
        [System.IO.File]::WriteAllText($StateFile, $JsonText, [System.Text.UTF8Encoding]::new($false))

        Write-Log "✅ Wait state sauvegardé: $StateFile"
        Write-Log "  → Attend: $($WaitState.waitFor)"
        Write-Log "  → Reprendra: $($WaitState.resumeWhen)"
    }
    catch {
        Write-Log "Erreur sauvegarde wait state: $_" "ERROR"
    }
}

function Test-WaitStateReady {
    <#
    .SYNOPSIS
    Vérifie si une tâche en attente peut reprendre

    .DESCRIPTION
    Lit le fichier wait state et vérifie si la condition resumeWhen est remplie.
    Retourne l'état si prêt, $null sinon.

    .OUTPUTS
    Hashtable avec l'état complet si ready, $null sinon
    #>
    param([string]$TaskId)

    $StateFile = Join-Path $RepoRoot ".claude\scheduler\wait-states\$TaskId.json"

    if (-not (Test-Path $StateFile)) {
        return $null
    }

    try {
        $State = Get-Content $StateFile -Raw | ConvertFrom-Json

        Write-Log "Wait state trouvé pour tâche: $TaskId"
        Write-Log "  → Attend: $($State.waitFor)"
        Write-Log "  → Reprendra: $($State.resumeWhen)"

        # TODO: Implémenter vérification condition resumeWhen
        # Pour l'instant, toujours retourner $null (pas de reprise auto)
        # Dans une version future, vérifier :
        # - Si c'est une user approval → checker INTERCOM ou GitHub comments
        # - Si c'est une RooSync response → checker inbox
        # - Si c'est une GitHub decision → checker issue status

        Write-Log "⏸️ Condition pas encore implémentée - skip pour cette exécution"
        return $null
    }
    catch {
        Write-Log "Erreur lecture wait state: $_" "WARN"
        return $null
    }
}

# =============================================================================
# Mode Selection
# =============================================================================

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

    # Déterminer modèle à utiliser
    # Priority: 1. Paramètre $Model (script-level), 2. Config mode, 3. Défaut
    $ModelToUse = if ($Model) {
        Write-Log "Override modèle via paramètre: $Model"
        $Model
    }
    elseif ($ModeConfig.model) {
        $ModeConfig.model
    }
    else {
        "sonnet"  # Défaut si aucun modèle spécifié
    }

    # Construire commande Claude CLI
    # Note: --dangerously-skip-permissions requis pour autonomie
    $ClaudeArgs = @(
        "--dangerously-skip-permissions",
        "--model", $ModelToUse,
        "-p", "`"$Prompt`""
    )

    if ($DryRun) {
        Write-Log "[DRY-RUN] Commande qui serait exécutée:" "INFO"
        Write-Log "claude $($ClaudeArgs -join ' ')" "INFO"
        return @{ success = $true; dryRun = $true }
    }

    try {
        Push-Location $WorkingDir

        Write-Log "Exécution dans: $WorkingDir"
        Write-Log "Max iterations: $Iterations"

        # =============================================================================
        # TODO #3 - Ralph Wiggum Loop (Option B - Internal Loop)
        # Pattern: Gather context → Take action → Verify → Repeat
        # =============================================================================

        $CurrentIteration = 0
        $Continue = $true
        $CumulativeOutput = @()
        $NeedsEscalation = $false
        $WaitStateData = $null

        while ($Continue -and $CurrentIteration -lt $Iterations) {
            $CurrentIteration++
            Write-Log "Ralph Wiggum - Iteration $CurrentIteration/$Iterations..."

            # TAKE ACTION: Exécuter Claude CLI
            try {
                $IterationOutput = & claude @ClaudeArgs 2>&1
                $CumulativeOutput += $IterationOutput
            }
            catch {
                Write-Log "Erreur exécution Claude (iteration $CurrentIteration): $_" "ERROR"
                $CumulativeOutput += "ERROR: $_"
                $Continue = $false
                break
            }

            # VERIFY: Parser signaux explicites de l'agent
            # Format attendu:
            # === AGENT STATUS ===
            # STATUS: <continue|escalate|wait|success|failure>
            # REASON: <description>
            # ESCALATE_TO: <model> (optionnel)
            # WAIT_FOR: <condition> (optionnel)
            # ===================
            $OutputText = $IterationOutput -join "`n"

            # Parser le signal STATUS (si présent)
            if ($OutputText -match "STATUS:\s*(\w+)") {
                $Status = $Matches[1].ToLower()

                # Extraire la raison si présente
                $Reason = if ($OutputText -match "REASON:\s*(.+)") { $Matches[1].Trim() } else { "Non spécifiée" }

                switch ($Status) {
                    "continue" {
                        Write-Log "🔄 Agent signale: CONTINUE ($Reason)"
                        $Continue = $true
                    }
                    "escalate" {
                        Write-Log "🚀 Agent signale: ESCALATE ($Reason)"
                        $NeedsEscalation = $true
                        $Continue = $false

                        # Extraire modèle cible si spécifié
                        if ($OutputText -match "ESCALATE_TO:\s*(\w+)") {
                            $TargetModel = $Matches[1]
                            Write-Log "  → Modèle cible suggéré: $TargetModel"
                            # TODO: Utiliser ce modèle au lieu de celui de la config
                        }
                    }
                    "wait" {
                        Write-Log "⏸️ Agent signale: WAIT ($Reason)"
                        $Continue = $false

                        # Extraire condition d'attente
                        $WaitFor = if ($OutputText -match "WAIT_FOR:\s*(.+)") { $Matches[1].Trim() } else { "Condition non spécifiée" }
                        $ResumeWhen = if ($OutputText -match "RESUME_WHEN:\s*(.+)") { $Matches[1].Trim() } else { "Non spécifié" }

                        Write-Log "  → Attend: $WaitFor"
                        Write-Log "  → Reprendra: $ResumeWhen"

                        # Préparer état pour sauvegarde (sera sauvegardé par le workflow principal)
                        $WaitStateData = @{
                            reason = $Reason
                            waitFor = $WaitFor
                            resumeWhen = $ResumeWhen
                            mode = $ModeId
                            model = $ModelToUse
                            iteration = $CurrentIteration
                            context = ($CumulativeOutput | Select-Object -Last 50) -join "`n"  # Dernières 50 lignes
                        }
                    }
                    "success" {
                        Write-Log "✅ Agent signale: SUCCESS ($Reason)"
                        $Continue = $false
                    }
                    "failure" {
                        Write-Log "❌ Agent signale: FAILURE ($Reason)"
                        $Continue = $false
                    }
                    default {
                        Write-Log "⚠️ Signal inconnu: $Status" "WARN"
                        $Continue = $CurrentIteration -lt $Iterations
                    }
                }
            }
            else {
                # Pas de signal explicite détecté
                # Par défaut: continuer si pas max iterations, sinon arrêter
                $Continue = $CurrentIteration -lt $Iterations
                if (-not $Continue) {
                    Write-Log "⏸️ Max iterations atteintes - Arrêt" "WARN"
                }
            }
        }

        Pop-Location

        Write-Log "Ralph Wiggum terminé - $CurrentIteration iterations utilisées"

        # GATHER CONTEXT: Retourner résultat avec flag escalade ou wait state si nécessaire
        return @{
            success = -not $NeedsEscalation -and $null -eq $WaitStateData
            needsEscalation = $NeedsEscalation
            waitState = $WaitStateData
            output = $CumulativeOutput -join "`n`n=== Iteration Break ===`n`n"
            mode = $ModeId
            iterations = $CurrentIteration
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

    # TODO #3 - Ralph Wiggum: Vérifier flag needsEscalation (détecté par boucle)
    if ($Result.needsEscalation) {
        Write-Log "🚀 Escalade demandée par Ralph Wiggum vers: $($ModeConfig.escalation.triggerMode)" "WARN"
        return $ModeConfig.escalation.triggerMode
    }

    # Vérifier conditions d'escalade (échec)
    if (-not $Result.success) {
        Write-Log "❌ Échec détecté, escalade vers: $($ModeConfig.escalation.triggerMode)" "WARN"
        return $ModeConfig.escalation.triggerMode
    }

    # TODO #4 - Agent Signaling Protocol: Implémenté (2026-02-12)
    # L'agent signale explicitement son état via format structuré (voir ESCALATION_MECHANISM.md)
    # Protocole de signaux remplace le pattern matching prescriptif
    # Format: === AGENT STATUS === / STATUS: <continue|escalate|wait|success|failure> / REASON: ... / ===

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

    # 1b. Vérifier si tâche en attente peut reprendre (TODO #5)
    $ResumeState = Test-WaitStateReady -TaskId $Task.id
    if ($ResumeState) {
        Write-Log "🔄 Reprise d'une tâche en attente: $($Task.id)" "INFO"
        Write-Log "  → Mode restauré: $($ResumeState.context.mode)"
        Write-Log "  → Iteration: $($ResumeState.context.iteration)"

        # TODO: Implémenter logique de reprise avec contexte
        # Pour l'instant, traiter comme nouvelle tâche
        Write-Log "⚠️ Reprise automatique pas encore implémentée - traitement comme nouvelle tâche" "WARN"
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

    # 4b. Vérifier wait state (TODO #5)
    if ($Result.waitState) {
        Write-Log "⏸️ Agent en attente - Sauvegarde état pour reprise ultérieure" "INFO"
        Save-WaitState -TaskId $Task.id -WaitState $Result.waitState

        # Fin anticipée - pas d'escalade ni de completion
        Write-Log "=== WORKER EN ATTENTE ==="
        return
    }

    # 5. Vérifier escalade
    $EscalateMode = Check-Escalation -Result $Result -CurrentMode $SelectedMode

    if ($EscalateMode) {
        Write-Log "ESCALADE vers mode: $EscalateMode" "WARN"
        $Result = Invoke-Claude -ModeId $EscalateMode -Prompt $Task.prompt -WorkingDir $WorktreePath -MaxIter $MaxIterations
        $SelectedMode = $EscalateMode

        # 5b. Vérifier wait state après escalade (TODO #5)
        if ($Result.waitState) {
            Write-Log "⏸️ Agent escaladé en attente - Sauvegarde état" "INFO"
            Save-WaitState -TaskId $Task.id -WaitState $Result.waitState

            # Fin anticipée
            Write-Log "=== WORKER EN ATTENTE (après escalade) ==="
            return
        }
    }

    # 6. Reporter résultats
    Report-Results -Task $Task -Result $Result -FinalMode $SelectedMode

    # 7. Marquer tâche comme complétée (RooSync, GitHub, ou rien si fallback)
    Mark-TaskAsComplete -Task $Task

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
