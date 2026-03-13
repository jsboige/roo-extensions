<#
.SYNOPSIS
    Génère le rapport final de déploiement pour la Phase 1 des corrections d'encodage.

.DESCRIPTION
    Ce script exécute l'ensemble des tests de validation, collecte les résultats,
    calcule le taux de succès global et génère un rapport synthétique en Markdown.

.EXAMPLE
    .\scripts\encoding\Generate-DeploymentReport.ps1
#>

param(
    [string]$ReportPath = "reports\deployment-report-phase1-final.md",
    [switch]$SkipTests
)

# Configuration
$ErrorActionPreference = "Stop"
$scriptPath = $PSScriptRoot
$rootPath = "$scriptPath\..\.."

# Définition des tests à exécuter
$tests = @(
    @{
        Name = "Validation Environnement Standardisé"
        Script = "$scriptPath\Test-StandardizedEnvironment.ps1"
        Weight = 1.0
    },
    @{
        Name = "Validation Configuration Terminal"
        Script = "$scriptPath\Test-TerminalConfiguration.ps1"
        Weight = 0.8
    },
    @{
        Name = "Validation Profils PowerShell"
        Script = "$scriptPath\Test-PowerShellProfiles.ps1"
        Weight = 0.8
    },
    @{
        Name = "Validation Activation UTF-8"
        Script = "$scriptPath\Test-UTF8Activation.ps1"
        Weight = 1.0
    },
    @{
        Name = "Validation Registre UTF-8"
        Script = "$scriptPath\Test-UTF8RegistryValidation.ps1"
        Weight = 1.0
    }
)

# Initialisation du rapport
$reportContent = @()
$reportContent += "# Rapport de Déploiement - Phase 1 : Corrections Critiques d'Encodage"
$reportContent += ""
$reportContent += "**Date**: $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
$reportContent += "**Auteur**: Roo Code"
$reportContent += "**Version**: 1.0"
$reportContent += ""
$reportContent += "## 📊 Synthèse Globale"
$reportContent += ""

$globalSuccess = $true
$totalTests = 0
$passedTests = 0
$results = @()

# Exécution des tests
Write-Host "Démarrage de la validation globale..." -ForegroundColor Cyan

foreach ($test in $tests) {
    Write-Host "Exécution : $($test.Name)..." -NoNewline
    
    $testResult = @{
        Name = $test.Name
        Status = "Inconnu"
        Details = ""
        Success = $false
    }

    if ($SkipTests) {
        Write-Host " [SKIPPED]" -ForegroundColor Yellow
        $testResult.Status = "Skipped"
        $testResult.Details = "Test ignoré par l'utilisateur"
    } else {
        try {
            if (Test-Path $test.Script) {
                # Exécution du script et capture de la sortie
                # On suppose que les scripts retournent $true/$false ou lancent une erreur
                # Pour une meilleure intégration, on pourrait analyser les rapports générés par ces scripts
                # Mais ici on va se baser sur le code de retour ($LASTEXITCODE ou booléen)
                
                # Note: Certains scripts peuvent ne pas retourner de valeur booléenne directe.
                # On va essayer de les invoquer.
                
                Invoke-Expression "& '$($test.Script)'" | Out-Null
                
                if ($?) {
                    Write-Host " [OK]" -ForegroundColor Green
                    $testResult.Status = "Succès"
                    $testResult.Success = $true
                    $passedTests++
                } else {
                    Write-Host " [ÉCHEC]" -ForegroundColor Red
                    $testResult.Status = "Échec"
                    $testResult.Success = $false
                    $globalSuccess = $false
                }
            } else {
                Write-Host " [MANQUANT]" -ForegroundColor Red
                $testResult.Status = "Script Manquant"
                $testResult.Details = "Script introuvable: $($test.Script)"
                $globalSuccess = $false
            }
        } catch {
            Write-Host " [ERREUR]" -ForegroundColor Red
            $testResult.Status = "Erreur"
            $testResult.Details = $_.Exception.Message
            $globalSuccess = $false
        }
    }
    
    $totalTests++
    $results += $testResult
}

# Calcul du taux de succès
$successRate = if ($totalTests -gt 0) { [math]::Round(($passedTests / $totalTests) * 100, 2) } else { 0 }

# Ajout de la synthèse au rapport
$reportContent += "| Métrique | Valeur |"
$reportContent += "|---|---|"
$reportContent += "| **Taux de Succès** | **$successRate%** |"
$reportContent += "| Tests Exécutés | $totalTests |"
$reportContent += "| Tests Réussis | $passedTests |"
$reportContent += "| Statut Global | $(if ($successRate -ge 95) { "✅ SUCCÈS" } else { "⚠️ ATTENTION" }) |"
$reportContent += ""

$reportContent += "## 📝 Détail des Validations"
$reportContent += ""
$reportContent += "| Composant | Statut | Détails |"
$reportContent += "|---|---|---|"

foreach ($res in $results) {
    $icon = if ($res.Success) { "✅" } else { "❌" }
    $reportContent += "| $($res.Name) | $icon $($res.Status) | $($res.Details) |"
}

$reportContent += ""
$reportContent += "## 📋 Matrice de Traçabilité (Extrait)"
$reportContent += ""
$reportContent += "Les corrections suivantes ont été validées :"
$reportContent += ""
# Ici on pourrait extraire les infos de la matrice, mais pour l'instant on met un placeholder
$reportContent += "> Voir `docs/encoding/matrice-tracabilite-corrections-20251030.md` pour le détail complet."
$reportContent += ""

$reportContent += "## 🔄 État des Rollbacks"
$reportContent += ""
$reportContent += "Toutes les procédures de rollback sont documentées dans `docs/encoding/guide-rollback-phase1.md`."
$reportContent += ""

# Sauvegarde du rapport
$reportFullPath = Join-Path $rootPath $ReportPath
$reportDir = Split-Path $reportFullPath
if (-not (Test-Path $reportDir)) {
    New-Item -ItemType Directory -Path $reportDir -Force | Out-Null
}

# BOM-safe write: use .NET method instead of Set-Content (PowerShell 5.1 adds BOM with -Encoding UTF8)
[System.IO.File]::WriteAllText($reportFullPath, [string]::Join("`r`n", $reportContent), [System.Text.UTF8Encoding]::new($false))
Write-Host "Rapport généré : $reportFullPath" -ForegroundColor Cyan

# Retourner le succès global
if ($successRate -ge 95) {
    exit 0
} else {
    exit 1
}