# Script de déploiement de l'architecture à 5 niveaux compatible avec Roo-Code
# Ce script déploie les configurations des modes pour l'architecture à 5 niveaux
# dans un format compatible avec Roo-Code

# Paramètres
param (
    [switch]$Force = $false,
    [switch]$SkipBackup = $false,
    [string]$ConfigFile = "$PSScriptRoot\..\configs\n5-modes-roo-compatible.json",
    [string]$DeploymentType = "global" # "global" ou "local"
)

# Constantes
$VSCodeGlobalStorage = "$env:APPDATA\Code\User\globalStorage\rooveterinaryinc.roo-cline\settings"
$LocalConfigPath = ".roomodes"
$BackupDir = "$PSScriptRoot\..\backup"
$Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"

# Fonction pour afficher des messages colorés
function Write-ColorOutput {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Message,
        
        [Parameter(Mandatory = $false)]
        [string]$ForegroundColor = "White"
    )
    
    Write-Host $Message -ForegroundColor $ForegroundColor
}

# Fonction pour créer un backup des configurations actuelles
function Backup-Configurations {
    if ($SkipBackup) {
        Write-ColorOutput "Sauvegarde ignorée (--skip-backup)" -ForegroundColor "Yellow"
        return
    }

    Write-ColorOutput "Création d'une sauvegarde des configurations actuelles..." -ForegroundColor "Cyan"
    
    # Créer le répertoire de sauvegarde s'il n'existe pas
    if (-not (Test-Path $BackupDir)) {
        New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null
    }
    
    # Déterminer le chemin du fichier à sauvegarder
    $sourcePath = ""
    if ($DeploymentType -eq "global") {
        $sourcePath = "$VSCodeGlobalStorage\custom_modes.json"
    } else {
        $sourcePath = "$LocalConfigPath"
    }
    
    # Sauvegarder le fichier s'il existe
    if (Test-Path $sourcePath) {
        $backupFile = "$BackupDir\modes_backup_$Timestamp.json"
        Copy-Item $sourcePath $backupFile
        Write-ColorOutput "Sauvegarde créée: $backupFile" -ForegroundColor "Green"
    } else {
        Write-ColorOutput "Aucun fichier de configuration trouvé à sauvegarder" -ForegroundColor "Yellow"
    }
}

# Fonction pour valider le fichier de configuration
function Test-Configuration {
    Write-ColorOutput "Validation du fichier de configuration..." -ForegroundColor "Cyan"
    
    # Vérifier que le fichier de configuration existe
    if (-not (Test-Path $ConfigFile)) {
        Write-ColorOutput "Erreur: Fichier de configuration non trouvé: $ConfigFile" -ForegroundColor "Red"
        return $false
    }
    
    # Vérifier que le fichier est un JSON valide
    try {
        $null = Get-Content $ConfigFile -Raw | ConvertFrom-Json
        Write-ColorOutput "Validation réussie: $ConfigFile" -ForegroundColor "Green"
        return $true
    } catch {
        Write-ColorOutput "Erreur: Fichier JSON invalide: $ConfigFile" -ForegroundColor "Red"
        Write-ColorOutput $_.Exception.Message -ForegroundColor "Red"
        return $false
    }
}

# Fonction pour déployer la configuration
function Deploy-Configuration {
    Write-ColorOutput "Déploiement de la configuration..." -ForegroundColor "Cyan"
    
    # Déterminer le chemin de destination
    $destinationPath = ""
    if ($DeploymentType -eq "global") {
        $destinationPath = "$VSCodeGlobalStorage\custom_modes.json"
        
        # Créer le répertoire de destination s'il n'existe pas
        if (-not (Test-Path $VSCodeGlobalStorage)) {
            New-Item -ItemType Directory -Path $VSCodeGlobalStorage -Force | Out-Null
            Write-ColorOutput "Répertoire de destination créé: $VSCodeGlobalStorage" -ForegroundColor "Green"
        }
    } else {
        $destinationPath = "$LocalConfigPath"
    }
    
    # Vérifier si le fichier de destination existe déjà
    if ((Test-Path $destinationPath) -and (-not $Force)) {
        Write-ColorOutput "Le fichier de destination existe déjà. Utilisez -Force pour écraser." -ForegroundColor "Yellow"
        return $false
    }
    
    # Copier le fichier de configuration
    try {
        Copy-Item $ConfigFile $destinationPath -Force
        Write-ColorOutput "Configuration déployée avec succès: $destinationPath" -ForegroundColor "Green"
        return $true
    } catch {
        Write-ColorOutput "Erreur lors du déploiement: $_" -ForegroundColor "Red"
        return $false
    }
}

# Fonction principale
function Main {
    Write-ColorOutput "=== Déploiement de l'architecture à 5 niveaux compatible avec Roo-Code ===" -ForegroundColor "Magenta"
    
    # Afficher les paramètres
    Write-ColorOutput "Paramètres:" -ForegroundColor "Cyan"
    Write-ColorOutput "  Fichier de configuration: $ConfigFile" -ForegroundColor "Cyan"
    Write-ColorOutput "  Type de déploiement: $DeploymentType" -ForegroundColor "Cyan"
    Write-ColorOutput "  Force: $Force" -ForegroundColor "Cyan"
    Write-ColorOutput "  SkipBackup: $SkipBackup" -ForegroundColor "Cyan"
    
    # Créer une sauvegarde
    Backup-Configurations
    
    # Valider la configuration
    $configValid = Test-Configuration
    if (-not $configValid -and -not $Force) {
        Write-ColorOutput "Erreur: La configuration est invalide. Utilisez -Force pour déployer quand même." -ForegroundColor "Red"
        exit 1
    }
    
    # Déployer la configuration
    $deployed = Deploy-Configuration
    if (-not $deployed) {
        Write-ColorOutput "Déploiement annulé." -ForegroundColor "Yellow"
        exit 1
    }
    
    Write-ColorOutput "=== Déploiement terminé avec succès ===" -ForegroundColor "Magenta"
    Write-ColorOutput "Configuration déployée: $ConfigFile" -ForegroundColor "Green"
    Write-ColorOutput "Type de déploiement: $DeploymentType" -ForegroundColor "Green"
    
    # Rappel pour redémarrer VS Code
    Write-ColorOutput "N'oubliez pas de redémarrer Visual Studio Code pour appliquer les changements." -ForegroundColor "Yellow"
}

# Exécuter la fonction principale
Main