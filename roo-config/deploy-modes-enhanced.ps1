# Script de déploiement des modes personnalisés Roo
# Ce script permet de déployer une configuration de modes soit globalement, soit localement
# Version améliorée avec support des profils

param (
    [Parameter(Mandatory = $false)]
    [string]$ConfigFile = "modes/standard-modes.json",
    
    [Parameter(Mandatory = $false)]
    [ValidateSet("global", "local")]
    [string]$DeploymentType = "global",
    
    [Parameter(Mandatory = $false)]
    [switch]$Force,
    
    [Parameter(Mandatory = $false)]
    [string]$ProfileName = "",
    
    [Parameter(Mandatory = $false)]
    [string]$ProfileConfigFile = "model-configs.json"
)

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
Write-ColorOutput "   Déploiement des modes personnalisés Roo" "Cyan"
Write-ColorOutput "=========================================================" "Cyan"

# Vérifier si un profil a été spécifié
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

if (-not [string]::IsNullOrEmpty($ProfileName)) {
    Write-ColorOutput "Profil spécifié: $ProfileName. Utilisation du script de déploiement basé sur profil..." "Yellow"
    
    # Appeler le script de déploiement basé sur profil
    $deployProfileScript = Join-Path -Path $scriptDir -ChildPath "deploy-profile-modes.ps1"
    
    if (-not (Test-Path -Path $deployProfileScript)) {
        Write-ColorOutput "Erreur: Le script de déploiement basé sur profil n'existe pas: $deployProfileScript" "Red"
        exit 1
    }
    
    # Construire les arguments pour le script de déploiement basé sur profil
    $arguments = @{
        ProfileName = $ProfileName
        DeploymentType = $DeploymentType
        ConfigFile = $ProfileConfigFile
    }
    
    if ($Force) {
        $arguments.Force = $true
    }
    
    # Appeler le script avec les arguments
    & $deployProfileScript @arguments
    
    # Sortir du script actuel
    exit $LASTEXITCODE
}

# Si aucun profil n'est spécifié, continuer avec le déploiement standard
Write-ColorOutput "Aucun profil spécifié. Utilisation du déploiement standard..." "Yellow"

# Vérifier que le fichier de configuration existe
$configFilePath = Join-Path -Path $scriptDir -ChildPath $ConfigFile

if (-not (Test-Path -Path $configFilePath)) {
    Write-ColorOutput "Erreur: Le fichier de configuration '$ConfigFile' n'existe pas." "Red"
    Write-ColorOutput "Assurez-vous que le fichier existe dans le répertoire 'roo-config/modes/'." "Red"
    exit 1
}

# Déterminer le chemin du fichier de destination
if ($DeploymentType -eq "global") {
    $destinationDir = Join-Path -Path $env:APPDATA -ChildPath "Code\User\globalStorage\rooveterinaryinc.roo-cline\settings"
    $destinationFile = Join-Path -Path $destinationDir -ChildPath "custom_modes.json"
    
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
} else {
    # Déploiement local (dans le répertoire du projet)
    $projectRoot = Split-Path -Parent (Split-Path -Parent $scriptDir)
    $destinationFile = Join-Path -Path $projectRoot -ChildPath ".roomodes"
}

Write-ColorOutput "`nDéploiement de la configuration '$ConfigFile' en mode $DeploymentType..." "Yellow"
Write-ColorOutput "Destination: $destinationFile" "Yellow"

# Vérifier si le fichier de destination existe déjà
if (Test-Path -Path $destinationFile) {
    if (-not $Force) {
        $confirmation = Read-Host "Le fichier de destination existe déjà. Voulez-vous le remplacer? (O/N)"
        if ($confirmation -ne "O" -and $confirmation -ne "o") {
            Write-ColorOutput "Opération annulée." "Yellow"
            exit 0
        }
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

# Vérifier que les fichiers sont identiques
try {
    $diff = Compare-Object -ReferenceObject (Get-Content $configFilePath) -DifferenceObject (Get-Content $destinationFile)
    
    if ($null -eq $diff) {
        Write-ColorOutput "Vérification réussie: Les fichiers sont identiques." "Green"
    } else {
        Write-ColorOutput "Avertissement: Les fichiers ne sont pas identiques." "Yellow"
        Write-ColorOutput "Différences trouvées:" "Yellow"
        $diff | Format-Table -AutoSize
    }
} catch {
    Write-ColorOutput "Erreur lors de la vérification des fichiers:" "Red"
    Write-ColorOutput $_.Exception.Message "Red"
}

# Résumé
Write-ColorOutput "`n=========================================================" "Cyan"
Write-ColorOutput "   Déploiement terminé avec succès!" "Green"
Write-ColorOutput "=========================================================" "Cyan"

if ($DeploymentType -eq "global") {
    Write-ColorOutput "`nLes modes personnalisés ont été déployés globalement et seront disponibles dans toutes les instances de VS Code." "White"
} else {
    Write-ColorOutput "`nLes modes personnalisés ont été déployés localement et seront disponibles uniquement dans ce projet." "White"
}

Write-ColorOutput "`nPour activer les modes personnalisés:" "White"
Write-ColorOutput "1. Redémarrez Visual Studio Code" "White"
Write-ColorOutput "2. Ouvrez la palette de commandes (Ctrl+Shift+P)" "White"
Write-ColorOutput "3. Tapez 'Roo: Switch Mode' et sélectionnez un mode personnalisé" "White"
Write-ColorOutput "`n" "White"

Write-ColorOutput "Astuce: Pour déployer une configuration basée sur un profil, utilisez le paramètre -ProfileName:" "Green"
Write-ColorOutput ".\deploy-modes-enhanced.ps1 -ProfileName `"nom_du_profil`" -DeploymentType global" "Yellow"
Write-ColorOutput "`n" "White"