<#
.SYNOPSIS
    Configure le terminal intégré de VSCode pour un support UTF-8 optimal.
.DESCRIPTION
    Ce script modifie la configuration utilisateur de VSCode (settings.json) pour :
    - Configurer le profil de terminal par défaut
    - Ajouter des arguments pour forcer UTF-8 (chcp 65001)
    - Configurer la police et le rendu
.PARAMETER BackupPath
    Chemin pour les backups de configuration (défaut: backups\vscode-config)
.EXAMPLE
    .\Configure-VSCodeTerminal.ps1
.NOTES
    Auteur: Roo Architect
    Date: 2025-11-26
    ID Tâche: SDDD-T001-J5-5
#>

[CmdletBinding()]
param(
    [string]$BackupPath = "backups\vscode-config"
)

# Configuration
$LogFile = "logs\Configure-VSCodeTerminal-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"

# Fonctions de logging
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    Write-Host $logEntry -ForegroundColor $(switch ($Level) { "ERROR" { "Red" } "WARN" { "Yellow" } "SUCCESS" { "Green" } default { "Cyan" } })
    if (!(Test-Path "logs")) { New-Item -ItemType Directory -Path "logs" -Force | Out-Null }
    Add-Content -Path $LogFile -Value $logEntry -Encoding UTF8
}

function Get-VSCodeSettingsPath {
    $settingsPath = "$env:APPDATA\Code\User\settings.json"
    if (Test-Path $settingsPath) {
        return $settingsPath
    }
    return $null
}

function Backup-VSCodeSettings {
    param([string]$SettingsPath)
    
    if (!(Test-Path $BackupPath)) {
        New-Item -ItemType Directory -Path $BackupPath -Force | Out-Null
    }
    
    $backupFile = Join-Path $BackupPath "vscode-settings-backup-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
    Copy-Item -Path $SettingsPath -Destination $backupFile -Force
    Write-Log "Backup créé: $backupFile" "SUCCESS"
    return $backupFile
}

function Update-VSCodeSettings {
    param([string]$SettingsPath)
    
    try {
        # Lecture du JSON avec commentaires (VSCode permet les commentaires, mais ConvertFrom-Json standard non)
        # On utilise une approche simple : lire tout le contenu, essayer de parser.
        # Si échec (commentaires), on avertit.
        
        $jsonContent = Get-Content -Path $SettingsPath -Raw -Encoding UTF8
        
        # Tentative de nettoyage des commentaires simples //
        $jsonClean = $jsonContent -replace "(?m)^\s*//.*$",""
        
        try {
            $settings = $jsonClean | ConvertFrom-Json
        } catch {
            Write-Log "Impossible de parser settings.json (probablement des commentaires). Modification manuelle requise ou utilisation d'un parser JSONC." "WARN"
            Write-Log "Erreur: $($_.Exception.Message)" "DEBUG"
            return $false
        }
        
        $modified = $false
        
        # 1. Configuration Terminal Intégré Windows
        if ($settings.'terminal.integrated.defaultProfile.windows' -ne "PowerShell") {
            $settings | Add-Member -MemberType NoteProperty -Name "terminal.integrated.defaultProfile.windows" -Value "PowerShell" -Force
            Write-Log "Profil terminal par défaut défini sur PowerShell" "INFO"
            $modified = $true
        }
        
        # 2. Profils Terminal
        if ($settings.'terminal.integrated.profiles.windows' -eq $null) {
            $settings | Add-Member -MemberType NoteProperty -Name "terminal.integrated.profiles.windows" -Value @{}
        }
        
        $profiles = $settings.'terminal.integrated.profiles.windows'
        
        # Configuration PowerShell avec UTF-8 forcé
        $psProfile = @{
            path = "pwsh.exe"
            args = @("-NoExit", "-Command", "chcp 65001")
            icon = "terminal-powershell"
        }
        
        # On vérifie si on doit mettre à jour le profil PowerShell
        if ($profiles.PowerShell -eq $null) {
            $profiles | Add-Member -MemberType NoteProperty -Name "PowerShell" -Value $psProfile
            Write-Log "Profil PowerShell créé avec support UTF-8" "INFO"
            $modified = $true
        } else {
            # Vérification des arguments
            $currentArgs = $profiles.PowerShell.args
            if ($currentArgs -notcontains "chcp 65001") {
                $profiles.PowerShell = $psProfile
                Write-Log "Profil PowerShell mis à jour pour forcer UTF-8" "INFO"
                $modified = $true
            }
        }
        
        # 3. Police et Rendu
        if ($settings.'terminal.integrated.fontFamily' -ne "'Cascadia Code', Consolas, 'Courier New', monospace") {
            $settings | Add-Member -MemberType NoteProperty -Name "terminal.integrated.fontFamily" -Value "'Cascadia Code', Consolas, 'Courier New', monospace" -Force
            Write-Log "Police terminal définie sur Cascadia Code" "INFO"
            $modified = $true
        }
        
        if ($settings.'terminal.integrated.gpuAcceleration' -ne "on") {
            $settings | Add-Member -MemberType NoteProperty -Name "terminal.integrated.gpuAcceleration" -Value "on" -Force
            Write-Log "Accélération GPU activée" "INFO"
            $modified = $true
        }

        if ($modified) {
            $settings | ConvertTo-Json -Depth 10 | Out-File -FilePath $SettingsPath -Encoding UTF8 -Force
            Write-Log "Configuration VSCode mise à jour avec succès." "SUCCESS"
            return $true
        } else {
            Write-Log "Aucune modification nécessaire pour VSCode." "INFO"
            return $true
        }
        
    } catch {
        Write-Log "Erreur lors de la mise à jour de settings.json: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

# Main
try {
    Write-Log "Début de la configuration du terminal VSCode..." "INFO"
    
    $settingsPath = Get-VSCodeSettingsPath
    
    if ($settingsPath) {
        Write-Log "Fichier de configuration trouvé: $settingsPath" "INFO"
        Backup-VSCodeSettings -SettingsPath $settingsPath
        Update-VSCodeSettings -SettingsPath $settingsPath
    } else {
        Write-Log "VSCode settings.json non trouvé." "WARN"
    }
    
    Write-Log "Configuration terminée." "SUCCESS"
    
} catch {
    Write-Log "Erreur inattendue: $($_.Exception.Message)" "ERROR"
    exit 1
}