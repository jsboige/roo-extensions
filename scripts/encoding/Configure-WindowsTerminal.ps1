<#
.SYNOPSIS
    Configure Windows Terminal pour un support UTF-8 optimal.
.DESCRIPTION
    Ce script modifie la configuration de Windows Terminal (settings.json) pour :
    - Définir un profil par défaut compatible UTF-8
    - Configurer la police (Cascadia Code/Mono)
    - Activer le moteur de rendu de texte AtlasEngine (si disponible)
    - Assurer que les caractères spéciaux s'affichent correctement
.PARAMETER BackupPath
    Chemin pour les backups de configuration (défaut: backups\terminal-config)
.EXAMPLE
    .\Configure-WindowsTerminal.ps1
.NOTES
    Auteur: Roo Architect
    Date: 2025-11-26
    ID Tâche: SDDD-T001-J5-5
#>

[CmdletBinding()]
param(
    [string]$BackupPath = "backups\terminal-config"
)

# Configuration
$LogFile = "logs\Configure-WindowsTerminal-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"

# Fonctions de logging (reprises de Set-StandardizedEnvironment pour cohérence)
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    Write-Host $logEntry -ForegroundColor $(switch ($Level) { "ERROR" { "Red" } "WARN" { "Yellow" } "SUCCESS" { "Green" } default { "Cyan" } })
    if (!(Test-Path "logs")) { New-Item -ItemType Directory -Path "logs" -Force | Out-Null }
    Add-Content -Path $LogFile -Value $logEntry -Encoding UTF8
}

function Get-WindowsTerminalSettingsPath {
    $packagesPath = "$env:LOCALAPPDATA\Packages"
    $wtPackage = Get-ChildItem -Path $packagesPath -Filter "Microsoft.WindowsTerminal*" | Select-Object -First 1
    
    if ($wtPackage) {
        $settingsPath = Join-Path $wtPackage.FullName "LocalState\settings.json"
        if (Test-Path $settingsPath) {
            return $settingsPath
        }
    }
    return $null
}

function Backup-TerminalSettings {
    param([string]$SettingsPath)
    
    if (!(Test-Path $BackupPath)) {
        New-Item -ItemType Directory -Path $BackupPath -Force | Out-Null
    }
    
    $backupFile = Join-Path $BackupPath "settings-backup-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
    Copy-Item -Path $SettingsPath -Destination $backupFile -Force
    Write-Log "Backup créé: $backupFile" "SUCCESS"
    return $backupFile
}

function Update-TerminalSettings {
    param([string]$SettingsPath)
    
    try {
        $jsonContent = Get-Content -Path $SettingsPath -Raw -Encoding UTF8
        $settings = $jsonContent | ConvertFrom-Json
        
        $modified = $false
        
        # 1. Configuration globale
        if ($settings.defaultProfile -eq $null) {
            # Si pas de profil par défaut, on prend le premier ou PowerShell
            $psProfile = $settings.profiles.list | Where-Object { $_.name -like "*PowerShell*" } | Select-Object -First 1
            if ($psProfile) {
                $settings.defaultProfile = $psProfile.guid
                Write-Log "Profil par défaut défini sur PowerShell ($($psProfile.guid))" "INFO"
                $modified = $true
            }
        }
        
        # 2. Configuration des profils (defaults)
        if ($settings.profiles.defaults -eq $null) {
            $settings.profiles | Add-Member -MemberType NoteProperty -Name "defaults" -Value @{}
        }
        
        $defaults = $settings.profiles.defaults
        
        # Police
        if ($defaults.font -eq $null) {
            $defaults | Add-Member -MemberType NoteProperty -Name "font" -Value @{}
        }
        if ($defaults.font.face -ne "Cascadia Code" -and $defaults.font.face -ne "Cascadia Mono") {
            $defaults.font.face = "Cascadia Code"
            Write-Log "Police par défaut définie sur Cascadia Code" "INFO"
            $modified = $true
        }
        
        # Rendu
        if ($defaults.useAtlasEngine -ne $true) {
            $defaults | Add-Member -MemberType NoteProperty -Name "useAtlasEngine" -Value $true -Force
            Write-Log "AtlasEngine activé pour le rendu de texte amélioré" "INFO"
            $modified = $true
        }
        
        # 3. Configuration spécifique PowerShell (si nécessaire)
        foreach ($profile in $settings.profiles.list) {
            if ($profile.name -like "*PowerShell*" -or $profile.commandline -like "*pwsh*" -or $profile.commandline -like "*powershell*") {
                # S'assurer que l'encodage n'est pas forcé incorrectement (WT gère UTF-8 nativement, mais on vérifie)
                # Pas de paramètre spécifique JSON pour forcer UTF-8 dans WT, c'est géré par le shell.
                # On s'assure juste que la police est bonne.
                if ($profile.font -eq $null) {
                     $profile | Add-Member -MemberType NoteProperty -Name "font" -Value @{ face = "Cascadia Code" }
                     $modified = $true
                } elseif ($profile.font.face -ne "Cascadia Code") {
                    $profile.font.face = "Cascadia Code"
                    $modified = $true
                }
            }
        }

        if ($modified) {
            $settings | ConvertTo-Json -Depth 10 | Out-File -FilePath $SettingsPath -Encoding UTF8 -Force
            Write-Log "Configuration Windows Terminal mise à jour avec succès." "SUCCESS"
            return $true
        } else {
            Write-Log "Aucune modification nécessaire pour Windows Terminal." "INFO"
            return $true
        }
        
    } catch {
        Write-Log "Erreur lors de la mise à jour de settings.json: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

# Main
try {
    Write-Log "Début de la configuration de Windows Terminal..." "INFO"
    
    $settingsPath = Get-WindowsTerminalSettingsPath
    
    if ($settingsPath) {
        Write-Log "Fichier de configuration trouvé: $settingsPath" "INFO"
        Backup-TerminalSettings -SettingsPath $settingsPath
        Update-TerminalSettings -SettingsPath $settingsPath
    } else {
        Write-Log "Windows Terminal non trouvé ou fichier settings.json inaccessible." "WARN"
        # On ne considère pas ça comme une erreur fatale car l'utilisateur peut ne pas utiliser WT
    }
    
    Write-Log "Configuration terminée." "SUCCESS"
    
} catch {
    Write-Log "Erreur inattendue: $($_.Exception.Message)" "ERROR"
    exit 1
}