# Script de déploiement des modes N5
# Ce script permet de déployer les configurations micro-modes.json, mini-modes.json et standard-modes.json (modes simple/complex) vers le répertoire approprié de Roo

param (
    [Parameter(Mandatory = $false)]
    [ValidateSet("global", "local")]
    [string]$DeploymentType = "global",
    
    [Parameter(Mandatory = $false)]
    [switch]$Force
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
Write-ColorOutput "   Déploiement des modes N5 (micro, mini, simple, complex)" "Cyan"
Write-ColorOutput "=========================================================" "Cyan"

# Définir les chemins des fichiers source
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$microModesPath = Join-Path -Path $scriptDir -ChildPath "configs/micro-modes.json"
$miniModesPath = Join-Path -Path $scriptDir -ChildPath "configs/mini-modes.json"
$standardModesPath = Join-Path -Path (Split-Path -Parent (Split-Path -Parent $scriptDir)) -ChildPath "configs/standard-modes.json"

# Vérifier que les fichiers source existent
if (-not (Test-Path -Path $microModesPath)) {
    Write-ColorOutput "Erreur: Le fichier 'micro-modes.json' n'existe pas." "Red"
    exit 1
}

if (-not (Test-Path -Path $miniModesPath)) {
    Write-ColorOutput "Erreur: Le fichier 'mini-modes.json' n'existe pas." "Red"
    exit 1
}

if (-not (Test-Path -Path $standardModesPath)) {
    Write-ColorOutput "Erreur: Le fichier 'standard-modes.json' n'existe pas." "Red"
    exit 1
}

# Déterminer le chemin du répertoire de destination
if ($DeploymentType -eq "global") {
    $destinationDir = Join-Path -Path $env:APPDATA -ChildPath "Code\User\globalStorage\rooveterinaryinc.roo-cline\settings\n5-modes"
    
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
    $destinationDir = Join-Path -Path $projectRoot -ChildPath ".roo\n5-modes"
    
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
}

$microModesDestination = Join-Path -Path $destinationDir -ChildPath "micro-modes.json"
$miniModesDestination = Join-Path -Path $destinationDir -ChildPath "mini-modes.json"
$standardModesDestination = Join-Path -Path $destinationDir -ChildPath "standard-modes.json"

Write-ColorOutput "`nDéploiement des configurations en mode $DeploymentType..." "Yellow"
Write-ColorOutput "Destination: $destinationDir" "Yellow"

# Vérifier si les fichiers de destination existent déjà
$filesExist = (Test-Path -Path $microModesDestination) -or (Test-Path -Path $miniModesDestination) -or (Test-Path -Path $standardModesDestination)
if ($filesExist) {
    if (-not $Force) {
        $confirmation = Read-Host "Un ou plusieurs fichiers de destination existent déjà. Voulez-vous les remplacer? (O/N)"
        if ($confirmation -ne "O" -and $confirmation -ne "o") {
            Write-ColorOutput "Opération annulée." "Yellow"
            exit 0
        }
    }
}

# Copier les fichiers
$success = $true

try {
    Copy-Item -Path $microModesPath -Destination $microModesDestination -Force
    Write-ColorOutput "Déploiement de micro-modes.json réussi!" "Green"
} catch {
    Write-ColorOutput "Erreur lors du déploiement de micro-modes.json:" "Red"
    Write-ColorOutput $_.Exception.Message "Red"
    $success = $false
}

try {
    Copy-Item -Path $miniModesPath -Destination $miniModesDestination -Force
    Write-ColorOutput "Déploiement de mini-modes.json réussi!" "Green"
} catch {
    Write-ColorOutput "Erreur lors du déploiement de mini-modes.json:" "Red"
    Write-ColorOutput $_.Exception.Message "Red"
    $success = $false
}

try {
    Copy-Item -Path $standardModesPath -Destination $standardModesDestination -Force
    Write-ColorOutput "Déploiement de standard-modes.json (modes simple/complex) réussi!" "Green"
} catch {
    Write-ColorOutput "Erreur lors du déploiement de standard-modes.json:" "Red"
    Write-ColorOutput $_.Exception.Message "Red"
    $success = $false
}

# Vérifier que les fichiers sont identiques
if ($success) {
    Write-ColorOutput "`nVérification des fichiers déployés..." "Yellow"
    
    try {
        $microDiff = Compare-Object -ReferenceObject (Get-Content $microModesPath) -DifferenceObject (Get-Content $microModesDestination)
        
        if ($null -eq $microDiff) {
            Write-ColorOutput "Vérification réussie: micro-modes.json est identique." "Green"
        } else {
            Write-ColorOutput "Avertissement: micro-modes.json n'est pas identique." "Yellow"
            $success = $false
        }
    } catch {
        Write-ColorOutput "Erreur lors de la vérification de micro-modes.json:" "Red"
        Write-ColorOutput $_.Exception.Message "Red"
        $success = $false
    }
    
    try {
        $miniDiff = Compare-Object -ReferenceObject (Get-Content $miniModesPath) -DifferenceObject (Get-Content $miniModesDestination)
        
        if ($null -eq $miniDiff) {
            Write-ColorOutput "Vérification réussie: mini-modes.json est identique." "Green"
        } else {
            Write-ColorOutput "Avertissement: mini-modes.json n'est pas identique." "Yellow"
            $success = $false
        }
    } catch {
        Write-ColorOutput "Erreur lors de la vérification de mini-modes.json:" "Red"
        Write-ColorOutput $_.Exception.Message "Red"
        $success = $false
    }
    
    try {
        $standardDiff = Compare-Object -ReferenceObject (Get-Content $standardModesPath) -DifferenceObject (Get-Content $standardModesDestination)
        
        if ($null -eq $standardDiff) {
            Write-ColorOutput "Vérification réussie: standard-modes.json est identique." "Green"
        } else {
            Write-ColorOutput "Avertissement: standard-modes.json n'est pas identique." "Yellow"
            $success = $false
        }
    } catch {
        Write-ColorOutput "Erreur lors de la vérification de standard-modes.json:" "Red"
        Write-ColorOutput $_.Exception.Message "Red"
        $success = $false
    }
}

# Résumé
Write-ColorOutput "`n=========================================================" "Cyan"
if ($success) {
    Write-ColorOutput "   Déploiement terminé avec succès!" "Green"
} else {
    Write-ColorOutput "   Déploiement terminé avec des avertissements ou erreurs." "Yellow"
}
Write-ColorOutput "=========================================================" "Cyan"

if ($DeploymentType -eq "global") {
    Write-ColorOutput "`nLes modes N5 (micro, mini, simple, complex) ont été déployés globalement et seront disponibles dans toutes les instances de VS Code." "White"
} else {
    Write-ColorOutput "`nLes modes N5 (micro, mini, simple, complex) ont été déployés localement et seront disponibles uniquement dans ce projet." "White"
}

Write-ColorOutput "`nPour activer les modes personnalisés:" "White"
Write-ColorOutput "1. Redémarrez Visual Studio Code" "White"
Write-ColorOutput "2. Ouvrez la palette de commandes (Ctrl+Shift+P)" "White"
Write-ColorOutput "3. Tapez 'Roo: Switch Mode' et sélectionnez un mode personnalisé" "White"
Write-ColorOutput "`n" "White"