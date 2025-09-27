#Requires -Version 5.1
<#
.SYNOPSIS
    Script de configuration UTF-8 consolidé (Version ASCII-Safe)

.DESCRIPTION
    Version sans emojis ni caractères spéciaux pour éviter les problèmes d'encodage lors des tests.

.PARAMETER TestConfiguration
    Test la configuration actuelle sans la modifier

.PARAMETER Force  
    Force la reconfiguration

.EXAMPLE
    .\setup-ascii-safe.ps1 -TestConfiguration

.NOTES
    Version: 3.0 ASCII-Safe
    Date: 26/09/2025
#>

param (
    [switch]$TestConfiguration,
    [switch]$Force
)

# Variables globales
$Script:Colors = @{
    Success = "Green"
    Warning = "Yellow"
    Error = "Red"
    Info = "Cyan"
    Header = "Magenta"
    Default = "White"
}

function Write-SafeOutput {
    param (
        [string]$Message,
        [string]$ForegroundColor = "White"
    )
    
    Write-Host $Message -ForegroundColor $ForegroundColor
}

function Test-CurrentConfiguration {
    Write-SafeOutput "`n=== TEST DE LA CONFIGURATION ACTUELLE ===" "Magenta"
    
    $results = @{
        PowerShellUTF8 = ($([Console]::OutputEncoding.CodePage) -eq 65001)
        SystemCodePage = (cmd /c chcp 2>&1) -match "65001"
        ProfileExists = (Test-Path $PROFILE)
        ProfileConfigured = $false
        GitConfigured = $false
    }
    
    # Vérifier la configuration du profil
    if ($results.ProfileExists) {
        $profileContent = Get-Content -Path $PROFILE -Raw -ErrorAction SilentlyContinue
        $results.ProfileConfigured = $profileContent -match "Configuration d'encodage pour roo-extensions"
    }
    
    # Vérifier la configuration Git
    try {
        $gitEncoding = git config --global i18n.commitencoding 2>$null
        $results.GitConfigured = ($gitEncoding -eq "utf-8")
    } catch {
        $results.GitConfigured = $false
    }
    
    # Afficher les résultats
    Write-SafeOutput "`nResultats du diagnostic :" "Cyan"
    Write-SafeOutput "PowerShell UTF-8: $(if($results.PowerShellUTF8) { 'OUI' } else { 'NON' })" $(if($results.PowerShellUTF8) { "Green" } else { "Red" })
    Write-SafeOutput "Code Page Systeme: $(if($results.SystemCodePage) { '65001 (UTF-8)' } else { 'PAS UTF-8' })" $(if($results.SystemCodePage) { "Green" } else { "Red" })
    Write-SafeOutput "Profil PowerShell: $(if($results.ProfileConfigured) { 'CONFIGURE' } else { 'NON CONFIGURE' })" $(if($results.ProfileConfigured) { "Green" } else { "Red" })
    Write-SafeOutput "Configuration Git: $(if($results.GitConfigured) { 'CONFIGUREE' } else { 'NON CONFIGUREE' })" $(if($results.GitConfigured) { "Green" } else { "Red" })
    
    $allConfigured = $results.PowerShellUTF8 -and $results.ProfileConfigured -and $results.GitConfigured
    Write-SafeOutput "`nEtat general: $(if($allConfigured) { 'TOUT EST CONFIGURE' } else { 'CONFIGURATION INCOMPLETE' })" $(if($allConfigured) { "Green" } else { "Yellow" })
    
    return $results
}

