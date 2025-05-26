# Script de test complet du système de synchronisation Roo Environment
# Fichier : d:/roo-extensions/roo-config/scheduler/test-complete-system.ps1
# Version: 1.0

param(
    [Parameter(Mandatory=$false)]
    [string]$TestMode = "full", # full, basic, scheduler-only, sync-only
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipSchedulerInstall, # Ne pas installer/désinstaller le scheduler
    
    [Parameter(Mandatory=$false)]
    [string]$RepoPath = "d:\roo-extensions"
)

$ErrorActionPreference = "Continue"
$TestResults = @()
$OverallSuccess = $true

function Write-TestLog {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    Write-Host $logMessage
    Add-Content -Path "$RepoPath\test_results.log" -Value $logMessage -ErrorAction SilentlyContinue
}

function Add-TestResult {
    param(
        [string]$TestName,
        [bool]$Success,
        [string]$Details = "",
        [string]$Duration = ""
    )
    
    $result = [PSCustomObject]@{
        TestName = $TestName
        Success = $Success
        Details = $Details
        Duration = $Duration
        Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    }
    
    $script:TestResults += $result
    
    if ($Success) {
        Write-TestLog "✓ $TestName - SUCCÈS $Duration" "SUCCESS"
    } else {
        Write-TestLog "✗ $TestName - ÉCHEC: $Details" "ERROR"
        $script:OverallSuccess = $false
    }
    
    if ($Details) {
        Write-TestLog "  Détails: $Details"
    }
}

function Test-Prerequisites {
    Write-TestLog "=== TEST DES PRÉREQUIS ==="
    
    $startTime = Get-Date
    
    # Test 1: Vérifier PowerShell version
    $psVersion = $PSVersionTable.PSVersion
    if ($psVersion.Major -ge 5) {
        Add-TestResult "PowerShell Version" $true "Version $psVersion détectée"
    } else {
        Add-TestResult "PowerShell Version" $false "Version $psVersion insuffisante (requis: 5.1+)"
    }
    
    # Test 2: Vérifier Git
    Try {
        $gitVersion = git --version
        Add-TestResult "Git Installation" $true $gitVersion
    } Catch {
        Add-TestResult "Git Installation" $false "Git non disponible"
    }
    
    # Test 3: Vérifier le répertoire de travail
    if (Test-Path $RepoPath) {
        Add-TestResult "Répertoire de Travail" $true "Répertoire $RepoPath accessible"
    } else {
        Add-TestResult "Répertoire de Travail" $false "Répertoire $RepoPath non trouvé"
    }
    
    # Test 4: Vérifier que c'est un dépôt Git
    Set-Location $RepoPath
    Try {
        git rev-parse --git-dir | Out-Null
        Add-TestResult "Dépôt Git Valide" $true "Dépôt Git détecté"
    } Catch {
        Add-TestResult "Dépôt Git Valide" $false "Pas un dépôt Git valide"
    }
    
    # Test 5: Vérifier la connectivité réseau
    Try {
        git ls-remote origin | Out-Null
        Add-TestResult "Connectivité Dépôt Distant" $true "Connexion au dépôt distant OK"
    } Catch {
        Add-TestResult "Connectivité Dépôt Distant" $false "Impossible de se connecter au dépôt distant"
    }
    
    $duration = "({0:F2}s)" -f ((Get-Date) - $startTime).TotalSeconds
    Write-TestLog "Tests des prérequis terminés $duration"
}

function Test-ScriptFiles {
    Write-TestLog "=== TEST DES FICHIERS DE SCRIPT ==="
    
    $startTime = Get-Date
    
    $scriptsToTest = @(
        @{ Path = "sync_roo_environment.ps1"; Name = "Script Principal de Synchronisation" },
        @{ Path = "roo-config\scheduler\setup-scheduler.ps1"; Name = "Script de Configuration Scheduler" },
        @{ Path = "roo-config\scheduler\validate-sync.ps1"; Name = "Script de Validation" }
    )
    
    foreach ($script in $scriptsToTest) {
        $fullPath = Join-Path $RepoPath $script.Path
        
        if (Test-Path $fullPath) {
            # Vérifier la syntaxe PowerShell
            Try {
                $null = [System.Management.Automation.PSParser]::Tokenize((Get-Content -Raw $fullPath), [ref]$null)
                Add-TestResult $script.Name $true "Syntaxe PowerShell valide"
            } Catch {
                Add-TestResult $script.Name $false "Erreur de syntaxe PowerShell: $($_.Exception.Message)"
            }
        } else {
            Add-TestResult $script.Name $false "Fichier non trouvé: $fullPath"
        }
    }
    
    $duration = "({0:F2}s)" -f ((Get-Date) - $startTime).TotalSeconds
    Write-TestLog "Tests des fichiers de script terminés $duration"
}

