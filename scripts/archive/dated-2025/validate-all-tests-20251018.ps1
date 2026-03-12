# Script de Validation Complète des Tests - Mission 2025-10-18
# Partie 4: Validation des tests existants
# Exécution automatisée de tous les tests avec génération de rapport

#Requires -Version 7.0
$ErrorActionPreference = "Continue"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# Configuration
$SCRIPT_DIR = $PSScriptRoot
$ROOT_DIR = Split-Path (Split-Path $SCRIPT_DIR -Parent) -Parent
$TIMESTAMP = Get-Date -Format "yyyyMMdd-HHmmss"
$REPORT_FILE = Join-Path $ROOT_DIR "docs\testing\test-validation-report-20251018.md"

# Initialisation du rapport
$global:TestResults = @{
    TotalTests = 0
    PassedTests = 0
    FailedTests = 0
    SkippedTests = 0
    Modules = @()
    StartTime = Get-Date
    Errors = @()
}

Write-Host "`n=====================================" -ForegroundColor Cyan
Write-Host "  Validation Complète Tests - 2025-10-18" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan

function Test-Module {
    param(
        [string]$Name,
        [string]$Path,
        [string]$TestCommand
    )
    
    Write-Host "`n--- Test Module: $Name ---" -ForegroundColor Yellow
    Write-Host "Path: $Path" -ForegroundColor Gray
    Write-Host "Command: $TestCommand" -ForegroundColor Gray
    
    $moduleResult = @{
        Name = $Name
        Path = $Path
        StartTime = Get-Date
        Passed = 0
        Failed = 0
        Skipped = 0
        Duration = 0
        Status = "Unknown"
        Output = ""
        Errors = @()
    }
    
    try {
        Push-Location $Path
        
        # Exécuter tests avec capture output
        $output = & pwsh -NoProfile -Command $TestCommand 2>&1
        $exitCode = $LASTEXITCODE
        
        $moduleResult.Output = $output -join "`n"
        $moduleResult.Duration = ((Get-Date) - $moduleResult.StartTime).TotalSeconds
        
        # Parser résultats selon le framework
        if ($output -match "Test Suites:\s+(\d+)\s+passed.*,\s*(\d+)\s+total") {
            # Jest format
            $moduleResult.Passed = [int]$matches[1]
            $moduleResult.Failed = [int]$matches[2] - [int]$matches[1]
        }
        elseif ($output -match "Tests:\s+(\d+)\s+passed.*,\s*(\d+)\s+total") {
            # Jest tests format
            $passed = [int]$matches[1]
            $total = [int]$matches[2]
            $moduleResult.Passed = $passed
            $moduleResult.Failed = $total - $passed
        }
        elseif ($output -match "✓\s+(\d+)\s+tests?\s+passed") {
            # Vitest format
            $moduleResult.Passed = [int]$matches[1]
            $moduleResult.Failed = 0
        }
        
        # Déterminer statut
        if ($exitCode -eq 0 -and $moduleResult.Failed -eq 0) {
            $moduleResult.Status = "Success"
            Write-Host "✓ SUCCÈS: $($moduleResult.Passed) tests passés" -ForegroundColor Green
        }
        elseif ($moduleResult.Failed -gt 0) {
            $moduleResult.Status = "Failed"
            Write-Host "✗ ÉCHEC: $($moduleResult.Failed) tests échoués sur $($moduleResult.Passed + $moduleResult.Failed)" -ForegroundColor Red
        }
        else {
            $moduleResult.Status = "Warning"
            Write-Host "⚠ AVERTISSEMENT: Exit code $exitCode" -ForegroundColor Yellow
        }
        
        # Extraire erreurs notables
        $errorLines = $output | Where-Object { $_ -match "error:|Error:|FAIL|✗" }
        if ($errorLines) {
            $moduleResult.Errors = $errorLines
        }
        
    }
    catch {
        $moduleResult.Status = "Error"
        $moduleResult.Errors = @($_.Exception.Message)
        Write-Host "✗ ERREUR: $($_.Exception.Message)" -ForegroundColor Red
    }
    finally {
        Pop-Location
    }
    
    # Mettre à jour totaux
    $global:TestResults.TotalTests += ($moduleResult.Passed + $moduleResult.Failed + $moduleResult.Skipped)
    $global:TestResults.PassedTests += $moduleResult.Passed
    $global:TestResults.FailedTests += $moduleResult.Failed
    $global:TestResults.SkippedTests += $moduleResult.Skipped
    $global:TestResults.Modules += $moduleResult
    
    return $moduleResult
}

