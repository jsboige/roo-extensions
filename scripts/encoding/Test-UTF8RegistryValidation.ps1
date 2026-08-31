<#
.SYNOPSIS
    Script de validation du registre UTF-8 pour Windows 11 Pro français
.DESCRIPTION
    Ce script valide la configuration du registre Windows pour l'encodage UTF-8.
    Il effectue des tests complets sur les pages de code système, la configuration console,
    et les paramètres régionaux pour s'assurer que UTF-8 (65001) est correctement appliqué.
.PARAMETER Detailed
    Affiche des informations détaillées pendant la validation
.PARAMETER OutputFormat
    Format de sortie du rapport (JSON, Markdown, Console)
.PARAMETER TestFiles
    Génère des fichiers de test pour validation manuelle
.PARAMETER CompareWithBackup
    Compare avec un backup de registre si spécifié
.PARAMETER BackupPath
    Chemin vers le backup de registre à comparer
.EXAMPLE
    .\Test-UTF8RegistryValidation.ps1
.EXAMPLE
    .\Test-UTF8RegistryValidation.ps1 -Detailed -OutputFormat JSON
.EXAMPLE
    .\Test-UTF8RegistryValidation.ps1 -TestFiles -CompareWithBackup -BackupPath "backups\registry-backup-20251030.reg"
.NOTES
    Auteur: Roo Architect Complex Mode
    Version: 1.0
    Date: 2025-10-30
    ID Correction: SYS-002-VALIDATION
    Priorité: CRITIQUE
    Requiert: Windows 10+ avec registre modifié
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [switch]$Detailed,
    
    [Parameter(Mandatory = $false)]
    [ValidateSet("JSON", "Markdown", "Console")]
    [string]$OutputFormat = "Console",
    
    [Parameter(Mandatory = $false)]
    [switch]$TestFiles,
    
    [Parameter(Mandatory = $false)]
    [switch]$CompareWithBackup,
    
    [Parameter(Mandatory = $false)]
    [string]$BackupPath
)

# Configuration du script
$script:LogFile = "logs\Test-UTF8RegistryValidation-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
$script:TestDir = "temp\utf8-registry-tests"
$script:ResultsDir = "results\utf8-registry-validation-$(Get-Date -Format 'yyyyMMdd-HHmmss')"

# Constantes de validation
$EXPECTED_UTF8_CODEPAGE = 65001
$EXPECTED_LOCALE_NAME = "fr-FR"
$EXPECTED_LOCALE_HEX = "0000040C"

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
            "DETAIL" { "White" }
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

# Tests de validation du registre
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
        $validACP = ($codePages.ACP -eq $EXPECTED_UTF8_CODEPAGE)
        $validOEMCP = ($codePages.OEMCP -eq $EXPECTED_UTF8_CODEPAGE)
        $validMACCP = ($codePages.MACCP -eq $EXPECTED_UTF8_CODEPAGE)
        
        if ($validACP -and $validOEMCP -and $validMACCP) {
            $result.Success = $true
            Write-Success "Pages de code système: OK (ACP=$($codePages.ACP), OEMCP=$($codePages.OEMCP), MACCP=$($codePages.MACCP))"
        } else {
            $result.Issues += "Pages de code incorrectes: ACP=$($codePages.ACP), OEMCP=$($codePages.OEMCP), MACCP=$($codePages.MACCP)"
            $result.Recommendations += "Les pages de code doivent être 65001 pour UTF-8"
            Write-Warning "Pages de code système: ÉCHEC"
        }
        
    } catch {
        $result.Issues += "Erreur lors de la lecture des pages de code: $($_.Exception.Message)"
        Write-Error "Test pages de code: ÉCHEC"
    }
    
    return $result
}

