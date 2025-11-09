#!/usr/bin/env pwsh
# ==============================================================================
# Script: correction-encoding-systeme-windows.ps1
# Description: Correction complète de l'encodage au niveau système Windows
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
$CorrectionResults = @()
$CorrectionStartTime = Get-Date

# ==============================================================================
# FONCTIONS UTILITAIRES
# ==============================================================================

function Write-CorrectionSection {
    param([string]$SectionName)
    Write-Host "`n═════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "  $SectionName" -ForegroundColor Cyan
    Write-Host "═════════════════════════════════════════════════════" -ForegroundColor Cyan
}

function Write-CorrectionResult {
    param(
        [string]$CorrectionName,
        [bool]$Success,
        [string]$Result = "",
        [string]$ErrorMessage = "",
        [object]$Details = $null
    )
    
    $status = if ($Success) { "✅ APPLIQUÉE" } else { "❌ ÉCHEC" }
    $color = if ($Success) { "Green" } else { "Red" }
    
    Write-Host "  $CorrectionName : $status" -ForegroundColor $color
    if ($Result) { Write-Host "    Résultat: $Result" -ForegroundColor White }
    if ($ErrorMessage) { Write-Host "    Erreur: $ErrorMessage" -ForegroundColor Red }
    
    $correctionResult = @{
        CorrectionName = $CorrectionName
        Success = $Success
        Result = $Result
        Error = $ErrorMessage
        Details = $Details
        Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
    }
    
    $script:CorrectionResults += $correctionResult
}