function Test-ConfigurationFiles {
    Write-TestLog "=== TEST DES FICHIERS DE CONFIGURATION ==="
    
    $startTime = Get-Date
    
    $configFiles = @(
        "roo-config\settings\settings.json",
        "roo-config\settings\servers.json",
        "roo-config\settings\modes.json",
        "roo-modes\configs\modes.json",
        "roo-modes\configs\new-roomodes.json",
        "roo-modes\configs\standard-modes.json",
        "roo-modes\configs\vscode-custom-modes.json"
    )
    
    foreach ($configFile in $configFiles) {
        $fullPath = Join-Path $RepoPath $configFile
        
        if (Test-Path $fullPath) {
            Try {
                Get-Content -Raw $fullPath | ConvertFrom-Json | Out-Null
                Add-TestResult "Config JSON: $(Split-Path $configFile -Leaf)" $true "JSON valide"
            } Catch {
                Add-TestResult "Config JSON: $(Split-Path $configFile -Leaf)" $false "JSON invalide: $($_.Exception.Message)"
            }
        } else {
            Add-TestResult "Config JSON: $(Split-Path $configFile -Leaf)" $false "Fichier non trouvé"
        }
    }
    
    $duration = "({0:F2}s)" -f ((Get-Date) - $startTime).TotalSeconds
    Write-TestLog "Tests des fichiers de configuration terminés $duration"
}

function Test-SyncScript {
    Write-TestLog "=== TEST DU SCRIPT DE SYNCHRONISATION ==="
    
    $startTime = Get-Date
    
    $syncScript = Join-Path $RepoPath "sync_roo_environment.ps1"
    
    if (Test-Path $syncScript) {
        Try {
            Write-TestLog "Exécution du script de synchronisation en mode test..."
            
            # Sauvegarder l'état actuel
            $originalLocation = Get-Location
            Set-Location $RepoPath
            
            # Exécuter le script et capturer la sortie
            $output = & PowerShell.exe -ExecutionPolicy Bypass -File $syncScript 2>&1
            $exitCode = $LASTEXITCODE
            
            Set-Location $originalLocation
            
            if ($exitCode -eq 0) {
                Add-TestResult "Exécution Script de Synchronisation" $true "Script exécuté avec succès (code: $exitCode)"
            } else {
                Add-TestResult "Exécution Script de Synchronisation" $false "Script échoué avec le code: $exitCode"
            }
            
            # Vérifier la création du log
            $logFile = Join-Path $RepoPath "sync_log.txt"
            if (Test-Path $logFile) {
                Add-TestResult "Génération Log de Synchronisation" $true "Fichier de log créé"
            } else {
                Add-TestResult "Génération Log de Synchronisation" $false "Fichier de log non créé"
            }
            
        } Catch {
            Add-TestResult "Exécution Script de Synchronisation" $false "Erreur d'exécution: $($_.Exception.Message)"
        }
    } else {
        Add-TestResult "Exécution Script de Synchronisation" $false "Script de synchronisation non trouvé"
    }
    
    $duration = "({0:F2}s)" -f ((Get-Date) - $startTime).TotalSeconds
    Write-TestLog "Test du script de synchronisation terminé $duration"
}

