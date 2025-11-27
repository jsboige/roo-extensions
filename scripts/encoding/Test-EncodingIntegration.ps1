<#
.SYNOPSIS
    Orchestrateur des tests d'intégration de l'architecture d'encodage.
.DESCRIPTION
    Ce script exécute la suite complète de tests pour valider l'architecture d'encodage unifiée.
    Il intègre :
    1. Validation de l'environnement standardisé (Test-StandardizedEnvironment.ps1)
    2. Validation des profils PowerShell (Test-PowerShellProfiles.ps1)
    3. Validation de la configuration VSCode (Validate-VSCodeConfig.ps1)
    4. Tests d'intégration cross-composants (Test-CrossComponentIntegration.ps1)
.EXAMPLE
    .\Test-EncodingIntegration.ps1
.NOTES
    Auteur: Roo Architect
    Date: 2025-11-26
    ID Tâche: SDDD-T002c
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [switch]$GenerateReport
)

# Configuration
$LogFile = "logs\Test-EncodingIntegration-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
$ReportFile = "reports\encoding-integration-test-report.md"
$ScriptsDir = "scripts\encoding"

# Fonctions de logging
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    Write-Host $logEntry -ForegroundColor $(switch ($Level) { "ERROR" { "Red" } "WARN" { "Yellow" } "SUCCESS" { "Green" } default { "Cyan" } })
    if (!(Test-Path "logs")) { New-Item -ItemType Directory -Path "logs" -Force | Out-Null }
    Add-Content -Path $LogFile -Value $logEntry -Encoding UTF8
}

function Invoke-TestScript {
    param(
        [string]$ScriptName,
        [string]$Description
    )
    
    Write-Log "--- Exécution de $ScriptName ($Description) ---" "INFO"
    $scriptPath = Join-Path $ScriptsDir $ScriptName
    
    if (!(Test-Path $scriptPath)) {
        Write-Log "Script introuvable: $scriptPath" "ERROR"
        return $false
    }
    
    $startTime = Get-Date
    try {
        # Exécution du script
        # On utilise Invoke-Expression ou & pour exécuter le script
        # On capture la sortie pour le rapport si nécessaire
        
        # Pour Test-StandardizedEnvironment, on peut passer des arguments
        if ($ScriptName -eq "Test-StandardizedEnvironment.ps1") {
            & $scriptPath -Detailed
        } else {
            & $scriptPath
        }
        
        $exitCode = $LASTEXITCODE
        $duration = (Get-Date) - $startTime
        
        if ($exitCode -eq 0) {
            Write-Log "✅ $ScriptName terminé avec succès (Durée: $($duration.TotalSeconds.ToString('N2'))s)" "SUCCESS"
            return $true
        } else {
            Write-Log "❌ $ScriptName a échoué (Code: $exitCode)" "ERROR"
            return $false
        }
    } catch {
        $errorMsg = $_.Exception.Message
        Write-Log "Exception lors de l'exécution de ${ScriptName}: $errorMsg" "ERROR"
        return $false
    }
}

# Initialisation
Write-Log "Début de la suite de tests d'intégration..." "INFO"
$results = @{}

# 1. Test Environnement
$results["Environment"] = Invoke-TestScript "Test-StandardizedEnvironment.ps1" "Validation Environnement Standardisé"

# 2. Test Profils PowerShell
$results["PowerShellProfiles"] = Invoke-TestScript "Test-PowerShellProfiles.ps1" "Validation Profils PowerShell"

# 3. Test VSCode Config
$results["VSCodeConfig"] = Invoke-TestScript "Validate-VSCodeConfig.ps1" "Validation Configuration VSCode"

# 4. Test Cross-Composants
$results["CrossComponent"] = Invoke-TestScript "Test-CrossComponentIntegration.ps1" "Tests Intégration Cross-Composants"

# Synthèse
Write-Log "--- Synthèse des Résultats ---" "INFO"
$successCount = 0
$totalCount = $results.Count

foreach ($key in $results.Keys) {
    $status = if ($results[$key]) { "SUCCÈS" } else { "ÉCHEC" }
    $icon = if ($results[$key]) { "✅" } else { "❌" }
    Write-Log "$icon $key : $status" $(if ($results[$key]) { "SUCCESS" } else { "ERROR" })
    if ($results[$key]) { $successCount++ }
}

$successRate = ($successCount / $totalCount) * 100
Write-Log "Taux de succès global: $($successRate.ToString('N0'))%" "INFO"

if ($GenerateReport) {
    Write-Log "Génération du rapport dans $ReportFile..." "INFO"
    
    $reportContent = @"
# Rapport de Tests d'Intégration - Architecture d'Encodage

**Date**: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
**Taux de Succès**: $($successRate.ToString('N0'))% ($successCount/$totalCount)

## Détail des Tests

| Composant | Statut | Description |
|-----------|--------|-------------|
| Environnement | $(if ($results["Environment"]) { "✅ SUCCÈS" } else { "❌ ÉCHEC" }) | Validation des variables d'environnement et du registre |
| Profils PowerShell | $(if ($results["PowerShellProfiles"]) { "✅ SUCCÈS" } else { "❌ ÉCHEC" }) | Chargement et configuration des profils |
| VSCode Config | $(if ($results["VSCodeConfig"]) { "✅ SUCCÈS" } else { "❌ ÉCHEC" }) | Configuration settings.json |
| Cross-Composants | $(if ($results["CrossComponent"]) { "✅ SUCCÈS" } else { "❌ ÉCHEC" }) | Interactions PowerShell <-> Node.js <-> Python |

## Logs d'Exécution

Voir le fichier de log complet: $LogFile
"@
    
    if (!(Test-Path "reports")) { New-Item -ItemType Directory -Path "reports" -Force | Out-Null }
    $reportContent | Out-File -FilePath $ReportFile -Encoding UTF8
    Write-Log "Rapport généré." "SUCCESS"
}

if ($successCount -eq $totalCount) {
    exit 0
} else {
    exit 1
}