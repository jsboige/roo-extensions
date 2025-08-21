# =================================================================================================
#
#   ██████╗ ███████╗██╗  ██╗██╗██╗     ██████╗  █████╗ ███████╗███████╗
#  ██╔═══██╗██╔════╝╚██╗██╔╝██║██║     ██╔══██╗██╔══██╗██╔════╝██╔════╝
#  ██║   ██║███████╗ ╚███╔╝ ██║██║     ██║  ██║███████║███████╗███████╗
#  ██║   ██║╚════██║ ██╔██╗ ██║██║     ██║  ██║██╔══██║╚════██║╚════██║
#  ╚██████╔╝███████║██╔╝ ██╗██║███████╗██████╔╝██║  ██║███████║███████║
#   ╚═════╝ ╚══════╝╚═╝  ╚═╝╚═╝╚══════╝╚═════╝ ╚═╝  ╚═╝╚══════╝╚══════╝
#
#   SCRIPT DE DÉPLOIEMENT UNIFIÉ DES MODES
#
#   Ce script consolide les fonctionnalités de tous les anciens scripts de déploiement.
#   Il permet de :
#   1. Déployer une configuration de modes standard (depuis un fichier).
#   2. Générer et déployer une configuration basée sur un profil de modèles.
#   3. Enrichir les modes "simple/complex" avec des métadonnées (famille, modèle).
#   4. Lancer des tests post-déploiement.
#
# =================================================================================================

param (
    # --- Mode de déploiement ---
    [Parameter(Mandatory = $false, HelpMessage = "Type de déploiement: 'global' pour toutes les instances de VSCode, 'local' pour ce projet uniquement.")]
    [ValidateSet("global", "local")]
    [string]$DeploymentType = "global",

    # --- Sélection de la configuration ---
    [Parameter(Mandatory = $false, HelpMessage = "Chemin du fichier de configuration des modes de base.")]
    [string]$ConfigFile = "roo-modes/configs/standard-modes.json",

    # --- Logique de Profils ---
    [Parameter(Mandatory = $false, HelpMessage = "Nom du profil à utiliser pour générer la configuration des modes.")]
    [string]$ProfileName,

    [Parameter(Mandatory = $false, HelpMessage = "Chemin du fichier de configuration des profils (utilisé avec -ProfileName).")]
    [string]$ProfileConfigFile = "roo-config/model-configs.json",

    # --- Options de traitement ---
    [Parameter(Mandatory = $false, HelpMessage = "Enrichit les modes 'simple' et 'complex' avec les métadonnées de famille et les modèles par défaut.")]
    [switch]$EnrichSimpleComplexModes,
    
    # --- Options d'exécution ---
    [Parameter(Mandatory = $false, HelpMessage = "Force le remplacement du fichier de destination sans demander de confirmation.")]
    [switch]$Force,

    [Parameter(Mandatory = $false, HelpMessage = "Exécute les tests de validation après le déploiement.")]
    [switch]$TestAfterDeploy
)

# =================================================================================================
#   FONCTIONS UTILITAIRES
# =================================================================================================

# Fonction pour afficher des messages colorés
function Write-ColorOutput {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Message,
        
        [Parameter(Mandatory = $false)]
        [ConsoleColor]$ForegroundColor = "White"
    )
    Write-Host $Message -ForegroundColor $ForegroundColor
}

# =================================================================================================
#   INITIALISATION ET VALIDATION
# =================================================================================================

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = (Get-Item $scriptDir).parent.parent.FullName

# Bannière
Write-ColorOutput "=========================================================" "Cyan"
Write-ColorOutput "   Déploiement unifié des modes personnalisés Roo" "Cyan"
Write-ColorOutput "=========================================================" "Cyan"

# Valider le chemin du fichier de configuration de base
$configFilePath = Join-Path -Path $projectRoot -ChildPath $ConfigFile
if (-not (Test-Path -Path $configFilePath)) {
    Write-ColorOutput "ERREUR: Le fichier de configuration de base '$configFilePath' n'a pas été trouvé." "Red"
    exit 1
}

# =================================================================================================
#   LOGIQUE DE GÉNÉRATION ET DE TRAITEMENT
# =================================================================================================

$modesConfigObject = $null

# --- Cas 1: Déploiement basé sur un profil ---
if ($PSBoundParameters.ContainsKey('ProfileName') -and -not [string]::IsNullOrEmpty($ProfileName)) {
    Write-ColorOutput "`nMode de déploiement: Génération par profil '$ProfileName'." "Magenta"

    $profileConfigPath = Join-Path -Path $projectRoot -ChildPath $ProfileConfigFile
    if (-not (Test-Path -Path $profileConfigPath)) {
        Write-ColorOutput "ERREUR: Le fichier de configuration des profils '$profileConfigPath' est introuvable." "Red"
        exit 1
    }

    $profilesData = Get-Content -Path $profileConfigPath -Raw | ConvertFrom-Json
    $profile = $profilesData.profiles | Where-Object { $_.name -eq $ProfileName }

    if (-not $profile) {
        Write-ColorOutput "ERREUR: Le profil '$ProfileName' n'a pas été trouvé dans '$profileConfigPath'." "Red"
        exit 1
    }
    Write-ColorOutput "Profil '$ProfileName' chargé. Description: $($profile.description)" "Green"

    # Charger les modes de référence
    $modesConfigObject = Get-Content -Path $configFilePath -Raw | ConvertFrom-Json
    
    # Appliquer les surcharges du profil
    foreach ($mode in $modesConfigObject.customModes) {
        $modelOverride = $profile.modeOverrides.$($mode.slug)
        if ($modelOverride) {
            Write-ColorOutput "  - Surcharge pour '$($mode.slug)': Utilisation du modèle '$modelOverride'." "Gray"
            $mode.model = $modelOverride
        }
        elseif ($profile.defaultModel) {
             Write-ColorOutput "  - Pas de surcharge pour '$($mode.slug)': Utilisation du modèle par défaut '$($profile.defaultModel)'." "Gray"
            $mode.model = $profile.defaultModel
        }
    }
}
# --- Cas 2: Déploiement standard depuis un fichier ---
else {
    Write-ColorOutput "`nMode de déploiement: Standard depuis le fichier '$ConfigFile'." "Magenta"
    $modesConfigObject = Get-Content -Path $configFilePath -Raw | ConvertFrom-Json
}

