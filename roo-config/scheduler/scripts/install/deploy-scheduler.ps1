# ============================================================================
# Script de Déploiement/Désactivation du RooScheduler
# Version: 1.0.0
# Description: Configure le scheduler pour la machine locale
# ============================================================================

param(
    [Parameter(Mandatory = $false)]
    [ValidateSet("deploy", "disable", "status", "test")]
    [string]$Action = "status",

    [Parameter(Mandatory = $false)]
    [string]$BasePath = ""  # Auto-détecté si vide
)

# Auto-détection du chemin racine
if (-not $BasePath) {
    $BasePath = (Resolve-Path (Join-Path $PSScriptRoot "..\..\")).Path.TrimEnd('\', '/')
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

        # Supprimer la note du template
        $json = $content | ConvertFrom-Json
        if ($json._template_note) {
            $json.PSObject.Properties.Remove('_template_note')
        }

        # Sauvegarder
        $json | ConvertTo-Json -Depth 10 | Set-Content $SchedulesPath -Encoding UTF8

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
    Write-Log "=== DÉSACTIVATION DU ROOSCHEDULE ===" "INFO"

    if (-not (Test-Path $SchedulesPath)) {
        Write-Log "Aucun scheduler actif à désactiver" "WARN"
        return $true
    }

    try {
        # Lire et désactiver
        $json = Get-Content $SchedulesPath -Raw | ConvertFrom-Json

        foreach ($schedule in $json.schedules) {
            $schedule.enabled = $false
        }

        $json | ConvertTo-Json -Depth 10 | Set-Content $SchedulesPath -Encoding UTF8

        Write-Log "Scheduler désactivé pour: $MachineName" "SUCCESS"
        return $true
    }
    catch {
        Write-Log "Erreur lors de la désactivation: $($_.Exception.Message)" "ERROR"
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
                $status = if ($schedule.enabled) { "ACTIF" } else { "DÉSACTIVÉ" }
                $statusColor = if ($schedule.enabled) { "SUCCESS" } else { "WARN" }
                Write-Log "  - $($schedule.name): $status" $statusColor
                Write-Log "    Trigger: $($schedule.trigger.type) @ $($schedule.trigger.time)" "INFO"
            }
        }
        catch {
            Write-Log "Erreur de lecture: $($_.Exception.Message)" "ERROR"
        }
    } else {
        Write-Log "✗ Scheduler non configuré (schedules.json absent)" "WARN"
        Write-Log "  Exécutez: .\deploy-scheduler.ps1 -Action deploy" "INFO"
    }

    # Vérifier le moteur d'orchestration
    $enginePath = Join-Path $BasePath "roo-config/scheduler/orchestration-engine.ps1"
    if (Test-Path $enginePath) {
        Write-Log "✓ Moteur d'orchestration présent" "SUCCESS"
    } else {
        Write-Log "✗ Moteur d'orchestration manquant" "ERROR"
    }
}

function Test-Scheduler {
    Write-Log "=== TEST DU ROOSCHEDULE ===" "INFO"

    $enginePath = Join-Path $BasePath "roo-config/scheduler/orchestration-engine.ps1"

    if (-not (Test-Path $enginePath)) {
        Write-Log "Moteur d'orchestration non trouvé" "ERROR"
        return $false
    }

    Write-Log "Exécution du test DryRun..."

    try {
        $output = & pwsh -NoProfile -File $enginePath -DryRun 2>&1
        $exitCode = $LASTEXITCODE

        # Chercher le résultat
        $success = $output | Select-String "Phases réussies: 5"

        if ($success) {
            Write-Log "✓ Test réussi: 5/5 phases" "SUCCESS"
            return $true
        } else {
            Write-Log "✗ Test échoué" "ERROR"
            $output | ForEach-Object { Write-Host $_ }
            return $false
        }
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
        $result = Disable-Scheduler
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

Usage: .\deploy-scheduler.ps1 -Action <action>

Actions:
  deploy   - Déploie le scheduler pour cette machine
  disable  - Désactive le scheduler
  status   - Affiche le statut actuel (défaut)
  test     - Exécute un test DryRun

Exemples:
  .\deploy-scheduler.ps1                    # Affiche le statut
  .\deploy-scheduler.ps1 -Action deploy     # Déploie le scheduler
  .\deploy-scheduler.ps1 -Action test       # Teste le scheduler
  .\deploy-scheduler.ps1 -Action disable    # Désactive le scheduler

"@
        exit 1
    }
}
