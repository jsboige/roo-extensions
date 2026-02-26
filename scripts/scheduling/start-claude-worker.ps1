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
    [string]$Prompt,
    [switch]$DryRun = $false,
    [switch]$NoFallback = $false
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

# Propager NoFallback en scope script pour accès depuis Get-NextTask
$script:NoFallbackMode = $NoFallback

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
        [string]$AgentType = "claude",
        [switch]$SkipClaim = $false
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
        # Claim l'issue immédiatement (sauf en DryRun)
        if (-not $SkipClaim) {
            Claim-GitHubIssue -IssueNumber $GitHubTask.issueNumber -AgentType $AgentType -MachineId $MachineId
        } else {
            Write-Log "[DRY-RUN] Skip claim issue #$($GitHubTask.issueNumber)" "INFO"
        }
        return $GitHubTask
    }

    # --- PRIORITÉ 3 : Fallback maintenance (sauf si -NoFallback) ---
    if ($script:NoFallbackMode) {
        Write-Log "Aucune tâche RooSync/GitHub → Mode NoFallback activé, pas de maintenance"
        return $null
    }
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

    # Filtrer par machine + unread + skip non-task messages
    # BUG FIXES (Cycle 34):
    # 1. Skip ALL messages from self (not just broadcasts) - prevents self-consumption loop
    #    on coordinator where worker picks up own reports
    # 2. Skip worker-report tagged messages (results, not tasks)
    # 3. Skip completion/info reports ([DONE], [INFO], Worker Report) - not actionable
    $MyMessages = $Messages | Where-Object {
        ($_.to -eq $MachineId -or $_.to -eq "all") -and
        $_.status -eq "unread" -and
        # Skip ALL messages from self (prevents self-consumption on coordinator)
        -not ($_.from -like "$MachineId*") -and
        # Skip worker reports (these are results, not tasks)
        -not ($_.tags -contains "worker-report") -and
        # Skip completion/info reports (not actionable tasks)
        -not ($_.subject -match "^\[DONE\]|^\[INFO\]|^Worker Report")
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

            # Vérifier champ Agent dans le body (optionnel - le label roo-schedulable suffit)
            # Si le body contient explicitement "Agent: Roo" (sans Both/Any), skip pour Claude
            $Body = $Issue.body
            if ($AgentType -eq "claude" -and ($Body -match "(?i)agent:\s*roo\s*$")) {
                Write-Log "  Issue #$($Issue.number) : Agent=Roo uniquement, skip" "DEBUG"
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

        # Vérifier condition resumeWhen
        $ResumeCondition = $State.resumeWhen.ToLower() -replace '[_\s]+', '_'

        switch -Regex ($ResumeCondition) {
            "user_approval|user approval" {
                Write-Log "  Vérification user approval (INTERCOM + GitHub)..."
                if (Test-UserApproval -TaskId $TaskId -WaitState $State) {
                    Write-Log "✅ User approval détectée - reprise autorisée"
                    return $State
                }
            }
            "roosync_response|roosync response" {
                Write-Log "  Vérification RooSync response (inbox)..."
                if (Test-RooSyncResponse -TaskId $TaskId -WaitState $State) {
                    Write-Log "✅ RooSync response détectée - reprise autorisée"
                    return $State
                }
            }
            "github_decision|github decision|github_status|github status" {
                Write-Log "  Vérification GitHub decision (issue status)..."
                if (Test-GitHubDecision -TaskId $TaskId -WaitState $State) {
                    Write-Log "✅ GitHub decision détectée - reprise autorisée"
                    return $State
                }
            }
            "intercom_message|intercom message" {
                Write-Log "  Vérification INTERCOM message..."
                if (Test-IntercomMessage -TaskId $TaskId -WaitState $State) {
                    Write-Log "✅ INTERCOM message détecté - reprise autorisée"
                    return $State
                }
            }
            default {
                Write-Log "⚠️ Condition resumeWhen inconnue: $($State.resumeWhen)" "WARN"
            }
        }

        Write-Log "⏸️ Condition pas encore remplie - skip pour cette exécution"
        return $null
    }
    catch {
        Write-Log "Erreur lecture wait state: $_" "WARN"
        return $null
    }
}

