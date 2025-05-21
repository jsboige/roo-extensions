# Script de déploiement des modes personnalisés Roo basé sur des profils
# Ce script permet de déployer une configuration de modes basée sur un profil spécifique

param (
    [Parameter(Mandatory = $true)]
    [string]$ProfileName,
    
    [Parameter(Mandatory = $false)]
    [ValidateSet("global", "local")]
    [string]$DeploymentType = "global",
    
    [Parameter(Mandatory = $false)]
    [switch]$Force,
    
    [Parameter(Mandatory = $false)]
    [string]$ConfigFile = "model-configs.json",
    
    [Parameter(Mandatory = $false)]
    [string]$OutputFile = "modes/generated-profile-modes.json"
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
Write-ColorOutput "   Déploiement des modes personnalisés Roo basé sur profil" "Cyan"
Write-ColorOutput "=========================================================" "Cyan"

# Vérifier que le fichier de configuration existe
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$configFilePath = Join-Path -Path $scriptDir -ChildPath $ConfigFile

if (-not (Test-Path -Path $configFilePath)) {
    Write-ColorOutput "Erreur: Le fichier de configuration '$ConfigFile' n'existe pas." "Red"
    Write-ColorOutput "Assurez-vous que le fichier existe dans le répertoire 'roo-config/'." "Red"
    exit 1
}

# Charger le fichier de configuration des profils
try {
    $profilesConfig = Get-Content -Path $configFilePath -Raw | ConvertFrom-Json
    Write-ColorOutput "Fichier de configuration des profils chargé avec succès." "Green"
} catch {
    Write-ColorOutput "Erreur lors du chargement du fichier de configuration des profils:" "Red"
    Write-ColorOutput $_.Exception.Message "Red"
    exit 1
}

# Vérifier si le profil spécifié existe
$profile = $null

# Vérifier si la structure utilise "profiles" ou "configurations"
if ($profilesConfig.PSObject.Properties.Name -contains "profiles") {
    $profilesList = $profilesConfig.profiles
    Write-ColorOutput "Structure de profils détectée." "Green"
} elseif ($profilesConfig.PSObject.Properties.Name -contains "configurations") {
    $profilesList = $profilesConfig.configurations
    Write-ColorOutput "Structure de configurations détectée (sera convertie en profils)." "Yellow"
} else {
    Write-ColorOutput "Erreur: Structure de configuration non reconnue." "Red"
    Write-ColorOutput "Le fichier doit contenir une propriété 'profiles' ou 'configurations'." "Red"
    exit 1
}

$profile = $profilesList | Where-Object { $_.name -eq $ProfileName }

if ($null -eq $profile) {
    Write-ColorOutput "Erreur: Le profil '$ProfileName' n'existe pas dans le fichier de configuration." "Red"
    Write-ColorOutput "Profils disponibles:" "Yellow"
    $profilesList | ForEach-Object { Write-ColorOutput "- $($_.name)" "Yellow" }
    exit 1
}

Write-ColorOutput "Profil '$ProfileName' trouvé: $($profile.description)" "Green"

# Créer le fichier de configuration des modes
$modesConfig = @{
    customModes = @()
}

# Charger un fichier de modes de référence pour obtenir les définitions complètes
$referenceModesPath = Join-Path -Path $scriptDir -ChildPath "modes/standard-modes.json"
if (-not (Test-Path -Path $referenceModesPath)) {
    Write-ColorOutput "Avertissement: Fichier de modes de référence non trouvé. Utilisation du fichier standard-modes-updated.json." "Yellow"
    $referenceModesPath = Join-Path -Path $scriptDir -ChildPath "modes/standard-modes-updated.json"
    
    if (-not (Test-Path -Path $referenceModesPath)) {
        Write-ColorOutput "Erreur: Aucun fichier de modes de référence trouvé." "Red"
        exit 1
    }
}

try {
    $referenceModes = Get-Content -Path $referenceModesPath -Raw | ConvertFrom-Json
    Write-ColorOutput "Fichier de modes de référence chargé avec succès." "Green"
} catch {
    Write-ColorOutput "Erreur lors du chargement du fichier de modes de référence:" "Red"
    Write-ColorOutput $_.Exception.Message "Red"
    exit 1
}

# Générer la configuration des modes basée sur le profil
foreach ($mode in $referenceModes.customModes) {
    $modeSlug = $mode.slug
    $modelName = ""
    
    # Vérifier si le mode a une surcharge dans le profil
    if ($profile.PSObject.Properties.Name -contains "modes" -and $profile.modes.PSObject.Properties.Name -contains $modeSlug) {
        # Structure ancienne avec modes directement spécifiés
        $modelName = $profile.modes.$modeSlug
        Write-ColorOutput "Mode '$modeSlug': Utilisation du modèle spécifié dans le profil: $modelName" "Green"
    } elseif ($profile.PSObject.Properties.Name -contains "modeOverrides" -and $profile.modeOverrides.PSObject.Properties.Name -contains $modeSlug) {
        # Structure nouvelle avec modeOverrides
        $modelName = $profile.modeOverrides.$modeSlug
        Write-ColorOutput "Mode '$modeSlug': Utilisation de la surcharge du profil: $modelName" "Green"
    } else {
        # Utiliser le modèle par défaut du profil
        if ($profile.PSObject.Properties.Name -contains "defaultModel") {
            $modelName = $profile.defaultModel
            Write-ColorOutput "Mode '$modeSlug': Utilisation du modèle par défaut du profil: $modelName" "Green"
        } else {
            Write-ColorOutput "Avertissement: Aucun modèle par défaut trouvé pour le mode '$modeSlug'. Le modèle existant sera conservé." "Yellow"
            $modelName = $mode.model
        }
    }
    
    # Mettre à jour le modèle dans la configuration
    if ($modelName -ne "") {
        $mode.model = $modelName
    }
    
    # Ajouter le mode à la configuration
    $modesConfig.customModes += $mode
}

# Enregistrer la configuration générée
$outputFilePath = Join-Path -Path $scriptDir -ChildPath $OutputFile

try {
    $modesConfigJson = $modesConfig | ConvertTo-Json -Depth 10
    $modesConfigJson | Out-File -FilePath $outputFilePath -Encoding utf8
    Write-ColorOutput "Configuration des modes générée avec succès: $outputFilePath" "Green"
} catch {
    Write-ColorOutput "Erreur lors de l'enregistrement de la configuration des modes:" "Red"
    Write-ColorOutput $_.Exception.Message "Red"
    exit 1
}

# Déployer la configuration générée
Write-ColorOutput "`nDéploiement de la configuration générée..." "Yellow"

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
    Copy-Item -Path $outputFilePath -Destination $destinationFile -Force
    Write-ColorOutput "Déploiement réussi!" "Green"
} catch {
    Write-ColorOutput "Erreur lors du déploiement:" "Red"
    Write-ColorOutput $_.Exception.Message "Red"
    exit 1
}

# Vérifier que les fichiers sont identiques
try {
    $diff = Compare-Object -ReferenceObject (Get-Content $outputFilePath) -DifferenceObject (Get-Content $destinationFile)
    
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