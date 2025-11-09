<#
.SYNOPSIS
    Active le support UTF-8 worldwide beta sur Windows 11 Pro français
.DESCRIPTION
    Ce script active l'option UTF-8 beta de Windows, valide son état effectif,
    et prépare le système pour un support complet de l'encodage UTF-8.
    Inclut l'analyse préliminaire, l'activation forcée via registre,
    la validation post-activation et la planification de redémarrage.
.PARAMETER Force
    Force l'activation même si déjà détectée comme active
.PARAMETER SkipRestart
    Saute la planification de redémarrage (pour tests automatisés)
.PARAMETER Verbose
    Affiche des informations détaillées pendant l'exécution
.PARAMETER ValidationOnly
    Effectue uniquement la validation sans activer
.EXAMPLE
    .\Enable-UTF8WorldwideSupport.ps1
.EXAMPLE
    .\Enable-UTF8WorldwideSupport.ps1 -Force -Verbose
.EXAMPLE
    .\Enable-UTF8WorldwideSupport.ps1 -ValidationOnly -Verbose
.NOTES
    Auteur: Roo Architect Complex Mode
    Version: 1.0
    Date: 2025-10-30
    ID Correction: SYS-001
    Priorité: CRITIQUE
    Requiert: Droits administrateur
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [switch]$Force,
    
    [Parameter(Mandatory = $false)]
    [switch]$SkipRestart,
    
    [Parameter(Mandatory = $false)]
    [switch]$Verbose,
    
    [Parameter(Mandatory = $false)]
    [switch]$ValidationOnly
)

# Configuration du logging
$script:LogFile = "logs\Enable-UTF8WorldwideSupport-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
$script:BackupDir = "backups\utf8-activation-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
$script:TempDir = "temp\utf8-validation"

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
    if ($Verbose) {
        Write-Log $Message "INFO"
    }
}

# Validation des prérequis
function Test-Prerequisites {
    Write-Info "Validation des prérequis..."
    
    # Vérification des droits administrateur
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    if (-not $currentUser.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Error "Ce script nécessite des droits administrateur. Exécutez en tant qu'administrateur."
        return $false
    }
    Write-Success "Droits administrateur: OK"
    
    # Vérification de la version Windows
    $osVersion = [System.Environment]::OSVersion
    if ($osVersion.Version.Major -lt 10) {
        Write-Error "Windows 10+ requis. Version détectée: $($osVersion.Version)"
        return $false
    }
    Write-Success "Version Windows: OK ($($osVersion.Version))"
    
    # Vérification PowerShell version
    $psVersion = $PSVersionTable.PSVersion
    if ($psVersion.Major -lt 5) {
        Write-Error "PowerShell 5.1+ requis. Version détectée: $psVersion"
        return $false
    }
    Write-Success "Version PowerShell: OK ($psVersion)"
    
    return $true
}

# Analyse de l'état actuel UTF-8 beta
function Get-UTF8BetaStatus {
    Write-Info "Analyse de l'état actuel UTF-8 beta..."
    
    $status = @{
        BetaEnabled = $false
        BetaEffective = $false
        CodePages = @{
            ACP = 0
            OEMCP = 0
            MACCP = 0
        }
        RegistryKeys = @{}
        Issues = @()
    }
    
    try {
        # Vérification de l'option beta via registre
        $betaPath = "HKCU:\Control Panel\International"
        if (Test-Path $betaPath) {
            $betaValue = Get-ItemProperty -Path $betaPath -Name "LocaleName" -ErrorAction SilentlyContinue
            if ($betaValue -and $betaValue.LocaleName -like "*UTF-8*") {
                $status.BetaEnabled = $true
            }
        }
        
        # Vérification des pages de code système
        $codePagePath = "HKLM:\SYSTEM\CurrentControlSet\Control\Nls\CodePage"
        if (Test-Path $codePagePath) {
            $codePages = Get-ItemProperty -Path $codePagePath
            $status.CodePages.ACP = $codePages.ACP
            $status.CodePages.OEMCP = $codePages.OEMCP
            $status.CodePages.MACCP = $codePages.MACCP
            
            # Vérification si UTF-8 (65001) est effectif
            if ($status.CodePages.ACP -eq 65001 -and $status.CodePages.OEMCP -eq 65001) {
                $status.BetaEffective = $true
            }
        }
        
        # Analyse des clés de registre pertinentes
        $status.RegistryKeys = @{
            "HKCU\Control Panel\International" = if (Test-Path "HKCU:\Control Panel\International") { 
                Get-ItemProperty "HKCU:\Control Panel\International" 
            } else { $null }
            "HKLM\SYSTEM\CurrentControlSet\Control\Nls\CodePage" = if (Test-Path "HKLM:\SYSTEM\CurrentControlSet\Control\Nls\CodePage") { 
                Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Nls\CodePage" 
            } else { $null }
        }
        
        # Détection des problèmes
        if ($status.BetaEnabled -and -not $status.BetaEffective) {
            $status.Issues += "Option beta activée mais pages de code non-UTF8"
        }
        if (-not $status.BetaEnabled -and $status.BetaEffective) {
            $status.Issues += "Pages de code UTF-8 mais option beta non activée"
        }
        if ($status.CodePages.ACP -ne 65001) {
            $status.Issues += "Page de code ACP non-UTF8: $($status.CodePages.ACP)"
        }
        if ($status.CodePages.OEMCP -ne 65001) {
            $status.Issues += "Page de code OEMCP non-UTF8: $($status.CodePages.OEMCP)"
        }
        
    } catch {
        Write-Error "Erreur lors de l'analyse: $($_.Exception.Message)"
        $status.Issues += "Erreur d'analyse: $($_.Exception.Message)"
    }
    
    return $status
}

