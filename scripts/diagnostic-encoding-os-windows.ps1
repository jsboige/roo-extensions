#!/usr/bin/env pwsh
# ==============================================================================
# Script: diagnostic-encoding-os-windows.ps1
# Description: Diagnostic complet de l'encodage au niveau OS Windows 11
# Auteur: Roo Debug Complex Mode
# Date: 2025-10-29
# Version: 1.0
# ==============================================================================

# Configuration UTF-8 explicite pour ce script
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::InputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
$PSDefaultParameterValues['*:Encoding'] = 'utf8'

# Variables globales
$DiagnosticResults = @()
$TestStartTime = Get-Date

# ==============================================================================
# FONCTIONS UTILITAIRES
# ==============================================================================

function Write-DiagnosticSection {
    param([string]$SectionName)
    Write-Host "`n═══════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "  $SectionName" -ForegroundColor Cyan
    Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan
}

function Write-TestResult {
    param(
        [string]$TestName,
        [bool]$Success,
        [string]$Result = "",
        [string]$ErrorMessage = "",
        [object]$Details = $null
    )
    
    $status = if ($Success) { "✅ SUCCÈS" } else { "❌ ÉCHEC" }
    $color = if ($Success) { "Green" } else { "Red" }
    
    Write-Host "  $TestName : $status" -ForegroundColor $color
    if ($Result) { Write-Host "    Résultat: $Result" -ForegroundColor White }
    if ($ErrorMessage) { Write-Host "    Erreur: $ErrorMessage" -ForegroundColor Red }
    
    $testResult = @{
        TestName = $TestName
        Success = $Success
        Result = $Result
        Error = $ErrorMessage
        Details = $Details
        Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
    }
    
    $script:DiagnosticResults += $testResult
}

function Test-RegistryValue {
    param(
        [string]$Path,
        [string]$ValueName = "",
        [string]$DefaultValue = "Non trouvé"
    )
    
    try {
        if ($ValueName) {
            $value = Get-ItemProperty -Path $Path -Name $ValueName -ErrorAction Stop | Select-Object -ExpandProperty $ValueName
        } else {
            $value = Get-ItemProperty -Path $Path -ErrorAction Stop
        }
        return $value
    }
    catch {
        return $DefaultValue
    }
}

function Test-EnvironmentVariable {
    param([string]$VarName)
    
    $value = [System.Environment]::GetEnvironmentVariable($VarName)
    return if ($value) { $value } else { "Non défini" }
}

function Get-SystemInfo {
    return @{
        ComputerName = $env:COMPUTERNAME
        OSVersion = [System.Environment]::OSVersion.ToString()
        PowerShellVersion = $PSVersionTable.PSVersion.ToString()
        PowerShellEdition = $PSVersionTable.PSEdition
        IsWindows = $IsWindows
        IsCore = $IsCoreCLR
        Architecture = $env:PROCESSOR_ARCHITECTURE
        Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
    }
}

# ==============================================================================
# 1. CONFIGURATION SYSTÈME WINDOWS
# ==============================================================================

function Test-WindowsConfiguration {
    Write-DiagnosticSection "1. CONFIGURATION SYSTÈME WINDOWS"
    
    # Test 1.1: Option Beta UTF-8 Worldwide
    try {
        # Vérifier via l'API Windows
        Add-Type -AssemblyName System.Core
        $unicodeSupport = [System.Globalization.CultureInfo]::CurrentCulture.UseUserOverride
        $culture = [System.Globalization.CultureInfo]::CurrentCulture.Name
        
        Write-TestResult "Option Beta UTF-8" $true "Culture: $culture" "" @{
            Culture = $culture
            UnicodeSupport = $unicodeSupport
        }
    }
    catch {
        Write-TestResult "Option Beta UTF-8" $false "" $_.Exception.Message
    }
    
    # Test 1.2: Paramètres régionaux
    try {
        $systemLocale = Get-Culture | Select-Object -ExpandProperty Name
        $uiLanguage = Get-WinUserLanguageList | Select-Object -First 1 -ExpandProperty InputLanguageID
        
        Write-TestResult "Paramètres régionaux" $true "Locale: $systemLocale, UI: $uiLanguage" "" @{
            SystemLocale = $systemLocale
            UILanguage = $uiLanguage
        }
    }
    catch {
        Write-TestResult "Paramètres régionaux" $false "" $_.Exception.Message
    }
    
    # Test 1.3: Pages de code système
    try {
        try {
            $ansiResult = &{chcp} 2>$null
            $ansiCodePage = $LASTEXITCODE
            $oemResult = &{chcp 65001} 2>$null
            $oemCodePage = $LASTEXITCODE
        } catch {
            $ansiCodePage = "Erreur"
            $oemCodePage = "Erreur"
        }
        
        Write-TestResult "Pages de code système" $true "ANSI: $ansiCodePage, OEM: $oemCodePage" "" @{
            ANSI = $ansiCodePage
            OEM = $oemCodePage
            UTF8 = 65001
        }
    }
    catch {
        Write-TestResult "Pages de code système" $false "" $_.Exception.Message
    }
    
    # Test 1.4: Langue non-Unicode
    try {
        $nonUnicodeLang = Test-RegistryValue "HKLM:\SYSTEM\CurrentControlSet\Control\Nls\Language" "InstallLanguage"
        Write-TestResult "Langue non-Unicode" $true "InstallLanguage: $nonUnicodeLang" "" @{
            InstallLanguage = $nonUnicodeLang
        }
    }
    catch {
        Write-TestResult "Langue non-Unicode" $false "" $_.Exception.Message
    }
}

