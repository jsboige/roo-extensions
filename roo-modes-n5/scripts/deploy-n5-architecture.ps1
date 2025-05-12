# Script de déploiement de l'architecture à 5 niveaux avec système de verrouillage de famille
# Ce script déploie les configurations des modes pour l'architecture à 5 niveaux
# et configure le système de verrouillage de famille

# Paramètres
param (
    [switch]$Force = $false,
    [switch]$SkipBackup = $false,
    [switch]$SkipValidation = $false
)

# Constantes
$RooConfigDir = "$env:APPDATA\Roo\config"
$BackupDir = "$PSScriptRoot\..\backup"
$ConfigsDir = "$PSScriptRoot\..\configs"
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
    
    # Sauvegarder le fichier modes.json s'il existe
    if (Test-Path "$RooConfigDir\modes.json") {
        Copy-Item "$RooConfigDir\modes.json" "$BackupDir\modes_backup_$Timestamp.json"
        Write-ColorOutput "Sauvegarde créée: $BackupDir\modes_backup_$Timestamp.json" -ForegroundColor "Green"
    } else {
        Write-ColorOutput "Aucun fichier modes.json trouvé à sauvegarder" -ForegroundColor "Yellow"
    }
}

# Fonction pour valider les fichiers de configuration
function Test-Configurations {
    if ($SkipValidation) {
        Write-ColorOutput "Validation ignorée (--skip-validation)" -ForegroundColor "Yellow"
        return $true
    }

    Write-ColorOutput "Validation des fichiers de configuration..." -ForegroundColor "Cyan"
    
    # Vérifier que tous les fichiers de configuration existent
    $requiredConfigs = @(
        "$ConfigsDir\micro-modes.json",
        "$ConfigsDir\mini-modes.json",
        "$ConfigsDir\medium-modes.json",
        "$ConfigsDir\large-modes.json",
        "$ConfigsDir\oracle-modes.json"
    )
    
    $allValid = $true
    foreach ($config in $requiredConfigs) {
        if (-not (Test-Path $config)) {
            Write-ColorOutput "Erreur: Fichier de configuration manquant: $config" -ForegroundColor "Red"
            $allValid = $false
        } else {
            # Vérifier que le fichier est un JSON valide
            try {
                $null = Get-Content $config -Raw | ConvertFrom-Json
                Write-ColorOutput "Validation réussie: $config" -ForegroundColor "Green"
            } catch {
                Write-ColorOutput "Erreur: Fichier JSON invalide: $config" -ForegroundColor "Red"
                Write-ColorOutput $_.Exception.Message -ForegroundColor "Red"
                $allValid = $false
            }
        }
    }
    
    # Exécuter le script de validation si disponible
    if (Test-Path "$PSScriptRoot\validate-n5-configs.js") {
        Write-ColorOutput "Exécution de la validation avancée..." -ForegroundColor "Cyan"
        try {
            node "$PSScriptRoot\validate-n5-configs.js"
            if ($LASTEXITCODE -ne 0) {
                Write-ColorOutput "Erreur: La validation avancée a échoué" -ForegroundColor "Red"
                $allValid = $false
            } else {
                Write-ColorOutput "Validation avancée réussie" -ForegroundColor "Green"
            }
        } catch {
            Write-ColorOutput "Erreur lors de l'exécution du script de validation: $_" -ForegroundColor "Red"
            $allValid = $false
        }
    }
    
    return $allValid
}

# Fonction pour fusionner les configurations
function Merge-Configurations {
    Write-ColorOutput "Fusion des configurations..." -ForegroundColor "Cyan"
    
    # Créer un objet pour stocker les modes fusionnés
    $mergedConfig = @{
        customModes = @()
    }
    
    # Lire et fusionner chaque fichier de configuration
    $configFiles = @(
        "$ConfigsDir\micro-modes.json",
        "$ConfigsDir\mini-modes.json",
        "$ConfigsDir\medium-modes.json",
        "$ConfigsDir\large-modes.json",
        "$ConfigsDir\oracle-modes.json"
    )
    
    foreach ($configFile in $configFiles) {
        $config = Get-Content $configFile -Raw | ConvertFrom-Json
        
        # Ajouter les modes personnalisés
        foreach ($mode in $config.customModes) {
            $mergedConfig.customModes += $mode
        }
    }
    
    # Ajouter le validateur de famille
    $familyValidator = @{
        slug = "mode-family-validator"
        name = "Mode Family Validator"
        description = "Système de validation des transitions entre familles de modes"
        version = "1.0.0"
        enabled = $true
        familyDefinitions = @{
            n5 = @()
        }
    }
    
    # Remplir les définitions de famille
    foreach ($mode in $mergedConfig.customModes) {
        if ($mode.family -eq "n5") {
            $familyValidator.familyDefinitions.n5 += $mode.slug
        }
    }
    
    # Ajouter le validateur au début de la liste des modes
    $mergedConfig.customModes = @($familyValidator) + $mergedConfig.customModes
    
    return $mergedConfig
}