# --- Traitement optionnel: Enrichissement des modes Simple/Complex ---
if ($EnrichSimpleComplexModes) {
    Write-ColorOutput "`nOption activée: Enrichissement des modes 'simple' et 'complex'." "Magenta"
    foreach ($mode in $modesConfigObject.customModes) {
        if ($mode.slug -match "-simple$") {
            $mode | Add-Member -MemberType NoteProperty -Name "family" -Value "simple" -Force
            $mode | Add-Member -MemberType NoteProperty -Name "allowedFamilyTransitions" -Value @("simple") -Force
            $mode | Add-Member -MemberType NoteProperty -Name "model" -Value "anthropic/claude-3.5-sonnet" -Force
            Write-ColorOutput "  - Mode simple enrichi: '$($mode.slug)'" "Gray"
        } elseif ($mode.slug -match "-complex$" -or $mode.slug -eq "manager") {
            $mode | Add-Member -MemberType NoteProperty -Name "family" -Value "complex" -Force
            $mode | Add-Member -MemberType NoteProperty -Name "allowedFamilyTransitions" -Value @("complex") -Force
            $mode | Add-Member -MemberType NoteProperty -Name "model" -Value "anthropic/claude-3.7-sonnet" -Force
             Write-ColorOutput "  - Mode complex enrichi: '$($mode.slug)'" "Gray"
        }
    }
}

# =================================================================================================
#   PHASE DE DÉPLOIEMENT
# =================================================================================================

Write-ColorOutput "`nPhase de déploiement..." "Cyan"

# Déterminer le chemin de destination
$destinationFile = ""
if ($DeploymentType -eq "global") {
    $destinationDir = Join-Path -Path $env:APPDATA -ChildPath "Code\User\globalStorage\rooveterinaryinc.roo-cline\settings"
    $destinationFile = Join-Path -Path $destinationDir -ChildPath "custom_modes.json"
    if (-not (Test-Path -Path $destinationDir)) {
        New-Item -Path $destinationDir -ItemType Directory -Force | Out-Null
        Write-ColorOutput "Répertoire de destination global créé: $destinationDir" "Green"
    }
} else {
    $destinationFile = Join-Path -Path $projectRoot -ChildPath ".roomodes"
}

Write-ColorOutput "Type de déploiement : $DeploymentType" "Yellow"
Write-ColorOutput "Fichier de destination: $destinationFile" "Yellow"

# Confirmation de l'écrasement
if ((Test-Path -Path $destinationFile) -and (-not $Force)) {
    $confirmation = Read-Host "Le fichier de destination existe déjà. Voulez-vous le remplacer? (O/N)"
    if ($confirmation.ToLower() -ne "o") {
        Write-ColorOutput "Opération annulée par l'utilisateur." "Yellow"
        exit 0
    }
}

# Conversion en JSON et écriture du fichier
try {
    $finalJson = $modesConfigObject | ConvertTo-Json -Depth 10 -Compress:$false
    $utf8NoBomEncoding = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($destinationFile, $finalJson, $utf8NoBomEncoding)
    Write-ColorOutput "Déploiement réussi!" "Green"
} catch {
    Write-ColorOutput "ERREUR lors de l'écriture du fichier de destination." "Red"
    Write-ColorOutput $_.Exception.Message "Red"
    exit 1
}

# =================================================================================================
#   VÉRIFICATION ET TESTS
# =================================================================================================

# Vérification du contenu
try {
    $sourceJsonForCompare = $modesConfigObject | ConvertTo-Json -Depth 10
    $destContentForCompare = Get-Content $destinationFile -Raw
    
    $diff = Compare-Object -ReferenceObject ($sourceJsonForCompare | ConvertFrom-Json) -DifferenceObject ($destContentForCompare | ConvertFrom-Json)
    if (-not $diff) {
        Write-ColorOutput "Vérification réussie: Le contenu déployé est conforme à la source générée." "Green"
    } else {
        Write-ColorOutput "AVERTISSEMENT: Des différences ont été détectées après le déploiement." "Yellow"
    }
} catch {
    Write-ColorOutput "ERREUR lors de la vérification du fichier déployé." "Red"
    Write-ColorOutput $_.Exception.Message "Red"
}


# Exécution des tests post-déploiement
if ($TestAfterDeploy) {
    Write-ColorOutput "`nExécution des tests post-déploiement..." "Magenta"
    # Ici, la logique pour appeler les scripts de test (ex: node, Pester, etc.)
    Write-ColorOutput "Logique de test à implémenter..." "Gray"
}

# =================================================================================================
#   RÉSUMÉ
# =================================================================================================

Write-ColorOutput "`n=========================================================" "Cyan"
Write-ColorOutput "   Déploiement terminé !" "Green"
Write-ColorOutput "=========================================================" "Cyan"
Write-ColorOutput "Redémarrez VS Code pour que les changements soient pris en compte." "White"