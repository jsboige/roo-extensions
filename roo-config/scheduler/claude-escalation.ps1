<#
.SYNOPSIS
    Module d'escalade vers Claude Code pour RooScheduler
.DESCRIPTION
    Implémente le Level 3 de l'escalation : notification de Claude Code via INTERCOM
    en cas d'échec critique dans l'orchestration automatique
.VERSION
    1.0.0
.CREATED
    2026-01-21
#>

# ============================================================================
# CONFIGURATION
# ============================================================================

$script:IntercomPath = ".claude/local/INTERCOM-$($env:COMPUTERNAME.ToLower()).md"
$script:EscalationLogPath = "roo-config/scheduler/logs/escalations-$(Get-Date -Format 'yyyyMM').json"

# ============================================================================
# FONCTIONS D'ESCALADE
# ============================================================================

function Test-CriticalPhaseFailure {
    <#
    .SYNOPSIS
        Détermine si un échec nécessite une escalade Level 3
    .PARAMETER ExecutionResult
        Résultat de l'exécution de l'orchestration
    .OUTPUTS
        Boolean - $true si escalade nécessaire
    #>
    param(
        [Parameter(Mandatory = $true)]
        [object]$ExecutionResult
    )

    # Critères d'escalation Level 3 :
    # 1. Status global = "failure" ou "error"
    # 2. Une phase critique a échoué
    # 3. Plus de 3 tentatives de retry sans succès

    $needsEscalation = $false
    $escalationReason = @()

    # Vérification du statut global
    if ($ExecutionResult.status -in @("failure", "error")) {
        $needsEscalation = $true
        $escalationReason += "Statut global: $($ExecutionResult.status)"
    }

    # Vérification des phases critiques
    foreach ($phaseName in $ExecutionResult.phases.Keys) {
        $phase = $ExecutionResult.phases.$phaseName

        if ($phase.status -eq "error") {
            # Charger la config pour vérifier si la phase est critique
            $config = Load-OrchestrationConfig -ConfigPath $Global:RooOrchestrationConfig.ConfigPath

            if ($config.orchestration.phases.$phaseName.critical) {
                $needsEscalation = $true
                $escalationReason += "Phase critique échouée: $phaseName"
            }
        }
    }

    # Vérification du taux d'erreurs
    if ($ExecutionResult.summary.failed_tasks -gt 3) {
        $needsEscalation = $true
        $escalationReason += "Nombre élevé de tâches échouées: $($ExecutionResult.summary.failed_tasks)"
    }

    return @{
        needs_escalation = $needsEscalation
        reasons = $escalationReason
    }
}