# ========================================
# MODULE 1: github-projects-mcp
# ========================================
$githubProjectsPath = Join-Path $ROOT_DIR "mcps\internal\servers\github-projects-mcp"
if (Test-Path $githubProjectsPath) {
    Test-Module -Name "github-projects-mcp" `
                -Path $githubProjectsPath `
                -TestCommand "npm test"
}

# ========================================
# MODULE 2: roo-state-manager
# ========================================
$stateManagerPath = Join-Path $ROOT_DIR "mcps\internal\servers\roo-state-manager"
if (Test-Path $stateManagerPath) {
    Test-Module -Name "roo-state-manager" `
                -Path $stateManagerPath `
                -TestCommand "npm test"
}

# ========================================
# MODULE 3: quickfiles-server
# ========================================
$quickfilesPath = Join-Path $ROOT_DIR "mcps\internal\servers\quickfiles-server"
if (Test-Path $quickfilesPath) {
    Test-Module -Name "quickfiles-server" `
                -Path $quickfilesPath `
                -TestCommand "npm test"
}

# ========================================
# MODULE 4: Tests du dépôt principal
# ========================================
# Tests indexer-phase1
$indexerTest1 = Join-Path $ROOT_DIR "tests\indexer-phase1-unit-tests.cjs"
if (Test-Path $indexerTest1) {
    Test-Module -Name "indexer-phase1-unit-tests" `
                -Path $ROOT_DIR `
                -TestCommand "node '$indexerTest1'"
}

# Tests indexer-phase2
$indexerTest2 = Join-Path $ROOT_DIR "tests\indexer-phase2-load-tests.cjs"
if (Test-Path $indexerTest2) {
    Test-Module -Name "indexer-phase2-load-tests" `
                -Path $ROOT_DIR `
                -TestCommand "node '$indexerTest2'"
}

# ========================================
# GÉNÉRATION DU RAPPORT
# ========================================
Write-Host "`n=====================================" -ForegroundColor Cyan
Write-Host "  Génération du Rapport" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan

$global:TestResults.EndTime = Get-Date
$totalDuration = ($global:TestResults.EndTime - $global:TestResults.StartTime).TotalSeconds

# Calculer taux de succès
$successRate = if ($global:TestResults.TotalTests -gt 0) {
    [math]::Round(($global:TestResults.PassedTests / $global:TestResults.TotalTests) * 100, 2)
} else { 0 }

# Créer répertoire si nécessaire
$reportDir = Split-Path $REPORT_FILE -Parent
if (-not (Test-Path $reportDir)) {
    New-Item -ItemType Directory -Path $reportDir -Force | Out-Null
}

# Générer rapport Markdown
$report = @"
# Rapport Validation Tests - 2025-10-18

**Date d'exécution**: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")  
**Durée totale**: $([math]::Round($totalDuration, 2)) secondes

---

## Résumé Exécutif

| Métrique | Valeur | Pourcentage |
|----------|--------|-------------|
| **Total tests exécutés** | $($global:TestResults.TotalTests) | 100% |
| **Tests passés** | $($global:TestResults.PassedTests) | $successRate% |
| **Tests échoués** | $($global:TestResults.FailedTests) | $([math]::Round(($global:TestResults.FailedTests / $global:TestResults.TotalTests) * 100, 2))% |
| **Tests ignorés** | $($global:TestResults.SkippedTests) | $([math]::Round(($global:TestResults.SkippedTests / $global:TestResults.TotalTests) * 100, 2))% |