function Test-SchedulerSetup {
    if ($SkipSchedulerInstall) {
        Write-TestLog "=== TEST DU SCHEDULER (IGNORÉ) ==="
        Write-TestLog "Test du scheduler ignoré (paramètre -SkipSchedulerInstall)"
        return
    }
    
    Write-TestLog "=== TEST DU SCHEDULER ==="
    
    $startTime = Get-Date
    $setupScript = Join-Path $RepoPath "roo-config\scheduler\setup-scheduler.ps1"
    
    if (-not (Test-Path $setupScript)) {
        Add-TestResult "Script Setup Scheduler" $false "Script setup-scheduler.ps1 non trouvé"
        return
    }
    
    # Test 1: Installation du scheduler
    Try {
        Write-TestLog "Test d'installation du scheduler..."
        $output = & PowerShell.exe -ExecutionPolicy Bypass -File $setupScript -Action install 2>&1
        $exitCode = $LASTEXITCODE
        
        if ($exitCode -eq 0) {
            Add-TestResult "Installation Scheduler" $true "Scheduler installé avec succès"
        } else {
            Add-TestResult "Installation Scheduler" $false "Échec installation (code: $exitCode)"
        }
    } Catch {
        Add-TestResult "Installation Scheduler" $false "Erreur: $($_.Exception.Message)"
    }
    
    # Test 2: Vérification du statut
    Try {
        Write-TestLog "Vérification du statut du scheduler..."
        $output = & PowerShell.exe -ExecutionPolicy Bypass -File $setupScript -Action status 2>&1
        $exitCode = $LASTEXITCODE
        
        if ($exitCode -eq 0) {
            Add-TestResult "Statut Scheduler" $true "Statut récupéré avec succès"
        } else {
            Add-TestResult "Statut Scheduler" $false "Échec récupération statut (code: $exitCode)"
        }
    } Catch {
        Add-TestResult "Statut Scheduler" $false "Erreur: $($_.Exception.Message)"
    }
    
    # Test 3: Désinstallation du scheduler (nettoyage)
    Try {
        Write-TestLog "Désinstallation du scheduler (nettoyage)..."
        $output = & PowerShell.exe -ExecutionPolicy Bypass -File $setupScript -Action uninstall 2>&1
        $exitCode = $LASTEXITCODE
        
        if ($exitCode -eq 0) {
            Add-TestResult "Désinstallation Scheduler" $true "Scheduler désinstallé avec succès"
        } else {
            Add-TestResult "Désinstallation Scheduler" $false "Échec désinstallation (code: $exitCode)"
        }
    } Catch {
        Add-TestResult "Désinstallation Scheduler" $false "Erreur: $($_.Exception.Message)"
    }
    
    $duration = "({0:F2}s)" -f ((Get-Date) - $startTime).TotalSeconds
    Write-TestLog "Tests du scheduler terminés $duration"
}

function Test-ValidationScript {
    Write-TestLog "=== TEST DU SCRIPT DE VALIDATION ==="
    
    $startTime = Get-Date
    $validateScript = Join-Path $RepoPath "roo-config\scheduler\validate-sync.ps1"
    
    if (Test-Path $validateScript) {
        # Test des différents modes de validation
        $validationModes = @("quick", "health", "logs")
        
        foreach ($mode in $validationModes) {
            Try {
                Write-TestLog "Test du mode de validation: $mode"
                $output = & PowerShell.exe -ExecutionPolicy Bypass -File $validateScript -Action $mode 2>&1
                $exitCode = $LASTEXITCODE
                
                Add-TestResult "Validation Mode: $mode" ($exitCode -eq 0) "Code de sortie: $exitCode"
                
            } Catch {
                Add-TestResult "Validation Mode: $mode" $false "Erreur: $($_.Exception.Message)"
            }
        }
    } else {
        Add-TestResult "Script de Validation" $false "Script validate-sync.ps1 non trouvé"
    }
    
    $duration = "({0:F2}s)" -f ((Get-Date) - $startTime).TotalSeconds
    Write-TestLog "Tests du script de validation terminés $duration"
}