function Format-EscalationMessage {
    <#
    .SYNOPSIS
        Formate un message d'escalade pour INTERCOM
    .PARAMETER ExecutionResult
        Résultat de l'exécution de l'orchestration
    .PARAMETER EscalationReasons
        Raisons de l'escalation
    .OUTPUTS
        String - Message formaté pour INTERCOM
    #>
    param(
        [Parameter(Mandatory = $true)]
        [object]$ExecutionResult,

        [Parameter(Mandatory = $true)]
        [array]$EscalationReasons
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $executionId = $ExecutionResult.execution_id
    $duration = [math]::Round($ExecutionResult.total_duration_ms / 1000, 2)

    # Construction du message
    $message = @"

---

## [$timestamp] roo-scheduler → claude-code [ERROR]

**🚨 ESCALADE LEVEL 3 - Intervention Requise**

**Exécution:** $executionId
**Durée:** $duration secondes
**Statut:** $($ExecutionResult.status.ToUpper())

### Raisons de l'escalade

"@

    foreach ($reason in $EscalationReasons) {
        $message += "`n- $reason"
    }

    $message += @"


### Résumé de l'exécution

- Phases exécutées: $($ExecutionResult.summary.phases_executed)
- Phases réussies: $($ExecutionResult.summary.phases_successful)
- Phases échouées: $($ExecutionResult.summary.phases_failed)
- Tâches totales: $($ExecutionResult.summary.total_tasks)
- Tâches échouées: $($ExecutionResult.summary.failed_tasks)

### Phases en erreur

"@

    foreach ($phaseName in $ExecutionResult.phases.Keys) {
        $phase = $ExecutionResult.phases.$phaseName

        if ($phase.status -eq "error") {
            $message += @"

**$($phaseName.ToUpper())**
- Durée: $([math]::Round($phase.duration_ms / 1000, 2))s
- Erreurs:
"@
            foreach ($error in $phase.errors) {
                $message += "`n  - $error"
            }

            # Détails des tâches échouées
            $failedTasks = $phase.tasks_results | Where-Object { $_.status -eq "error" }
            if ($failedTasks) {
                $message += "`n- Tâches échouées:"
                foreach ($task in $failedTasks) {
                    $message += "`n  - $($task.name): $($task.errors -join '; ')"
                }
            }
        }
    }

    $message += @"


### Actions recommandées

1. Examiner les logs détaillés dans: ``roo-config/scheduler/logs/``
2. Vérifier l'état Git: ``git status``
3. Consulter les métriques: ``roo-config/scheduler/metrics/``
4. Exécuter un diagnostic manuel si nécessaire

### Logs

- Log principal: ``roo-config/scheduler/daily-orchestration-log.json``
- Escalation log: ``$EscalationLogPath``

**Action attendue:** Analyse de la situation et correction manuelle si nécessaire.

---

"@

    return $message
}

function Save-EscalationRecord {
    <#
    .SYNOPSIS
        Enregistre un événement d'escalation dans le log
    .PARAMETER ExecutionResult
        Résultat de l'exécution
    .PARAMETER EscalationReasons
        Raisons de l'escalation
    #>
    param(
        [Parameter(Mandatory = $true)]
        [object]$ExecutionResult,

        [Parameter(Mandatory = $true)]
        [array]$EscalationReasons
    )

    $escalationRecord = @{
        timestamp = Get-Date -Format "o"
        execution_id = $ExecutionResult.execution_id
        status = $ExecutionResult.status
        reasons = $EscalationReasons
        phases_summary = $ExecutionResult.summary
        intercom_notified = $true
    }

    try {
        # Créer le dossier de logs si nécessaire
        $logDir = Split-Path -Parent $EscalationLogPath
        if (-not (Test-Path $logDir)) {
            New-Item -ItemType Directory -Path $logDir -Force | Out-Null
        }

        # Charger ou créer le fichier de log
        $escalationLog = @{
            month = Get-Date -Format "yyyy-MM"
            escalations = @()
        }

        if (Test-Path $EscalationLogPath) {
            $escalationLog = Get-Content -Raw $EscalationLogPath | ConvertFrom-Json
        }

        # Ajouter le nouvel enregistrement
        $escalationLog.escalations += $escalationRecord

        # Sauvegarder
        $escalationLog | ConvertTo-Json -Depth 10 | Set-Content -Path $EscalationLogPath

        Write-OrchestrationLog "Escalation enregistrée dans: $EscalationLogPath" -Level "INFO"
    }
    catch {
        Write-OrchestrationLog "Erreur lors de l'enregistrement de l'escalation: $($_.Exception.Message)" -Level "ERROR"
    }
}

function Invoke-ClaudeEscalation {
    <#
    .SYNOPSIS
        Déclenche une escalation Level 3 vers Claude Code
    .DESCRIPTION
        Invoque Claude Code directement via 'claude -p' pour intervention immédiate
        en cas d'échec critique de l'orchestration automatique.
        Écrit également dans INTERCOM pour traçabilité.
    .PARAMETER ExecutionResult
        Résultat de l'exécution de l'orchestration
    .OUTPUTS
        Boolean - $true si escalation réussie
    #>
    param(
        [Parameter(Mandatory = $true)]
        [object]$ExecutionResult
    )

    Write-OrchestrationLog "=== DÉCLENCHEMENT ESCALADE LEVEL 3 ===" -Level "WARN"

    try {
        # 1. Vérifier si l'escalation est nécessaire
        $escalationCheck = Test-CriticalPhaseFailure -ExecutionResult $ExecutionResult

        if (-not $escalationCheck.needs_escalation) {
            Write-OrchestrationLog "Escalation non nécessaire - erreurs non critiques" -Level "INFO"
            return $false
        }

        Write-OrchestrationLog "Escalation nécessaire. Raisons: $($escalationCheck.reasons -join ', ')" -Level "WARN"

        # 2. Enregistrer l'événement d'escalation AVANT d'invoquer Claude
        Save-EscalationRecord -ExecutionResult $ExecutionResult -EscalationReasons $escalationCheck.reasons

        # 3. Écrire dans INTERCOM pour traçabilité
        $escalationMessage = Format-EscalationMessage `
            -ExecutionResult $ExecutionResult `
            -EscalationReasons $escalationCheck.reasons

        if (-not (Test-Path $IntercomPath)) {
            $intercomDir = Split-Path -Parent $IntercomPath
            if (-not (Test-Path $intercomDir)) {
                New-Item -ItemType Directory -Path $intercomDir -Force | Out-Null
            }

            $header = @"
# INTERCOM - Communication Locale Roo ↔ Claude Code
# Machine: $($env:COMPUTERNAME.ToLower())
# Protocole: v2.0

"@
            $header | Set-Content -Path $IntercomPath
        }

        Add-Content -Path $IntercomPath -Value $escalationMessage
        Write-OrchestrationLog "Traçabilité INTERCOM enregistrée: $IntercomPath" -Level "INFO"

        # 4. INVOCATION DIRECTE DE CLAUDE CODE via 'claude -p'
        Write-OrchestrationLog "Invocation de Claude Code via 'claude -p'..." -Level "WARN"

        # Construire le prompt pour Claude
        $executionId = $ExecutionResult.execution_id
        $duration = [math]::Round($ExecutionResult.total_duration_ms / 1000, 2)
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

        # Identifier les phases en erreur
        $failedPhases = @()
        foreach ($phaseName in $ExecutionResult.phases.Keys) {
            $phase = $ExecutionResult.phases.$phaseName
            if ($phase.status -eq "error") {
                $failedPhases += $phaseName
            }
        }

        $claudePrompt = @"
🚨 ESCALADE LEVEL 3 - RooScheduler

L'orchestration automatique quotidienne a échoué de manière critique.

**Timestamp:** $timestamp
**Execution ID:** $executionId
**Durée:** $duration secondes
**Statut:** $($ExecutionResult.status.ToUpper())

**Raisons de l'escalation:**
$($escalationCheck.reasons -join "`n")

**Phases échouées:** $($failedPhases -join ', ')
**Tâches échouées:** $($ExecutionResult.summary.failed_tasks)/$($ExecutionResult.summary.total_tasks)

**Actions requises:**
1. Examiner les logs: roo-config/scheduler/logs/
2. Vérifier l'état Git: git status
3. Consulter INTERCOM: .claude/local/INTERCOM-$($env:COMPUTERNAME.ToLower()).md
4. Corriger les problèmes identifiés

Analyse la situation et prends les mesures correctives nécessaires.
"@

        try {
            # Lancer claude en arrière-plan pour éviter de bloquer l'orchestration
            Start-Process -FilePath "claude" -ArgumentList "-p", "`"$claudePrompt`"" -NoNewWindow -PassThru
            Write-OrchestrationLog "✅ Claude Code invoqué avec succès" -Level "INFO"
        }
        catch {
            Write-OrchestrationLog "⚠️ Échec invocation Claude (claude CLI peut ne pas être disponible): $($_.Exception.Message)" -Level "WARN"
            Write-OrchestrationLog "Fallback: Message INTERCOM disponible pour lecture manuelle" -Level "INFO"
        }

        Write-OrchestrationLog "=== ESCALATION LEVEL 3 TERMINÉE ===" -Level "WARN"
        return $true
    }
    catch {
        Write-OrchestrationLog "Erreur lors de l'escalation: $($_.Exception.Message)" -Level "ERROR"
        return $false
    }
}

# ============================================================================
# FONCTIONS EXPORTÉES (via dot-sourcing)
# ============================================================================
# Ce fichier est chargé via dot-sourcing (.), pas comme module.
# Les fonctions suivantes sont disponibles après chargement :
# - Invoke-ClaudeEscalation
# - Test-CriticalPhaseFailure
# - Format-EscalationMessage
# - Save-EscalationRecord
