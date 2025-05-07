# Script pour commiter et pusher les modifications de l'architecture à 5 niveaux compatible avec Roo-Code

# Paramètres
param (
    [string]$CommitMessage = "Adaptation de l'architecture à 5 niveaux pour compatibilité avec Roo-Code",
    [switch]$NoPush = $false
)

# Constantes
$RootDir = (Get-Item $PSScriptRoot).Parent.Parent.FullName

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

# Fonction pour vérifier si Git est installé
function Test-GitInstalled {
    try {
        $null = git --version
        return $true
    } catch {
        Write-ColorOutput "Erreur: Git n'est pas installé ou n'est pas dans le PATH" -ForegroundColor "Red"
        return $false
    }
}

# Fonction pour vérifier si le répertoire est un dépôt Git
function Test-GitRepository {
    try {
        Push-Location $RootDir
        $null = git rev-parse --is-inside-work-tree
        $isGitRepo = $?
        Pop-Location
        return $isGitRepo
    } catch {
        Write-ColorOutput "Erreur: Le répertoire n'est pas un dépôt Git" -ForegroundColor "Red"
        return $false
    }
}

# Fonction pour afficher le statut Git
function Show-GitStatus {
    Write-ColorOutput "Statut Git actuel:" -ForegroundColor "Cyan"
    Push-Location $RootDir
    git status
    Pop-Location
}

# Fonction pour ajouter les fichiers modifiés
function Add-GitFiles {
    Write-ColorOutput "Ajout des fichiers modifiés..." -ForegroundColor "Cyan"
    
    # Liste des fichiers à ajouter
    $filesToAdd = @(
        "roo-modes-n5/configs/n5-modes-roo-compatible.json",
        "roo-modes-n5/scripts/deploy-roo-compatible.ps1",
        "roo-modes-n5/docs/guide-migration-roo-compatible.md",
        "roo-modes-n5/scripts/test-roo-compatible-transitions.js",
        "roo-modes-n5/scripts/commit-roo-compatible.ps1"
    )
    
    # Ajouter chaque fichier
    Push-Location $RootDir
    foreach ($file in $filesToAdd) {
        if (Test-Path $file) {
            git add $file
            Write-ColorOutput "  Ajouté: $file" -ForegroundColor "Green"
        } else {
            Write-ColorOutput "  Avertissement: Fichier non trouvé: $file" -ForegroundColor "Yellow"
        }
    }
    Pop-Location
}

# Fonction pour commiter les modifications
function Commit-GitChanges {
    param (
        [string]$Message
    )
    
    Write-ColorOutput "Commit des modifications..." -ForegroundColor "Cyan"
    Push-Location $RootDir
    git commit -m $Message
    $commitSuccess = $?
    Pop-Location
    
    if ($commitSuccess) {
        Write-ColorOutput "Commit réussi avec le message: $Message" -ForegroundColor "Green"
    } else {
        Write-ColorOutput "Erreur lors du commit" -ForegroundColor "Red"
    }
    
    return $commitSuccess
}

# Fonction pour pusher les modifications
function Push-GitChanges {
    Write-ColorOutput "Push des modifications..." -ForegroundColor "Cyan"
    Push-Location $RootDir
    git push
    $pushSuccess = $?
    Pop-Location
    
    if ($pushSuccess) {
        Write-ColorOutput "Push réussi" -ForegroundColor "Green"
    } else {
        Write-ColorOutput "Erreur lors du push" -ForegroundColor "Red"
    }
    
    return $pushSuccess
}

# Fonction principale
function Main {
    Write-ColorOutput "=== Commit et push des modifications de l'architecture à 5 niveaux compatible avec Roo-Code ===" -ForegroundColor "Magenta"
    
    # Vérifier si Git est installé
    if (-not (Test-GitInstalled)) {
        exit 1
    }
    
    # Vérifier si le répertoire est un dépôt Git
    if (-not (Test-GitRepository)) {
        exit 1
    }
    
    # Afficher le statut Git
    Show-GitStatus
    
    # Ajouter les fichiers modifiés
    Add-GitFiles
    
    # Commiter les modifications
    $commitSuccess = Commit-GitChanges -Message $CommitMessage
    if (-not $commitSuccess) {
        exit 1
    }
    
    # Pusher les modifications si demandé
    if (-not $NoPush) {
        $pushSuccess = Push-GitChanges
        if (-not $pushSuccess) {
            exit 1
        }
    } else {
        Write-ColorOutput "Push ignoré (--no-push)" -ForegroundColor "Yellow"
    }
    
    Write-ColorOutput "=== Opération terminée avec succès ===" -ForegroundColor "Magenta"
}

# Exécuter la fonction principale
Main