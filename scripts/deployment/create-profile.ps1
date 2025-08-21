# Script de création de profils pour les modes personnalisés Roo
# Ce script permet de créer un nouveau profil avec un nom, une description et un modèle par défaut,
# ainsi que des surcharges pour certains modes spécifiques

param (
    [Parameter(Mandatory = $true)]
    [string]$ProfileName,
    
    [Parameter(Mandatory = $true)]
    [string]$Description,
    
    [Parameter(Mandatory = $true)]
    [string]$DefaultModel,
    
    [Parameter(Mandatory = $false)]
    [string]$ConfigFile = "model-configs.json",
    
    [Parameter(Mandatory = $false)]
    [switch]$Force,
    
    [Parameter(Mandatory = $false)]
    [string]$ModeOverridesJson = ""
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
Write-ColorOutput "   Création d'un profil pour les modes personnalisés Roo" "Cyan"
Write-ColorOutput "=========================================================" "Cyan"

# Vérifier que le fichier de configuration existe
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$configFilePath = Join-Path -Path $scriptDir -ChildPath $ConfigFile

if (-not (Test-Path -Path $configFilePath)) {
    Write-ColorOutput "Le fichier de configuration '$ConfigFile' n'existe pas. Un nouveau fichier sera créé." "Yellow"
    
    # Créer un nouveau fichier de configuration avec la structure attendue
    $newConfig = @{
        profiles = @()
        activeProfile = ""
    }
    
    try {
        $newConfigJson = $newConfig | ConvertTo-Json -Depth 10
        $newConfigJson | Out-File -FilePath $configFilePath -Encoding utf8
        Write-ColorOutput "Nouveau fichier de configuration créé: $configFilePath" "Green"
    } catch {
        Write-ColorOutput "Erreur lors de la création du fichier de configuration:" "Red"
        Write-ColorOutput $_.Exception.Message "Red"
        exit 1
    }
}

# Charger le fichier de configuration
try {
    $config = Get-Content -Path $configFilePath -Raw | ConvertFrom-Json
    Write-ColorOutput "Fichier de configuration chargé avec succès." "Green"
} catch {
    Write-ColorOutput "Erreur lors du chargement du fichier de configuration:" "Red"
    Write-ColorOutput $_.Exception.Message "Red"
    exit 1
}

# Vérifier et adapter la structure du fichier de configuration
if (-not ($config.PSObject.Properties.Name -contains "profiles")) {
    if ($config.PSObject.Properties.Name -contains "configurations") {
        Write-ColorOutput "Structure ancienne détectée (configurations). Conversion en 'profiles'..." "Yellow"
        
        # Créer une nouvelle propriété profiles avec le contenu de configurations
        $profiles = $config.configurations
        
        # Créer un nouvel objet avec la structure attendue
        $newConfig = @{
            profiles = $profiles
            activeProfile = if ($profiles.Count -gt 0) { $profiles[0].name } else { "" }
        }
        
        # Remplacer l'objet config
        $config = $newConfig
    } else {
        Write-ColorOutput "Structure non reconnue. Création d'une nouvelle structure..." "Yellow"
        
        # Créer un nouvel objet avec la structure attendue
        $config = @{
            profiles = @()
            activeProfile = ""
        }
    }
}

# Vérifier si le profil existe déjà
$existingProfile = $config.profiles | Where-Object { $_.name -eq $ProfileName }

if ($null -ne $existingProfile) {
    if (-not $Force) {
        $confirmation = Read-Host "Le profil '$ProfileName' existe déjà. Voulez-vous le remplacer? (O/N)"
        if ($confirmation -ne "O" -and $confirmation -ne "o") {
            Write-ColorOutput "Opération annulée." "Yellow"
            exit 0
        }
        
        # Supprimer le profil existant
        $config.profiles = $config.profiles | Where-Object { $_.name -ne $ProfileName }
    } else {
        # Supprimer le profil existant
        $config.profiles = $config.profiles | Where-Object { $_.name -ne $ProfileName }
        Write-ColorOutput "Le profil existant '$ProfileName' sera remplacé." "Yellow"
    }
}

# Traiter les surcharges de modes
$modeOverrides = @{}

if (-not [string]::IsNullOrEmpty($ModeOverridesJson)) {
    try {
        $modeOverridesObj = $ModeOverridesJson | ConvertFrom-Json
        
        # Convertir l'objet en hashtable
        foreach ($property in $modeOverridesObj.PSObject.Properties) {
            $modeOverrides[$property.Name] = $property.Value
        }
        
        Write-ColorOutput "Surcharges de modes traitées avec succès." "Green"
    } catch {
        Write-ColorOutput "Erreur lors du traitement des surcharges de modes:" "Red"
        Write-ColorOutput $_.Exception.Message "Red"
        Write-ColorOutput "Les surcharges doivent être au format JSON valide, par exemple: '{\"code\":\"anthropic/claude-3.7-sonnet\",\"debug\":\"anthropic/claude-3.5-sonnet\"}'" "Yellow"
        exit 1
    }
} else {
    # Demander interactivement les surcharges de modes
    Write-ColorOutput "`nVous pouvez spécifier des surcharges pour certains modes (laissez vide pour passer):" "White"
    
    $commonModes = @("code", "code-complex", "debug", "debug-complex", "architect", "architect-complex", "ask", "ask-complex", "orchestrator", "orchestrator-complex")
    
    foreach ($mode in $commonModes) {
        $modelOverride = Read-Host "Modèle pour le mode '$mode' (vide = utiliser le modèle par défaut)"
        if (-not [string]::IsNullOrEmpty($modelOverride)) {
            $modeOverrides[$mode] = $modelOverride
        }
    }
    
    $customMode = Read-Host "Voulez-vous ajouter d'autres modes personnalisés? (O/N)"
    while ($customMode -eq "O" -or $customMode -eq "o") {
        $modeName = Read-Host "Nom du mode"
        $modelName = Read-Host "Modèle pour le mode '$modeName'"
        
        if (-not [string]::IsNullOrEmpty($modeName) -and -not [string]::IsNullOrEmpty($modelName)) {
            $modeOverrides[$modeName] = $modelName
        }
        
        $customMode = Read-Host "Voulez-vous ajouter un autre mode personnalisé? (O/N)"
    }
}

# Créer le nouveau profil
$newProfile = @{
    name = $ProfileName
    description = $Description
    defaultModel = $DefaultModel
    modeOverrides = $modeOverrides
}

# Ajouter le profil à la configuration
$config.profiles += $newProfile

# Si c'est le premier profil, le définir comme profil actif
if ($config.profiles.Count -eq 1 -or [string]::IsNullOrEmpty($config.activeProfile)) {
    $config.activeProfile = $ProfileName
    Write-ColorOutput "Le profil '$ProfileName' a été défini comme profil actif." "Green"
}

# Enregistrer la configuration
try {
    $configJson = $config | ConvertTo-Json -Depth 10
    $configJson | Out-File -FilePath $configFilePath -Encoding utf8
    Write-ColorOutput "Profil '$ProfileName' créé avec succès et enregistré dans $configFilePath" "Green"
} catch {
    Write-ColorOutput "Erreur lors de l'enregistrement du fichier de configuration:" "Red"
    Write-ColorOutput $_.Exception.Message "Red"
    exit 1
}

# Résumé
Write-ColorOutput "`n=========================================================" "Cyan"
Write-ColorOutput "   Création du profil terminée avec succès!" "Green"
Write-ColorOutput "=========================================================" "Cyan"

Write-ColorOutput "`nDétails du profil créé:" "White"
Write-ColorOutput "- Nom: $ProfileName" "White"
Write-ColorOutput "- Description: $Description" "White"
Write-ColorOutput "- Modèle par défaut: $DefaultModel" "White"

if ($modeOverrides.Count -gt 0) {
    Write-ColorOutput "- Surcharges de modes:" "White"
    foreach ($mode in $modeOverrides.Keys) {
        Write-ColorOutput "  - $mode: $($modeOverrides[$mode])" "White"
    }
}

Write-ColorOutput "`nPour déployer ce profil, utilisez la commande:" "White"
Write-ColorOutput ".\deploy-profile-modes.ps1 -ProfileName `"$ProfileName`" -DeploymentType global" "Yellow"
Write-ColorOutput "`n" "White"