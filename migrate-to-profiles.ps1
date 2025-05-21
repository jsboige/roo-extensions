# Script de migration des configurations de modes vers le système de profils
# Ce script analyse les configurations existantes, extrait les modèles utilisés par chaque mode,
# crée un nouveau profil avec ces informations et sauvegarde l'ancienne configuration.

param (
    [Parameter(Mandatory=$true)]
    [string]$ConfigFile,
    
    [Parameter(Mandatory=$true)]
    [string]$OutputProfileName,
    
    [Parameter(Mandatory=$false)]
    [string]$OutputProfileDescription = "Profil migré depuis la configuration $ConfigFile",
    
    [Parameter(Mandatory=$false)]
    [string]$ProfileConfigFile = "roo-config/model-configs.json",
    
    [Parameter(Mandatory=$false)]
    [switch]$Force
)

# Fonction pour afficher des messages colorés
function Write-ColorOutput($ForegroundColor) {
    $fc = $host.UI.RawUI.ForegroundColor
    $host.UI.RawUI.ForegroundColor = $ForegroundColor
    if ($args) {
        Write-Output $args
    }
    else {
        $input | Write-Output
    }
    $host.UI.RawUI.ForegroundColor = $fc
}

# Vérifier que le fichier de configuration existe
if (-not (Test-Path $ConfigFile)) {
    Write-ColorOutput Red "Erreur: Le fichier de configuration $ConfigFile n'existe pas."
    exit 1
}

# Vérifier que le fichier de configuration des profils existe
if (-not (Test-Path $ProfileConfigFile)) {
    Write-ColorOutput Red "Erreur: Le fichier de configuration des profils $ProfileConfigFile n'existe pas."
    exit 1
}

# Charger la configuration des modes
try {
    $modesConfig = Get-Content -Path $ConfigFile -Raw | ConvertFrom-Json
    Write-ColorOutput Green "Configuration des modes chargée avec succès."
} catch {
    Write-ColorOutput Red "Erreur lors du chargement de la configuration des modes: $_"
    exit 1
}

# Charger la configuration des profils
try {
    $profilesConfig = Get-Content -Path $ProfileConfigFile -Raw | ConvertFrom-Json
    Write-ColorOutput Green "Configuration des profils chargée avec succès."
} catch {
    Write-ColorOutput Red "Erreur lors du chargement de la configuration des profils: $_"
    exit 1
}

# Vérifier si le profil existe déjà
$profileExists = $false
foreach ($profile in $profilesConfig.profiles) {
    if ($profile.name -eq $OutputProfileName) {
        $profileExists = $true
        break
    }
}

if ($profileExists -and -not $Force) {
    Write-ColorOutput Yellow "Attention: Un profil nommé '$OutputProfileName' existe déjà."
    $confirmation = Read-Host "Voulez-vous le remplacer? (O/N)"
    if ($confirmation -ne "O" -and $confirmation -ne "o") {
        Write-ColorOutput Yellow "Opération annulée."
        exit 0
    }
}

# Extraire les modèles utilisés par chaque mode
$models = @{}
$defaultModel = $null
$firstModel = $null

Write-ColorOutput Cyan "Analyse des modèles utilisés dans la configuration..."

foreach ($mode in $modesConfig.customModes) {
    # Ignorer le validateur de famille et autres modes spéciaux
    if ($mode.slug -eq "mode-family-validator" -or -not $mode.model) {
        continue
    }
    
    # Stocker le modèle pour ce mode
    $models[$mode.slug] = $mode.model
    
    # Garder une trace du premier modèle rencontré pour l'utiliser comme modèle par défaut
    if ($null -eq $firstModel) {
        $firstModel = $mode.model
    }
    
    Write-ColorOutput White "Mode '$($mode.slug)' utilise le modèle '$($mode.model)'"
}

# Déterminer le modèle par défaut (le plus fréquent)
$modelCounts = @{}
foreach ($model in $models.Values) {
    if ($modelCounts.ContainsKey($model)) {
        $modelCounts[$model]++
    } else {
        $modelCounts[$model] = 1
    }
}

$maxCount = 0
foreach ($model in $modelCounts.Keys) {
    if ($modelCounts[$model] -gt $maxCount) {
        $maxCount = $modelCounts[$model]
        $defaultModel = $model
    }
}

# Si aucun modèle par défaut n'a été trouvé, utiliser le premier modèle rencontré
if ($null -eq $defaultModel) {
    $defaultModel = $firstModel
}

Write-ColorOutput Cyan "Modèle par défaut détecté: $defaultModel"

# Créer les surcharges de modèle (uniquement pour les modes qui utilisent un modèle différent du modèle par défaut)
$modeOverrides = @{}
foreach ($mode in $models.Keys) {
    if ($models[$mode] -ne $defaultModel) {
        $modeOverrides[$mode] = $models[$mode]
        Write-ColorOutput White "Surcharge pour le mode '$mode': '$($models[$mode])'"
    }
}

# Créer le nouveau profil
$newProfile = @{
    name = $OutputProfileName
    description = $OutputProfileDescription
    defaultModel = $defaultModel
    modeOverrides = $modeOverrides
}

# Sauvegarder l'ancienne configuration
$backupFile = "$ConfigFile.backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
Copy-Item -Path $ConfigFile -Destination $backupFile
Write-ColorOutput Green "Configuration originale sauvegardée dans $backupFile"

# Mettre à jour la configuration des profils
if ($profileExists) {
    # Remplacer le profil existant
    for ($i = 0; $i -lt $profilesConfig.profiles.Count; $i++) {
        if ($profilesConfig.profiles[$i].name -eq $OutputProfileName) {
            $profilesConfig.profiles[$i] = $newProfile
            break
        }
    }
} else {
    # Ajouter le nouveau profil
    $profilesConfig.profiles += $newProfile
}

# Enregistrer la configuration des profils mise à jour
try {
    $profilesConfig | ConvertTo-Json -Depth 10 | Out-File -FilePath $ProfileConfigFile -Encoding utf8
    Write-ColorOutput Green "Profil '$OutputProfileName' créé avec succès dans $ProfileConfigFile"
} catch {
    Write-ColorOutput Red "Erreur lors de l'enregistrement de la configuration des profils: $_"
    exit 1
}

# Créer une version modifiée de la configuration des modes sans les propriétés 'model'
$updatedModesConfig = $modesConfig | ConvertTo-Json -Depth 10 | ConvertFrom-Json
foreach ($mode in $updatedModesConfig.customModes) {
    if ($mode.PSObject.Properties.Name -contains "model") {
        $mode.PSObject.Properties.Remove("model")
    }
}

# Enregistrer la configuration des modes mise à jour
$updatedConfigFile = "$ConfigFile.updated-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
try {
    $updatedModesConfig | ConvertTo-Json -Depth 10 | Out-File -FilePath $updatedConfigFile -Encoding utf8
    Write-ColorOutput Green "Configuration des modes mise à jour (sans propriétés 'model') enregistrée dans $updatedConfigFile"
} catch {
    Write-ColorOutput Red "Erreur lors de l'enregistrement de la configuration des modes mise à jour: $_"
    exit 1
}

Write-ColorOutput Green "Migration terminée avec succès!"
Write-ColorOutput Cyan "Pour déployer cette configuration avec le nouveau profil, utilisez:"
Write-ColorOutput White ".\roo-config\deploy-profile-modes.ps1 -ProfileName `"$OutputProfileName`" -DeploymentType global"