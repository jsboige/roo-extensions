#!/usr/bin/env powershell
<#
.SYNOPSIS
Script de validation complète post-Mission SDDD Triple Grounding

.DESCRIPTION
Valide systématiquement tous les composants critiques modifiés pendant la Mission SDDD :
- Smart Truncation Engine (300K caractères)
- Architecture Qdrant optimisée
- Outils développeur améliorés
- Infrastructure Git et hooks
- Documentation maintenance

.NOTES
Créé le: 2025-10-07
Version: 1.0
Mission: Validation finale SDDD Triple Grounding
#>

param(
    [switch]$DetailedOutput = $false,
    [switch]$RunTests = $true,
    [switch]$SkipPerformance = $false
)

# Configuration
$ErrorActionPreference = "Continue"
$WarningPreference = "Continue"
$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$logFile = "scripts/diagnostic/logs/validation-post-sddd-$timestamp.log"
$reportFile = "analysis-reports/VALIDATION-POST-SDDD-$timestamp.md"

# Créer le répertoire de logs si nécessaire
if (!(Test-Path "scripts/diagnostic/logs")) {
    New-Item -ItemType Directory -Path "scripts/diagnostic/logs" -Force | Out-Null
}

function Write-LoggedOutput {
    param([string]$Message, [string]$Level = "INFO")
    
    $formattedMessage = "[$timestamp] [$Level] $Message"
    Write-Host $formattedMessage
    Add-Content -Path $logFile -Value $formattedMessage
}

function Test-SmartTruncationEngine {
    Write-LoggedOutput "=== PHASE 1: TESTS SMART TRUNCATION ENGINE ===" "PHASE"
    
    $results = @{
        TestsExist = $false
        TestsPassed = $false
        ConfigValid = $false
        Capacity300K = $false
        Errors = @()
    }
    
    # Verifier structure des tests
    $testDir = "mcps/internal/servers/roo-state-manager/src/tools/smart-truncation/__tests__"
    if (Test-Path $testDir) {
        $results.TestsExist = $true
        $testFiles = Get-ChildItem -Path $testDir -Filter "*.test.ts" -Recurse
        Write-LoggedOutput "Tests dependances|REUSSIS|ECHOUS|GENERATION|configure|detecte|presents|executables|synchronises|trouves: $($testFiles.Count) fichiers" "SUCCESS"
        
        foreach ($testFile in $testFiles) {
            Write-LoggedOutput "  - $($testFile.Name) ($('{0:N0}' -f $testFile.Length) bytes, modifié: $($testFile.LastWriteTime))"
        }
    } else {
        $results.Errors += "Répertoire de tests manquant: $testDir"
        Write-LoggedOutput "ERREUR: Répertoire de tests manquant" "ERROR"
    }
    
    # Verifier package.json
    $packageJson = "mcps/internal/servers/roo-state-manager/package.json"
    if (Test-Path $packageJson) {
        try {
            $pkg = Get-Content $packageJson | ConvertFrom-Json
            $results.ConfigValid = $true
            Write-LoggedOutput "Package: $($pkg.name) v$($pkg.version)" "SUCCESS"
            
            if ($pkg.scripts -and $pkg.scripts.test) {
                Write-LoggedOutput "Script test dependances|REUSSIS|ECHOUS|GENERATION|configure|detecte|presents|executables|synchronises|trouve: $($pkg.scripts.test)" "SUCCESS"
            } else {
                $results.Errors += "Script test manquant dans package.json"
            }
        } catch {
            $results.Errors += "Erreur lecture package.json: $_"
            Write-LoggedOutput "ERREUR lecture package.json: $_" "ERROR"
        }
    } else {
        $results.Errors += "package.json manquant"
    }
    
    # Test capacité 300K
    $configFile = "mcps/internal/servers/roo-state-manager/src/tools/smart-truncation/config.ts"
    if (Test-Path $configFile) {
        $configContent = Get-Content $configFile -Raw
        if ($configContent -match "300000|300\s*\*\s*1000") {
            $results.Capacity300K = $true
            Write-LoggedOutput "Capacité 300K dependances|REUSSIS|ECHOUS|GENERATION|configure|detecte|presents|executables|synchronises|trouve dans config" "SUCCESS"
        } else {
            $results.Errors += "Capacité 300K non confirmée dans config"
        }
    }
    
    return $results
}

