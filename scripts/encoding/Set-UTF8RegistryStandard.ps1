<#
.SYNOPSIS
    Standardise le registre Windows pour l'encodage UTF-8 (65001)
.DESCRIPTION
    Ce script configure toutes les clés de registre Windows relatives à l'encodage
    pour forcer l'utilisation de UTF-8 (65001) à tous les niveaux.
    Il inclut la modification unifiée des pages de code, la configuration console,
    et la création de backups automatiques avant toute modification.
.PARAMETER Force
    Force l'application même si les valeurs sont déjà correctes
.PARAMETER BackupPath
    Chemin personnalisé pour les backups (défaut: backups\utf8-registry-YYYYMMDD-HHmmss)
.PARAMETER ValidateOnly
    Effectue uniquement la validation sans appliquer les modifications
.PARAMETER Detailed
    Affiche des informations détaillées pendant l'exécution
.EXAMPLE
    .\Set-UTF8RegistryStandard.ps1
.EXAMPLE
    .\Set-UTF8RegistryStandard.ps1 -Force -Detailed
.EXAMPLE
    .\Set-UTF8RegistryStandard.ps1 -ValidateOnly -Verbose
.NOTES
    Auteur: Roo Architect Complex Mode
    Version: 1.0
    Date: 2025-10-30
    ID Correction: SYS-002
    Priorité: CRITIQUE
    Requiert: Droits administrateur
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [switch]$Force,
    
    [Parameter(Mandatory = $false)]
    [string]$BackupPath,
    
    [Parameter(Mandatory = $false)]
    [switch]$ValidateOnly,
    
    [Parameter(Mandatory = $false)]
    [switch]$Detailed
)

# Configuration du script
$script:LogFile = "logs\Set-UTF8RegistryStandard-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
$script:BackupDir = if ($BackupPath) { $BackupPath } else { "backups\utf8-registry-$(Get-Date -Format 'yyyyMMdd-HHmmss')" }
$script:TempDir = "temp\utf8-registry-validation"

# Constantes UTF-8
$UTF8_CODEPAGE = 65001
$UTF8_LOCALE = "fr-FR"
$UTF8_LOCALE_HEX = "0000040C"

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

