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
    [bool]$UseWorktree = $true,
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
# Worker defaults (decoupled from Roo modes-config.json since 2026-03-06)
# Model/iterations come from Project #67 fields. Escalation uses Agent Status protocol
# (haiku -> sonnet -> opus), NOT Roo mode hierarchy (simple -> complex).
$WorkerDefaultIterations = 5
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

function Test-ClaudeCLI {
    try {
        $Version = & claude --version 2>&1
        Write-Log "Claude CLI: $Version"
        return $true
    } catch {
        Write-Log "Claude CLI non disponible: $_" "ERROR"
        return $false
    }
}

function Get-EscalatedModel {
    param([string]$CurrentModel)
    # Claude worker escalation: haiku -> sonnet -> opus (model-based, not Roo mode-based)
    switch ($CurrentModel) {
        "haiku"  { return "sonnet" }
        "sonnet" { return "opus" }
        "opus"   { return $null }  # Already at max
        default  { return "sonnet" }
    }
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

    # Filtrer par machine + unread + WHITELIST subjects actionnables
    # BUG FIXES:
    # - Cycle 34: Skip self messages, worker-reports, [DONE]/[INFO]
    # - Cycle 36: Switch to WHITELIST approach - only accept [TASK] and [URGENT]
    #   messages as real work. [STATUS], [READY], [DONE], [INFO], Worker Report
    #   are all non-actionable and were causing stale message re-processing.
    $MyMessages = $Messages | Where-Object {
        ($_.to -eq $MachineId -or $_.to -eq "all") -and
        $_.status -eq "unread" -and
        # Skip ALL messages from self (prevents self-consumption on coordinator)
        -not ($_.from -like "$MachineId*") -and
        # Skip worker reports (these are results, not tasks)
        -not ($_.tags -contains "worker-report") -and
        # WHITELIST: Only accept actionable message types
        ($_.subject -match "^\[TASK\]|^\[URGENT\]")
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

function Test-IssueAlreadyProcessed {
    <#
    .SYNOPSIS
    Checks if a GitHub issue was already processed recently by the Claude Worker.
    Prevents re-processing the same issue every 3h tick.
    #>
    param([int]$IssueNumber)

    try {
        $CommentsJson = & gh issue view $IssueNumber --repo jsboige/roo-extensions `
            --json comments --jq '.comments[-5:]' 2>&1

        if ($LASTEXITCODE -ne 0) { return $false }

        $Comments = $CommentsJson | ConvertFrom-Json

        foreach ($Comment in $Comments) {
            $CreatedAt = [DateTime]::Parse($Comment.createdAt)
            $Age = (Get-Date).ToUniversalTime() - $CreatedAt.ToUniversalTime()

            # Skip if claimed by claude worker in the last 6 hours
            if ($Comment.body -match "Claimed by claude" -and $Age.TotalHours -lt 6) {
                Write-Log "  Issue #$IssueNumber : deja traitee il y a $([Math]::Round($Age.TotalHours, 1))h, skip" "INFO"
                return $true
            }

            # Skip if issue has a BLOCKED/Awaiting marker in last 24h
            if ($Comment.body -match "(?i)(BLOCKED|Awaiting|STATUS: wait)" -and $Age.TotalHours -lt 24) {
                Write-Log "  Issue #$IssueNumber : bloquee (marker dans commentaire < 24h), skip" "INFO"
                return $true
            }
        }

        return $false
    } catch {
        Write-Log "Erreur Test-IssueAlreadyProcessed #$IssueNumber : $_" "WARN"
        return $false
    }
}

function Get-IssueProjectFields {
    <#
    .SYNOPSIS
    Reads Project #67 fields for a specific issue via GraphQL.
    Returns Model, Execution, Deadline, Machine, Agent, Status.
    #>
    param([int]$IssueNumber)

    try {
        $Query = @"
{
  repository(owner: "jsboige", name: "roo-extensions") {
    issue(number: $IssueNumber) {
      projectItems(first: 5) {
        nodes {
          fieldValues(first: 15) {
            nodes {
              ... on ProjectV2ItemFieldSingleSelectValue {
                name
                field { ... on ProjectV2SingleSelectField { name } }
              }
              ... on ProjectV2ItemFieldDateValue {
                date
                field { ... on ProjectV2Field { name } }
              }
            }
          }
        }
      }
    }
  }
}
"@

        # Use temp JSON file to pass multiline query (avoids PowerShell argument splitting)
        $RequestBody = @{ query = $Query } | ConvertTo-Json -Depth 2
        $TempFile = Join-Path $env:TEMP "gql-project-fields-$IssueNumber.json"
        [System.IO.File]::WriteAllText($TempFile, $RequestBody, [System.Text.UTF8Encoding]::new($false))
        $ResultJson = & gh api graphql --input $TempFile 2>&1
        Remove-Item $TempFile -ErrorAction SilentlyContinue
        if ($LASTEXITCODE -ne 0) {
            Write-Log "  GraphQL error for #$IssueNumber : $ResultJson" "WARN"
            return @{}
        }

        $Result = $ResultJson | ConvertFrom-Json
        $Fields = @{}

        # Parse project item field values
        $ProjectItems = $Result.data.repository.issue.projectItems.nodes
        if ($ProjectItems -and $ProjectItems.Count -gt 0) {
            foreach ($Item in $ProjectItems) {
                foreach ($FieldValue in $Item.fieldValues.nodes) {
                    if ($FieldValue.field -and $FieldValue.field.name) {
                        $FieldName = $FieldValue.field.name
                        if ($FieldValue.name) {
                            # SingleSelect field
                            $Fields[$FieldName] = $FieldValue.name
                        }
                        elseif ($FieldValue.date) {
                            # Date field
                            $Fields[$FieldName] = $FieldValue.date
                        }
                    }
                }
            }
        }

        if ($Fields.Count -gt 0) {
            Write-Log "  Project fields #$IssueNumber : $(($Fields.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join ', ')" "INFO"
        }

        return $Fields
    } catch {
        Write-Log "Erreur Get-IssueProjectFields #$IssueNumber : $_" "WARN"
        return @{}
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
        # Lister TOUTES les issues ouvertes (pas seulement roo-schedulable)
        # Le filtrage se fait en aval (labels, dispatch status, claim status, Agent field)
        $IssuesJson = & gh issue list --repo jsboige/roo-extensions `
            --state open `
            --limit 30 --json number,title,body,labels,assignees 2>&1

        if ($LASTEXITCODE -ne 0) { return $null }

        $Issues = $IssuesJson | ConvertFrom-Json
        if ($Issues.Count -eq 0) { return $null }

        # Filtrer par Agent, disponibilité, labels, et dispatch status
        foreach ($Issue in $Issues) {
            # Skip si déjà assignée
            if ($Issue.assignees.Count -gt 0) { continue }

            # Skip si label needs-approval (attente validation utilisateur)
            $LabelNames = @($Issue.labels | ForEach-Object { $_.name })
            if ($LabelNames -contains "needs-approval") {
                Write-Log "  Issue #$($Issue.number) : needs-approval, skip" "DEBUG"
                continue
            }

            # Vérifier dispatch status : priorité aux issues dispatchées à cette machine
            $IsDispatchedToMe = $false
            $IsDispatchedToOther = $false
            try {
                $DispatchJson = & gh issue view $Issue.number --repo jsboige/roo-extensions `
                    --json comments --jq '[.comments[-10:][] | .body | select(test("\\[DISPATCH\\]|\\[CLAIMED\\]|\\[RESULT\\]"))]' 2>&1
                if ($LASTEXITCODE -eq 0 -and $DispatchJson) {
                    $DispatchComments = $DispatchJson | ConvertFrom-Json
                    foreach ($Dc in $DispatchComments) {
                        # ANTI-DOUBLON: skip si résultat déjà posté
                        if ($Dc -match "\[RESULT\]") {
                            $IsDispatchedToOther = $true  # Already completed
                            break
                        }
                        if ($Dc -match "\[CLAIMED\]") {
                            $IsDispatchedToOther = $true  # Already claimed
                            break
                        }
                        if ($Dc -match "\[DISPATCH\]\s*$MachineId") {
                            $IsDispatchedToMe = $true
                        }
                        elseif ($Dc -match "\[DISPATCH\]\s*(All|Any)") {
                            $IsDispatchedToMe = $true  # Available to any
                        }
                        elseif ($Dc -match "\[DISPATCH\]") {
                            $IsDispatchedToOther = $true  # Dispatched to another machine
                        }
                    }
                }
            } catch {
                Write-Log "  Issue #$($Issue.number) : erreur check dispatch: $_" "WARN"
            }

            # Skip si claimed par une autre machine
            if ($IsDispatchedToOther -and -not $IsDispatchedToMe) {
                Write-Log "  Issue #$($Issue.number) : dispatchée/claimée ailleurs, skip" "DEBUG"
                continue
            }

            # Vérifier champ Agent dans le body (optionnel)
            # Si le body contient explicitement "Agent: Roo" (sans Both/Any), skip pour Claude
            $Body = $Issue.body
            if ($AgentType -eq "claude" -and ($Body -match "(?i)agent:\s*roo\s*$")) {
                Write-Log "  Issue #$($Issue.number) : Agent=Roo uniquement, skip" "DEBUG"
                continue
            }

            # Vérifier locks git
            if (Test-GitHubIssueLock -IssueNumber $Issue.number) { continue }

            # Skip si déjà traitée récemment (anti-repetition)
            if (Test-IssueAlreadyProcessed -IssueNumber $Issue.number) { continue }

            # Lire les champs Project #67 (Model, Execution, Deadline, etc.)
            $ProjectFields = Get-IssueProjectFields -IssueNumber $Issue.number

            # Skip si Execution = interactive (réservé aux sessions manuelles)
            if ($ProjectFields.Execution -eq "interactive") {
                Write-Log "  Issue #$($Issue.number) : Execution=interactive, skip pour worker" "INFO"
                continue
            }

            # Disponible !
            return @{
                id = "github-$($Issue.number)"
                subject = $Issue.title
                priority = "MEDIUM"
                prompt = Build-GitHubPrompt -IssueNumber $Issue.number -Title $Issue.title -Body $Body
                source = "github"
                issueNumber = $Issue.number
                projectFields = $ProjectFields
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
        # Phase 1 - Issue #1005: Check assignee field atomique (prioritaire)
        $IssueJson = & gh issue view $IssueNumber --repo jsboige/roo-extensions `
            --json assignees 2>&1

        if ($LASTEXITCODE -eq 0) {
            $IssueData = $IssueJson | ConvertFrom-Json
            # Si l'issue a un assignee, elle est verrouillee
            if ($IssueData.assignees.Count -gt 0) {
                return $true
            }
        }

        # Fallback Phase 2 - Check commentaires LOCK (compatibilite arriere)
        $CommentsJson = & gh issue view $IssueNumber --repo jsboige/roo-extensions `
            --json comments --jq '.comments[-3:]' 2>&1

        if ($LASTEXITCODE -ne 0) { return $false }

        $Comments = $CommentsJson | ConvertFrom-Json

        foreach ($Comment in $Comments) {
            $Body = $Comment.body
            $CreatedAt = [DateTime]::Parse($Comment.createdAt)
            $Age = (Get-Date).ToUniversalTime() - $CreatedAt.ToUniversalTime()

            # LOCK actif si < 5 minutes (seulement pour compatibilite)
            if (($Body -match "LOCK:") -and $Age.TotalMinutes -lt 5) {
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
        # Phase 1: Utiliser GitHub assignee comme verrou atomique (Issue #1005)
        # Le champ assignee est atomique et evite la race condition TOCTOU

        # 1. Claim par assignee (operation atomique)
        & gh issue edit $IssueNumber --repo jsboige/roo-extensions --add-assignee jsboige 2>&1 | Out-Null

        # 2. Verifier que l'assignee est bien nous (apres 5s pour propagation)
        Start-Sleep -Seconds 5
        $IssueJson = & gh issue view $IssueNumber --repo jsboige/roo-extensions --json assignees 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Log "⚠️ Erreur lecture assignee #$IssueNumber" "WARN"
            return $false
        }

        $IssueData = $IssueJson | ConvertFrom-Json
        $HasAssignee = $IssueData.assignees.Count -gt 0

        if (-not $HasAssignee) {
            # Rollback: quelqu'un d'autre a retire l'assignee (race condition perdue)
            Write-Log "⚠️ Issue #$IssueNumber : assignee retire (race condition perdue)" "WARN"
            return $false
        }

        # 3. Ajouter le commentaire de traçabilité [CLAIMED]
        $Timestamp = Get-Date -Format "o"
        $Body = "[CLAIMED] by $AgentType on $MachineId at $Timestamp"
        & gh issue comment $IssueNumber --repo jsboige/roo-extensions --body $Body 2>&1 | Out-Null

        Write-Log "✅ Issue #$IssueNumber claimed (assignee + commentaire)"
        return $true
    } catch {
        Write-Log "⚠️ Erreur claim #$IssueNumber : $_" "WARN"
        return $false
    }
}

function Build-GitHubPrompt {
    <#
    .SYNOPSIS
    Constructs an actionable prompt from a GitHub issue for autonomous Claude execution.

    .DESCRIPTION
    Extracts the Execution-Ready Spec section if present, and wraps the issue content
    with autonomous agent instructions so Claude acts without asking for clarification.
    #>
    param(
        [int]$IssueNumber,
        [string]$Title,
        [string]$Body
    )

    $MachineId = $env:COMPUTERNAME.ToLower()

    # Try to extract Execution-Ready Spec section
    $Spec = $null
    if ($Body -match '(?si)## Execution-Ready Spec.*?\n(.*?)(?=\n## |\z)') {
        $Spec = $Matches[1].Trim()
    }

    # Build the prompt
    $PromptParts = @()
    $PromptParts += "You are an autonomous Claude Code agent on machine $MachineId."
    $PromptParts += "Execute the following GitHub issue autonomously. Do NOT ask for clarification - make reasonable decisions and proceed."
    $PromptParts += ""
    $PromptParts += "## RooSync Dashboard Protocol"
    $PromptParts += "BEFORE starting work, read the workspace dashboard: roosync_dashboard(action: `"read`", type: `"workspace`", section: `"intercom`", intercomLimit: 10)"
    $PromptParts += "Check for recent messages with tags: [DONE], [WAKE-CLAUDE], [PATROL], [FRICTION-FOUND], [ERROR], [ASK]."
    $PromptParts += "If [WAKE-CLAUDE] found: prioritize the indicated RooSync messages."
    $PromptParts += "If [FRICTION-FOUND] found: note the friction for context."
    $PromptParts += ""
    $PromptParts += "AFTER completing work, append a message to the dashboard workspace:"
    $PromptParts += "roosync_dashboard(action: `"append`", type: `"workspace`", tags: [`"[DONE|PROGRESS|BLOCKED]`", `"claude-interactive`"], content: `"Your report...`")"
    $PromptParts += "Include: task executed, result (success/fail), next recommended action."
    $PromptParts += ""
    $PromptParts += "## Issue #$IssueNumber : $Title"
    $PromptParts += ""

    if ($Spec) {
        $PromptParts += "### Execution-Ready Spec"
        $PromptParts += $Spec
        $PromptParts += ""
        $PromptParts += "### Full Issue Context (for reference)"
        # Truncate body to avoid excessively long prompts
        $MaxBodyLen = 3000
        if ($Body.Length -gt $MaxBodyLen) {
            $PromptParts += $Body.Substring(0, $MaxBodyLen) + "`n[... body truncated ...]"
        } else {
            $PromptParts += $Body
        }
    } else {
        # No execution-ready spec - use the full body but add guidance
        $PromptParts += "### Issue Description"
        $MaxBodyLen = 4000
        if ($Body.Length -gt $MaxBodyLen) {
            $PromptParts += $Body.Substring(0, $MaxBodyLen) + "`n[... body truncated ...]"
        } else {
            $PromptParts += $Body
        }
    }

    $PromptParts += ""
    $PromptParts += "After completing the work, output your results clearly. If you cannot complete the task, explain what blocked you."
    $PromptParts += ""
    $PromptParts += "## Agent Protocol"
    $PromptParts += "You MUST end your response with one of these structured status blocks:"
    $PromptParts += ""
    $PromptParts += "If you completed the work successfully:"
    $PromptParts += "=== AGENT STATUS ==="
    $PromptParts += "STATUS: success"
    $PromptParts += "REASON: [summary of what was done]"
    $PromptParts += "==================="
    $PromptParts += ""
    $PromptParts += "If this task requires a more capable model (e.g. complex architecture, multi-file refactoring):"
    $PromptParts += "=== AGENT STATUS ==="
    $PromptParts += "STATUS: escalate"
    $PromptParts += "REASON: [why you cannot handle this]"
    $PromptParts += "ESCALATE_TO: sonnet"
    $PromptParts += "==================="
    $PromptParts += ""
    $PromptParts += "If blocked by an external dependency (waiting for another machine, user input, etc.):"
    $PromptParts += "=== AGENT STATUS ==="
    $PromptParts += "STATUS: wait"
    $PromptParts += "REASON: [blocking condition]"
    $PromptParts += "WAIT_FOR: [what needs to happen]"
    $PromptParts += "RESUME_WHEN: [github_comment|dashboard_message|timeout_hours:N]"
    $PromptParts += "==================="
    $PromptParts += ""
    $PromptParts += "If you need more iterations to complete (partial progress made):"
    $PromptParts += "=== AGENT STATUS ==="
    $PromptParts += "STATUS: continue"
    $PromptParts += "REASON: [what remains to be done]"
    $PromptParts += "==================="
    $PromptParts += ""
    $PromptParts += "For multi-session work: report progress via GitHub issue comment so the next session can continue."

    return ($PromptParts -join "`n")
}

function Get-FallbackTask {
    return @{
        id = "fallback-maintenance"
        subject = "Maintenance quotidienne (fallback)"
        priority = "LOW"
        prompt = "Exécute les tâches de maintenance :`n0. Lire dashboard workspace: roosync_dashboard(action=`"read`", type=`"workspace`", section=`"intercom`", intercomLimit: 10) - chercher messages Roo recents (tags: [DONE], [WAKE-CLAUDE], [FRICTION-FOUND])`n1. Vérifier build : cd mcps/internal/servers/roo-state-manager && npm run build`n2. Vérifier tests : npx vitest run`n3. Reporter résultats dans dashboard workspace: roosync_dashboard(action=`"append`", type=`"workspace`", tags=[`"DONE`",`"claude-interactive`"], content=`"...`")"
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

        # --- Stale wait-state auto-cleanup ---
        # Auto-remove wait states older than 7 days or for CLOSED issues
        $StaleThresholdDays = 7
        $WaitAge = (Get-Date) - [datetime]$State.timestamp
        if ($WaitAge.TotalDays -gt $StaleThresholdDays) {
            Write-Log "🗑️ Wait state PÉRIMÉ (age: $([math]::Round($WaitAge.TotalDays))j > ${StaleThresholdDays}j) → suppression automatique" "WARN"
            Remove-WaitState -TaskId $TaskId
            return $null
        }

        # Auto-remove wait states for CLOSED GitHub issues
        if ($TaskId -match "github-(\d+)") {
            $IssueNum = $Matches[1]
            try {
                $IssueState = (& gh issue view $IssueNum --repo jsboige/roo-extensions --json state --jq '.state' 2>$null)
                if ($IssueState -eq "CLOSED") {
                    Write-Log "🗑️ Wait state pour issue FERMÉE (#$IssueNum) → suppression automatique" "WARN"
                    Remove-WaitState -TaskId $TaskId
                    return $null
                }
            } catch {
                Write-Log "  Impossible de vérifier l'état de l'issue #$IssueNum" "WARN"
            }
        }

        # Vérifier condition resumeWhen
        $ResumeCondition = $State.resumeWhen.ToLower() -replace '[_\s]+', '_'

        switch -Regex ($ResumeCondition) {
            "timeout_hours:?\s*(\d+)" {
                $TimeoutHours = [int]$Matches[1]
                Write-Log "  Vérification timeout ($TimeoutHours heures)..."
                if ($WaitAge.TotalHours -ge $TimeoutHours) {
                    Write-Log "✅ Timeout expiré ($([math]::Round($WaitAge.TotalHours))h >= ${TimeoutHours}h) - reprise autorisée"
                    return $State
                } else {
                    Write-Log "  ⏳ Timeout pas encore atteint ($([math]::Round($WaitAge.TotalHours,1))h / ${TimeoutHours}h)"
                }
            }
            "user_approval|user approval" {
                Write-Log "  Vérification user approval (Dashboard + GitHub)..."
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
            "github_decision|github decision|github_status|github status|github_comment|github comment" {
                Write-Log "  Vérification GitHub decision/comment (issue status)..."
                if (Test-GitHubDecision -TaskId $TaskId -WaitState $State) {
                    Write-Log "✅ GitHub decision/comment détectée - reprise autorisée"
                    return $State
                }
            }
            "intercom_message|intercom message" {
                Write-Log "  Vérification Dashboard message..."
                if (Test-DashboardMessage -TaskId $TaskId -WaitState $State) {
                    Write-Log "✅ Dashboard message détecté - reprise autorisée"
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
    Vérifie si user approval détectée (Dashboard workspace + GitHub comments)
    #>
    param([string]$TaskId, $WaitState)

    # Note: Cette fonction vérifie les commentaires GitHub pour user approval
    # Le dashboard workspace est utilisé pour la coordination mais les approvals
    # se font généralement via GitHub issues/comments

    try {
        # Vérifier les commentaires GitHub récents sur l'issue associée
        $IssueNumber = if ($TaskId -match 'issue-(\d+)') { $Matches[1] } else { $null }

        if ($IssueNumber) {
            $Comments = & gh issue view $IssueNumber --repo jsboige/roo-extensions --json comments --jq '.comments[].body' 2>&1
            if ($LASTEXITCODE -eq 0) {
                $ApprovalPatterns = @(
                    '\[APPROVE\]', '\[APPROVED\]', '\[OK\]', '\[GO\]',
                    'approved', 'go ahead', 'proceed', 'continue'
                )

                foreach ($Comment in $Comments) {
                    foreach ($Pattern in $ApprovalPatterns) {
                        if ($Comment -match $Pattern) {
                            return $true
                        }
                    }
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
        $ApprovalPatterns = @('approve', 'go ahead', 'proceed', 'continue', 'done', 'confirmed', 'validated', 'tested', 'ok', 'lgtm')
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
    Vérifie si message dashboard workspace détecté (DEPRECATED - use Test-DashboardMessage)
    #>
    param([string]$TaskId, $WaitState)

    # DEPRECATED since #745 Phase 2 — use Test-DashboardMessage instead
    # Returns false always (INTERCOM file no longer used for resume signals)
    Write-Log "Test-IntercomMessage est deprecated - utiliser Test-DashboardMessage à la place" "WARN"
    return $false
}

function Test-DashboardMessage {
    <#
    .SYNOPSIS
    Vérifie si message dashboard workspace détecté après timestamp
    #>
    param([string]$TaskId, $WaitState)

    # Note: Pour l'instant, cette fonction retourne false car le dashboard
    # est principalement utilisé pour les rapports, pas pour les signaux de reprise
    # Les signaux de reprise se font via GitHub issues/comments ou RooSync inbox
    return $false
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

function Determine-Model {
    <#
    .SYNOPSIS
    Determines which Claude model to use based on Project #67 field, then script param, then default.

    .DESCRIPTION
    Priority chain:
    1. Project field "Model" (deterministic, set by coordinator in GitHub Project #67)
    2. Script parameter -Model (fallback, e.g. from Task Scheduler)
    3. Default: "sonnet"

    Note: Claude Code does NOT have "modes" like Roo. It uses models (haiku/sonnet/opus)
    and sub-agents (Agent tool). The mode config model is intentionally NOT in this chain.
    #>
    param($Task)

    # Priority 1: Project field "Model" (deterministic, highest priority)
    if ($Task.projectFields -and $Task.projectFields.Model) {
        $ProjectModel = $Task.projectFields.Model.ToLower()
        Write-Log "Modele determine par champ Project: $ProjectModel"
        return $ProjectModel
    }

    # Priority 2: Script parameter -Model (fallback)
    if ($Model) {
        Write-Log "Modele determine par parametre script: $Model"
        return $Model
    }

    # Priority 3: Default
    Write-Log "Modele par defaut: sonnet"
    return "sonnet"
}

function Get-DeadlineUrgency {
    <#
    .SYNOPSIS
    Calculates urgency level from the Deadline Project field.

    .DESCRIPTION
    Returns urgency level that determines iteration count:
    - "urgent" (<6h): Max effort, do everything now
    - "normal" (6-48h): Use configured iterations
    - "relaxed" (>48h or no deadline): Spread across sessions (1-2 iter)
    #>
    param($Task)

    if (-not $Task.projectFields -or -not $Task.projectFields.Deadline) {
        return "relaxed"
    }

    try {
        $DeadlineDate = [DateTime]::Parse($Task.projectFields.Deadline)
        $TimeLeft = $DeadlineDate - (Get-Date).ToUniversalTime()

        if ($TimeLeft.TotalHours -lt 0) {
            Write-Log "  Deadline DEPASSEE de $([Math]::Abs([Math]::Round($TimeLeft.TotalHours, 1)))h !" "WARN"
            return "urgent"
        }
        elseif ($TimeLeft.TotalHours -lt 6) {
            Write-Log "  Deadline dans $([Math]::Round($TimeLeft.TotalHours, 1))h -> URGENT"
            return "urgent"
        }
        elseif ($TimeLeft.TotalHours -lt 48) {
            Write-Log "  Deadline dans $([Math]::Round($TimeLeft.TotalHours, 1))h -> normal"
            return "normal"
        }
        else {
            Write-Log "  Deadline dans $([Math]::Round($TimeLeft.TotalHours / 24, 1))j -> relaxed"
            return "relaxed"
        }
    }
    catch {
        Write-Log "  Erreur parsing deadline '$($Task.projectFields.Deadline)': $_" "WARN"
        return "relaxed"
    }
}

function Get-AdjustedIterations {
    <#
    .SYNOPSIS
    Adjusts iteration count based on urgency level and mode config.

    .DESCRIPTION
    - urgent: At least 10 iterations (max effort in this session)
    - normal: Use mode config maxIterations (or script param)
    - relaxed: Cap at 2 iterations (spread work across scheduler ticks)
    #>
    param(
        [string]$Urgency,
        [int]$BaseIterations,
        [string]$ModeId
    )

    # Iterations: explicit param > worker default
    $Iterations = if ($BaseIterations -gt 0) { $BaseIterations } else { $WorkerDefaultIterations }

    $AdjustedIterations = switch ($Urgency) {
        "urgent"  { [Math]::Max($Iterations, 10) }   # Max effort
        "normal"  { $Iterations }                      # As configured
        "relaxed" { [Math]::Min($Iterations, 2) }     # Spread across sessions
        default   { $Iterations }
    }

    Write-Log "Iterations: $AdjustedIterations (urgence=$Urgency, base=$Iterations, config=$ConfigIterations)"
    return $AdjustedIterations
}

function Find-ExistingWorktree {
    <#
    .SYNOPSIS
    Cherche un worktree existant du run précédent pour reprise

    .DESCRIPTION
    Scanne le répertoire .claude/worktrees/ pour trouver des worktrees orphelins
    du run précédent. Si trouvé, évalue l'état (git status, log) et décide si on peut reprendre.

    .OUTPUTS
    Hashtable avec { worktreePath, state, branch, hasChanges } si un worktree reprise possible, $null sinon.
    #>
    param([string]$TaskId)

    $WorktreeDir = Join-Path $RepoRoot ".claude\worktrees"
    if (-not (Test-Path $WorktreeDir)) { return $null }

    $Machine = $env:COMPUTERNAME.ToLower()

    # Chercher les worktrees correspondants à cette machine
    $WorktreePattern = "wt-worker-$Machine-*"
    if ($TaskId -match 'issue-(\d+)') {
        $WorktreePattern = "wt-$($Matches[1])-$Machine-*"
    }

    $CandidateDirs = Get-ChildItem $WorktreeDir -Filter "$WorktreePattern" -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending

    if ($CandidateDirs.Count -eq 0) { return $null }

    Write-Log "Vérification de $($CandidateDirs.Count) worktree(s) existant(s) pour reprise..."

    foreach ($Dir in $CandidateDirs) {
        $WorktreePath = $Dir.FullName

        # Vérifier que c'est bien un worktree git valide
        $GitDir = Join-Path $WorktreePath ".git"
        if (-not (Test-Path $GitDir)) { continue }

        try {
            # Évaluer l'état du worktree
            $PrevPref = $ErrorActionPreference
            $ErrorActionPreference = "Continue"

            # Récupérer le nom de la branche
            $Branch = git -C $WorktreePath branch --show-current 2>&1
            if ($LASTEXITCODE -ne 0) {
                $ErrorActionPreference = $PrevPref
                continue
            }
            $Branch = $Branch.Trim()

            # Vérifier s'il y a des changements
            $StatusOutput = git -C $WorktreePath status --porcelain 2>&1
            $HasChanges = $StatusOutput -and $StatusOutput.Trim().Length -gt 0

            # Récupérer les derniers commits
            $LogOutput = git -C $WorktreePath log --oneline -3 2>&1

            $ErrorActionPreference = $PrevPref

            # Log les détails
            Write-Log "Worktree existant trouvé: $WorktreePath"
            Write-Log "  → Branch: $Branch"
            Write-Log "  → Changements: $(if ($HasChanges) { 'OUI' } else { 'NON' })"
            Write-Log "  → Derniers commits:"
            $LogOutput -split "`n" | ForEach-Object { Write-Log "    $_" "GIT" }

            # Décider: si pas de changements, proposer de supprimer et recréer
            # Si changements, proposer de reprendre
            if ($HasChanges) {
                Write-Log "✅ Worktree avec changements - REPRISE POSSIBLE"
                return @{
                    worktreePath = $WorktreePath
                    state = "resume"
                    branch = $Branch
                    hasChanges = $true
                }
            } else {
                Write-Log "ℹ️ Worktree propre (0 changements) - suppression et recréation recommandée"
                # On pourrait supprimer ici, mais on laisse Create-Worktree le faire
                return @{
                    worktreePath = $WorktreePath
                    state = "clean"
                    branch = $Branch
                    hasChanges = $false
                }
            }
        }
        catch {
            Write-Log "Erreur vérification worktree ${WorktreePath}: $_" "WARN"
            continue
        }
    }

    return $null
}

function Create-Worktree {
    param([string]$TaskId, $Task)

    if (-not $UseWorktree) {
        Write-Log "Worktree désactivé, travail sur branche principale"
        return $null
    }

    # 1. Chercher d'abord un worktree existant du run précédent
    $ExistingWt = Find-ExistingWorktree -TaskId $TaskId

    if ($ExistingWt) {
        if ($ExistingWt.state -eq "resume") {
            # Worktree avec changements - on reprend dedans
            Write-Log "🔄 REPRISE dans worktree existant: $($ExistingWt.worktreePath)"
            Write-Log "  → Branch: $($ExistingWt.branch)"
            Write-Log "  → Les changements existants seront préservés"

            # Ajouter un contexte de continuation au prompt si fourni
            if ($Task -and $Task.prompt) {
                $Task.prompt = "[CONTINUATION FROM PREVIOUS SESSION - Resuming in existing worktree with uncommitted changes]`n`n" + $Task.prompt
            }

            return $ExistingWt.worktreePath
        } elseif ($ExistingWt.state -eq "clean") {
            # Worktree propre - supprimer et recréer
            Write-Log "🧹 Nettoyage worktree propre: $($ExistingWt.worktreePath)"
            Remove-Worktree -WorktreePath $ExistingWt.worktreePath
            Write-Log "  → Worktree supprimé, création d'un nouveau..."
        }
    }

    # 2. Créer un nouveau worktree
    # Extract issue number from task subject for cleaner branch names
    $IssueNum = $null
    if ($Task -and $Task.subject -match '#(\d+)') { $IssueNum = $Matches[1] }

    # Branch naming: wt/{issue}-{machine}-{date} or wt/worker-{machine}-{date}
    $Machine = $env:COMPUTERNAME.ToLower()
    $DateStamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $BranchName = if ($IssueNum) {
        "wt/$IssueNum-$Machine-$DateStamp"
    } else {
        "wt/worker-$Machine-$DateStamp"
    }

    # Use .claude/worktrees/ (already in .gitignore)
    $WorktreeDir = Join-Path $RepoRoot ".claude\worktrees"
    if (-not (Test-Path $WorktreeDir)) {
        New-Item -ItemType Directory -Path $WorktreeDir -Force | Out-Null
    }
    $WorktreePath = Join-Path $WorktreeDir $BranchName.Replace("/", "-")

    Write-Log "Création worktree: $WorktreePath (branch: $BranchName)"

    try {
        # Ensure we're on latest main before branching
        # Note: git sends info messages to stderr; temporarily allow errors
        $prevPref = $ErrorActionPreference
        $ErrorActionPreference = "Continue"

        git -C $RepoRoot fetch origin main --quiet 2>&1 | Out-Null

        # Créer worktree with new branch from current HEAD
        $wtOutput = git -C $RepoRoot worktree add $WorktreePath -b $BranchName 2>&1
        $wtExitCode = $LASTEXITCODE
        $ErrorActionPreference = $prevPref

        $wtOutput | ForEach-Object { Write-Log "$_" "GIT" }

        if ($wtExitCode -ne 0) {
            Write-Log "git worktree add failed (exit $wtExitCode)" "ERROR"
            return $null
        }

        Write-Log "Worktree créé avec succès (branch: $BranchName)"

        # Initialize submodules in the new worktree (#802)
        Write-Log "Initialisation des submodules dans le worktree..."
        try {
            $prevPref2 = $ErrorActionPreference
            $ErrorActionPreference = "Continue"
            $smOutput = git -C $WorktreePath submodule update --init --recursive 2>&1
            $smExitCode = $LASTEXITCODE
            $ErrorActionPreference = $prevPref2

            $smOutput | ForEach-Object { Write-Log "$_" "GIT" }

            if ($smExitCode -eq 0) {
                Write-Log "Submodules initialisés avec succès"
            } else {
                Write-Log "Attention: initialisation submodules code $smExitCode" "WARN"
            }
        } catch {
            $ErrorActionPreference = $prevPref2
            Write-Log "Erreur initialisation submodules: $_" "WARN"
        }

        return $WorktreePath
    }
    catch {
        $ErrorActionPreference = $prevPref
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
        $prevPref = $ErrorActionPreference
        $ErrorActionPreference = "Continue"
        $rmOutput = git -C $RepoRoot worktree remove $WorktreePath --force 2>&1
        $ErrorActionPreference = $prevPref
        $rmOutput | ForEach-Object { Write-Log "$_" "GIT" }
        Write-Log "Worktree supprimé"
    }
    catch {
        $ErrorActionPreference = $prevPref
        Write-Log "Erreur suppression worktree: $_" "WARN"
    }
}

# ============================================================================
# Worktree → PR Workflow (#461 Phase 1)
# ============================================================================

function Test-WorktreeHasChanges {
    <#
    .SYNOPSIS
    Checks if the worktree branch has changes relative to main.
    Auto-commits any uncommitted changes before checking.
    #>
    param([string]$WorktreePath)

    try {
        Push-Location $WorktreePath
        $prevPref = $ErrorActionPreference
        $ErrorActionPreference = "Continue"

        # Auto-commit any uncommitted changes left by Claude
        $Uncommitted = (git status --porcelain 2>&1) | Where-Object { $_ -is [string] }
        if ($Uncommitted) {
            Write-Log "Worktree has uncommitted changes, auto-committing..." "INFO"
            git add -A 2>&1 | Out-Null
            $CommitMsg = "chore: Auto-commit uncommitted worker changes`n`nCo-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
            git commit -m $CommitMsg 2>&1 | ForEach-Object { Write-Log "$_" "GIT" }
        }

        # Check if branch has commits ahead of main
        $Ahead = (git rev-list main..HEAD --count 2>&1).Trim()
        $ErrorActionPreference = $prevPref
        $HasChanges = ([int]$Ahead) -gt 0

        Write-Log "Worktree commits ahead of main: $Ahead"
        return $HasChanges
    }
    catch {
        $ErrorActionPreference = $prevPref
        Write-Log "Error checking worktree changes: $_" "WARN"
        return $false
    }
    finally {
        Pop-Location
    }
}

function Push-WorktreeBranch {
    <#
    .SYNOPSIS
    Pushes the worktree branch to origin.
    #>
    param([string]$WorktreePath)

    try {
        Push-Location $WorktreePath
        $prevPref = $ErrorActionPreference
        $ErrorActionPreference = "Continue"

        # Get current branch name
        $BranchName = (git rev-parse --abbrev-ref HEAD 2>&1).Trim()
        Write-Log "Pushing branch: $BranchName"

        $pushOutput = git push -u origin $BranchName 2>&1
        $pushExitCode = $LASTEXITCODE
        $ErrorActionPreference = $prevPref

        $pushOutput | ForEach-Object { Write-Log "$_" "GIT" }

        if ($pushExitCode -ne 0) {
            Write-Log "Push failed (exit $pushExitCode)" "ERROR"
            return $false
        }

        Write-Log "Branch pushed successfully"
        return $true
    }
    catch {
        $ErrorActionPreference = $prevPref
        Write-Log "Error pushing branch: $_" "ERROR"
        return $false
    }
    finally {
        Pop-Location
    }
}

function New-WorkerPR {
    <#
    .SYNOPSIS
    Creates a GitHub Pull Request from the worktree branch.

    .DESCRIPTION
    After Claude Worker completes its task in a worktree, this function
    creates a PR targeting main for review by the coordinator.
    Part of #461 Phase 1 - worktree/PR protocol.

    .OUTPUTS
    String - PR URL if created successfully, $null otherwise
    #>
    param(
        $Task,
        [string]$WorktreePath,
        $Result,
        [string]$FinalMode
    )

    try {
        Push-Location $WorktreePath

        # Extract issue number from task subject
        $IssueNum = $null
        if ($Task.subject -match '#(\d+)') { $IssueNum = $Matches[1] }

        # Count commits for summary
        $CommitCount = (git rev-list main..HEAD --count 2>&1).Trim()
        $CommitLog = (git log main..HEAD --oneline 2>&1) -join "`n"

        # PR title (max 70 chars)
        $CleanSubject = $Task.subject -replace '^\[TASK\]\s*', '' -replace '^\[URGENT\]\s*', ''
        $Title = "[Worker] $CleanSubject"
        if ($Title.Length -gt 70) { $Title = $Title.Substring(0, 67) + "..." }

        # PR body
        $IssueRef = if ($IssueNum) { "`nRelates to #$IssueNum" } else { "" }
        $StatusText = if ($Result.success) { "Success" } else { "Partial (needs review)" }
        $Body = @"
## Summary
- **Machine:** $($env:COMPUTERNAME)
- **Task:** $($Task.id)
- **Mode:** $FinalMode
- **Status:** $StatusText
- **Commits:** $CommitCount

### Commits
``````
$CommitLog
``````

## Test plan
- [ ] Build passes (``npm run build``)
- [ ] Tests pass (``npx vitest run``)
- [ ] Code review by coordinator
$IssueRef

Generated by Claude Worker on $($env:COMPUTERNAME) at $(Get-Date -Format o)
"@

        # Write body to temp file (avoid PS argument splitting issues)
        $BodyFile = Join-Path $env:TEMP "pr-body-$(Get-Date -Format 'yyyyMMdd-HHmmss').txt"
        [System.IO.File]::WriteAllText($BodyFile, $Body, [System.Text.UTF8Encoding]::new($false))

        Write-Log "Creating PR: $Title"
        $PrOutput = & gh pr create --title $Title --body-file $BodyFile --repo jsboige/roo-extensions --base main 2>&1
        $PrExitCode = $LASTEXITCODE
        Remove-Item $BodyFile -ErrorAction SilentlyContinue

        if ($PrExitCode -ne 0) {
            Write-Log "PR creation failed (exit $PrExitCode): $PrOutput" "ERROR"
            return $null
        }

        # Extract PR URL from output
        $PrUrl = ($PrOutput | Where-Object { $_ -match 'https://github.com' }) | Select-Object -First 1
        if (-not $PrUrl) { $PrUrl = ($PrOutput -join " ").Trim() }

        Write-Log "PR created: $PrUrl" "INFO"
        return $PrUrl
    }
    catch {
        Write-Log "Error creating PR: $_" "ERROR"
        return $null
    }
    finally {
        Pop-Location
    }
}

function Invoke-Claude {
    param(
        [string]$ModeId,
        [string]$Prompt,
        [string]$WorkingDir,
        [int]$MaxIter
    )

    Write-Log "Lancement Claude en mode: $ModeId (model: $Model)"
    Write-Log "Prompt: $Prompt"

    # Iterations: explicit param > worker default
    $Iterations = if ($MaxIter -gt 0) { $MaxIter } else { $WorkerDefaultIterations }

    # Model is already set by Determine-Model in main workflow (Project field > param > default)
    $ModelToUse = if ($Model) { $Model } else { "sonnet" }
    Write-Log "Modele final: $ModelToUse"

    # Construire commande Claude CLI
    # Note: --dangerously-skip-permissions requis pour autonomie
    # BUG FIX (Cycle 42): Prompts containing option-like strings (e.g. "-simple",
    # "--body") cause PowerShell to split multiline strings and pass fragments
    # as separate CLI arguments when using -p with splatting.
    # Fix: Save prompt to temp file, pipe via stdin. Claude Code reads stdin as prompt.
    $PromptFile = Join-Path $env:TEMP "claude-prompt-$(Get-Date -Format 'yyyyMMdd-HHmmss').txt"
    [System.IO.File]::WriteAllText($PromptFile, $Prompt, [System.Text.UTF8Encoding]::new($false))
    Write-Log "Prompt sauvé dans: $PromptFile ($($Prompt.Length) chars)"

    if ($DryRun) {
        Write-Log "[DRY-RUN] Commande qui serait exécutée:" "INFO"
        Write-Log "Get-Content $PromptFile | claude --dangerously-skip-permissions --model $ModelToUse -p -" "INFO"
        Remove-Item $PromptFile -ErrorAction SilentlyContinue
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

            # TAKE ACTION: Exécuter Claude CLI avec streaming en temps réel
            # Uses --output-format stream-json --verbose --include-partial-messages to get
            # real-time token-by-token streaming of text + tool calls in the terminal.
            # Raw JSON events are logged to per-iteration files for audit/debug.
            # BUG FIX (Cycle 42): Pipe prompt from file to avoid PowerShell argument splitting.
            $IterationOutputFile = Join-Path $LogDir "worker-iter-$(Get-Date -Format 'yyyyMMdd-HHmmss')-$CurrentIteration.log"
            Write-Log "Output streaming (stream-json --verbose) vers: $IterationOutputFile"
            try {
                $FinalResultText = ""
                $CurrentToolName = $null
                $CurrentToolInput = ""
                Get-Content $PromptFile -Raw | & claude --dangerously-skip-permissions --model $ModelToUse -p - --output-format stream-json --verbose --include-partial-messages 2>&1 | ForEach-Object {
                    $rawLine = $_.ToString()
                    # Raw JSON events to iteration-specific log (audit/debug)
                    Add-Content -Path $IterationOutputFile -Value $rawLine
                    try {
                        $evt = $rawLine | ConvertFrom-Json -ErrorAction Stop
                        if ($evt.type -eq "stream_event" -and $evt.event) {
                            $inner = $evt.event
                            if ($inner.type -eq "content_block_start" -and $inner.content_block) {
                                if ($inner.content_block.type -eq "tool_use") {
                                    $CurrentToolName = $inner.content_block.name
                                    $CurrentToolInput = ""
                                    Write-Host ""
                                    Write-Host "  [Tool: $CurrentToolName] " -NoNewline -ForegroundColor Cyan
                                }
                            }
                            elseif ($inner.type -eq "content_block_delta" -and $inner.delta) {
                                if ($inner.delta.type -eq "text_delta" -and $inner.delta.text) {
                                    Write-Host $inner.delta.text -NoNewline
                                }
                                elseif ($inner.delta.type -eq "input_json_delta" -and $inner.delta.partial_json) {
                                    $CurrentToolInput += $inner.delta.partial_json
                                }
                            }
                            elseif ($inner.type -eq "content_block_stop") {
                                if ($CurrentToolName) {
                                    # Show truncated tool input for context
                                    $preview = if ($CurrentToolInput.Length -gt 150) { $CurrentToolInput.Substring(0, 150) + "..." } else { $CurrentToolInput }
                                    Write-Host $preview -ForegroundColor DarkCyan
                                    $CurrentToolName = $null
                                    $CurrentToolInput = ""
                                }
                            }
                        }
                        elseif ($evt.type -eq "result") {
                            if ($evt.result) { $FinalResultText = $evt.result }
                            Write-Host "`n--- Fin session ($($evt.session_id)) ---" -ForegroundColor DarkGray
                        }
                        # Skip assistant/user/system messages (content already streamed via deltas)
                    }
                    catch {
                        # Not JSON (stderr, etc.) - display raw
                        Write-Host $rawLine -ForegroundColor Yellow
                    }
                }
                $IterationOutputs += $FinalResultText
                Write-Log "Iteration $CurrentIteration terminée (result: $($FinalResultText.Length) chars)"
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
        Remove-Item $PromptFile -ErrorAction SilentlyContinue

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
        Remove-Item $PromptFile -ErrorAction SilentlyContinue
        Write-Log "Erreur exécution Claude: $_" "ERROR"
        return @{ success = $false; error = $_.Exception.Message }
    }
}

function Check-Escalation {
    param(
        $Result,
        [string]$CurrentModel
    )

    # Agent Status protocol: agent explicitly signals escalation need
    # STATUS: escalate / ESCALATE_TO: sonnet|opus
    if ($Result.escalateToModel) {
        Write-Log "Escalade demandee par agent vers modele: $($Result.escalateToModel)" "WARN"
        return $Result.escalateToModel
    }

    # Auto-escalate on failure: haiku -> sonnet -> opus
    if (-not $Result.success) {
        $NextModel = Get-EscalatedModel -CurrentModel $CurrentModel
        if ($NextModel) {
            Write-Log "Echec detecte, escalade modele: $CurrentModel -> $NextModel" "WARN"
            return $NextModel
        }
        Write-Log "Echec detecte mais deja au modele max ($CurrentModel)" "WARN"
    }

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
# Git Sync + Auto-Review (#544 Phase 2)
# ============================================================================

function Invoke-GitSyncAndReview {
    <#
    .SYNOPSIS
    Pulls latest changes and triggers auto-review if new commits detected.

    .DESCRIPTION
    Phase 0.5 of the worker pipeline:
    1. Record current HEAD
    2. Git pull from origin
    3. If HEAD changed → trigger auto-review (non-blocking)

    .OUTPUTS
    Hashtable with: pullSuccess, headChanged, newHead, reviewTriggered
    #>

    $result = @{
        pullSuccess = $false
        headChanged = $false
        newHead = $null
        reviewTriggered = $false
        error = $null
    }

    try {
        # Record current HEAD before pull
        $oldHead = (git -C $RepoRoot rev-parse HEAD 2>&1).Trim()
        Write-Log "Git HEAD before pull: $($oldHead.Substring(0, 7))"

        # Pull from origin (no-rebase to avoid conflicts)
        Write-Log "Git pull origin main..."
        $pullOutput = git -C $RepoRoot pull --no-rebase origin main 2>&1
        $pullExitCode = $LASTEXITCODE

        if ($pullExitCode -ne 0) {
            Write-Log "Git pull failed (exit $pullExitCode): $pullOutput" "WARN"
            $result.error = "Git pull failed: $pullOutput"
            return $result
        }

        $result.pullSuccess = $true
        $newHead = (git -C $RepoRoot rev-parse HEAD 2>&1).Trim()
        $result.newHead = $newHead
        Write-Log "Git HEAD after pull: $($newHead.Substring(0, 7))"

        # Check if HEAD changed
        if ($newHead -ne $oldHead) {
            $result.headChanged = $true
            $commitCount = (git -C $RepoRoot rev-list "$oldHead..$newHead" --count 2>&1).Trim()
            Write-Log "HEAD changed: $commitCount new commit(s) detected" "INFO"

            # Trigger auto-review (non-blocking, best-effort)
            $reviewScript = Join-Path $RepoRoot "scripts\review\start-auto-review.ps1"
            if (Test-Path $reviewScript) {
                Write-Log "Triggering auto-review for new commits..."
                try {
                    # Run with -BuildCheck and -DryRun if worker is in DryRun mode
                    $reviewArgs = @("-BuildCheck")
                    if ($DryRun) { $reviewArgs += "-DryRun" }

                    # Calculate diff range based on commit count
                    if ([int]$commitCount -gt 1) {
                        $reviewArgs += "-DiffRange"
                        $reviewArgs += "HEAD~$commitCount"
                    }

                    # Execute auto-review with build gate (timeout 600s: build ~30-60s + tests ~90-180s + sk-agent ~60s)
                    # 600s accommodates web1 (16GB RAM, --maxWorkers=1) where tests take ~180s
                    $reviewJob = Start-Job -ScriptBlock {
                        param($script, $args)
                        & powershell -ExecutionPolicy Bypass -File $script @args
                    } -ArgumentList $reviewScript, $reviewArgs

                    # Wait max 600s, then continue regardless
                    $reviewCompleted = Wait-Job $reviewJob -Timeout 600
                    if ($reviewCompleted) {
                        $reviewOutput = Receive-Job $reviewJob
                        Write-Log "Auto-review completed: $($reviewOutput | Select-Object -Last 1)" "INFO"
                        $result.reviewTriggered = $true
                    } else {
                        Write-Log "Auto-review still running (timeout 600s), continuing..." "WARN"
                        Stop-Job $reviewJob -ErrorAction SilentlyContinue
                        $result.reviewTriggered = $true  # It was triggered, just timed out
                    }
                    Remove-Job $reviewJob -Force -ErrorAction SilentlyContinue
                }
                catch {
                    Write-Log "Auto-review failed (non-blocking): $_" "WARN"
                }
            } else {
                Write-Log "Auto-review script not found: $reviewScript" "WARN"
            }
        } else {
            Write-Log "No new commits (HEAD unchanged)"
        }
    }
    catch {
        Write-Log "Git sync error: $_" "WARN"
        $result.error = "Git sync error: $_"
    }

    return $result
}

# ============================================================================
# MAIN WORKFLOW
# ============================================================================

Write-Log "=== DÉMARRAGE CLAUDE WORKER ==="
Write-Log "Machine: $env:COMPUTERNAME"
Write-Log "RepoRoot: $RepoRoot"
Write-Log "DryRun: $DryRun"

# Pre-flight: verify Claude CLI is available (#571 Bug 3)
if (-not (Test-ClaudeCLI)) {
    Write-Log "ABORT: Claude CLI introuvable. Installer via: npm install -g @anthropic-ai/claude-code" "ERROR"
    exit 1
}

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
    # Phase 0.5 : Git Sync + Auto-Review (#544)
    # Pull latest changes and trigger review if new commits detected.
    # Non-blocking: failures here don't prevent task execution.
    # ==========================================================================

    if (-not $IsResume) {
        $GitSyncResult = Invoke-GitSyncAndReview
        if ($GitSyncResult.pullSuccess) {
            Write-Log "Git sync OK (head changed: $($GitSyncResult.headChanged), review: $($GitSyncResult.reviewTriggered))"
        } elseif ($GitSyncResult.error) {
            Write-Log "Git sync issue: $($GitSyncResult.error)" "WARN"
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

        # --- Idle mode: coverage/patrol instead of doing nothing (#debrief-P3b) ---
        Write-Log "Passage en mode IDLE : tache de couverture de code" "INFO"
        $IdlePrompt = @"
Tu es un agent Claude Code en mode idle (aucune tache assignee).
Ta mission : ameliorer la couverture de tests du projet roo-state-manager.

## Instructions

1. Lance la commande de couverture :
   cd mcps/internal/servers/roo-state-manager && npx vitest run --coverage 2>&1 | tail -100

2. Identifie les 3 fichiers avec la couverture la plus faible (< 60% de lignes couvertes).

3. Pour le fichier le PLUS faible, ecris 2-3 tests unitaires supplementaires dans le dossier __tests__ correspondant.

4. Relance les tests pour verifier qu'ils passent :
   npx vitest run

5. Si les tests passent, commit avec le message :
   test(coverage): Add tests for [module] - idle worker coverage improvement

## Contraintes
- NE MODIFIE PAS le code source (seulement les fichiers de test)
- Si la couverture est deja > 80% partout, fais une exploration de veille : cherche des TODO, FIXME, ou du code mort et rapporte tes trouvailles dans un commentaire GitHub sur une issue existante.
- Maximum 15 minutes de travail.

=== AGENT STATUS ===
STATUS: success
REASON: [resume des tests ajoutes ou findings de veille]
===================
"@
        $Task = @{
            id = "idle-coverage-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
            subject = "[IDLE] Coverage improvement"
            from = "self"
            prompt = $IdlePrompt
        }
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

    # ==========================================================================
    # Phase 2b : Déterminer modèle (Project field > param > default)
    # ==========================================================================

    $Model = Determine-Model -Task $Task

    # Guard: Minimum model check (#747 - context window overflow prevention)
    # The project harness (CLAUDE.md + 10 rules + MCP tool schemas) consumes ~114K tokens.
    # haiku maps to glm-4.5-air on z.ai which has insufficient context for this harness.
    # Minimum viable model is sonnet (glm-4.7 on z.ai, ~131K context).
    $MinimumModel = "sonnet"
    $ModelHierarchy = @{ "haiku" = 1; "sonnet" = 2; "opus" = 3 }
    $ModelLevel = if ($ModelHierarchy.ContainsKey($Model)) { $ModelHierarchy[$Model] } else { 2 }
    $MinLevel = $ModelHierarchy[$MinimumModel]
    if ($ModelLevel -lt $MinLevel) {
        Write-Log "WARN: Model '$Model' has insufficient context window for harness (~114K tokens). Upgrading to '$MinimumModel'." "WARN"
        $Model = $MinimumModel
    }

    Write-Log "Modele selectionne: $Model"

    # ==========================================================================
    # Phase 2c : Planifier iterations selon Deadline
    # ==========================================================================

    $Urgency = Get-DeadlineUrgency -Task $Task
    $AdjustedIterations = Get-AdjustedIterations -Urgency $Urgency -BaseIterations $MaxIterations -ModeId $SelectedMode

    # 3. Créer worktree (#461 Phase 1 - default ON for scheduled tasks)
    $WorktreePath = if ($UseWorktree) {
        Create-Worktree -TaskId $Task.id -Task $Task
    } else {
        $RepoRoot
    }

    if (-not $WorktreePath) {
        $WorktreePath = $RepoRoot
    }

    # 3b. Validate worktree integrity (#802 - submodule must be initialized)
    if ($UseWorktree -and $WorktreePath -ne $RepoRoot) {
        $submodulePath = Join-Path $WorktreePath "mcps/internal/servers/roo-state-manager"
        if (-not (Test-Path (Join-Path $submodulePath "package.json"))) {
            Write-Log "WARN: Submodule not initialized in worktree (mcps/internal missing). Tasks requiring build/test will fail." "WARN"
        } else {
            Write-Log "Worktree integrity OK (submodule present)"
        }
    }

    # 4. Exécuter Claude avec mode sélectionné
    $Result = Invoke-Claude -ModeId $SelectedMode -Prompt $Task.prompt -WorkingDir $WorktreePath -MaxIter $AdjustedIterations

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

    # 5. Vérifier escalade (model-based: haiku -> sonnet -> opus)
    $EscalatedModel = Check-Escalation -Result $Result -CurrentModel $Model

    if ($EscalatedModel) {
        Write-Log "ESCALADE modele: $Model -> $EscalatedModel" "WARN"

        $OriginalModel = $Model
        $Model = $EscalatedModel

        $Result = Invoke-Claude -ModeId $SelectedMode -Prompt $Task.prompt -WorkingDir $WorktreePath -MaxIter $AdjustedIterations

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
        Write-Log "Nettoyage wait state après reprise réussie"
        Remove-WaitState -TaskId $Task.id
    }

    # 6c. Worktree → PR workflow (#461 Phase 1)
    $PrUrl = $null
    if ($UseWorktree -and $WorktreePath -ne $RepoRoot) {
        $HasChanges = Test-WorktreeHasChanges -WorktreePath $WorktreePath

        if ($HasChanges) {
            Write-Log "Worktree has changes, creating PR..." "INFO"
            $PushOk = Push-WorktreeBranch -WorktreePath $WorktreePath
            if ($PushOk) {
                $PrUrl = New-WorkerPR -Task $Task -WorktreePath $WorktreePath -Result $Result -FinalMode $SelectedMode
                if ($PrUrl) {
                    Write-Log "PR created successfully: $PrUrl" "INFO"

                    # PR review OBLIGATOIRE — plus d'auto-merge (feedback utilisateur 2026-03-23)
                    # La moitié du "code mort" détecté était du code fonctionnel détruit par des agents.
                    # Tout PR doit être reviewé par le coordinateur AVANT merge.
                    # Ancien comportement: auto-merge si SUCCESS (Issue #debrief-P1b) — DÉSACTIVÉ.
                    if ($Result.success) {
                        Write-Log "Agent reported SUCCESS — PR left open for coordinator review (auto-merge disabled)" "INFO"
                    } else {
                        Write-Log "Agent reported non-success — PR left open for coordinator review" "INFO"
                    }
                } else {
                    Write-Log "PR creation failed, changes are on remote branch" "WARN"
                }
            } else {
                Write-Log "Branch push failed, changes remain in local worktree only" "WARN"
            }
        } else {
            Write-Log "No changes in worktree, skipping PR creation"
        }
    }

    # 7. Marquer tâche comme complétée (RooSync, GitHub, ou rien si fallback)
    Mark-TaskAsComplete -Task $Task

    # 8. Cleanup worktree SEULEMENT après push+PR confirmés
    # Si PR créée avec succès, on peut supprimer le worktree (branch existe sur origin)
    # Sinon, conserver pour reprise ou investigation manuelle
    if ($UseWorktree -and $WorktreePath -ne $RepoRoot) {
        if ($PrUrl) {
            Write-Log "PR créée avec succès, suppression du worktree..."
            Remove-Worktree -WorktreePath $WorktreePath
        } else {
            Write-Log "⚠️ Pas de PR créée - worktree CONSERVÉ pour investigation: $WorktreePath" "WARN"
            Write-Log "  → Si pas de changements, le worktree sera nettoyé au prochain run" "INFO"
        }
    }

    Write-Log "=== WORKER TERMINÉ $(if ($PrUrl) { "(PR: $PrUrl)" }) ==="

    if ($Result.success) {
        exit 0
    } else {
        exit 1
    }
}
catch {
    Write-Log "ERREUR CRITIQUE: $_" "ERROR"
    Write-Log $_.ScriptStackTrace "ERROR"

    # EN CAS D'ERREUR: CONSERVER le worktree pour reprise au prochain run
    # Le worktree contient tout le travail non commité/pushé qui peut être repris
    if ($UseWorktree -and $WorktreePath -and ($WorktreePath -ne $RepoRoot)) {
        Write-Log "⚠️ Worktree CONSERVÉ pour reprise: $WorktreePath" "WARN"
        Write-Log "  → Le prochain run tentera de reprendre le travail dans ce worktree" "WARN"
    }

    exit 1
}