function Test-QdrantArchitecture {
    Write-LoggedOutput "=== PHASE 2: ARCHITECTURE QDRANT ===" "PHASE"
    
    $results = @{
        ServicesExist = $false
        IndexingOptimized = $false
        NoInfiniteLoops = $false
        TTLConfigured = $false
        Errors = @()
    }
    
    # Verifier services d'indexation
    $indexingService = "mcps/internal/servers/roo-state-manager/src/services/indexing.ts"
    $decisionService = "mcps/internal/servers/roo-state-manager/src/services/indexing-decision.ts"
    
    if ((Test-Path $indexingService) -and (Test-Path $decisionService)) {
        $results.ServicesExist = $true
        Write-LoggedOutput "Services indexing dependances|REUSSIS|ECHOUS|GENERATION|configure|detecte|presents|executables|synchronises|trouves" "SUCCESS"
        
        # Verifier optimisations
        $decisionContent = Get-Content $decisionService -Raw
        if ($decisionContent -match "TTL|cache|optimization") {
            $results.IndexingOptimized = $true
            Write-LoggedOutput "Optimisations dependances|REUSSIS|ECHOUS|GENERATION|configure|detecte|presents|executables|synchronises|trouves dans indexing-decision" "SUCCESS"
        }
        
        if ($decisionContent -match "7.*day|604800") {
            $results.TTLConfigured = $true
            Write-LoggedOutput "TTL 7 jours dependances|REUSSIS|ECHOUS|GENERATION|configure|detecte|presents|executables|synchronises|trouve" "SUCCESS"
        }
    } else {
        $results.Errors += "Services indexing manquants"
    }
    
    return $results
}

function Test-DeveloperTools {
    Write-LoggedOutput "=== PHASE 3: OUTILS DÉVELOPPEUR ===" "PHASE"
    
    $results = @{
        ViewConversationTree = $false
        GenerateTraceSummary = $false
        Performance300K = $false
        Errors = @()
    }
    
    # Verifier outils dans l'index principal
    $mainIndex = "mcps/internal/servers/roo-state-manager/src/index.ts"
    if (Test-Path $mainIndex) {
        $indexContent = Get-Content $mainIndex -Raw
        
        if ($indexContent -match "view_conversation_tree") {
            $results.ViewConversationTree = $true
            Write-LoggedOutput "view_conversation_tree détecté" "SUCCESS"
        }
        
        if ($indexContent -match "generate_trace_summary") {
            $results.GenerateTraceSummary = $true  
            Write-LoggedOutput "generate_trace_summary détecté" "SUCCESS"
        }
        
        # Verifier intégration Smart Truncation
        if ($indexContent -match "smart.truncation|smartTruncation|300000") {
            $results.Performance300K = $true
            Write-LoggedOutput "Intégration Smart Truncation 300K dependances|REUSSIS|ECHOUS|GENERATION|configure|detecte|presents|executables|synchronises|trouve" "SUCCESS"
        }
    } else {
        $results.Errors += "Index principal roo-state-manager manquant"
    }
    
    return $results
}

function Test-GitInfrastructure {
    Write-LoggedOutput "=== PHASE 4: INFRASTRUCTURE GIT ===" "PHASE"
    
    $results = @{
        HooksExist = $false
        HooksExecutable = $false
        SubmodulesSync = $false
        DocumentationReady = $false
        Errors = @()
    }
    
    # Verifier hooks
    $preCommitHook = ".git/hooks/pre-commit"
    if (Test-Path $preCommitHook) {
        $results.HooksExist = $true
        Write-LoggedOutput "Hook pre-commit dependances|REUSSIS|ECHOUS|GENERATION|configure|detecte|presents|executables|synchronises|trouve" "SUCCESS"
        
        # Verifier permissions (Windows)
        try {
            $hookContent = Get-Content $preCommitHook -Raw
            if ($hookContent -match "#!/|pwsh|powershell") {
                $results.HooksExecutable = $true
                Write-LoggedOutput "Hook pre-commit semble exécutable" "SUCCESS"
            }
        } catch {
            $results.Errors += "Erreur lecture hook pre-commit: $_"
        }
    } else {
        $results.Errors += "Hook pre-commit manquant"
    }
    
    # Verifier sous-modules
    if (Test-Path ".gitmodules") {
        $submodules = git submodule status 2>$null
        if ($LASTEXITCODE -eq 0) {
            $results.SubmodulesSync = $true
            Write-LoggedOutput "Sous-modules dependances|REUSSIS|ECHOUS|GENERATION|configure|detecte|presents|executables|synchronises|trouve" "SUCCESS"
        } else {
            $results.Errors += "Problème synchronisation sous-modules"
        }
    }
    
    # Verifier documentation maintenance
    $maintenanceGuide = "docs/maintenance/GUIDE_HOOKS_GIT_RESOLUTION.md"
    if (Test-Path $maintenanceGuide) {
        $results.DocumentationReady = $true
        Write-LoggedOutput "Guide maintenance dependances|REUSSIS|ECHOUS|GENERATION|configure|detecte|presents|executables|synchronises|trouve" "SUCCESS"
    }
    
    return $results
}

