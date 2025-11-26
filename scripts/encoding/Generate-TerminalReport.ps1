<#
.SYNOPSIS
    Génère un rapport de compatibilité des terminaux pour le support UTF-8.
.DESCRIPTION
    Ce script collecte les informations de configuration et de test des terminaux
    et génère un rapport Markdown détaillé.
.EXAMPLE
    .\Generate-TerminalReport.ps1
.NOTES
    Auteur: Roo Architect
    Date: 2025-11-26
    ID Tâche: SDDD-T001-J5-5
#>

[CmdletBinding()]
param()

$ReportFile = "reports\terminal-compatibility-report-$(Get-Date -Format 'yyyyMMdd').md"
$LogFile = "logs\Generate-TerminalReport-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"

# Fonctions de logging
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    Write-Host $logEntry -ForegroundColor $(switch ($Level) { "ERROR" { "Red" } "WARN" { "Yellow" } "SUCCESS" { "Green" } default { "Cyan" } })
    if (!(Test-Path "logs")) { New-Item -ItemType Directory -Path "logs" -Force | Out-Null }
    Add-Content -Path $LogFile -Value $logEntry -Encoding UTF8
}

function Get-SystemInfo {
    @{
        OS = [System.Environment]::OSVersion.ToString()
        PowerShellVersion = $PSVersionTable.PSVersion.ToString()
        WindowsTerminal = if (Get-Command wt -ErrorAction SilentlyContinue) { "Installé" } else { "Non trouvé" }
        VSCode = if (Get-Command code -ErrorAction SilentlyContinue) { "Installé" } else { "Non trouvé" }
        CurrentCodePage = [Console]::OutputEncoding.CodePage
    }
}

function Run-Tests {
    Write-Log "Exécution des tests de configuration..." "INFO"
    
    # On exécute le script de test et on capture la sortie
    # Note: Test-TerminalConfiguration.ps1 doit être dans le même répertoire
    $scriptPath = Join-Path $PSScriptRoot "Test-TerminalConfiguration.ps1"
    
    if (Test-Path $scriptPath) {
        $testOutput = & $scriptPath 2>&1 | Out-String
        $lastExitCode = $LASTEXITCODE
        
        return @{
            Output = $testOutput
            Success = $lastExitCode -eq 0
        }
    } else {
        Write-Log "Script de test introuvable: $scriptPath" "ERROR"
        return @{ Output = "Script de test introuvable"; Success = $false }
    }
}

function Generate-MarkdownReport {
    param($SystemInfo, $TestResults)
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    
    $md = @"
# Rapport de Compatibilité des Terminaux UTF-8

**Date:** $timestamp
**ID Tâche:** SDDD-T001-J5-5
**Statut Global:** $(if ($TestResults.Success) { "✅ SUCCÈS" } else { "⚠️ ATTENTION" })

## 1. Informations Système

| Composant | État / Version |
|-----------|----------------|
| OS | $($SystemInfo.OS) |
| PowerShell | $($SystemInfo.PowerShellVersion) |
| Windows Terminal | $($SystemInfo.WindowsTerminal) |
| VSCode | $($SystemInfo.VSCode) |
| CodePage Actuel | $($SystemInfo.CurrentCodePage) |

## 2. Résultats des Tests

### Résumé de l'exécution
```
$($TestResults.Output)
```

## 3. Analyse de Configuration

### Windows Terminal
- **Profil par défaut:** Doit être PowerShell.
- **Police:** Doit être Cascadia Code ou Mono.
- **Rendu:** AtlasEngine doit être activé.

### VSCode
- **Terminal intégré:** Doit utiliser PowerShell par défaut.
- **Arguments:** Doit inclure `-NoExit -Command chcp 65001`.
- **Police:** Doit inclure Cascadia Code.

## 4. Recommandations

$(if (-not $TestResults.Success) {
@"
- Exécuter `scripts/encoding/Configure-WindowsTerminal.ps1` pour corriger Windows Terminal.
- Exécuter `scripts/encoding/Configure-VSCodeTerminal.ps1` pour corriger VSCode.
- Vérifier que les polices Cascadia Code sont installées.
"@
} else {
"- Aucune action requise. L'environnement est correctement configuré pour UTF-8."
})

---
*Généré automatiquement par Generate-TerminalReport.ps1*
"@
    
    return $md
}

# Main
try {
    Write-Log "Génération du rapport de compatibilité..." "INFO"
    
    if (!(Test-Path "reports")) {
        New-Item -ItemType Directory -Path "reports" -Force | Out-Null
    }
    
    $sysInfo = Get-SystemInfo
    $testResults = Run-Tests
    
    $reportContent = Generate-MarkdownReport -SystemInfo $sysInfo -TestResults $testResults
    
    $reportContent | Out-File -FilePath $ReportFile -Encoding UTF8 -Force
    
    Write-Log "Rapport généré avec succès : $ReportFile" "SUCCESS"
    
} catch {
    Write-Log "Erreur lors de la génération du rapport: $($_.Exception.Message)" "ERROR"
    exit 1
}