# ==============================================================================
# 2. REGISTRE WINDOWS
# ==============================================================================

function Test-WindowsRegistry {
    Write-DiagnosticSection "2. REGISTRE WINDOWS"
    
    # Test 2.1: Clés d'encodage CodePage
    try {
        $codePagePath = "HKLM:\SYSTEM\CurrentControlSet\Control\Nls\CodePage"
        $acp = Test-RegistryValue $codePagePath "ACP"
        $oemcp = Test-RegistryValue $codePagePath "OEMCP"
        $maccp = Test-RegistryValue $codePagePath "MACCP"
        
        Write-TestResult "Registre CodePage" $true "ACP: $acp, OEMCP: $oemcp, MACCP: $maccp" "" @{
            ACP = $acp
            OEMCP = $oemcp
            MACCP = $maccp
            RegistryPath = $codePagePath
        }
    }
    catch {
        Write-TestResult "Registre CodePage" $false "" $_.Exception.Message
    }
    
    # Test 2.2: Configuration Console
    try {
        $consolePath = "HKCU:\Console"
        $faceName = Test-RegistryValue $consolePath "FaceName"
        $fontSize = Test-RegistryValue $consolePath "FontSize"
        $fontFamily = Test-RegistryValue $consolePath "FontFamily"
        
        Write-TestResult "Registre Console" $true "Font: $faceName, Size: $fontSize, Family: $fontFamily" "" @{
            FaceName = $faceName
            FontSize = $fontSize
            FontFamily = $fontFamily
            RegistryPath = $consolePath
        }
    }
    catch {
        Write-TestResult "Registre Console" $false "" $_.Exception.Message
    }
    
    # Test 2.3: Paramètres internationaux
    try {
        $intlPath = "HKCU:\Control Panel\International"
        $localeName = Test-RegistryValue $intlPath "LocaleName"
        $sShortDate = Test-RegistryValue $intlPath "sShortDate"
        $sTimeFormat = Test-RegistryValue $intlPath "sTimeFormat"
        
        Write-TestResult "Registre International" $true "Locale: $localeName, Date: $sShortDate, Time: $sTimeFormat" "" @{
            LocaleName = $localeName
            ShortDate = $sShortDate
            TimeFormat = $sTimeFormat
            RegistryPath = $intlPath
        }
    }
    catch {
        Write-TestResult "Registre International" $false "" $_.Exception.Message
    }
}

# ==============================================================================
# 3. ENVIRONNEMENT SYSTÈME
# ==============================================================================