function Test-UserApproval {
    <#
    .SYNOPSIS
    Vérifie si user approval détectée (INTERCOM + GitHub comments)
    #>
    param([string]$TaskId, $WaitState)

    $MachineId = $env:COMPUTERNAME.ToLower()
    $IntercomPath = Join-Path $RepoRoot ".claude\local\INTERCOM-$MachineId.md"

    if (-not (Test-Path $IntercomPath)) { return $false }

    try {
        $Content = Get-Content $IntercomPath -Raw
        $SavedTimestamp = [DateTime]::Parse($WaitState.timestamp)

        # Chercher messages INTERCOM après le timestamp
        $ApprovalPatterns = @(
            '\[APPROVE\]', '\[APPROVED\]', '\[OK\]', '\[GO\]',
            'approved', 'go ahead', 'proceed', 'continue'
        )

        foreach ($Pattern in $ApprovalPatterns) {
            if ($Content -match "(?m)^## \[([^\]]+)\].*$Pattern") {
                $MessageTimestamp = [DateTime]::Parse($Matches[1])
                if ($MessageTimestamp -gt $SavedTimestamp) {
                    return $true
                }
            }
        }

        return $false
    }
    catch {
        Write-Log "Erreur Test-UserApproval: $_" "WARN"
        return $false
    }
}

function Test-RooSyncResponse {
    <#
    .SYNOPSIS
    Vérifie si réponse RooSync détectée dans inbox
    #>
    param([string]$TaskId, $WaitState)

    $SharedPath = $env:ROOSYNC_SHARED_PATH
    if (-not $SharedPath) { return $false }

    $InboxPath = Join-Path $SharedPath "messages\inbox"
    if (-not (Test-Path $InboxPath)) { return $false }

    try {
        $SavedTimestamp = [DateTime]::Parse($WaitState.timestamp)
        $MachineId = $env:COMPUTERNAME.ToLower()

        # Lire messages inbox pour cette machine
        $Messages = Get-ChildItem $InboxPath -Filter "*.json" | ForEach-Object {
            try { Get-Content $_.FullName -Raw | ConvertFrom-Json } catch { $null }
        } | Where-Object { $_ -ne $null }

        # Chercher réponses après le timestamp
        foreach ($Message in $Messages) {
            if (($Message.to -eq $MachineId -or $Message.to -eq "all") -and
                $Message.status -eq "unread") {
                $MessageTimestamp = [DateTime]::Parse($Message.timestamp)
                if ($MessageTimestamp -gt $SavedTimestamp) {
                    # Vérifier si le message concerne cette tâche
                    if ($Message.subject -match $TaskId -or $Message.body -match $TaskId) {
                        return $true
                    }
                }
            }
        }

        return $false
    }
    catch {
        Write-Log "Erreur Test-RooSyncResponse: $_" "WARN"
        return $false
    }
}

function Test-GitHubDecision {
    <#
    .SYNOPSIS
    Vérifie si décision GitHub détectée (issue status change)
    #>
    param([string]$TaskId, $WaitState)

    # Extraire issue number du TaskId ou du waitFor
    $IssueNumber = $null
    if ($TaskId -match '#(\d+)') { $IssueNumber = $Matches[1] }
    elseif ($WaitState.waitFor -match '#(\d+)') { $IssueNumber = $Matches[1] }

    if (-not $IssueNumber) {
        Write-Log "  Pas d'issue number trouvée dans TaskId ou waitFor"
        return $false
    }

    try {
        # Vérifier si gh CLI disponible
        $GhPath = Get-Command gh -ErrorAction SilentlyContinue
        if (-not $GhPath) {
            Write-Log "  gh CLI non disponible" "WARN"
            return $false
        }

        # Récupérer l'état de l'issue
        $IssueJson = & gh issue view $IssueNumber --repo jsboige/roo-extensions --json state,comments 2>&1

        if ($LASTEXITCODE -ne 0) {
            Write-Log "  Erreur gh issue view: $IssueJson" "WARN"
            return $false
        }

        $Issue = $IssueJson | ConvertFrom-Json
        $SavedTimestamp = [DateTime]::Parse($WaitState.timestamp)

        # Vérifier si issue fermée après le timestamp
        if ($Issue.state -eq "CLOSED") {
            Write-Log "  Issue #$IssueNumber est fermée - reprise autorisée"
            return $true
        }

        # Vérifier commentaires récents avec approval
        $ApprovalPatterns = @('approve', 'go ahead', 'proceed', 'continue', 'done')
        foreach ($Comment in $Issue.comments) {
            $CommentTimestamp = [DateTime]::Parse($Comment.createdAt)
            if ($CommentTimestamp -gt $SavedTimestamp) {
                foreach ($Pattern in $ApprovalPatterns) {
                    if ($Comment.body -match $Pattern) {
                        Write-Log "  Commentaire approval détecté: $($Comment.body.Substring(0, [Math]::Min(50, $Comment.body.Length)))"
                        return $true
                    }
                }
            }
        }

        return $false
    }
    catch {
        Write-Log "Erreur Test-GitHubDecision: $_" "WARN"
        return $false
    }
}

