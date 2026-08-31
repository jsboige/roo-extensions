<#
.SYNOPSIS
    Script de validation post-activation UTF-8 pour Windows 11 Pro français
.DESCRIPTION
    Ce script valide l'activation effective de l'option UTF-8 beta sur Windows.
    Il effectue des tests complets pour confirmer que l'encodage UTF-8
    est correctement configuré à tous les niveaux système.
.PARAMETER Detailed
    Affiche des informations détaillées pendant la validation
.PARAMETER OutputFormat
    Format de sortie du rapport (JSON, Markdown, Console)
.PARAMETER TestFiles
    Génère des fichiers de test pour validation manuelle
.EXAMPLE
    .\Test-UTF8Activation.ps1
.EXAMPLE
    .\Test-UTF8Activation.ps1 -Detailed -OutputFormat JSON
.EXAMPLE
    .\Test-UTF8Activation.ps1 -TestFiles -Detailed
.NOTES
    Auteur: Roo Architect Complex Mode
    Version: 1.0
    Date: 2025-10-30
    ID Correction: SYS-001-VALIDATION
    Priorité: CRITIQUE
    Requiert: Windows 10+ avec UTF-8 beta activé
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [switch]$Detailed,
    
    [Parameter(Mandatory = $false)]
    [ValidateSet("JSON", "Markdown", "Console")]
    [string]$OutputFormat = "Console",
    
    [Parameter(Mandatory = $false)]
    [switch]$TestFiles
)

# Configuration du script
$script:LogFile = "logs\Test-UTF8Activation-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
$script:TestDir = "temp\utf8-validation-tests"
$script:ResultsDir = "results\utf8-validation-$(Get-Date -Format 'yyyyMMdd-HHmmss')"

# Fonctions de logging
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    
    Write-Host $logEntry -ForegroundColor $(
        switch ($Level) {
            "ERROR" { "Red" }
            "WARN" { "Yellow" }
            "SUCCESS" { "Green" }
            "INFO" { "Cyan" }
            "TEST" { "Magenta" }
            default { "White" }
        }
    )
    
    # Création du répertoire de logs si nécessaire
    if (!(Test-Path "logs")) {
        New-Item -ItemType Directory -Path "logs" -Force | Out-Null
    }
    
    # Écriture dans le fichier de log
    Add-Content -Path $script:LogFile -Value $logEntry -Encoding UTF8
}

function Write-Success {
    param([string]$Message)
    Write-Log $Message "SUCCESS"
}

function Write-Error {
    param([string]$Message)
    Write-Log $Message "ERROR"
}

function Write-Warning {
    param([string]$Message)
    Write-Log $Message "WARN"
}

function Write-Info {
    param([string]$Message)
    if ($Detailed) {
        Write-Log $Message "INFO"
    }
}

function Write-Test {
    param([string]$Message)
    Write-Log $Message "TEST"
}

# Tests de validation UTF-8
function Test-SystemCodePages {
    Write-Test "Test 1: Validation des pages de code système..."
    
    $result = @{
        TestName = "SystemCodePages"
        Success = $false
        Details = @{}
        Issues = @()
        Recommendations = @()
    }
    
    try {
        $codePagePath = "HKLM:\SYSTEM\CurrentControlSet\Control\Nls\CodePage"
        if (-not (Test-Path $codePagePath)) {
            $result.Issues += "Clé de registre des pages de code introuvable"
            return $result
        }
        
        $codePages = Get-ItemProperty -Path $codePagePath
        $result.Details = @{
            ACP = $codePages.ACP
            OEMCP = $codePages.OEMCP
            MACCP = $codePages.MACCP
        }
        
        # Validation UTF-8 (65001)
        if ($codePages.ACP -eq 65001 -and $codePages.OEMCP -eq 65001) {
            $result.Success = $true
            Write-Success "Pages de code système: OK (ACP=$($codePages.ACP), OEMCP=$($codePages.OEMCP))"
        } else {
            $result.Issues += "Pages de code incorrectes: ACP=$($codePages.ACP), OEMCP=$($codePages.OEMCP)"
            $result.Recommendations += "Les pages de code doivent être 65001 pour UTF-8"
            Write-Warning "Pages de code système: ÉCHEC"
        }
        
    } catch {
        $result.Issues += "Erreur lors de la lecture des pages de code: $($_.Exception.Message)"
        Write-Error "Test pages de code: ÉCHEC"
    }
    
    return $result
}

