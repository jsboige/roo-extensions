<#
.SYNOPSIS
    Migre l'environnement utilisateur vers Windows Terminal comme terminal par défaut.
.DESCRIPTION
    Ce script automatise la migration vers Windows Terminal :
    1. Vérifie l'installation de Windows Terminal.
    2. Configure Windows Terminal via Configure-WindowsTerminal.ps1.
    3. Tente de définir Windows Terminal comme terminal par défaut (nécessite Windows 11 ou Windows 10 récent).
    4. Génère un rapport de migration.
.PARAMETER Force
    Force la réapplication de la configuration même si déjà correcte.
.EXAMPLE
    .\Migrate-ToWindowsTerminal.ps1
.NOTES
    Auteur: Roo Architect
    Date: 2025-11-26
    ID Tâche: SDDD-T003
#>

[CmdletBinding()]
param(
    [switch]$Force
)

# Configuration
$LogFile = "logs\Migrate-ToWindowsTerminal-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
$ReportFile = "reports\migration-terminal-$(Get-Date -Format 'yyyyMMdd-HHmmss').md"

# Fonctions de logging
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    Write-Host $logEntry -ForegroundColor $(switch ($Level) { "ERROR" { "Red" } "WARN" { "Yellow" } "SUCCESS" { "Green" } default { "Cyan" } })
    if (!(Test-Path "logs")) { New-Item -ItemType Directory -Path "logs" -Force | Out-Null }
    Add-Content -Path $LogFile -Value $logEntry -Encoding UTF8
}

function Write-Report {
    param([string]$Content)
    if (!(Test-Path "reports")) { New-Item -ItemType Directory -Path "reports" -Force | Out-Null }
    Add-Content -Path $ReportFile -Value $Content -Encoding UTF8
}

# Initialisation du rapport
Write-Report "# Rapport de Migration Windows Terminal"
Write-Report "Date: $(Get-Date)"
Write-Report ""

try {
    Write-Log "Démarrage de la migration vers Windows Terminal..." "INFO"

    # 1. Vérification de l'installation
    Write-Log "Vérification de l'installation de Windows Terminal..." "INFO"
    $wtPackage = Get-AppxPackage -Name Microsoft.WindowsTerminal*
    
    if ($wtPackage) {
        Write-Log "Windows Terminal est installé: $($wtPackage.Name) ($($wtPackage.Version))" "SUCCESS"
        Write-Report "- [x] Windows Terminal installé: $($wtPackage.Version)"
    } else {
        Write-Log "Windows Terminal n'est PAS installé." "ERROR"
        Write-Report "- [ ] Windows Terminal installé: NON"
        Write-Report "ERREUR CRITIQUE: Windows Terminal doit être installé depuis le Microsoft Store ou via winget."
        throw "Windows Terminal non trouvé."
    }

    # 2. Configuration de base
    Write-Log "Lancement de la configuration de base (Configure-WindowsTerminal.ps1)..." "INFO"
    $configScript = Join-Path $PSScriptRoot "Configure-WindowsTerminal.ps1"
    if (Test-Path $configScript) {
        & $configScript
        if ($LASTEXITCODE -eq 0) {
             Write-Log "Configuration de base appliquée avec succès." "SUCCESS"
             Write-Report "- [x] Configuration de base appliquée (profils, polices)"
        } else {
             Write-Log "Erreur lors de la configuration de base." "WARN"
             Write-Report "- [!] Erreur lors de la configuration de base"
        }
    } else {
        Write-Log "Script de configuration introuvable: $configScript" "ERROR"
        Write-Report "- [ ] Script de configuration introuvable"
    }

    # 3. Définition comme terminal par défaut (Windows 11+)
    Write-Log "Tentative de définition comme terminal par défaut..." "INFO"
    
    # Vérification OS
    $osVersion = [System.Environment]::OSVersion.Version
    if ($osVersion.Major -ge 10 -and $osVersion.Build -ge 22000) {
        # Windows 11
        Write-Log "Windows 11 détecté. Vérification du terminal par défaut..." "INFO"
        
        # Clé de registre pour le terminal par défaut (HKCU\Console\%%Startup)
        # DelegationConsole : {2EACA947-7F5F-4CFA-BA87-8F7FBEEFBE69} = Windows Terminal
        # DelegationTerminal : {E12CFF52-A866-4C77-9A90-F570A7AA2C6B} = Let Windows Decide (conhost)
        
        $regPath = "HKCU:\Console\%%Startup"
        $wtGuid = "{2EACA947-7F5F-4CFA-BA87-8F7FBEEFBE69}"
        
        if (!(Test-Path $regPath)) {
            New-Item -Path $regPath -Force | Out-Null
        }
        
        $currentDelegation = Get-ItemProperty -Path $regPath -Name "DelegationConsole" -ErrorAction SilentlyContinue
        $currentTerminal = Get-ItemProperty -Path $regPath -Name "DelegationTerminal" -ErrorAction SilentlyContinue

        if ($currentDelegation.DelegationConsole -eq $wtGuid -or $currentTerminal.DelegationTerminal -eq $wtGuid) {
             Write-Log "Windows Terminal est DÉJÀ le terminal par défaut." "SUCCESS"
             Write-Report "- [x] Windows Terminal est le terminal par défaut"
        } else {
            Write-Log "Windows Terminal n'est pas le défaut. Tentative de modification..." "INFO"
            try {
                Set-ItemProperty -Path $regPath -Name "DelegationConsole" -Value $wtGuid -Force
                Set-ItemProperty -Path $regPath -Name "DelegationTerminal" -Value $wtGuid -Force
                Write-Log "Windows Terminal défini comme défaut via Registre." "SUCCESS"
                Write-Report "- [x] Windows Terminal défini comme défaut (Registre mis à jour)"
            } catch {
                Write-Log "Impossible de modifier le registre: $($_.Exception.Message)" "WARN"
                Write-Report "- [!] Échec de la définition automatique comme défaut (Permissions?)"
                Write-Report "  Action manuelle requise: Paramètres > Confidentialité et sécurité > Pour les développeurs > Terminal"
            }
        }

    } else {
        Write-Log "Version de Windows antérieure à 11 ($($osVersion.Build)). La définition par défaut programmatique est limitée." "WARN"
        Write-Report "- [!] OS antérieur à Windows 11. Configuration manuelle recommandée."
    }

    # 4. Validation finale
    Write-Log "Migration terminée." "SUCCESS"
    Write-Report ""
    Write-Report "## Conclusion"
    Write-Report "Migration effectuée. Veuillez redémarrer vos terminaux pour valider les changements."

} catch {
    Write-Log "Erreur fatale lors de la migration: $($_.Exception.Message)" "ERROR"
    Write-Report ""
    Write-Report "## ERREUR"
    Write-Report "La migration a échoué: $($_.Exception.Message)"
    exit 1
}