function Test-ConsoleSettings {
    Write-Test "Test 2: Validation des paramètres console..."
    
    $result = @{
        TestName = "ConsoleSettings"
        Success = $false
        Details = @{}
        Issues = @()
        Recommendations = @()
    }
    
    try {
        $consolePath = "HKCU:\Console"
        if (-not (Test-Path $consolePath)) {
            $result.Issues += "Clé de registre console introuvable"
            return $result
        }
        
        $console = Get-ItemProperty -Path $consolePath
        $result.Details = $console
        
        # Validation UTF-8
        $validCodePage = ($console.CodePage -eq $EXPECTED_UTF8_CODEPAGE)
        $validFaceName = ($console.FaceName -eq "Consolas")
        
        if ($validCodePage -and $validFaceName) {
            $result.Success = $true
            Write-Success "Paramètres console: OK (CodePage=$($console.CodePage), FaceName=$($console.FaceName))"
        } else {
            $result.Issues += "Paramètres console invalides: CodePage=$($console.CodePage), FaceName=$($console.FaceName)"
            $result.Recommendations += "Configurer CodePage=65001 et FaceName=Consolas"
            Write-Warning "Paramètres console: ÉCHEC"
        }
        
    } catch {
        $result.Issues += "Erreur lors de la lecture des paramètres console: $($_.Exception.Message)"
        Write-Error "Test paramètres console: ÉCHEC"
    }
    
    return $result
}

function Test-InternationalSettings {
    Write-Test "Test 3: Validation des paramètres internationaux..."
    
    $result = @{
        TestName = "InternationalSettings"
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
        
        $intl = Get-ItemProperty -Path $intlPath
        $result.Details = $intl
        
        # Validation UTF-8
        $validLocaleName = ($intl.LocaleName -eq $EXPECTED_LOCALE_NAME)
        $validLocale = ($intl.Locale -eq $EXPECTED_LOCALE_HEX)
        
        if ($validLocaleName -and $validLocale) {
            $result.Success = $true
            Write-Success "Paramètres internationaux: OK (LocaleName=$($intl.LocaleName), Locale=$($intl.Locale))"
        } else {
            $result.Issues += "Paramètres internationaux invalides: LocaleName=$($intl.LocaleName), Locale=$($intl.Locale))"
            $result.Recommendations += "Configurer LocaleName=$EXPECTED_LOCALE_NAME et Locale=$EXPECTED_LOCALE_HEX"
            Write-Warning "Paramètres internationaux: ÉCHEC"
        }
        
    } catch {
        $result.Issues += "Erreur lors de la lecture des paramètres internationaux: $($_.Exception.Message)"
        Write-Error "Test paramètres internationaux: ÉCHEC"
    }
    
    return $result
}

function Test-RegistryConsistency {
    Write-Test "Test 4: Validation de la cohérence du registre..."
    
    $result = @{
        TestName = "RegistryConsistency"
        Success = $false
        Details = @{}
        Issues = @()
        Recommendations = @()
    }
    
    try {
        # Test de cohérence entre les différentes sections du registre
        $codePagePath = "HKLM:\SYSTEM\CurrentControlSet\Control\Nls\CodePage"
        $consolePath = "HKCU:\Console"
        $intlPath = "HKCU:\Control Panel\International"
        
        $paths = @{
            CodePages = $codePagePath
            Console = $consolePath
            International = $intlPath
        }
        
        $allPathsExist = $true
        foreach ($path in $paths.GetEnumerator()) {
            if (-not (Test-Path $path.Value)) {
                $allPathsExist = $false
                break
            }
        }
        
        if (-not $allPathsExist) {
            $result.Issues += "Certaines clés de registre sont manquantes"
            return $result
        }
        
        # Lecture des valeurs actuelles
        $codePages = Get-ItemProperty -Path $codePagePath
        $console = Get-ItemProperty -Path $consolePath
        $intl = Get-ItemProperty -Path $intlPath
        
        # Validation de cohérence UTF-8
        $consistentUTF8 = ($codePages.ACP -eq $EXPECTED_UTF8_CODEPAGE -and 
                        $codePages.OEMCP -eq $EXPECTED_UTF8_CODEPAGE -and 
                        $codePages.MACCP -eq $EXPECTED_UTF8_CODEPAGE -and 
                        $console.CodePage -eq $EXPECTED_UTF8_CODEPAGE -and 
                        $intl.LocaleName -eq $EXPECTED_LOCALE_NAME -and 
                        $intl.Locale -eq $EXPECTED_LOCALE_HEX)
        
        $result.Details = @{
            CodePages = $codePages
            Console = $console
            International = $intl
            ConsistentUTF8 = $consistentUTF8
        }
        
        if ($consistentUTF8) {
            $result.Success = $true
            Write-Success "Cohérence du registre: OK (toutes les clés UTF-8)"
        } else {
            $result.Issues += "Incohérence UTF-8 détectée dans le registre"
            $result.Recommendations += "Exécuter Set-UTF8RegistryStandard.ps1 pour corriger les incohérences"
            Write-Warning "Cohérence du registre: ÉCHEC"
        }
        
    } catch {
        $result.Issues += "Erreur lors du test de cohérence: $($_.Exception.Message)"
        Write-Error "Test cohérence: ÉCHEC"
    }
    
    return $result
}

