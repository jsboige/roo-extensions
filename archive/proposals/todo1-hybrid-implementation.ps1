# TODO #1 - Get-NextTask - Implémentation Hybride Complète
# Issue #461 - Worktrees Integration
# Machine : myia-po-2025
# Date : 2026-02-12
# Validé par : myia-ai-01 (coordinateur)

<#
.SYNOPSIS
Système hybride de récupération de tâches pour Claude Code scheduler

.DESCRIPTION
Récupère la prochaine tâche depuis 3 sources par ordre de priorité :
1. RooSync inbox (instructions directes du coordinateur)
2. GitHub issues avec label "roo-schedulable" ET champ Agent = "Claude Code" ou "Both"
3. Fallback maintenance (build + tests)

.NOTES
Inclut protocole git lock/unlock pour éviter conflits entre Roo et Claude
#>

# =============================================================================
# FONCTION PRINCIPALE : Get-NextTask
# =============================================================================

function Get-NextTask {
    <#
    .SYNOPSIS
    Récupère la prochaine tâche depuis RooSync, GitHub, ou fallback

    .PARAMETER MachineId
    ID de la machine (défaut: hostname en minuscules)

    .PARAMETER AgentType
    Type d'agent : "claude" ou "roo" (défaut: "claude")

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
        Write-Log "Tâche RooSync trouvée: $($RooSyncTask.id)" "INFO"
        return $RooSyncTask
    }

    # --- PRIORITÉ 2 : GitHub issues ---
    Write-Log "Vérification GitHub issues..."
    $GitHubTask = Get-GitHubTask -AgentType $AgentType -MachineId $MachineId
    if ($GitHubTask) {
        Write-Log "Tâche GitHub trouvée: #$($GitHubTask.issueNumber)" "INFO"
        return $GitHubTask
    }

    # --- PRIORITÉ 3 : Fallback maintenance ---
    Write-Log "Aucune tâche RooSync/GitHub → Fallback maintenance"
    return Get-FallbackTask
}

# =============================================================================
# PRIORITÉ 1 : RooSync Inbox
# =============================================================================

function Get-RooSyncTask {
    <#
    .SYNOPSIS
    Récupère tâche depuis l'inbox RooSync

    .DESCRIPTION
    Lit les fichiers JSON dans $env:ROOSYNC_SHARED_PATH/messages/inbox/
    Filtre par machine (to == machine || to == "all") ET status == "unread"
    Trie par priorité (URGENT > HIGH > MEDIUM > LOW)
    #>

    param([string]$MachineId)

    # Récupérer le shared path depuis env
    $SharedPath = $env:ROOSYNC_SHARED_PATH
    if (-not $SharedPath) {
        Write-Log "ROOSYNC_SHARED_PATH non défini" "WARN"
        return $null
    }

    # Chemin inbox
    $InboxPath = Join-Path $SharedPath "messages\inbox"
    if (-not (Test-Path $InboxPath)) {
        Write-Log "Inbox RooSync introuvable: $InboxPath" "WARN"
        return $null
    }

    # Lire tous les messages JSON
    $Messages = Get-ChildItem $InboxPath -Filter "*.json" -ErrorAction SilentlyContinue | ForEach-Object {
        try {
            $Content = Get-Content $_.FullName -Raw | ConvertFrom-Json
            return $Content
        }
        catch {
            Write-Log "Erreur lecture message $($_.Name): $_" "WARN"
            return $null
        }
    } | Where-Object { $_ -ne $null }

    if ($Messages.Count -eq 0) {
        Write-Log "Inbox vide"
        return $null
    }

    # Filtrer messages pour cette machine
    $MyMessages = $Messages | Where-Object {
        ($_.to -eq $MachineId -or $_.to -eq "all") -and $_.status -eq "unread"
    }

    Write-Log "Messages non-lus pour $MachineId : $($MyMessages.Count)"

    if ($MyMessages.Count -eq 0) {
        return $null
    }

    # Trier par priorité (URGENT > HIGH > MEDIUM > LOW)
    $PriorityOrder = @{ "URGENT" = 1; "HIGH" = 2; "MEDIUM" = 3; "LOW" = 4 }
    $NextMessage = $MyMessages | Sort-Object {
        $PriorityOrder[$_.priority]
    } | Select-Object -First 1

    # Construire objet tâche
    $Task = @{
        id = $NextMessage.id
        subject = $NextMessage.subject
        priority = $NextMessage.priority
        prompt = $NextMessage.body
        source = "roosync"
        messageFile = Join-Path $InboxPath "$($NextMessage.id).json"
    }

    Write-Log "✅ RooSync: $($Task.id) - $($Task.subject) [Priority: $($Task.priority)]"

    return $Task
}

