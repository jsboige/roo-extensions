# =========================================================
# Script: simple-deploy.ps1
# =========================================================
# Description:
#   Script simplifié pour déployer rapidement les modes Roo (simple et complex).
#   Ce script est un wrapper autour de deploy-modes-simple-complex.ps1 qui
#   l'exécute avec l'option -Force pour un déploiement rapide sans confirmation.
#
# Fonctionnalités:
#   - Déploiement rapide des modes Roo
#   - Utilisation automatique de l'option -Force
#   - Vérification de l'existence du script principal
#
# Paramètres:
#   -Force : Force le déploiement (transmis au script principal)
#
# Utilisation:
#   .\simple-deploy.ps1
#
# Auteur: Équipe Roo
# Date: Mai 2025
# =========================================================
param (
    [Parameter(Mandatory=$false)]
    [switch]$Force = $false
)

# Chemin du script de déploiement
$deployScript = Join-Path $PSScriptRoot "deploy-modes-simple-complex.ps1"

# Vérifier si le script de déploiement existe
if (-not (Test-Path $deployScript)) {
    Write-Host "Erreur : Le script de déploiement $deployScript n'existe pas."
    exit 1
}

# Exécuter le script de déploiement avec l'option -Force
Write-Host "Exécution du script de déploiement avec l'option -Force..."
& $deployScript -Force

Write-Host "Déploiement terminé. Redémarrez Visual Studio Code et vérifiez les modes."