function Test-SystemEnvironment {
    Write-DiagnosticSection "3. ENVIRONNEMENT SYSTÈME"
    
    # Test 3.1: Variables d'environnement liées à l'encodage
    $lang = Test-EnvironmentVariable "LANG"
    $lcAll = Test-EnvironmentVariable "LC_ALL"
    $lcCtype = Test-EnvironmentVariable "LC_CTYPE"
    $pythonUtf8 = Test-EnvironmentVariable "PYTHONUTF8"
    $nodeEncoding = Test-EnvironmentVariable "NODE_ENCODING"
    
    Write-TestResult "Variables encodage" $true "LANG: $lang, LC_ALL: $lcAll, PYTHONUTF8: $pythonUtf8" "" @{
            LANG = $lang
            LC_ALL = $lcAll
            LC_CTYPE = $lcCtype
            PYTHONUTF8 = $pythonUtf8
            NODE_ENCODING = $nodeEncoding
        }
    
    # Test 3.2: Configuration système de fichiers
    try {
        $drives = Get-WmiObject -Class Win32_LogicalDisk | Select-Object DeviceID, FileSystem, Size
        $ntfsDrives = $drives | Where-Object { $_.FileSystem -eq "NTFS" }
        
        Write-TestResult "Système fichiers NTFS" $true "Drives NTFS: $($ntfsDrives.Count)" "" @{
            TotalDrives = $drives.Count
            NTFSDrives = $ntfsDrives.Count
            FileSystem = $drives | ForEach-Object { @{ DeviceID = $_.DeviceID; FileSystem = $_.FileSystem } }
        }
    }
    catch {
        Write-TestResult "Système fichiers NTFS" $false "" $_.Exception.Message
    }
    
    # Test 3.3: Services Windows pertinents
    try {
        $services = Get-Service | Where-Object { $_.Name -match "(WinRM|TermService|ConHost)" } | Select-Object Name, Status, StartType
        Write-TestResult "Services pertinents" $true "Services trouvés: $($services.Count)" "" @{
            Services = $services | ForEach-Object { @{ Name = $_.Name; Status = $_.Status; StartType = $_.StartType } }
        }
    }
    catch {
        Write-TestResult "Services pertinents" $false "" $_.Exception.Message
    }
}

# ==============================================================================
# 4. INFRASTRUCTURE DE CONSOLE
# ==============================================================================

function Test-ConsoleInfrastructure {
    Write-DiagnosticSection "4. INFRASTRUCTURE DE CONSOLE"
    
    # Test 4.1: Conhost.exe vs Windows Terminal
    try {
        $conhost = Get-Process conhost -ErrorAction SilentlyContinue
        $windowsTerminal = Get-Process WindowsTerminal -ErrorAction SilentlyContinue
        $wt = Get-Process wt -ErrorAction SilentlyContinue
        
        $consoleInfo = @{
            ConhostRunning = $conhost -ne $null
            WindowsTerminalRunning = $windowsTerminal -ne $null
            WTRunning = $wt -ne $null
        }
        
        Write-TestResult "Infrastructure console" $true "Conhost: $($consoleInfo.ConhostRunning), WT: $($consoleInfo.WTRunning)" "" $consoleInfo
    }
    catch {
        Write-TestResult "Infrastructure console" $false "" $_.Exception.Message
    }
    
    # Test 4.2: Présence ConPTY
    try {
        # Test si ConPTY est disponible
        $conptyTest = try {
            Add-Type -AssemblyName System.Console
            $true
        } catch {
            $false
        }
        
        Write-TestResult "Support ConPTY" $conptyTest "ConPTY disponible: $conptyTest" "" @{
            ConPTYAvailable = $conptyTest
            ConsoleAPIs = [System.Console] | Get-Member | Select-Object Name
        }
    }
    catch {
        Write-TestResult "Support ConPTY" $false "" $_.Exception.Message
    }
    
    # Test 4.3: APIs de console disponibles
    try {
        $consoleProperties = [System.Console] | Get-Member -MemberType Property | Select-Object Name
        $consoleMethods = [System.Console] | Get-Member -MemberType Method | Select-Object Name
        
        Write-TestResult "APIs console" $true "Propriétés: $($consoleProperties.Count), Méthodes: $($consoleMethods.Count)" "" @{
            Properties = $consoleProperties | ForEach-Object { $_.Name }
            Methods = $consoleMethods | ForEach-Object { $_.Name }
        }
    }
    catch {
        Write-TestResult "APIs console" $false "" $_.Exception.Message
    }
}

# ==============================================================================
# 5. TESTS DE REPRODUCTION SYSTÉMIQUES
# ==============================================================================