function Set-PowerShellEncodingBasic {
    Write-SafeOutput "1. Configuration PowerShell..." "Green"
    
    $profilePath = $PROFILE
    $profileExists = Test-Path -Path $profilePath
    $profileContent = ""
    
    if ($profileExists) {
        $profileContent = Get-Content -Path $profilePath -Raw -ErrorAction SilentlyContinue
    }
    
    # Configuration d'encodage
    $encodingSettings = @"

# Configuration d'encodage pour roo-extensions - Version Consolidee
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new()
[Console]::InputEncoding = [System.Text.UTF8Encoding]::new()
`$OutputEncoding = [System.Text.UTF8Encoding]::new()
`$PSDefaultParameterValues['Out-File:Encoding'] = 'utf8NoBOM'
`$PSDefaultParameterValues['Set-Content:Encoding'] = 'utf8NoBOM'
try { chcp 65001 | Out-Null } catch { Write-Warning "Impossible de definir la code page 65001" }
# Fin de la configuration d'encodage
"@
    
    # Vérifier si déjà configuré
    if ($profileExists -and $profileContent -match "\[Console\]::OutputEncoding = \[System\.Text\.UTF8Encoding\]::new\(\)") {
        if ($Force) {
            Write-SafeOutput "   Reconfiguration forcee..." "Yellow"
        } else {
            Write-SafeOutput "   Deja configure. Utilisez -Force pour reconfigurer." "Yellow"
            return $true
        }
    }
    
    try {
        # Créer le répertoire du profil si nécessaire
        $profileDir = Split-Path -Path $profilePath -Parent
        if (-not (Test-Path -Path $profileDir)) {
            New-Item -Path $profileDir -ItemType Directory -Force | Out-Null
        }
        
        # Modifier le profil
        if ($profileExists) {
            $profileContent = $profileContent -replace "# Configuration d'encodage pour roo-extensions[\s\S]*?# Fin de la configuration d'encodage", ""
            $profileContent += $encodingSettings
            Set-Content -Path $profilePath -Value $profileContent -Encoding UTF8
        } else {
            Set-Content -Path $profilePath -Value $encodingSettings -Encoding UTF8
        }
        
        # Appliquer à la session actuelle
        [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new()
        [Console]::InputEncoding = [System.Text.UTF8Encoding]::new()
        $OutputEncoding = [System.Text.UTF8Encoding]::new()
        $PSDefaultParameterValues['Out-File:Encoding'] = 'utf8NoBOM'
        $PSDefaultParameterValues['Set-Content:Encoding'] = 'utf8NoBOM'
        try { chcp 65001 | Out-Null } catch { }
        
        Write-SafeOutput "   Configuration PowerShell terminee avec succes." "Green"
        return $true
    } catch {
        Write-SafeOutput "   Erreur lors de la configuration PowerShell: $_" "Red"
        return $false
    }
}

function Set-GitConfigurationBasic {
    Write-SafeOutput "2. Configuration Git..." "Green"
    
    try {
        $gitVersion = git --version 2>$null
        if (-not $?) {
            Write-SafeOutput "   Git non installe. Configuration Git ignoree." "Yellow"
            return $false
        }
        
        # Configurer Git
        git config --global core.autocrlf input
        git config --global core.safecrlf warn
        git config --global i18n.commitencoding utf-8
        git config --global i18n.logoutputencoding utf-8
        git config --global core.quotepath false
        git config --global gui.encoding utf-8
        
        Write-SafeOutput "   Configuration Git terminee avec succes." "Green"
        return $true
    } catch {
        Write-SafeOutput "   Erreur lors de la configuration Git: $_" "Red"
        return $false
    }
}

# Programme principal
Write-SafeOutput "=========================================================" "Cyan"
Write-SafeOutput "  CONFIGURATION UTF-8 CONSOLIDEE - VERSION ASCII-SAFE" "Cyan"
Write-SafeOutput "=========================================================" "Cyan"
Write-Host ""

if ($TestConfiguration) {
    Test-CurrentConfiguration
    exit 0
}

# Configuration
$results = @{
    PowerShell = Set-PowerShellEncodingBasic
    Git = Set-GitConfigurationBasic
}

# Résumé
Write-Host ""
Write-SafeOutput "=========================================================" "Cyan"
Write-SafeOutput "  CONFIGURATION TERMINEE" "Cyan"
Write-SafeOutput "=========================================================" "Cyan"
Write-Host ""

Write-SafeOutput "Résumé des actions effectuees:" "White"
Write-SafeOutput "Configuration PowerShell: $(if($results.PowerShell) { 'SUCCES' } else { 'ECHEC' })" $(if($results.PowerShell) { "Green" } else { "Red" })
Write-SafeOutput "Configuration Git: $(if($results.Git) { 'SUCCES' } else { 'ECHEC' })" $(if($results.Git) { "Green" } else { "Red" })

$allSuccess = $results.PowerShell -and $results.Git
Write-SafeOutput "`nStatut global: $(if($allSuccess) { 'CONFIGURATION REUSSIE' } else { 'PROBLEMES DETECTES' })" $(if($allSuccess) { "Green" } else { "Yellow" })

if ($allSuccess) {
    Write-SafeOutput "`nRedemarrez votre session PowerShell pour appliquer tous les changements." "Cyan"
}

# Code de sortie
exit $(if($allSuccess) { 0 } else { 1 })