function Write-Detail {
    param([string]$Message)
    if ($Detailed) {
        Write-Log $Message "DETAIL"
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
    
    return $true
}

# Analyse de l'état actuel du registre
function Get-CurrentRegistryState {
    Write-Detail "Analyse de l'état actuel du registre..."
    
    $state = @{
        CodePages = @{}
        Console = @{}
        International = @{}
        Issues = @()
        BackupCreated = $false
    }
    
    try {
        # Analyse des pages de code
        $codePagePath = "HKLM:\SYSTEM\CurrentControlSet\Control\Nls\CodePage"
        if (Test-Path $codePagePath) {
            $codePages = Get-ItemProperty -Path $codePagePath
            $state.CodePages = $codePages
            Write-Detail "Pages de code actuelles: ACP=$($codePages.ACP), OEMCP=$($codePages.OEMCP), MACCP=$($codePages.MACCP)"
        } else {
            $state.Issues += "Clé de registre des pages de code introuvable"
        }
        
        # Analyse de la console
        $consolePath = "HKCU:\Console"
        if (Test-Path $consolePath) {
            $console = Get-ItemProperty -Path $consolePath
            $state.Console = $console
            Write-Detail "Console actuelle: CodePage=$($console.CodePage), FaceName=$($console.FaceName)"
        } else {
            $state.Issues += "Clé de registre console introuvable"
        }
        
        # Analyse des paramètres internationaux
        $intlPath = "HKCU:\Control Panel\International"
        if (Test-Path $intlPath) {
            $intl = Get-ItemProperty -Path $intlPath
            $state.International = $intl
            Write-Detail "Paramètres internationaux: LocaleName=$($intl.LocaleName), Locale=$($intl.Locale))"
        } else {
            $state.Issues += "Clé de registre internationale introuvable"
        }
        
    } catch {
        $state.Issues += "Erreur lors de l'analyse: $($_.Exception.Message)"
        Write-Error "Erreur d'analyse: $($_.Exception.Message)"
    }
    
    return $state
}

# Création du backup du registre
function Backup-Registry {
    Write-Info "Création du backup du registre..."
    
    try {
        # Création du répertoire de backup
        if (!(Test-Path $script:BackupDir)) {
            New-Item -ItemType Directory -Path $script:BackupDir -Force | Out-Null
        }
        
        $backupFile = Join-Path $script:BackupDir "registry-backup-$(Get-Date -Format 'yyyyMMdd-HHmmss').reg"
        
        # Backup des clés principales
        $backupCmd = @"
reg export "HKLM\SYSTEM\CurrentControlSet\Control\Nls\CodePage" "$backupFile" /y
reg export "HKCU\Console" "$backupFile" /y
reg export "HKCU\Control Panel\International" "$backupFile" /y
"@
        
        Invoke-Expression $backupCmd
        
        if (Test-Path $backupFile) {
            Write-Success "Backup créé: $backupFile"
            return $backupFile
        } else {
            Write-Error "Échec de la création du backup"
            return $null
        }
        
    } catch {
        Write-Error "Erreur lors du backup: $($_.Exception.Message)"
        return $null
    }
}

# Application des standards UTF-8
function Apply-UTF8Standards {
    Write-Info "Application des standards UTF-8..."
    
    $changes = @{}
    $errors = @()
    
    try {
        # Configuration des pages de code système
        Write-Detail "Configuration des pages de code système..."
        
        Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Nls\CodePage" -Name "ACP" -Value $UTF8_CODEPAGE -Type DWord -Force
        $changes.CodePages_ACP = "ACP: $UTF8_CODEPAGE"
        Write-Success "ACP configuré à $UTF8_CODEPAGE"
        
        Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Nls\CodePage" -Name "OEMCP" -Value $UTF8_CODEPAGE -Type DWord -Force
        $changes.CodePages_OEMCP = "OEMCP: $UTF8_CODEPAGE"
        Write-Success "OEMCP configuré à $UTF8_CODEPAGE"
        
        Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Nls\CodePage" -Name "MACCP" -Value $UTF8_CODEPAGE -Type DWord -Force
        $changes.CodePages_MACCP = "MACCP: $UTF8_CODEPAGE"
        Write-Success "MACCP configuré à $UTF8_CODEPAGE"
        
        # Configuration des paramètres console
        Write-Detail "Configuration des paramètres console..."
        
        Set-ItemProperty -Path "HKCU:\Console" -Name "CodePage" -Value $UTF8_CODEPAGE -Type DWord -Force
        $changes.Console_CodePage = "Console CodePage: $UTF8_CODEPAGE"
        Write-Success "Console CodePage configuré à $UTF8_CODEPAGE"
        
        Set-ItemProperty -Path "HKCU:\Console" -Name "FaceName" -Value "Consolas" -Type String -Force
        $changes.Console_FaceName = "Console FaceName: Consolas"
        Write-Success "Console FaceName configuré à Consolas"
        
        # Configuration des paramètres internationaux
        Write-Detail "Configuration des paramètres internationaux..."
        
        Set-ItemProperty -Path "HKCU:\Control Panel\International" -Name "LocaleName" -Value $UTF8_LOCALE -Type String -Force
        $changes.International_LocaleName = "LocaleName: $UTF8_LOCALE"
        Write-Success "LocaleName configuré à $UTF8_LOCALE"
        
        Set-ItemProperty -Path "HKCU:\Control Panel\International" -Name "Locale" -Value $UTF8_LOCALE_HEX -Type String -Force
        $changes.International_Locale = "Locale: $UTF8_LOCALE_HEX"
        Write-Success "Locale configuré à $UTF8_LOCALE_HEX"
        
        # Configuration supplémentaire pour compatibilité
        Set-ItemProperty -Path "HKCU:\Control Panel\International" -Name "sCountry" -Value "FR" -Type String -Force
        $changes.International_sCountry = "sCountry: FR"
        Write-Success "sCountry configuré à FR"
        
        Set-ItemProperty -Path "HKCU:\Control Panel\International" -Name "sLanguage" -Value "FRF" -Type String -Force
        $changes.International_sLanguage = "sLanguage: FRF"
        Write-Success "sLanguage configuré à FRF"
        
    } catch {
        $errors += "Erreur lors de l'application des standards: $($_.Exception.Message)"
        Write-Error "Erreur d'application: $($_.Exception.Message)"
    }
    
    return @{
        Changes = $changes
        Errors = $errors
    }
}

# Validation des modifications appliquées
function Validate-RegistryChanges {
    Write-Info "Validation des modifications du registre..."
    
    $validation = @{
        Success = $false
        Details = @{}
        Issues = @()
        Recommendations = @()
    }
    
    try {
        # Relecture des pages de code
        $codePagePath = "HKLM:\SYSTEM\CurrentControlSet\Control\Nls\CodePage"
        $codePages = Get-ItemProperty -Path $codePagePath
        $validation.Details.CodePages = $codePages
        
        $codePageValid = ($codePages.ACP -eq $UTF8_CODEPAGE -and 
                        $codePages.OEMCP -eq $UTF8_CODEPAGE -and 
                        $codePages.MACCP -eq $UTF8_CODEPAGE)
        
        if ($codePageValid) {
            Write-Success "Pages de code valides: ACP=$($codePages.ACP), OEMCP=$($codePages.OEMCP), MACCP=$($codePages.MACCP)"
        } else {
            $validation.Issues += "Pages de code invalides: ACP=$($codePages.ACP), OEMCP=$($codePages.OEMCP), MACCP=$($codePages.MACCP)"
            $validation.Recommendations += "Vérifier les droits administrateur et redémarrer"
        }
        
        # Validation de la console
        $consolePath = "HKCU:\Console"
        $console = Get-ItemProperty -Path $consolePath
        $validation.Details.Console = $console
        
        $consoleValid = ($console.CodePage -eq $UTF8_CODEPAGE)
        if ($consoleValid) {
            Write-Success "Console validée: CodePage=$($console.CodePage)"
        } else {
            $validation.Issues += "Console invalide: CodePage=$($console.CodePage)"
            $validation.Recommendations += "Redémarrer le système pour appliquer les changements"
        }
        
        # Validation des paramètres internationaux
        $intlPath = "HKCU:\Control Panel\International"
        $intl = Get-ItemProperty -Path $intlPath
        $validation.Details.International = $intl
        
        $intlValid = ($intl.LocaleName -eq $UTF8_LOCALE -and 
                    $intl.Locale -eq $UTF8_LOCALE_HEX)
        
        if ($intlValid) {
            Write-Success "Paramètres internationaux valides: LocaleName=$($intl.LocaleName)"
        } else {
            $validation.Issues += "Paramètres internationaux invalides: LocaleName=$($intl.LocaleName)"
            $validation.Recommendations += "Vérifier la cohérence des paramètres régionaux"
        }
        
        # Validation globale
        $validation.Success = ($codePageValid -and $consoleValid -and $intlValid)
        
        if ($validation.Success) {
            Write-Success "Validation du registre: SUCCÈS"
        } else {
            Write-Warning "Validation du registre: PARTIELLE - $($validation.Issues.Count) problèmes détectés"
        }
        
    } catch {
        $validation.Issues += "Erreur lors de la validation: $($_.Exception.Message)"
        Write-Error "Erreur de validation: $($_.Exception.Message)"
    }
    
    return $validation
}

# Génération du rapport de validation
function New-ValidationReport {
    param([hashtable]$InitialState, [hashtable]$Changes, [hashtable]$Validation, [string]$BackupFile)
    
    $reportPath = "results\UTF8-Registry-Validation-Report-$(Get-Date -Format 'yyyyMMdd-HHmmss').md"
    
    # Création du répertoire de résultats
    if (!(Test-Path "results")) {
        New-Item -ItemType Directory -Path "results" -Force | Out-Null
    }
    
    $report = @"
# Rapport de Standardisation Registre UTF-8

**Date**: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
**Script**: Set-UTF8RegistryStandard.ps1
**Version**: 1.0
**Auteur**: Roo Architect Complex Mode
**ID Correction**: SYS-002
**Priorité**: CRITIQUE

## 📊 État Initial

### Pages de Code Système
- **ACP**: $($InitialState.CodePages.ACP) → **$($Changes.CodePages_ACP)**
- **OEMCP**: $($InitialState.CodePages.OEMCP) → **$($Changes.CodePages_OEMCP)**
- **MACCP**: $($InitialState.CodePages.MACCP) → **$($Changes.CodePages_MACCP)**

### Configuration Console
- **CodePage**: $($InitialState.Console.CodePage) → **$($Changes.Console_CodePage)**
- **FaceName**: $($InitialState.Console.FaceName) → **$($Changes.Console_FaceName)**

### Paramètres Internationaux
- **LocaleName**: $($InitialState.International.LocaleName) → **$($Changes.International_LocaleName)**
- **Locale**: $($InitialState.International.Locale) → **$($Changes.International_Locale)**

## 📋 Résultats de Validation

### Succès Global
- **Validation Réussie**: $(if ($Validation.Success) { "✅ OUI" } else { "❌ NON" })

### Validation Détaillée
- **Pages de Code**: $(if ($Validation.Details.CodePages.ACP -eq $UTF8_CODEPAGE -and $Validation.Details.CodePages.OEMCP -eq $UTF8_CODEPAGE -and $Validation.Details.CodePages.MACCP -eq $UTF8_CODEPAGE) { "✅ Validées" } else { "❌ Invalidées" })
- **Configuration Console**: $(if ($Validation.Details.Console.CodePage -eq $UTF8_CODEPAGE) { "✅ Validée" } else { "❌ Invalidée" })
- **Paramètres Internationaux**: $(if ($Validation.Details.International.LocaleName -eq $UTF8_LOCALE -and $Validation.Details.International.Locale -eq $UTF8_LOCALE_HEX) { "✅ Validés" } else { "❌ Invalidés" })

### Problèmes Détectés
$($Validation.Issues | ForEach-Object { "- $($_)" })

### Recommandations
$($Validation.Recommendations | ForEach-Object { "- $($_)" })

## 🔄 Procédures de Rollback

### Restauration Automatique
```powershell
# Restauration depuis le backup
reg import "$BackupFile"

# Redémarrage système requis
Restart-Computer -Force
```

### Restauration Manuelle
1. Ouvrir l'Éditeur du Registre (regedit.exe)
2. Naviguer vers les clés modifiées
3. Restaurer les valeurs originales depuis le backup
4. Redémarrer le système

## 📝 Informations Complémentaires

- **Fichier de Backup**: $BackupFile
- **Fichier de Log**: $script:LogFile
- **Date d'Exécution**: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
- **Modifications Appliquées**: $($Changes.Count) changements
- **Problèmes Validation**: $($Validation.Issues.Count) problèmes

---

**Statut**: $(if ($Validation.Success) { "✅ STANDARDISATION RÉUSSIE" } else { "⚠️ STANDARDISATION PARTIELLE" })
**Prochaine Étape**: $(if ($Validation.Success) { "Jour 4-4: Variables Environnement Standardisées" } else { "Diagnostic et correction des problèmes" })
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
    Write-Log "Début du script Set-UTF8RegistryStandard.ps1" "INFO"
    Write-Log "ID Correction: SYS-002" "INFO"
    Write-Log "Priorité: CRITIQUE" "INFO"
    
    try {
        # Validation des prérequis
        if (-not (Test-Prerequisites)) {
            Write-Error "Prérequis non satisfaits. Arrêt du script."
            exit 1
        }
        
        # Analyse de l'état actuel
        $initialState = Get-CurrentRegistryState
        
        if ($Detailed) {
            Write-Info "État initial analysé:"
            Write-Detail "  Pages de code: ACP=$($initialState.CodePages.ACP), OEMCP=$($initialState.CodePages.OEMCP), MACCP=$($initialState.CodePages.MACCP)"
            Write-Detail "  Console: CodePage=$($initialState.Console.CodePage), FaceName=$($initialState.Console.FaceName)"
            Write-Detail "  International: LocaleName=$($initialState.International.LocaleName), Locale=$($initialState.International.Locale)"
            Write-Detail "  Problèmes détectés: $($initialState.Issues.Count)"
        }
        
        # Mode validation uniquement
        if ($ValidateOnly) {
            Write-Info "Mode validation uniquement - aucune modification appliquée"
            $validation = Validate-RegistryChanges
            $reportPath = New-ValidationReport -InitialState $initialState -Changes @{} -Validation $validation -BackupFile $null
            exit 0
        }
        
        # Vérification si les modifications sont nécessaires
        $changesNeeded = $false
        if ($initialState.CodePages.ACP -ne $UTF8_CODEPAGE -or 
            $initialState.CodePages.OEMCP -ne $UTF8_CODEPAGE -or 
            $initialState.CodePages.MACCP -ne $UTF8_CODEPAGE) {
            $changesNeeded = $true
        }
        
        if ($initialState.Console.CodePage -ne $UTF8_CODEPAGE) {
            $changesNeeded = $true
        }
        
        if ($initialState.International.LocaleName -ne $UTF8_LOCALE -or 
            $initialState.International.Locale -ne $UTF8_LOCALE_HEX) {
            $changesNeeded = $true
        }
        
        if (-not $changesNeeded -and -not $Force) {
            Write-Success "Le registre est déjà configuré pour UTF-8. Utilisez -Force pour forcer la reconfiguration."
            $validation = Validate-RegistryChanges
            $reportPath = New-ValidationReport -InitialState $initialState -Changes @{} -Validation $validation -BackupFile $null
            exit 0
        }
        
        # Création du backup
        $backupFile = Backup-Registry
        
        if (-not $backupFile) {
            Write-Error "Échec de la création du backup. Arrêt du script."
            exit 1
        }
        
        # Application des standards UTF-8
        $changes = Apply-UTF8Standards
        
        if ($changes.Errors.Count -gt 0) {
            Write-Error "Erreurs lors de l'application des standards: $($changes.Errors.Count)"
            Write-Error "Consulter le fichier de log pour plus de détails."
            exit 1
        }
        
        # Validation des modifications
        Start-Sleep -Seconds 2  # Attendre la stabilisation du registre
        $validation = Validate-RegistryChanges
        
        # Génération du rapport
        $reportPath = New-ValidationReport -InitialState $initialState -Changes $changes -Validation $validation -BackupFile $backupFile
        
        if ($validation.Success) {
            Write-Success "Standardisation du registre UTF-8 terminée avec succès"
            Write-Success "Modifications appliquées: $($changes.Changes.Count)"
            Write-Success "Rapport généré: $reportPath"
            
            # Notification de redémarrage recommandé
            Write-Warning "Redémarrage du système recommandé pour appliquer tous les changements"
            Write-Warning "Sauvegardez votre travail avant de redémarrer!"
            
        } else {
            Write-Warning "Standardisation partielle - $($validation.Issues.Count) problèmes détectés"
            Write-Warning "Rapport généré: $reportPath"
            Write-Warning "Vérifiez les problèmes et corrigez-les manuellement si nécessaire"
        }
        
    } catch {
        Write-Error "Erreur inattendue: $($_.Exception.Message)"
        Write-Error "Stack Trace: $($_.ScriptStackTrace)"
        exit 1
    }
}

# Point d'entrée principal
Main