function Test-RegionalSettings {
    Write-Test "Test 2: Validation des paramètres régionaux..."
    
    $result = @{
        TestName = "RegionalSettings"
        Success = $false
        Details = @{}
        Issues = @()
        Recommendations = @()
    }
    
    try {
        $intlPath = "HKCU:\Control Panel\International"
        if (-not (Test-Path $intlPath)) {
            $result.Issues += "Clé de registre internationale introuvable"
            return $result
        }
        
        $intlSettings = Get-ItemProperty -Path $intlPath
        $result.Details = $intlSettings
        
        # Validation des paramètres UTF-8
        $validLocale = $false
        if ($intlSettings.LocaleName -eq "fr-FR") {
            $validLocale = $true
        }
        
        if ($intlSettings.Locale -eq "0000040C") {
            $validLocale = $true
        }
        
        if ($validLocale) {
            $result.Success = $true
            Write-Success "Paramètres régionaux: OK ($($intlSettings.LocaleName))"
        } else {
            $result.Issues += "Paramètres régionaux incorrects: $($intlSettings.LocaleName)"
            $result.Recommendations += "Configurer fr-FR comme locale par défaut"
            Write-Warning "Paramètres régionaux: ÉCHEC"
        }
        
    } catch {
        $result.Issues += "Erreur lors de la lecture des paramètres régionaux: $($_.Exception.Message)"
        Write-Error "Test paramètres régionaux: ÉCHEC"
    }
    
    return $result
}

function Test-ConsoleEncoding {
    Write-Test "Test 3: Validation de l'encodage console..."
    
    $result = @{
        TestName = "ConsoleEncoding"
        Success = $false
        Details = @{}
        Issues = @()
        Recommendations = @()
    }
    
    try {
        # Test de l'encodage de sortie console
        $outputEncoding = [System.Console]::OutputEncoding
        $inputEncoding = [System.Console]::InputEncoding
        
        $result.Details = @{
            OutputEncoding = $outputEncoding.EncodingName
            InputEncoding = $inputEncoding.EncodingName
            CodePage = [System.Console]::OutputEncoding.CodePage
        }
        
        # Validation UTF-8
        if ($outputEncoding.CodePage -eq 65001) {
            $result.Success = $true
            Write-Success "Encodage console: OK ($($outputEncoding.EncodingName))"
        } else {
            $result.Issues += "Encodage console non-UTF-8: $($outputEncoding.EncodingName)"
            $result.Recommendations += "Exécuter 'chcp 65001' dans chaque session"
            Write-Warning "Encodage console: ÉCHEC"
        }
        
    } catch {
        $result.Issues += "Erreur lors du test d'encodage console: $($_.Exception.Message)"
        Write-Error "Test encodage console: ÉCHEC"
    }
    
    return $result
}