# =============================================================================
# PRIORITÉ 2 : GitHub Issues
# =============================================================================

function Get-GitHubTask {
    <#
    .SYNOPSIS
    Récupère tâche depuis GitHub issues avec label "roo-schedulable"

    .DESCRIPTION
    Utilise gh CLI pour lister les issues ouvertes
    Filtre par champ Agent (Claude Code ou Both)
    Évite les issues déjà assignées (premier arrivé, premier servi)
    Vérifie les locks git via commentaires récents
    #>

    param(
        [string]$AgentType,
        [string]$MachineId
    )

    # Vérifier que gh CLI est disponible
    $GhPath = Get-Command gh -ErrorAction SilentlyContinue
    if (-not $GhPath) {
        Write-Log "gh CLI non disponible → skip GitHub" "WARN"
        return $null
    }

    try {
        # Lister issues avec label roo-schedulable
        $IssuesJson = & gh issue list --repo jsboige/roo-extensions `
            --state open --label roo-schedulable `
            --limit 10 --json number,title,body,assignees 2>&1

        if ($LASTEXITCODE -ne 0) {
            Write-Log "Erreur gh issue list: $IssuesJson" "WARN"
            return $null
        }

        $Issues = $IssuesJson | ConvertFrom-Json

        if ($Issues.Count -eq 0) {
            Write-Log "Aucune issue roo-schedulable ouverte"
            return $null
        }

        Write-Log "Issues roo-schedulable trouvées: $($Issues.Count)"

        # Filtrer par Agent et disponibilité
        foreach ($Issue in $Issues) {
            $IssueNum = $Issue.number
            $Body = $Issue.body

            # Vérifier si déjà assignée à une autre machine
            if ($Issue.assignees.Count -gt 0) {
                Write-Log "  #$IssueNum : Déjà assignée → skip"
                continue
            }

            # Vérifier champ Agent dans le body
            $AgentMatch = $Body -match "(?i)agent:\s*(claude code|claude|both|any)"
            if (-not $AgentMatch -and $AgentType -eq "claude") {
                Write-Log "  #$IssueNum : Pas pour Claude → skip"
                continue
            }

            # Vérifier locks git via commentaires récents
            $IsLocked = Test-GitHubIssueLock -IssueNumber $IssueNum
            if ($IsLocked) {
                Write-Log "  #$IssueNum : Verrouillée par autre agent → skip"
                continue
            }

            # Issue disponible !
            Write-Log "  ✅ #$IssueNum : Disponible pour $AgentType"

            return @{
                id = "github-$IssueNum"
                subject = $Issue.title
                priority = "MEDIUM"  # GitHub issues = priorité moyenne
                prompt = $Body
                source = "github"
                issueNumber = $IssueNum
            }
        }

        Write-Log "Aucune issue GitHub disponible après filtrage"
        return $null
    }
    catch {
        Write-Log "Erreur Get-GitHubTask: $_" "ERROR"
        return $null
    }
}

