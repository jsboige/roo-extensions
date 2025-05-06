# Script de déploiement de la configuration générale Roo
# Ce script permet de déployer la configuration générale de Roo

param (
    [Parameter(Mandatory = $false)]
    [string]$ConfigFile = "settings.json",
    
    [Parameter(Mandatory = $false)]
    [switch]$Force
)

# Forcer l'encodage UTF-8 pour la sortie
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# Fonction pour afficher des messages colorés
function Write-ColorOutput {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Message,
        
        [Parameter(Mandatory = $false)]
        [string]$ForegroundColor = "White"
    )
    
    $originalColor = $host.UI.RawUI.ForegroundColor
    $host.UI.RawUI.ForegroundColor = $ForegroundColor
    Write-Output $Message
    $host.UI.RawUI.ForegroundColor = $originalColor
}

# Bannière
Write-ColorOutput "`n=========================================================" "Cyan"
Write-ColorOutput "   Déploiement de la configuration générale Roo" "Cyan"
Write-ColorOutput "=========================================================" "Cyan"

# Vérifier que le fichier de configuration existe
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$configFilePath = Join-Path -Path $scriptDir -ChildPath $ConfigFile

if (-not (Test-Path -Path $configFilePath)) {
    Write-ColorOutput "Erreur: Le fichier de configuration '$ConfigFile' n'existe pas." "Red"
    Write-ColorOutput "Assurez-vous que le fichier existe dans le répertoire 'roo-settings/'." "Red"
    exit 1
}

# Déterminer le chemin du fichier de destination selon le système d'exploitation
if ($env:OS -match "Windows") {
    $destinationDir = Join-Path -Path $env:APPDATA -ChildPath "roo"
} elseif ($IsMacOS) {
    $destinationDir = Join-Path -Path $HOME -ChildPath "Library/Application Support/roo"
} else {
    # Supposer Linux
    $destinationDir = Join-Path -Path $HOME -ChildPath ".config/roo"
}

$destinationFile = Join-Path -Path $destinationDir -ChildPath "config.json"

# Vérifier que le répertoire de destination existe
if (-not (Test-Path -Path $destinationDir)) {
    try {
        New-Item -Path $destinationDir -ItemType Directory -Force | Out-Null
        Write-ColorOutput "Répertoire créé: $destinationDir" "Green"
    }
    catch {
        Write-ColorOutput "Erreur lors de la création du répertoire: $destinationDir" "Red"
        Write-ColorOutput $_.Exception.Message "Red"
        exit 1
    }
}

Write-ColorOutput "`nDéploiement de la configuration '$ConfigFile'..." "Yellow"
Write-ColorOutput "Destination: $destinationFile" "Yellow"

# Vérifier si le fichier de destination existe déjà
if (Test-Path -Path $destinationFile) {
    if (-not $Force) {
        Write-ColorOutput "ATTENTION: Ce fichier contient généralement des clés d'API et autres informations sensibles." "Yellow"
        Write-ColorOutput "Le déploiement écrasera ces informations si elles existent déjà." "Yellow"
        $confirmation = Read-Host "Le fichier de destination existe déjà. Voulez-vous le remplacer? (O/N)"
        if ($confirmation -ne "O" -and $confirmation -ne "o") {
            Write-ColorOutput "Opération annulée." "Yellow"
            exit 0
        }
    }
    
    # Créer une sauvegarde du fichier existant
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $backupFile = "$destinationFile.backup_$timestamp"
    try {
        Copy-Item -Path $destinationFile -Destination $backupFile -Force
        Write-ColorOutput "Sauvegarde créée: $backupFile" "Green"
    } catch {
        Write-ColorOutput "Erreur lors de la création de la sauvegarde:" "Red"
        Write-ColorOutput $_.Exception.Message "Red"
        # Continuer malgré l'erreur de sauvegarde
    }
}

# Copier le fichier
try {
    Copy-Item -Path $configFilePath -Destination $destinationFile -Force
    Write-ColorOutput "Déploiement réussi!" "Green"
} catch {
    Write-ColorOutput "Erreur lors du déploiement:" "Red"
    Write-ColorOutput $_.Exception.Message "Red"
    exit 1
}

# Résumé
Write-ColorOutput "`n=========================================================" "Cyan"
Write-ColorOutput "   Déploiement terminé avec succès!" "Green"
Write-ColorOutput "=========================================================" "Cyan"

Write-ColorOutput "`nLa configuration générale a été déployée." "White"
Write-ColorOutput "IMPORTANT: Ce fichier ne contient pas les clés d'API et autres informations sensibles." "Yellow"
Write-ColorOutput "Vous devrez ajouter manuellement ces informations au fichier de configuration." "Yellow"

Write-ColorOutput "`nPour activer la configuration:" "White"
Write-ColorOutput "1. Ajoutez vos clés d'API et autres informations sensibles au fichier $destinationFile" "White"
Write-ColorOutput "2. Redémarrez Visual Studio Code" "White"
Write-ColorOutput "`n" "White"