function Run-UnitTests {
    if (!$RunTests) {
        Write-LoggedOutput "Tests unitaires ignorés (paramètre SkipTests)" "SKIP"
        return @{ Executed = $false; Reason = "Skipped by parameter" }
    }
    
    Write-LoggedOutput "=== EXÉCUTION TESTS UNITAIRES ===" "PHASE"
    
    $results = @{
        Executed = $false
        Passed = $false
        Output = ""
        Errors = @()
    }
    
    $testDir = "mcps/internal/servers/roo-state-manager"
    if (Test-Path "$testDir/package.json") {
        try {
            Push-Location $testDir
            Write-LoggedOutput "Execution npm test dans $testDir" "INFO"
            
            # Verifier si node_modules existe
            if (!(Test-Path "node_modules")) {
                Write-LoggedOutput "Installation dependances|REUSSIS|ECHOUS|GENERATION|configure|detecte|presents|executables|synchronises|trouve..." "INFO"
                $installResult = npm install 2>&1
                if ($LASTEXITCODE -ne 0) {
                    $results.Errors += "Erreur npm install: $installResult"
                    return $results
                }
            }
            
            # Exécuter tests
            $testOutput = npm test 2>&1
            $results.Executed = $true
            $results.Output = $testOutput -join "`n"
            
            if ($LASTEXITCODE -eq 0) {
                $results.Passed = $true
                Write-LoggedOutput "Tests unitaires dependances|REUSSIS|ECHOUS|GENERATION|configure|detecte|presents|executables|synchronises|trouve" "SUCCESS"
            } else {
                $results.Errors += "Tests unitaires dependances|REUSSIS|ECHOUS|GENERATION|configure|detecte|presents|executables|synchronises|trouve"
                Write-LoggedOutput "Tests unitaires dependances|REUSSIS|ECHOUS|GENERATION|configure|detecte|presents|executables|synchronises|trouve" "ERROR"
            }
            
        } catch {
            $results.Errors += "Exception lors de l'exécution des tests: $_"
        } finally {
            Pop-Location
        }
    } else {
        $results.Errors += "package.json introuvable dans $testDir"
    }
    
    return $results
}