function Test-GitHubIssueLock {
    <#
    .SYNOPSIS
    Vérifie si une issue est verrouillée par un autre agent (protocole git)

    .DESCRIPTION
    Lit les 3 derniers commentaires de l'issue
    Cherche les patterns "LOCK:" ou "Claimed by" récents (<5 min)
    #>

    param([int]$IssueNumber)

    try {
        # Récupérer les 3 derniers commentaires
        $CommentsJson = & gh issue view $IssueNumber --repo jsboige/roo-extensions `
            --json comments --jq '.comments[-3:]' 2>&1

        if ($LASTEXITCODE -ne 0) {
            Write-Log "Erreur lecture commentaires #$IssueNumber" "WARN"
            return $false
        }

        $Comments = $CommentsJson | ConvertFrom-Json

        foreach ($Comment in $Comments) {
            $Body = $Comment.body
            $CreatedAt = [DateTime]::Parse($Comment.createdAt)
            $Age = (Get-Date).ToUniversalTime() - $CreatedAt.ToUniversalTime()

            # LOCK: actif si < 5 minutes
            if ($Body -match "LOCK:" -and $Age.TotalMinutes -lt 5) {
                Write-Log "  Lock détecté (il y a $([math]::Round($Age.TotalMinutes, 1)) min)"
                return $true
            }

            # Claimed by: actif si < 5 minutes
            if ($Body -match "Claimed by" -and $Age.TotalMinutes -lt 5) {
                Write-Log "  Claimed détecté (il y a $([math]::Round($Age.TotalMinutes, 1)) min)"
                return $true
            }
        }

        return $false
    }
    catch {
        Write-Log "Erreur Test-GitHubIssueLock: $_" "WARN"
        return $false  # En cas d'erreur, ne pas bloquer
    }
}

function Claim-GitHubIssue {
    <#
    .SYNOPSIS
    Revendique une issue GitHub (protocole git - premier arrivé)

    .DESCRIPTION
    Ajoute un commentaire "Claimed by {agent} on {machine}"
    #>

    param(
        [int]$IssueNumber,
        [string]$AgentType,
        [string]$MachineId
    )

    try {
        $Timestamp = Get-Date -Format "o"
        $Body = "Claimed by $AgentType on $MachineId at $Timestamp"

        & gh issue comment $IssueNumber --repo jsboige/roo-extensions --body $Body 2>&1 | Out-Null

        if ($LASTEXITCODE -eq 0) {
            Write-Log "✅ Issue #$IssueNumber claimed"
        }
        else {
            Write-Log "⚠️ Erreur claim issue #$IssueNumber" "WARN"
        }
    }
    catch {
        Write-Log "Erreur Claim-GitHubIssue: $_" "WARN"
    }
}

# =============================================================================
# PRIORITÉ 3 : Fallback Maintenance
# =============================================================================

function Get-FallbackTask {
    <#
    .SYNOPSIS
    Retourne une tâche de maintenance par défaut si aucune tâche RooSync/GitHub
    #>

    return @{
        id = "fallback-maintenance"
        subject = "Maintenance quotidienne (fallback)"
        priority = "LOW"
        prompt = "Exécute les tâches de maintenance :`n1. Vérifier build : cd mcps/internal/servers/roo-state-manager && npm run build`n2. Vérifier tests : npx vitest run`n3. Reporter résultats dans INTERCOM local"
        source = "fallback"
    }
}

# =============================================================================
# POST-TRAITEMENT : Marquer comme lu/done
# =============================================================================

function Mark-TaskAsComplete {
    <#
    .SYNOPSIS
    Marque une tâche comme complétée selon sa source
    #>

    param($Task)

    switch ($Task.source) {
        "roosync" {
            if ($Task.messageFile -and (Test-Path $Task.messageFile)) {
                Mark-RooSyncMessageAsRead -MessageFile $Task.messageFile
            }
        }
        "github" {
            if ($Task.issueNumber) {
                Comment-GitHubIssue -IssueNumber $Task.issueNumber -Status "Done"
            }
        }
        "fallback" {
            # Rien à marquer
        }
    }
}

function Mark-RooSyncMessageAsRead {
    param([string]$MessageFile)

    try {
        $Message = Get-Content $MessageFile -Raw | ConvertFrom-Json
        $Message.status = "read"

        # Sauvegarder (UTF-8 sans BOM)
        $JsonText = $Message | ConvertTo-Json -Depth 10
        [System.IO.File]::WriteAllText($MessageFile, $JsonText, [System.Text.UTF8Encoding]::new($false))

        Write-Log "✅ Message RooSync marqué comme lu: $($Message.id)"
    }
    catch {
        Write-Log "Erreur Mark-RooSyncMessageAsRead: $_" "ERROR"
    }
}

function Comment-GitHubIssue {
    param(
        [int]$IssueNumber,
        [string]$Status,
        [string]$Mode = "N/A",
        [string]$CommitHash = "N/A"
    )

    try {
        $MachineId = $env:COMPUTERNAME.ToLower()
        $Timestamp = Get-Date -Format "o"

        $Body = @"
Executed by Claude Code scheduler on $MachineId at $Timestamp

**Status:** $Status
**Mode:** $Mode
**Commit:** $CommitHash
"@

        & gh issue comment $IssueNumber --repo jsboige/roo-extensions --body $Body 2>&1 | Out-Null

        if ($LASTEXITCODE -eq 0) {
            Write-Log "✅ Commentaire ajouté sur #$IssueNumber"
        }
    }
    catch {
        Write-Log "Erreur Comment-GitHubIssue: $_" "WARN"
    }
}

# =============================================================================
# EXPORT DES FONCTIONS
# =============================================================================

Export-ModuleMember -Function @(
    'Get-NextTask',
    'Get-RooSyncTask',
    'Get-GitHubTask',
    'Get-FallbackTask',
    'Test-GitHubIssueLock',
    'Claim-GitHubIssue',
    'Mark-TaskAsComplete',
    'Mark-RooSyncMessageAsRead',
    'Comment-GitHubIssue'
)
