# ============================================================================
# Script de Déploiement/Désactivation du RooScheduler
# Version: 1.0.0
# Description: Configure le scheduler pour la machine locale
# ============================================================================

param(
    [Parameter(Mandatory = $false)]
    [ValidateSet("deploy", "disable", "enable", "status", "test")]
    [string]$Action = "status",

    [Parameter(Mandatory = $false)]
    [string]$Schedule = "",  # Nom EXACT d'une cadence : enable/disable d'une seule cadence (vide = toutes)

    [Parameter(Mandatory = $false)]
    [string]$BasePath = ""  # Auto-détecté si vide
)

# Auto-détection du chemin racine
if (-not $BasePath) {
    $BasePath = (Resolve-Path (Join-Path $PSScriptRoot "..\..\..\..\")).Path.TrimEnd('\', '/')
}

$MachineName = $env:COMPUTERNAME.ToLower()
$TemplatePath = Join-Path $BasePath ".roo/schedules.template.json"
$SchedulesPath = Join-Path $BasePath ".roo/schedules.json"

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $color = switch ($Level) {
        "INFO" { "White" }
        "SUCCESS" { "Green" }
        "WARN" { "Yellow" }
        "ERROR" { "Red" }
        default { "White" }
    }
    Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $color
}

function Deploy-Scheduler {
    Write-Log "=== DÉPLOIEMENT DU ROOSCHEDULE ===" "INFO"
    Write-Log "Machine: $MachineName"
    Write-Log "BasePath: $BasePath"

    # Vérifier le template
    if (-not (Test-Path $TemplatePath)) {
        Write-Log "Template non trouvé: $TemplatePath" "ERROR"
        Write-Log "Exécutez 'git pull' pour récupérer le template" "ERROR"
        return $false
    }

    # Lire et personnaliser le template
    try {
        $content = Get-Content $TemplatePath -Raw

        # Remplacer les variables
        $content = $content -replace '\$\{MACHINE_NAME\}', $MachineName

        # Choisir le workflow selon le role (coordinateur vs executeur)
        $workflowFile = if ($MachineName -eq "myia-ai-01") {
            "scheduler-workflow-coordinator.md"
        } else {
            "scheduler-workflow-executor.md"
        }
        $content = $content -replace '\$\{WORKFLOW_FILE\}', $workflowFile
        Write-Log "Workflow: $workflowFile (role: $(if ($MachineName -eq 'myia-ai-01') {'coordinateur'} else {'executeur'}))"

        # Générer des IDs uniques basés sur le timestamp
        $uniqueId = [DateTimeOffset]::Now.ToUnixTimeMilliseconds().ToString()
        # Replace TEMPLATE_META_ID first (more specific) to avoid partial match
        $content = $content -replace 'TEMPLATE_META_ID', ($uniqueId + "1")
        $content = $content -replace 'TEMPLATE_ID', $uniqueId

        # Parser et nettoyer
        $json = $content | ConvertFrom-Json

        # Supprimer les notes du template
        foreach ($schedule in $json.schedules) {
            if ($schedule.PSObject.Properties['_template_note']) {
                $schedule.PSObject.Properties.Remove('_template_note')
            }
            if ($schedule.PSObject.Properties['_template_note_meta']) {
                $schedule.PSObject.Properties.Remove('_template_note_meta')
            }
        }

        # Sauvegarder (UTF8 sans BOM pour compatibilite Roo Scheduler)
        $utf8NoBom = New-Object System.Text.UTF8Encoding $false
        $jsonText = $json | ConvertTo-Json -Depth 10
        [System.IO.File]::WriteAllText($SchedulesPath, $jsonText, $utf8NoBom)

        Write-Log "Fichier créé: $SchedulesPath" "SUCCESS"
        Write-Log "Configuration personnalisée pour: $MachineName" "SUCCESS"

        return $true
    }
    catch {
        Write-Log "Erreur lors du déploiement: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

function Disable-Scheduler {
    param([string]$ScheduleName = "")

    Write-Log "=== DÉSACTIVATION DU ROOSCHEDULE ===" "INFO"

    if (-not (Test-Path $SchedulesPath)) {
        Write-Log "Aucun scheduler actif à désactiver" "WARN"
        return $true
    }

    try {
        # Lire et désactiver
        $json = Get-Content $SchedulesPath -Raw | ConvertFrom-Json

        $targets = $json.schedules
        if ($ScheduleName) {
            $targets = @($json.schedules | Where-Object { $_.name -eq $ScheduleName })
            if ($targets.Count -eq 0) {
                Write-Log "Aucun schedule nommé '$ScheduleName' (disponibles: $(($json.schedules | ForEach-Object { $_.name }) -join ', '))" "ERROR"
                return $false
            }
        }

        foreach ($schedule in $targets) {
            $schedule.active = $false
        }

        $utf8NoBom = New-Object System.Text.UTF8Encoding $false
        $jsonText = $json | ConvertTo-Json -Depth 10
        [System.IO.File]::WriteAllText($SchedulesPath, $jsonText, $utf8NoBom)

        Write-Log "Scheduler désactivé pour: $MachineName" "SUCCESS"
        return $true
    }
    catch {
        Write-Log "Erreur lors de la désactivation: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

function Enable-Scheduler {
    param([string]$ScheduleName = "")

    Write-Log "=== ACTIVATION DU ROOSCHEDULE ===" "INFO"

    if (-not (Test-Path $SchedulesPath)) {
        Write-Log "schedules.json introuvable: $SchedulesPath" "ERROR"
        Write-Log "Exécutez d'abord: .\deploy-scheduler.ps1 -Action deploy" "ERROR"
        return $false
    }

    try {
        # Lire et activer
        $json = Get-Content $SchedulesPath -Raw | ConvertFrom-Json

        $targets = $json.schedules
        if ($ScheduleName) {
            $targets = @($json.schedules | Where-Object { $_.name -eq $ScheduleName })
            if ($targets.Count -eq 0) {
                Write-Log "Aucun schedule nommé '$ScheduleName' (disponibles: $(($json.schedules | ForEach-Object { $_.name }) -join ', '))" "ERROR"
                return $false
            }
        }

        foreach ($schedule in $targets) {
            $schedule.active = $true
        }

        $utf8NoBom = New-Object System.Text.UTF8Encoding $false
        $jsonText = $json | ConvertTo-Json -Depth 10
        [System.IO.File]::WriteAllText($SchedulesPath, $jsonText, $utf8NoBom)

        Write-Log "Scheduler activé pour: $MachineName" "SUCCESS"
        return $true
    }
    catch {
        Write-Log "Erreur lors de l'activation: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

function Get-SchedulerStatus {
    Write-Log "=== STATUT DU ROOSCHEDULE ===" "INFO"
    Write-Log "Machine: $MachineName"
    Write-Log "BasePath: $BasePath"

    # Vérifier le template
    if (Test-Path $TemplatePath) {
        Write-Log "✓ Template présent: $TemplatePath" "SUCCESS"
    } else {
        Write-Log "✗ Template manquant: $TemplatePath" "ERROR"
    }

    # Vérifier le fichier local
    if (Test-Path $SchedulesPath) {
        Write-Log "✓ Scheduler configuré: $SchedulesPath" "SUCCESS"

        try {
            $json = Get-Content $SchedulesPath -Raw | ConvertFrom-Json

            foreach ($schedule in $json.schedules) {
                $status = if ($schedule.active) { "ACTIF" } else { "DÉSACTIVÉ" }
                $statusColor = if ($schedule.active) { "SUCCESS" } else { "WARN" }
                Write-Log "  - $($schedule.name): $status" $statusColor
                Write-Log "    Mode: $($schedule.mode), Interval: $($schedule.timeInterval)min" "INFO"
            }
        }
        catch {
            Write-Log "Erreur de lecture: $($_.Exception.Message)" "ERROR"
        }
    } else {
        Write-Log "✗ Scheduler non configuré (schedules.json absent)" "WARN"
        Write-Log "  Exécutez: .\deploy-scheduler.ps1 -Action deploy" "INFO"
    }

    # Vérifier l'extension Roo Scheduler
    $extensionDir = Join-Path $env:USERPROFILE ".vscode/extensions"
    $schedulerExt = Get-ChildItem -Path $extensionDir -Filter "kylehoskins.roo-scheduler-*" -Directory -ErrorAction SilentlyContinue
    if ($schedulerExt) {
        Write-Log "Roo Scheduler extension: $($schedulerExt.Name)" "SUCCESS"
    } else {
        Write-Log "Roo Scheduler extension non trouvee - installer via VS Code" "WARN"
    }
}

function Test-Scheduler {
    Write-Log "=== TEST DU ROOSCHEDULE ===" "INFO"

    if (-not (Test-Path $SchedulesPath)) {
        Write-Log "schedules.json non trouve - deployer d'abord" "ERROR"
        return $false
    }

    Write-Log "Verification de la configuration..."

    try {
        $json = Get-Content $SchedulesPath -Raw | ConvertFrom-Json

        $ok = $true
        foreach ($schedule in $json.schedules) {
            # Verifier ID unique (pas TEMPLATE_ID ou TEMPLATE_META_ID)
            if ($schedule.id -eq "TEMPLATE_ID" -or $schedule.id -eq "TEMPLATE_META_ID") {
                Write-Log "ID non remplace (encore $($schedule.id))" "ERROR"
                $ok = $false
            } else {
                Write-Log "ID: $($schedule.id) ($($schedule.name))" "SUCCESS"
            }

            # Verifier que les variables de template sont remplacees
            if ($schedule.taskInstructions -match '\$\{MACHINE_NAME\}' -or $schedule.taskInstructions -match '\$\{WORKFLOW_FILE\}') {
                Write-Log "Variables de template non remplacees dans taskInstructions" "ERROR"
                $ok = $false
            } else {
                Write-Log "taskInstructions: variables de template remplacees" "SUCCESS"
            }

            # Verifier active
            if ($schedule.active) {
                Write-Log "Schedule actif: $($schedule.name)" "SUCCESS"
            } else {
                Write-Log "Schedule inactif: $($schedule.name)" "WARN"
            }

            # Verifier pas de _template_note
            if ($schedule.PSObject.Properties['_template_note']) {
                Write-Log "_template_note presente (devrait etre retiree)" "WARN"
                $ok = $false
            }
        }

        if ($ok) {
            Write-Log "Configuration valide" "SUCCESS"
        } else {
            Write-Log "Configuration avec problemes - re-deployer" "WARN"
        }

        return $ok
    }
    catch {
        Write-Log "Erreur lors du test: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

# === MAIN ===

switch ($Action.ToLower()) {
    "deploy" {
        $result = Deploy-Scheduler
        if ($result) {
            Write-Log ""
            Write-Log "Prochaine étape: Testez avec" "INFO"
            Write-Log "  .\deploy-scheduler.ps1 -Action test" "INFO"
        }
        exit $(if ($result) { 0 } else { 1 })
    }

    "disable" {
        $result = Disable-Scheduler -ScheduleName $Schedule
        exit $(if ($result) { 0 } else { 1 })
    }

    "enable" {
        $result = Enable-Scheduler -ScheduleName $Schedule
        exit $(if ($result) { 0 } else { 1 })
    }

    "status" {
        Get-SchedulerStatus
        exit 0
    }

    "test" {
        $result = Test-Scheduler
        exit $(if ($result) { 0 } else { 1 })
    }

    default {
        Write-Log "Action non reconnue: $Action" "ERROR"
        Write-Host @"

Usage: .\deploy-scheduler.ps1 -Action <action> [-Schedule <nom>]

Actions:
  deploy   - Déploie le scheduler pour cette machine
  disable  - Désactive le scheduler (toutes les cadences, ou une seule avec -Schedule)
  enable   - Active le scheduler (toutes les cadences, ou une seule avec -Schedule)
  status   - Affiche le statut actuel (défaut)
  test     - Exécute un test DryRun

Exemples:
  .\deploy-scheduler.ps1                    # Affiche le statut
  .\deploy-scheduler.ps1 -Action deploy     # Déploie le scheduler
  .\deploy-scheduler.ps1 -Action test       # Teste le scheduler
  .\deploy-scheduler.ps1 -Action disable    # Désactive toutes les cadences
  .\deploy-scheduler.ps1 -Action enable -Schedule "Claude-Code Assistant"  # Active UNE cadence

-Schedule prend le nom EXACT d'une cadence du fichier (voir -Action status).
Une cadence inconnue échoue sans rien modifier.

"@
        exit 1
    }
}
