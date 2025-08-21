# ======================================================
# Script de préparation des espaces de travail (workspaces)
# ======================================================
#
# Description: Ce script copie les fichiers nécessaires depuis les répertoires
# "ressources" vers les répertoires "workspace" pour préparer les démos.
#
# Auteur: Roo Assistant
# Date: 20/05/2025
# Version: 1.0
# ======================================================

# Fonction pour afficher les messages avec formatage
function Write-ColorOutput {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Message,
        
        [Parameter(Mandatory=$false)]
        [string]$ForegroundColor = "White"
    )
    
    Write-Host $Message -ForegroundColor $ForegroundColor
}

# Affichage du titre
Write-ColorOutput "=========================================" "Cyan"
Write-ColorOutput "  PRÉPARATION DES ESPACES DE TRAVAIL" "Cyan"
Write-ColorOutput "=========================================" "Cyan"
Write-Host ""

# Déterminer le chemin du script pour trouver le répertoire racine du projet
$scriptPath = $PSScriptRoot
if (-not $scriptPath) {
    $scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
}

# Remonter de deux niveaux pour atteindre la racine du projet
$rootPath = Join-Path -Path $scriptPath -ChildPath "..\.."
$rootPath = [System.IO.Path]::GetFullPath($rootPath)

# Définir le chemin vers le répertoire demo-roo-code
$demoRootPath = Join-Path -Path $rootPath -ChildPath "demo-roo-code"

# Recherche récursive de tous les répertoires de démo
Write-ColorOutput "Recherche des répertoires de démo..." "Yellow"
$demoDirs = Get-ChildItem -Path $demoRootPath -Recurse -Directory | Where-Object {
    $_.Name -match "^demo-\d+-\w+"
}

Write-ColorOutput "Nombre de répertoires de démo trouvés: $($demoDirs.Count)" "Yellow"
Write-Host ""

# Compteur pour le suivi
$totalCopied = 0
$totalErrors = 0

# Traitement de chaque répertoire de démo
foreach ($demoDir in $demoDirs) {
    Write-ColorOutput "Traitement de la démo: $($demoDir.Name)" "Yellow"
    
    # Vérifier si le répertoire ressources existe
    $resourcesDir = Join-Path -Path $demoDir.FullName -ChildPath "ressources"
    if (-not (Test-Path $resourcesDir)) {
        # Essayer avec ressourcesX si ressources n'existe pas
        $resourcesDir = Join-Path -Path $demoDir.FullName -ChildPath "ressourcesX"
        if (-not (Test-Path $resourcesDir)) {
            Write-ColorOutput "  → Aucun répertoire ressources trouvé pour cette démo" "Red"
            $totalErrors++
            continue
        }
    }
    
    # Vérifier si le répertoire workspace existe
    $workspaceDir = Join-Path -Path $demoDir.FullName -ChildPath "workspace"
    if (-not (Test-Path $workspaceDir)) {
        Write-ColorOutput "  → Répertoire workspace non trouvé pour cette démo" "Red"
        $totalErrors++
        continue
    }
    
    # Vérifier s'il y a des fichiers à copier dans le répertoire ressources
    $resourceFiles = Get-ChildItem -Path $resourcesDir -File -Recurse
    if ($resourceFiles.Count -eq 0) {
        Write-ColorOutput "  → Aucun fichier ressource à copier" "Gray"
        continue
    }
    
    # Copier les fichiers du répertoire ressources vers le répertoire workspace
    try {
        # Nettoyer d'abord le répertoire workspace (sauf README.md)
        $itemsToRemove = Get-ChildItem -Path $workspaceDir -Exclude "README.md","desktop.ini" -ErrorAction Stop
        foreach ($item in $itemsToRemove) {
            if (Test-Path $item.FullName) {
                Remove-Item -Path $item.FullName -Recurse -Force -ErrorAction Stop
            }
        }
        
        # Copier les fichiers
        foreach ($file in $resourceFiles) {
            # Déterminer le chemin relatif du fichier par rapport au répertoire ressources
            $relativePath = $file.FullName.Substring($resourcesDir.Length)
            
            # Construire le chemin de destination
            $destinationPath = Join-Path -Path $workspaceDir -ChildPath $relativePath
            
            # Créer le répertoire de destination s'il n'existe pas
            $destinationDir = Split-Path -Path $destinationPath -Parent
            if (-not (Test-Path $destinationDir)) {
                New-Item -Path $destinationDir -ItemType Directory -Force | Out-Null
            }
            
            # Copier le fichier
            Copy-Item -Path $file.FullName -Destination $destinationPath -Force
            Write-ColorOutput "  → Copié: $relativePath" "Gray"
            $totalCopied++
        }
        
        Write-ColorOutput "  → Espace de travail préparé avec succès!" "Green"
    } catch {
        Write-ColorOutput "  → ERREUR lors de la préparation de l'espace de travail: $_" "Red"
        $totalErrors++
    }
    
    Write-Host ""
}

# Affichage du résumé
Write-ColorOutput "=========================================" "Cyan"
Write-ColorOutput "  RÉSUMÉ DE LA PRÉPARATION" "Cyan"
Write-ColorOutput "=========================================" "Cyan"
Write-ColorOutput "Fichiers copiés: $totalCopied" $(if ($totalCopied -gt 0) {"Green"} else {"White"})
Write-ColorOutput "Erreurs rencontrées: $totalErrors" $(if ($totalErrors -gt 0) {"Red"} else {"Green"})
Write-Host ""
Write-ColorOutput "Tous les espaces de travail ont été préparés!" "Cyan"
Write-ColorOutput "=========================================" "Cyan"