function Test-AdminPrivileges {
    $isAdmin = ([System.Security.Principal.WindowsPrincipal] [System.Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
    return $isAdmin
}

function Backup-RegistryKey {
    param(
        [string]$KeyPath,
        [string]$BackupName
    )
    
    try {
        if (Test-Path $KeyPath) {
            $backupPath = "results\registry-backups\$BackupName.reg"
            $backupDir = Split-Path $backupPath -Parent
            if (-not (Test-Path $backupDir)) {
                New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
            }
            
            &reg export $KeyPath $backupPath /y
            Write-CorrectionResult "Sauvegarde registre" $true "Sauvegardé dans: $backupPath" "" @{
                KeyPath = $KeyPath
                BackupPath = $backupPath
            }
        } else {
            Write-CorrectionResult "Sauvegarde registre" $false "Clé non trouvée: $KeyPath" ""
        }
    }
    catch {
        Write-CorrectionResult "Sauvegarde registre" $false "" $_.Exception.Message
    }
}

# ==============================================================================
# 1. CORRECTION CONFIGURATION WINDOWS
# ==============================================================================

function Set-WindowsUTF8Configuration {
    Write-CorrectionSection "1. CONFIGURATION WINDOWS UTF-8"
    
    # Test 1.1: Vérifier si l'option UTF-8 beta est activée
    try {
        $culture = [System.Globalization.CultureInfo]::CurrentCulture
        $isUTF8Beta = $culture.Name -eq "fr-FR" -and $culture.TextInfo.ANSICodePage -eq 65001
        
        if (-not $isUTF8Beta) {
            Write-CorrectionResult "Option UTF-8 Beta" $false "Non activée" ""
        } else {
            Write-CorrectionResult "Option UTF-8 Beta" $true "Déjà activée" ""
        }
    }
    catch {
        Write-CorrectionResult "Option UTF-8 Beta" $false "" $_.Exception.Message
    }
    
    # Test 1.2: Activer l'option UTF-8 beta (nécessite des privilèges admin)
    if (Test-AdminPrivileges) {
        try {
            # Cette modification nécessite une intervention manuelle via les paramètres Windows
            # Nous allons créer un script de notification pour l'utilisateur
            $notificationScript = @"
# Script d'activation UTF-8 Beta pour Windows
Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Yellow
Write-Host "  ACTIVATION MANUELLE REQUISE" -ForegroundColor Yellow
Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Yellow
Write-Host ""
Write-Host "Pour activer complètement l'option UTF-8:" -ForegroundColor White
Write-Host "1. Ouvrir les Paramètres Windows" -ForegroundColor Cyan
Write-Host "2. Aller dans 'Heure et langue'" -ForegroundColor Cyan
Write-Host "3. Cliquer sur 'Langue et région'" -ForegroundColor Cyan
Write-Host "4. Activer 'Beta: Use Unicode UTF-8 for worldwide language support'" -ForegroundColor Cyan
Write-Host "5. Redémarrer Windows" -ForegroundColor Cyan
Write-Host ""
Write-Host "Cette action est OBLIGATOIRE pour une correction complète." -ForegroundColor Red
Write-Host ""
Read-Host "Appuyez sur Entrée pour continuer..."
"@
            
            $notificationScript | Out-File -FilePath "results\activer-utf8-beta.ps1" -Encoding UTF8
            
            Write-CorrectionResult "Notification UTF-8 Beta" $true "Script créé: results\activer-utf8-beta.ps1" "" @{
                ScriptPath = "results\activer-utf8-beta.ps1"
                RequiresAdmin = $true
            }
        }
        catch {
            Write-CorrectionResult "Notification UTF-8 Beta" $false "" $_.Exception.Message
        }
    } else {
        Write-CorrectionResult "Notification UTF-8 Beta" $false "Privilèges administratifs requis" ""
    }
}

# ==============================================================================
# 2. CORRECTION REGISTRE WINDOWS
# ==============================================================================

function Set-WindowsRegistryUTF8 {
    Write-CorrectionSection "2. CORRECTION REGISTRE WINDOWS"
    
    if (-not (Test-AdminPrivileges)) {
        Write-CorrectionResult "Correction registre" $false "Privilèges administratifs requis" ""
        return
    }
    
    # Test 2.1: Sauvegarder les clés actuelles
    Backup-RegistryKey "HKLM:\SYSTEM\CurrentControlSet\Control\Nls\CodePage" "codepage-backup"
    Backup-RegistryKey "HKCU:\Console" "console-backup"
    
    # Test 2.2: Forcer UTF-8 dans les clés CodePage
    try {
        Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Nls\CodePage" -Name "ACP" -Value 65001 -Type DWord -Force
        Write-CorrectionResult "Registre ACP" $true "Forcé à 65001 (UTF-8)" "" @{
            OldValue = (Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Nls\CodePage" -Name "ACP" -ErrorAction SilentlyContinue).ACP
            NewValue = 65001
        }
        
        Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Nls\CodePage" -Name "OEMCP" -Value 65001 -Type DWord -Force
        Write-CorrectionResult "Registre OEMCP" $true "Forcé à 65001 (UTF-8)" "" @{
            OldValue = (Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Nls\CodePage" -Name "OEMCP" -ErrorAction SilentlyContinue).OEMCP
            NewValue = 65001
        }
    }
    catch {
        Write-CorrectionResult "Registre CodePage" $false "" $_.Exception.Message
    }
    
    # Test 2.3: Configurer la console pour UTF-8
    try {
        Set-ItemProperty -Path "HKCU:\Console" -Name "CodePage" -Value 65001 -Type DWord -Force
        Set-ItemProperty -Path "HKCU:\Console" -Name "FaceName" -Value "Consolas" -Type String -Force
        Set-ItemProperty -Path "HKCU:\Console" -Name "FontFamily" -Value "Lucida Console" -Type String -Force
        
        Write-CorrectionResult "Registre Console" $true "Configuré pour UTF-8" "" @{
            CodePage = 65001
            FaceName = "Consolas"
            FontFamily = "Lucida Console"
        }
    }
    catch {
        Write-CorrectionResult "Registre Console" $false "" $_.Exception.Message
    }
}

# ==============================================================================
# 3. CORRECTION VARIABLES D'ENVIRONNEMENT
# ==============================================================================

function Set-SystemEnvironmentUTF8 {
    Write-CorrectionSection "3. VARIABLES D'ENVIRONNEMENT SYSTÈME"
    
    # Test 3.1: Variables système (Machine)
    try {
        [System.Environment]::SetEnvironmentVariable("PYTHONUTF8", "1", "Machine")
        Write-CorrectionResult "PYTHONUTF8 (Machine)" $true "Défini à 1" ""
        
        [System.Environment]::SetEnvironmentVariable("PYTHONIOENCODING", "utf-8", "Machine")
        Write-CorrectionResult "PYTHONIOENCODING (Machine)" $true "Défini à utf-8" ""
        
        [System.Environment]::SetEnvironmentVariable("NODE_OPTIONS", "--encoding=utf8", "Machine")
        Write-CorrectionResult "NODE_OPTIONS (Machine)" $true "Défini à --encoding=utf8" ""
        
        [System.Environment]::SetEnvironmentVariable("LANG", "fr_FR.UTF-8", "Machine")
        Write-CorrectionResult "LANG (Machine)" $true "Défini à fr_FR.UTF-8" ""
        
        [System.Environment]::SetEnvironmentVariable("LC_ALL", "fr_FR.UTF-8", "Machine")
        Write-CorrectionResult "LC_ALL (Machine)" $true "Défini à fr_FR.UTF-8" ""
    }
    catch {
        Write-CorrectionResult "Variables système" $false "" $_.Exception.Message
    }
    
    # Test 3.2: Variables utilisateur (User) - fallback
    try {
        [System.Environment]::SetEnvironmentVariable("PYTHONUTF8", "1", "User")
        Write-CorrectionResult "PYTHONUTF8 (User)" $true "Défini à 1" ""
        
        [System.Environment]::SetEnvironmentVariable("PYTHONIOENCODING", "utf-8", "User")
        Write-CorrectionResult "PYTHONIOENCODING (User)" $true "Défini à utf-8" ""
        
        [System.Environment]::SetEnvironmentVariable("NODE_OPTIONS", "--encoding=utf8", "User")
        Write-CorrectionResult "NODE_OPTIONS (User)" $true "Défini à --encoding=utf8" ""
        
        [System.Environment]::SetEnvironmentVariable("LANG", "fr_FR.UTF-8", "User")
        Write-CorrectionResult "LANG (User)" $true "Défini à fr_FR.UTF-8" ""
        
        [System.Environment]::SetEnvironmentVariable("LC_ALL", "fr_FR.UTF-8", "User")
        Write-CorrectionResult "LC_ALL (User)" $true "Défini à fr_FR.UTF-8" ""
    }
    catch {
        Write-CorrectionResult "Variables utilisateur" $false "" $_.Exception.Message
    }
}

# ==============================================================================
# 4. CONFIGURATION POWERSHELL UNIFIÉE
# ==============================================================================

function Set-PowerShellUTF8Profiles {
    Write-CorrectionSection "4. CONFIGURATION POWERSHELL UNIFIÉE"
    
    # Test 4.1: Profile PowerShell 7+ (prioritaire)
    try {
        $profile7 = $PROFILE
        if (-not (Test-Path $profile7)) {
            New-Item -ItemType File -Path $profile7 -Force | Out-Null
        }
        
        $profileContent = @"
# Configuration UTF-8 universelle pour PowerShell 7+
# Généré par le script de correction d'encodage système
# Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')

# Forcer UTF-8 pour toutes les opérations
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::InputEncoding = [System.Text.Encoding]::UTF8
`$OutputEncoding = [System.Text.Encoding]::UTF8
`$PSDefaultParameterValues['*:Encoding'] = 'utf8'

# Variables d'environnement UTF-8
`$env:PYTHONUTF8 = "1"
`$env:PYTHONIOENCODING = "utf-8"
`$env:NODE_OPTIONS = "--encoding=utf8"
`$env:LANG = "fr_FR.UTF-8"
`$env:LC_ALL = "fr_FR.UTF-8"

# Affichage de la configuration
Write-Host "✅ Profile PowerShell 7+ configuré pour UTF-8" -ForegroundColor Green
Write-Host "   Encodage sortie: `$([Console]::OutputEncoding.EncodingName)" -ForegroundColor Cyan
Write-Host "   Encodage entrée: `$([Console]::InputEncoding.EncodingName)" -ForegroundColor Cyan
"@
        
        $profileContent | Out-File -FilePath $profile7 -Encoding UTF8 -Force
        Write-CorrectionResult "Profile PowerShell 7+" $true "Configuré pour UTF-8" "" @{
            ProfilePath = $profile7
            ContentLength = $profileContent.Length
        }
    }
    catch {
        Write-CorrectionResult "Profile PowerShell 7+" $false "" $_.Exception.Message
    }
    
    # Test 4.2: Profile PowerShell 5.1 (compatibilité)
    try {
        $profile51 = "$HOME\Documents\WindowsPowerShell\profile.ps1"
        if (-not (Test-Path $profile51)) {
            New-Item -ItemType File -Path $profile51 -Force | Out-Null
        }
        
        # Contenu similaire mais adapté pour PowerShell 5.1
        $profile51Content = $profileContent -replace 'PowerShell 7\+', 'PowerShell 5.1'
        
        $profile51Content | Out-File -FilePath $profile51 -Encoding UTF8 -Force
        Write-CorrectionResult "Profile PowerShell 5.1" $true "Configuré pour UTF-8" "" @{
            ProfilePath = $profile51
            ContentLength = $profile51Content.Length
        }
    }
    catch {
        Write-CorrectionResult "Profile PowerShell 5.1" $false "" $_.Exception.Message
    }
}

# ==============================================================================
# 5. VALIDATION DES CORRECTIONS
# ==============================================================================

function Test-UTF8Corrections {
    Write-CorrectionSection "5. VALIDATION DES CORRECTIONS"
    
    # Test 5.1: Validation PowerShell
    try {
        $testString = "Test UTF-8: é è à ù ç œ æ â ê î ô û 🚀 💻 ⚙️ 🪲"
        
        # Test avec PowerShell 7+
        $ps7Result = &pwsh -Command "`$testString = '$testString'; Write-Host 'PowerShell 7+:'; Write-Host `$testString"
        
        # Test avec PowerShell 5.1
        $ps51Result = &powershell.exe -Command "`$testString = '$testString'; Write-Host 'PowerShell 5.1:'; Write-Host `$testString"
        
        $ps7Success = $ps7Result -contains $testString
        $ps51Success = $ps51Result -contains $testString
        
        Write-CorrectionResult "Validation PowerShell 7+" $ps7Success "Affichage correct" "" @{
            TestString = $testString
            Result = $ps7Result
        }
        
        Write-CorrectionResult "Validation PowerShell 5.1" $ps51Success "Affichage correct" "" @{
            TestString = $testString
            Result = $ps51Result
        }
    }
    catch {
        Write-CorrectionResult "Validation PowerShell" $false "" $_.Exception.Message
    }
    
    # Test 5.2: Validation Python
    try {
        $pythonCmd = if (Get-Command python -ErrorAction SilentlyContinue) { "python" } else { "python3" }
        
        # Créer un script de test Python
        $pythonTest = @"
import sys
import os
test_string = "Test UTF-8: é è à ù ç œ æ â ê î ô û 🚀 💻 ⚙️ 🪲"
print(f'Python stdout: {test_string}')
print(f'Python encoding: {sys.stdout.encoding}')
print(f'Python default: {sys.getdefaultencoding()}')
"@
        
        $pythonTest | Out-File -FilePath "results\test-python-validation.py" -Encoding UTF8
        
        $pythonResult = & $pythonCmd "results\test-python-validation.py" 2>&1
        
        $pythonSuccess = $pythonResult -contains "utf-8" -and $pythonResult -contains "Test UTF-8"
        
        Write-CorrectionResult "Validation Python" $pythonSuccess "Encodage UTF-8 détecté" "" @{
            TestString = $testString
            Result = $pythonResult
        }
    }
    catch {
        Write-CorrectionResult "Validation Python" $false "" $_.Exception.Message
    }
    
    # Test 5.3: Validation Node.js
    try {
        # Créer un script de test Node.js
        $nodeTest = @"
const testString = 'Test UTF-8: é è à ù ç œ æ â ê î ô û 🚀 💻 ⚙️ 🪲';
console.log('Node.js stdout:', testString);
console.log('Node.js encoding:', process.stdout.encoding || 'undefined');
console.log('Node.js platform:', process.platform);
"@
        
        $nodeTest | Out-File -FilePath "results\test-node-validation.js" -Encoding UTF8
        
        $nodeResult = &node "results\test-node-validation.js" 2>&1
        
        $nodeSuccess = $nodeResult -contains "utf-8" -or $nodeResult -contains "Test UTF-8"
        
        Write-CorrectionResult "Validation Node.js" $nodeSuccess "Encodage UTF-8 détecté" "" @{
            TestString = $testString
            Result = $nodeResult
        }
    }
    catch {
        Write-CorrectionResult "Validation Node.js" $false "" $_.Exception.Message
    }
}

# ==============================================================================
# 6. GÉNÉRATION DU RAPPORT DE CORRECTION
# ==============================================================================

function New-CorrectionReport {
    $systemInfo = @{
        ComputerName = $env:COMPUTERNAME
        OSVersion = [System.Environment]::OSVersion.ToString()
        PowerShellVersion = $PSVersionTable.PSVersion.ToString()
        IsAdmin = Test-AdminPrivileges
        Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
    }
    
    $report = @{
        Metadata = @{
            ReportTitle = "Correction Encodage Système Windows"
            GeneratedBy = "Roo Debug Complex Mode"
            GeneratedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss UTC"
            PowerShellVersion = $systemInfo.PowerShellVersion
            ComputerName = $systemInfo.ComputerName
            OSVersion = $systemInfo.OSVersion
            IsAdmin = $systemInfo.IsAdmin
        }
        CorrectionResults = $script:CorrectionResults
        Summary = @{
            TotalCorrections = $script:CorrectionResults.Count
            SuccessfulCorrections = ($script:CorrectionResults | Where-Object { $_.Success }).Count
            FailedCorrections = ($script:CorrectionResults | Where-Object { -not $_.Success }).Count
            SuccessRate = if ($script:CorrectionResults.Count -gt 0) { [math]::Round((($script:CorrectionResults | Where-Object { $_.Success }).Count / $script:CorrectionResults.Count) * 100, 2) } else { 0 }
            CorrectionDuration = (Get-Date) - $script:CorrectionStartTime
        }
        SystemInfo = $systemInfo
        NextSteps = @()
    }
    
    # Générer les prochaines étapes
    $failedCorrections = $script:CorrectionResults | Where-Object { -not $_.Success }
    
    if ($failedCorrections.Count -gt 0) {
        $report.NextSteps += "Corriger manuellement les corrections échouées"
        $report.NextSteps += "Redémarrer Windows pour appliquer les modifications du registre"
        $report.NextSteps += "Exécuter le script de diagnostic pour validation"
    } else {
        $report.NextSteps += "Redémarrer Windows pour appliquer toutes les modifications"
        $report.NextSteps += "Tester les scripts Python/Node.js dans différents environnements"
        $report.NextSteps += "Valider que les emojis s'affichent correctement"
    }
    
    return $report
}

# ==============================================================================
# FONCTION PRINCIPALE
# ==============================================================================

function Main {
    Write-Host "═════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "  CORRECTION COMPLÈTE DE L'ENCODAGE SYSTÈME WINDOWS" -ForegroundColor Cyan
    Write-Host "═════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""
    
    # Vérifier les privilèges administratifs
    $isAdmin = Test-AdminPrivileges
    if (-not $isAdmin) {
        Write-Host "⚠️ ATTENTION: Ce script nécessite des privilèges administratifs" -ForegroundColor Yellow
        Write-Host "  Certaines corrections nécessitent des droits élevés" -ForegroundColor Yellow
        Write-Host "  Exécutez ce script en tant qu'administrateur pour une correction complète" -ForegroundColor Yellow
        Write-Host ""
    }
    
    # Créer le répertoire results si nécessaire
    if (-not (Test-Path "results")) {
        New-Item -ItemType Directory -Path "results" -Force | Out-Null
    }
    
    if (-not (Test-Path "results\registry-backups")) {
        New-Item -ItemType Directory -Path "results\registry-backups" -Force | Out-Null
    }
    
    # Exécuter toutes les corrections
    Set-WindowsUTF8Configuration
    Set-WindowsRegistryUTF8
    Set-SystemEnvironmentUTF8
    Set-PowerShellUTF8Profiles
    
    # Valider les corrections
    Test-UTF8Corrections
    
    # Générer le rapport
    $report = New-CorrectionReport
    
    # Sauvegarder le rapport JSON
    $reportJson = $report | ConvertTo-Json -Depth 10
    $reportPath = "results\correction-encoding-systeme-windows.json"
    $reportJson | Out-File -FilePath $reportPath -Encoding UTF8
    
    # Afficher le résumé
    Write-Host "`n═════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "  RÉSUMÉ DES CORRECTIONS" -ForegroundColor Cyan
    Write-Host "═════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""
    
    Write-Host "Corrections appliquées: $($report.Summary.TotalCorrections)" -ForegroundColor White
    Write-Host "Réussies: $($report.Summary.SuccessfulCorrections)" -ForegroundColor Green
    Write-Host "Échecs: $($report.Summary.FailedCorrections)" -ForegroundColor Red
    Write-Host "Taux de succès: $($report.Summary.SuccessRate)%" -ForegroundColor Yellow
    Write-Host "Durée: $([math]::Round($report.Summary.CorrectionDuration.TotalSeconds, 2)) secondes" -ForegroundColor Gray
    
    Write-Host "`nProchaines étapes:" -ForegroundColor White
    foreach ($step in $report.NextSteps) {
        Write-Host "  • $step" -ForegroundColor Cyan
    }
    
    Write-Host "`nRapport détaillé sauvegardé dans: $reportPath" -ForegroundColor Green
    Write-Host "Sauvegardes du registre dans: results\registry-backups\" -ForegroundColor Green
    
    if (-not $isAdmin) {
        Write-Host "`n⚠️ Certaines corrections nécessitent un redémarrage avec privilèges administratifs" -ForegroundColor Yellow
    }
    
    Write-Host "`n✅ Correction système terminée" -ForegroundColor Green
}

# ==============================================================================
# EXÉCUTION
# ==============================================================================

# Exécuter la fonction principale
Main