function Generate-TestReport {
    Write-TestLog "=== GÉNÉRATION DU RAPPORT DE TEST ==="
    
    $reportPath = Join-Path $RepoPath "test_report_$(Get-Date -Format 'yyyyMMdd_HHmmss').html"
    
    $html = @"
<!DOCTYPE html>
<html>
<head>
    <title>Rapport de Test - Système de Synchronisation Roo Environment</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { background-color: #f0f0f0; padding: 10px; border-radius: 5px; }
        .success { color: green; font-weight: bold; }
        .failure { color: red; font-weight: bold; }
        .test-result { margin: 10px 0; padding: 10px; border-left: 4px solid #ccc; }
        .test-success { border-left-color: green; background-color: #f0fff0; }
        .test-failure { border-left-color: red; background-color: #fff0f0; }
        table { border-collapse: collapse; width: 100%; margin: 20px 0; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; }
    </style>
</head>
<body>
    <div class="header">
        <h1>Rapport de Test - Système de Synchronisation Roo Environment</h1>
        <p><strong>Date:</strong> $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')</p>
        <p><strong>Mode de Test:</strong> $TestMode</p>
        <p><strong>Répertoire:</strong> $RepoPath</p>
        <p><strong>Résultat Global:</strong> $(if ($OverallSuccess) { '<span class="success">SUCCÈS</span>' } else { '<span class="failure">ÉCHEC</span>' })</p>
    </div>
    
    <h2>Résumé des Tests</h2>
    <table>
        <tr>
            <th>Test</th>
            <th>Résultat</th>
            <th>Détails</th>
            <th>Durée</th>
            <th>Timestamp</th>
        </tr>
"@

    foreach ($result in $TestResults) {
        $statusClass = if ($result.Success) { "success" } else { "failure" }
        $statusText = if ($result.Success) { "SUCCÈS" } else { "ÉCHEC" }
        
        $html += @"
        <tr>
            <td>$($result.TestName)</td>
            <td class="$statusClass">$statusText</td>
            <td>$($result.Details)</td>
            <td>$($result.Duration)</td>
            <td>$($result.Timestamp)</td>
        </tr>
"@
    }
    
    $html += @"
    </table>
    
    <h2>Statistiques</h2>
    <p><strong>Total des tests:</strong> $($TestResults.Count)</p>
    <p><strong>Tests réussis:</strong> $($TestResults | Where-Object { $_.Success } | Measure-Object | Select-Object -ExpandProperty Count)</p>
    <p><strong>Tests échoués:</strong> $($TestResults | Where-Object { -not $_.Success } | Measure-Object | Select-Object -ExpandProperty Count)</p>
    
    <h2>Recommandations</h2>
"@

    if (-not $OverallSuccess) {
        $html += "<p class='failure'>Des tests ont échoué. Veuillez corriger les problèmes identifiés avant de déployer le système en production.</p>"
    } else {
        $html += "<p class='success'>Tous les tests ont réussi. Le système est prêt pour le déploiement.</p>"
    }
    
    $html += @"
</body>
</html>
"@

    $html | Out-File -FilePath $reportPath -Encoding UTF8
    Write-TestLog "Rapport HTML généré: $reportPath"
}

# === MAIN EXECUTION ===

Write-TestLog "=== DÉBUT DES TESTS COMPLETS DU SYSTÈME ==="
Write-TestLog "Mode de test: $TestMode"
Write-TestLog "Répertoire: $RepoPath"

$overallStartTime = Get-Date

switch ($TestMode.ToLower()) {
    "full" {
        Test-Prerequisites
        Test-ScriptFiles
        Test-ConfigurationFiles
        Test-SyncScript
        Test-SchedulerSetup
        Test-ValidationScript
    }
    
    "basic" {
        Test-Prerequisites
        Test-ScriptFiles
        Test-ConfigurationFiles
    }
    
    "scheduler-only" {
        Test-Prerequisites
        Test-SchedulerSetup
    }
    
    "sync-only" {
        Test-Prerequisites
        Test-SyncScript
        Test-ValidationScript
    }
    
    default {
        Write-TestLog "Mode de test non reconnu: $TestMode" "ERROR"
        Exit 1
    }
}

$totalDuration = "({0:F2}s)" -f ((Get-Date) - $overallStartTime).TotalSeconds

Write-TestLog "=== TESTS TERMINÉS $totalDuration ==="
Write-TestLog "Résultat global: $(if ($OverallSuccess) { 'SUCCÈS' } else { 'ÉCHEC' })"

Generate-TestReport

if ($OverallSuccess) {
    Write-TestLog "✓ Tous les tests ont réussi. Le système est opérationnel." "SUCCESS"
    Exit 0
} else {
    Write-TestLog "✗ Certains tests ont échoué. Vérifiez les détails ci-dessus." "ERROR"
    Exit 1
}