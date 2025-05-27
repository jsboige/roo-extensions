# Script de correction d'encodage PowerShell
# Auteur: Roo (Assistant IA)
# Date: 26/05/2025

param(
    [string]$ProfilePath = "$env:USERPROFILE\OneDrive\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1",
    [switch]$Force
)

Write-Host "=== Correction d'encodage PowerShell ===" -ForegroundColor Cyan
Write-Host "Profil cible: $ProfilePath" -ForegroundColor Yellow

# Créer le répertoire du profil s'il n'existe pas
$ProfileDir = Split-Path $ProfilePath -Parent
if (-not (Test-Path $ProfileDir)) {
    Write-Host "Création du répertoire de profil: $ProfileDir" -ForegroundColor Yellow
    New-Item -ItemType Directory -Path $ProfileDir -Force | Out-Null
}

# Lire le contenu existant s'il existe
$ExistingContent = ""
if (Test-Path $ProfilePath) {
    $ExistingContent = Get-Content $ProfilePath -Raw
    Write-Host "✓ Profil existant détecté, préservation du contenu" -ForegroundColor Green
}

# Créer le nouveau contenu avec configuration d'encodage
$DateStamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$NewProfileContent = @"
# Configuration d'encodage UTF-8 pour PowerShell
# Ajouté automatiquement pour corriger les problèmes d'affichage des caractères français
# Date: $DateStamp

# Forcer l'encodage de sortie en UTF-8
`$OutputEncoding = [System.Text.Encoding]::UTF8

# Configurer l'encodage de la console
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::InputEncoding = [System.Text.Encoding]::UTF8

# Définir la code page UTF-8 (65001)
try {
    chcp 65001 | Out-Null
} catch {
    Write-Warning "Impossible de définir la code page 65001: `$(`$_.Exception.Message)"
}

# Message de confirmation (optionnel, peut être commenté)
# Write-Host "Configuration d'encodage UTF-8 appliquée" -ForegroundColor Green

"@

# Si du contenu existant, l'ajouter après la configuration d'encodage
if ($ExistingContent.Trim()) {
    # Vérifier si la configuration d'encodage existe déjà
    if (($ExistingContent -match "OutputEncoding.*UTF8" -or $ExistingContent -match "chcp 65001") -and -not $Force) {
        Write-Host "⚠ Configuration d'encodage déjà présente dans le profil" -ForegroundColor Yellow
        Write-Host "Le profil ne sera pas modifié. Utilisez -Force pour forcer la mise à jour." -ForegroundColor Yellow
        return
    }
    
    $NewProfileContent += "`n# === Configuration existante préservée ===`n"
    $NewProfileContent += $ExistingContent
}

# Écrire le nouveau profil
try {
    Set-Content -Path $ProfilePath -Value $NewProfileContent -Encoding UTF8 -Force
    Write-Host "✓ Profil PowerShell mis à jour avec la configuration d'encodage UTF-8" -ForegroundColor Green
    
    Write-Host "`n=== Configuration appliquée ===" -ForegroundColor Cyan
    Write-Host "• OutputEncoding: UTF-8" -ForegroundColor Green
    Write-Host "• Console.OutputEncoding: UTF-8" -ForegroundColor Green
    Write-Host "• Console.InputEncoding: UTF-8" -ForegroundColor Green
    Write-Host "• Code page: 65001 (UTF-8)" -ForegroundColor Green
    
    Write-Host "`n⚠ IMPORTANT: Redémarrez PowerShell pour appliquer les changements" -ForegroundColor Yellow
    Write-Host "Puis exécutez 'test-encoding.ps1' pour valider la configuration" -ForegroundColor Yellow
    
} catch {
    Write-Host "✗ Erreur lors de la mise à jour du profil: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