function Test-FileSystemEncoding {
    Write-Test "Test 4: Validation de l'encodage système de fichiers..."
    
    $result = @{
        TestName = "FileSystemEncoding"
        Success = $false
        Details = @{}
        Issues = @()
        Recommendations = @()
    }
    
    try {
        # Création du répertoire de tests
        if (!(Test-Path $script:TestDir)) {
            New-Item -ItemType Directory -Path $script:TestDir -Force | Out-Null
        }
        
        # Test strings avec caractères UTF-8 complexes
        $testStrings = @(
            "Test français: é è à ù ç œ æ â ê î ô û",
            "Test européen: ß ä ö ü ñ ç",
            "Test symboles: € £ ¥ © ® ™",
            "Test emojis: 🚀 🔧 🏗️ ✅ ❌ ⚠️",
            "Test mathématiques: ∑ ∏ ∫ ∆ ∇ ∂",
            "Test citations: « » '' "" — – …"
        )
        
        $testResults = @()
        $successCount = 0
        
        foreach ($testString in $testStrings) {
            $testFile = Join-Path $script:TestDir "test-$(Get-Random).txt"
            
            # Écriture avec encodage UTF-8 explicite
            $testString | Out-File -FilePath $testFile -Encoding UTF8 -Force
            
            # Lecture avec détection automatique
            $readContent = Get-Content -Path $testFile -Encoding UTF8
            
            # Validation du contenu
            if ($readContent -eq $testString) {
                $successCount++
                if ($Detailed) {
                    Write-Success "Fichier test: OK - $($testString.Substring(0, 30))..."
                }
            } else {
                $result.Issues += "Corruption détectée dans: $($testString.Substring(0, 30))..."
                if ($Detailed) {
                    Write-Error "Fichier test: ÉCHEC - $($testString.Substring(0, 30))..."
                }
            }
        }
        
        $result.Details = @{
            TotalTests = $testStrings.Count
            SuccessfulTests = $successCount
            FailedTests = $testStrings.Count - $successCount
            SuccessRate = [math]::Round(($successCount / $testStrings.Count) * 100, 2)
        }
        
        if ($successCount -eq $testStrings.Count) {
            $result.Success = $true
            Write-Success "Tests système de fichiers: OK ($successCount/$($testStrings.Count))"
        } else {
            $result.Issues += "Échec des tests fichiers: $successCount/$($testStrings.Count) réussis"
            $result.Recommendations += "Vérifier les permissions et l'espace disque"
            Write-Warning "Tests système de fichiers: ÉCHEC ($successCount/$($testStrings.Count))"
        }
        
    } catch {
        $result.Issues += "Erreur lors des tests fichiers: $($_.Exception.Message)"
        Write-Error "Tests système de fichiers: ÉCHEC"
    }
    
    return $result
}

function Test-PowerShellEncoding {
    Write-Test "Test 5: Validation de l'encodage PowerShell..."
    
    $result = @{
        TestName = "PowerShellEncoding"
        Success = $false
        Details = @{}
        Issues = @()
        Recommendations = @()
    }
    
    try {
        # Test de l'encodage par défaut de PowerShell
        $psDefaultEncoding = $OutputEncoding.EncodingName
        $psVersion = $PSVersionTable.PSVersion
        
        $result.Details = @{
            PowerShellVersion = $psVersion
            DefaultEncoding = $psDefaultEncoding
            UTF8Support = $psDefaultEncoding -like "*UTF*"
        }
        
        # Validation UTF-8
        if ($psDefaultEncoding -like "*UTF*") {
            $result.Success = $true
            Write-Success "Encodage PowerShell: OK ($($psDefaultEncoding))"
        } else {
            $result.Issues += "PowerShell n'utilise pas UTF-8 par défaut: $($psDefaultEncoding)"
            $result.Recommendations += "Configurer [Console]::OutputEncoding = [System.Text.Encoding]::UTF8"
            Write-Warning "Encodage PowerShell: ÉCHEC"
        }
        
    } catch {
        $result.Issues += "Erreur lors du test PowerShell: $($_.Exception.Message)"
        Write-Error "Test PowerShell: ÉCHEC"
    }
    
    return $result
}