function Test-IntercomMessage {
    <#
    .SYNOPSIS
    Vérifie si message INTERCOM détecté
    #>
    param([string]$TaskId, $WaitState)

    $MachineId = $env:COMPUTERNAME.ToLower()
    $IntercomPath = Join-Path $RepoRoot ".claude\local\INTERCOM-$MachineId.md"

    if (-not (Test-Path $IntercomPath)) { return $false }

    try {
        $Content = Get-Content $IntercomPath -Raw
        $SavedTimestamp = [DateTime]::Parse($WaitState.timestamp)

        # Chercher messages INTERCOM après le timestamp
        $Pattern = '(?m)^## \[([^\]]+)\].*\[(TASK|INFO|DONE|URGENT)\]'
        $Matches = [regex]::Matches($Content, $Pattern)

        foreach ($Match in $Matches) {
            $MessageTimestamp = [DateTime]::Parse($Match.Groups[1].Value)
            if ($MessageTimestamp -gt $SavedTimestamp) {
                return $true
            }
        }

        return $false
    }
    catch {
        Write-Log "Erreur Test-IntercomMessage: $_" "WARN"
        return $false
    }
}

# =============================================================================
# Phase 2 - Wait State Resume Logic (#461)
# =============================================================================

function Get-PendingWaitStates {
    <#
    .SYNOPSIS
    Scanne les wait states en attente et retourne ceux qui sont prêts à reprendre.

    .DESCRIPTION
    Parcourt le répertoire wait-states/, vérifie chaque fichier JSON,
    et teste la condition resumeWhen. Retourne le premier prêt (par ancienneté).

    .OUTPUTS
    Hashtable avec { taskId, state } si un wait state est prêt, $null sinon.
    #>
    $WaitStatesDir = Join-Path $RepoRoot ".claude\scheduler\wait-states"

    if (-not (Test-Path $WaitStatesDir)) { return $null }

    $WaitFiles = Get-ChildItem $WaitStatesDir -Filter "*.json" -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime  # Plus ancien en premier

    if ($WaitFiles.Count -eq 0) { return $null }

    Write-Log "Vérification de $($WaitFiles.Count) wait state(s) en attente..."

    foreach ($File in $WaitFiles) {
        $TaskId = $File.BaseName
        $State = Test-WaitStateReady -TaskId $TaskId

        if ($State) {
            Write-Log "✅ Wait state prêt: $TaskId (condition: $($State.resumeWhen))"
            return @{
                taskId = $TaskId
                state = $State
            }
        }
    }

    Write-Log "Aucun wait state prêt à reprendre"
    return $null
}

function Remove-WaitState {
    <#
    .SYNOPSIS
    Supprime le fichier wait state après reprise réussie.
    #>
    param([string]$TaskId)

    $StateFile = Join-Path $RepoRoot ".claude\scheduler\wait-states\$TaskId.json"

    if (Test-Path $StateFile) {
        try {
            Remove-Item $StateFile -Force
            Write-Log "🗑️ Wait state nettoyé: $TaskId"
        }
        catch {
            Write-Log "Erreur suppression wait state: $_" "WARN"
        }
    }
}