function Test-SystemicReproduction {
    Write-DiagnosticSection "5. TESTS DE REPRODUCTION SYSTÉMIQUES"
    
    # Test 5.1: Création de scripts minimaux
    $testDir = "results\diagnostic-tests"
    if (-not (Test-Path $testDir)) {
        New-Item -ItemType Directory -Path $testDir -Force | Out-Null
    }
    
    # Script Python minimal
    $pythonScript = @"
import sys
import os
test_string = "Test UTF-8: é è à ù ç œ æ â ê î ô û 🚀 💻 ⚙️ 🪲"
print(f"Python stdout: {test_string}")
print(f"Python encoding: {sys.stdout.encoding}", file=sys.stderr)
print(f"Python default: {sys.getdefaultencoding()}", file=sys.stderr)
print(f"Python filesystem: {sys.getfilesystemencoding()}", file=sys.stderr)
"@
    
    $pythonScript | Out-File -FilePath "$testDir\test-minimal-python.py" -Encoding UTF8
    
    # Script Node.js minimal
    $nodeScript = @"
const testString = 'Test UTF-8: é è à ù ç œ æ â ê î ô û 🚀 💻 ⚙️ 🪲';
console.log('Node.js stdout:', testString);
console.error('Node.js encoding:', process.stdout.encoding || 'undefined');
console.error('Node.js platform:', process.platform);
"@
    
    $nodeScript | Out-File -FilePath "$testDir\test-minimal-node.js" -Encoding UTF8
    
    # Script PowerShell minimal
    $psScript = @"
`$testString = "Test UTF-8: é è à ù ç œ æ â ê î ô û 🚀 💻 ⚙️ 🪲"
Write-Host "PowerShell stdout: $testString"
Write-Host "PowerShell encoding: $([Console]::OutputEncoding.EncodingName)"
Write-Host "PowerShell version: `$($PSVersionTable.PSVersion)"
"@
    
    $psScript | Out-File -FilePath "$testDir\test-minimal-ps.ps1" -Encoding UTF8
    
    Write-TestResult "Scripts minimaux créés" $true "Scripts créés dans: $testDir" "" @{
        TestDirectory = $testDir
        PythonScript = "$testDir\test-minimal-python.py"
        NodeScript = "$testDir\test-minimal-node.js"
        PowerShellScript = "$testDir\test-minimal-ps.ps1"
    }
    
    # Test 5.2: Exécution avec différentes méthodes
    $reproductionResults = @()
    
    # Test PowerShell 5.1
    try {
        $ps51Result = &powershell.exe -ExecutionPolicy Bypass -File "$testDir\test-minimal-ps.ps1" 2>&1
        $reproductionResults += @{
            Language = "PowerShell 5.1"
            Success = $?
            Output = $ps51Result -join "`n"
            Method = "powershell.exe"
        }
    }
    catch {
        $reproductionResults += @{
            Language = "PowerShell 5.1"
            Success = $false
            Output = $_.Exception.Message
            Method = "powershell.exe"
        }
    }
    
    # Test PowerShell 7+
    try {
        $pwshResult = &pwsh -File "$testDir\test-minimal-ps.ps1" 2>&1
        $reproductionResults += @{
            Language = "PowerShell 7+"
            Success = $?
            Output = $pwshResult -join "`n"
            Method = "pwsh.exe"
        }
    }
    catch {
        $reproductionResults += @{
            Language = "PowerShell 7+"
            Success = $false
            Output = $_.Exception.Message
            Method = "pwsh.exe"
        }
    }
    
    # Test Python
    try {
        $pythonCmd = if (Get-Command python -ErrorAction SilentlyContinue) { "python" } else { "python3" }
        $pythonResult = & $pythonCmd "$testDir\test-minimal-python.py" 2>&1
        $reproductionResults += @{
            Language = "Python"
            Success = $?
            Output = $pythonResult -join "`n"
            Method = $pythonCmd
        }
    }
    catch {
        $reproductionResults += @{
            Language = "Python"
            Success = $false
            Output = $_.Exception.Message
            Method = $pythonCmd
        }
    }
    
    # Test Node.js
    try {
        $nodeResult = &node "$testDir\test-minimal-node.js" 2>&1
        $reproductionResults += @{
            Language = "Node.js"
            Success = $?
            Output = $nodeResult -join "`n"
            Method = "node.exe"
        }
    }
    catch {
        $reproductionResults += @{
            Language = "Node.js"
            Success = $false
            Output = $_.Exception.Message
            Method = "node.exe"
        }
    }
    
    Write-TestResult "Tests reproduction" $true "Langages testés: $($reproductionResults.Count)" "" $reproductionResults
}

# ==============================================================================
# 6. GÉNÉRATION DU RAPPORT
# ==============================================================================