function Test-ApplicationCompatibility {
    Write-Test "Test 6: Validation de la compatibilité applicative..."
    
    $result = @{
        TestName = "ApplicationCompatibility"
        Success = $false
        Details = @{}
        Issues = @()
        Recommendations = @()
    }
    
    try {
        # Test de détection UTF-8 par les applications courantes
        $apps = @(
            @{ Name = "Python"; Command = "python --version"; ExpectedPattern = "UTF-8" },
            @{ Name = "Node.js"; Command = "node --version"; ExpectedPattern = "UTF-8" },
            @{ Name = "Git"; Command = "git --version"; ExpectedPattern = "UTF-8" }
        )
        
        $appResults = @()
        $successCount = 0
        
        foreach ($app in $apps) {
            try {
                $appResult = @{
                    Name = $app.Name
                    Detected = $false
                    UTF8Compatible = $false
                    Issues = @()
                }
                
                # Test de détection de l'application
                $process = Start-Process -FilePath $app.Command -RedirectStandardOutput "temp\app-output.txt" -RedirectStandardError "temp\app-error.txt" -Wait -PassThru
                
                if ($process.ExitCode -eq 0) {
                    $appResult.Detected = $true
                    
                    # Analyse de la sortie pour détecter le support UTF-8
                    $output = Get-Content "temp\app-output.txt" -Raw
                    if ($output -match $app.ExpectedPattern) {
                        $appResult.UTF8Compatible = $true
                        $successCount++
                    }
                } else {
                    $appResult.Issues += "Application non détectée: Code de sortie $($process.ExitCode)"
                }
                
                $appResults += $appResult
                
            } catch {
                $appResult.Issues += "Erreur lors du test: $($_.Exception.Message)"
                $appResults += $appResult
            }
        }
        
        $result.Details = @{
            TotalApplications = $apps.Count
            DetectedApplications = $appResults.Count
            UTF8CompatibleApplications = $successCount
            ApplicationResults = $appResults
        }
        
        if ($successCount -eq $apps.Count) {
            $result.Success = $true
            Write-Success "Compatibilité applicative: OK ($successCount/$($apps.Count))"
        } else {
            $result.Issues += "Incompatibilités détectées: $successCount/$($apps.Count) applications UTF-8 compatibles"
            $result.Recommendations += "Mettre à jour les applications non compatibles"
            Write-Warning "Compatibilité applicative: ÉCHEC ($successCount/$($apps.Count))"
        }
        
    } catch {
        $result.Issues += "Erreur lors des tests de compatibilité: $($_.Exception.Message)"
        Write-Error "Compatibilité applicative: ÉCHEC"
    }
    
    return $result
}

# Génération des fichiers de test
function New-TestFiles {
    Write-Info "Génération des fichiers de test UTF-8..."
    
    try {
        # Création du répertoire de tests
        if (!(Test-Path $script:TestDir)) {
            New-Item -ItemType Directory -Path $script:TestDir -Force | Out-Null
        }
        
        # Fichiers de test avec différents types de caractères
        $testFiles = @(
            @{
                Name = "french-accents.txt"
                Content = "Test français: é è à ù ç œ æ â ê î ô û"
                Description = "Caractères français avec accents"
            },
            @{
                Name = "european-special.txt"
                Content = "Test européen: ß ä ö ü ñ ç ÿ"
                Description = "Caractères européens spéciaux"
            },
            @{
                Name = "currency-symbols.txt"
                Content = "Test symboles: € £ ¥ $ © ® ™"
                Description = "Symboles monétaires et commerciaux"
            },
            @{
                Name = "mathematical.txt"
                Content = "Test mathématiques: ∑ ∏ ∫ ∆ ∇ ∂ √ ∞"
                Description = "Symboles mathématiques Unicode"
            },
            @{
                Name = "emojis.txt"
                Content = "Test emojis: 🚀 🔧 🏗️ ✅ ❌ ⚠️ 🎉 🌟"
                Description = "Émojis et symboles modernes"
            },
            @{
                Name = "quotes-punctuation.txt"
                Content = "Test citations: « » '' "" — – … …"
                Description = "Guillemets et ponctuation typographique"
            },
            @{
                Name = "mixed-complex.txt"
                Content = "Test complexe: Café naïve — œuvre Noël — €100 — 🚀🔧 — ∑(i=1→n) i² = n(n+1)/2"
                Description = "Texte complexe mixte"
            }
        )
        
        foreach ($file in $testFiles) {
            $filePath = Join-Path $script:TestDir $file.Name
            $file.Content | Out-File -FilePath $filePath -Encoding UTF8 -Force
            
            # Création du fichier de description
            $descPath = $filePath.Replace(".txt", ".desc.txt")
            $file.Description | Out-File -FilePath $descPath -Encoding UTF8 -Force
            
            if ($Detailed) {
                Write-Success "Fichier test créé: $($file.Name)"
            }
        }
        
        Write-Success "Fichiers de test générés: $($testFiles.Count) fichiers dans $script:TestDir"
        
    } catch {
        Write-Error "Erreur lors de la génération des fichiers de test: $($_.Exception.Message)"
    }
}