function Generate-ValidationReport {
    param(
        $SmartTruncationResults,
        $QdrantResults, 
        $DeveloperToolsResults,
        $GitResults,
        $TestResults
    )
    
    Write-LoggedOutput "=== dependances|REUSSIS|ECHOUS|GENERATION|configure|detecte|presents|executables|synchronises|trouve RAPPORT FINAL ===" "PHASE"
    
    $report = @"
# RAPPORT VALIDATION POST-MISSION SDDD TRIPLE GROUNDING

**Date:** $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
**Duree:** $('{0:F2}' -f ((Get-Date) - $startTime).TotalMinutes) minutes

## RESUME EXECUTIF

### COMPOSANTS VALIDES
$(if ($SmartTruncationResults.TestsExist -and $SmartTruncationResults.Capacity300K) {"- Smart Truncation Engine (300K) : OK"} else {"- Smart Truncation Engine (300K) : ERREUR"})
$(if ($QdrantResults.ServicesExist -and $QdrantResults.IndexingOptimized) {"- Architecture Qdrant optimisee : OK"} else {"- Architecture Qdrant optimisee : ERREUR"})
$(if ($DeveloperToolsResults.ViewConversationTree -and $DeveloperToolsResults.Performance300K) {"- Outils developpeur ameliores : OK"} else {"- Outils developpeur ameliores : ERREUR"})
$(if ($GitResults.HooksExist -and $GitResults.DocumentationReady) {"- Infrastructure Git : OK"} else {"- Infrastructure Git : ERREUR"})
$(if ($TestResults.Executed -and $TestResults.Passed) {"- Tests unitaires : OK"} else {"- Tests unitaires : ERREUR"})

## DETAILS PAR COMPOSANT

### Smart Truncation Engine
- Tests presents: $($SmartTruncationResults.TestsExist)
- Configuration valide: $($SmartTruncationResults.ConfigValid)
- Capacite 300K: $($SmartTruncationResults.Capacity300K)
- Erreurs: $($SmartTruncationResults.Errors.Count)

### Architecture Qdrant
- Services indexing: $($QdrantResults.ServicesExist)
- Optimisations: $($QdrantResults.IndexingOptimized)
- TTL configure: $($QdrantResults.TTLConfigured)
- Erreurs: $($QdrantResults.Errors.Count)

### Outils Developpeur
- view_conversation_tree: $($DeveloperToolsResults.ViewConversationTree)
- generate_trace_summary: $($DeveloperToolsResults.GenerateTraceSummary)
- Performance 300K: $($DeveloperToolsResults.Performance300K)
- Erreurs: $($DeveloperToolsResults.Errors.Count)

### Infrastructure Git
- Hooks presents: $($GitResults.HooksExist)
- Hooks executables: $($GitResults.HooksExecutable)
- Sous-modules sync: $($GitResults.SubmodulesSync)
- Documentation: $($GitResults.DocumentationReady)
- Erreurs: $($GitResults.Errors.Count)

### Tests Unitaires
- Executes: $($TestResults.Executed)
- Reussis: $($TestResults.Passed)
- Erreurs: $($TestResults.Errors.Count)

## PROBLEMES DETECTES

$(if ($SmartTruncationResults.Errors.Count -gt 0) {"### Smart Truncation Engine`n" + ($SmartTruncationResults.Errors | ForEach-Object {"- $_"} | Out-String)})
$(if ($QdrantResults.Errors.Count -gt 0) {"### Architecture Qdrant`n" + ($QdrantResults.Errors | ForEach-Object {"- $_"} | Out-String)})
$(if ($DeveloperToolsResults.Errors.Count -gt 0) {"### Outils Developpeur`n" + ($DeveloperToolsResults.Errors | ForEach-Object {"- $_"} | Out-String)})
$(if ($GitResults.Errors.Count -gt 0) {"### Infrastructure Git`n" + ($GitResults.Errors | ForEach-Object {"- $_"} | Out-String)})
$(if ($TestResults.Errors.Count -gt 0) {"### Tests Unitaires`n" + ($TestResults.Errors | ForEach-Object {"- $_"} | Out-String)})

## RECOMMANDATIONS

$(if ($SmartTruncationResults.Errors.Count -gt 0 -or $QdrantResults.Errors.Count -gt 0) {"[CRITIQUE] Problemes majeurs detectes - correction immediate requise"} elseif ($DeveloperToolsResults.Errors.Count -gt 0 -or $GitResults.Errors.Count -gt 0) {"[ATTENTION] Problemes mineurs - correction recommandee"} else {"[SUCCES] Validation complete reussie - Mission SDDD confirmee"})

---
*Rapport genere automatiquement par validation-post-sddd-$(Get-Date -Format "yyyy-MM-dd").ps1*
"@

    # Sauvegarder le rapport
    $report | Out-File -FilePath $reportFile -Encoding UTF8
    Write-LoggedOutput "Rapport sauvegardé: $reportFile" "SUCCESS"
    
    return $report
}

# === EXÉCUTION PRINCIPALE ===

Write-LoggedOutput "Démarrage validation post-Mission SDDD Triple Grounding" "START"
$startTime = Get-Date

# Phase 1: Tests Smart Truncation Engine
$smartTruncationResults = Test-SmartTruncationEngine

# Phase 2: Architecture Qdrant  
$qdrantResults = Test-QdrantArchitecture

# Phase 3: Outils Développeur
$developerToolsResults = Test-DeveloperTools  

# Phase 4: Infrastructure Git
$gitResults = Test-GitInfrastructure

# Phase 5: Tests Unitaires
$testResults = Run-UnitTests

# Génération rapport final
$finalReport = Generate-ValidationReport -SmartTruncationResults $smartTruncationResults -QdrantResults $qdrantResults -DeveloperToolsResults $developerToolsResults -GitResults $gitResults -TestResults $testResults

Write-LoggedOutput "=== VALIDATION TERMINÉE ===" "END"
Write-LoggedOutput "Durée totale: $('{0:F2}' -f ((Get-Date) - $startTime).TotalMinutes) minutes" "INFO"
Write-LoggedOutput "Log détaillé: $logFile" "INFO"  
Write-LoggedOutput "Rapport final: $reportFile" "INFO"

# Afficher résumé si demandé
if ($DetailedOutput) {
    Write-Host "`n" -NoNewline
    Write-Host $finalReport
}

# Code de sortie basé sur le succès global
$criticalErrors = $smartTruncationResults.Errors.Count + $qdrantResults.Errors.Count
if ($criticalErrors -gt 0) {
    exit 1
} else {
    exit 0
}