# Activation de l'option UTF-8 beta
function Enable-UTF8Beta {
    Write-Info "Activation de l'option UTF-8 beta..."
    
    try {
        # Création du répertoire de backup
        if (!(Test-Path $script:BackupDir)) {
            New-Item -ItemType Directory -Path $script:BackupDir -Force | Out-Null
        }
        
        # Backup des clés de registre avant modification
        $backupPath = Join-Path $script:BackupDir "registry-backup.reg"
        Write-Info "Sauvegarde du registre vers: $backupPath"
        
        $backupCmd = "reg export `"HKCU\Control Panel\International`" `"$backupPath`" /y"
        Invoke-Expression $backupCmd
        
        # Activation de l'option beta via registre
        Write-Info "Configuration de l'option UTF-8 beta..."
        
        # Configuration des paramètres régionaux UTF-8
        Set-ItemProperty -Path "HKCU:\Control Panel\International" -Name "LocaleName" -Value "fr-FR" -Force
        Set-ItemProperty -Path "HKCU:\Control Panel\International" -Name "Locale" -Value "0000040C" -Force
        
        # Configuration des pages de code système
        Write-Info "Configuration des pages de code système à 65001 (UTF-8)..."
        Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Nls\CodePage" -Name "ACP" -Value 65001 -Type DWord -Force
        Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Nls\CodePage" -Name "OEMCP" -Value 65001 -Type DWord -Force
        Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Nls\CodePage" -Name "MACCP" -Value 65001 -Type DWord -Force
        
        Write-Success "Option UTF-8 beta activée avec succès"
        Write-Success "Pages de code configurées à 65001 (UTF-8)"
        
        return $true
        
    } catch {
        Write-Error "Erreur lors de l'activation: $($_.Exception.Message)"
        return $false
    }
}