function Test-RegistryPermissions {
    Write-Test "Test 5: Validation des permissions du registre..."
    
    $result = @{
        TestName = "RegistryPermissions"
        Success = $false
        Details = @{}
        Issues = @()
        Recommendations = @()
    }
    
    try {
        # Test d'écriture dans une clé de test
        $testPath = "HKCU:\Software\UTF8RegistryTest"
        $testValue = "Test-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
        
        try {
            New-Item -Path $testPath -Force | Out-Null
            Set-ItemProperty -Path $testPath -Name "TestValue" -Value $testValue -Type String -Force
            Remove-Item -Path $testPath -Force
            $result.Success = $true
            Write-Success "Permissions du registre: OK (écriture/lecture/suppression possible)"
        } catch {
            $result.Issues += "Permissions insuffisantes pour modifier le registre"
            $result.Recommendations += "Exécuter en tant qu'administrateur"
            Write-Warning "Permissions du registre: ÉCHEC"
        }
        
    } catch {
        $result.Issues += "Erreur lors du test de permissions: $($_.Exception.Message)"
        Write-Error "Test permissions: ÉCHEC"
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
        # Test de détection UTF-8 par les applications système
        $apps = @(
            @{ Name = "Explorateur Windows"; Command = "explorer.exe --version"; ExpectedPattern = "UTF-8" },
            @{ Name = "Bloc-notes"; Command = "notepad.exe --version"; ExpectedPattern = "UTF-8" },
            @{ Name = "Éditeur de registre"; Command = "regedit.exe --version"; ExpectedPattern = "UTF-8" }
        )
        
        $appResults = @()
        $successCount = 0
        
        foreach ($app in $apps) {
            try {
                $process = Start-Process -FilePath $app.Command -RedirectStandardOutput "temp\app-output.txt" -RedirectStandardError "temp\app-error.txt" -Wait -PassThru
                
                if ($process.ExitCode -eq 0) {
                    $output = Get-Content "temp\app-output.txt" -Raw
                    if ($output -match $app.ExpectedPattern) {
                        $successCount++
                        $appResults += @{
                            Name = $app.Name
                            Detected = $true
                            UTF8Compatible = $true
                            Issues = @()
                        }
                    } else {
                        $appResults += @{
                            Name = $app.Name
                            Detected = $true
                            UTF8Compatible = $false
                            Issues = @("Sortie inattendue: Code de sortie $($process.ExitCode)")
                        }
                    }
                } else {
                    $appResults += @{
                        Name = $app.Name
                        Detected = $false
                        UTF8Compatible = $false
                        Issues = @("Application non détectée: Code de sortie $($process.ExitCode)")
                        }
                }
                
            } catch {
                $appResults += @{
                    Name = $app.Name
                    Detected = $false
                    UTF8Compatible = $false
                    Issues = @("Erreur lors du test: $($_.Exception.Message)")
                }
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
            Write-Success "Compatibilité applicative: OK ($successCount/$($apps.Count) applications UTF-8 compatibles)"
        } else {
            $result.Issues += "Incompatibilités détectées: $successCount/$($apps.Count) applications UTF-8 compatibles"
            $result.Recommendations += "Mettre à jour les applications non compatibles"
            Write-Warning "Compatibilité applicative: ÉCHEC"
        }
        
    } catch {
        $result.Issues += "Erreur lors des tests de compatibilité: $($_.Exception.Message)"
        Write-Error "Test compatibilité applicative: ÉCHEC"
    }
    
    return $result
}

# Comparaison avec backup
function Compare-WithBackup {
    param([string]$BackupPath)
    
    Write-Info "Comparaison avec le backup: $BackupPath"
    
    if (-not (Test-Path $BackupPath)) {
        Write-Warning "Fichier de backup introuvable: $BackupPath"
        return @{}
    }
    
    try {
        $backupContent = Get-Content -Path $BackupPath -Raw
        $currentSettings = @{}
        
        # Extraction des valeurs actuelles
        $codePagePath = "HKLM:\SYSTEM\CurrentControlSet\Control\Nls\CodePage"
        $consolePath = "HKCU:\Console"
        $intlPath = "HKCU:\Control Panel\International"
        
        if (Test-Path $codePagePath) { $currentSettings.CodePages = Get-ItemProperty -Path $codePagePath }
        if (Test-Path $consolePath) { $currentSettings.Console = Get-ItemProperty -Path $consolePath }
        if (Test-Path $intlPath) { $currentSettings.International = Get-ItemProperty -Path $intlPath }
        
        # Analyse simple des différences
        $differences = @()
        
        # Comparaison des pages de code
        if ($backupContent -match '"ACP"=dword:0000fde9') {
            $currentACP = if ($currentSettings.CodePages) { $currentSettings.CodePages.ACP } else { "Non trouvé" }
            if ($currentACP -ne "Non trouvé") {
                $differences += "ACP: Backup=65001, Actuel=$($currentACP)"
            }
        }
        
        # Comparaison des paramètres console
        if ($backupContent -match '"CodePage"=dword:0000fde9') {
            $currentConsoleCP = if ($currentSettings.Console) { $currentSettings.Console.CodePage } else { "Non trouvé" }
            if ($currentConsoleCP -ne "Non trouvé") {
                $differences += "Console CodePage: Backup=65001, Actuel=$($currentConsoleCP)"
            }
        }
        
        # Comparaison des paramètres internationaux
        if ($backupContent -match '"LocaleName"="fr-FR"') {
            $currentLocale = if ($currentSettings.International) { $currentSettings.International.LocaleName } else { "Non trouvé" }
            if ($currentLocale -ne "Non trouvé") {
                $differences += "LocaleName: Backup=fr-FR, Actuel=$($currentLocale)"
            }
        }
        
        return @{
            BackupPath = $BackupPath
            CurrentSettings = $currentSettings
            Differences = $differences
            ComparisonDate = Get-Date
        }
        
    } catch {
        Write-Error "Erreur lors de la comparaison avec le backup: $($_.Exception.Message)"
        return @{}
    }
}

# Génération des fichiers de test
function New-TestFiles {
    Write-Info "Génération des fichiers de test UTF-8..."
    
    try {
        # Création du répertoire de tests
        if (!(Test-Path $script:TestDir)) {
            New-Item -ItemType Directory -Path $script:TestDir -Force | Out-Null
        }
        
        # Fichiers de test avec différents types de caractères UTF-8
        $testFiles = @(
            @{
                Name = "french-accents.txt"
                Content = "Test français: é è à ù ç œ æ â ê î ô û 🚀"
                Description = "Caractères français avec accents"
            },
            @{
                Name = "european-special.txt"
                Content = "Test européen: ß ä ö ü ñ ç ÿ € £ ¥"
                Description = "Caractères européens spéciaux"
            },
            @{
                Name = "mathematical.txt"
                Content = "Test mathématiques: ∑ ∏ ∫ ∆ ∇ ∂ √ ∞"
                Description = "Symboles mathématiques Unicode"
            },
            @{
                Name = "currency-symbols.txt"
                Content = "Test symboles: € £ ¥ © ® ™"
                Description = "Symboles monétaires et commerciaux"
            },
            @{
                Name = "registry-test.txt"
                Content = "Test registre UTF-8: HKEY_CURRENT_USER\Software\UTF8Test"
                Description = "Test d'accès au registre avec caractères UTF-8"
            }
            @{
                Name = "console-test.txt"
                Content = "Test console UTF-8: chcp 65001 && echo Test UTF-8: é è à ù ç"
                Description = "Test de la console avec commande chcp"
            }
            @{
                Name = "mixed-complex.txt"
                Content = "Test complexe: Café naïve — œuvre Noël — €100 — 🚀🔧 — ∑(i=1→n) i² = n(n+1)/2"
                Description = "Texte complexe mixte avec caractères UTF-8 variés"
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
    param([array]$TestResults, [hashtable]$BackupComparison)
    
    $reportPath = Join-Path $script:ResultsDir "registry-validation-report.$($OutputFormat.ToLower())"
    
    # Création du répertoire de résultats
    if (!(Test-Path $script:ResultsDir)) {
        New-Item -ItemType Directory -Path $script:ResultsDir -Force | Out-Null
    }
    
    # Calcul des statistiques globales
    $totalTests = $TestResults.Count
    $successfulTests = ($TestResults | Where-Object { $_.Success }).Count
    $failedTests = $totalTests - $successfulTests
    $successRate = if ($totalTests -gt 0) { [math]::Round(($successfulTests / $totalTests) * 100, 2) } else { 0 }
    $overallSuccess = $successRate -ge 95
    
    # Génération du rapport selon le format
    switch ($OutputFormat) {
        "JSON" {
            $jsonReport = @{
                metadata = @{
                    date = Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ"
                    script = "Test-UTF8RegistryValidation.ps1"
                    version = "1.0"
                    correctionId = "SYS-002-VALIDATION"
                    backupComparison = $BackupComparison
                }
                summary = @{
                    totalTests = $totalTests
                    successfulTests = $successfulTests
                    failedTests = $failedTests
                    successRate = $successRate
                    overallSuccess = $overallSuccess
                }
                results = $TestResults
            }
            
            $jsonReport | ConvertTo-Json -Depth 10 | Out-File -FilePath $reportPath -Encoding UTF8 -Force
        }
        
        "Markdown" {
            $mdReport = @"
# Rapport de Validation du Registre UTF-8

**Date**: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
**Script**: Test-UTF8RegistryValidation.ps1
**Version**: 1.0
**ID Correction**: SYS-002-VALIDATION

## 📊 Résumé Exécutif

### Métriques Globales
- **Tests Total**: $totalTests
- **Tests Réussis**: $successfulTests
- **Tests Échoués**: $failedTests
- **Taux de Succès**: $successRate%
- **Statut Global**: $(if ($overallSuccess) { "✅ SUCCÈS" } else { "❌ ÉCHEC" })

## 📋 Résultats Détaillés

$($TestResults | ForEach-Object {
    "### $($_.TestName)"
    "#### Statut"
    "- **Résultat**: $(if ($_.Success) { "✅ SUCCÈS" } else { "❌ ÉCHEC" })"
    "#### Détails Techniques"
    $($_.Details | ForEach-Object {
        "- **$($_.Key)**: $($_.Value)"
    })
    $(if ($_.Issues.Count -gt 0) {
        "#### Problèmes Détectés"
        $($_.Issues | ForEach-Object {
            "- $($_)"
        })
    })
    $(if ($_.Recommendations.Count -gt 0) {
        "#### Recommandations"
        $($_.Recommendations | ForEach-Object {
            "- $($_)"
        })
    })
    ""
})

## 🔄 Comparaison avec Backup

$(if ($BackupComparison) {
    @"
### Fichier de Backup Analysé
- **Chemin**: $($BackupComparison.BackupPath)
- **Date de Comparaison**: $($BackupComparison.ComparisonDate)

### Différences Détectées
$($BackupComparison.Differences | ForEach-Object { "- $($_)" } | Out-String)
"@
} else {
    "### Aucune comparaison de backup effectuée"
})

## 🎯 Recommandations Globales

$(if ($overallSuccess) {
    "- ✅ **Configuration UTF-8 validée**: Le registre est correctement configuré pour UTF-8"
    "- ✅ **Continuer vers Jour 4-4**: Variables Environnement Standardisées"
} else {
    "- ⚠️ **Actions correctives immédiates requises**:"
    "- 1. Réexécuter Set-UTF8RegistryStandard.ps1 avec le paramètre -Force"
    "- 2. Redémarrer le système après application des corrections"
    "- 3. Revalider avec ce script après redémarrage"
    "- 🔄 **Nouvelle validation requise**: Réexécuter ce script après corrections"
})

## 📝 Informations Complémentaires

- **Fichier de Log**: $script:LogFile"
- **Répertoire de Tests**: $script:TestDir
- **Date d'Exécution**: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')

---

**Statut**: $(if ($overallSuccess) { "✅ VALIDATION RÉUSSIE" } else { "⚠️ VALIDATION PARTIELLE - ACTIONS REQUISES" })
**Prochaine Étape**: $(if ($overallSuccess) { "Jour 4-4: Variables Environnement Standardisées" } else { "Correction des problèmes de registre" })
"@
            
            $mdReport | Out-File -FilePath $reportPath -Encoding UTF8 -Force
        }
        
        "Console" {
            Write-Host "`n=== RAPPORT DE VALIDATION DU REGISTRE UTF-8 ===" -ForegroundColor Cyan
            Write-Host "Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor White
            Write-Host "Tests: $successfulTests/$totalTests réussis ($successRate%)" -ForegroundColor $(if ($overallSuccess) { "Green" } else { "Red" })
            
            foreach ($result in $TestResults) {
                $color = if ($result.Success) { "Green" } else { "Red" }
                Write-Host "`n$($result.TestName): $(if ($result.Success) { "SUCCÈS" } else { "ÉCHEC" })" -ForegroundColor $color
                
                if ($Detailed -and $result.Issues.Count -gt 0) {
                    Write-Host "  Problèmes: $($result.Issues.Count)" -ForegroundColor Yellow
                }
            }
            
            Write-Host "`n=== FIN DU RAPPORT ===" -ForegroundColor Cyan
        }
        
        default {
            Write-Error "Format de sortie non supporté: $OutputFormat"
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
    Write-Log "Début du script Test-UTF8RegistryValidation.ps1" "INFO"
    Write-Log "ID Correction: SYS-002-VALIDATION" "INFO"
    Write-Log "Priorité: CRITIQUE" "INFO"
    
    try {
        Write-Info "Début de la validation du registre UTF-8..."
        
        # Génération des fichiers de test si demandé
        if ($TestFiles) {
            New-TestFiles
        }
        
        # Exécution des tests de validation
        $testResults = @(
            (Test-SystemCodePages),
            (Test-ConsoleSettings),
            (Test-InternationalSettings),
            (Test-RegistryConsistency),
            (Test-RegistryPermissions),
            (Test-ApplicationCompatibility)
        )
        
        if ($Detailed) {
            Write-Info "Tests exécutés: $($testResults.Count)"
            foreach ($result in $testResults) {
                Write-Info "  - $($result.TestName): $(if ($result.Success) { "SUCCÈS" } else { "ÉCHEC" })"
            }
        }
        
        # Comparaison avec backup si demandé
        $backupComparison = $null
        if ($CompareWithBackup -and $BackupPath) {
            $backupComparison = Compare-WithBackup -BackupPath $BackupPath
        }
        
        # Génération du rapport
        $reportPath = New-ValidationReport -TestResults $testResults -BackupComparison $backupComparison
        
        if ($reportPath) {
            # Calcul du succès global
            $successfulTests = ($testResults | Where-Object { $_.Success }).Count
            $totalTests = $testResults.Count
            $successRate = if ($totalTests -gt 0) { [math]::Round(($successfulTests / $totalTests) * 100, 2) } else { 0 }
            $overallSuccess = $successRate -ge 95
            
            if ($overallSuccess) {
                Write-Success "Validation du registre UTF-8 terminée avec succès ($successRate%)"
                Write-Success "Rapport généré: $reportPath"
            } else {
                Write-Warning "Validation du registre UTF-8 partielle ($successRate%) - actions correctives requises"
                Write-Warning "Rapport généré: $reportPath"
            }
        } else {
            Write-Error "Échec de la génération du rapport"
        }
        
    } catch {
        Write-Error "Erreur inattendue: $($_.Exception.Message)"
        Write-Error "Stack Trace: $($_.ScriptStackTrace)"
        exit 1
    }
}

# Point d'entrée principal
Main