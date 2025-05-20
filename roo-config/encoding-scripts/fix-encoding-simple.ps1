# =========================================================
# Script: fix-encoding-simple.ps1
# =========================================================
# Description:
#   Script simple pour corriger les problèmes d'encodage dans les fichiers JSON.
#   Utilise plusieurs méthodes de conversion d'encodage pour résoudre les problèmes
#   courants avec les caractères accentués et les emojis.
#
# Fonctionnalités:
#   - Crée automatiquement une sauvegarde du fichier original
#   - Détecte les problèmes d'encodage courants (caractères accentués, emojis)
#   - Applique plusieurs méthodes de correction en cas d'échec
#   - Vérifie que le JSON reste valide après correction
#   - Restaure automatiquement la sauvegarde en cas d'échec
#
# Paramètres:
#   -SourcePath : Chemin du fichier à corriger (défaut: roo-modes/configs/standard-modes.json)
#   -BackupPath : Chemin de la sauvegarde (défaut: roo-modes/configs/standard-modes.json.bak)
#   -Force      : Force l'écrasement de la sauvegarde si elle existe déjà
#
# Utilisation:
#   .\fix-encoding-simple.ps1
#   .\fix-encoding-simple.ps1 -SourcePath "chemin\vers\fichier.json" -Force
#
# Auteur: Équipe Roo
# Date: Mai 2025
# =========================================================
param (
    [Parameter(Mandatory=$false)]
    [string]$SourcePath = "roo-modes/configs/standard-modes.json",
    
    [Parameter(Mandatory=$false)]
    [string]$BackupPath = "roo-modes/configs/standard-modes.json.bak",
    
    [Parameter(Mandatory=$false)]
    [switch]$Force = $false
)

# Vérifier si le fichier source existe
if (-not (Test-Path $SourcePath)) {
    Write-Host "Erreur : Le fichier source $SourcePath n'existe pas."
    exit 1
}

# Créer une sauvegarde si elle n'existe pas déjà ou si -Force est spécifié
if ((Test-Path $BackupPath) -and -not $Force) {
    Write-Host "Une sauvegarde existe déjà à $BackupPath. Utilisez -Force pour écraser."
} else {
    Copy-Item -Path $SourcePath -Destination $BackupPath -Force
    Write-Host "Sauvegarde créée à $BackupPath"
}

Write-Host "Correction de l'encodage en cours..."

# Approche 1: Utiliser la méthode de conversion d'encodage
try {
    # Lire le contenu du fichier avec l'encodage actuel
    $bytes = [System.IO.File]::ReadAllBytes($SourcePath)
    
    # Convertir les bytes en texte UTF-8
    $utf8 = [System.Text.Encoding]::UTF8
    $content = $utf8.GetString($bytes)
    
    # Détecter si le contenu est déjà correctement encodé
    $containsEncodingIssues = $content -match "Ã©|Ã¨|Ã°Å¸|ÃƒÂ°"
    
    if ($containsEncodingIssues) {
        Write-Host "Problèmes d'encodage détectés, tentative de correction..."
        
        # Approche 2: Utiliser une méthode de décodage multiple
        # Cette approche tente de décoder le texte plusieurs fois pour corriger le double/triple encodage
        
        # Convertir le texte en bytes avec l'encodage Latin1 (ISO-8859-1)
        $latin1 = [System.Text.Encoding]::GetEncoding("ISO-8859-1")
        $bytesLatin1 = $latin1.GetBytes($content)
        
        # Reconvertir en UTF-8
        $correctedContent = $utf8.GetString($bytesLatin1)
        
        # Écrire le contenu corrigé dans le fichier source
        [System.IO.File]::WriteAllText($SourcePath, $correctedContent, $utf8)
        
        Write-Host "Correction d'encodage terminée."
        
        # Vérifier si la correction a fonctionné
        $newContent = [System.IO.File]::ReadAllText($SourcePath, $utf8)
        $stillContainsEncodingIssues = $newContent -match "Ã©|Ã¨|Ã°Å¸|ÃƒÂ°"
        
        if ($stillContainsEncodingIssues) {
            Write-Host "Attention : Certains problèmes d'encodage n'ont pas pu être corrigés."
            
            # Approche 3: Essayer une autre méthode de correction
            Write-Host "Tentative avec une méthode alternative..."
            
            # Lire à nouveau le contenu original
            $originalContent = [System.IO.File]::ReadAllText($BackupPath, $utf8)
            
            # Appliquer une double conversion
            $bytesLatin1 = $latin1.GetBytes($originalContent)
            $tempContent = $utf8.GetString($bytesLatin1)
            $bytesLatin1Again = $latin1.GetBytes($tempContent)
            $correctedContent = $utf8.GetString($bytesLatin1Again)
            
            # Écrire le contenu corrigé dans le fichier source
            [System.IO.File]::WriteAllText($SourcePath, $correctedContent, $utf8)
            
            # Vérifier à nouveau
            $newContent = [System.IO.File]::ReadAllText($SourcePath, $utf8)
            $stillContainsEncodingIssues = $newContent -match "Ã©|Ã¨|Ã°Å¸|ÃƒÂ°"
            
            if ($stillContainsEncodingIssues) {
                Write-Host "La méthode alternative n'a pas fonctionné non plus."
                Write-Host "Restauration de la sauvegarde..."
                Copy-Item -Path $BackupPath -Destination $SourcePath -Force
                Write-Host "Sauvegarde restaurée."
            } else {
                Write-Host "La méthode alternative a fonctionné ! Tous les problèmes d'encodage ont été corrigés."
            }
        } else {
            Write-Host "Tous les problèmes d'encodage ont été corrigés avec succès."
        }
    } else {
        Write-Host "Aucun problème d'encodage détecté dans le fichier."
    }
    
    # Vérifier si le fichier est toujours du JSON valide
    try {
        $json = Get-Content -Path $SourcePath -Raw | ConvertFrom-Json
        Write-Host "Le fichier contient du JSON valide."
    } catch {
        Write-Host "Erreur : Le fichier ne contient pas du JSON valide. Restauration de la sauvegarde..."
        Copy-Item -Path $BackupPath -Destination $SourcePath -Force
        Write-Host "Sauvegarde restaurée."
    }
} catch {
    Write-Host "Erreur lors de la correction de l'encodage : $_"
    Write-Host "Restauration de la sauvegarde..."
    Copy-Item -Path $BackupPath -Destination $SourcePath -Force
    Write-Host "Sauvegarde restaurée."
}

# Afficher un résumé
Write-Host "==========================================================="
Write-Host "   Résumé des opérations"
Write-Host "==========================================================="
Write-Host "Fichier source : $SourcePath"
Write-Host "Fichier de sauvegarde : $BackupPath"
Write-Host "==========================================================="