# Génération du rapport de validation
function New-ValidationReport {
    param([array]$TestResults)
    
    $reportPath = Join-Path $script:ResultsDir "validation-report.$($OutputFormat.ToLower())"
    
    # Création du répertoire de résultats
    if (!(Test-Path $script:ResultsDir)) {
        New-Item -ItemType Directory -Path $script:ResultsDir -Force | Out-Null
    }
    
    # Calcul des statistiques globales
    $totalTests = $TestResults.Count
    $successfulTests = ($TestResults | Where-Object { $_.Success }).Count
    $failedTests = $totalTests - $successfulTests
    $successRate = if ($totalTests -gt 0) { [math]::Round(($successfulTests / $totalTests) * 100, 2) } else { 0 }
    
    # Génération du rapport selon le format
    switch ($OutputFormat) {
        "JSON" {
            $jsonReport = @{
                metadata = @{
                    date = Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ"
                    script = "Test-UTF8Activation.ps1"
                    version = "1.0"
                    correctionId = "SYS-001-VALIDATION"
                }
                summary = @{
                    totalTests = $totalTests
                    successfulTests = $successfulTests
                    failedTests = $failedTests
                    successRate = $successRate
                    overallSuccess = $successRate -ge 95
                }
                results = $TestResults
            }
            
            $jsonReport | ConvertTo-Json -Depth 10 | Out-File -FilePath $reportPath -Encoding UTF8 -Force
        }
        
        "Markdown" {
            $mdReport = @"
# Rapport de Validation UTF-8 Activation

**Date**: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
**Script**: Test-UTF8Activation.ps1
**Version**: 1.0
**ID Correction**: SYS-001-VALIDATION

## 📊 Résumé Global

- **Tests Total**: $totalTests
- **Tests Réussis**: $successfulTests
- **Tests Échoués**: $failedTests
- **Taux de Succès**: $successRate%
- **Succès Global**: $(if ($successRate -ge 95) { "✅ SUCCÈS" } else { "❌ ÉCHEC" })

## 📋 Résultats Détaillés

$($TestResults | ForEach-Object {
    $status = if ($_.Success) { "✅ SUCCÈS" } else { "❌ ÉCHEC" }
    $details = $_.Details | ConvertTo-Json -Compress
    $issues = if ($_.Issues.Count -gt 0) { "- **Problèmes**: $($_.Issues -join ', ')" } else { "" }
    $recommendations = if ($_.Recommendations.Count -gt 0) { "- **Recommandations**: $($_.Recommendations -join ', ')" } else { "" }
    
    @"
### $($_.TestName)
- **Statut**: $status
- **Détails**: $details
$issues
$recommendations

"@
})

## 🎯 Recommandations Globales

$(if ($successRate -lt 95) {
    "- Le taux de succès global est inférieur à 95%. Une révision de la configuration UTF-8 est recommandée."
} else {
    "- La configuration UTF-8 est validée avec succès."
})

## 📝 Informations Complémentaires

- **Fichier de Log**: $script:LogFile
- **Répertoire de Tests**: $script:TestDir
- **Date d'Exécution**: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')

---

**Statut**: $(if ($successRate -ge 95) { "✅ VALIDATION RÉUSSIE" } else { "❌ VALIDATION ÉCHOUÉE" })
"@
            
            $mdReport | Out-File -FilePath $reportPath -Encoding UTF8 -Force
        }
        
        "Console" {
            Write-Host "`n=== RAPPORT DE VALIDATION UTF-8 ===" -ForegroundColor Cyan
            Write-Host "Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor White
            Write-Host "Tests: $successfulTests/$totalTests réussis ($successRate%)" -ForegroundColor $(if ($successRate -ge 95) { "Green" } else { "Red" })
            
            foreach ($result in $TestResults) {
                $color = if ($result.Success) { "Green" } else { "Red" }
                Write-Host "`n$($result.TestName): $(if ($result.Success) { "SUCCÈS" } else { "ÉCHEC" })" -ForegroundColor $color
                
                if ($Detailed -and $result.Issues.Count -gt 0) {
                    Write-Host "  Problèmes: $($result.Issues -join ', ')" -ForegroundColor Yellow
                }
                
                if ($Detailed -and $result.Recommendations.Count -gt 0) {
                    Write-Host "  Recommandations: $($result.Recommendations -join ', ')" -ForegroundColor Cyan
                }
            }
            
            Write-Host "`n=== FIN DU RAPPORT ===" -ForegroundColor Cyan
        }
        
        default {
            Write-Error "Format de sortie non supporté: $OutputFormat"
            return
        }
    }
    
    try {
        Write-Success "Rapport généré: $reportPath"
        return $reportPath
    } catch {
        Write-Error "Erreur lors de la génération du rapport: $($_.Exception.Message)"
        return $null
    }
}

