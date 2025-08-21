#Requires -Version 5.1
[CmdletBinding()]
param (
)

$ErrorActionPreference = "Stop"
$PSDefaultParameterValues['Out-File:Encoding'] = 'utf8'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$InformationPreference = "Continue"

function Write-Log {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Message,
        [Parameter(Mandatory = $false)]
        [string]$Level = "INFO"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logLine = "[$timestamp] [$Level] $Message"
    Write-Output $logLine
    Add-Content -Path $logFilePath -Value $logLine -Encoding UTF8
}

function Start-Section {
    param([string]$Title)
    Write-Log -Message "=================================================="
    Write-Log -Message "START: $Title"
    Write-Log -Message "=================================================="
}

function End-Section {
    param([string]$Title)
    Write-Log -Message "--------------------------------------------------"
    Write-Log -Message "END: $Title"
    Write-Log -Message "--------------------------------------------------"
}

$logDir = "logs/daily-monitoring"
if (-not (Test-Path -Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force
}
$logFileName = "daily-monitoring-$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
$logFilePath = Join-Path -Path $logDir -ChildPath $logFileName
$reportFilePath = Join-Path -Path $logDir -ChildPath "health-report-$(Get-Date -Format 'yyyyMMdd_HHmmss').md"

$global:healthReport = @{
    GlobalStatus = "SUCCESS"
    Sections = @()
}

function Add-ReportSection {
    param(
        [string]$Title,
        [string]$Status,
        [string]$Details
    )
    $section = @{
        Title = $Title
        Status = $Status
        Details = $Details
    }
    $global:healthReport.Sections += $section
    if ($Status -ne "SUCCESS") {
        $global:healthReport.GlobalStatus = "WARNING"
    }
}

# --- 1. Diagnostic Git ---
Start-Section "Diagnostic Git"
$gitStatus = try {
    git status
    git branch -v
    git remote -v
    Add-ReportSection -Title "Diagnostic Git" -Status "SUCCESS" -Details "Le dépôt Git est sain."
    "SUCCESS"
} catch {
    Write-Log -Level "ERROR" -Message "Erreur lors du diagnostic Git: $($_.Exception.Message)"
    Add-ReportSection -Title "Diagnostic Git" -Status "FAILURE" -Details "Erreur lors du diagnostic Git: $($_.Exception.Message)"
    "FAILURE"
}
End-Section "Diagnostic Git"


# --- 2. Diagnostic MCP ---
Start-Section "Diagnostic MCP"
$mcpStatus = try {
    if (Test-Path -Path "roo-config/mcp-diagnostic-repair.ps1") {
        & "roo-config/mcp-diagnostic-repair.ps1" -Validate
        Add-ReportSection -Title "Diagnostic MCP" -Status "SUCCESS" -Details "Le diagnostic MCP s'est terminé avec succès."
    } else {
        throw "Le script mcp-diagnostic-repair.ps1 est introuvable."
    }
    "SUCCESS"
} catch {
    Write-Log -Level "ERROR" -Message "Erreur lors du diagnostic MCP: $($_.Exception.Message)"
    Add-ReportSection -Title "Diagnostic MCP" -Status "FAILURE" -Details "Erreur lors du diagnostic MCP: $($_.Exception.Message)"
    "FAILURE"
}
End-Section "Diagnostic MCP"


# --- 3. Validation des configurations ---
Start-Section "Validation des configurations"
$configFiles = @(
    "roo-config/settings/settings.json",
    "roo-config/settings/servers.json",
    "roo-config/modes/modes.json",
    "roo-config/scheduler/schedules.json"
)
$configStatus = "SUCCESS"
foreach ($file in $configFiles) {
    try {
        if (Test-Path $file) {
            Get-Content $file | ConvertFrom-Json | Out-Null
            Write-Log "Fichier de configuration valide: $file"
        } else {
            throw "Fichier de configuration manquant: $file"
        }
    } catch {
        Write-Log -Level "ERROR" -Message "Erreur de validation pour le fichier '$file': $($_.Exception.Message)"
        $configStatus = "FAILURE"
    }
}
if ($configStatus -eq "SUCCESS") {
    Add-ReportSection -Title "Validation des configurations" -Status "SUCCESS" -Details "Tous les fichiers de configuration sont valides."
} else {
    Add-ReportSection -Title "Validation des configurations" -Status "FAILURE" -Details "Un ou plusieurs fichiers de configuration sont invalides ou manquants."
}
End-Section "Validation des configurations"


# --- 4. Nettoyage et maintenance ---
Start-Section "Nettoyage et maintenance"
$maintenanceStatus = try {
    if (Test-Path -Path "roo-config/maintenance-routine.ps1") {
        & "roo-config/maintenance-routine.ps1"
        Add-ReportSection -Title "Nettoyage et maintenance" -Status "SUCCESS" -Details "La routine de maintenance s'est terminée avec succès."
    } else {
        throw "Le script maintenance-routine.ps1 est introuvable."
    }
    "SUCCESS"
} catch {
    Write-Log -Level "ERROR" -Message "Erreur lors de la maintenance: $($_.Exception.Message)"
    Add-ReportSection -Title "Nettoyage et maintenance" -Status "FAILURE" -Details "Erreur lors de la maintenance: $($_.Exception.Message)"
    "FAILURE"
}
End-Section "Nettoyage et maintenance"


# --- 5. Vérification d'intégrité système ---
Start-Section "Vérification d'intégrité système"
$systemHealth = "SUCCESS"
$details = ""
# Espace disque
try {
    $disk = Get-PSDrive C
    $freeSpaceGB = [math]::Round($disk.Free / 1GB, 2)
    $details += "Espace disque disponible (C:): $freeSpaceGB GB`n"
} catch {
    $systemHealth = "WARNING"
    $details += "Impossible de vérifier l'espace disque.`n"
}
# Connectivité réseau
try {
    Test-NetConnection -ComputerName github.com -InformationLevel Quiet
    $details += "Connectivité à GitHub: OK`n"
} catch {
    $systemHealth = "WARNING"
    $details += "Connectivité à GitHub: ECHEC`n"
}
Add-ReportSection -Title "Vérification d'intégrité système" -Status $systemHealth -Details $details
End-Section "Vérification d'intégrité système"

# --- 6. Génération de rapport ---
Start-Section "Génération de rapport"
$reportContent = "# Rapport de Santé - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n`n"
$reportContent += "**Statut Global: $($global:healthReport.GlobalStatus)**`n`n"
foreach ($section in $global:healthReport.Sections) {
    $reportContent += "## $($section.Title)`n"
    $reportContent += "- **Statut:** $($section.Status)`n"
    $reportContent += "- **Détails:**`n"
    $reportContent += "$($section.Details | Out-String)`n`n"
}

try {
    Set-Content -Path $reportFilePath -Value $reportContent -Encoding UTF8
    Write-Log "Rapport de santé généré: $reportFilePath"
} catch {
    Write-Log -Level "ERROR" -Message "Impossible de générer le rapport de santé: $($_.Exception.Message)"
}
Write-Log "Logs complets disponibles ici: $logFilePath"
End-Section "Génération de rapport"

Write-Output "Surveillance quotidienne terminée. Rapport généré: $reportFilePath"