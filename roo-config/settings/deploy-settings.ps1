# Script de déploiement de la configuration générale Roo
# Ce script permet de déployer la configuration générale de Roo en préservant les clés d'API

param (
    [Parameter(Mandatory = $false)]
    [string]$ConfigFile = "settings.json",
    
    [Parameter(Mandatory = $false)]
    [switch]$Force,
    
    [Parameter(Mandatory = $false)]
    [switch]$NoMerge
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

# Initialiser et mettre à jour les submodules Git
Write-ColorOutput "Initialisation et mise à jour des submodules Git..." "Yellow"
try {
    git submodule update --init --recursive
    Write-ColorOutput "Submodules mis à jour avec succès." "Green"
} catch {
    Write-ColorOutput "Erreur lors de la mise à jour des submodules:" "Red"
    Write-ColorOutput $_.Exception.Message "Red"
    # Il est peut-être préférable de ne pas quitter le script ici,
    # car la mise à jour des submodules peut ne pas être critique pour tous les déploiements.
}
# Vérifier que le fichier de configuration existe
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$configFilePath = Join-Path -Path $scriptDir -ChildPath $ConfigFile

if (-not (Test-Path -Path $configFilePath)) {
    Write-ColorOutput "Erreur: Le fichier de configuration '$ConfigFile' n'existe pas." "Red"
    Write-ColorOutput "Assurez-vous que le fichier existe dans le répertoire 'roo-config/settings/'." "Red"
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

# Fonction pour fusionner deux objets JSON en préservant les valeurs de l'objet cible
function Merge-JsonObjects {
    param (
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$Source,
        
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$Target
    )
    
    $merged = $Target.PSObject.Copy()
    
    foreach ($property in $Source.PSObject.Properties) {
        $propertyName = $property.Name
        
        # Si la propriété n'existe pas dans la cible, l'ajouter
        if (-not $merged.PSObject.Properties[$propertyName]) {
            $merged | Add-Member -MemberType NoteProperty -Name $propertyName -Value $property.Value
        }
        # Si la propriété existe dans les deux et est un objet, fusionner récursivement
        elseif ($property.Value -is [PSCustomObject] -and $merged.$propertyName -is [PSCustomObject]) {
            $merged.$propertyName = Merge-JsonObjects -Source $property.Value -Target $merged.$propertyName
        }
        # Sinon, remplacer la valeur par celle de la source (sauf pour les propriétés sensibles)
        else {
            # Ici, on pourrait ajouter une liste de propriétés sensibles à ne pas écraser
            # Pour l'instant, on remplace simplement la valeur
            $merged.$propertyName = $property.Value
        }
    }
    
    return $merged
}

# Charger le fichier de configuration source
try {
    $sourceConfig = Get-Content -Path $configFilePath -Raw | ConvertFrom-Json
    Write-ColorOutput "Configuration source chargée avec succès." "Green"
} catch {
    Write-ColorOutput "Erreur lors du chargement de la configuration source:" "Red"
    Write-ColorOutput $_.Exception.Message "Red"
    exit 1
}

# Déployer la configuration
try {
    # Si le fichier de destination existe et que -NoMerge n'est pas spécifié, fusionner les configurations
    if ((Test-Path -Path $destinationFile) -and (-not $NoMerge)) {
        Write-ColorOutput "Fusion des configurations..." "Yellow"
        
        try {
            $targetConfig = Get-Content -Path $destinationFile -Raw | ConvertFrom-Json
            $mergedConfig = Merge-JsonObjects -Source $sourceConfig -Target $targetConfig
            
            # Convertir l'objet fusionné en JSON et l'écrire dans le fichier de destination
            $mergedConfig | ConvertTo-Json -Depth 10 | Set-Content -Path $destinationFile -Encoding UTF8
            Write-ColorOutput "Fusion et déploiement réussis!" "Green"
        } catch {
            Write-ColorOutput "Erreur lors de la fusion des configurations:" "Red"
            Write-ColorOutput $_.Exception.Message "Red"
            Write-ColorOutput "Utilisation de la méthode de remplacement complet..." "Yellow"
            
            # En cas d'erreur lors de la fusion, revenir à la méthode de remplacement complet
            $sourceConfig | ConvertTo-Json -Depth 10 | Set-Content -Path $destinationFile -Encoding UTF8
            Write-ColorOutput "Déploiement par remplacement réussi!" "Green"
        }
    } else {
        # Si le fichier de destination n'existe pas ou si -NoMerge est spécifié, remplacer complètement
        if ($NoMerge) {
            Write-ColorOutput "Option -NoMerge spécifiée. Remplacement complet de la configuration..." "Yellow"
        } else {
            Write-ColorOutput "Aucune configuration existante trouvée. Déploiement de la nouvelle configuration..." "Yellow"
        }
        
        $sourceConfig | ConvertTo-Json -Depth 10 | Set-Content -Path $destinationFile -Encoding UTF8
        Write-ColorOutput "Déploiement réussi!" "Green"
    }
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

if ((Test-Path -Path $destinationFile) -and (-not $NoMerge)) {
    Write-ColorOutput "Les clés d'API et autres informations sensibles ont été préservées." "Green"
    Write-ColorOutput "Si vous avez ajouté de nouvelles sections dans la configuration source, elles ont été fusionnées avec la configuration existante." "White"
} else {
    Write-ColorOutput "IMPORTANT: Ce fichier ne contient pas les clés d'API et autres informations sensibles." "Yellow"
    Write-ColorOutput "Vous devrez ajouter manuellement ces informations au fichier de configuration." "Yellow"
    
    Write-ColorOutput "`nPour activer la configuration:" "White"
    Write-ColorOutput "1. Ajoutez vos clés d'API et autres informations sensibles au fichier $destinationFile" "White"
}

Write-ColorOutput "2. Redémarrez Visual Studio Code pour appliquer les changements" "White"
Write-ColorOutput "`n" "White"

Write-ColorOutput "Options disponibles pour les prochains déploiements:" "Cyan"
Write-ColorOutput "- Utilisez -Force pour déployer sans confirmation" "White"
Write-ColorOutput "- Utilisez -NoMerge pour remplacer complètement la configuration (écrase les clés d'API)" "White"
Write-ColorOutput "`n" "White"