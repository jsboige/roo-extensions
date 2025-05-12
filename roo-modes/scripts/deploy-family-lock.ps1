# Script de déploiement du système de verrouillage de famille pour les modes Roo
# Ce script PowerShell installe et configure le système de verrouillage de famille

# Définition des chemins
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$rootPath = Split-Path -Parent $scriptPath
$configPath = Join-Path -Path $rootPath -ChildPath "configs"
$backupPath = Join-Path -Path $rootPath -ChildPath "backups"
$logPath = Join-Path -Path $rootPath -ChildPath "logs"

# Fonction pour afficher les messages avec couleur
function Write-ColorOutput {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Message,
        
        [Parameter(Mandatory=$false)]
        [string]$ForegroundColor = "White"
    )
    
    $originalColor = $host.UI.RawUI.ForegroundColor
    $host.UI.RawUI.ForegroundColor = $ForegroundColor
    Write-Output $Message
    $host.UI.RawUI.ForegroundColor = $originalColor
}

# Fonction pour créer un répertoire s'il n'existe pas
function Ensure-Directory {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Path
    )
    
    if (-not (Test-Path -Path $Path)) {
        Write-ColorOutput "Création du répertoire: $Path" -ForegroundColor "Yellow"
        New-Item -Path $Path -ItemType Directory | Out-Null
    }
}

# Fonction pour créer une sauvegarde de la configuration
function Backup-Configuration {
    param (
        [Parameter(Mandatory=$true)]
        [string]$ConfigFile
    )
    
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $backupFile = Join-Path -Path $backupPath -ChildPath "modes_backup_$timestamp.json"
    
    Ensure-Directory -Path $backupPath
    
    if (Test-Path -Path $ConfigFile) {
        Write-ColorOutput "Création d'une sauvegarde: $backupFile" -ForegroundColor "Yellow"
        Copy-Item -Path $ConfigFile -Destination $backupFile
        return $true
    } else {
        Write-ColorOutput "Erreur: Le fichier de configuration n'existe pas: $ConfigFile" -ForegroundColor "Red"
        return $false
    }
}

# Vérification des prérequis
Write-ColorOutput "Vérification des prérequis..." -ForegroundColor "Cyan"

# Vérifier si Node.js est installé
try {
    $nodeVersion = node --version
    Write-ColorOutput "Node.js version: $nodeVersion" -ForegroundColor "Green"
} catch {
    Write-ColorOutput "Erreur: Node.js n'est pas installé ou n'est pas accessible." -ForegroundColor "Red"
    exit 1
}

# Vérifier si les répertoires nécessaires existent
Ensure-Directory -Path $configPath
Ensure-Directory -Path $logPath

# Vérifier si le fichier de configuration existe
$configFile = Join-Path -Path $configPath -ChildPath "standard-modes.json"
if (-not (Test-Path -Path $configFile)) {
    Write-ColorOutput "Erreur: Le fichier de configuration n'existe pas: $configFile" -ForegroundColor "Red"
    exit 1
}

# Créer une sauvegarde de la configuration
$backupSuccess = Backup-Configuration -ConfigFile $configFile
if (-not $backupSuccess) {
    Write-ColorOutput "Erreur: Impossible de créer une sauvegarde de la configuration." -ForegroundColor "Red"
    exit 1
}

# Installation du système de verrouillage de famille
Write-ColorOutput "`nInstallation du système de verrouillage de famille..." -ForegroundColor "Cyan"

# Exécuter le script d'installation
try {
    Write-ColorOutput "Exécution du script d'installation..." -ForegroundColor "Yellow"
    $installScript = Join-Path -Path $scriptPath -ChildPath "install-family-lock.js"
    node $installScript
    
    if ($LASTEXITCODE -ne 0) {
        Write-ColorOutput "Erreur: Le script d'installation a échoué avec le code $LASTEXITCODE." -ForegroundColor "Red"
        exit 1
    }
    
    Write-ColorOutput "Installation réussie!" -ForegroundColor "Green"
} catch {
    Write-ColorOutput "Erreur lors de l'exécution du script d'installation: $_" -ForegroundColor "Red"
    exit 1
}

# Exécuter les tests
Write-ColorOutput "`nExécution des tests..." -ForegroundColor "Cyan"

try {
    $testScript = Join-Path -Path $scriptPath -ChildPath "test-family-lock.js"
    node $testScript
    
    if ($LASTEXITCODE -ne 0) {
        Write-ColorOutput "Attention: Certains tests ont échoué. Vérifiez les résultats des tests." -ForegroundColor "Yellow"
    } else {
        Write-ColorOutput "Tous les tests ont réussi!" -ForegroundColor "Green"
    }
} catch {
    Write-ColorOutput "Erreur lors de l'exécution des tests: $_" -ForegroundColor "Red"
}

# Afficher les instructions post-installation
Write-ColorOutput "`nInstructions post-installation:" -ForegroundColor "Cyan"
Write-ColorOutput "1. Redémarrez les services Roo si nécessaire" -ForegroundColor "White"
Write-ColorOutput "2. Vérifiez les journaux dans le répertoire 'logs' pour vous assurer que le système fonctionne correctement" -ForegroundColor "White"
Write-ColorOutput "3. Consultez le fichier 'docs/guide-verrouillage-famille-modes.md' pour plus d'informations" -ForegroundColor "White"

Write-ColorOutput "`nDéploiement terminé!" -ForegroundColor "Green"