# ======================================================
# Script de nettoyage des espaces de travail (workspaces)
# ======================================================
#
# Description: Ce script supprime tout le contenu des répertoires workspace
# tout en préservant les fichiers README.md et les répertoires eux-mêmes.
#
# Auteur: Roo Assistant
# Date: 20/05/2025
# Version: 2.0
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
Write-ColorOutput "  NETTOYAGE DES ESPACES DE TRAVAIL" "Cyan"
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

# Recherche récursive de tous les répertoires workspace
Write-ColorOutput "Recherche des répertoires workspace..." "Yellow"
$workspaceDirs = Get-ChildItem -Path $demoRootPath -Recurse -Directory -Filter "workspace" | Where-Object {
    # Exclure les répertoires workspace qui ne sont pas dans la structure de démos
    $_.FullName -match "\\demo-\d+-\w+\\workspace$" -or $_.FullName -match "\\0\d-\w+\\demo-\d+-\w+\\workspace$"
}

Write-ColorOutput "Nombre de répertoires workspace trouvés: $($workspaceDirs.Count)" "Yellow"
Write-Host ""

# Compteur pour le suivi
$totalCleaned = 0
$totalErrors = 0

# Traitement de chaque répertoire workspace
foreach ($dir in $workspaceDirs) {
    # Vérification que le répertoire existe
    if (Test-Path $dir.FullName) {
        Write-ColorOutput "Traitement du répertoire: $($dir.FullName)" "Yellow"
        
        try {
            # Récupération de tous les éléments sauf README.md
            $itemsToRemove = Get-ChildItem -Path $dir.FullName -Exclude "README.md","desktop.ini" -ErrorAction Stop
            
            if ($itemsToRemove.Count -eq 0) {
                Write-ColorOutput "  → Aucun élément à supprimer" "Gray"
            } else {
                # Suppression des éléments
                foreach ($item in $itemsToRemove) {
                    try {
                        if (Test-Path $item.FullName) {
                            Remove-Item -Path $item.FullName -Recurse -Force -ErrorAction Stop
                            Write-ColorOutput "  → Supprimé: $($item.Name)" "Gray"
                            $totalCleaned++
                        }
                    } catch {
                        Write-ColorOutput "  → ERREUR lors de la suppression de $($item.Name): $_" "Red"
                        $totalErrors++
                    }
                }
            }
            
            Write-ColorOutput "  → Répertoire nettoyé avec succès!" "Green"
        } catch {
            Write-ColorOutput "  → ERREUR lors du traitement du répertoire $($dir.FullName) : $_" "Red"
            $totalErrors++
        }
    } else {
        Write-ColorOutput "Répertoire non trouvé: $($dir.FullName)" "Red"
        $totalErrors++
    }
    
    Write-Host ""
}

# Affichage du résumé
Write-ColorOutput "=========================================" "Cyan"
Write-ColorOutput "  RÉSUMÉ DU NETTOYAGE" "Cyan"
Write-ColorOutput "=========================================" "Cyan"
Write-ColorOutput "Éléments supprimés: $totalCleaned" $(if ($totalCleaned -gt 0) {"Green"} else {"White"})
Write-ColorOutput "Erreurs rencontrées: $totalErrors" $(if ($totalErrors -gt 0) {"Red"} else {"Green"})
Write-Host ""
Write-ColorOutput "Tous les espaces de travail ont été réinitialisés!" "Cyan"
Write-ColorOutput "Les fichiers README.md ont été préservés." "Cyan"
Write-ColorOutput "=========================================" "Cyan"