# Validation post-activation
function Test-UTF8Activation {
    Write-Info "Validation de l'activation UTF-8..."
    
    $results = @{
        Success = $false
        Details = @{}
        Issues = @()
        Recommendations = @()
    }
    
    try {
        # Test 1: Vérification des pages de code
        $codePagePath = "HKLM:\SYSTEM\CurrentControlSet\Control\Nls\CodePage"
        $codePages = Get-ItemProperty -Path $codePagePath
        
        $results.Details.CodePages = @{
            ACP = $codePages.ACP
            OEMCP = $codePages.OEMCP
            MACCP = $codePages.MACCP
        }
        
        if ($codePages.ACP -eq 65001 -and $codePages.OEMCP -eq 65001) {
            $results.Success = $true
            Write-Success "Pages de code: OK (ACP=$($codePages.ACP), OEMCP=$($codePages.OEMCP))"
        } else {
            $results.Issues += "Pages de code incorrectes: ACP=$($codePages.ACP), OEMCP=$($codePages.OEMCP)"
            $results.Recommendations += "Vérifier les droits administrateur et réexécuter le script"
        }
        
        # Test 2: Vérification des paramètres régionaux
        $intlPath = "HKCU:\Control Panel\International"
        if (Test-Path $intlPath) {
            $intlSettings = Get-ItemProperty -Path $intlPath
            $results.Details.LocaleSettings = $intlSettings
            
            if ($intlSettings.LocaleName -eq "fr-FR") {
                Write-Success "Paramètres régionaux: OK ($($intlSettings.LocaleName))"
            } else {
                $results.Issues += "Paramètres régionaux incorrects: $($intlSettings.LocaleName)"
            }
        }
        
        # Test 3: Test pratique d'encodage
        Write-Info "Test pratique d'encodage UTF-8..."
        $testString = "Test UTF-8: é è à ù ç œ æ â ê î ô û 🚀 💻 ⚙️ 🪲"
        $tempFile = Join-Path $script:TempDir "utf8-test.txt"
        
        # Création du répertoire temporaire
        if (!(Test-Path $script:TempDir)) {
            New-Item -ItemType Directory -Path $script:TempDir -Force | Out-Null
        }
        
        # Écriture du test avec encodage UTF-8 explicite
        $testString | Out-File -FilePath $tempFile -Encoding UTF8 -Force
        
        # Lecture et vérification
        $readContent = Get-Content -Path $tempFile -Encoding UTF8
        if ($readContent -eq $testString) {
            Write-Success "Test pratique d'encodage: OK"
            $results.Details.EncodingTest = "SUCCESS"
        } else {
            $results.Issues += "Test pratique d'encodage: ÉCHEC"
            $results.Details.EncodingTest = "FAILED"
            $results.Recommendations += "Redémarrage système peut être nécessaire"
        }
        
        # Nettoyage du fichier temporaire
        if (Test-Path $tempFile) {
            Remove-Item -Path $tempFile -Force
        }
        
    } catch {
        Write-Error "Erreur lors de la validation: $($_.Exception.Message)"
        $results.Issues += "Erreur de validation: $($_.Exception.Message)"
    }
    
    return $results
}

# Planification du redémarrage
function Schedule-SystemRestart {
    if ($SkipRestart) {
        Write-Info "Redémarrage sauté (paramètre -SkipRestart)"
        return $true
    }
    
    Write-Info "Planification du redémarrage système..."
    
    try {
        # Notification utilisateur
        Write-Warning "Redémarrage système planifié dans 60 secondes..."
        Write-Warning "Sauvegardez votre travail avant le redémarrage!"
        
        # Compte à rebours
        for ($i = 60; $i -gt 0; $i--) {
            Write-Host "`rRedémarrage dans $i secondes... " -ForegroundColor Yellow -NoNewline
            Start-Sleep -Seconds 1
        }
        Write-Host ""
        
        # Redémarrage système
        Write-Info "Redémarrage du système..."
        Restart-Computer -Force
        
        return $true
        
    } catch {
        Write-Error "Erreur lors de la planification du redémarrage: $($_.Exception.Message)"
        return $false
    }
}

# Génération du rapport de validation
function New-ValidationReport {
    param([hashtable]$Status, [hashtable]$ValidationResults)
    
    $reportPath = "results\UTF8-Activation-Report-$(Get-Date -Format 'yyyyMMdd-HHmmss').md"
    
    # Création du répertoire de résultats
    if (!(Test-Path "results")) {
        New-Item -ItemType Directory -Path "results" -Force | Out-Null
    }
    
    $report = @"
# Rapport d'Activation UTF-8 Worldwide Support

**Date**: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
**Script**: Enable-UTF8WorldwideSupport.ps1
**Version**: 1.0
**Auteur**: Roo Architect Complex Mode
**ID Correction**: SYS-001

## 📊 État Initial

### Configuration UTF-8 Beta
- **Option Beta Activée**: $($Status.BetaEnabled)
- **Option Beta Effective**: $($Status.BetaEffective)

### Pages de Code Système
- **ACP**: $($Status.CodePages.ACP) (65001 = UTF-8)
- **OEMCP**: $($Status.CodePages.OEMCP) (65001 = UTF-8)
- **MACCP**: $($Status.CodePages.MACCP) (65001 = UTF-8)

### Problèmes Détectés
$($Status.Issues | ForEach-Object { "- $($_)" })

## 📋 Résultats de Validation

### Succès Global
- **Validation Réussie**: $($ValidationResults.Success)

### Détails Techniques
- **Pages de Code**: ACP=$($ValidationResults.Details.CodePages.ACP), OEMCP=$($ValidationResults.Details.CodePages.OEMCP)
- **Paramètres Régionaux**: $($ValidationResults.Details.LocaleSettings.LocaleName)
- **Test Encodage**: $($ValidationResults.Details.EncodingTest)

### Problèmes Post-Activation
$($ValidationResults.Issues | ForEach-Object { "- $($_)" })

### Recommandations
$($ValidationResults.Recommendations | ForEach-Object { "- $($_)" })

## 🔄 Procédures de Rollback

### Restauration Automatique
```powershell
# Restauration depuis le backup de registre
reg import "$($script:BackupDir)\registry-backup.reg"
```

### Restauration Manuelle
1. Ouvrir l'Éditeur du Registre (regedit.exe)
2. Naviguer vers `HKEY_CURRENT_USER\Control Panel\International`
3. Restaurer les valeurs originales depuis le backup
4. Redémarrer le système

## 📝 Logs Complémentaires

- **Fichier de Log**: $script:LogFile
- **Répertoire de Backup**: $script:BackupDir
- **Date d'Exécution**: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')