**Statut global**: $(if ($global:TestResults.FailedTests -eq 0) { "✅ SUCCÈS" } elseif ($successRate -ge 80) { "⚠️ AVERTISSEMENT" } else { "❌ ÉCHEC" })

---

## Détails par Module

"@

foreach ($module in $global:TestResults.Modules) {
    $statusIcon = switch ($module.Status) {
        "Success" { "✅" }
        "Failed" { "❌" }
        "Warning" { "⚠️" }
        default { "❓" }
    }
    
    $report += @"

### $statusIcon $($module.Name)

**Chemin**: ``$($module.Path)``  
**Durée**: $([math]::Round($module.Duration, 2))s  
**Statut**: $($module.Status)

**Résultats**:
- Tests passés: $($module.Passed)
- Tests échoués: $($module.Failed)
- Tests ignorés: $($module.Skipped)

"@

    if ($module.Errors.Count -gt 0) {
        $report += @"

**Erreurs notables**:
``````
$($module.Errors -join "`n")
``````

"@
    }
}

$report += @"

---

## Analyse

"@

if ($global:TestResults.FailedTests -eq 0) {
    $report += @"
### ✅ Tous les tests passent avec succès

Aucun test échoué détecté. L'infrastructure de tests est en bon état.

"@
}
else {
    $report += @"
### ⚠️ Des tests ont échoué

**Nombre de tests échoués**: $($global:TestResults.FailedTests)  
**Taux d'échec**: $([math]::Round(($global:TestResults.FailedTests / $global:TestResults.TotalTests) * 100, 2))%

**Modules concernés**:
"@
    
    $failedModules = $global:TestResults.Modules | Where-Object { $_.Failed -gt 0 }
    foreach ($mod in $failedModules) {
        $report += "`n- **$($mod.Name)**: $($mod.Failed) test(s) échoué(s)"
    }
}

$report += @"


---

## Actions Requises

"@

if ($global:TestResults.FailedTests -eq 0) {
    $report += @"
- ✅ Aucune action immédiate requise
- Procéder à la Partie 5: Augmentation de la couverture tests

"@
}
else {
    $report += @"
- ❌ Corriger les tests échoués avant de procéder
- Analyser les logs d'erreur ci-dessus
- Re-exécuter ce script après corrections: ``scripts\testing\validate-all-tests-20251018.ps1``

"@
}

$report += @"

---

## Métadonnées

- **Script**: ``scripts\testing\validate-all-tests-20251018.ps1``
- **Timestamp**: $TIMESTAMP
- **Système**: Windows PowerShell $($PSVersionTable.PSVersion)
- **Répertoire**: ``$ROOT_DIR``

"@

# Écrire le rapport
$report | Out-File -FilePath $REPORT_FILE -Encoding UTF8 -Force

Write-Host "`n✓ Rapport généré: $REPORT_FILE" -ForegroundColor Green

# ========================================
# RÉSUMÉ FINAL CONSOLE
# ========================================
Write-Host "`n=====================================" -ForegroundColor Cyan
Write-Host "  RÉSUMÉ FINAL" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan

Write-Host "`nTotal tests: $($global:TestResults.TotalTests)" -ForegroundColor White
Write-Host "  Passés:    $($global:TestResults.PassedTests) ($successRate%)" -ForegroundColor Green
Write-Host "  Échoués:   $($global:TestResults.FailedTests)" -ForegroundColor $(if ($global:TestResults.FailedTests -eq 0) { "Green" } else { "Red" })
Write-Host "  Ignorés:   $($global:TestResults.SkippedTests)" -ForegroundColor Gray

Write-Host "`nDurée totale: $([math]::Round($totalDuration, 2))s" -ForegroundColor White

if ($global:TestResults.FailedTests -eq 0) {
    Write-Host "`n✅ TOUS LES TESTS PASSENT - Prêt pour Partie 5" -ForegroundColor Green
    exit 0
}
else {
    Write-Host "`n⚠️  CERTAINS TESTS ONT ÉCHOUÉ - Vérifier le rapport" -ForegroundColor Yellow
    Write-Host "Rapport: $REPORT_FILE" -ForegroundColor Cyan
    exit 1
}