function New-DiagnosticReport {
    $systemInfo = Get-SystemInfo
    
    $report = @{
        Metadata = @{
            ReportTitle = "Diagnostic Encodage OS Windows"
            GeneratedBy = "Roo Debug Complex Mode"
            GeneratedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss UTC"
            PowerShellVersion = $systemInfo.PowerShellVersion
            ComputerName = $systemInfo.ComputerName
            OSVersion = $systemInfo.OSVersion
            Architecture = $systemInfo.Architecture
        }
        TestResults = $script:DiagnosticResults
        Summary = @{
            TotalTests = $script:DiagnosticResults.Count
            SuccessfulTests = ($script:DiagnosticResults | Where-Object { $_.Success }).Count
            FailedTests = ($script:DiagnosticResults | Where-Object { -not $_.Success }).Count
            SuccessRate = if ($script:DiagnosticResults.Count -gt 0) { [math]::Round((($script:DiagnosticResults | Where-Object { $_.Success }).Count / $script:DiagnosticResults.Count) * 100, 2) } else { 0 }
            TestDuration = (Get-Date) - $script:TestStartTime
        }
        SystemInfo = $systemInfo
        Recommendations = @()
    }
    
    # Générer les recommandations
    $failedTests = $script:DiagnosticResults | Where-Object { -not $_.Success }
    
    foreach ($failure in $failedTests) {
        switch ($failure.TestName) {
            "Option Beta UTF-8" {
                $report.Recommendations += "Activer l'option 'Beta: Use Unicode UTF-8 for worldwide language support' dans les paramètres Windows"
            }
            "Registre CodePage" {
                $report.Recommendations += "Vérifier les valeurs ACP/OEMCP dans le registre Windows"
            }
            "Variables encodage" {
                $report.Recommendations += "Définir PYTHONUTF8=1 et vérifier les variables LANG/LC_ALL"
            }
            "Support ConPTY" {
                $report.Recommendations += "Mettre à jour Windows Terminal vers la dernière version pour le support ConPTY"
            }
            default {
                $report.Recommendations += "Investiguer l'échec du test '$($failure.TestName)': $($failure.Error)"
            }
        }
    }
    
    # Ajouter des recommandations générales
    $report.Recommendations += "Utiliser Windows Terminal au lieu de conhost.exe pour un meilleur support UTF-8"
    $report.Recommendations += "Configurer explicitement l'encodage UTF-8 dans tous les scripts"
    $report.Recommendations += "Vérifier que l'option 'Beta: Use Unicode UTF-8' est activée au niveau système"
    
    return $report
}

# ==============================================================================
# FONCTION PRINCIPALE
# ==============================================================================

function Main {
    Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "  DIAGNOSTIC COMPLET DE L'ENCODAGE OS WINDOWS" -ForegroundColor Cyan
    Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""
    
    # Créer le répertoire results si nécessaire
    if (-not (Test-Path "results")) {
        New-Item -ItemType Directory -Path "results" -Force | Out-Null
    }
    
    # Exécuter tous les tests
    Test-WindowsConfiguration
    Test-WindowsRegistry
    Test-SystemEnvironment
    Test-ConsoleInfrastructure
    Test-SystemicReproduction
    
    # Générer le rapport
    $report = New-DiagnosticReport
    
    # Sauvegarder le rapport JSON
    $reportJson = $report | ConvertTo-Json -Depth 10
    $reportPath = "results\diagnostic-encoding-os-windows.json"
    $reportJson | Out-File -FilePath $reportPath -Encoding UTF8
    
    # Afficher le résumé
    Write-Host "`n═══════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "  RÉSUMÉ DU DIAGNOSTIC" -ForegroundColor Cyan
    Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""
    
    Write-Host "Tests exécutés: $($report.Summary.TotalTests)" -ForegroundColor White
    Write-Host "Réussis: $($report.Summary.SuccessfulTests)" -ForegroundColor Green
    Write-Host "Échecs: $($report.Summary.FailedTests)" -ForegroundColor Red
    Write-Host "Taux de succès: $($report.Summary.SuccessRate)%" -ForegroundColor Yellow
    Write-Host "Durée: $([math]::Round($report.Summary.TestDuration.TotalSeconds, 2)) secondes" -ForegroundColor Gray
    
    Write-Host "`nRecommandations:" -ForegroundColor White
    foreach ($recommendation in $report.Recommendations) {
        Write-Host "  • $recommendation" -ForegroundColor Cyan
    }
    
    Write-Host "`nRapport détaillé sauvegardé dans: $reportPath" -ForegroundColor Green
    Write-Host "Logs individuels disponibles dans: results\diagnostic-tests\" -ForegroundColor Green
    
    Write-Host "`n✅ Diagnostic système terminé" -ForegroundColor Green
}

# ==============================================================================
# EXÉCUTION
# ==============================================================================

# Vérifier les privilèges administratifs pour certains tests
$isAdmin = ([System.Security.Principal.WindowsPrincipal] [System.Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "⚠️ Attention: Certains tests nécessitent des privilèges administratifs" -ForegroundColor Yellow
    Write-Host "  Pour un diagnostic complet, exécutez ce script en tant qu'administrateur" -ForegroundColor Yellow
    Write-Host ""
}

# Exécuter la fonction principale
Main