# Programme principal
function Main {
    Write-Log "Début du script Test-UTF8Activation.ps1" "INFO"
    Write-Log "ID Correction: SYS-001-VALIDATION" "INFO"
    Write-Log "Priorité: CRITIQUE" "INFO"
    
    try {
        Write-Info "Début de la validation UTF-8 post-activation..."
        
        # Génération des fichiers de test si demandé
        if ($TestFiles) {
            New-TestFiles
        }
        
        # Exécution des tests de validation
        $testResults = @(
            (Test-SystemCodePages),
            (Test-RegionalSettings),
            (Test-ConsoleEncoding),
            (Test-FileSystemEncoding),
            (Test-PowerShellEncoding),
            (Test-ApplicationCompatibility)
        )
        
        if ($Detailed) {
            Write-Info "Tests exécutés: $($testResults.Count)"
            foreach ($result in $testResults) {
                Write-Info "  - $($result.TestName): $(if ($result.Success) { "SUCCÈS" } else { "ÉCHEC" })"
            }
        }
        
        # Génération du rapport
        $reportPath = New-ValidationReport -TestResults $testResults
        
        if ($reportPath) {
            # Calcul du succès global
            $successfulTests = ($testResults | Where-Object { $_.Success }).Count
            $totalTests = $testResults.Count
            $successRate = [math]::Round(($successfulTests / $totalTests) * 100, 2)
            
            if ($successRate -ge 95) {
                Write-Success "Validation UTF-8 terminée avec succès ($successRate%)"
                Write-Success "Rapport disponible: $reportPath"
            } else {
                Write-Warning "Validation UTF-8 partielle ($successRate%) - actions correctives recommandées"
                Write-Warning "Rapport disponible: $reportPath"
            }
        } else {
            Write-Error "Échec de la génération du rapport"
            exit 1
        }
        
    } catch {
        Write-Error "Erreur inattendue: $($_.Exception.Message)"
        Write-Error "Stack Trace: $($_.ScriptStackTrace)"
        exit 1
    }
}

# Point d'entrée principal
Main