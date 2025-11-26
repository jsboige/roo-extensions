<#
.SYNOPSIS
    Configure les profils PowerShell pour utiliser la gestion d'encodage unifiée.
.DESCRIPTION
    Ce script déploie les profils PowerShell standardisés pour PS 5.1 et PS 7+.
    Il effectue une sauvegarde des profils existants avant toute modification.
.PARAMETER Force
    Écrase les profils existants sans demander confirmation.
.PARAMETER BackupPath
    Chemin où stocker les sauvegardes des profils (défaut: backups\profiles).
.NOTES
    Auteur: Roo Architect
    Date: 2025-10-30
    Version: 1.0
#>

[CmdletBinding()]
param(
    [switch]$Force,
    [string]$BackupPath = "backups\profiles"
)

# Configuration
$script:TemplatesPath = Join-Path $PSScriptRoot "..\..\profiles\templates"
$script:LogFile = "logs\Configure-PowerShellProfiles-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"

# Fonctions de logging (simplifiées)
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $entry = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [$Level] $Message"
    Write-Host $entry -ForegroundColor $(if ($Level -eq "ERROR") { "Red" } elseif ($Level -eq "WARN") { "Yellow" } else { "Cyan" })
    
    if (-not (Test-Path "logs")) { New-Item -ItemType Directory -Path "logs" -Force | Out-Null }
    Add-Content -Path $script:LogFile -Value $entry -Encoding UTF8
}

function Backup-Profile {
    param([string]$ProfilePath)
    
    if (Test-Path $ProfilePath) {
        if (-not (Test-Path $BackupPath)) { New-Item -ItemType Directory -Path $BackupPath -Force | Out-Null }
        
        $fileName = Split-Path $ProfilePath -Leaf
        $backupFile = Join-Path $BackupPath "$fileName-$(Get-Date -Format 'yyyyMMdd-HHmmss').bak"
        
        Copy-Item -Path $ProfilePath -Destination $backupFile -Force
        Write-Log "Backup créé: $backupFile" "INFO"
        return $true
    }
    return $false
}

function Install-Profile {
    param(
        [string]$TargetProfilePath,
        [string]$TemplateName
    )
    
    $templatePath = Join-Path $script:TemplatesPath $TemplateName
    
    if (-not (Test-Path $templatePath)) {
        Write-Log "Template introuvable: $templatePath" "ERROR"
        return $false
    }
    
    Write-Log "Installation du profil: $TargetProfilePath" "INFO"
    
    # Création du répertoire parent si nécessaire
    $parentDir = Split-Path $TargetProfilePath -Parent
    if (-not (Test-Path $parentDir)) {
        New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
        Write-Log "Répertoire créé: $parentDir" "INFO"
    }
    
    # Backup si existant
    if (Test-Path $TargetProfilePath) {
        Backup-Profile -ProfilePath $TargetProfilePath
        
        if (-not $Force) {
            Write-Log "Le profil existe déjà. Utilisez -Force pour écraser ou fusionner manuellement." "WARN"
            # TODO: Implémenter une fusion intelligente si nécessaire
            # Pour l'instant, on n'écrase pas sans Force, mais on peut ajouter l'appel au script d'encodage
            
            $content = Get-Content $TargetProfilePath -Raw
            if ($content -notmatch "Initialize-EncodingManager.ps1") {
                Write-Log "Ajout de l'appel EncodingManager au profil existant..." "INFO"
                $initScript = "`n# --- Added by Roo Code ---`n. `"$((Resolve-Path 'scripts\encoding\Initialize-EncodingManager.ps1').Path)`"`n"
                Add-Content -Path $TargetProfilePath -Value $initScript -Encoding UTF8
                Write-Log "Profil mis à jour avec EncodingManager." "SUCCESS"
            } else {
                Write-Log "Le profil contient déjà l'appel à EncodingManager." "INFO"
            }
            return $true
        }
    }
    
    # Installation du nouveau profil (si Force ou inexistant)
    Copy-Item -Path $templatePath -Destination $TargetProfilePath -Force
    Write-Log "Profil installé avec succès." "SUCCESS"
    return $true
}

# --- Main ---

Write-Log "Début de la configuration des profils PowerShell..." "INFO"

# 1. Configuration PowerShell 5.1 (CurrentUserCurrentHost)
# Note: $PROFILE dans PS 5.1 pointe généralement vers Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1
$ps5Profile = [System.Environment]::GetFolderPath("MyDocuments") + "\WindowsPowerShell\Microsoft.PowerShell_profile.ps1"
Install-Profile -TargetProfilePath $ps5Profile -TemplateName "Microsoft.PowerShell_profile.ps1"

# 2. Configuration PowerShell 7+ (CurrentUserCurrentHost)
# Note: $PROFILE dans PS 7 pointe généralement vers Documents\PowerShell\Microsoft.PowerShell_profile.ps1
$ps7Profile = [System.Environment]::GetFolderPath("MyDocuments") + "\PowerShell\Microsoft.PowerShell_profile.ps1"
Install-Profile -TargetProfilePath $ps7Profile -TemplateName "Microsoft.PowerShell_profile_v7.ps1"

Write-Log "Configuration terminée." "INFO"