function Build-ResumePrompt {
    <#
    .SYNOPSIS
    Construit un prompt enrichi pour reprendre une tâche en attente.

    .DESCRIPTION
    Inclut le contexte précédent, la raison de l'attente,
    et les informations disponibles pour la reprise.

    .OUTPUTS
    String prompt enrichi pour Claude
    #>
    param(
        $WaitState,
        [string]$OriginalPrompt = ""
    )

    $ResumePrompt = @"
=== REPRISE DE TÂCHE EN ATTENTE ===

Cette tâche a été mise en pause précédemment et reprend maintenant.

**Raison de la pause :** $($WaitState.reason)
**En attente de :** $($WaitState.waitFor)
**Condition remplie :** $($WaitState.resumeWhen)
**Iteration précédente :** $($WaitState.context.iteration)
**Mode précédent :** $($WaitState.context.mode)
**Modèle précédent :** $($WaitState.context.model)

**Contexte de l'exécution précédente (dernières lignes) :**
```
$($WaitState.context.outputSnippet)
```

=== INSTRUCTIONS ===
La condition d'attente est maintenant remplie. Reprends la tâche là où elle a été interrompue.
$(if ($OriginalPrompt) { "Tâche originale : $OriginalPrompt" })

Continue l'exécution en tenant compte du contexte ci-dessus.
"@

    return $ResumePrompt
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
    # BUG FIX: Ne pas ajouter de guillemets supplémentaires autour du prompt.
    # PowerShell splatting gère le quoting automatiquement.
    # Les guillemets manuels causaient des erreurs quand le prompt contenait des
    # fragments ressemblant à des options CLI (ex: --body dans un texte).
    $ClaudeArgs = @(
        "--dangerously-skip-permissions",
        "--model", $ModelToUse,
        "-p", $Prompt
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
        $IterationOutputs = @()  # Array of iteration output STRINGS (not individual lines)
        $NeedsEscalation = $false
        $EscalateToModel = $null  # Modèle suggéré par l'agent
        $WaitStateData = $null

        while ($Continue -and $CurrentIteration -lt $Iterations) {
            $CurrentIteration++
            Write-Log "Ralph Wiggum - Iteration $CurrentIteration/$Iterations..."

            # TAKE ACTION: Exécuter Claude CLI
            try {
                $IterationOutput = & claude @ClaudeArgs 2>&1
                # BUG FIX: Join lines into a single string per iteration,
                # so "=== Iteration Break ===" only appears BETWEEN iterations, not between lines
                $IterationOutputs += ($IterationOutput -join "`n")
            }
            catch {
                Write-Log "Erreur exécution Claude (iteration $CurrentIteration): $_" "ERROR"
                $IterationOutputs += "ERROR: $_"
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
            $OutputText = $IterationOutputs[-1]  # Last iteration's joined output

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
                            $EscalateToModel = $Matches[1]
                            Write-Log "  → Modèle cible suggéré: $EscalateToModel"
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
                            context = ($IterationOutputs[-1].Split("`n") | Select-Object -Last 50) -join "`n"  # Dernières 50 lignes
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
            escalateToModel = $EscalateToModel
            waitState = $WaitStateData
            output = $IterationOutputs -join "`n`n=== Iteration Break ===`n`n"
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

    # Truncate output to last 80 lines to keep reports readable
    $OutputLines = $Result.output -split "`n"
    $TruncatedOutput = if ($OutputLines.Count -gt 80) {
        $Skipped = $OutputLines.Count - 80
        "... ($Skipped lines truncated)`n" + ($OutputLines | Select-Object -Last 80) -join "`n"
    } else {
        $Result.output
    }

    $ReportMessage = @"
## Worker Report - $($env:COMPUTERNAME)

**Tâche:** $($Task.id) - $($Task.subject)
**Mode utilisé:** $FinalMode
**Statut:** $(if ($Result.success) { "✅ SUCCÈS" } else { "❌ ÉCHEC" })
**Itérations:** $($Result.iterations)

### Output
``````
$TruncatedOutput
``````

### Logs
Voir: $LogFile
"@

    Write-Log $ReportMessage

    # Envoyer message RooSync au coordinateur
    $SharedPath = $env:ROOSYNC_SHARED_PATH
    if (-not $SharedPath) {
        Write-Log "ROOSYNC_SHARED_PATH non défini - skip envoi RooSync" "WARN"
        return
    }

    try {
        $MachineId = $env:COMPUTERNAME.ToLower()
        $Timestamp = Get-Date -Format "yyyyMMddTHHmmss"
        $MessageId = "msg-$Timestamp-worker-report"

        $Message = @{
            id = $MessageId
            from = $MachineId
            to = "myia-ai-01"
            subject = "Worker Report - $($Task.subject)"
            body = $ReportMessage
            priority = if ($Result.success) { "LOW" } else { "HIGH" }
            status = "unread"
            timestamp = (Get-Date).ToUniversalTime().ToString("o")
            tags = @("worker-report", "scheduler")
        }

        $SentPath = Join-Path $SharedPath "messages\sent"
        $InboxPath = Join-Path $SharedPath "messages\inbox"

        # Créer répertoires si nécessaires
        if (-not (Test-Path $SentPath)) { New-Item -ItemType Directory -Path $SentPath -Force | Out-Null }
        if (-not (Test-Path $InboxPath)) { New-Item -ItemType Directory -Path $InboxPath -Force | Out-Null }

        # Sauvegarder en UTF-8 sans BOM
        $JsonText = $Message | ConvertTo-Json -Depth 10
        $SentFile = Join-Path $SentPath "$MessageId.json"
        $InboxFile = Join-Path $InboxPath "$MessageId.json"

        [System.IO.File]::WriteAllText($SentFile, $JsonText, [System.Text.UTF8Encoding]::new($false))
        [System.IO.File]::WriteAllText($InboxFile, $JsonText, [System.Text.UTF8Encoding]::new($false))

        Write-Log "✅ Message RooSync envoyé: $MessageId"
    }
    catch {
        Write-Log "Erreur envoi RooSync: $_" "ERROR"
    }
}

# ============================================================================
# MAIN WORKFLOW
# ============================================================================

Write-Log "=== DÉMARRAGE CLAUDE WORKER ==="
Write-Log "Machine: $env:COMPUTERNAME"
Write-Log "RepoRoot: $RepoRoot"
Write-Log "DryRun: $DryRun"

try {
    # ==========================================================================
    # Phase 0 : Vérifier wait states en attente (PRIORITÉ MAXIMALE)
    # Un wait state prêt reprend avant toute nouvelle tâche.
    # ==========================================================================

    $IsResume = $false
    $ResumeState = $null

    $PendingResume = Get-PendingWaitStates
    if ($PendingResume -and -not $TaskId) {
        # Wait state trouvé et aucun TaskId forcé → reprendre la tâche en attente
        $ResumeState = $PendingResume.state
        $IsResume = $true

        Write-Log "🔄 REPRISE d'une tâche en attente (priorité sur nouvelles tâches)"
        Write-Log "  → TaskId: $($PendingResume.taskId)"
        Write-Log "  → Condition remplie: $($ResumeState.resumeWhen)"
        Write-Log "  → Mode sauvegardé: $($ResumeState.context.mode)"
        Write-Log "  → Modèle sauvegardé: $($ResumeState.context.model)"

        # Construire tâche de reprise
        $Task = @{
            id = $PendingResume.taskId
            subject = "REPRISE: $($ResumeState.waitFor)"
            prompt = Build-ResumePrompt -WaitState $ResumeState
            source = "wait-state-resume"
            suggestedMode = $ResumeState.context.mode
        }
    }

    # ==========================================================================
    # Phase 1 : Récupérer tâche (si pas de reprise)
    # ==========================================================================

    if (-not $IsResume) {
        if ($TaskId) {
            Write-Log "TaskId spécifié: $TaskId"

            # Récupérer tâche depuis RooSync inbox
            $SharedPath = $env:ROOSYNC_SHARED_PATH
            if ($SharedPath) {
                $InboxPath = Join-Path $SharedPath "messages\inbox"
                $MessageFile = Join-Path $InboxPath "$TaskId.json"

                if (Test-Path $MessageFile) {
                    try {
                        $Message = Get-Content $MessageFile -Raw | ConvertFrom-Json
                        $Task = @{
                            id = $Message.id
                            subject = $Message.subject
                            priority = $Message.priority
                            prompt = $Message.body
                            source = "roosync"
                            messageFile = $MessageFile
                            suggestedMode = $Mode
                        }
                        Write-Log "✅ Tâche RooSync récupérée: $($Task.id)"
                    }
                    catch {
                        Write-Log "Erreur lecture tâche $TaskId : $_" "ERROR"
                        $Task = @{ id = $TaskId; subject = "Tâche spécifiée (erreur lecture)"; prompt = $Prompt; suggestedMode = $Mode }
                    }
                }
                else {
                    Write-Log "Tâche $TaskId introuvable dans inbox" "WARN"
                    $Task = @{ id = $TaskId; subject = "Tâche spécifiée (introuvable)"; prompt = $Prompt; suggestedMode = $Mode }
                }
            }
            else {
                Write-Log "ROOSYNC_SHARED_PATH non défini" "WARN"
                $Task = @{ id = $TaskId; subject = "Tâche spécifiée"; prompt = $Prompt; suggestedMode = $Mode }
            }

            # Vérifier si CETTE tâche spécifique a un wait state prêt
            $ResumeState = Test-WaitStateReady -TaskId $Task.id
            if ($ResumeState) {
                Write-Log "🔄 Reprise de tâche spécifiée $TaskId avec contexte sauvegardé" "INFO"
                Write-Log "  → Mode restauré: $($ResumeState.context.mode)"
                Write-Log "  → Iteration: $($ResumeState.context.iteration)"
                $IsResume = $true

                # Enrichir le prompt avec le contexte de reprise
                $Task.prompt = Build-ResumePrompt -WaitState $ResumeState -OriginalPrompt $Task.prompt
                $Task.suggestedMode = $ResumeState.context.mode
            }
        } else {
            $Task = Get-NextTask -SkipClaim:$DryRun
        }
    }

    # ==========================================================================
    # Phase 1b : Vérifier si tâche trouvée (graceful idle si -NoFallback)
    # ==========================================================================

    if (-not $Task) {
        Write-Log "Aucune tâche disponible et aucun wait state prêt"
        Write-Log "=== WORKER IDLE - Sortie propre ==="
        exit 0
    }

    # ==========================================================================
    # Phase 2 : Déterminer mode (restauré si reprise, sinon auto-détecté)
    # ==========================================================================

    $SelectedMode = if ($IsResume -and $ResumeState.context.mode) {
        Write-Log "Mode restauré depuis wait state: $($ResumeState.context.mode)"

        # Restaurer aussi le modèle si sauvegardé
        if ($ResumeState.context.model -and -not $Model) {
            $Model = $ResumeState.context.model
            Write-Log "Modèle restauré depuis wait state: $Model"
        }

        $ResumeState.context.mode
    } else {
        Determine-Mode -Task $Task
    }

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

    # DryRun: stop after showing the command (Invoke-Claude already logged it)
    if ($DryRun) {
        Write-Log "[DRY-RUN] Skip report, RooSync send, GitHub comment"
        Write-Log "=== WORKER TERMINÉ (DRY-RUN) ==="
        exit 0
    }

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

        # Déterminer le modèle pour l'escalade (priorité: agent > mode config > original)
        $OriginalModel = $Model
        if ($Result.escalateToModel) {
            $Model = $Result.escalateToModel
            Write-Log "  → Utilisation modèle suggéré par agent: $Model"
        } else {
            # BUG FIX: Utiliser le modèle configuré pour le mode escaladé
            # Sans ça, -Model haiku restait actif même après escalade vers sync-complex (sonnet)
            $EscModeConfig = Get-ModeConfig -ModeId $EscalateMode
            if ($EscModeConfig -and $EscModeConfig.model) {
                $Model = $EscModeConfig.model
                Write-Log "  → Utilisation modèle du mode escaladé ($EscalateMode): $Model"
            }
        }

        $Result = Invoke-Claude -ModeId $EscalateMode -Prompt $Task.prompt -WorkingDir $WorktreePath -MaxIter $MaxIterations
        $SelectedMode = $EscalateMode

        # Restaurer le modèle original
        $Model = $OriginalModel

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

    # 6b. Nettoyer wait state si c'était une reprise réussie
    if ($IsResume -and $Result.success) {
        Write-Log "🗑️ Nettoyage wait state après reprise réussie"
        Remove-WaitState -TaskId $Task.id
    }

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