# Fonction pour déployer les configurations
function Deploy-Configurations {
    param (
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$MergedConfig
    )
    
    Write-ColorOutput "Déploiement des configurations..." -ForegroundColor "Cyan"
    
    # Vérifier si le répertoire de configuration existe
    if (-not (Test-Path $RooConfigDir)) {
        New-Item -ItemType Directory -Path $RooConfigDir -Force | Out-Null
        Write-ColorOutput "Répertoire de configuration créé: $RooConfigDir" -ForegroundColor "Green"
    }
    
    # Vérifier si le fichier modes.json existe déjà
    if ((Test-Path "$RooConfigDir\modes.json") -and (-not $Force)) {
        Write-ColorOutput "Le fichier modes.json existe déjà. Utilisez -Force pour écraser." -ForegroundColor "Yellow"
        return $false
    }
    
    # Écrire le fichier de configuration fusionné
    $MergedConfig | ConvertTo-Json -Depth 10 | Out-File "$RooConfigDir\modes.json" -Encoding UTF8
    Write-ColorOutput "Configuration déployée avec succès: $RooConfigDir\modes.json" -ForegroundColor "Green"
    
    return $true
}

# Fonction pour tester les transitions
function Test-Transitions {
    if (Test-Path "$PSScriptRoot\test-n5-transitions.js") {
        Write-ColorOutput "Test des transitions entre modes..." -ForegroundColor "Cyan"
        try {
            node "$PSScriptRoot\test-n5-transitions.js"
            if ($LASTEXITCODE -ne 0) {
                Write-ColorOutput "Avertissement: Certains tests de transition ont échoué" -ForegroundColor "Yellow"
            } else {
                Write-ColorOutput "Tests de transition réussis" -ForegroundColor "Green"
            }
        } catch {
            Write-ColorOutput "Erreur lors de l'exécution des tests de transition: $_" -ForegroundColor "Yellow"
        }
    } else {
        Write-ColorOutput "Script de test des transitions non trouvé, test ignoré" -ForegroundColor "Yellow"
    }
}

# Fonction principale
function Main {
    Write-ColorOutput "=== Déploiement de l'architecture à 5 niveaux avec système de verrouillage de famille ===" -ForegroundColor "Magenta"
    
    # Créer une sauvegarde
    Backup-Configurations
    
    # Valider les configurations
    $configsValid = Test-Configurations
    if (-not $configsValid -and -not $Force) {
        Write-ColorOutput "Erreur: Les configurations sont invalides. Utilisez -Force pour déployer quand même." -ForegroundColor "Red"
        exit 1
    }
    
    # Fusionner les configurations
    $mergedConfig = Merge-Configurations
    
    # Déployer les configurations
    $deployed = Deploy-Configurations -MergedConfig $mergedConfig
    if (-not $deployed) {
        Write-ColorOutput "Déploiement annulé." -ForegroundColor "Yellow"
        exit 1
    }
    
    # Tester les transitions
    Test-Transitions
    
    Write-ColorOutput "=== Déploiement terminé avec succès ===" -ForegroundColor "Magenta"
    Write-ColorOutput "Configuration déployée: $RooConfigDir\modes.json" -ForegroundColor "Green"
    if (-not $SkipBackup) {
        Write-ColorOutput "Sauvegarde créée: $BackupDir\modes_backup_$Timestamp.json" -ForegroundColor "Green"
    }
}

# Exécuter la fonction principale
Main