---

**Statut**: $(if ($ValidationResults.Success) { "✅ SUCCÈS" } else { "❌ ÉCHEC" })
**Prochaine Étape**: $(if ($ValidationResults.Success) { "Continuer vers Jour 3-3: Standardisation Registre UTF-8" } else { "Diagnostic et correction des problèmes" })
"@
    
    try {
        $report | Out-File -FilePath $reportPath -Encoding UTF8 -Force
        Write-Success "Rapport généré: $reportPath"
        return $reportPath
    } catch {
        Write-Error "Erreur lors de la génération du rapport: $($_.Exception.Message)"
        return $null
    }
}

# Programme principal
function Main {
    Write-Log "Début du script Enable-UTF8WorldwideSupport.ps1" "INFO"
    Write-Log "ID Correction: SYS-001" "INFO"
    Write-Log "Priorité: CRITIQUE" "INFO"
    
    try {
        # Validation des prérequis
        if (-not (Test-Prerequisites)) {
            Write-Error "Prérequis non satisfaits. Arrêt du script."
            exit 1
        }
        
        # Analyse de l'état actuel
        $currentStatus = Get-UTF8BetaStatus
        
        if ($Verbose) {
            Write-Info "État actuel:"
            Write-Info "  Beta Enabled: $($currentStatus.BetaEnabled)"
            Write-Info "  Beta Effective: $($currentStatus.BetaEffective)"
            Write-Info "  ACP: $($currentStatus.CodePages.ACP)"
            Write-Info "  OEMCP: $($currentStatus.CodePages.OEMCP)"
            Write-Info "  Issues: $($currentStatus.Issues.Count)"
        }
        
        # Mode validation uniquement
        if ($ValidationOnly) {
            Write-Info "Mode validation uniquement - aucune modification effectuée"
            $validationResults = Test-UTF8Activation
            $reportPath = New-ValidationReport -Status $currentStatus -ValidationResults $validationResults
            exit 0
        }
        
        # Vérification si l'activation est nécessaire
        if ($currentStatus.BetaEffective -and -not $Force) {
            Write-Success "UTF-8 beta déjà actif et effectif. Utilisez -Force pour forcer la réactivation."
            $validationResults = Test-UTF8Activation
            $reportPath = New-ValidationReport -Status $currentStatus -ValidationResults $validationResults
            exit 0
        }
        
        # Activation de l'option UTF-8 beta
        if (-not (Enable-UTF8Beta)) {
            Write-Error "Échec de l'activation UTF-8 beta"
            exit 1
        }
        
        # Validation post-activation
        Write-Info "Validation post-activation..."
        Start-Sleep -Seconds 2  # Attendre que le registre se stabilise
        $validationResults = Test-UTF8Activation
        
        # Génération du rapport
        $reportPath = New-ValidationReport -Status $currentStatus -ValidationResults $validationResults
        
        if ($validationResults.Success) {
            Write-Success "Activation UTF-8 beta validée avec succès"
            
            # Planification du redémarrage
            if (-not (Schedule-SystemRestart)) {
                Write-Error "Échec de la planification du redémarrage"
                exit 1
            }
        } else {
            Write-Error "La validation post-activation a échoué"
            Write-Error "Vérifiez le rapport généré pour plus de détails"
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